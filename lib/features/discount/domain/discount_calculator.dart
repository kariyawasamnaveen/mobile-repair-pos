import 'package:pos_system/core/database/tables.dart' show DiscountType, DiscountScope;
import 'package:pos_system/features/billing/domain/cart_item.dart';
import 'package:pos_system/features/discount/domain/discount_rule.dart';

class DiscountCalculator {
  /// Evaluates a list of rules against the current cart and subtotal,
  /// returning only the rules that are valid and applicable.
  static List<DiscountRule> getApplicableRules({
    required List<DiscountRule> activeRules,
    required List<CartItem> cart,
    required double subtotal,
  }) {
    final now = DateTime.now();
    return activeRules.where((rule) {
      if (!rule.isActive) return false;
      if (!rule.isValidForDate(now)) return false;
      if (rule.minPurchaseAmount != null && subtotal < rule.minPurchaseAmount!) return false;

      switch (rule.scope) {
        case DiscountScope.entireSale:
          return true;
        case DiscountScope.specificCategory:
          if (rule.scopeReference == null) return false;
          return cart.any((item) => item.category?.name == rule.scopeReference);
        case DiscountScope.specificItem:
          if (rule.scopeReference == null) return false;
          return cart.any((item) => item.itemId == rule.scopeReference);
      }
    }).toList();
  }

  /// Calculates the discount amount for a single applicable rule against the cart.
  static double calculateDiscountAmount({
    required DiscountRule rule,
    required List<CartItem> cart,
    required double subtotal,
  }) {
    double applicableAmount = 0.0;

    switch (rule.scope) {
      case DiscountScope.entireSale:
        applicableAmount = subtotal;
        break;
      case DiscountScope.specificCategory:
        if (rule.scopeReference != null) {
          applicableAmount = cart
              .where((item) => item.category?.name == rule.scopeReference)
              .fold(0.0, (sum, item) => sum + item.total);
        }
        break;
      case DiscountScope.specificItem:
        if (rule.scopeReference != null) {
          applicableAmount = cart
              .where((item) => item.itemId == rule.scopeReference)
              .fold(0.0, (sum, item) => sum + item.total);
        }
        break;
    }

    if (applicableAmount <= 0) return 0.0;

    switch (rule.type) {
      case DiscountType.percentage:
        // percentage is stored as 0-100, so we divide by 100
        final discount = applicableAmount * (rule.value / 100);
        return discount > applicableAmount ? applicableAmount : discount;
      case DiscountType.fixedAmount:
        // For a fixed amount, we just return the value, capped at the applicable amount
        return rule.value > applicableAmount ? applicableAmount : rule.value;
    }
  }
}
