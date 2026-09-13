import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/features/billing/domain/tax_calculator.dart';

void main() {
  group('Tax Calculation Logic', () {
    test('Exclusive: given subtotal 1000, discount 0, rate 15% -> tax = 150, total = 1150', () {
      final result = TaxCalculator.calculate(
        subtotal: 1000,
        discount: 0,
        taxRate: 15,
        isTaxEnabled: true,
        isTaxInclusive: false,
      );

      expect(result.taxAmount, closeTo(150.0, 0.01));
      expect(result.total, closeTo(1150.0, 0.01));
    });

    test('Exclusive with discount: subtotal 1000, discount 100, rate 15% -> tax = 135, total = 1035', () {
      final result = TaxCalculator.calculate(
        subtotal: 1000,
        discount: 100,
        taxRate: 15,
        isTaxEnabled: true,
        isTaxInclusive: false,
      );

      expect(result.taxAmount, closeTo(135.0, 0.01));
      expect(result.total, closeTo(1035.0, 0.01));
    });

    test('Inclusive: given total 1000, rate 15% -> tax ≈ 130.43, pre-tax amount ≈ 869.57', () {
      final result = TaxCalculator.calculate(
        subtotal: 1000,
        discount: 0,
        taxRate: 15,
        isTaxEnabled: true,
        isTaxInclusive: true,
      );

      expect(result.taxAmount, closeTo(130.43, 0.01));
      expect(result.total, closeTo(1000.0, 0.01));
    });

    test('Tax disabled: total = subtotal - discount, no tax line', () {
      final result = TaxCalculator.calculate(
        subtotal: 1000,
        discount: 100,
        taxRate: 15,
        isTaxEnabled: false,
        isTaxInclusive: false,
      );

      expect(result.taxAmount, equals(0.0));
      expect(result.total, equals(900.0));
    });

    test('Edge case: 0% rate', () {
      final result = TaxCalculator.calculate(
        subtotal: 1000,
        discount: 100,
        taxRate: 0,
        isTaxEnabled: true,
        isTaxInclusive: false,
      );

      expect(result.taxAmount, equals(0.0));
      expect(result.total, equals(900.0));
    });

    test('Edge case: discount larger than subtotal (should not go negative)', () {
      final result = TaxCalculator.calculate(
        subtotal: 1000,
        discount: 1500,
        taxRate: 15,
        isTaxEnabled: true,
        isTaxInclusive: false,
      );

      expect(result.taxAmount, equals(0.0));
      expect(result.total, equals(0.0));
    });
  });
}
