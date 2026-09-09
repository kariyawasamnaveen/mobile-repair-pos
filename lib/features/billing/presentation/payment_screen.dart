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
  final _amountTenderedController = TextEditingController();
  final _cashierNameController = TextEditingController();
  final _tenderedFocusNode = FocusNode();
  
  bool _isProcessing = false;
  bool _showCustomerInfo = false;
  double _changeDue = 0.0;

  @override
  void initState() {
    super.initState();
    // Auto-focus tendered field initially since default is cash
    Future.microtask(() => _tenderedFocusNode.requestFocus());
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _amountPaidController.dispose();
    _amountTenderedController.dispose();
    _cashierNameController.dispose();
    _tenderedFocusNode.dispose();
    super.dispose();
  }

  void _calculateChangeDue(double total) {
    if (_paymentMethod == PaymentMethod.cash) {
      final tendered = double.tryParse(_amountTenderedController.text) ?? 0.0;
      setState(() {
        _changeDue = tendered - total;
      });
    }
  }

  void _setQuickAmount(double amount, double total) {
    _amountTenderedController.text = amount.toStringAsFixed(0);
    _calculateChangeDue(total);
  }

  List<double> _getQuickAmounts(double total) {
    final amounts = <double>{};
    if (total > 0) {
      amounts.add((total / 100).ceil() * 100.0);
      amounts.add((total / 500).ceil() * 500.0);
      amounts.add((total / 1000).ceil() * 1000.0);
      amounts.add((total / 5000).ceil() * 5000.0);
    }
    final filtered = amounts.where((a) => a > total).toList()..sort();
    return filtered.take(3).toList();
  }

  Future<void> _processPayment(double total) async {
    final isCash = _paymentMethod == PaymentMethod.cash;
    final tendered = double.tryParse(_amountTenderedController.text) ?? 0.0;

    if (isCash && tendered < total) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount tendered is less than total')));
      return;
    }

    setState(() => _isProcessing = true);
    
    final isCredit = _paymentMethod == PaymentMethod.credit;
    final amountPaid = double.tryParse(_amountPaidController.text) ?? 0.0;

    final controller = ref.read(checkoutControllerProvider);
    final result = await controller.processCheckout(
      paymentMethod: _paymentMethod,
      customerName: _customerNameController.text.isNotEmpty ? _customerNameController.text : null,
      customerPhone: _customerPhoneController.text.isNotEmpty ? _customerPhoneController.text : null,
      cashierName: _cashierNameController.text.isNotEmpty ? _cashierNameController.text : null,
      isCreditSale: isCredit,
      amountPaid: isCredit ? amountPaid : 0.0,
      amountTendered: isCash ? tendered : null,
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
    final isCash = _paymentMethod == PaymentMethod.cash;
    
    final quickAmounts = _getQuickAmounts(total);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text('Total Due: LKR $total', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    if (isCash)
                      Text('Change: LKR ${_changeDue >= 0 ? _changeDue.toStringAsFixed(2) : "0.00"}', 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _changeDue < 0 ? Colors.red : Colors.green)),
                  ],
                ),
                const SizedBox(height: 16),
                
                SegmentedButton<PaymentMethod>(
                  segments: const [
                    ButtonSegment(value: PaymentMethod.cash, label: Text('Cash')),
                    ButtonSegment(value: PaymentMethod.card, label: Text('Card')),
                    ButtonSegment(value: PaymentMethod.credit, label: Text('Credit')),
                  ],
                  selected: {_paymentMethod},
                  onSelectionChanged: (set) {
                    setState(() {
                      _paymentMethod = set.first;
                      _calculateChangeDue(total);
                      if (_paymentMethod == PaymentMethod.credit) {
                        _showCustomerInfo = true;
                      }
                    });
                    if (_paymentMethod == PaymentMethod.cash) {
                      _tenderedFocusNode.requestFocus();
                    }
                  },
                ),
                
                const SizedBox(height: 16),
                
                if (isCash) ...[
                  TextField(
                    controller: _amountTenderedController,
                    focusNode: _tenderedFocusNode,
                    decoration: const InputDecoration(labelText: 'Amount Tendered', isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => _calculateChangeDue(total),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Exact'),
                        onPressed: () => _setQuickAmount(total, total),
                      ),
                      for (final amount in quickAmounts)
                        ActionChip(
                          label: Text(amount.toStringAsFixed(0)),
                          onPressed: () => _setQuickAmount(amount, total),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                if (isCredit) ...[
                  TextField(
                    controller: _amountPaidController,
                    decoration: const InputDecoration(labelText: 'Amount Paid Now', isDense: true),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                ],

                if (!_showCustomerInfo)
                  TextButton.icon(
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('+ Add customer info (optional)'),
                    onPressed: () => setState(() => _showCustomerInfo = true),
                  )
                else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Customer Info', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (!isCredit)
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => setState(() {
                            _showCustomerInfo = false;
                            _customerNameController.clear();
                            _customerPhoneController.clear();
                          }),
                        ),
                    ],
                  ),
                  TextField(
                    controller: _customerNameController,
                    decoration: const InputDecoration(labelText: 'Name', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customerPhoneController,
                    decoration: const InputDecoration(labelText: 'Phone', isDense: true),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 16),
                
                TextField(
                  controller: _cashierNameController,
                  decoration: const InputDecoration(labelText: 'Cashier Name (Optional)', isDense: true, prefixIcon: Icon(Icons.badge)),
                ),

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _processPayment(total),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('CONFIRM PAYMENT', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
    );
  }
}
