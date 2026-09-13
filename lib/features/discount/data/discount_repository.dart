import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/database/tables.dart' show DiscountScope, DiscountType;
import 'package:pos_system/core/error/failure.dart';
import 'package:pos_system/features/discount/domain/discount_rule.dart';
import 'package:uuid/uuid.dart';

class DiscountRepository {
  final AppDatabase db;
  final _uuid = const Uuid();

  DiscountRepository(this.db);

  /// Retrieves all discount rules, ordered by newest first.
  Future<Either<Failure, List<DiscountRule>>> getDiscountRules() async {
    try {
      final rows = await (db.select(db.discountRules)
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
          .get();
      return Right(rows.map((row) => DiscountRule.fromEntity(row)).toList());
    } catch (e, stackTrace) {
      return Left(Failure('Failed to fetch discount rules: $e', stackTrace: stackTrace));
    }
  }

  /// Retrieves only the active discount rules.
  Future<Either<Failure, List<DiscountRule>>> getActiveDiscountRules() async {
    try {
      final rows = await (db.select(db.discountRules)
            ..where((t) => t.isActive.equals(true))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
          .get();
      return Right(rows.map((row) => DiscountRule.fromEntity(row)).toList());
    } catch (e, stackTrace) {
      return Left(Failure('Failed to fetch active discount rules: $e', stackTrace: stackTrace));
    }
  }

  /// Creates a new discount rule.
  Future<Either<Failure, DiscountRule>> createDiscountRule({
    required String name,
    required DiscountType type,
    required double value,
    required DiscountScope scope,
    String? scopeReference,
    double? minPurchaseAmount,
    DateTime? startDate,
    DateTime? endDate,
    String? branchId,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now();

      final companion = DiscountRulesCompanion.insert(
        id: id,
        name: name,
        type: type,
        value: value,
        scope: scope,
        scopeReference: Value(scopeReference),
        minPurchaseAmount: Value(minPurchaseAmount),
        startDate: Value(startDate),
        endDate: Value(endDate),
        createdAt: Value(now),
        branchId: Value(branchId),
      );

      final row = await db.into(db.discountRules).insertReturning(companion);
      return Right(DiscountRule.fromEntity(row));
    } catch (e, stackTrace) {
      return Left(Failure('Failed to create discount rule: $e', stackTrace: stackTrace));
    }
  }

  /// Updates an existing discount rule.
  Future<Either<Failure, DiscountRule>> updateDiscountRule(
    String id, {
    String? name,
    DiscountType? type,
    double? value,
    DiscountScope? scope,
    String? scopeReference,
    double? minPurchaseAmount,
    bool? isActive,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final companion = DiscountRulesCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        type: type != null ? Value(type) : const Value.absent(),
        value: value != null ? Value(value) : const Value.absent(),
        scope: scope != null ? Value(scope) : const Value.absent(),
        scopeReference: scopeReference != null ? Value(scopeReference) : const Value.absent(),
        minPurchaseAmount: minPurchaseAmount != null ? Value(minPurchaseAmount) : const Value.absent(),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
        startDate: startDate != null ? Value(startDate) : const Value.absent(),
        endDate: endDate != null ? Value(endDate) : const Value.absent(),
      );

      final rowsUpdated = await (db.update(db.discountRules)..where((t) => t.id.equals(id))).write(companion);
      if (rowsUpdated == 0) {
        return Left(Failure('Discount rule not found'));
      }

      final row = await (db.select(db.discountRules)..where((t) => t.id.equals(id))).getSingle();
      return Right(DiscountRule.fromEntity(row));
    } catch (e, stackTrace) {
      return Left(Failure('Failed to update discount rule: $e', stackTrace: stackTrace));
    }
  }

  /// Deactivates a discount rule (soft delete).
  Future<Either<Failure, void>> deactivateDiscountRule(String id) async {
    try {
      await (db.update(db.discountRules)..where((t) => t.id.equals(id))).write(
        const DiscountRulesCompanion(isActive: Value(false)),
      );
      return const Right(null);
    } catch (e, stackTrace) {
      return Left(Failure('Failed to deactivate discount rule: $e', stackTrace: stackTrace));
    }
  }
}
