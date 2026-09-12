import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/error/failure.dart';
import 'package:pos_system/providers/app_providers.dart';
import 'package:uuid/uuid.dart';

import 'package:pos_system/features/auth/data/activity_log_repository.dart';
import 'package:pos_system/core/database/tables.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(
    ref.watch(databaseProvider),
    ref.watch(activityLogRepositoryProvider),
  );
});

class SettingsRepository {
  final AppDatabase _db;
  final ActivityLogRepository _activityLogRepo;

  SettingsRepository(this._db, this._activityLogRepo);

  Future<Either<Failure, String?>> getSetting(String key) async {
    try {
      final query = _db.select(_db.appSettings)..where((t) => t.key.equals(key));
      final result = await query.getSingleOrNull();
      return Right(result?.value);
    } catch (e, st) {
      return Left(Failure('Failed to get setting', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, Unit>> setSetting(String key, String value, {String? staffId}) async {
    try {
      await _db.into(_db.appSettings).insertOnConflictUpdate(
        AppSettingsCompanion(
          key: Value(key),
          value: Value(value),
        ),
      );

      // Only log user-facing setting changes, not system stuff like install_id or last_backup
      if (!['install_id', 'last_backup_time', 'supabase_last_sync_timestamp'].contains(key)) {
        final currentBranchRes = await getCurrentBranchId();
        final currentBranchId = currentBranchRes.isRight() ? currentBranchRes.getRight().toNullable() : null;

        await _activityLogRepo.logAction(
          staffId: staffId,
          actionType: ActivityActionType.settings_changed,
          description: 'Updated setting: $key',
          branchId: currentBranchId,
        );
      }

      return const Right(unit);
    } catch (e, st) {
      return Left(Failure('Failed to set setting', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, String>> getOrCreateInstallId() async {
    final existingRes = await getSetting('install_id');
    return existingRes.fold(
      (l) => Left(l),
      (id) async {
        if (id != null && id.isNotEmpty) {
          return Right(id);
        }
        // Generate new UUID
        const uuid = Uuid();
        final newId = uuid.v4();
        final saveRes = await setSetting('install_id', newId);
        return saveRes.fold(
          (l) => Left(l),
          (_) => Right(newId),
        );
      }
    );
  }

  Future<Either<Failure, DateTime?>> getLastBackupTime() async {
    final res = await getSetting('last_backup_at');
    return res.fold(
      (l) => Left(l),
      (val) {
        if (val == null || val.isEmpty) return const Right(null);
        final dt = DateTime.tryParse(val);
        return Right(dt);
      }
    );
  }

  Future<Either<Failure, Unit>> setLastBackupTime(DateTime dt) async {
    return setSetting('last_backup_at', dt.toIso8601String());
  }

  Future<Either<Failure, String?>> getCurrentBranchId() async {
    return getSetting('current_branch_id');
  }

  Future<Either<Failure, Unit>> setCurrentBranchId(String branchId) async {
    return setSetting('current_branch_id', branchId);
  }

  Future<Either<Failure, String?>> getBusinessAccountId() async {
    return getSetting('business_account_id');
  }

  Future<Either<Failure, Unit>> setBusinessAccountId(String id) async {
    return setSetting('business_account_id', id);
  }
}
