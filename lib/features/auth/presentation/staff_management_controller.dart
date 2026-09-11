import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/auth/data/auth_repository.dart';
import 'package:pos_system/features/auth/domain/auth_models.dart';
import 'package:pos_system/core/database/tables.dart';

final staffMembersProvider = StateNotifierProvider<StaffMembersNotifier, AsyncValue<List<StaffMember>>>((ref) {
  return StaffMembersNotifier(ref.watch(authRepositoryProvider));
});

class StaffMembersNotifier extends StateNotifier<AsyncValue<List<StaffMember>>> {
  final AuthRepository _repository;

  StaffMembersNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadStaff();
  }

  Future<void> loadStaff() async {
    state = const AsyncValue.loading();
    final result = await _repository.getAllStaff();
    result.match(
      (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
      (staff) => state = AsyncValue.data(staff),
    );
  }

  Future<String?> addStaff({
    required String name,
    required String pin,
    required StaffRole role,
  }) async {
    final result = await _repository.addStaff(name, pin, role);
    return result.match(
      (failure) => failure.message,
      (_) {
        loadStaff();
        return null;
      },
    );
  }

  Future<String?> updateStaff({
    required String id,
    String? name,
    String? newPin,
    StaffRole? role,
  }) async {
    final result = await _repository.updateStaff(
      id,
      name: name,
      role: role,
    );
    
    if (newPin != null && newPin.isNotEmpty) {
      await _repository.resetPin(id, newPin);
    }
    
    return result.match(
      (failure) => failure.message,
      (_) {
        loadStaff();
        return null;
      },
    );
  }

  Future<void> toggleStaffStatus(String id, bool isActive) async {
    await _repository.updateStaff(id, isActive: isActive);
    loadStaff();
  }
}
