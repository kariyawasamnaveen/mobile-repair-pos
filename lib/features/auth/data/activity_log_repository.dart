import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as developer;
import 'package:drift/drift.dart' as drift;
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/core/error/failure.dart';
import 'package:pos_system/providers/app_providers.dart';

class ActivityLog {
  final int id;
  final String? staffId;
  final String? staffName; // joined from StaffMembers
  final ActivityActionType actionType;
  final String description;
  final DateTime timestamp;

  ActivityLog({
    required this.id,
    this.staffId,
    this.staffName,
    required this.actionType,
    required this.description,
    required this.timestamp,
  });
}

final activityLogRepositoryProvider = Provider<ActivityLogRepository>((ref) {
  return ActivityLogRepository(ref.watch(databaseProvider));
});

class ActivityLogRepository {
  final AppDatabase _db;

  ActivityLogRepository(this._db);

  /// Log an action (can be used directly by other repositories)
  Future<void> logAction({
    required String? staffId,
    required ActivityActionType actionType,
    required String description,
  }) async {
    try {
      final entry = ActivityLogsCompanion.insert(
        staffId: staffId == null ? const drift.Value.absent() : drift.Value(staffId),
        actionType: actionType,
        description: description,
      );
      await _db.into(_db.activityLogs).insert(entry);
    } catch (e) {
      // Intentionally swallow errors so logging failure doesn't crash the main transaction
      developer.log('Failed to write activity log: $e');
    }
  }

  /// Get logs with optional filters (Owner only)
  Future<Either<Failure, List<ActivityLog>>> getLogs({
    String? staffId,
    ActivityActionType? actionType,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final query = _db.select(_db.activityLogs).join([
        drift.leftOuterJoin(_db.staffMembers, _db.staffMembers.id.equalsExp(_db.activityLogs.staffId)),
      ]);

      if (staffId != null) {
        query.where(_db.activityLogs.staffId.equals(staffId));
      }
      if (actionType != null) {
        query.where(_db.activityLogs.actionType.equals(actionType.name));
      }

      query.orderBy([drift.OrderingTerm.desc(_db.activityLogs.timestamp)]);
      query.limit(limit, offset: offset);

      final results = await query.get();

      final logs = results.map((row) {
        final log = row.readTable(_db.activityLogs);
        final staff = row.readTableOrNull(_db.staffMembers);
        
        return ActivityLog(
          id: log.id,
          staffId: log.staffId,
          staffName: staff?.name,
          actionType: log.actionType,
          description: log.description,
          timestamp: log.timestamp,
        );
      }).toList();

      return Right(logs);
    } catch (e, st) {
      return Left(Failure('Failed to fetch activity logs', error: e, stackTrace: st));
    }
  }
}
