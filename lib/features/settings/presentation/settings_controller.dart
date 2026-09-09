import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/settings/data/settings_repository.dart';

class StoreSettings {
  final String? name;
  final String? address;
  final String? phone;

  const StoreSettings({this.name, this.address, this.phone});

  StoreSettings copyWith({String? name, String? address, String? phone}) {
    return StoreSettings(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
    );
  }
}

final storeSettingsProvider = StateNotifierProvider<StoreSettingsNotifier, AsyncValue<StoreSettings>>((ref) {
  return StoreSettingsNotifier(ref.watch(settingsRepositoryProvider));
});

class StoreSettingsNotifier extends StateNotifier<AsyncValue<StoreSettings>> {
  final SettingsRepository _repository;

  StoreSettingsNotifier(this._repository) : super(const AsyncValue.loading()) {
    _loadStoreSettings();
  }

  Future<void> _loadStoreSettings() async {
    state = const AsyncValue.loading();
    final nameRes = await _repository.getSetting('store_name');
    final addressRes = await _repository.getSetting('store_address');
    final phoneRes = await _repository.getSetting('store_phone');

    String? name;
    String? address;
    String? phone;

    nameRes.match((_) {}, (val) => name = val);
    addressRes.match((_) {}, (val) => address = val);
    phoneRes.match((_) {}, (val) => phone = val);

    state = AsyncValue.data(StoreSettings(name: name, address: address, phone: phone));
  }

  Future<String?> saveStoreSettings({required String name, required String address, required String phone}) async {
    final res1 = await _repository.setSetting('store_name', name);
    final res2 = await _repository.setSetting('store_address', address);
    final res3 = await _repository.setSetting('store_phone', phone);

    if (res1.isLeft() || res2.isLeft() || res3.isLeft()) {
      return 'Failed to save some settings';
    }

    state = AsyncValue.data(StoreSettings(name: name, address: address, phone: phone));
    return null; // success
  }
}
