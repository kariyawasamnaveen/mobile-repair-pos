import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/features/inventory/data/inventory_repository.dart';
import 'package:pos_system/features/inventory/domain/item.dart';
import 'package:pos_system/features/auth/presentation/auth_controller.dart';

final inventoryControllerProvider = StateNotifierProvider<InventoryController, AsyncValue<List<Item>>>((ref) {
  return InventoryController(ref.watch(inventoryRepositoryProvider), ref);
});

class InventoryController extends StateNotifier<AsyncValue<List<Item>>> {
  final InventoryRepository _repository;
  final Ref _ref;
  String _searchQuery = '';
  ItemCategory? _categoryFilter;

  InventoryController(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadItems();
  }

  Future<void> loadItems() async {
    state = const AsyncValue.loading();
    final result = await _repository.getItems(search: _searchQuery, category: _categoryFilter);
    result.match(
      (failure) => state = AsyncValue.error('${failure.message}: ${failure.error}', StackTrace.current),
      (items) => state = AsyncValue.data(items),
    );
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    loadItems();
  }

  void setCategoryFilter(ItemCategory? category) {
    _categoryFilter = category;
    loadItems();
  }

  Future<String?> addItem(Item item, {MovementReason reason = MovementReason.restock}) async {
    final staffId = _ref.read(authStateProvider)?.id;
    final result = await _repository.addItem(item, reason: reason, staffId: staffId);
    return result.match(
      (failure) => failure.message,
      (_) {
        loadItems();
        return null;
      },
    );
  }

  Future<String?> adjustStock(
    String itemId, 
    int amount, 
    MovementReason reason, 
    {
      bool allowNegative = false,
      List<String> imeisToAdd = const [], 
      List<String> imeisToRemove = const []
    }
  ) async {
    final staffId = _ref.read(authStateProvider)?.id;
    final result = await _repository.adjustStock(
      itemId, 
      amount, 
      reason, 
      allowNegative: allowNegative,
      imeisToAdd: imeisToAdd, 
      imeisToRemove: imeisToRemove,
      staffId: staffId,
    );
    return result.match(
      (failure) => failure.message,
      (_) {
        loadItems();
        return null;
      },
    );
  }
}
