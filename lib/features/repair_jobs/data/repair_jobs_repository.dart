import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/core/error/failure.dart';
import 'package:pos_system/features/repair_jobs/domain/repair_job.dart';
import 'package:pos_system/providers/app_providers.dart';
import 'package:uuid/uuid.dart';
import 'package:pos_system/features/repair_jobs/domain/repair_notifier.dart';

import 'package:pos_system/core/sms/sms_gateway.dart';
import 'package:pos_system/features/settings/data/settings_repository.dart';

final repairNotifierProvider = Provider<RepairNotifier>((ref) {
  return RepairSmsNotifier(
    ref.watch(smsGatewayProvider),
    ref.watch(settingsRepositoryProvider),
  );
});

final repairJobsRepositoryProvider = Provider<RepairJobsRepository>((ref) {
  return RepairJobsRepository(
    ref.watch(databaseProvider),
    ref.watch(repairNotifierProvider),
  );
});

class RepairJobsRepository {
  final AppDatabase _db;
  final RepairNotifier _notifier;
  final _uuid = const Uuid();

  RepairJobsRepository(this._db, this._notifier);

  Future<Either<Failure, RepairJob>> createRepairJob({
    required String customerName,
    required String customerPhone,
    String? deviceModel,
    String? deviceImei,
    required String reportedIssue,
    required String deviceConditionNotes,
    double? estimatedCost,
  }) async {
    try {
      final jobId = _uuid.v4();
      final now = DateTime.now();

      return await _db.transaction(() async {
        // Generate RJ-xxxx number
        final countExpr = _db.repairJobs.id.count();
        final query = _db.selectOnly(_db.repairJobs)..addColumns([countExpr]);
        final count = await query.map((row) => row.read(countExpr)).getSingle();
        final jobNumber = 'RJ-${(count! + 1).toString().padLeft(4, '0')}';

        await _db.into(_db.repairJobs).insert(
              RepairJobsCompanion.insert(
                id: jobId,
                jobNumber: jobNumber,
                customerName: customerName,
                customerPhone: customerPhone,
                deviceModel: Value(deviceModel),
                deviceImei: Value(deviceImei),
                reportedIssue: reportedIssue,
                deviceConditionNotes: deviceConditionNotes,
                status: RepairJobStatus.received,
                estimatedCost: Value(estimatedCost),
                createdAt: Value(now),
                statusUpdatedAt: Value(now),
              ),
            );

        await _db.into(_db.repairStatusHistory).insert(
              RepairStatusHistoryCompanion.insert(
                jobId: jobId,
                newStatus: RepairJobStatus.received,
                timestamp: Value(now),
                note: const Value('Job created'),
              ),
            );

        return await getRepairJobById(jobId);
      });
    } catch (e, st) {
      return Left(Failure('Failed to create repair job', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, List<RepairJob>>> getRepairJobs() async {
    try {
      final query = _db.select(_db.repairJobs)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
      final rows = await query.get();
      final jobs = <RepairJob>[];
      for (final row in rows) {
        final jobEither = await getRepairJobById(row.id);
        jobEither.map((job) => jobs.add(job));
      }
      return Right(jobs);
    } catch (e, st) {
      return Left(Failure('Failed to load repair jobs', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, RepairJob>> getRepairJobById(String id) async {
    try {
      final jobRow = await (_db.select(_db.repairJobs)..where((t) => t.id.equals(id))).getSingle();
      
      // Get history
      final historyRows = await (_db.select(_db.repairStatusHistory)
            ..where((t) => t.jobId.equals(id))
            ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
          .get();
          
      final history = historyRows.map((r) => RepairStatusHistoryEntry(
        id: r.id,
        previousStatus: r.previousStatus,
        newStatus: r.newStatus,
        note: r.note,
        timestamp: r.timestamp,
      )).toList();

      // Get parts
      final partsQuery = _db.select(_db.repairJobParts).join([
        innerJoin(_db.items, _db.items.id.equalsExp(_db.repairJobParts.itemId))
      ])..where(_db.repairJobParts.jobId.equals(id));
      
      final partsResult = await partsQuery.get();
      final parts = partsResult.map((res) {
        final part = res.readTable(_db.repairJobParts);
        final item = res.readTable(_db.items);
        return RepairJobPart(
          id: part.id,
          itemId: item.id,
          itemName: item.name,
          quantityUsed: part.quantityUsed,
          unitPrice: part.unitPrice,
        );
      }).toList();

      return Right(RepairJob(
        id: jobRow.id,
        jobNumber: jobRow.jobNumber,
        customerName: jobRow.customerName,
        customerPhone: jobRow.customerPhone,
        deviceModel: jobRow.deviceModel,
        deviceImei: jobRow.deviceImei,
        reportedIssue: jobRow.reportedIssue,
        deviceConditionNotes: jobRow.deviceConditionNotes,
        status: jobRow.status,
        assignedTechnicianName: jobRow.assignedTechnicianName,
        estimatedCost: jobRow.estimatedCost,
        finalCost: jobRow.finalCost,
        createdAt: jobRow.createdAt,
        statusUpdatedAt: jobRow.statusUpdatedAt,
        deliveredAt: jobRow.deliveredAt,
        history: history,
        partsUsed: parts,
      ));
    } catch (e, st) {
      return Left(Failure('Failed to load repair job $id', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, RepairJob>> updateRepairJob({
    required String id,
    RepairJobStatus? newStatus,
    String? assignedTechnicianName,
    double? finalCost,
    String? statusNote,
  }) async {
    try {
      final now = DateTime.now();
      
      return await _db.transaction(() async {
        final currentJob = await (_db.select(_db.repairJobs)..where((t) => t.id.equals(id))).getSingle();
        
        DateTime? deliveredAt = currentJob.deliveredAt;
        if (newStatus == RepairJobStatus.delivered && currentJob.status != RepairJobStatus.delivered) {
          deliveredAt = now;
        }

        await (_db.update(_db.repairJobs)..where((t) => t.id.equals(id))).write(
          RepairJobsCompanion(
            status: newStatus != null ? Value(newStatus) : const Value.absent(),
            assignedTechnicianName: assignedTechnicianName != null ? Value(assignedTechnicianName) : const Value.absent(),
            finalCost: finalCost != null ? Value(finalCost) : const Value.absent(),
            statusUpdatedAt: newStatus != null && newStatus != currentJob.status ? Value(now) : const Value.absent(),
            deliveredAt: deliveredAt != null ? Value(deliveredAt) : const Value.absent(),
          ),
        );

        if (newStatus != null && newStatus != currentJob.status) {
          await _db.into(_db.repairStatusHistory).insert(
                RepairStatusHistoryCompanion.insert(
                  jobId: id,
                  previousStatus: Value(currentJob.status),
                  newStatus: newStatus,
                  note: Value(statusNote),
                  timestamp: Value(now),
                ),
              );
        }

        final updatedEither = await getRepairJobById(id);
        
        // Notify if status changed
        if (newStatus != null && newStatus != currentJob.status) {
          updatedEither.map((job) => _notifier.notifyStatusChange(job));
        }

        return updatedEither;
      });
    } catch (e, st) {
      return Left(Failure('Failed to update repair job', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, Unit>> addSparePart({
    required String jobId,
    required String itemId,
    required int quantity,
  }) async {
    try {
      return await _db.transaction(() async {
        final item = await (_db.select(_db.items)..where((t) => t.id.equals(itemId))).getSingle();
        
        if (item.quantity < quantity) {
          throw Exception('Not enough stock available');
        }

        // Deduct from items
        await (_db.update(_db.items)..where((t) => t.id.equals(itemId))).write(
          ItemsCompanion(quantity: Value(item.quantity - quantity)),
        );

        // Log movement
        await _db.into(_db.stockMovements).insert(
              StockMovementsCompanion.insert(
                itemId: itemId,
                changeAmount: -quantity,
                reason: MovementReason.repairUsage,
              ),
            );

        // Add part to job
        await _db.into(_db.repairJobParts).insert(
              RepairJobPartsCompanion.insert(
                jobId: jobId,
                itemId: itemId,
                quantityUsed: quantity,
                unitPrice: item.sellingPrice,
              ),
            );

        return const Right(unit);
      });
    } catch (e, st) {
      return Left(Failure('Failed to add spare part', error: e, stackTrace: st));
    }
  }
}
