import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/core/error/failure.dart';
import 'package:pos_system/features/credit_ledger/domain/credit_ledger_models.dart';
import 'package:pos_system/providers/app_providers.dart';

final creditLedgerRepositoryProvider = Provider<CreditLedgerRepository>((ref) {
  return CreditLedgerRepository(ref.watch(databaseProvider));
});

class CreditLedgerRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  CreditLedgerRepository(this._db);

  /// Returns all customers with any outstanding credit balance,
  /// sorted by highest balance first.
  /// Balance is computed on-demand from [Sales.balanceDue] — no cached total.
  Future<Either<Failure, List<CustomerBalance>>> getOutstandingCustomers() async {
    try {
      // Select all credit sales with remaining balance
      final rows = await (_db.select(_db.sales)
            ..where((s) =>
                s.isCreditSale.equals(true) &
                s.balanceDue.isBiggerThanValue(0.001)))
          .get();

      // Group by phone (primary key) while preserving the name
      final Map<String, _CustomerAccumulator> acc = {};
      for (final row in rows) {
        final phone = row.customerPhone ?? 'unknown';
        acc.putIfAbsent(
          phone,
          () => _CustomerAccumulator(phone: phone, name: row.customerName),
        );
        acc[phone]!.totalOutstanding += row.balanceDue;
        acc[phone]!.unpaidSaleCount += 1;
      }

      final result = acc.values
          .map((a) => CustomerBalance(
                customerPhone: a.phone,
                customerName: a.name,
                totalOutstanding: a.totalOutstanding,
                unpaidSaleCount: a.unpaidSaleCount,
              ))
          .toList()
        ..sort((a, b) => b.totalOutstanding.compareTo(a.totalOutstanding));

      return Right(result);
    } catch (e, st) {
      return Left(Failure('Failed to load credit ledger', error: e, stackTrace: st));
    }
  }

  /// Returns all credit sales for [customerPhone], most recent first.
  Future<Either<Failure, List<CreditSaleSummary>>> getSalesForCustomer(
    String customerPhone,
  ) async {
    try {
      final rows = await (_db.select(_db.sales)
            ..where((s) =>
                s.customerPhone.equals(customerPhone) &
                s.isCreditSale.equals(true))
            ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
          .get();

      final summaries = rows
          .map((r) => CreditSaleSummary(
                saleId: r.id,
                total: r.total,
                amountPaid: r.amountPaid,
                balanceDue: r.balanceDue,
                createdAt: r.createdAt,
              ))
          .toList();

      return Right(summaries);
    } catch (e, st) {
      return Left(Failure('Failed to load sales for customer', error: e, stackTrace: st));
    }
  }

  /// Returns all payment records for [customerPhone], most recent first.
  Future<Either<Failure, List<CreditPayment>>> getPaymentsForCustomer(
    String customerPhone,
  ) async {
    try {
      final rows = await (_db.select(_db.creditPayments)
            ..where((p) => p.customerPhone.equals(customerPhone))
            ..orderBy([(p) => OrderingTerm.desc(p.collectedAt)]))
          .get();

      final payments = rows
          .map((r) => CreditPayment(
                id: r.id,
                customerPhone: r.customerPhone,
                saleId: r.saleId,
                amount: r.amount,
                paymentMethod: r.paymentMethod,
                collectedAt: r.collectedAt,
                notes: r.notes,
              ))
          .toList();

      return Right(payments);
    } catch (e, st) {
      return Left(Failure('Failed to load payments for customer', error: e, stackTrace: st));
    }
  }

  /// Records a credit payment.
  ///
  /// If [saleId] is provided, the payment is applied directly to that sale.
  /// If [saleId] is null, the payment is applied to the customer's oldest
  /// outstanding sale(s) first (FIFO — clears oldest debt first).
  ///
  /// The repository validates that the payment does not exceed the customer's
  /// total outstanding balance and returns [Left] if it would.
  ///
  /// All balance updates happen inside a single atomic transaction.
  Future<Either<Failure, CreditPayment>> recordPayment({
    required String customerPhone,
    String? targetSaleId,
    required double amount,
    required CreditPaymentMethod paymentMethod,
    String? notes,
  }) async {
    if (amount <= 0) {
      return Left(Failure('Payment amount must be greater than zero'));
    }

    try {
      CreditPayment? recorded;

      await _db.transaction(() async {
        // ── 1. Validate against outstanding balance ──────────────────────────
        if (targetSaleId != null) {
          // Targeted payment: check just that sale's balance
          final saleRow = await (_db.select(_db.sales)
                ..where((s) => s.id.equals(targetSaleId)))
              .getSingleOrNull();
          if (saleRow == null) {
            throw Exception('Sale $targetSaleId not found');
          }
          if (amount > saleRow.balanceDue + 0.001) {
            throw _OverpaymentException(
              'Payment of ${amount.toStringAsFixed(2)} exceeds balance due '
              'of ${saleRow.balanceDue.toStringAsFixed(2)} for this sale.',
            );
          }
          // Apply directly to that sale
          final newAmountPaid = saleRow.amountPaid + amount;
          final newBalanceDue = (saleRow.balanceDue - amount).clamp(0.0, double.infinity);
          await (_db.update(_db.sales)..where((s) => s.id.equals(targetSaleId))).write(
            SalesCompanion(
              amountPaid: Value(newAmountPaid),
              balanceDue: Value(newBalanceDue),
            ),
          );
        } else {
          // General payment: apply FIFO to oldest outstanding sales
          final outstandingSales = await (_db.select(_db.sales)
                ..where((s) =>
                    s.customerPhone.equals(customerPhone) &
                    s.isCreditSale.equals(true) &
                    s.balanceDue.isBiggerThanValue(0.001))
                ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]))
              .get();

          final totalOutstanding =
              outstandingSales.fold(0.0, (sum, s) => sum + s.balanceDue);

          if (amount > totalOutstanding + 0.001) {
            throw _OverpaymentException(
              'Payment of ${amount.toStringAsFixed(2)} exceeds total outstanding balance '
              'of ${totalOutstanding.toStringAsFixed(2)}.',
            );
          }

          double remaining = amount;
          for (final sale in outstandingSales) {
            if (remaining <= 0) break;
            final applied = remaining <= sale.balanceDue ? remaining : sale.balanceDue;
            final newAmountPaid = sale.amountPaid + applied;
            final newBalanceDue = (sale.balanceDue - applied).clamp(0.0, double.infinity);
            await (_db.update(_db.sales)..where((s) => s.id.equals(sale.id))).write(
              SalesCompanion(
                amountPaid: Value(newAmountPaid),
                balanceDue: Value(newBalanceDue),
              ),
            );
            remaining -= applied;
          }
        }

        // ── 2. Insert payment record ─────────────────────────────────────────
        final paymentId = _uuid.v4();
        final now = DateTime.now();
        await _db.into(_db.creditPayments).insert(
              CreditPaymentsCompanion.insert(
                id: paymentId,
                customerPhone: customerPhone,
                saleId: Value(targetSaleId),
                amount: amount,
                paymentMethod: paymentMethod,
                collectedAt: Value(now),
                notes: Value(notes),
              ),
            );

        recorded = CreditPayment(
          id: paymentId,
          customerPhone: customerPhone,
          saleId: targetSaleId,
          amount: amount,
          paymentMethod: paymentMethod,
          collectedAt: now,
          notes: notes,
        );
      });

      return Right(recorded!);
    } on _OverpaymentException catch (e) {
      return Left(Failure(e.message));
    } catch (e, st) {
      return Left(Failure('Failed to record payment: $e', error: e, stackTrace: st));
    }
  }
}

// ── Internal helpers ──────────────────────────────────────────────────────────

class _CustomerAccumulator {
  final String phone;
  final String? name;
  double totalOutstanding = 0;
  int unpaidSaleCount = 0;

  _CustomerAccumulator({required this.phone, this.name});
}

class _OverpaymentException implements Exception {
  final String message;
  const _OverpaymentException(this.message);
}
