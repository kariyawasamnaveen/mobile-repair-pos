import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/theme/app_theme.dart';
import 'package:pos_system/core/widgets/empty_state_widget.dart';
import 'package:pos_system/features/suppliers/presentation/supplier_controller.dart';
import 'package:pos_system/features/suppliers/data/supplier_repository.dart';
import 'package:pos_system/features/suppliers/domain/supplier.dart';
import 'package:pos_system/features/inventory/presentation/inventory_controller.dart';

class CreatePurchaseOrderScreen extends ConsumerStatefulWidget {
  final String supplierId;
  const CreatePurchaseOrderScreen({super.key, required this.supplierId});

  @override
  ConsumerState<CreatePurchaseOrderScreen> createState() => _CreatePurchaseOrderScreenState();
}

class _CreatePurchaseOrderScreenState extends ConsumerState<CreatePurchaseOrderScreen> {
  final _notesCtrl = TextEditingController();
  final List<PurchaseOrderItem> _lineItems = [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _lineItems.fold(0.0, (sum, i) => sum + i.lineTotal);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Purchase Order'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: AppThemeConstants.defaultPadding,
              children: [
                TextField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Line Items', style: theme.textTheme.titleMedium),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('ADD ITEM'),
                      onPressed: () => _showAddItemSheet(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_lineItems.isEmpty)
                  const EmptyStateWidget(
                    icon: Icons.list_alt_outlined,
                    title: 'No items added yet',
                    subtitle: 'Use the button above to add items to this order.',
                  )
                else
                  ..._lineItems.asMap().entries.map((e) {
                    final index = e.key;
                    final item = e.value;
                    return Card(
                      child: ListTile(
                        title: Text(item.displayName),
                        subtitle: Text('${item.quantityOrdered} x Rs ${item.unitCost.toStringAsFixed(2)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Rs ${item.lineTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: Icon(Icons.delete, color: AppTheme.errorColor),
                              onPressed: () => setState(() => _lineItems.removeAt(index)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Rs ${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _lineItems.isEmpty ? null : _submitOrder,
                  child: const Text('CREATE ORDER'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddItemSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: const _AddItemSheet(),
      ),
    ).then((newItem) {
      if (newItem != null && newItem is PurchaseOrderItem) {
        setState(() => _lineItems.add(newItem));
      }
    });
  }

  Future<void> _submitOrder() async {
    final repo = ref.read(supplierRepositoryProvider);
    final draftRes = await repo.getNewDraftPurchaseOrder(widget.supplierId);
    
    if (!mounted) return;
    
    draftRes.fold(
      (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
      (draftPo) async {
        final total = _lineItems.fold(0.0, (sum, i) => sum + i.lineTotal);
        final finalPo = draftPo.copyWith(
          totalAmount: total,
          balanceDue: total,
          notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        );

        final res = await repo.createPurchaseOrder(finalPo, _lineItems);
        if (mounted) {
          res.fold(
            (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
            (r) {
              ref.invalidate(purchaseOrdersProvider(widget.supplierId));
              Navigator.pop(context);
            },
          );
        }
      },
    );
  }
}

class _AddItemSheet extends ConsumerStatefulWidget {
  const _AddItemSheet();

  @override
  ConsumerState<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<_AddItemSheet> {
  String? _selectedItemId;
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _costCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryControllerProvider);

    return Padding(
      padding: AppThemeConstants.cardPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add Line Item', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          inventoryState.when(
            data: (items) {
              return DropdownButtonFormField<String>(
                initialValue: _selectedItemId,
                decoration: const InputDecoration(labelText: 'Link to Inventory Item (Optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None (Custom Item)')),
                  ...items.map((i) => DropdownMenuItem(value: i.id, child: Text(i.name))),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedItemId = val;
                    if (val != null) {
                      final item = items.firstWhere((i) => i.id == val);
                      _nameCtrl.text = item.name;
                      _costCtrl.text = item.purchasePrice.toString();
                    }
                  });
                },
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Error loading inventory: $e'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Item Name'),
            readOnly: _selectedItemId != null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _costCtrl,
                  decoration: const InputDecoration(labelText: 'Unit Cost'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              final qty = int.tryParse(_qtyCtrl.text);
              final cost = double.tryParse(_costCtrl.text);
              if (qty == null || qty <= 0 || cost == null || cost < 0 || _nameCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid input')));
                return;
              }

              final item = PurchaseOrderItem(
                id: 0,
                purchaseOrderId: '', // Will be set by repository
                itemId: _selectedItemId,
                itemNameText: _nameCtrl.text,
                quantityOrdered: qty,
                quantityReceived: 0,
                unitCost: cost,
                lineTotal: qty * cost,
              );
              Navigator.pop(context, item);
            },
            child: const Text('ADD'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
