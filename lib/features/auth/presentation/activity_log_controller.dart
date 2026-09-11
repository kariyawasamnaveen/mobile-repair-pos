import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/auth/data/activity_log_repository.dart';
import 'package:pos_system/core/database/tables.dart';

class ActivityLogFilter {
  final String? staffId;
  final ActivityActionType? actionType;

  const ActivityLogFilter({this.staffId, this.actionType});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityLogFilter &&
          runtimeType == other.runtimeType &&
          staffId == other.staffId &&
          actionType == other.actionType;

  @override
  int get hashCode => staffId.hashCode ^ actionType.hashCode;
}

final activityLogsProvider = FutureProvider.family.autoDispose<List<ActivityLog>, ActivityLogFilter>((ref, filter) async {
  final repo = ref.watch(activityLogRepositoryProvider);
  final result = await repo.getLogs(
    staffId: filter.staffId,
    actionType: filter.actionType,
  );
  return result.getOrElse((l) => throw l.message);
});
