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
import 'dart:developer' as developer;

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    ref.watch(databaseProvider),
    ref.watch(settingsRepositoryProvider),
    ref.watch(backupEncryptionServiceProvider),
    Supabase.instance.client,
  );
});

class BackupService {
  final AppDatabase _db;
  final SettingsRepository _settingsRepository;
  final BackupEncryptionService _encryptionService;
  final SupabaseClient _supabase;
  
  static const String _bucketName = 'backups';

  BackupService(this._db, this._settingsRepository, this._encryptionService, this._supabase);

  Future<Either<Failure, void>> backupDatabase() async {
    try {
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
      final storagePath = '$installId/$fileName';

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

      // Cleanup old backups in background (fire and forget)
      _cleanupOldBackups(installId).ignore();

      return const Right(null);
    } catch (e, st) {
      developer.log('Backup failed', name: 'BackupService', error: e, stackTrace: st);
      return Left(Failure('Failed to backup database: $e'));
    }
  }

  Future<Either<Failure, List<FileObject>>> listBackups() async {
    try {
      final installIdRes = await _settingsRepository.getOrCreateInstallId();
      if (installIdRes.isLeft()) {
        return Left(installIdRes.fold((l) => l, (r) => throw Exception()));
      }
      final installId = installIdRes.getRight().toNullable()!;

      final files = await _supabase.storage.from(_bucketName).list(path: installId);
      
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
      final installIdRes = await _settingsRepository.getOrCreateInstallId();
      if (installIdRes.isLeft()) {
        return Left(installIdRes.fold((l) => l, (r) => throw Exception()));
      }
      final installId = installIdRes.getRight().toNullable()!;

      final storagePath = '$installId/$fileName';
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

  Future<void> _cleanupOldBackups(String installId) async {
    try {
      final files = await _supabase.storage.from(_bucketName).list(path: installId);
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
              filesToDelete.add('$installId/${file.name}');
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
}
