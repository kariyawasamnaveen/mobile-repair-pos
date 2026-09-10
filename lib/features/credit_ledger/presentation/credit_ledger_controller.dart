import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pos_system/core/error/failure.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/features/credit_ledger/data/credit_ledger_repository.dart';
import 'package:pos_system/features/credit_ledger/domain/credit_ledger_models.dart';

// ── Customer ledger list ─────────────────────────────────────────────────────

final customerLedgerProvider =
    StateNotifierProvider<CustomerLedgerNotifier, AsyncValue<List<CustomerBalance>>>(
  (ref) => CustomerLedgerNotifier(ref.watch(creditLedgerRepositoryProvider)),
);

class CustomerLedgerNotifier
    extends StateNotifier<AsyncValue<List<CustomerBalance>>> {
  final CreditLedgerRepository _repository;

  CustomerLedgerNotifier(this._repository) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    final result = await _repository.getOutstandingCustomers();
    result.match(
      (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
      (customers) => state = AsyncValue.data(customers),
    );
  }
}

// ── Customer detail (sales + payments for one customer) ─────────────────────

class CustomerDetailState {
  final AsyncValue<List<CreditSaleSummary>> sales;
  final AsyncValue<List<CreditPayment>> payments;

  const CustomerDetailState({
    required this.sales,
    required this.payments,
  });

  CustomerDetailState copyWith({
    AsyncValue<List<CreditSaleSummary>>? sales,
    AsyncValue<List<CreditPayment>>? payments,
  }) {
    return CustomerDetailState(
      sales: sales ?? this.sales,
      payments: payments ?? this.payments,
    );
  }
}

final customerDetailProvider = StateNotifierProvider.family<
    CustomerDetailNotifier, CustomerDetailState, String>(
  (ref, customerPhone) => CustomerDetailNotifier(
    ref.watch(creditLedgerRepositoryProvider),
    customerPhone,
  ),
);

class CustomerDetailNotifier extends StateNotifier<CustomerDetailState> {
  final CreditLedgerRepository _repository;
  final String _customerPhone;

  CustomerDetailNotifier(this._repository, this._customerPhone)
      : super(const CustomerDetailState(
          sales: AsyncValue.loading(),
          payments: AsyncValue.loading(),
        )) {
    load();
  }

  Future<void> load() async {
    state = const CustomerDetailState(
      sales: AsyncValue.loading(),
      payments: AsyncValue.loading(),
    );

    final salesResult = await _repository.getSalesForCustomer(_customerPhone);
    salesResult.match(
      (f) => state = state.copyWith(sales: AsyncValue.error(f.message, StackTrace.current)),
      (sales) => state = state.copyWith(sales: AsyncValue.data(sales)),
    );

    final paymentsResult = await _repository.getPaymentsForCustomer(_customerPhone);
    paymentsResult.match(
      (f) => state = state.copyWith(payments: AsyncValue.error(f.message, StackTrace.current)),
      (payments) => state = state.copyWith(payments: AsyncValue.data(payments)),
    );
  }

  /// Records a payment and refreshes both lists + the parent ledger list.
  Future<Either<Failure, void>> recordPayment({
    required String customerPhone,
    String? targetSaleId,
    required double amount,
    required CreditPaymentMethod paymentMethod,
    String? notes,
    required void Function() onSuccess,
  }) async {
    final result = await _repository.recordPayment(
      customerPhone: customerPhone,
      targetSaleId: targetSaleId,
      amount: amount,
      paymentMethod: paymentMethod,
      notes: notes,
    );
    if (result.isRight()) {
      load();
      onSuccess();
    }
    return result.map((_) {});
  }
}
