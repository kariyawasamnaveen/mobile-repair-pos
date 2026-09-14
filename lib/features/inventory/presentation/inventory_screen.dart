import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/inventory/presentation/inventory_controller.dart';
import 'package:pos_system/features/inventory/presentation/add_item_screen.dart';
import 'package:pos_system/features/inventory/presentation/stock_adjustment_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pos_system/features/inventory/data/inventory_repository.dart';
import 'package:pos_system/features/auth/presentation/auth_controller.dart';
import 'package:pos_system/core/theme/app_theme.dart';
import 'package:pos_system/core/widgets/empty_state_widget.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();

  Future<void> _importCsv() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (files.isNotEmpty && files.first.path != null) {
      final file = File(files.first.path!);
      final csvString = await file.readAsString();
      
      final repo = ref.read(inventoryRepositoryProvider);
      final importResult = await repo.bulkImportCsv(csvString);
      
      if (mounted) {
        importResult.match(
          (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message))),
          (count) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $count items successfully')));
            ref.read(inventoryControllerProvider.notifier).loadItems();
          }
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        actions: [
          if (ref.watch(authStateProvider)?.isOwner == true) ...[
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Import CSV',
              onPressed: _importCsv,
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AddItemScreen()));
              },
            ),
          ],
          const SizedBox(width: AppThemeConstants.spacing8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: AppThemeConstants.defaultPadding,
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search items',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) {
                ref.read(inventoryControllerProvider.notifier).setSearchQuery(val);
              },
            ),
          ),
          Expanded(
            child: inventoryState.when(
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.inventory_2_outlined,
                    title: 'Your inventory is empty',
                    subtitle: 'Add your first item to get started.',
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing16, vertical: AppThemeConstants.spacing8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isLowStock = item.quantity <= item.reorderLevel;
                    
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing16, vertical: AppThemeConstants.spacing8),
                        title: Text(item.name, style: theme.textTheme.titleMedium),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: AppThemeConstants.spacing4),
                          child: Wrap(
                            spacing: AppThemeConstants.spacing8,
                            runSpacing: AppThemeConstants.spacing4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(item.internalCode, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isLowStock ? theme.colorScheme.errorContainer : theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Stock: ${item.quantity}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isLowStock ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              if (ref.watch(authStateProvider)?.isOwner == true)
                                Builder(
                                  builder: (context) {
                                    final profit = item.sellingPrice - item.purchasePrice;
                                    final margin = item.sellingPrice > 0 ? (profit / item.sellingPrice) * 100 : 0.0;
                                    final isNegative = profit < 0;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isNegative ? theme.colorScheme.errorContainer : theme.colorScheme.tertiaryContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Margin: Rs ${profit.toStringAsFixed(0)} (${margin.toStringAsFixed(0)}%)',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: isNegative ? theme.colorScheme.error : theme.colorScheme.onTertiaryContainer,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  }
                                ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isLowStock)
                              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                            if (ref.watch(authStateProvider)?.isOwner == true) ...[
                              if (isLowStock) const SizedBox(width: AppThemeConstants.spacing8),
                              IconButton(
                                icon: Icon(Icons.edit_note, color: theme.colorScheme.primary),
                                tooltip: 'Adjust Stock',
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute<void>(builder: (_) => StockAdjustmentScreen(item: item)));
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
