import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/core/error/failure.dart';
import 'package:pos_system/features/auth/domain/auth_models.dart';
import 'package:pos_system/providers/app_providers.dart';

import 'package:pos_system/features/settings/data/branch_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(databaseProvider),
    ref.watch(branchRepositoryProvider),
  );
});

class AuthRepository {
  final AppDatabase _db;
  final BranchRepository _branchRepo;
  final _uuid = const Uuid();
  final _random = Random.secure();

  AuthRepository(this._db, this._branchRepo);

  /// Helper to hash a PIN with a given salt
  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode(pin + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Helper to generate a random salt
  String _generateSalt() {
    final values = List<int>.generate(16, (i) => _random.nextInt(256));
    return base64UrlEncode(values);
  }

  /// Converts a Drift entity to a Domain model
  StaffMember _mapToDomain(StaffMemberEntity entity) {
    return StaffMember(
      id: entity.id,
      name: entity.name,
      role: entity.role,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }

  /// Check if ANY staff members exist (used for bootstrapping)
  Future<Either<Failure, bool>> hasAnyStaff() async {
    try {
      final countExp = _db.staffMembers.id.count();
      final query = _db.selectOnly(_db.staffMembers)..addColumns([countExp]);
      final result = await query.map((row) => row.read(countExp)).getSingle();
      return Right((result ?? 0) > 0);
    } catch (e, st) {
      return Left(Failure('Failed to check staff existence', error: e, stackTrace: st));
    }
  }

  /// Bootstrap the initial Owner account
  Future<Either<Failure, StaffMember>> createFirstOwner(String name, String pin) async {
    try {
      final existing = await hasAnyStaff();
      if (existing.isRight() && existing.getRight().toNullable()! == true) {
        return Left(Failure('Staff members already exist. Cannot bootstrap.'));
      }

      final salt = _generateSalt();
      final hash = _hashPin(pin, salt);
      final id = _uuid.v4();

      final entity = StaffMembersCompanion.insert(
        id: id,
        name: name,
        pinHash: hash,
        salt: salt,
        role: StaffRole.owner,
      );

      await _db.into(_db.staffMembers).insert(entity);
      
      // Bootstrap the default branch
      await _branchRepo.bootstrapDefaultBranch();
      
      final inserted = await (_db.select(_db.staffMembers)..where((t) => t.id.equals(id))).getSingle();
      return Right(_mapToDomain(inserted));
    } catch (e, st) {
      return Left(Failure('Failed to create first owner', error: e, stackTrace: st));
    }
  }

  /// Get all active staff members for the login dropdown
  Future<Either<Failure, List<StaffMember>>> getActiveStaff() async {
    try {
      final result = await (_db.select(_db.staffMembers)
            ..where((t) => t.isActive.equals(true))
            ..orderBy([(t) => OrderingTerm(expression: t.name)]))
          .get();
      
      final domainList = result.map(_mapToDomain).toList();
      debugPrint('DEBUG [getActiveStaff]: Found ${domainList.length} active staff members: ${domainList.map((e) => e.name).join(", ")}');
      return Right(domainList);
    } catch (e, st) {
      return Left(Failure('Failed to fetch active staff', error: e, stackTrace: st));
    }
  }

  /// Get all staff members (for Staff Management screen)
  Future<Either<Failure, List<StaffMember>>> getAllStaff() async {
    try {
      final result = await (_db.select(_db.staffMembers)
            ..orderBy([(t) => OrderingTerm(expression: t.name)]))
          .get();
      return Right(result.map(_mapToDomain).toList());
    } catch (e, st) {
      return Left(Failure('Failed to fetch staff list', error: e, stackTrace: st));
    }
  }

  /// Validate PIN and return StaffMember if successful
  Future<Either<Failure, StaffMember>> login(String staffId, String pin) async {
    try {
      final entity = await (_db.select(_db.staffMembers)..where((t) => t.id.equals(staffId))).getSingleOrNull();
      if (entity == null) {
        return Left(Failure('Staff member not found.'));
      }
      if (!entity.isActive) {
        return Left(Failure('Staff member is inactive.'));
      }

      final computedHash = _hashPin(pin, entity.salt);
      if (computedHash != entity.pinHash) {
        return Left(Failure('Incorrect PIN.'));
      }

      return Right(_mapToDomain(entity));
    } catch (e, st) {
      return Left(Failure('Login failed due to an error', error: e, stackTrace: st));
    }
  }

  /// Add a new staff member (Owner only, enforced in UI/provider)
  Future<Either<Failure, StaffMember>> addStaff(String name, String pin, StaffRole role) async {
    try {
      final salt = _generateSalt();
      final hash = _hashPin(pin, salt);
      final id = _uuid.v4();

      final entity = StaffMembersCompanion.insert(
        id: id,
        name: name,
        pinHash: hash,
        salt: salt,
        role: role,
      );

      await _db.into(_db.staffMembers).insert(entity);
      final inserted = await (_db.select(_db.staffMembers)..where((t) => t.id.equals(id))).getSingle();
      return Right(_mapToDomain(inserted));
    } catch (e, st) {
      return Left(Failure('Failed to add staff member', error: e, stackTrace: st));
    }
  }

  /// Edit existing staff member (name, role, active status)
  Future<Either<Failure, StaffMember>> updateStaff(String id, {String? name, StaffRole? role, bool? isActive}) async {
    try {
      final update = StaffMembersCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        role: role != null ? Value(role) : const Value.absent(),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
      );

      await (_db.update(_db.staffMembers)..where((t) => t.id.equals(id))).write(update);
      final updated = await (_db.select(_db.staffMembers)..where((t) => t.id.equals(id))).getSingle();
      return Right(_mapToDomain(updated));
    } catch (e, st) {
      return Left(Failure('Failed to update staff member', error: e, stackTrace: st));
    }
  }

  /// Reset a staff member's PIN
  Future<Either<Failure, Unit>> resetPin(String id, String newPin) async {
    try {
      final salt = _generateSalt();
      final hash = _hashPin(newPin, salt);

      final update = StaffMembersCompanion(
        pinHash: Value(hash),
        salt: Value(salt),
      );

      await (_db.update(_db.staffMembers)..where((t) => t.id.equals(id))).write(update);
      return const Right(unit);
    } catch (e, st) {
      return Left(Failure('Failed to reset PIN', error: e, stackTrace: st));
    }
  }
}
