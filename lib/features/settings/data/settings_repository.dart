import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/error/failure.dart';
import 'package:pos_system/providers/app_providers.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(databaseProvider));
});

class SettingsRepository {
  final AppDatabase _db;

  SettingsRepository(this._db);

  Future<Either<Failure, String?>> getSetting(String key) async {
    try {
      final query = _db.select(_db.appSettings)..where((t) => t.key.equals(key));
      final result = await query.getSingleOrNull();
      return Right(result?.value);
    } catch (e, st) {
      return Left(Failure('Failed to get setting', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, Unit>> setSetting(String key, String value) async {
    try {
      await _db.into(_db.appSettings).insertOnConflictUpdate(
        AppSettingsCompanion(
          key: Value(key),
          value: Value(value),
        ),
      );
      return const Right(unit);
    } catch (e, st) {
      return Left(Failure('Failed to set setting', error: e, stackTrace: st));
    }
  }
}
