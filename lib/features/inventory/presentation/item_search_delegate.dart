import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/inventory/domain/item.dart';
import 'package:pos_system/features/inventory/presentation/inventory_controller.dart';

class ItemSearchDelegate extends SearchDelegate<Item?> {
  final WidgetRef ref;

  ItemSearchDelegate(this.ref);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList();
  }

  Widget _buildList() {
    // A simplistic implementation: we fetch all inventory items and filter them
    // Ideally we'd have a specific search provider to avoid blocking on large lists
    final state = ref.watch(inventoryControllerProvider);

    return state.when(
      data: (items) {
        final filtered = items.where((item) => 
          item.name.toLowerCase().contains(query.toLowerCase()) || 
          item.internalCode.toLowerCase().contains(query.toLowerCase())
        ).toList();

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final item = filtered[index];
            return ListTile(
              title: Text(item.name),
              subtitle: Text('${item.internalCode} • Qty: ${item.quantity}'),
              onTap: () => close(context, item),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
