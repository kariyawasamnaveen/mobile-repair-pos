import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/error/failure.dart';
import 'package:pos_system/features/settings/domain/branch_models.dart';
import 'package:pos_system/providers/app_providers.dart';
import 'package:pos_system/features/settings/data/settings_repository.dart';

final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  return BranchRepository(
    ref.watch(databaseProvider),
    ref.watch(settingsRepositoryProvider),
  );
});

class BranchRepository {
  final AppDatabase _db;
  final SettingsRepository _settings;
  final _uuid = const Uuid();

  BranchRepository(this._db, this._settings);

  Branch _mapToDomain(BranchEntity entity) {
    return Branch(
      id: entity.id,
      name: entity.name,
      address: entity.address,
      phone: entity.phone,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }

  Future<Either<Failure, List<Branch>>> getAllBranches() async {
    try {
      final result = await (_db.select(_db.branches)
            ..orderBy([(t) => OrderingTerm(expression: t.name)]))
          .get();
      return Right(result.map(_mapToDomain).toList());
    } catch (e, st) {
      return Left(Failure('Failed to fetch branches', error: e, stackTrace: st));
    }
  }
  
  Future<Either<Failure, List<Branch>>> getActiveBranches() async {
    try {
      final result = await (_db.select(_db.branches)
            ..where((t) => t.isActive.equals(true))
            ..orderBy([(t) => OrderingTerm(expression: t.name)]))
          .get();
      return Right(result.map(_mapToDomain).toList());
    } catch (e, st) {
      return Left(Failure('Failed to fetch active branches', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, Branch>> addBranch({
    required String name,
    String? address,
    String? phone,
  }) async {
    try {
      final id = _uuid.v4();
      final entity = BranchesCompanion.insert(
        id: id,
        name: name,
        address: Value(address),
        phone: Value(phone),
      );

      await _db.into(_db.branches).insert(entity);
      final inserted = await (_db.select(_db.branches)..where((t) => t.id.equals(id))).getSingle();
      return Right(_mapToDomain(inserted));
    } catch (e, st) {
      return Left(Failure('Failed to add branch', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, Branch>> updateBranch({
    required String id,
    String? name,
    String? address,
    String? phone,
    bool? isActive,
  }) async {
    try {
      final companion = BranchesCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        address: address != null ? Value(address) : const Value.absent(),
        phone: phone != null ? Value(phone) : const Value.absent(),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
      );

      await (_db.update(_db.branches)..where((t) => t.id.equals(id))).write(companion);
      final updated = await (_db.select(_db.branches)..where((t) => t.id.equals(id))).getSingle();
      return Right(_mapToDomain(updated));
    } catch (e, st) {
      return Left(Failure('Failed to update branch', error: e, stackTrace: st));
    }
  }

  /// Bootstraps the default Main Branch if no branches exist.
  /// Also sets it as the current branch for this installation.
  Future<Either<Failure, Branch>> bootstrapDefaultBranch() async {
    try {
      final countExp = _db.branches.id.count();
      final query = _db.selectOnly(_db.branches)..addColumns([countExp]);
      final countRes = await query.map((row) => row.read(countExp)).getSingle();
      
      Branch branch;
      if (countRes != null && countRes > 0) {
        // Just return the first one if already bootstrapped
        final existing = await (_db.select(_db.branches)..limit(1)).getSingle();
        branch = _mapToDomain(existing);
      } else {
        final id = _uuid.v4();
        final entity = BranchesCompanion.insert(
          id: id,
          name: 'Main Branch',
        );
        await _db.into(_db.branches).insert(entity);
        final inserted = await (_db.select(_db.branches)..where((t) => t.id.equals(id))).getSingle();
        branch = _mapToDomain(inserted);
      }
      
      // Ensure current_branch_id is set
      final currentBranchIdRes = await _settings.getCurrentBranchId();
      if (currentBranchIdRes.isRight() && currentBranchIdRes.getRight().toNullable() == null) {
        await _settings.setCurrentBranchId(branch.id);
      }
      
      return Right(branch);
    } catch (e, st) {
      return Left(Failure('Failed to bootstrap default branch', error: e, stackTrace: st));
    }
  }
}
