import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/core/error/failure.dart';
import 'package:pos_system/features/repair_jobs/data/repair_jobs_repository.dart';
import 'package:pos_system/features/repair_jobs/domain/repair_job.dart';
import 'package:pos_system/features/inventory/presentation/inventory_controller.dart';

final repairJobsListProvider = FutureProvider.autoDispose<List<RepairJob>>((ref) async {
  final repo = ref.watch(repairJobsRepositoryProvider);
  final result = await repo.getRepairJobs();
  return result.getOrElse((l) => throw l.message);
});

final repairJobDetailProvider = FutureProvider.family.autoDispose<RepairJob, String>((ref, id) async {
  final repo = ref.watch(repairJobsRepositoryProvider);
  final result = await repo.getRepairJobById(id);
  return result.getOrElse((l) => throw l.message);
});

final repairJobsControllerProvider = Provider<RepairJobsController>((ref) {
  return RepairJobsController(ref.watch(repairJobsRepositoryProvider), ref);
});

class RepairJobsController {
  final RepairJobsRepository _repository;
  final Ref _ref;

  RepairJobsController(this._repository, this._ref);

  Future<Either<Failure, RepairJob>> createRepairJob({
    required String customerName,
    required String customerPhone,
    String? deviceModel,
    String? deviceImei,
    required String reportedIssue,
    required String deviceConditionNotes,
    double? estimatedCost,
  }) async {
    final res = await _repository.createRepairJob(
      customerName: customerName,
      customerPhone: customerPhone,
      deviceModel: deviceModel,
      deviceImei: deviceImei,
      reportedIssue: reportedIssue,
      deviceConditionNotes: deviceConditionNotes,
      estimatedCost: estimatedCost,
    );
    if (res.isRight()) {
      _ref.invalidate(repairJobsListProvider);
    }
    return res;
  }

  Future<Either<Failure, RepairJob>> updateStatus({
    required String id,
    required RepairJobStatus status,
    String? note,
  }) async {
    final res = await _repository.updateRepairJob(
      id: id,
      newStatus: status,
      statusNote: note,
    );
    if (res.isRight()) {
      _ref.invalidate(repairJobsListProvider);
      _ref.invalidate(repairJobDetailProvider(id));
    }
    return res;
  }
  
  Future<Either<Failure, RepairJob>> updateTechnician({
    required String id,
    required String name,
  }) async {
    final res = await _repository.updateRepairJob(
      id: id,
      assignedTechnicianName: name,
    );
    if (res.isRight()) {
      _ref.invalidate(repairJobsListProvider);
      _ref.invalidate(repairJobDetailProvider(id));
    }
    return res;
  }

  Future<Either<Failure, RepairJob>> updateFinalCost({
    required String id,
    required double cost,
  }) async {
    final res = await _repository.updateRepairJob(
      id: id,
      finalCost: cost,
    );
    if (res.isRight()) {
      _ref.invalidate(repairJobsListProvider);
      _ref.invalidate(repairJobDetailProvider(id));
    }
    return res;
  }

  Future<Either<Failure, Unit>> addSparePart({
    required String jobId,
    required String itemId,
    required int quantity,
  }) async {
    final res = await _repository.addSparePart(jobId: jobId, itemId: itemId, quantity: quantity);
    if (res.isRight()) {
      _ref.invalidate(repairJobDetailProvider(jobId));
      _ref.read(inventoryControllerProvider.notifier).loadItems();
    }
    return res;
  }
}
