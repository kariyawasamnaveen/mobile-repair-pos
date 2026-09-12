class BranchRegistryEntry {
  final String installId;
  final String branchName;
  final DateTime lastBackupTimestamp;

  const BranchRegistryEntry({
    required this.installId,
    required this.branchName,
    required this.lastBackupTimestamp,
  });

  factory BranchRegistryEntry.fromJson(Map<String, dynamic> json) {
    return BranchRegistryEntry(
      installId: json['installId'] as String,
      branchName: json['branchName'] as String,
      lastBackupTimestamp: DateTime.parse(json['lastBackupTimestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'installId': installId,
      'branchName': branchName,
      'lastBackupTimestamp': lastBackupTimestamp.toIso8601String(),
    };
  }
}

class BranchSummary {
  final String installId;
  final String branchName;
  final String month;
  final double totalSalesRevenue;
  final int totalTransactions;
  final double totalRepairRevenue;
  final double totalTaxCollected;

  const BranchSummary({
    required this.installId,
    required this.branchName,
    required this.month,
    required this.totalSalesRevenue,
    required this.totalTransactions,
    required this.totalRepairRevenue,
    required this.totalTaxCollected,
  });

  factory BranchSummary.fromJson(Map<String, dynamic> json) {
    return BranchSummary(
      installId: json['installId'] as String,
      branchName: json['branchName'] as String,
      month: json['month'] as String,
      totalSalesRevenue: (json['totalSalesRevenue'] as num).toDouble(),
      totalTransactions: json['totalTransactions'] as int,
      totalRepairRevenue: (json['totalRepairRevenue'] as num).toDouble(),
      totalTaxCollected: (json['totalTaxCollected'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'installId': installId,
      'branchName': branchName,
      'month': month,
      'totalSalesRevenue': totalSalesRevenue,
      'totalTransactions': totalTransactions,
      'totalRepairRevenue': totalRepairRevenue,
      'totalTaxCollected': totalTaxCollected,
    };
  }
}
