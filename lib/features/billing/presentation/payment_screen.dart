import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/features/billing/presentation/billing_controller.dart';
import 'package:pos_system/features/billing/presentation/receipt_screen.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _amountPaidController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _amountPaidController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);
    
    final isCredit = _paymentMethod == PaymentMethod.credit;
    final amountPaid = double.tryParse(_amountPaidController.text) ?? 0.0;

    final controller = ref.read(checkoutControllerProvider);
    final result = await controller.processCheckout(
      paymentMethod: _paymentMethod,
      customerName: _customerNameController.text.isNotEmpty ? _customerNameController.text : null,
      customerPhone: _customerPhoneController.text.isNotEmpty ? _customerPhoneController.text : null,
      isCreditSale: isCredit,
      amountPaid: isCredit ? amountPaid : 0.0,
    );

    if (mounted) {
      setState(() => _isProcessing = false);
      result.match(
        (error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error))),
        (sale) {
          Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => ReceiptScreen(sale: sale)));
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = ref.watch(cartProvider.notifier).subtotal;
    final discount = ref.watch(discountProvider);
    final total = subtotal - discount;
    final isCredit = _paymentMethod == PaymentMethod.credit;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Total Due: LKR $total', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                
                const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
                SegmentedButton<PaymentMethod>(
                  segments: const [
                    ButtonSegment(value: PaymentMethod.cash, label: Text('Cash')),
                    ButtonSegment(value: PaymentMethod.card, label: Text('Card')),
                    ButtonSegment(value: PaymentMethod.credit, label: Text('Credit (Naya Potha)')),
                  ],
                  selected: {_paymentMethod},
                  onSelectionChanged: (set) {
                    setState(() => _paymentMethod = set.first);
                  },
                ),
                
                const SizedBox(height: 24),
                const Text('Customer Info (Optional for Cash/Card)', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  controller: _customerNameController,
                  decoration: const InputDecoration(labelText: 'Customer Name'),
                ),
                TextField(
                  controller: _customerPhoneController,
                  decoration: const InputDecoration(labelText: 'Customer Phone'),
                  keyboardType: TextInputType.phone,
                ),

                if (isCredit) ...[
                  const SizedBox(height: 24),
                  const Text('Credit Details', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  TextField(
                    controller: _amountPaidController,
                    decoration: const InputDecoration(labelText: 'Amount Paid Now'),
                    keyboardType: TextInputType.number,
                  ),
                ],

                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: _processPayment,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  child: const Text('CONFIRM PAYMENT & PRINT', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
    );
  }
}
