import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/core/scanning/camera_scanner_sheet.dart';
import 'package:pos_system/features/repair_jobs/domain/repair_job.dart';
import 'package:pos_system/features/repair_jobs/presentation/repair_jobs_controller.dart';
import 'package:pos_system/features/inventory/presentation/inventory_controller.dart';
import 'package:pos_system/features/auth/presentation/auth_controller.dart';
import 'package:pos_system/features/inventory/presentation/item_search_delegate.dart';
import 'package:pos_system/core/theme/app_theme.dart';

class RepairJobDetailScreen extends ConsumerStatefulWidget {
  final String jobId;

  const RepairJobDetailScreen({super.key, required this.jobId});

  @override
  ConsumerState<RepairJobDetailScreen> createState() => _RepairJobDetailScreenState();
}

class _RepairJobDetailScreenState extends ConsumerState<RepairJobDetailScreen> {
  final _techController = TextEditingController();
  final _costController = TextEditingController();

  @override
  void dispose() {
    _techController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _updateStatus(RepairJob job, RepairJobStatus newStatus) async {
    final controller = ref.read(repairJobsControllerProvider);
    final res = await controller.updateStatus(id: job.id, status: newStatus);
    if (!mounted) return;
    if (res.isLeft()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.fold((l) => l.message, (r) => ''))));
    }
  }

  void _updateTech(RepairJob job) async {
    final controller = ref.read(repairJobsControllerProvider);
    final res = await controller.updateTechnician(id: job.id, name: _techController.text);
    if (!mounted) return;
    if (res.isLeft()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.fold((l) => l.message, (r) => ''))));
    }
  }

  void _updateCost(RepairJob job) async {
    final cost = double.tryParse(_costController.text);
    if (cost == null) return;
    final controller = ref.read(repairJobsControllerProvider);
    final res = await controller.updateFinalCost(id: job.id, cost: cost);
    if (!mounted) return;
    if (res.isLeft()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.fold((l) => l.message, (r) => ''))));
    }
  }

  void _addSparePart(RepairJob job) async {
    final item = await showSearch(context: context, delegate: ItemSearchDelegate(ref));
    if (item == null) return;
    
    // Simplistic dialog for quantity
    if (!mounted) return;
    int qty = 1;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add ${item.name}'),
        content: Text('Quantity: 1 (Stock: ${item.quantity})'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (confirm != true) return;

    final controller = ref.read(repairJobsControllerProvider);
    final res = await controller.addSparePart(jobId: job.id, itemId: item.id, quantity: qty);
    if (!mounted) return;
    if (res.isLeft()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.fold((l) => l.message, (r) => ''))));
    }
  }

  /// Scan a part barcode with the camera, resolve it to an inventory item,
  /// then hand off to the same confirmation + add flow as [_addSparePart].
  void _scanAndAddSparePart(RepairJob job) async {
    final scanned = await showCameraScannerSheet(context);
    if (scanned == null || !mounted) return;

    // Look up the item by barcode or internal code from the current inventory list.
    final inventoryAsync = ref.read(inventoryControllerProvider);
    final allItems = inventoryAsync.valueOrNull ?? [];
    final match = allItems.where((i) =>
      i.barcode == scanned || i.internalCode == scanned,
    ).firstOrNull;

    if (!mounted) return;
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No item found for code: $scanned')),
      );
      return;
    }

    // Reuse the same confirmation + repository call as the search-based path.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add ${match.name}'),
        content: Text('Quantity: 1 (Stock: ${match.quantity})'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final controller = ref.read(repairJobsControllerProvider);
    final res = await controller.addSparePart(jobId: job.id, itemId: match.id, quantity: 1);
    if (!mounted) return;
    if (res.isLeft()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.fold((l) => l.message, (r) => ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(repairJobDetailProvider(widget.jobId));
    final isCashier = ref.watch(authStateProvider)?.isCashier == true;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: jobAsync.when(
        data: (job) {
          final isDelivered = job.status == RepairJobStatus.delivered;
          return ListView(
            padding: AppThemeConstants.defaultPadding,
            children: [
              Card(
                child: Padding(
                  padding: AppThemeConstants.defaultPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.jobNumber, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: AppThemeConstants.spacing8),
                      Text('Customer: ${job.customerName} (${job.customerPhone})', style: theme.textTheme.titleMedium),
                      Text('Device: ${job.deviceModel ?? "N/A"} (IMEI: ${job.deviceImei ?? "N/A"})', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      Divider(height: AppThemeConstants.spacing32, color: theme.dividerColor),
                      Text('Issue:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text(job.reportedIssue, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: AppThemeConstants.spacing16),
                      Text('Condition:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text(job.deviceConditionNotes, style: theme.textTheme.bodyLarge),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppThemeConstants.spacing16),
              Card(
                child: Padding(
                  padding: AppThemeConstants.defaultPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status & Assignment', style: theme.textTheme.titleLarge),
                      const SizedBox(height: AppThemeConstants.spacing16),
                      DropdownButtonFormField<RepairJobStatus>(
                        initialValue: job.status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: RepairJobStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                        onChanged: isDelivered ? null : (s) {
                          if (s != null && s != job.status) _updateStatus(job, s);
                        },
                      ),
                      const SizedBox(height: AppThemeConstants.spacing16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _techController..text = job.assignedTechnicianName ?? '',
                              decoration: const InputDecoration(labelText: 'Technician'),
                              enabled: !isDelivered,
                            ),
                          ),
                          const SizedBox(width: AppThemeConstants.spacing8),
                          FilledButton(
                            onPressed: isDelivered ? null : () => _updateTech(job),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppThemeConstants.spacing16),
              Card(
                child: Padding(
                  padding: AppThemeConstants.defaultPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Spare Parts Used', style: theme.textTheme.titleLarge),
                          if (!isDelivered)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Scan part barcode',
                                  icon: const Icon(Icons.qr_code_scanner),
                                  onPressed: () => _scanAndAddSparePart(job),
                                ),
                                TextButton.icon(
                                  onPressed: () => _addSparePart(job),
                                  icon: const Icon(Icons.search),
                                  label: const Text('Search Part'),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (job.partsUsed.isEmpty) 
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppThemeConstants.spacing8),
                          child: Text('No parts used yet.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ),
                      for (final part in job.partsUsed)
                        ListTile(
                          title: Text(part.itemName, style: theme.textTheme.titleMedium),
                          subtitle: Text('Qty: ${part.quantityUsed} @ LKR ${part.unitPrice}', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppThemeConstants.spacing16),
              Card(
                child: Padding(
                  padding: AppThemeConstants.defaultPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Costing', style: theme.textTheme.titleLarge),
                      const SizedBox(height: AppThemeConstants.spacing8),
                      Text('Estimated: LKR ${job.estimatedCost ?? "N/A"}', style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppThemeConstants.spacing16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _costController..text = job.finalCost?.toString() ?? '',
                              decoration: const InputDecoration(labelText: 'Final Cost'),
                              keyboardType: TextInputType.number,
                              enabled: !isDelivered && !isCashier,
                            ),
                          ),
                          const SizedBox(width: AppThemeConstants.spacing8),
                          FilledButton(
                            onPressed: (isDelivered || isCashier) ? null : () => _updateCost(job),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppThemeConstants.spacing16),
              Card(
                child: Padding(
                  padding: AppThemeConstants.defaultPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('History', style: theme.textTheme.titleLarge),
                      for (final entry in job.history)
                        ListTile(
                          title: Text('${entry.previousStatus?.name ?? "Created"} -> ${entry.newStatus.name}', style: theme.textTheme.titleMedium),
                          subtitle: Text(entry.timestamp.toString().split('.')[0], style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
