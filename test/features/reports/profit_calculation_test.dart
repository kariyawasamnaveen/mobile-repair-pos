import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/features/reports/data/reports_repository.dart';
import 'package:pos_system/features/reports/domain/reports_models.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase database;
  late ReportsRepository repository;
  final uuid = const Uuid();
  late String branchId;
  late DateTime now;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = ReportsRepository(database);
    now = DateTime.now();
    branchId = uuid.v4();
    await database.into(database.branches).insert(
      BranchesCompanion.insert(id: branchId, name: 'Main', address: const Value('123 Main'), isActive: const Value(true), createdAt: Value(now)),
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('Profit Calculation Logic', () {
    test('Basic profit calculation (no discount)', () async {
      // Create an item with cost=100
      final itemId = uuid.v4();
      await database.into(database.items).insert(
        ItemsCompanion.insert(
          id: itemId,
          name: 'Test Item',
          internalCode: 'ITM001',
          category: ItemCategory.accessory,
          purchasePrice: 100.0,
          sellingPrice: 150.0,
          branchId: Value(branchId),
        ),
      );

      // Create a sale for 2 items (revenue = 300, cost = 200, profit = 100)
      final saleId = uuid.v4();
      await database.into(database.sales).insert(
        SalesCompanion.insert(
          id: saleId,
          subtotal: 300.0, // Pre-tax
          total: 300.0,
          paymentMethod: PaymentMethod.cash,
          amountPaid: 300.0,
          createdAt: Value(now),
          branchId: Value(branchId),
        ),
      );

      await database.into(database.saleItems).insert(
        SaleItemsCompanion.insert(
          saleId: saleId,
          itemId: itemId,
          quantitySold: 2,
          unitPriceAtSale: 150.0,
          purchasePriceAtSale: const Value(100.0), // Proper historical record
        ),
      );

      final range = DateRange(now.subtract(const Duration(days: 1)), now.add(const Duration(days: 1)));
      final result = await repository.getDashboardSummary(range);
      
      final summary = result.getOrElse((_) => throw Exception('Failed'));
      
      expect(summary.totalSalesRevenue, equals(300.0));
      expect(summary.totalSalesProfit, equals(100.0)); // (300) - (100 * 2) = 100
    });

    test('Profit calculation with discount applied', () async {
      final itemId = uuid.v4();
      await database.into(database.items).insert(
        ItemsCompanion.insert(
          id: itemId,
          name: 'Test Item',
          internalCode: 'ITM002',
          category: ItemCategory.accessory,
          purchasePrice: 100.0,
          sellingPrice: 150.0,
        ),
      );

      final saleId = uuid.v4();
      await database.into(database.sales).insert(
        SalesCompanion.insert(
          id: saleId,
          subtotal: 300.0, 
          discount: const Value(30.0), // Discount of 30
          total: 270.0,
          paymentMethod: PaymentMethod.cash,
          amountPaid: 270.0,
          createdAt: Value(now),
        ),
      );

      await database.into(database.saleItems).insert(
        SaleItemsCompanion.insert(
          saleId: saleId,
          itemId: itemId,
          quantitySold: 2,
          unitPriceAtSale: 150.0,
          purchasePriceAtSale: const Value(100.0),
        ),
      );

      final result = await repository.getDashboardSummary(DateRange(now.subtract(const Duration(days: 1)), now.add(const Duration(days: 1))));
      final summary = result.getOrElse((_) => throw Exception('Failed'));
      
      // Revenue = 270, COGS = 200, Profit = 70
      expect(summary.totalSalesProfit, equals(70.0));
    });

    test('Profit calculation excludes tax', () async {
      final itemId = uuid.v4();
      await database.into(database.items).insert(
        ItemsCompanion.insert(
          id: itemId,
          name: 'Test Item',
          internalCode: 'ITM003',
          category: ItemCategory.accessory,
          purchasePrice: 100.0,
          sellingPrice: 150.0,
        ),
      );

      final saleId = uuid.v4();
      await database.into(database.sales).insert(
        SalesCompanion.insert(
          id: saleId,
          subtotal: 150.0, // Pre-tax
          taxAmount: const Value(15.0), // 10% tax
          total: 165.0, // Post-tax
          paymentMethod: PaymentMethod.cash,
          amountPaid: 165.0,
          createdAt: Value(now),
        ),
      );

      await database.into(database.saleItems).insert(
        SaleItemsCompanion.insert(
          saleId: saleId,
          itemId: itemId,
          quantitySold: 1,
          unitPriceAtSale: 150.0,
          purchasePriceAtSale: const Value(100.0),
        ),
      );

      final result = await repository.getDashboardSummary(DateRange(now.subtract(const Duration(days: 1)), now.add(const Duration(days: 1))));
      final summary = result.getOrElse((_) => throw Exception('Failed'));
      
      // Revenue (pre-tax) = 150, COGS = 100, Profit = 50. Tax is ignored.
      expect(summary.totalSalesProfit, equals(50.0));
      expect(summary.totalTaxCollected, equals(15.0));
    });

    test('Negative margin case', () async {
      final itemId = uuid.v4();
      await database.into(database.items).insert(
        ItemsCompanion.insert(
          id: itemId,
          name: 'Loss Leader',
          internalCode: 'ITM004',
          category: ItemCategory.accessory,
          purchasePrice: 200.0,
          sellingPrice: 150.0,
        ),
      );

      final saleId = uuid.v4();
      await database.into(database.sales).insert(
        SalesCompanion.insert(
          id: saleId,
          subtotal: 150.0, 
          total: 150.0,
          paymentMethod: PaymentMethod.cash,
          amountPaid: 150.0,
          createdAt: Value(now),
        ),
      );

      await database.into(database.saleItems).insert(
        SaleItemsCompanion.insert(
          saleId: saleId,
          itemId: itemId,
          quantitySold: 1,
          unitPriceAtSale: 150.0,
          purchasePriceAtSale: const Value(200.0), // Sold below cost
        ),
      );

      final result = await repository.getDashboardSummary(DateRange(now.subtract(const Duration(days: 1)), now.add(const Duration(days: 1))));
      final summary = result.getOrElse((_) => throw Exception('Failed'));
      
      expect(summary.totalSalesProfit, equals(-50.0));
    });

    test('Repair job profit calculation with parts used', () async {
      final itemId = uuid.v4();
      await database.into(database.items).insert(
        ItemsCompanion.insert(
          id: itemId,
          name: 'Screen Replacement',
          internalCode: 'ITM005',
          category: ItemCategory.sparePart,
          purchasePrice: 50.0,
          sellingPrice: 100.0,
        ),
      );

      final jobId = uuid.v4();
      await database.into(database.repairJobs).insert(
        RepairJobsCompanion.insert(
          id: jobId,
          jobNumber: 'RJ-001',
          customerName: 'Test',
          customerPhone: '123',
          reportedIssue: 'Broken Screen',
          deviceConditionNotes: '',
          status: RepairJobStatus.delivered,
          finalCost: const Value(150.0), // Charged 150 for parts + labor
          deliveredAt: Value(now),
        ),
      );

      await database.into(database.repairJobParts).insert(
        RepairJobPartsCompanion.insert(
          jobId: jobId,
          itemId: itemId,
          quantityUsed: 1,
          unitPrice: 100.0,
          purchasePriceAtUsage: const Value(50.0),
        ),
      );

      final result = await repository.getDashboardSummary(DateRange(now.subtract(const Duration(days: 1)), now.add(const Duration(days: 1))));
      final summary = result.getOrElse((_) => throw Exception('Failed'));
      
      // Revenue = 150, Parts Cost = 50, Profit = 100
      expect(summary.totalRepairProfit, equals(100.0));
    });

    test('Profit margin percentage calculation', () {
      final summary = DashboardSummary(
        totalSalesRevenue: 1000,
        totalTransactions: 10,
        totalRepairRevenue: 500,
        totalTaxCollected: 0,
        outstandingCredit: 0,
        totalOwedToSuppliers: 0,
        lowStockItemsCount: 0,
        totalDiscounts: 0,
        totalSalesProfit: 400,
        totalRepairProfit: 350,
      );

      expect(summary.totalProfit, equals(750.0));
      expect(summary.totalRevenue, equals(1500.0));
      expect(summary.profitMarginPercentage, equals(50.0)); // 750 / 1500 * 100
    });
  });
}
