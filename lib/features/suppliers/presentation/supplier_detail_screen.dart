import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/core/theme/app_theme.dart';
import 'package:pos_system/features/suppliers/presentation/supplier_controller.dart';
import 'package:pos_system/features/suppliers/data/supplier_repository.dart';
import 'package:pos_system/features/suppliers/presentation/purchase_order_detail_screen.dart';
import 'package:pos_system/features/suppliers/presentation/create_purchase_order_screen.dart';

class SupplierDetailScreen extends ConsumerWidget {
  final String supplierId;
  const SupplierDetailScreen({super.key, required this.supplierId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierState = ref.watch(supplierDetailProvider(supplierId));
    final posState = ref.watch(purchaseOrdersProvider(supplierId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Details'),
      ),
      body: supplierState.when(
        data: (supplier) {
          return posState.when(
            data: (pos) {
              final balance = pos.where((p) => p.status != PurchaseOrderStatus.cancelled).fold(0.0, (sum, p) => sum + p.balanceDue);
              return ListView(
                padding: AppThemeConstants.defaultPadding,
                children: [
                  Card(
                    child: Padding(
                      padding: AppThemeConstants.cardPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(supplier.name, style: theme.textTheme.headlineSmall),
                          if (supplier.phone != null) Text('Phone: ${supplier.phone}'),
                          if (supplier.address != null) Text('Address: ${supplier.address}'),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Owed:', style: theme.textTheme.titleMedium),
                              Text('Rs ${balance.toStringAsFixed(2)}', style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.errorColor)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              icon: const Icon(Icons.payment),
                              label: const Text('Record Payment'),
                              onPressed: balance > 0 ? () => _showPaymentSheet(context, ref, supplierId, balance) : null,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Purchase Orders', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (pos.isEmpty)
                    const Center(child: Text('No purchase orders found.'))
                  else
                    ...pos.map((po) => Card(
                      child: ListTile(
                        title: Text(po.poNumber, style: theme.textTheme.titleSmall),
                        subtitle: Text('${po.status.name.toUpperCase()} • ${po.orderDate.toString().split(' ')[0]}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Rs ${po.totalAmount.toStringAsFixed(2)}'),
                            if (po.balanceDue > 0)
                              Text('Owe: Rs ${po.balanceDue.toStringAsFixed(2)}', style: TextStyle(color: AppTheme.errorColor, fontSize: 10)),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => PurchaseOrderDetailScreen(purchaseOrderId: po.id)));
                        },
                      ),
                    )),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => CreatePurchaseOrderScreen(supplierId: supplierId)));
        },
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('New PO'),
      ),
    );
  }

  void _showPaymentSheet(BuildContext context, WidgetRef ref, String supplierId, double maxAmount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _PaymentSheet(supplierId: supplierId, maxAmount: maxAmount),
      ),
    );
  }
}

class _PaymentSheet extends ConsumerStatefulWidget {
  final String supplierId;
  final double maxAmount;

  const _PaymentSheet({required this.supplierId, required this.maxAmount});

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final _amountCtrl = TextEditingController();
  CreditPaymentMethod _method = CreditPaymentMethod.cash;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppThemeConstants.cardPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Record Payment', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            decoration: InputDecoration(labelText: 'Amount (Max: Rs ${widget.maxAmount.toStringAsFixed(2)})'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<CreditPaymentMethod>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Payment Method'),
            items: CreditPaymentMethod.values.map((m) => DropdownMenuItem(value: m, child: Text(m.name.toUpperCase()))).toList(),
            onChanged: (v) => setState(() => _method = v!),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              final amt = double.tryParse(_amountCtrl.text);
              if (amt == null || amt <= 0) return;
              if (amt > widget.maxAmount) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot pay more than outstanding balance')));
                return;
              }
              final res = await ref.read(supplierRepositoryProvider).recordPayment(
                supplierId: widget.supplierId,
                amount: amt,
                method: _method,
              );
              if (mounted) {
                res.fold(
                  (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
                  (r) {
                    ref.invalidate(suppliersProvider);
                    ref.invalidate(purchaseOrdersProvider(widget.supplierId));
                    Navigator.pop(context);
                  },
                );
              }
            },
            child: const Text('SUBMIT PAYMENT'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
