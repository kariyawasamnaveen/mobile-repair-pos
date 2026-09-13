import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/core/backup/storage_path_builder.dart';

void main() {
  group('Business Account ID Isolation', () {
    test('buildBackupPath correctly prefixes with businessAccountId', () {
      final path = StoragePathBuilder.buildBackupPath('BIZ-123', 'INSTALL-456', 'backup_1.enc');
      expect(path, equals('business_accounts/BIZ-123/backups/INSTALL-456/backup_1.enc'));
      
      // Verify it cannot access another biz id
      expect(path.startsWith('business_accounts/OTHER-BIZ/'), isFalse);
    });

    test('buildBackupDirectoryPath correctly prefixes with businessAccountId', () {
      final path = StoragePathBuilder.buildBackupDirectoryPath('BIZ-123', 'INSTALL-456');
      expect(path, equals('business_accounts/BIZ-123/backups/INSTALL-456'));
    });

    test('buildRegistryFilePath correctly prefixes with businessAccountId', () {
      final path = StoragePathBuilder.buildRegistryFilePath('BIZ-123', 'INSTALL-456');
      expect(path, equals('business_accounts/BIZ-123/branch_registry/INSTALL-456.json'));
    });

    test('buildRegistryDirectoryPath correctly prefixes with businessAccountId', () {
      final path = StoragePathBuilder.buildRegistryDirectoryPath('BIZ-123');
      expect(path, equals('business_accounts/BIZ-123/branch_registry'));
    });

    test('buildSummaryFilePath correctly prefixes with businessAccountId', () {
      final path = StoragePathBuilder.buildSummaryFilePath('BIZ-123', 'INSTALL-456', '2026-09');
      expect(path, equals('business_accounts/BIZ-123/branch_summaries/INSTALL-456/summary_2026-09.json'));
    });
  });
}
