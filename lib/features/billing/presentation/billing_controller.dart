import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/features/billing/data/billing_repository.dart';
import 'package:pos_system/features/billing/domain/cart_item.dart';
import 'package:pos_system/features/billing/domain/tax_calculator.dart';
import 'package:pos_system/features/billing/domain/payment_calculator.dart';
import 'package:pos_system/features/billing/domain/sale.dart';
import 'package:pos_system/features/inventory/domain/item.dart';
import 'package:pos_system/features/inventory/presentation/inventory_controller.dart';
import 'package:pos_system/features/auth/presentation/auth_controller.dart';
import 'package:pos_system/features/settings/presentation/settings_controller.dart';

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void clear() => state = [];

  void addItem(Item item, {String? imei}) {
    final existingIndex = state.indexWhere((c) => c.itemId == item.id);
    final isSerialized = item.category == ItemCategory.phone;

    if (existingIndex >= 0) {
      final existing = state[existingIndex];
      if (isSerialized && imei != null) {
        if (existing.selectedImeis.contains(imei)) return; // Already in cart
        if (existing.selectedImeis.length >= item.quantity) return; // Stock limit
        
        final updatedImeis = List<String>.from(existing.selectedImeis)..add(imei);
        final updatedItem = existing.copyWith(
          quantity: updatedImeis.length,
          selectedImeis: updatedImeis,
        );
        state = [
          ...state.sublist(0, existingIndex),
          updatedItem,
          ...state.sublist(existingIndex + 1),
        ];
      } else {
        if (existing.quantity >= item.quantity) return; // Stock limit
        
        final updatedItem = existing.copyWith(quantity: existing.quantity + 1);
        state = [
          ...state.sublist(0, existingIndex),
          updatedItem,
          ...state.sublist(existingIndex + 1),
        ];
      }
    } else {
      state = [
        ...state,
        CartItem(
          itemId: item.id,
          itemName: item.name,
          barcode: item.barcode,
          unitPrice: item.sellingPrice,
          maxQuantity: item.quantity,
          isSerialized: isSerialized,
          quantity: isSerialized ? 1 : 1,
          selectedImeis: isSerialized && imei != null ? [imei] : [],
        )
      ];
    }
  }

  void updateQuantity(String itemId, int quantity) {
    final existingIndex = state.indexWhere((c) => c.itemId == itemId);
    if (existingIndex >= 0) {
      final existing = state[existingIndex];
      if (existing.isSerialized) return; // Serialized quantities are managed via IMEIs
      if (quantity <= 0) {
        removeItem(itemId);
        return;
      }
      if (quantity > existing.maxQuantity) return; // Stock limit
      
      final updatedItem = existing.copyWith(quantity: quantity);
      state = [
        ...state.sublist(0, existingIndex),
        updatedItem,
        ...state.sublist(existingIndex + 1),
      ];
    }
  }

  void removeImei(String itemId, String imei) {
    final existingIndex = state.indexWhere((c) => c.itemId == itemId);
    if (existingIndex >= 0) {
      final existing = state[existingIndex];
      final updatedImeis = List<String>.from(existing.selectedImeis)..remove(imei);
      if (updatedImeis.isEmpty) {
        removeItem(itemId);
      } else {
        final updatedItem = existing.copyWith(
          quantity: updatedImeis.length,
          selectedImeis: updatedImeis,
        );
        state = [
          ...state.sublist(0, existingIndex),
          updatedItem,
          ...state.sublist(existingIndex + 1),
        ];
      }
    }
  }

  void removeItem(String itemId) {
    state = state.where((c) => c.itemId != itemId).toList();
  }

  double get subtotal => state.fold(0, (sum, item) => sum + item.total);
}

final discountProvider = StateProvider<double>((ref) => 0.0);

final checkoutControllerProvider = Provider<CheckoutController>((ref) {
  return CheckoutController(ref);
});

class CheckoutController {
  final Ref _ref;
  CheckoutController(this._ref);

  Future<Either<String, Sale>> processCheckout({
    required PaymentMethod paymentMethod,
    String? customerName,
    String? customerPhone,
    String? cashierName,
    bool isCreditSale = false,
    double amountPaid = 0.0,
    double? amountTendered,
  }) async {
    final cart = _ref.read(cartProvider);
    if (cart.isEmpty) return const Left('Cart is empty');

    final subtotal = _ref.read(cartProvider.notifier).subtotal;
    final discount = _ref.read(discountProvider);
    
    final settings = _ref.read(storeSettingsProvider).valueOrNull;
    final isTaxEnabled = settings?.isTaxEnabled ?? false;
    final taxRate = settings?.taxRate ?? 0.0;
    final isTaxInclusive = settings?.isTaxInclusive ?? false;

    double total = subtotal - discount;
    final taxResult = TaxCalculator.calculate(
      subtotal: subtotal,
      discount: discount,
      taxRate: taxRate,
      isTaxEnabled: isTaxEnabled,
      isTaxInclusive: isTaxInclusive,
    );

    final double? taxAmount = isTaxEnabled && taxRate > 0 ? taxResult.taxAmount : null;
    final double? taxRateApplied = isTaxEnabled && taxRate > 0 ? taxRate : null;
    total = taxResult.total;

    final balanceDue = isCreditSale ? total - amountPaid : 0.0;
    
    double? changeDue;
    if (paymentMethod == PaymentMethod.cash) {
      final paymentResult = PaymentCalculator.calculateCashChange(
        total: total,
        amountTendered: amountTendered,
      );
      if (!paymentResult.isValid) {
        return Left(paymentResult.errorMessage!);
      }
      changeDue = paymentResult.changeDue;
    }

    final repo = _ref.read(billingRepositoryProvider);
    final result = await repo.processSale(
      cart: cart,
      subtotal: subtotal,
      discount: discount,
      taxAmount: taxAmount,
      taxRateApplied: taxRateApplied,
      total: total,
      paymentMethod: paymentMethod,
      customerName: customerName,
      customerPhone: customerPhone,
      isCreditSale: isCreditSale,
      amountPaid: amountPaid,
      balanceDue: balanceDue,
      amountTendered: paymentMethod == PaymentMethod.cash ? amountTendered : null,
      changeDue: changeDue,
      cashierName: cashierName,
      staffId: _ref.read(authStateProvider)?.id,
    );

    return result.match(
      (failure) => Left(failure.message),
      (sale) {
        _ref.read(cartProvider.notifier).clear();
        _ref.read(discountProvider.notifier).state = 0.0;
        _ref.read(inventoryControllerProvider.notifier).loadItems();
        return Right(sale);
      },
    );
  }
}

final salesHistoryProvider = StateNotifierProvider<SalesHistoryNotifier, AsyncValue<List<Sale>>>((ref) {
  return SalesHistoryNotifier(ref.watch(billingRepositoryProvider));
});

class SalesHistoryNotifier extends StateNotifier<AsyncValue<List<Sale>>> {
  final BillingRepository _repository;

  SalesHistoryNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadSales();
  }

  Future<void> loadSales({DateTime? startDate, DateTime? endDate}) async {
    state = const AsyncValue.loading();
    final result = await _repository.getSalesHistory(startDate: startDate, endDate: endDate);
    result.match(
      (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
      (sales) => state = AsyncValue.data(sales),
    );
  }
}
