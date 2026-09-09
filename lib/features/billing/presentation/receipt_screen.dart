import 'package:flutter/material.dart';
import 'package:pos_system/features/billing/domain/receipt_printer.dart';
import 'package:pos_system/features/billing/domain/sale.dart';
import 'package:pos_system/core/database/tables.dart';

class ReceiptScreen extends StatelessWidget {
  final Sale sale;
  final ReceiptPrinter _printer = LoggingReceiptPrinter();

  ReceiptScreen({super.key, required this.sale});

  void _printReceipt(BuildContext context) async {
    await _printer.printReceipt(sale);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt sent to printer')));
    }
  }

  @override
  Widget build(BuildContext context) {
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('STORE NAME', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Receipt #: ${sale.id.substring(0, 8).toUpperCase()}', textAlign: TextAlign.center),
                  Text('Date: ${sale.createdAt.toString().split('.')[0]}', textAlign: TextAlign.center),
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
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => _printReceipt(context),
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
    );
  }
}
