import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/error/failure.dart';
import 'package:pos_system/features/reports/domain/reports_models.dart';
import 'package:pos_system/providers/app_providers.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(databaseProvider));
});

class ReportsRepository {
  final AppDatabase _db;
  
  ReportsRepository(this._db);

  Future<Either<Failure, DashboardSummary>> getDashboardSummary(DateRange range) async {
    try {
      final vars = [Variable.withDateTime(range.start), Variable.withDateTime(range.end)];
      
      // 1. Sales revenue & transactions
      final salesRes = await _db.customSelect(
        'SELECT SUM(total) as revenue, COUNT(*) as count FROM sales WHERE created_at >= ? AND created_at <= ?',
        variables: vars,
      ).getSingle();
      final totalSalesRevenue = salesRes.read<double?>('revenue') ?? 0.0;
      final totalTransactions = salesRes.read<int?>('count') ?? 0;
      
      // 2. Repair jobs revenue
      final repairRes = await _db.customSelect(
        'SELECT SUM(final_cost) as repair_revenue FROM repair_jobs WHERE status = ? AND delivered_at >= ? AND delivered_at <= ?',
        variables: [Variable.withString('delivered'), ...vars],
      ).getSingle();
      final totalRepairRevenue = repairRes.read<double?>('repair_revenue') ?? 0.0;
      
      // 3. Outstanding Credit (snapshot)
      final creditRes = await _db.customSelect(
        'SELECT SUM(balance_due) as outstanding FROM sales WHERE is_credit_sale = 1 AND balance_due > 0',
      ).getSingle();
      final outstandingCredit = creditRes.read<double?>('outstanding') ?? 0.0;
      
      // 4. Low stock items count (snapshot)
      final stockRes = await _db.customSelect(
        'SELECT COUNT(*) as low_stock FROM items WHERE quantity <= reorder_level',
      ).getSingle();
      final lowStockCount = stockRes.read<int?>('low_stock') ?? 0;
      
      return Right(DashboardSummary(
        totalSalesRevenue: totalSalesRevenue,
        totalTransactions: totalTransactions,
        totalRepairRevenue: totalRepairRevenue,
        outstandingCredit: outstandingCredit,
        lowStockItemsCount: lowStockCount,
      ));
    } catch (e, st) {
      return Left(Failure('Failed to load dashboard summary', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, SalesBreakdown>> getSalesBreakdown(DateRange range) async {
    try {
      final vars = [Variable.withDateTime(range.start), Variable.withDateTime(range.end)];
      
      // 1. Revenue by method
      final methodRes = await _db.customSelect(
        'SELECT payment_method, SUM(total) as rev FROM sales WHERE created_at >= ? AND created_at <= ? GROUP BY payment_method',
        variables: vars,
      ).get();
      
      final revenueByMethod = <String, double>{};
      for (final row in methodRes) {
        final method = row.read<String>('payment_method');
        final rev = row.read<double?>('rev') ?? 0.0;
        revenueByMethod[method] = rev;
      }
      
      // 2. Top selling items by quantity
      final topQtyRes = await _db.customSelect('''
        SELECT i.name, SUM(si.quantity_sold) as total_qty, SUM(si.quantity_sold * si.unit_price_at_sale) as total_rev
        FROM sale_items si
        JOIN sales s ON si.sale_id = s.id
        JOIN items i ON si.item_id = i.id
        WHERE s.created_at >= ? AND s.created_at <= ?
        GROUP BY si.item_id
        ORDER BY total_qty DESC
        LIMIT 5
      ''', variables: vars).get();
      
      final topByQty = topQtyRes.map((r) => ItemSales(
        itemName: r.read<String>('name'),
        totalQuantity: r.read<int>('total_qty'),
        totalRevenue: r.read<double>('total_rev'),
      )).toList();
      
      // 3. Top selling items by revenue
      final topRevRes = await _db.customSelect('''
        SELECT i.name, SUM(si.quantity_sold) as total_qty, SUM(si.quantity_sold * si.unit_price_at_sale) as total_rev
        FROM sale_items si
        JOIN sales s ON si.sale_id = s.id
        JOIN items i ON si.item_id = i.id
        WHERE s.created_at >= ? AND s.created_at <= ?
        GROUP BY si.item_id
        ORDER BY total_rev DESC
        LIMIT 5
      ''', variables: vars).get();
      
      final topByRev = topRevRes.map((r) => ItemSales(
        itemName: r.read<String>('name'),
        totalQuantity: r.read<int>('total_qty'),
        totalRevenue: r.read<double>('total_rev'),
      )).toList();
      
      return Right(SalesBreakdown(
        revenueByMethod: revenueByMethod,
        topSellingByQuantity: topByQty,
        topSellingByRevenue: topByRev,
      ));
    } catch (e, st) {
      return Left(Failure('Failed to load sales breakdown', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, RepairJobsBreakdown>> getRepairJobsBreakdown(DateRange range) async {
    try {
      final vars = [Variable.withDateTime(range.start), Variable.withDateTime(range.end)];
      
      // 1. Count by status
      final statusRes = await _db.customSelect(
        'SELECT status, COUNT(*) as count FROM repair_jobs WHERE created_at >= ? AND created_at <= ? GROUP BY status',
        variables: vars,
      ).get();
      
      final jobsByStatus = <String, int>{};
      for (final row in statusRes) {
        final status = row.read<String>('status');
        final count = row.read<int>('count');
        jobsByStatus[status] = count;
      }
      
      // 2. Average turnaround time
      final avgRes = await _db.customSelect('''
        SELECT AVG(delivered_at - created_at) as avg_time
        FROM repair_jobs
        WHERE status = 'delivered' AND delivered_at IS NOT NULL AND delivered_at >= ? AND delivered_at <= ?
      ''', variables: vars).getSingle();
      
      // The difference between unix timestamps is in seconds.
      final avgSeconds = avgRes.read<double?>('avg_time');
      Duration? avgTurnaround;
      if (avgSeconds != null && avgSeconds > 0) {
        avgTurnaround = Duration(seconds: avgSeconds.toInt());
      }
      
      return Right(RepairJobsBreakdown(
        jobsByStatus: jobsByStatus,
        averageTurnaroundTime: avgTurnaround,
      ));
    } catch (e, st) {
      return Left(Failure('Failed to load repair jobs breakdown', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, InventoryHealth>> getInventoryHealth() async {
    try {
      final valueRes = await _db.customSelect(
        'SELECT SUM(quantity * purchase_price) as total_val FROM items',
      ).getSingle();
      
      final totalValue = valueRes.read<double?>('total_val') ?? 0.0;
      
      return Right(InventoryHealth(totalValue: totalValue));
    } catch (e, st) {
      return Left(Failure('Failed to load inventory health', error: e, stackTrace: st));
    }
  }
}
