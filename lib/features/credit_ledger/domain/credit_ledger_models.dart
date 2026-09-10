import 'package:pos_system/core/database/tables.dart';

/// A customer who has one or more outstanding credit sales.
class CustomerBalance {
  final String customerPhone;
  final String? customerName;
  final double totalOutstanding;
  final int unpaidSaleCount;

  const CustomerBalance({
    required this.customerPhone,
    this.customerName,
    required this.totalOutstanding,
    required this.unpaidSaleCount,
  });
}

/// A credit sale summary shown inside a customer's ledger detail.
class CreditSaleSummary {
  final String saleId;
  final double total;
  final double amountPaid;
  final double balanceDue;
  final DateTime createdAt;

  const CreditSaleSummary({
    required this.saleId,
    required this.total,
    required this.amountPaid,
    required this.balanceDue,
    required this.createdAt,
  });

  bool get isSettled => balanceDue <= 0;
}

/// A recorded payment against a customer's credit balance.
class CreditPayment {
  final String id;
  final String customerPhone;
  final String? saleId;
  final double amount;
  final CreditPaymentMethod paymentMethod;
  final DateTime collectedAt;
  final String? notes;

  const CreditPayment({
    required this.id,
    required this.customerPhone,
    this.saleId,
    required this.amount,
    required this.paymentMethod,
    required this.collectedAt,
    this.notes,
  });
}
