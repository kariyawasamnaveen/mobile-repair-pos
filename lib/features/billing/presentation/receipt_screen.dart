import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/billing/domain/receipt_printer.dart';
import 'package:pos_system/features/billing/domain/sale.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/features/settings/presentation/settings_controller.dart';

const String receiptFooterPolicy = "Items eligible for exchange within 7 days with this receipt";
const String receiptFooterGreeting = "Thank you, visit again!";

class ReceiptScreen extends ConsumerWidget {
  final Sale sale;
  final ReceiptPrinter _printer = LoggingReceiptPrinter();

  ReceiptScreen({super.key, required this.sale});

  void _printReceipt(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(storeSettingsProvider).valueOrNull;
    // Assuming printer uses the settings internally or we can pass them in future
    await _printer.printReceipt(sale, storeName: settings?.name, storeAddress: settings?.address, storePhone: settings?.phone);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt sent to printer')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(storeSettingsProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(settings?.name ?? 'STORE NAME', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    if (settings?.address != null && settings!.address!.isNotEmpty)
                      Text(settings.address!, textAlign: TextAlign.center),
                    if (settings?.phone != null && settings!.phone!.isNotEmpty)
                      Text(settings.phone!, textAlign: TextAlign.center),
                    
                    const SizedBox(height: 16),
                    Text('Receipt #: ${sale.id.substring(0, 8).toUpperCase()}', textAlign: TextAlign.center),
                    Text('Date: ${sale.createdAt.toString().split('.')[0]}', textAlign: TextAlign.center),
                    if (sale.cashierName != null) Text('Served by: ${sale.cashierName}', textAlign: TextAlign.center),
                    if (sale.customerName != null) Text('Customer: ${sale.customerName}', textAlign: TextAlign.center),
                    const Divider(height: 32),
                    ...sale.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(item.itemName)),
                              Text('${item.quantitySold} x ${item.unitPriceAtSale}'),
                            ],
                          ),
                          if (item.imeiSold != null)
                            Text('IMEI: ${item.imeiSold}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    )),
                    const Divider(height: 32),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal'), Text('${sale.subtotal}')]),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Discount'), Text('${sale.discount}')]),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text('${sale.total}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
                    const SizedBox(height: 16),
                    Text('Payment: ${sale.paymentMethod.name.toUpperCase()}', textAlign: TextAlign.right),
                    if (sale.paymentMethod == PaymentMethod.cash && sale.amountTendered != null) ...[
                      Text('Amount Tendered: ${sale.amountTendered}', textAlign: TextAlign.right),
                      Text('Change Due: ${sale.changeDue}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                    if (sale.isCreditSale) ...[
                      Text('Paid: ${sale.amountPaid}', textAlign: TextAlign.right),
                      Text('Balance Due: ${sale.balanceDue}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                    const Divider(height: 32),
                    const Text(receiptFooterPolicy, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 4),
                    const Text(receiptFooterGreeting, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () => _printReceipt(context, ref),
                      icon: const Icon(Icons.print),
                      label: const Text('PRINT RECEIPT'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
