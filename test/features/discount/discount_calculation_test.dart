import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/core/database/tables.dart' show DiscountScope, DiscountType, ItemCategory;
import 'package:pos_system/features/billing/domain/cart_item.dart';
import 'package:pos_system/features/discount/domain/discount_calculator.dart';
import 'package:pos_system/features/discount/domain/discount_rule.dart';

void main() {
  group('Discount Calculation Logic', () {
    final now = DateTime.now();
    final rulePercentage = DiscountRule(
      id: 'r1',
      name: 'Percentage Rule',
      type: DiscountType.percentage,
      value: 10.0, // 10%
      scope: DiscountScope.entireSale,
      isActive: true,
      createdAt: now,
    );
    
    final ruleFixed = DiscountRule(
      id: 'r2',
      name: 'Fixed Rule',
      type: DiscountType.fixedAmount,
      value: 50.0, // 50 LKR
      scope: DiscountScope.entireSale,
      isActive: true,
      createdAt: now,
    );

    final cart = [
      CartItem(itemId: 'i1', itemName: 'Item 1', unitPrice: 100.0, quantity: 2, maxQuantity: 10, isSerialized: false, category: ItemCategory.accessory),
      CartItem(itemId: 'i2', itemName: 'Item 2', unitPrice: 200.0, quantity: 1, maxQuantity: 10, isSerialized: false, category: ItemCategory.phone),
    ];
    final subtotal = 400.0; // (100 * 2) + 200

    test('Percentage calculation on entire sale', () {
      final discount = DiscountCalculator.calculateDiscountAmount(rule: rulePercentage, cart: cart, subtotal: subtotal);
      expect(discount, equals(40.0)); // 10% of 400
    });

    test('Fixed amount calculation on entire sale', () {
      final discount = DiscountCalculator.calculateDiscountAmount(rule: ruleFixed, cart: cart, subtotal: subtotal);
      expect(discount, equals(50.0));
    });

    test('Percentage calculation on specific category', () {
      final catRule = DiscountRule(
        id: 'r3',
        name: 'Cat Rule',
        type: DiscountType.percentage,
        value: 15.0, // 15%
        scope: DiscountScope.specificCategory,
        scopeReference: 'accessory',
        isActive: true,
        createdAt: now,
      );
      final discount = DiscountCalculator.calculateDiscountAmount(rule: catRule, cart: cart, subtotal: subtotal);
      // Accessory total = 200. 15% of 200 = 30
      expect(discount, equals(30.0));
    });

    test('Fixed calculation on specific item', () {
      final itemRule = DiscountRule(
        id: 'r4',
        name: 'Item Rule',
        type: DiscountType.fixedAmount,
        value: 200.0,
        scope: DiscountScope.specificItem,
        scopeReference: 'i2',
        isActive: true,
        createdAt: now,
      );
      final discount = DiscountCalculator.calculateDiscountAmount(rule: itemRule, cart: cart, subtotal: subtotal);
      // i2 total = 200. Fixed = 200.
      expect(discount, equals(200.0));
    });

    test('Discount does not exceed applicable amount', () {
      final crazyRule = DiscountRule(
        id: 'r5',
        name: 'Crazy Rule',
        type: DiscountType.fixedAmount,
        value: 1000.0,
        scope: DiscountScope.entireSale,
        isActive: true,
        createdAt: now,
      );
      final discount = DiscountCalculator.calculateDiscountAmount(rule: crazyRule, cart: cart, subtotal: subtotal);
      // Subtotal is 400, so discount caps at 400
      expect(discount, equals(400.0));
    });
  });

  group('Discount Validity Logic', () {
    final now = DateTime.now();
    final pastDate = now.subtract(const Duration(days: 5));
    final futureDate = now.add(const Duration(days: 5));

    final cart = [
      CartItem(itemId: 'i1', itemName: 'Item 1', unitPrice: 100.0, quantity: 1, maxQuantity: 10, isSerialized: false, category: ItemCategory.other),
    ];
    final subtotal = 100.0;

    test('Inactive rule is skipped', () {
      final rule = DiscountRule(
        id: 'r1', name: 'Rule', type: DiscountType.percentage, value: 10, scope: DiscountScope.entireSale, isActive: false, createdAt: now,
      );
      final applicable = DiscountCalculator.getApplicableRules(activeRules: [rule], cart: cart, subtotal: subtotal);
      expect(applicable, isEmpty);
    });

    test('Date range checking', () {
      // Valid range
      final validRule = DiscountRule(
        id: '1', name: 'R', type: DiscountType.percentage, value: 10, scope: DiscountScope.entireSale, isActive: true, createdAt: now,
        startDate: pastDate, endDate: futureDate,
      );
      // Future range
      final futureRule = DiscountRule(
        id: '2', name: 'R', type: DiscountType.percentage, value: 10, scope: DiscountScope.entireSale, isActive: true, createdAt: now,
        startDate: futureDate,
      );
      // Past range
      final pastRule = DiscountRule(
        id: '3', name: 'R', type: DiscountType.percentage, value: 10, scope: DiscountScope.entireSale, isActive: true, createdAt: now,
        endDate: pastDate,
      );

      expect(DiscountCalculator.getApplicableRules(activeRules: [validRule], cart: cart, subtotal: subtotal), isNotEmpty);
      expect(DiscountCalculator.getApplicableRules(activeRules: [futureRule], cart: cart, subtotal: subtotal), isEmpty);
      expect(DiscountCalculator.getApplicableRules(activeRules: [pastRule], cart: cart, subtotal: subtotal), isEmpty);
    });

    test('Minimum purchase amount checking', () {
      final minRule = DiscountRule(
        id: '1', name: 'R', type: DiscountType.percentage, value: 10, scope: DiscountScope.entireSale, isActive: true, createdAt: now,
        minPurchaseAmount: 150.0,
      );
      
      expect(DiscountCalculator.getApplicableRules(activeRules: [minRule], cart: cart, subtotal: 100.0), isEmpty);
      expect(DiscountCalculator.getApplicableRules(activeRules: [minRule], cart: cart, subtotal: 150.0), isNotEmpty);
      expect(DiscountCalculator.getApplicableRules(activeRules: [minRule], cart: cart, subtotal: 200.0), isNotEmpty);
    });

    test('Scope checking', () {
      final categoryRule = DiscountRule(
        id: '1', name: 'R', type: DiscountType.percentage, value: 10, scope: DiscountScope.specificCategory, scopeReference: 'accessory', isActive: true, createdAt: now,
      );
      final itemRule = DiscountRule(
        id: '2', name: 'R', type: DiscountType.percentage, value: 10, scope: DiscountScope.specificItem, scopeReference: 'i2', isActive: true, createdAt: now,
      );
      
      // Cart only has ItemCategory.other with id i1
      expect(DiscountCalculator.getApplicableRules(activeRules: [categoryRule], cart: cart, subtotal: subtotal), isEmpty);
      expect(DiscountCalculator.getApplicableRules(activeRules: [itemRule], cart: cart, subtotal: subtotal), isEmpty);
      
      // Add matching items
      final mixedCart = [
        ...cart,
        CartItem(itemId: 'i2', itemName: 'Item 2', unitPrice: 100.0, quantity: 1, maxQuantity: 10, isSerialized: false, category: ItemCategory.accessory),
      ];
      expect(DiscountCalculator.getApplicableRules(activeRules: [categoryRule], cart: mixedCart, subtotal: subtotal), isNotEmpty);
      expect(DiscountCalculator.getApplicableRules(activeRules: [itemRule], cart: mixedCart, subtotal: subtotal), isNotEmpty);
    });
  });
}
