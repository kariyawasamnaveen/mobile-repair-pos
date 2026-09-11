import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/auth/data/auth_repository.dart';
import 'package:pos_system/features/auth/domain/auth_models.dart';

final authStateProvider = StateProvider<StaffMember?>((ref) => null);

final hasAnyStaffProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  final res = await repo.hasAnyStaff();
  return res.fold(
    (l) => false,
    (r) => r,
  );
});

final activeStaffProvider = FutureProvider<List<StaffMember>>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  final res = await repo.getActiveStaff();
  return res.fold(
    (l) => [],
    (r) => r,
  );
});

final allStaffProvider = FutureProvider<List<StaffMember>>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  final res = await repo.getAllStaff();
  return res.fold(
    (l) => [],
    (r) => r,
  );
});
