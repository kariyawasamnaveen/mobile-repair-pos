import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pos_system/features/settings/presentation/settings_controller.dart';
import 'package:pos_system/features/settings/presentation/branch_management_controller.dart';
import 'package:pos_system/features/reports/presentation/reports_dashboard_screen.dart';
import 'package:pos_system/features/auth/presentation/auth_controller.dart';
import 'package:pos_system/features/auth/presentation/staff_management_screen.dart';
import 'package:pos_system/features/settings/presentation/branch_management_screen.dart';
import 'package:pos_system/features/auth/presentation/activity_log_screen.dart';
import 'package:pos_system/features/settings/data/settings_repository.dart';
import 'package:pos_system/features/suppliers/presentation/supplier_list_screen.dart';
import 'package:pos_system/core/backup/backup_service.dart';
import 'package:pos_system/core/backup/backup_encryption_service.dart';
import 'package:pos_system/features/auth/data/activity_log_repository.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/core/theme/app_theme.dart';
import 'package:pos_system/features/settings/presentation/discount_rules_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _storeNameController = TextEditingController();
  final _storeAddressController = TextEditingController();
  final _storePhoneController = TextEditingController();
  String _defaultReceiptDelivery = 'ask';
  
  bool _isTaxEnabled = false;
  final _taxNameController = TextEditingController();
  final _taxRateController = TextEditingController();
  bool _isTaxInclusive = false;
  bool _taxInitialized = false;

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _storePhoneController.dispose();
    _taxNameController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  Future<void> _saveStoreSettings() async {
    final error = await ref.read(storeSettingsProvider.notifier).saveStoreSettings(
      name: _storeNameController.text,
      address: _storeAddressController.text,
      phone: _storePhoneController.text,
      defaultReceiptDelivery: _defaultReceiptDelivery,
      isTaxEnabled: _isTaxEnabled,
      taxName: _taxNameController.text,
      taxRate: double.tryParse(_taxRateController.text) ?? 0.0,
      isTaxInclusive: _isTaxInclusive,
    );
    if (!mounted) return;
    
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store settings saved successfully!')));
    }
  }

  Future<void> _pickQrImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      final docDir = await getApplicationDocumentsDirectory();
      final fileName = 'qr_payment_${DateTime.now().millisecondsSinceEpoch}${p.extension(pickedFile.path)}';
      final savedImage = await File(pickedFile.path).copy(p.join(docDir.path, fileName));
      
      if (!mounted) return;
      await ref.read(storeSettingsProvider.notifier).updateQrImagePath(savedImage.path);
    }
  }

  Future<void> _removeQrImage() async {
    await ref.read(storeSettingsProvider.notifier).updateQrImagePath(null);
  }

  Future<void> _showRecoveryKeyDialog(BuildContext context, WidgetRef ref) async {
    final key = await ref.read(backupEncryptionServiceProvider).getRecoveryKey();
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recovery Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WARNING: This key encrypts your cloud backups. If you lose this device and do not have this key saved, your backups cannot be restored.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey.shade200,
              child: SelectableText(key, style: const TextStyle(fontFamily: 'monospace')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: key));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
            },
            child: const Text('COPY'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRestoreDialog(BuildContext context) async {
    final backupService = ref.read(backupServiceProvider);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Loading backups...'),
        content: SizedBox(height: 50, child: Center(child: CircularProgressIndicator())),
      ),
    );

    final res = await backupService.listBackups();
    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    res.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message))),
      (backups) {
        if (backups.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No backups found in the cloud.')));
          return;
        }

        showModalBottomSheet(
          context: context,
          builder: (context) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ListTile(
                    title: Text('Select Backup to Restore', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('WARNING: This will replace ALL current data!', style: TextStyle(color: Colors.red)),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: backups.length,
                      itemBuilder: (context, index) {
                        final file = backups[index];
                        final timeString = file.name.replaceAll('backup_', '').replaceAll('.sqlite', '').replaceAll('-', ':').replaceFirst(':', '-').replaceFirst(':', '-');
                        final fileDate = DateTime.tryParse(timeString);
                        
                        return ListTile(
                          leading: const Icon(Icons.cloud_download),
                          title: Text(fileDate != null ? fileDate.toLocal().toString().split('.')[0] : file.name),
                          subtitle: Text('${(file.metadata?['size'] ?? 0) ~/ 1024} KB'),
                          onTap: () {
                            Navigator.pop(context); // Close sheet
                            _confirmRestore(context, file.name);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmRestore(BuildContext context, String fileName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you absolutely sure?', style: TextStyle(color: Colors.red)),
        content: const Text('This will DELETE all current local data and replace it with the selected backup. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RESTORE DATA'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Text('Restoring...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Downloading and applying backup. The app will close after completion.'),
            ],
          ),
        ),
      );

      final res = await ref.read(backupServiceProvider).restoreDatabase(fileName);
      if (!context.mounted) return;
      
      res.fold(
        (failure) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: ${failure.message}')));
        },
        (_) {
          // Success! App state is now inconsistent because DB was swapped underneath Drift.
          // The safest way to handle SQLite file swap in a running app is to crash/exit and let the user restart.
          exit(0);
        },
      );
    }
  }

  Future<void> _showChangeBranchDialog() async {
    final activeBranches = ref.read(branchesProvider).valueOrNull?.where((b) => b.isActive).toList() ?? [];
    
    if (activeBranches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active branches available.')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Current Branch', style: TextStyle(color: Colors.red)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'WARNING: Changing the branch will associate all future transactions on this device to the newly selected branch. This should only be done if you are physically relocating this device to another branch.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...activeBranches.map((branch) => ListTile(
                title: Text(branch.name),
                subtitle: Text(branch.address ?? ''),
                onTap: () async {
                  Navigator.pop(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  await ref.read(settingsRepositoryProvider).setCurrentBranchId(branch.id);
                  ref.invalidate(currentBranchProvider);
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(SnackBar(content: Text('Branch changed to ${branch.name}')));
                  }
                },
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(storeSettingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Switch User / Logout',
            onPressed: () async {
              final user = ref.read(authStateProvider);
              if (user != null) {
                await ref.read(activityLogRepositoryProvider).logAction(
                  staffId: user.id,
                  actionType: ActivityActionType.staff_login,
                  description: 'Logged out',
                );
              }
              ref.read(authStateProvider.notifier).state = null;
            },
          ),
        ],
      ),
      body: settingsState.when(
        data: (settings) {
          if (_storeNameController.text.isEmpty && settings.name != null) {
            _storeNameController.text = settings.name!;
          }
          if (_storeAddressController.text.isEmpty && settings.address != null) {
            _storeAddressController.text = settings.address!;
          }
          if (_storePhoneController.text.isEmpty && settings.phone != null) {
            _storePhoneController.text = settings.phone!;
          }
          if (settings.defaultReceiptDelivery != null) {
            _defaultReceiptDelivery = settings.defaultReceiptDelivery!;
          }
          
          if (!_taxInitialized) {
            _isTaxEnabled = settings.isTaxEnabled ?? false;
            _taxNameController.text = settings.taxName ?? 'VAT';
            _taxRateController.text = (settings.taxRate ?? 0.0).toString();
            _isTaxInclusive = settings.isTaxInclusive ?? false;
            _taxInitialized = true;
          }
          
          final isOwner = ref.watch(authStateProvider)?.isOwner == true;

          return ListView(
            padding: AppThemeConstants.defaultPadding,
            children: [
              if (!isOwner) ...[
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.person),
                  ),
                  title: Text('Logged in as: ${ref.watch(authStateProvider)?.name}', style: theme.textTheme.titleMedium),
                  subtitle: Text('Role: ${ref.watch(authStateProvider)?.role.name.toUpperCase()}', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
                const Divider(),
              ],

              if (isOwner) ...[
                Card(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                child: ListTile(
                  leading: Icon(Icons.analytics, color: theme.colorScheme.primary),
                  title: Text('Reports & Analytics', style: theme.textTheme.titleMedium),
                  subtitle: Text('View sales, repairs, and inventory performance', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportsDashboardScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppThemeConstants.spacing24),
              if (isOwner) ...[
                Text('Current Installation Branch', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppThemeConstants.spacing12),
                Consumer(
                  builder: (context, ref, child) {
                    final currentBranchAsync = ref.watch(currentBranchProvider);
                    return Card(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: ListTile(
                        leading: Icon(Icons.store, color: theme.colorScheme.primary),
                        title: currentBranchAsync.when(
                          data: (b) => Text(b?.name ?? 'Not Set', style: const TextStyle(fontWeight: FontWeight.bold)),
                          loading: () => const Text('Loading...'),
                          error: (err, stack) => const Text('Error loading branch'),
                        ),
                        subtitle: const Text('Transactions on this device are attributed to this branch.'),
                        trailing: OutlinedButton(
                          onPressed: _showChangeBranchDialog,
                          child: const Text('Change'),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppThemeConstants.spacing24),
              ],
              Text('Store Profile', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppThemeConstants.spacing12),
              TextField(
                controller: _storeNameController,
                decoration: const InputDecoration(
                  labelText: 'Store Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppThemeConstants.spacing16),
              TextField(
                controller: _storeAddressController,
                decoration: const InputDecoration(
                  labelText: 'Store Address',
                ),
              ),
              const SizedBox(height: AppThemeConstants.spacing16),
              TextField(
                controller: _storePhoneController,
                decoration: const InputDecoration(
                  labelText: 'Store Phone',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppThemeConstants.spacing16),
              DropdownButtonFormField<String>(
                initialValue: _defaultReceiptDelivery,
                decoration: const InputDecoration(
                  labelText: 'Default Receipt Delivery',
                ),
                items: const [
                  DropdownMenuItem(value: 'ask', child: Text('Ask each time')),
                  DropdownMenuItem(value: 'print', child: Text('Print by default')),
                  DropdownMenuItem(value: 'sms', child: Text('SMS by default')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _defaultReceiptDelivery = val;
                    });
                  }
                },
              ),
              const SizedBox(height: AppThemeConstants.spacing24),
              Text('Payment QR Code', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppThemeConstants.spacing12),
              if (settings.qrPaymentImagePath != null && settings.qrPaymentImagePath!.isNotEmpty) ...[
                Center(
                  child: Image.file(
                    File(settings.qrPaymentImagePath!),
                    height: 200,
                    cacheHeight: 400,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Text('Error loading image'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Change'),
                      onPressed: _pickQrImage,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Remove', style: TextStyle(color: Colors.red)),
                      onPressed: _removeQrImage,
                    ),
                  ],
                ),
              ] else ...[
                Card(
                  child: ListTile(
                    leading: Icon(Icons.qr_code, color: theme.colorScheme.onSurfaceVariant),
                    title: Text('No QR Code configured', style: theme.textTheme.titleSmall),
                    subtitle: Text('Upload a static payment QR for customers to scan.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    trailing: FilledButton.tonal(
                      onPressed: _pickQrImage,
                      child: const Text('Upload'),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppThemeConstants.spacing24),
              Text('Tax Settings', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppThemeConstants.spacing12),
              SwitchListTile(
                title: const Text('Enable Tax Calculation'),
                value: _isTaxEnabled,
                onChanged: (val) => setState(() => _isTaxEnabled = val),
              ),
              if (_isTaxEnabled) ...[
                const SizedBox(height: AppThemeConstants.spacing12),
                TextField(
                  controller: _taxNameController,
                  decoration: const InputDecoration(labelText: 'Tax Name (e.g. VAT)'),
                ),
                const SizedBox(height: AppThemeConstants.spacing16),
                TextField(
                  controller: _taxRateController,
                  decoration: const InputDecoration(labelText: 'Tax Rate (%)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: AppThemeConstants.spacing16),
                SwitchListTile(
                  title: const Text('Tax-inclusive pricing'),
                  subtitle: const Text('Inclusive: item prices already include tax (tax is extracted from the total).\nExclusive: tax is added on top of the subtotal.'),
                  value: _isTaxInclusive,
                  onChanged: (val) => setState(() => _isTaxInclusive = val),
                ),
              ],

              const SizedBox(height: AppThemeConstants.spacing24),
              const Divider(),
              Text('Suppliers & Purchasing', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppThemeConstants.spacing12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.local_shipping),
                  title: const Text('Manage Suppliers & POs'),
                  subtitle: const Text('View suppliers, purchase orders, and record supplier payments.'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierListScreen()));
                  },
                ),
              ),
              
              const SizedBox(height: AppThemeConstants.spacing24),
              const Divider(),
              Text('Pricing & Discounts', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppThemeConstants.spacing12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.local_offer),
                  title: const Text('Manage Discounts & Promotions'),
                  subtitle: const Text('Create and manage automated discount rules.'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscountRulesScreen()));
                  },
                ),
              ),

              const SizedBox(height: AppThemeConstants.spacing24),
              const Divider(),
              Text('Database Backup', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppThemeConstants.spacing12),
              Card(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Padding(
                  padding: AppThemeConstants.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Last Backup: ${settings.lastBackupAt != null ? settings.lastBackupAt!.toLocal().toString().split('.')[0] : 'Never'}',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppThemeConstants.spacing8),
                      Text(
                        'Backups are securely encrypted and stored in the cloud. They can only be restored with your recovery key on this device.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppThemeConstants.spacing12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.key),
                        label: const Text('View Recovery Key'),
                        onPressed: () => _showRecoveryKeyDialog(context, ref),
                      ),
                      const SizedBox(height: AppThemeConstants.spacing16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.cloud_upload),
                              label: const Text('Backup Now'),
                              onPressed: () async {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Starting backup...')));
                                final res = await ref.read(backupServiceProvider).backupDatabase();
                                if (mounted) {
                                  res.fold(
                                    (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message))),
                                    (_) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup successful!')));
                                      // Force reload settings to show new timestamp
                                      ref.read(storeSettingsProvider.notifier).loadStoreSettings();
                                    },
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.restore),
                              label: const Text('Restore'),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                              onPressed: () => _showRestoreDialog(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ),
                ),
              ], // End of if (isOwner) ...[

              if (isOwner) ...[
                const SizedBox(height: AppThemeConstants.spacing24),
                Text('Admin Controls', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppThemeConstants.spacing12),
                Card(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.people, color: theme.colorScheme.primary),
                        title: Text('Staff Management', style: theme.textTheme.titleSmall),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffManagementScreen()));
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.storefront, color: theme.colorScheme.primary),
                        title: Text('Branch Management', style: theme.textTheme.titleSmall),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const BranchManagementScreen()));
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.history, color: theme.colorScheme.primary),
                        title: Text('Activity Log', style: theme.textTheme.titleSmall),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityLogScreen()));
                        },
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppThemeConstants.spacing24),
              ElevatedButton(
                onPressed: _saveStoreSettings,
                child: const Text('Save Settings'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
