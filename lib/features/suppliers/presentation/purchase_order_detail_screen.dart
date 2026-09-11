import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/core/theme/app_theme.dart';
import 'package:pos_system/features/suppliers/presentation/supplier_controller.dart';
import 'package:pos_system/features/suppliers/data/supplier_repository.dart';

class PurchaseOrderDetailScreen extends ConsumerWidget {
  final String purchaseOrderId;
  const PurchaseOrderDetailScreen({super.key, required this.purchaseOrderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poState = ref.watch(purchaseOrderDetailProvider(purchaseOrderId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PO Details'),
      ),
      body: poState.when(
        data: (po) {
          final isReceivable = po.status == PurchaseOrderStatus.ordered || po.status == PurchaseOrderStatus.partiallyReceived;
          return ListView(
            padding: AppThemeConstants.defaultPadding,
            children: [
              Card(
                child: Padding(
                  padding: AppThemeConstants.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(po.poNumber, style: theme.textTheme.headlineSmall),
                          Chip(label: Text(po.status.name.toUpperCase()), backgroundColor: _getStatusColor(po.status).withValues(alpha: 0.2)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Supplier: ${po.supplier?.name ?? 'Unknown'}', style: theme.textTheme.titleMedium),
                      Text('Date: ${po.orderDate.toString().split(' ')[0]}'),
                      const SizedBox(height: 16),
                      Text('Total: Rs ${po.totalAmount.toStringAsFixed(2)}', style: theme.textTheme.titleMedium),
                      Text('Paid: Rs ${po.amountPaid.toStringAsFixed(2)}'),
                      if (po.balanceDue > 0)
                        Text('Balance: Rs ${po.balanceDue.toStringAsFixed(2)}', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Line Items', style: theme.textTheme.titleMedium),
                  if (isReceivable)
                    FilledButton.tonal(
                      onPressed: () => _showReceiveSheet(context, ref, po.id, po.items),
                      child: const Text('Receive Items'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ...po.items.map((item) => Card(
                child: ListTile(
                  title: Text(item.displayName),
                  subtitle: Text('Ordered: ${item.quantityOrdered} | Received: ${item.quantityReceived}'),
                  trailing: Text('Rs ${item.lineTotal.toStringAsFixed(2)}'),
                ),
              )),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Color _getStatusColor(PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.draft: return Colors.grey;
      case PurchaseOrderStatus.ordered: return Colors.blue;
      case PurchaseOrderStatus.partiallyReceived: return Colors.orange;
      case PurchaseOrderStatus.received: return AppTheme.successColor;
      case PurchaseOrderStatus.cancelled: return AppTheme.errorColor;
    }
  }

  void _showReceiveSheet(BuildContext context, WidgetRef ref, String poId, List<dynamic> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ReceiveSheet(poId: poId, items: items),
      ),
    );
  }
}

class _ReceiveSheet extends ConsumerStatefulWidget {
  final String poId;
  final List<dynamic> items;

  const _ReceiveSheet({required this.poId, required this.items});

  @override
  ConsumerState<_ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends ConsumerState<_ReceiveSheet> {
  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (final item in widget.items) {
      _controllers[item.id] = TextEditingController(text: '0');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppThemeConstants.cardPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Receive Items', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...widget.items.map((item) {
            final maxToReceive = item.quantityOrdered - item.quantityReceived;
            if (maxToReceive <= 0) return const SizedBox.shrink();
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text('${item.displayName}\n(Max: $maxToReceive)', style: const TextStyle(fontSize: 12)),
                  ),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _controllers[item.id],
                      decoration: const InputDecoration(labelText: 'Qty'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              final Map<int, int> toReceive = {};
              for (final item in widget.items) {
                final maxToReceive = item.quantityOrdered - item.quantityReceived;
                final qty = int.tryParse(_controllers[item.id]?.text ?? '0') ?? 0;
                if (qty > 0) {
                  if (qty > maxToReceive) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot receive more than ordered for ${item.displayName}')));
                    return;
                  }
                  toReceive[item.id] = qty;
                }
              }

              if (toReceive.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No quantities entered')));
                return;
              }

              final res = await ref.read(supplierRepositoryProvider).receiveItems(widget.poId, toReceive);
              if (mounted) {
                res.fold(
                  (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
                  (r) {
                    ref.invalidate(purchaseOrderDetailProvider(widget.poId));
                    ref.invalidate(purchaseOrdersProvider);
                    Navigator.pop(context);
                  },
                );
              }
            },
            child: const Text('CONFIRM RECEIPT'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
