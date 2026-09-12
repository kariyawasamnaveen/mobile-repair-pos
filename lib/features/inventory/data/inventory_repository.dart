import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/core/error/failure.dart';
import 'package:pos_system/features/inventory/domain/item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/providers/app_providers.dart';
import 'package:pos_system/features/auth/data/activity_log_repository.dart';
import 'package:pos_system/features/settings/data/settings_repository.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(
    ref.watch(databaseProvider),
    ref.watch(activityLogRepositoryProvider),
    ref.watch(settingsRepositoryProvider),
  );
});

class InventoryRepository {
  final AppDatabase _db;
  final ActivityLogRepository _activityLogRepo;
  final SettingsRepository _settings;
  final _uuid = const Uuid();

  InventoryRepository(this._db, this._activityLogRepo, this._settings);

  Future<Either<Failure, String>> _generateInternalCode() async {
    try {
      final query = _db.select(_db.items)
        ..orderBy([(t) => OrderingTerm.desc(t.id)])
        ..limit(1);
      final lastItem = await query.getSingleOrNull();

      if (lastItem == null) return const Right('CAT-0001');

      final lastCode = lastItem.internalCode;
      if (lastCode.startsWith('CAT-')) {
        final numberPart = lastCode.substring(4);
        final number = int.tryParse(numberPart) ?? 0;
        final nextNumber = number + 1;
        return Right('CAT-${nextNumber.toString().padLeft(4, '0')}');
      }
      return Right('CAT-${_uuid.v4().substring(0, 8).toUpperCase()}');
    } catch (e) {
      return Left(Failure('Failed to generate internal code', error: e));
    }
  }

