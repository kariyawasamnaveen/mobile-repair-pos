import 'package:flutter/foundation.dart';
import 'package:pos_system/features/repair_jobs/domain/repair_job.dart';
import 'package:pos_system/core/database/tables.dart';

abstract class RepairNotifier {
  Future<void> notifyStatusChange(RepairJob job);
}

class LoggingRepairNotifier implements RepairNotifier {
  @override
  Future<void> notifyStatusChange(RepairJob job) async {
    // Only notify for specific actionable statuses per requirement
    if (job.status == RepairJobStatus.readyForPickup || job.status == RepairJobStatus.delivered) {
      final statusStr = job.status == RepairJobStatus.readyForPickup ? "Ready for Pickup" : "Delivered";
      debugPrint('================ SMS NOTIFICATION STUB ================');
      debugPrint('Would send SMS to: ${job.customerPhone}');
      debugPrint('Message: Hello ${job.customerName}, your repair job ${job.jobNumber} is now $statusStr.');
      debugPrint('=======================================================');
    }
  }
}
