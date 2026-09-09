import 'package:pos_system/core/database/tables.dart';

class SaleItem {
  final String itemId;
  final String itemName;
  final int quantitySold;
  final double unitPriceAtSale;
  final String? imeiSold;

  const SaleItem({
    required this.itemId,
    required this.itemName,
    required this.quantitySold,
    required this.unitPriceAtSale,
    this.imeiSold,
  });
}

class Sale {
  final String id;
  final String? customerName;
  final String? customerPhone;
  final double subtotal;
  final double discount;
  final double total;
  final PaymentMethod paymentMethod;
  final bool isCreditSale;
  final double amountPaid;
  final double balanceDue;
  final double? amountTendered;
  final double? changeDue;
  final DateTime createdAt;
  final List<SaleItem> items;

  const Sale({
    required this.id,
    this.customerName,
    this.customerPhone,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paymentMethod,
    required this.isCreditSale,
    required this.amountPaid,
    required this.balanceDue,
    this.amountTendered,
    this.changeDue,
    required this.createdAt,
    required this.items,
  });
}
