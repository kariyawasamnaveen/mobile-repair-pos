import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pos_system/core/database/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [AppSettings, Items, StockMovements, ItemImeis, Sales, SaleItems, RepairJobs, RepairStatusHistory, RepairJobParts])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        try {
          if (from < 2) {
            await m.addColumn(sales, sales.amountTendered);
            await m.addColumn(sales, sales.changeDue);
          }
          if (from < 3) {
            await m.addColumn(sales, sales.cashierName);
          }
          if (from < 4) {
            await m.createTable(repairJobs);
            await m.createTable(repairStatusHistory);
            await m.createTable(repairJobParts);
          }
        } catch (e) {
          // Log migration error but allow DB to open so we can surface it
          debugPrint('Migration Error: $e');
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        await customStatement('PRAGMA journal_mode = WAL');
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'pos_system.db'));
    
    return NativeDatabase.createInBackground(file);
  });
}
