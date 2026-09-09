import 'package:flutter/foundation.dart';
import 'package:pos_system/features/billing/domain/sale.dart';
import 'package:pos_system/core/database/tables.dart';

abstract class ReceiptPrinter {
  Future<void> printReceipt(Sale sale);
}

class LoggingReceiptPrinter implements ReceiptPrinter {
  @override
  Future<void> printReceipt(Sale sale) async {
    debugPrint('=== RECEIPT ===');
    debugPrint('Sale ID: ${sale.id}');
    debugPrint('Customer: ${sale.customerName ?? 'Walk-in'}');
    debugPrint('----------------');
    for (final item in sale.items) {
      debugPrint('${item.itemName} x${item.quantitySold} @ ${item.unitPriceAtSale}');
      if (item.imeiSold != null) {
        debugPrint('  IMEI: ${item.imeiSold}');
      }
    }
    debugPrint('----------------');
    debugPrint('Subtotal: ${sale.subtotal}');
    debugPrint('Discount: ${sale.discount}');
    debugPrint('Total: ${sale.total}');
    debugPrint('Payment: ${sale.paymentMethod.name}');
    if (sale.paymentMethod == PaymentMethod.cash && sale.amountTendered != null) {
      debugPrint('Amount Tendered: ${sale.amountTendered}');
      debugPrint('Change Due: ${sale.changeDue}');
    }
    if (sale.isCreditSale) {
      debugPrint('Paid: ${sale.amountPaid}');
      debugPrint('Balance Due: ${sale.balanceDue}');
    }
    debugPrint('================');
  }
}
