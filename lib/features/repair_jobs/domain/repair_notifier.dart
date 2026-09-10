import 'package:flutter/foundation.dart';
import 'package:pos_system/features/repair_jobs/domain/repair_job.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/core/sms/sms_gateway.dart';
import 'package:pos_system/features/settings/data/settings_repository.dart';

abstract class RepairNotifier {
  Future<void> notifyStatusChange(RepairJob job);
}

class RepairSmsNotifier implements RepairNotifier {
  final SmsGateway _smsGateway;
  final SettingsRepository _settingsRepository;

  RepairSmsNotifier(this._smsGateway, this._settingsRepository);

  static const _readyTemplate = "Hi {customer_name}, your {device_model} repair (Job #{job_number}) is ready for pickup at {store_name}. Total: LKR {final_cost}.";
  static const _deliveredTemplate = "Hi {customer_name}, thank you for choosing {store_name} for your {device_model} repair (Job #{job_number}).";

  @override
  Future<void> notifyStatusChange(RepairJob job) async {
    try {
      if (job.customerPhone.isEmpty) {
        return;
      }

      String? message;
      if (job.status == RepairJobStatus.readyForPickup) {
        message = _readyTemplate;
      } else if (job.status == RepairJobStatus.delivered) {
        message = _deliveredTemplate;
      }

      if (message != null) {
        // Fetch store name
        final storeNameEither = await _settingsRepository.getSetting('store_name').timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw Exception('Timeout fetching store name from database');
          },
        );
        final storeName = storeNameEither.fold((l) => 'Our Store', (r) => r ?? 'Our Store');

        // Replace placeholders
        message = message
            .replaceAll('{customer_name}', job.customerName)
            .replaceAll('{device_model}', job.deviceModel ?? 'device')
            .replaceAll('{job_number}', job.jobNumber)
            .replaceAll('{store_name}', storeName)
            .replaceAll('{final_cost}', (job.finalCost ?? job.estimatedCost ?? 0.0).toStringAsFixed(2));

        // Send SMS
        final result = await _smsGateway.sendSms(toPhone: job.customerPhone, message: message);
        
        // Log errors but don't throw, as SMS failure shouldn't fail the repair update
        result.fold(
          (failure) => debugPrint('SMS Notifier Failed: ${failure.message}'),
          (_) => debugPrint('SMS Notifier Success: Message sent to ${job.customerPhone}'),
        );
      }
    } catch (e) {
      debugPrint('SMS Notifier Exception: $e');
    }
  }
}
