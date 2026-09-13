import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/widgets/empty_state_widget.dart';
import 'package:pos_system/core/theme/app_theme.dart';
import 'package:pos_system/features/suppliers/presentation/supplier_controller.dart';
import 'package:pos_system/features/suppliers/data/supplier_repository.dart';
import 'package:pos_system/features/suppliers/presentation/supplier_detail_screen.dart';

class SupplierListScreen extends ConsumerWidget {
  const SupplierListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersState = ref.watch(suppliersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers'),
      ),
      body: suppliersState.when(
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.local_shipping_outlined,
              title: 'No suppliers found',
              subtitle: 'Add a supplier to start managing purchase orders.',
            );
          }
          return ListView.builder(
            padding: AppThemeConstants.defaultPadding,
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final item = suppliers[index];
              return Card(
                child: ListTile(
                  title: Text(item.supplier.name, style: theme.textTheme.titleMedium),
                  subtitle: Text(item.supplier.phone ?? 'No phone'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Balance Owed', style: theme.textTheme.bodySmall),
                      Text('Rs ${item.balanceDue.toStringAsFixed(2)}', style: theme.textTheme.titleSmall?.copyWith(color: AppTheme.errorColor)),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => SupplierDetailScreen(supplierId: item.supplier.id)));
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSupplierDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddSupplierDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Supplier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 8),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final res = await ref.read(supplierRepositoryProvider).createSupplier(
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                address: addressCtrl.text.trim(),
              );
              if (context.mounted) {
                res.fold(
                  (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
                  (r) {
                    ref.invalidate(suppliersProvider);
                    Navigator.pop(context);
                  },
                );
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
}
