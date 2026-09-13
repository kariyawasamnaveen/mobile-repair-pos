import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/features/discount/data/discount_repository.dart';
import 'package:pos_system/features/discount/domain/discount_rule.dart';
import 'package:pos_system/providers/app_providers.dart';

final discountRepositoryProvider = Provider<DiscountRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DiscountRepository(db);
});

final activeDiscountRulesProvider = FutureProvider<List<DiscountRule>>((ref) async {
  final repo = ref.watch(discountRepositoryProvider);
  final res = await repo.getActiveDiscountRules();
  return res.fold((l) => throw l, (r) => r);
});

final allDiscountRulesProvider = FutureProvider<List<DiscountRule>>((ref) async {
  final repo = ref.watch(discountRepositoryProvider);
  final res = await repo.getDiscountRules();
  return res.fold((l) => throw l, (r) => r);
});

class DiscountRulesController extends StateNotifier<AsyncValue<void>> {
  final DiscountRepository _repository;
  final Ref _ref;

  DiscountRulesController(this._repository, this._ref) : super(const AsyncValue.data(null));

  Future<String?> createRule({
    required String name,
    required DiscountType type,
    required double value,
    required DiscountScope scope,
    String? scopeReference,
    double? minPurchaseAmount,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = const AsyncValue.loading();
    final result = await _repository.createDiscountRule(
      name: name,
      type: type,
      value: value,
      scope: scope,
      scopeReference: scopeReference,
      minPurchaseAmount: minPurchaseAmount,
      startDate: startDate,
      endDate: endDate,
    );

    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (_) {
        _ref.invalidate(allDiscountRulesProvider);
        _ref.invalidate(activeDiscountRulesProvider);
        return const AsyncValue.data(null);
      },
    );

    return result.fold((l) => l.message, (r) => null);
  }

  Future<String?> deactivateRule(String id) async {
    state = const AsyncValue.loading();
    final result = await _repository.deactivateDiscountRule(id);
    
    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (_) {
        _ref.invalidate(allDiscountRulesProvider);
        _ref.invalidate(activeDiscountRulesProvider);
        return const AsyncValue.data(null);
      },
    );

    return result.fold((l) => l.message, (r) => null);
  }
}

final discountRulesControllerProvider = StateNotifierProvider<DiscountRulesController, AsyncValue<void>>((ref) {
  return DiscountRulesController(ref.watch(discountRepositoryProvider), ref);
});
