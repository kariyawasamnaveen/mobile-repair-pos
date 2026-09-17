import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/billing/domain/sale.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/features/settings/presentation/settings_controller.dart';
import 'package:pos_system/core/sms/sms_gateway.dart';
import 'package:pos_system/features/billing/domain/sms_receipt_generator.dart';
import 'package:pos_system/features/billing/domain/pdf_receipt_generator.dart';
import 'package:printing/printing.dart';

const String receiptFooterPolicy = "Items eligible for exchange within 7 days with this receipt";
const String receiptFooterGreeting = "Thank you, visit again!";

class ReceiptScreen extends ConsumerStatefulWidget {
  final Sale sale;
  const ReceiptScreen({super.key, required this.sale});

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  late final TextEditingController _phoneController;
  bool _isSendingSms = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.sale.customerPhone ?? '');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  int _calculateSmsPages(int charCount, bool hasUnicode) {
    if (charCount == 0) return 0;
    if (hasUnicode) {
      if (charCount <= 70) return 1;
      return (charCount / 67).ceil();
    } else {
      if (charCount <= 160) return 1;
      return (charCount / 153).ceil();
    }
  }

  bool _containsUnicode(String text) {
    for (int i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) > 127) return true;
    }
    return false;
  }

  void _printReceipt(BuildContext context, StoreSettings? settings) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final generator = PdfReceiptGenerator();
    final result = await generator.generateReceipt(widget.sale, settings);
    
    if (mounted) {
      result.fold(
        (failure) {
          scaffoldMessenger.showSnackBar(SnackBar(content: Text(failure.message), backgroundColor: Colors.red));
        },
        (bytes) async {
          try {
            await Printing.layoutPdf(
              onLayout: (_) => bytes,
              name: 'Receipt_${widget.sale.id.substring(0, 8)}.pdf',
            );
          } catch (e) {
            if (mounted) {
              scaffoldMessenger.showSnackBar(const SnackBar(content: Text('No printer found - check your printer is connected'), backgroundColor: Colors.red));
            }
          }
        },
      );
    }
  }

  Future<void> _sendSmsReceipt(BuildContext context, StoreSettings? settings) async {
    final phone = _phoneController.text.trim();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (phone.isEmpty) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Please enter a phone number')));
      return;
    }

    setState(() => _isSendingSms = true);
    
    final message = SmsReceiptGenerator.generateReceiptMessage(widget.sale, settings);
    final gateway = ref.read(smsGatewayProvider);
    
    final result = await gateway.sendSms(toPhone: phone, message: message);
    
    if (mounted) {
      setState(() => _isSendingSms = false);
      result.fold(
        (failure) {
          scaffoldMessenger.showSnackBar(SnackBar(content: Text('Failed to send SMS: ${failure.message}'), backgroundColor: Colors.red));
        },
        (_) {
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('SMS Receipt sent successfully!'), backgroundColor: Colors.green));
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(storeSettingsProvider).valueOrNull;
    final message = SmsReceiptGenerator.generateReceiptMessage(widget.sale, settings);
    final charCount = message.length;
    final hasUnicode = _containsUnicode(message);
    final pageCount = _calculateSmsPages(charCount, hasUnicode);

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
                    Text('Receipt #: ${widget.sale.id.substring(0, 8).toUpperCase()}', textAlign: TextAlign.center),
                    Text('Date: ${widget.sale.createdAt.toString().split('.')[0]}', textAlign: TextAlign.center),
                    if (widget.sale.cashierName != null) Text('Served by: ${widget.sale.cashierName}', textAlign: TextAlign.center),
                    if (widget.sale.customerName != null) Text('Customer: ${widget.sale.customerName}', textAlign: TextAlign.center),
                    const Divider(height: 32),
                    ...widget.sale.items.map((item) => Padding(
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
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal'), Text('${widget.sale.subtotal}')]),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Discount'), Text('${widget.sale.discount}')]),
                    if (widget.sale.taxAmount != null)
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Tax (${widget.sale.taxRateApplied}%)'), Text(widget.sale.taxAmount!.toStringAsFixed(2))]),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text('${widget.sale.total}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
                    const SizedBox(height: 16),
                    Text('Payment: ${widget.sale.paymentMethod.name.toUpperCase()}', textAlign: TextAlign.right),
                    if (widget.sale.paymentMethod == PaymentMethod.cash && widget.sale.amountTendered != null) ...[
                      Text('Amount Tendered: ${widget.sale.amountTendered}', textAlign: TextAlign.right),
                      Text('Change Due: ${widget.sale.changeDue}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                    if (widget.sale.isCreditSale) ...[
                      Text('Paid: ${widget.sale.amountPaid}', textAlign: TextAlign.right),
                      Text('Balance Due: ${widget.sale.balanceDue}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                    const Divider(height: 32),
                    const Text(receiptFooterPolicy, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 4),
                    const Text(receiptFooterGreeting, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 32),
                    
                    if (settings?.defaultReceiptDelivery == 'print' || settings?.defaultReceiptDelivery == 'ask') ...[
                      ElevatedButton.icon(
                        onPressed: () => _printReceipt(context, settings),
                        icon: const Icon(Icons.print),
                        label: const Text('PRINT RECEIPT'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('SMS Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Customer Phone',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.phone),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Length: $charCount chars (~$pageCount SMS page${pageCount > 1 ? 's' : ''})',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _isSendingSms ? null : () => _sendSmsReceipt(context, settings),
                              icon: _isSendingSms ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sms),
                              label: const Text('SEND SMS RECEIPT'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (settings?.defaultReceiptDelivery == 'sms') ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _printReceipt(context, settings),
                        icon: const Icon(Icons.print),
                        label: const Text('PRINT INSTEAD'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                      ),
                    ],
                    const SizedBox(height: 32),

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
