import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/features/billing/domain/payment_calculator.dart';

void main() {
  group('Cash Payment Change Calculation', () {
    test('Amount tendered >= total -> change = tendered - total', () {
      final result = PaymentCalculator.calculateCashChange(
        total: 1000.0,
        amountTendered: 1500.0,
      );

      expect(result.isValid, isTrue);
      expect(result.changeDue, equals(500.0));
      expect(result.errorMessage, isNull);
    });

    test('Amount tendered < total -> should be rejected/flagged as invalid (not a negative change)', () {
      final result = PaymentCalculator.calculateCashChange(
        total: 1000.0,
        amountTendered: 900.0,
      );

      expect(result.isValid, isFalse);
      expect(result.changeDue, isNull);
      expect(result.errorMessage, equals('Amount tendered must be greater than or equal to total'));
    });

    test('Amount tendered == total exactly -> change = 0', () {
      final result = PaymentCalculator.calculateCashChange(
        total: 1000.0,
        amountTendered: 1000.0,
      );

      expect(result.isValid, isTrue);
      expect(result.changeDue, equals(0.0));
    });

    test('Null amount tendered -> should be rejected', () {
      final result = PaymentCalculator.calculateCashChange(
        total: 1000.0,
        amountTendered: null,
      );

      expect(result.isValid, isFalse);
      expect(result.changeDue, isNull);
      expect(result.errorMessage, equals('Amount tendered must be greater than or equal to total'));
    });
  });
}
