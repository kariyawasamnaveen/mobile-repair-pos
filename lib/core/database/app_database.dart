import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pos_system/core/database/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [AppSettings, Items, StockMovements, ItemImeis, Sales, SaleItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(sales, sales.amountTendered);
          await m.addColumn(sales, sales.changeDue);
        }
        if (from < 3) {
          await m.addColumn(sales, sales.cashierName);
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
    
    // TEMPORARY WIPE FOR LOCAL DEV:
    // This deletes the database file if it exists so it gets recreated fresh
    // with the latest schema, bypassing any corrupted schemaVersion stamps.
    // We should remove this before going to production!
    if (await file.exists()) {
      await file.delete();
    }
    
    return NativeDatabase.createInBackground(file);
  });
}
