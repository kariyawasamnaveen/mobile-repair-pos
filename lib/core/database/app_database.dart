import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pos_system/core/database/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [AppSettings, Items, StockMovements, ItemImeis, Sales, SaleItems, RepairJobs, RepairStatusHistory, RepairJobParts, CreditPayments,  StaffMembers,
  ActivityLogs,
  Suppliers,
  PurchaseOrders,
  PurchaseOrderItems,
  SupplierPayments,
  Branches,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          try { await m.addColumn(sales, sales.amountTendered); } catch (e) { if (!e.toString().contains('duplicate column')) rethrow; }
          try { await m.addColumn(sales, sales.changeDue); } catch (e) { if (!e.toString().contains('duplicate column')) rethrow; }
        }
        if (from < 3) {
          try { await m.addColumn(sales, sales.cashierName); } catch (e) { if (!e.toString().contains('duplicate column')) rethrow; }
        }
        if (from < 4) {
          // Check if table exists before creating to prevent out-of-sync user_version crashes
          final existingTablesResult = await m.database.customSelect("SELECT name FROM sqlite_master WHERE type='table'").get();
          final existingTables = existingTablesResult.map((row) => row.read<String>('name')).toSet();

          if (!existingTables.contains('repair_jobs')) {
            await m.createTable(repairJobs);
          }
          if (!existingTables.contains('repair_status_history')) {
            await m.createTable(repairStatusHistory);
          }
          if (!existingTables.contains('repair_job_parts')) {
            await m.createTable(repairJobParts);
          }
        }
        if (from < 5) {
          final existingTablesResult = await m.database.customSelect("SELECT name FROM sqlite_master WHERE type='table'").get();
          final existingTables = existingTablesResult.map((row) => row.read<String>('name')).toSet();
          if (!existingTables.contains('credit_payments')) {
            await m.createTable(creditPayments);
          }
        }
        if (from < 6) {
          // Added 'qr' to PaymentMethod and CreditPaymentMethod enums.
          // Since they are mapped via textEnum() to SQLite TEXT columns, no DDL changes are required.
        }
        if (from < 7) {
          // Add performance indexes
          await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_sales_customer_phone ON sales(customer_phone);');
          await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales(created_at);');
          await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_repair_jobs_customer_phone ON repair_jobs(customer_phone);');
          await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_repair_jobs_status ON repair_jobs(status);');
          await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_repair_jobs_created_at ON repair_jobs(created_at);');
          await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_credit_payments_customer_phone ON credit_payments(customer_phone);');
        }
        if (from < 8) {
          final existingTablesResult = await m.database.customSelect("SELECT name FROM sqlite_master WHERE type='table'").get();
          final existingTables = existingTablesResult.map((row) => row.read<String>('name')).toSet();
          
          if (!existingTables.contains('staff_members')) {
            await m.createTable(staffMembers);
          }
          if (!existingTables.contains('activity_logs')) {
            await m.createTable(activityLogs);
            await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_activity_logs_staff_id ON activity_logs(staff_id);');
            await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_activity_logs_timestamp ON activity_logs(timestamp);');
          }
        }
        if (from < 9) {
          try { await m.addColumn(sales, sales.taxAmount); } catch (e) { if (!e.toString().contains('duplicate column')) rethrow; }
          try { await m.addColumn(sales, sales.taxRateApplied); } catch (e) { if (!e.toString().contains('duplicate column')) rethrow; }
        }
        if (from < 10) {
          final existingTablesResult = await m.database.customSelect("SELECT name FROM sqlite_master WHERE type='table'").get();
          final existingTables = existingTablesResult.map((row) => row.read<String>('name')).toSet();
          
          if (!existingTables.contains('suppliers')) {
            await m.createTable(suppliers);
          }
          if (!existingTables.contains('purchase_orders')) {
            await m.createTable(purchaseOrders);
            await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier_id ON purchase_orders(supplier_id);');
            await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_purchase_orders_status ON purchase_orders(status);');
          }
          if (!existingTables.contains('purchase_order_items')) {
            await m.createTable(purchaseOrderItems);
          }
          if (!existingTables.contains('supplier_payments')) {
            await m.createTable(supplierPayments);
            await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_supplier_payments_supplier_id ON supplier_payments(supplier_id);');
          }
        }
        if (from < 11) {
          final existingTablesResult = await m.database.customSelect("SELECT name FROM sqlite_master WHERE type='table'").get();
          final existingTables = existingTablesResult.map((row) => row.read<String>('name')).toSet();
          
          if (!existingTables.contains('branches')) {
            await m.createTable(branches);
          }
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
