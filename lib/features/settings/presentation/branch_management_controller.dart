import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/settings/data/branch_repository.dart';
import 'package:pos_system/features/settings/domain/branch_models.dart';
import 'package:pos_system/features/settings/data/settings_repository.dart';

final branchesProvider = StateNotifierProvider<BranchesNotifier, AsyncValue<List<Branch>>>((ref) {
  return BranchesNotifier(ref.watch(branchRepositoryProvider));
});

final currentBranchProvider = FutureProvider.autoDispose<Branch?>((ref) async {
  final repo = ref.watch(branchRepositoryProvider);
  ref.watch(branchesProvider); // To refresh when branches change
  
  final allRes = await repo.getAllBranches();
  if (allRes.isLeft()) return null;
  final all = allRes.getRight().toNullable()!;
  
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final branchIdRes = await settingsRepo.getCurrentBranchId();
  if (branchIdRes.isLeft()) return null;
  final branchId = branchIdRes.getRight().toNullable();
  
  if (branchId == null) return null;
  try {
    return all.firstWhere((b) => b.id == branchId);
  } catch (_) {
    return null;
  }
});

class BranchesNotifier extends StateNotifier<AsyncValue<List<Branch>>> {
  final BranchRepository _repository;

  BranchesNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadBranches();
  }

  Future<void> loadBranches() async {
    state = const AsyncValue.loading();
    final result = await _repository.getAllBranches();
    result.match(
      (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
      (branches) => state = AsyncValue.data(branches),
    );
  }

  Future<String?> addBranch({
    required String name,
    String? address,
    String? phone,
  }) async {
    final result = await _repository.addBranch(name: name, address: address, phone: phone);
    return result.match(
      (failure) => failure.message,
      (_) {
        loadBranches();
        return null;
      },
    );
  }

  Future<String?> updateBranch({
    required String id,
    String? name,
    String? address,
    String? phone,
  }) async {
    final result = await _repository.updateBranch(
      id: id,
      name: name,
      address: address,
      phone: phone,
    );
    
    return result.match(
      (failure) => failure.message,
      (_) {
        loadBranches();
        return null;
      },
    );
  }

  Future<void> toggleBranchStatus(String id, bool isActive) async {
    await _repository.updateBranch(id: id, isActive: isActive);
    loadBranches();
  }
}
