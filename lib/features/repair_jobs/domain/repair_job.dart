import 'package:pos_system/core/database/tables.dart';

class RepairJobPart {
  final int id;
  final String itemId;
  final String itemName;
  final int quantityUsed;
  final double unitPrice;

  const RepairJobPart({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.quantityUsed,
    required this.unitPrice,
  });
}

class RepairStatusHistoryEntry {
  final int id;
  final RepairJobStatus? previousStatus;
  final RepairJobStatus newStatus;
  final String? note;
  final DateTime timestamp;

  const RepairStatusHistoryEntry({
    required this.id,
    this.previousStatus,
    required this.newStatus,
    this.note,
    required this.timestamp,
  });
}

class RepairJob {
  final String id;
  final String jobNumber;
  final String customerName;
  final String customerPhone;
  final String? deviceModel;
  final String? deviceImei;
  final String reportedIssue;
  final String deviceConditionNotes;
  final RepairJobStatus status;
  final String? assignedTechnicianName;
  final double? estimatedCost;
  final double? finalCost;
  final DateTime createdAt;
  final DateTime statusUpdatedAt;
  final DateTime? deliveredAt;
  final List<RepairStatusHistoryEntry> history;
  final List<RepairJobPart> partsUsed;

  const RepairJob({
    required this.id,
    required this.jobNumber,
    required this.customerName,
    required this.customerPhone,
    this.deviceModel,
    this.deviceImei,
    required this.reportedIssue,
    required this.deviceConditionNotes,
    required this.status,
    this.assignedTechnicianName,
    this.estimatedCost,
    this.finalCost,
    required this.createdAt,
    required this.statusUpdatedAt,
    this.deliveredAt,
    required this.history,
    required this.partsUsed,
  });
}
