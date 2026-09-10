import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/reports/domain/reports_models.dart';
import 'package:pos_system/features/reports/data/reports_repository.dart';

final dateRangeTypeProvider = StateProvider<DateRangeType>((ref) => DateRangeType.today);

final customDateRangeProvider = StateProvider<DateRange?>((ref) => null);

final selectedDateRangeProvider = Provider<DateRange>((ref) {
  final type = ref.watch(dateRangeTypeProvider);
  final now = DateTime.now();
  
  switch (type) {
    case DateRangeType.today:
      final start = DateTime(now.year, now.month, now.day);
      return DateRange(start, start.add(const Duration(days: 1, milliseconds: -1)));
    case DateRangeType.thisWeek:
      final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      return DateRange(start, start.add(const Duration(days: 7, milliseconds: -1)));
    case DateRangeType.thisMonth:
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(milliseconds: 1));
      return DateRange(start, end);
    case DateRangeType.custom:
      final custom = ref.watch(customDateRangeProvider);
      if (custom != null) return custom;
      final start = DateTime(now.year, now.month, now.day);
      return DateRange(start, start.add(const Duration(days: 1, milliseconds: -1)));
  }
});

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final range = ref.watch(selectedDateRangeProvider);
  final repo = ref.watch(reportsRepositoryProvider);
  final res = await repo.getDashboardSummary(range);
  return res.fold((l) => throw l.message, (r) => r);
});

final salesBreakdownProvider = FutureProvider.autoDispose<SalesBreakdown>((ref) async {
  final range = ref.watch(selectedDateRangeProvider);
  final repo = ref.watch(reportsRepositoryProvider);
  final res = await repo.getSalesBreakdown(range);
  return res.fold((l) => throw l.message, (r) => r);
});

final repairJobsBreakdownProvider = FutureProvider.autoDispose<RepairJobsBreakdown>((ref) async {
  final range = ref.watch(selectedDateRangeProvider);
  final repo = ref.watch(reportsRepositoryProvider);
  final res = await repo.getRepairJobsBreakdown(range);
  return res.fold((l) => throw l.message, (r) => r);
});

final inventoryHealthProvider = FutureProvider.autoDispose<InventoryHealth>((ref) async {
  final repo = ref.watch(reportsRepositoryProvider);
  final res = await repo.getInventoryHealth();
  return res.fold((l) => throw l.message, (r) => r);
});
