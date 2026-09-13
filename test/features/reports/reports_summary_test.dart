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

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = ReportsRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Reports Repository Dashboard Summary', () {
    test('Calculates total discounts correctly', () async {
      final now = DateTime.now();
      
      // Insert branch to satisfy foreign key
      final branchId = uuid.v4();
      await database.into(database.branches).insert(
        BranchesCompanion.insert(id: branchId, name: 'Main', address: const Value('123 Main'), isActive: const Value(true), createdAt: Value(now)),
      );

      // Insert dummy sales
      await database.into(database.sales).insert(
        SalesCompanion.insert(
          id: uuid.v4(),
          subtotal: 1000.0,
          discount: const Value(200.0),
          total: 800.0,
          paymentMethod: PaymentMethod.cash,
          isCreditSale: const Value(false),
          amountPaid: 800.0,
          balanceDue: const Value(0.0),
          createdAt: Value(now),
          branchId: Value(branchId),
        ),
      );

      await database.into(database.sales).insert(
        SalesCompanion.insert(
          id: uuid.v4(),
          subtotal: 2000.0,
          discount: const Value(50.0),
          total: 1950.0,
          paymentMethod: PaymentMethod.card,
          isCreditSale: const Value(false),
          amountPaid: 1950.0,
          balanceDue: const Value(0.0),
          createdAt: Value(now),
          branchId: Value(branchId),
        ),
      );

      // Test within date range
      final range = DateRange(now.subtract(const Duration(days: 1)), now.add(const Duration(days: 1)));
      final result = await repository.getDashboardSummary(range);
      
      expect(result.isRight(), isTrue);
      
      final summary = result.getOrElse((_) => throw Exception('Failed'));
      
      expect(summary.totalSalesRevenue, equals(2750.0));
      expect(summary.totalTransactions, equals(2));
      expect(summary.totalDiscounts, equals(250.0));
    });
  });
}
