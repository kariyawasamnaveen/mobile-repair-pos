import 'dart:developer' as developer;
import 'package:pos_system/features/billing/domain/sale.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/features/billing/presentation/receipt_screen.dart' show receiptFooterPolicy, receiptFooterGreeting;

abstract class ReceiptPrinter {
  Future<void> printReceipt(Sale sale, {String? storeName, String? storeAddress, String? storePhone});
}

class LoggingReceiptPrinter implements ReceiptPrinter {
  @override
  Future<void> printReceipt(Sale sale, {String? storeName, String? storeAddress, String? storePhone}) async {
    final buffer = StringBuffer();
    buffer.writeln('=== RECEIPT ===');
    buffer.writeln(storeName ?? 'STORE NAME');
    if (storeAddress != null && storeAddress.isNotEmpty) buffer.writeln(storeAddress);
    if (storePhone != null && storePhone.isNotEmpty) buffer.writeln(storePhone);
    
    buffer.writeln('Sale ID: ${sale.id}');
    if (sale.cashierName != null) buffer.writeln('Served by: ${sale.cashierName}');
    buffer.writeln('Customer: ${sale.customerName ?? 'Walk-in'}');
    buffer.writeln('----------------');
    for (final item in sale.items) {
      buffer.writeln('${item.itemName} x${item.quantitySold} @ ${item.unitPriceAtSale}');
      if (item.imeiSold != null) {
        buffer.writeln('  IMEI: ${item.imeiSold}');
      }
    }
    buffer.writeln('----------------');
    buffer.writeln('Subtotal: ${sale.subtotal}');
    if (sale.discount > 0) {
      if (sale.appliedDiscountRuleName != null && sale.appliedDiscountRuleName!.isNotEmpty) {
        buffer.writeln('Discount (${sale.appliedDiscountRuleName}): -${sale.discount}');
      } else {
        buffer.writeln('Discount: -${sale.discount}');
      }
    }
    buffer.writeln('Total: ${sale.total}');
    buffer.writeln('Payment: ${sale.paymentMethod.name}');
    if (sale.paymentMethod == PaymentMethod.cash && sale.amountTendered != null) {
      buffer.writeln('Amount Tendered: ${sale.amountTendered}');
      buffer.writeln('Change Due: ${sale.changeDue}');
    }
    if (sale.isCreditSale) {
      buffer.writeln('Paid: ${sale.amountPaid}');
      buffer.writeln('Balance Due: ${sale.balanceDue}');
    }
    buffer.writeln('----------------');
    buffer.writeln(receiptFooterPolicy);
    buffer.writeln(receiptFooterGreeting);
    buffer.writeln('================');

    developer.log(buffer.toString(), name: 'ReceiptPrinter');
  }
}
