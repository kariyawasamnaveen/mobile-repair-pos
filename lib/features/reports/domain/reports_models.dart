enum DateRangeType { today, thisWeek, thisMonth, custom }

class DateRange {
  final DateTime start;
  final DateTime end;
  
  const DateRange(this.start, this.end);
}

class DashboardSummary {
  final double totalSalesRevenue;
  final int totalTransactions;
  final double totalRepairRevenue;
  final double totalTaxCollected;
  final double outstandingCredit; // snapshot
  final double totalOwedToSuppliers;
  final int lowStockItemsCount; // snapshot
  final double totalDiscounts; // new field
  final double totalSalesProfit;
  final double totalRepairProfit;
  
  const DashboardSummary({
    required this.totalSalesRevenue,
    required this.totalTransactions,
    required this.totalRepairRevenue,
    required this.totalTaxCollected,
    required this.outstandingCredit,
    required this.totalOwedToSuppliers,
    required this.lowStockItemsCount,
    required this.totalDiscounts,
    required this.totalSalesProfit,
    required this.totalRepairProfit,
  });

  double get totalProfit => totalSalesProfit + totalRepairProfit;
  double get totalRevenue => totalSalesRevenue + totalRepairRevenue;
  double get profitMarginPercentage => totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0.0;
}

class SalesBreakdown {
  final Map<String, double> revenueByMethod;
  final List<ItemSales> topSellingByQuantity;
  final List<ItemSales> topSellingByRevenue;
  final List<ItemProfit> topSellingByProfit;
  
  const SalesBreakdown({
    required this.revenueByMethod,
    required this.topSellingByQuantity,
    required this.topSellingByRevenue,
    required this.topSellingByProfit,
  });
}

class ItemSales {
  final String itemName;
  final int totalQuantity;
  final double totalRevenue;
  
  const ItemSales({
    required this.itemName,
    required this.totalQuantity,
    required this.totalRevenue,
  });
}

class ItemProfit {
  final String itemName;
  final double totalProfit;
  
  const ItemProfit({
    required this.itemName,
    required this.totalProfit,
  });
}

class RepairJobsBreakdown {
  final Map<String, int> jobsByStatus;
  final Duration? averageTurnaroundTime;
  
  const RepairJobsBreakdown({
    required this.jobsByStatus,
    required this.averageTurnaroundTime,
  });
}

class InventoryHealth {
  final double totalValue; // snapshot sum of quantity * purchase_price
  
  const InventoryHealth({
    required this.totalValue,
  });
}
