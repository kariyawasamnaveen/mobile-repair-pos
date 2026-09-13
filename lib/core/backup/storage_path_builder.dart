class StoragePathBuilder {
  static String buildBackupPath(String bizId, String installId, String fileName) {
    return 'business_accounts/$bizId/backups/$installId/$fileName';
  }

  static String buildBackupDirectoryPath(String bizId, String installId) {
    return 'business_accounts/$bizId/backups/$installId';
  }

  static String buildRegistryFilePath(String bizId, String installId) {
    return 'business_accounts/$bizId/branch_registry/$installId.json';
  }

  static String buildRegistryDirectoryPath(String bizId) {
    return 'business_accounts/$bizId/branch_registry';
  }

  static String buildSummaryFilePath(String bizId, String installId, String monthStr) {
    return 'business_accounts/$bizId/branch_summaries/$installId/summary_$monthStr.json';
  }
}
