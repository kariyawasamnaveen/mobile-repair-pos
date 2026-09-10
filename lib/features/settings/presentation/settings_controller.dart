import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/settings/data/settings_repository.dart';

class StoreSettings {
  final String? name;
  final String? address;
  final String? phone;
  final String? defaultReceiptDelivery; // 'print', 'sms', or 'ask'
  final String? qrPaymentImagePath;
  final DateTime? lastBackupAt;

  const StoreSettings({this.name, this.address, this.phone, this.defaultReceiptDelivery, this.qrPaymentImagePath, this.lastBackupAt});

  StoreSettings copyWith({String? name, String? address, String? phone, String? defaultReceiptDelivery, String? qrPaymentImagePath, DateTime? lastBackupAt}) {
    return StoreSettings(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      defaultReceiptDelivery: defaultReceiptDelivery ?? this.defaultReceiptDelivery,
      qrPaymentImagePath: qrPaymentImagePath ?? this.qrPaymentImagePath,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
    );
  }
}

final storeSettingsProvider = StateNotifierProvider<StoreSettingsNotifier, AsyncValue<StoreSettings>>((ref) {
  return StoreSettingsNotifier(ref.watch(settingsRepositoryProvider));
});

class StoreSettingsNotifier extends StateNotifier<AsyncValue<StoreSettings>> {
  final SettingsRepository _repository;

  StoreSettingsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadStoreSettings();
  }

  Future<void> loadStoreSettings() async {
    state = const AsyncValue.loading();
    final nameRes = await _repository.getSetting('store_name');
    final addressRes = await _repository.getSetting('store_address');
    final phoneRes = await _repository.getSetting('store_phone');

    String? name;
    String? address;
    String? phone;
    String? defaultReceiptDelivery;

    nameRes.match((_) {}, (val) => name = val);
    addressRes.match((_) {}, (val) => address = val);
    phoneRes.match((_) {}, (val) => phone = val);
    
    final deliveryRes = await _repository.getSetting('default_receipt_delivery');
    deliveryRes.match((_) {}, (val) => defaultReceiptDelivery = val);
    
    String? qrPath;
    final qrRes = await _repository.getSetting('qr_payment_image_path');
    qrRes.match((_) {}, (val) => qrPath = val);

    final backupRes = await _repository.getLastBackupTime();
    DateTime? lastBackupAt;
    backupRes.match((_) {}, (val) => lastBackupAt = val);

    state = AsyncValue.data(StoreSettings(
      name: name,
      address: address,
      phone: phone,
      defaultReceiptDelivery: defaultReceiptDelivery ?? 'ask',
      qrPaymentImagePath: qrPath,
      lastBackupAt: lastBackupAt,
    ));
  }

  Future<String?> saveStoreSettings({
    required String name,
    required String address,
    required String phone,
    required String defaultReceiptDelivery,
  }) async {
    final res1 = await _repository.setSetting('store_name', name);
    final res2 = await _repository.setSetting('store_address', address);
    final res3 = await _repository.setSetting('store_phone', phone);
    final res4 = await _repository.setSetting('default_receipt_delivery', defaultReceiptDelivery);

    if (res1.isLeft() || res2.isLeft() || res3.isLeft() || res4.isLeft()) {
      return 'Failed to save some settings';
    }

    // Keep existing QR path and backup time
    final qrPath = state.valueOrNull?.qrPaymentImagePath;
    final lastBackupAt = state.valueOrNull?.lastBackupAt;

    state = AsyncValue.data(StoreSettings(
      name: name,
      address: address,
      phone: phone,
      defaultReceiptDelivery: defaultReceiptDelivery,
      qrPaymentImagePath: qrPath,
      lastBackupAt: lastBackupAt,
    ));
    return null; // success
  }

  Future<void> updateQrImagePath(String? path) async {
    if (path == null) {
      await _repository.setSetting('qr_payment_image_path', '');
    } else {
      await _repository.setSetting('qr_payment_image_path', path);
    }
    
    if (state.hasValue && state.value != null) {
      state = AsyncValue.data(state.value!.copyWith(qrPaymentImagePath: path ?? ''));
    } else {
      loadStoreSettings();
    }
  }
}
