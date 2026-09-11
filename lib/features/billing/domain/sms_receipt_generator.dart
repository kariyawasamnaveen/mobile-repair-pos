import 'package:pos_system/features/billing/domain/sale.dart';
import 'package:pos_system/features/settings/presentation/settings_controller.dart';
import 'package:pos_system/core/database/tables.dart';

class SmsReceiptGenerator {
  static String generateReceiptMessage(Sale sale, StoreSettings? settings) {
    final storeName = settings?.name ?? 'Our Store';
    final storePhone = settings?.phone;
    final shortId = sale.id.substring(0, 8).toUpperCase();
    final date = sale.createdAt.toString().split('.')[0];
    
    final buffer = StringBuffer();
    buffer.writeln(storeName);
    if (storePhone != null && storePhone.isNotEmpty) {
      buffer.writeln('Tel: $storePhone');
    }
    buffer.writeln('Receipt: $shortId');
    buffer.writeln('Date: $date');
    buffer.writeln('Items:');
    
    // List itemized items (up to 3 to save space)
    final maxItems = 3;
    for (var i = 0; i < sale.items.length; i++) {
      if (i >= maxItems) {
        final remaining = sale.items.length - maxItems;
        buffer.writeln('(+ $remaining more items)');
        break;
      }
      final item = sale.items[i];
      buffer.writeln('${item.itemName} x${item.quantitySold} - LKR ${item.unitPriceAtSale}');
    }
    
    if (sale.taxAmount != null) {
      final taxName = settings?.taxName ?? 'Tax';
      buffer.writeln('$taxName: LKR ${sale.taxAmount!.toStringAsFixed(2)}');
    }
    
    if (sale.isCreditSale) {
      buffer.writeln('Total: LKR ${sale.total}');
      buffer.writeln('Paid Now: LKR ${sale.amountPaid.toStringAsFixed(2)}');
      buffer.writeln('Balance Due: LKR ${sale.balanceDue.toStringAsFixed(2)}');
    } else {
      buffer.writeln('Total: LKR ${sale.total} (${sale.paymentMethod.name.toUpperCase()})');
      if (sale.paymentMethod == PaymentMethod.cash && sale.changeDue != null && sale.changeDue! > 0) {
        buffer.writeln('Change: LKR ${sale.changeDue}');
      }
    }
    
    buffer.write('Thank you!');
    return buffer.toString();
  }
}
