import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/features/repair_jobs/presentation/repair_jobs_controller.dart';
import 'package:pos_system/features/repair_jobs/presentation/new_repair_job_screen.dart';
import 'package:pos_system/features/repair_jobs/presentation/repair_job_detail_screen.dart';
import 'package:pos_system/core/theme/app_theme.dart';

class RepairJobListScreen extends ConsumerStatefulWidget {
  const RepairJobListScreen({super.key});

  @override
  ConsumerState<RepairJobListScreen> createState() => _RepairJobListScreenState();
}

class _RepairJobListScreenState extends ConsumerState<RepairJobListScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(repairJobsListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repair Jobs'),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing8, vertical: AppThemeConstants.spacing8),
            padding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppThemeConstants.radiusInput),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filter,
                icon: Icon(Icons.filter_list, color: theme.colorScheme.onSurfaceVariant),
                dropdownColor: theme.colorScheme.surfaceContainerHighest,
                style: theme.textTheme.bodyMedium,
                items: ['All', 'In Progress', 'Ready', 'Delivered']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _filter = val);
                },
              ),
            ),
          ),
          const SizedBox(width: AppThemeConstants.spacing8),
        ],
      ),
      body: jobsAsync.when(
        data: (jobs) {
          final filteredJobs = jobs.where((job) {
            if (_filter == 'All') return true;
            if (_filter == 'In Progress' && (job.status == RepairJobStatus.diagnosing || job.status == RepairJobStatus.inProgress || job.status == RepairJobStatus.awaitingCustomerApproval)) return true;
            if (_filter == 'Ready' && job.status == RepairJobStatus.readyForPickup) return true;
            if (_filter == 'Delivered' && job.status == RepairJobStatus.delivered) return true;
            return false;
          }).toList();

          if (filteredJobs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.build_circle_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: AppThemeConstants.spacing16),
                  Text('No repair jobs found.', style: theme.textTheme.titleMedium),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing16, vertical: AppThemeConstants.spacing8),
            itemCount: filteredJobs.length,
            itemBuilder: (context, index) {
              final job = filteredJobs[index];
              final days = DateTime.now().difference(job.createdAt).inDays;
              
              Color statusColor = theme.colorScheme.primary;
              if (job.status == RepairJobStatus.delivered) statusColor = AppTheme.successColor;
              if (job.status == RepairJobStatus.awaitingCustomerApproval) statusColor = AppTheme.warningColor;
              if (job.status == RepairJobStatus.cancelled) statusColor = AppTheme.errorColor;

              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing16, vertical: AppThemeConstants.spacing8),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('${job.jobNumber} - ${job.customerName}', style: theme.textTheme.titleMedium),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          job.status.name,
                          style: theme.textTheme.labelSmall?.copyWith(color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: AppThemeConstants.spacing4),
                    child: Text('${job.deviceModel ?? 'Unknown Device'} • ${days}d ago', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ),
                  trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RepairJobDetailScreen(jobId: job.id)));
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const NewRepairJobScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
