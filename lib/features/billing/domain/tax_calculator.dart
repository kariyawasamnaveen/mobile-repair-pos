class TaxCalculationResult {
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double total;

  TaxCalculationResult({
    required this.subtotal,
    required this.discount,
    required this.taxAmount,
    required this.total,
  });
}

class TaxCalculator {
  static TaxCalculationResult calculate({
    required double subtotal,
    required double discount,
    required double taxRate,
    required bool isTaxEnabled,
    required bool isTaxInclusive,
  }) {
    double discountedSubtotal = subtotal - discount;
    if (discountedSubtotal < 0) discountedSubtotal = 0;

    if (!isTaxEnabled || taxRate <= 0) {
      return TaxCalculationResult(
        subtotal: subtotal,
        discount: discount,
        taxAmount: 0.0,
        total: discountedSubtotal,
      );
    }

    double taxAmount = 0.0;
    double total = discountedSubtotal;

    if (isTaxInclusive) {
      taxAmount = total - (total / (1 + taxRate / 100));
    } else {
      taxAmount = total * (taxRate / 100);
      total += taxAmount;
    }

    return TaxCalculationResult(
      subtotal: subtotal,
      discount: discount,
      taxAmount: taxAmount,
      total: total,
    );
  }
}
