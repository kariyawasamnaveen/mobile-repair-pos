import 'dart:io';
import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/error/failure.dart';
import 'package:pos_system/features/settings/data/settings_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/providers/app_providers.dart';
import 'package:pos_system/core/backup/backup_encryption_service.dart';
import 'package:pos_system/core/backup/storage_path_builder.dart';
import 'dart:convert';
import 'package:pos_system/core/backup/backup_models.dart';
import 'package:pos_system/features/subscription/domain/subscription_service.dart';
import 'package:pos_system/features/reports/data/reports_repository.dart';
import 'package:pos_system/features/reports/domain/reports_models.dart';
import 'package:pos_system/features/settings/data/branch_repository.dart';
import 'dart:developer' as developer;

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    ref.watch(databaseProvider),
    ref.watch(settingsRepositoryProvider),
    ref.watch(backupEncryptionServiceProvider),
    Supabase.instance.client,
    ref.watch(reportsRepositoryProvider),
    ref.watch(branchRepositoryProvider),
    ref.watch(subscriptionServiceProvider),
  );
});

class BackupService {
  final AppDatabase _db;
  final SettingsRepository _settingsRepository;
  final BackupEncryptionService _encryptionService;
  final SupabaseClient _supabase;
  final ReportsRepository _reportsRepo;
  final BranchRepository _branchRepo;
  final SubscriptionService _subscriptionService;
  
  static const String _bucketName = 'backups';

  BackupService(this._db, this._settingsRepository, this._encryptionService, this._supabase, this._reportsRepo, this._branchRepo, this._subscriptionService);

  Future<Either<Failure, void>> backupDatabase() async {
    try {
      final isActive = await _subscriptionService.isSubscriptionActive();
      if (!isActive) {
        return Left(Failure('Subscription expired - contact support to renew'));
      }
      final bizIdRes = await _settingsRepository.getBusinessAccountId();
      if (bizIdRes.isLeft() || bizIdRes.getRight().toNullable() == null) {
        return Left(Failure('Business Account ID not found. Please set it in Settings.'));
      }
      final bizId = bizIdRes.getRight().toNullable()!;

      final installIdRes = await _settingsRepository.getOrCreateInstallId();
      if (installIdRes.isLeft()) {
        return Left(installIdRes.fold((l) => l, (r) => throw Exception()));
      }
      final installId = installIdRes.getRight().toNullable()!;

      // Force WAL checkpoint to ensure all data is flushed to the main DB file
      await _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');

      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'pos_system.db'));

      if (!await dbFile.exists()) {
        return Left(Failure('Database file not found.'));
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = 'backup_$timestamp.sqlite.enc';
      final storagePath = StoragePathBuilder.buildBackupPath(bizId, installId, fileName);

      // Read DB file, encrypt, and upload
      final plainBytes = await dbFile.readAsBytes();
      final cipherBytes = await _encryptionService.encryptFile(plainBytes);

      await _supabase.storage.from(_bucketName).uploadBinary(
        storagePath,
        Uint8List.fromList(cipherBytes),
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      await _settingsRepository.setLastBackupTime(DateTime.now());
      
      developer.log('Backup successful: $storagePath', name: 'BackupService');

      // Attempt to upload cross-branch reporting summary
      try {
        await _uploadReportingSummary(installId, bizId);
      } catch (e) {
        developer.log('Failed to upload reporting summary', name: 'BackupService', error: e);
      }

      // Cleanup old backups in background (fire and forget)
      _cleanupOldBackups(installId, bizId).ignore();

      return const Right(null);
    } catch (e, st) {
      developer.log('Backup failed', name: 'BackupService', error: e, stackTrace: st);
      return Left(Failure('Failed to backup database: $e'));
    }
  }