  Future<Either<Failure, List<Item>>> getItems({
    String? search,
    ItemCategory? category,
  }) async {
    try {
      final currentBranchRes = await _settings.getCurrentBranchId();
      final currentBranchId = currentBranchRes.isRight() ? currentBranchRes.getRight().toNullable() : null;

      var query = _db.select(_db.items);

      if (currentBranchId != null) {
        query.where((t) => t.branchId.isNull() | t.branchId.equals(currentBranchId));
      }

      if (search != null && search.isNotEmpty) {
        query.where((t) =>
            t.name.like('%$search%') |
            t.barcode.like('%$search%') |
            t.internalCode.like('%$search%'));
      }

      if (category != null) {
        query.where((t) => t.category.equals(category.name));
      }

      final itemsData = await query.get();
      final items = <Item>[];

      final phoneIds = itemsData
          .where((r) => r.category == ItemCategory.phone)
          .map((r) => r.id)
          .toList();
      final Map<String, List<String>> imeiMap = {};

      if (phoneIds.isNotEmpty) {
        final imeiQuery = _db.select(_db.itemImeis)
          ..where((t) => t.itemId.isIn(phoneIds) & t.isSold.equals(false));
        final imeiRows = await imeiQuery.get();
        for (final row in imeiRows) {
          imeiMap.putIfAbsent(row.itemId, () => []).add(row.imei);
        }
      }

      for (final row in itemsData) {
        List<String> imeis = [];
        int actualQuantity = row.quantity;

        if (row.category == ItemCategory.phone) {
          imeis = imeiMap[row.id] ?? [];
          actualQuantity = imeis.length;
        }

        items.add(Item(
          id: row.id,
          name: row.name,
          internalCode: row.internalCode,
          barcode: row.barcode,
          category: row.category,
          purchasePrice: row.purchasePrice,
          sellingPrice: row.sellingPrice,
          quantity: actualQuantity,
          reorderLevel: row.reorderLevel,
          imeis: imeis,
          branchId: row.branchId,
        ));
      }

      return Right(items);
    } catch (e, st) {
      return Left(Failure('Failed to load items', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, Item>> addItem(Item item, {MovementReason reason = MovementReason.restock, String? staffId}) async {
    try {
      String internalCode = item.internalCode;
      if (internalCode.isEmpty) {
        final codeResult = await _generateInternalCode();
        if (codeResult.isLeft()) return Left(codeResult.fold((l) => l, (r) => throw Exception()));
        internalCode = codeResult.getOrElse((_) => '');
      }

      final itemId = item.id.isEmpty ? _uuid.v4() : item.id;
      final isPhone = item.category == ItemCategory.phone;
      final quantity = isPhone ? item.imeis.length : item.quantity;

      final currentBranchRes = await _settings.getCurrentBranchId();
      final currentBranchId = currentBranchRes.isRight() ? currentBranchRes.getRight().toNullable() : null;

      await _db.transaction(() async {
        await _db.into(_db.items).insert(
              ItemsCompanion(
                id: Value(itemId),
                name: Value(item.name),
                internalCode: Value(internalCode),
                barcode: Value(item.barcode),
                category: Value(item.category),
                purchasePrice: Value(item.purchasePrice),
                sellingPrice: Value(item.sellingPrice),
                quantity: Value(quantity),
                reorderLevel: Value(item.reorderLevel),
                branchId: currentBranchId == null ? const Value.absent() : Value(currentBranchId),
              ),
            );

        if (quantity > 0) {
          await _db.into(_db.stockMovements).insert(
                StockMovementsCompanion(
                  itemId: Value(itemId),
                  changeAmount: Value(quantity),
                  reason: Value(reason),
                  branchId: currentBranchId == null ? const Value.absent() : Value(currentBranchId),
                ),
              );
        }

        if (isPhone && item.imeis.isNotEmpty) {
          for (final imei in item.imeis) {
            await _db.into(_db.itemImeis).insert(
                  ItemImeisCompanion(
                    itemId: Value(itemId),
                    imei: Value(imei),
                  ),
                );
          }
        }
      });

      await _activityLogRepo.logAction(
        staffId: staffId,
        actionType: ActivityActionType.stock_adjusted,
        description: 'Added new item: ${item.name} ($internalCode)',
        branchId: currentBranchId,
      );

      return Right(Item(
        id: itemId,
        name: item.name,
        internalCode: internalCode,
        barcode: item.barcode,
        category: item.category,
        purchasePrice: item.purchasePrice,
        sellingPrice: item.sellingPrice,
        quantity: quantity,
        reorderLevel: item.reorderLevel,
        imeis: item.imeis,
        branchId: currentBranchId,
      ));
    } catch (e, st) {
      return Left(Failure('Failed to add item', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, Unit>> adjustStock(
      String itemId, int changeAmount, MovementReason reason,
      {bool allowNegative = false,
      List<String> imeisToAdd = const [],
      List<String> imeisToRemove = const [],
      String? staffId}) async {
    try {
      await _db.transaction(() async {
        final itemRow = await (_db.select(_db.items)..where((t) => t.id.equals(itemId))).getSingleOrNull();
        if (itemRow == null) throw Exception('Item not found');

        int finalChangeAmount = changeAmount;
        if (itemRow.category == ItemCategory.phone) {
          finalChangeAmount = imeisToAdd.length - imeisToRemove.length;
        }

        final newQuantity = itemRow.quantity + finalChangeAmount;
        if (newQuantity < 0 && !allowNegative) {
          throw Exception('Stock cannot be negative');
        }

        await (_db.update(_db.items)..where((t) => t.id.equals(itemId))).write(
          ItemsCompanion(quantity: Value(newQuantity), updatedAt: Value(DateTime.now())),
        );

        if (finalChangeAmount != 0) {
          final currentBranchRes = await _settings.getCurrentBranchId();
          final currentBranchId = currentBranchRes.isRight() ? currentBranchRes.getRight().toNullable() : null;

          await _db.into(_db.stockMovements).insert(
                StockMovementsCompanion(
                  itemId: Value(itemId),
                  changeAmount: Value(finalChangeAmount),
                  reason: Value(reason),
                  branchId: currentBranchId == null ? const Value.absent() : Value(currentBranchId),
                ),
              );
        }

        for (final imei in imeisToAdd) {
          await _db.into(_db.itemImeis).insert(ItemImeisCompanion(itemId: Value(itemId), imei: Value(imei)));
        }

        for (final imei in imeisToRemove) {
          await (_db.update(_db.itemImeis)..where((t) => t.imei.equals(imei) & t.itemId.equals(itemId)))
              .write(const ItemImeisCompanion(isSold: Value(true)));
        }
      });

      if (changeAmount != 0) {
        final currentBranchRes = await _settings.getCurrentBranchId();
        final currentBranchId = currentBranchRes.isRight() ? currentBranchRes.getRight().toNullable() : null;
        await _activityLogRepo.logAction(
          staffId: staffId,
          actionType: ActivityActionType.stock_adjusted,
          description: 'Adjusted stock for item $itemId by $changeAmount (Reason: ${reason.name})',
          branchId: currentBranchId,
        );
      }

      return const Right(unit);
    } catch (e, st) {
      return Left(Failure('Failed to adjust stock', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, int>> bulkImportCsv(String csvString) async {
    try {
      final rows = csv.decode(csvString);
      if (rows.isEmpty) return const Left(Failure('CSV is empty'));

      final dataRows = rows.skip(1).toList();
      int importedCount = 0;

      await _db.transaction(() async {
        for (final row in dataRows) {
          if (row.length < 6) continue;
          
          final name = row[0].toString();
          final categoryStr = row[1].toString().toLowerCase();
          final purchasePrice = double.tryParse(row[2].toString()) ?? 0.0;
          final sellingPrice = double.tryParse(row[3].toString()) ?? 0.0;
          final quantity = int.tryParse(row[4].toString()) ?? 0;
          final barcode = row[5].toString();

          ItemCategory category = ItemCategory.other;
          if (categoryStr.contains('phone')) {
            category = ItemCategory.phone;
          } else if (categoryStr.contains('accessory')) {
            category = ItemCategory.accessory;
          } else if (categoryStr.contains('spare')) {
            category = ItemCategory.sparePart;
          }

          final item = Item(
            id: '',
            name: name,
            internalCode: '',
            barcode: barcode.isNotEmpty ? barcode : null,
            category: category,
            purchasePrice: purchasePrice,
            sellingPrice: sellingPrice,
            quantity: quantity,
            reorderLevel: 5,
          );

          await addItem(item);
          importedCount++;
        }
      });

      return Right(importedCount);
    } catch (e, st) {
      return Left(Failure('Failed to import CSV', error: e, stackTrace: st));
    }
  }
}
