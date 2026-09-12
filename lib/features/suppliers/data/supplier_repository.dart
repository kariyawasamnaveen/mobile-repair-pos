import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/core/error/failure.dart';
import 'package:pos_system/features/auth/data/activity_log_repository.dart';
import 'package:pos_system/features/auth/presentation/auth_controller.dart';
import 'package:pos_system/features/suppliers/domain/supplier.dart';
import 'package:pos_system/providers/app_providers.dart';
import 'package:uuid/uuid.dart';

import 'package:pos_system/features/settings/data/settings_repository.dart';

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepository(
    ref.watch(databaseProvider),
    ref.watch(activityLogRepositoryProvider),
    ref.watch(settingsRepositoryProvider),
    ref.watch(authStateProvider)?.id,
  );
});

class SupplierRepository {
  final AppDatabase _db;
  final ActivityLogRepository _activityLogRepository;
  final SettingsRepository _settings;
  final String? _currentStaffId;
  final _uuid = const Uuid();

  SupplierRepository(this._db, this._activityLogRepository, this._settings, this._currentStaffId);

  // ─── Suppliers ─────────────────────────────────────────────────────────────

  Future<Either<Failure, List<SupplierWithBalance>>> getSuppliersWithBalance() async {
    try {
      final query = _db.select(_db.suppliers)
        ..where((t) => t.isActive.equals(true))
        ..orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]);
      
      final suppliersEntities = await query.get();
      final List<SupplierWithBalance> result = [];

      for (final e in suppliersEntities) {
        final balanceRes = await _db.customSelect(
          'SELECT SUM(balance_due) as total_owed FROM purchase_orders WHERE supplier_id = ? AND status != ?',
          variables: [Variable.withString(e.id), Variable.withString('cancelled')],
        ).getSingle();
        
        final balance = balanceRes.read<double?>('total_owed') ?? 0.0;
        result.add(SupplierWithBalance(
          supplier: Supplier.fromEntity(e),
          balanceDue: balance,
        ));
      }