  Future<void> _uploadReportingSummary(String installId, String bizId) async {
    final now = DateTime.now();
    final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    
    // Get Branch Name
    String branchName = 'Unknown Branch';
    final branchIdRes = await _settingsRepository.getCurrentBranchId();
    if (branchIdRes.isRight() && branchIdRes.getRight().toNullable() != null) {
      final branchId = branchIdRes.getRight().toNullable()!;
      final branchesRes = await _branchRepo.getAllBranches();
      if (branchesRes.isRight()) {
        final branches = branchesRes.getRight().toNullable() ?? [];
        try {
          final branch = branches.firstWhere((b) => b.id == branchId);
          branchName = branch.name;
        } catch (_) {
          // Keep 'Unknown Branch'
        }
      }
    }

    // Get current month summary
    final startOfMonth = DateTime(now.year, now.month, 1);
    final nextMonth = now.month == 12 ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
    final endOfMonth = nextMonth.subtract(const Duration(seconds: 1));
    
    final summaryRes = await _reportsRepo.getDashboardSummary(DateRange(startOfMonth, endOfMonth));
    if (summaryRes.isLeft()) return;
    
    final summary = summaryRes.getRight().toNullable()!;
    
    final branchSummary = BranchSummary(
      installId: installId,
      branchName: branchName,
      month: monthStr,
      totalSalesRevenue: summary.totalSalesRevenue,
      totalTransactions: summary.totalTransactions,
      totalRepairRevenue: summary.totalRepairRevenue,
      totalTaxCollected: summary.totalTaxCollected,
    );

    final registryEntry = BranchRegistryEntry(
      installId: installId,
      branchName: branchName,
      lastBackupTimestamp: now,
    );

    // Upload Registry
    await _supabase.storage.from(_bucketName).uploadBinary(
      StoragePathBuilder.buildRegistryFilePath(bizId, installId),
      Uint8List.fromList(utf8.encode(jsonEncode(registryEntry.toJson()))),
      fileOptions: const FileOptions(cacheControl: '3600', upsert: true, contentType: 'application/json'),
    );

    // Upload Summary
    await _supabase.storage.from(_bucketName).uploadBinary(
      StoragePathBuilder.buildSummaryFilePath(bizId, installId, monthStr),
      Uint8List.fromList(utf8.encode(jsonEncode(branchSummary.toJson()))),
      fileOptions: const FileOptions(cacheControl: '3600', upsert: true, contentType: 'application/json'),
    );
  }

  Future<Either<Failure, List<FileObject>>> listBackups() async {
    try {
      final bizIdRes = await _settingsRepository.getBusinessAccountId();
      if (bizIdRes.isLeft() || bizIdRes.getRight().toNullable() == null) {
        return Left(Failure('Business Account ID not found. Please set it in Settings.'));
      }
      final bizId = bizIdRes.getRight().toNullable()!;

      final installIdRes = await _settingsRepository.getOrCreateInstallId();
      if (installIdRes.isLeft()) {
        return Left(installIdRes.fold((l) => l, (r) => throw Exception()));
      }
      final installId = installIdRes.getRight().toNullable()!;

      final files = await _supabase.storage.from(_bucketName).list(path: StoragePathBuilder.buildBackupDirectoryPath(bizId, installId));
      
      // Filter only encrypted sqlite files (and old unencrypted ones if any remain)
      final backups = files.where((f) => f.name.endsWith('.sqlite.enc') || f.name.endsWith('.sqlite')).toList();
      // Sort newest first
      backups.sort((a, b) => b.name.compareTo(a.name));
      
      return Right(backups);
    } catch (e, st) {
      developer.log('Failed to list backups', name: 'BackupService', error: e, stackTrace: st);
      return Left(Failure('Failed to list backups: $e'));
    }
  }

  Future<Either<Failure, void>> restoreDatabase(String fileName) async {
    try {
      final bizIdRes = await _settingsRepository.getBusinessAccountId();
      if (bizIdRes.isLeft() || bizIdRes.getRight().toNullable() == null) {
        return Left(Failure('Business Account ID not found. Please set it in Settings.'));
      }
      final bizId = bizIdRes.getRight().toNullable()!;

      final installIdRes = await _settingsRepository.getOrCreateInstallId();
      if (installIdRes.isLeft()) {
        return Left(installIdRes.fold((l) => l, (r) => throw Exception()));
      }
      final installId = installIdRes.getRight().toNullable()!;

      final storagePath = StoragePathBuilder.buildBackupPath(bizId, installId, fileName);
      final bytes = await _supabase.storage.from(_bucketName).download(storagePath);
      // Decrypt if it's an encrypted backup
      List<int> plainBytes;
      if (fileName.endsWith('.enc')) {
        try {
          plainBytes = await _encryptionService.decryptFile(bytes);
        } catch (e) {
          developer.log('Decryption failed', name: 'BackupService', error: e);
          return Left(Failure('Could not decrypt backup — the recovery key may be missing or incorrect.'));
        }
      } else {
        // Fallback for old unencrypted backups
        plainBytes = bytes;
      }

      // Close the current database connection
      await _db.close();

      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'pos_system.db'));
      final walFile = File(p.join(dbFolder.path, 'pos_system.db-wal'));
      final shmFile = File(p.join(dbFolder.path, 'pos_system.db-shm'));

      // Delete WAL and SHM files to prevent corruption with the new main file
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();

