import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/core/scanning/camera_scanner_sheet.dart';
import 'package:pos_system/features/repair_jobs/domain/repair_job.dart';
import 'package:pos_system/features/repair_jobs/presentation/repair_jobs_controller.dart';
import 'package:pos_system/features/inventory/presentation/inventory_controller.dart';
import 'package:pos_system/features/inventory/presentation/item_search_delegate.dart';

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
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
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
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: jobAsync.when(
        data: (job) {
          final isDelivered = job.status == RepairJobStatus.delivered;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.jobNumber, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Customer: ${job.customerName} (${job.customerPhone})'),
                      Text('Device: ${job.deviceModel ?? "N/A"} (IMEI: ${job.deviceImei ?? "N/A"})'),
                      const Divider(),
                      const Text('Issue:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(job.reportedIssue),
                      const SizedBox(height: 8),
                      const Text('Condition:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(job.deviceConditionNotes),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Status & Assignment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<RepairJobStatus>(
                        initialValue: job.status,
                        decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                        items: RepairJobStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                        onChanged: isDelivered ? null : (s) {
                          if (s != null && s != job.status) _updateStatus(job, s);
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _techController..text = job.assignedTechnicianName ?? '',
                              decoration: const InputDecoration(labelText: 'Technician', border: OutlineInputBorder()),
                              enabled: !isDelivered,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isDelivered ? null : () => _updateTech(job),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Spare Parts Used', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      if (job.partsUsed.isEmpty) const Text('No parts used yet.'),
                      for (final part in job.partsUsed)
                        ListTile(
                          title: Text(part.itemName),
                          subtitle: Text('Qty: ${part.quantityUsed} @ ${part.unitPrice}'),
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Costing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Estimated: ${job.estimatedCost ?? "N/A"}'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _costController..text = job.finalCost?.toString() ?? '',
                              decoration: const InputDecoration(labelText: 'Final Cost', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              enabled: !isDelivered,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isDelivered ? null : () => _updateCost(job),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      for (final entry in job.history)
                        ListTile(
                          title: Text('${entry.previousStatus?.name ?? "Created"} -> ${entry.newStatus.name}'),
                          subtitle: Text(entry.timestamp.toString().split('.')[0]),
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