      return Right(result);
    } catch (e, st) {
      return Left(Failure('Failed to load suppliers', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, Supplier>> getSupplierById(String id) async {
    try {
      final e = await (_db.select(_db.suppliers)..where((t) => t.id.equals(id))).getSingle();
      return Right(Supplier.fromEntity(e));
    } catch (e, st) {
      return Left(Failure('Failed to load supplier', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, Supplier>> createSupplier({
    required String name,
    String? phone,
    String? address,
    String? notes,
  }) async {
    try {
      final id = _uuid.v4();
      final companion = SuppliersCompanion.insert(
        id: id,
        name: name,
        phone: Value(phone),
        address: Value(address),
        notes: Value(notes),
      );
      
      await _db.into(_db.suppliers).insert(companion);
      final newSupplier = await getSupplierById(id);
      return newSupplier;
    } catch (e, st) {
      return Left(Failure('Failed to create supplier', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, void>> updateSupplier(String id, {
    String? name,
    String? phone,
    String? address,
    String? notes,
  }) async {
    try {
      await (_db.update(_db.suppliers)..where((t) => t.id.equals(id))).write(
        SuppliersCompanion(
          name: name != null ? Value(name) : const Value.absent(),
          phone: phone != null ? Value(phone) : const Value.absent(),
          address: address != null ? Value(address) : const Value.absent(),
          notes: notes != null ? Value(notes) : const Value.absent(),
        ),
      );
      return const Right(null);
    } catch (e, st) {
      return Left(Failure('Failed to update supplier', error: e, stackTrace: st));
    }
  }

  // ─── Purchase Orders ───────────────────────────────────────────────────────

  Future<Either<Failure, String>> createPurchaseOrder(PurchaseOrder po, List<PurchaseOrderItem> items) async {
    try {
      final currentBranchRes = await _settings.getCurrentBranchId();
      final currentBranchId = currentBranchRes.isRight() ? currentBranchRes.getRight().toNullable() : null;

      return await _db.transaction(() async {
        await _db.into(_db.purchaseOrders).insert(
          PurchaseOrdersCompanion.insert(
            id: po.id,
            poNumber: po.poNumber,
            supplierId: po.supplierId,
            status: const Value(PurchaseOrderStatus.ordered),
            orderDate: Value(po.orderDate),
            expectedDate: Value(po.expectedDate),
            totalAmount: Value(po.totalAmount),
            amountPaid: const Value(0.0),
            balanceDue: Value(po.totalAmount),
            notes: Value(po.notes),
            branchId: currentBranchId == null ? const Value.absent() : Value(currentBranchId),
          )
        );

        for (final item in items) {
          await _db.into(_db.purchaseOrderItems).insert(
            PurchaseOrderItemsCompanion.insert(
              purchaseOrderId: po.id,
              itemId: Value(item.itemId),
              itemNameText: Value(item.itemNameText),
              quantityOrdered: item.quantityOrdered,
              quantityReceived: const Value(0),
              unitCost: item.unitCost,
              lineTotal: item.lineTotal,
            )
          );
        }

        await _activityLogRepository.logAction(
          actionType: ActivityActionType.po_created,
          description: 'Created PO ${po.poNumber} for ${po.totalAmount}',
          staffId: _currentStaffId,
          branchId: currentBranchId,
        );

        return Right(po.id);
      });
    } catch (e, st) {
      return Left(Failure('Failed to create purchase order', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, String>> _generatePoNumber() async {
    final countRes = await _db.customSelect('SELECT COUNT(*) as c FROM purchase_orders').getSingle();
    final count = countRes.read<int>('c');
    return Right('PO-${(count + 1).toString().padLeft(4, '0')}');
  }

  Future<Either<Failure, PurchaseOrder>> getNewDraftPurchaseOrder(String supplierId) async {
    try {
      final poNumberRes = await _generatePoNumber();
      return poNumberRes.fold(
        (l) => Left(l),
        (poNumber) => Right(PurchaseOrder(
          id: _uuid.v4(),
          poNumber: poNumber,
          supplierId: supplierId,
          status: PurchaseOrderStatus.draft,
          orderDate: DateTime.now(),
          totalAmount: 0,
          amountPaid: 0,
          balanceDue: 0,
          createdAt: DateTime.now(),
        )),
      );
    } catch (e, st) {
      return Left(Failure('Failed to generate draft PO', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, List<PurchaseOrder>>> getPurchaseOrders({String? supplierId, PurchaseOrderStatus? status}) async {
    try {
      final query = _db.select(_db.purchaseOrders)
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);
        
      if (supplierId != null) {
        query.where((t) => t.supplierId.equals(supplierId));
      }
      if (status != null) {
        query.where((t) => t.status.equals(status.name));
      }

      final entities = await query.get();
      final List<PurchaseOrder> pos = [];

      for (final e in entities) {
        final supplierE = await (_db.select(_db.suppliers)..where((t) => t.id.equals(e.supplierId))).getSingle();
        pos.add(PurchaseOrder.fromEntity(e, supplier: Supplier.fromEntity(supplierE)));
      }

      return Right(pos);
    } catch (e, st) {
      return Left(Failure('Failed to load purchase orders', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, PurchaseOrder>> getPurchaseOrderById(String id) async {
    try {
      final e = await (_db.select(_db.purchaseOrders)..where((t) => t.id.equals(id))).getSingle();
      final supplierE = await (_db.select(_db.suppliers)..where((t) => t.id.equals(e.supplierId))).getSingle();
      final itemsE = await (_db.select(_db.purchaseOrderItems)..where((t) => t.purchaseOrderId.equals(id))).get();
      
      return Right(PurchaseOrder.fromEntity(
        e, 
        items: itemsE.map((i) => PurchaseOrderItem.fromEntity(i)).toList(),
        supplier: Supplier.fromEntity(supplierE),
      ));
    } catch (e, st) {
      return Left(Failure('Failed to load purchase order', error: e, stackTrace: st));
    }
  }

  // ─── Receiving Items ───────────────────────────────────────────────────────

  Future<Either<Failure, void>> receiveItems(String purchaseOrderId, Map<int, int> receivedQuantities) async {
    try {
      return await _db.transaction(() async {
        final poE = await (_db.select(_db.purchaseOrders)..where((t) => t.id.equals(purchaseOrderId))).getSingle();
        final itemsE = await (_db.select(_db.purchaseOrderItems)..where((t) => t.purchaseOrderId.equals(purchaseOrderId))).get();
        
        bool allFullyReceived = true;
        bool anyReceived = false;

        for (final itemE in itemsE) {
          final toReceiveNow = receivedQuantities[itemE.id] ?? 0;
          if (toReceiveNow <= 0) {
            if (itemE.quantityReceived < itemE.quantityOrdered) {
              allFullyReceived = false;
            }
            continue;
          }

          final newTotalReceived = itemE.quantityReceived + toReceiveNow;
          if (newTotalReceived > itemE.quantityOrdered) {
            return Left(Failure('Cannot receive more than ordered for item ${itemE.id}'));
          }

          if (newTotalReceived < itemE.quantityOrdered) {
            allFullyReceived = false;
          }
          anyReceived = true;

          // 1. Update PO Item
          await (_db.update(_db.purchaseOrderItems)..where((t) => t.id.equals(itemE.id))).write(
            PurchaseOrderItemsCompanion(quantityReceived: Value(newTotalReceived))
          );

          // 2. Update Inventory
          if (itemE.itemId != null) {
            final invItem = await (_db.select(_db.items)..where((t) => t.id.equals(itemE.itemId!))).getSingleOrNull();
            if (invItem != null) {
              await (_db.update(_db.items)..where((t) => t.id.equals(invItem.id))).write(
                ItemsCompanion(quantity: Value(invItem.quantity + toReceiveNow))
              );
              
              // 3. Log Stock Movement
              await _db.into(_db.stockMovements).insert(
                StockMovementsCompanion.insert(
                  itemId: invItem.id,
                  changeAmount: toReceiveNow,
                  reason: MovementReason.purchaseReceived,
                  saleId: Value(purchaseOrderId),
                )
              );
            }
          }
        }

        if (anyReceived) {
          // Update PO Status
          final newStatus = allFullyReceived ? PurchaseOrderStatus.received : PurchaseOrderStatus.partiallyReceived;
          await (_db.update(_db.purchaseOrders)..where((t) => t.id.equals(purchaseOrderId))).write(
            PurchaseOrdersCompanion(status: Value(newStatus))
          );

          final currentBranchRes = await _settings.getCurrentBranchId();
          final currentBranchId = currentBranchRes.isRight() ? currentBranchRes.getRight().toNullable() : null;

          await _activityLogRepository.logAction(
            actionType: ActivityActionType.po_received,
            description: 'Received items for PO ${poE.poNumber} ($newStatus)',
            staffId: _currentStaffId,
            branchId: currentBranchId,
          );
        }

        return const Right(null);
      });
    } catch (e, st) {
      return Left(Failure('Failed to receive items', error: e, stackTrace: st));
    }
  }

  // ─── Supplier Payments ─────────────────────────────────────────────────────

  Future<Either<Failure, void>> recordPayment({
    required String supplierId,
    required double amount,
    required CreditPaymentMethod method,
    String? purchaseOrderId,
    String? notes,
  }) async {
    try {
      if (amount <= 0) return Left(Failure('Payment amount must be greater than 0'));

      return await _db.transaction(() async {
        // 1. Validate total owed
        final balanceRes = await _db.customSelect(
          'SELECT SUM(balance_due) as total_owed FROM purchase_orders WHERE supplier_id = ? AND status != ? AND balance_due > 0',
          variables: [Variable.withString(supplierId), Variable.withString('cancelled')],
        ).getSingle();
        
        final totalOwed = balanceRes.read<double?>('total_owed') ?? 0.0;
        
        if (amount > totalOwed) {
          return Left(Failure('Payment amount ($amount) exceeds total outstanding balance ($totalOwed)'));
        }

        // 2. Fetch outstanding POs
        var query = _db.select(_db.purchaseOrders)
          ..where((t) => t.supplierId.equals(supplierId))
          ..where((t) => t.status.isNotIn([PurchaseOrderStatus.cancelled.name]))
          ..where((t) => t.balanceDue.isBiggerThan(const Constant(0.0)))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]);
          
        if (purchaseOrderId != null) {
          query = _db.select(_db.purchaseOrders)
            ..where((t) => t.id.equals(purchaseOrderId))
            ..where((t) => t.balanceDue.isBiggerThan(const Constant(0.0)));
        }

        final outstandingPOs = await query.get();
        double remainingToApply = amount;

        // 3. Apply FIFO
        for (final po in outstandingPOs) {
          if (remainingToApply <= 0) break;

          final applyToThisPO = remainingToApply >= po.balanceDue ? po.balanceDue : remainingToApply;
          final newPaid = po.amountPaid + applyToThisPO;
          final newBalance = po.balanceDue - applyToThisPO;

          await (_db.update(_db.purchaseOrders)..where((t) => t.id.equals(po.id))).write(
            PurchaseOrdersCompanion(
              amountPaid: Value(newPaid),
              balanceDue: Value(newBalance),
            )
          );

          remainingToApply -= applyToThisPO;
        }

        // 4. Record the payment
        await _db.into(_db.supplierPayments).insert(
          SupplierPaymentsCompanion.insert(
            id: _uuid.v4(),
            supplierId: supplierId,
            purchaseOrderId: Value(purchaseOrderId),
            amount: amount,
            paymentMethod: method,
            notes: Value(notes),
          )
        );

        // 5. Activity Log
        final currentBranchRes = await _settings.getCurrentBranchId();
        final currentBranchId = currentBranchRes.isRight() ? currentBranchRes.getRight().toNullable() : null;

        await _activityLogRepository.logAction(
          actionType: ActivityActionType.supplier_payment,
          description: 'Recorded payment of $amount to supplier $supplierId',
          staffId: _currentStaffId,
          branchId: currentBranchId,
        );

        return const Right(null);
      });
    } catch (e, st) {
      return Left(Failure('Failed to record supplier payment', error: e, stackTrace: st));
    }
  }
}