      // Overwrite the main DB file
      await dbFile.writeAsBytes(plainBytes, flush: true);

      developer.log('Restore successful: $fileName. App needs to restart.', name: 'BackupService');
      
      return const Right(null);
    } catch (e, st) {
      developer.log('Restore failed', name: 'BackupService', error: e, stackTrace: st);
      return Left(Failure('Failed to restore database: $e'));
    }
  }

  Future<void> _cleanupOldBackups(String installId, String bizId) async {
    try {
      final path = StoragePathBuilder.buildBackupDirectoryPath(bizId, installId);
      final files = await _supabase.storage.from(_bucketName).list(path: path);
      final backups = files.where((f) => f.name.endsWith('.sqlite.enc') || f.name.endsWith('.sqlite')).toList();
      
      if (backups.isEmpty) return;

      final now = DateTime.now();
      final filesToDelete = <String>[];

      for (final file in backups) {
        // Parse date from filename: backup_YYYY-MM-DDTHH-MM-SS.sqlite or .sqlite.enc
        final name = file.name;
        try {
          final timeString = name.replaceAll('backup_', '').replaceAll('.sqlite.enc', '').replaceAll('.sqlite', '').replaceAll('-', ':').replaceFirst(':', '-').replaceFirst(':', '-');
          final fileDate = DateTime.tryParse(timeString);
          if (fileDate != null) {
            final difference = now.difference(fileDate);
            if (difference.inDays >= 7) {
              filesToDelete.add('$path/${file.name}');
            }
          }
        } catch (_) {}
      }

      if (filesToDelete.isNotEmpty) {
        await _supabase.storage.from(_bucketName).remove(filesToDelete);
        developer.log('Cleaned up ${filesToDelete.length} old backups', name: 'BackupService');
      }
    } catch (e, st) {
      developer.log('Cleanup failed', name: 'BackupService', error: e, stackTrace: st);
    }
  }

  // ─── CROSS-BRANCH REPORTING (Phase 3) ──────────────────────────────────────

  Future<Either<Failure, List<BranchRegistryEntry>>> fetchRegistry() async {
    try {
      final bizIdRes = await _settingsRepository.getBusinessAccountId();
      if (bizIdRes.isLeft() || bizIdRes.getRight().toNullable() == null) {
        return Left(Failure('Business Account ID not found. Please set it in Settings.'));
      }
      final bizId = bizIdRes.getRight().toNullable()!;

      final path = StoragePathBuilder.buildRegistryDirectoryPath(bizId);
      final files = await _supabase.storage.from(_bucketName).list(path: path);
      final jsonFiles = files.where((f) => f.name.endsWith('.json')).toList();
      
      List<BranchRegistryEntry> registry = [];
      for (final file in jsonFiles) {
        try {
          final bytes = await _supabase.storage.from(_bucketName).download('$path/${file.name}');
          final jsonStr = utf8.decode(bytes);
          final map = jsonDecode(jsonStr);
          registry.add(BranchRegistryEntry.fromJson(map));
        } catch (e) {
          developer.log('Failed to parse registry entry ${file.name}', name: 'BackupService', error: e);
        }
      }
      return Right(registry);
    } catch (e, st) {
      developer.log('Failed to fetch registry', name: 'BackupService', error: e, stackTrace: st);
      return Left(Failure('Failed to load branch registry: $e'));
    }
  }

  Future<Either<Failure, List<BranchSummary>>> fetchSummaries(String month, List<String> installIds) async {
    try {
      final bizIdRes = await _settingsRepository.getBusinessAccountId();
      if (bizIdRes.isLeft() || bizIdRes.getRight().toNullable() == null) {
        return Left(Failure('Business Account ID not found. Please set it in Settings.'));
      }
      final bizId = bizIdRes.getRight().toNullable()!;

      List<BranchSummary> summaries = [];
      for (final id in installIds) {
        try {
          final path = StoragePathBuilder.buildSummaryFilePath(bizId, id, month);
          final bytes = await _supabase.storage.from(_bucketName).download(path);
          final jsonStr = utf8.decode(bytes);
          final map = jsonDecode(jsonStr);
          summaries.add(BranchSummary.fromJson(map));
        } catch (e) {
          developer.log('Failed to fetch/parse summary for $id ($month)', name: 'BackupService', error: e);
          // We just skip it; it will be treated as "No data available" in UI if missing
        }
      }
      return Right(summaries);
    } catch (e, st) {
      developer.log('Failed to fetch summaries', name: 'BackupService', error: e, stackTrace: st);
      return Left(Failure('Failed to load branch summaries: $e'));
    }
  }
}
