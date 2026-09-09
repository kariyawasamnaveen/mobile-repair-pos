import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/inventory/presentation/inventory_controller.dart';
import 'package:pos_system/features/inventory/presentation/add_item_screen.dart';
import 'package:pos_system/features/inventory/presentation/stock_adjustment_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pos_system/features/inventory/data/inventory_repository.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search items',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                ref.read(inventoryControllerProvider.notifier).setSearchQuery(val);
              },
            ),
          ),
          Expanded(
            child: inventoryState.when(
              data: (items) {
                if (items.isEmpty) return const Center(child: Text('No items found'));
                
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isLowStock = item.quantity <= item.reorderLevel;
                    
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text('${item.internalCode} | Stock: ${item.quantity}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLowStock)
                            const Icon(Icons.warning, color: Colors.orange),
                          IconButton(
                            icon: const Icon(Icons.inventory),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute<void>(builder: (_) => StockAdjustmentScreen(item: item)));
                            },
                          ),
                        ],
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
