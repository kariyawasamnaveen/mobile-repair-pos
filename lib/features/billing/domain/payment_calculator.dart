class PaymentCalculationResult {
  final double? changeDue;
  final String? errorMessage;

  PaymentCalculationResult({this.changeDue, this.errorMessage});

  bool get isValid => errorMessage == null;
}

class PaymentCalculator {
  static PaymentCalculationResult calculateCashChange({
    required double total,
    required double? amountTendered,
  }) {
    if (amountTendered == null || amountTendered < total) {
      return PaymentCalculationResult(
        errorMessage: 'Amount tendered must be greater than or equal to total',
      );
    }
    return PaymentCalculationResult(
      changeDue: amountTendered - total,
    );
  }
}
