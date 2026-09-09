import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/settings/data/settings_repository.dart';

final storeNameProvider = StateNotifierProvider<StoreNameNotifier, AsyncValue<String?>>((ref) {
  return StoreNameNotifier(ref.watch(settingsRepositoryProvider));
});

class StoreNameNotifier extends StateNotifier<AsyncValue<String?>> {
  final SettingsRepository _repository;

  StoreNameNotifier(this._repository) : super(const AsyncValue.loading()) {
    _loadStoreName();
  }

  Future<void> _loadStoreName() async {
    state = const AsyncValue.loading();
    final result = await _repository.getSetting('store_name');
    result.match(
      (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
      (name) => state = AsyncValue.data(name),
    );
  }

  Future<String?> saveStoreName(String newName) async {
    final result = await _repository.setSetting('store_name', newName);
    return result.match(
      (failure) => failure.message,
      (_) {
        state = AsyncValue.data(newName);
        return null; // success
      },
    );
  }
}
