import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/auth/presentation/activity_log_controller.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:intl/intl.dart';
import 'package:pos_system/core/theme/app_theme.dart';

class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  String? _selectedStaffId;
  ActivityActionType? _selectedActionType;
  
  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(activityLogsProvider(ActivityLogFilter(
      staffId: _selectedStaffId,
      actionType: _selectedActionType,
    )));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
      ),
      body: Column(
        children: [
          Padding(
            padding: AppThemeConstants.defaultPadding,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ActivityActionType?>(
                    decoration: const InputDecoration(
                      labelText: 'Filter by Action',
                      prefixIcon: Icon(Icons.filter_list),
                    ),
                    initialValue: _selectedActionType,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Actions')),
                      ...ActivityActionType.values.map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.name.replaceAll('_', ' ').toUpperCase()),
                      )),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedActionType = val;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: logsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, size: 64, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: AppThemeConstants.spacing16),
                        Text('No activity logs found.', style: theme.textTheme.titleMedium),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: logs.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final dateStr = DateFormat('MMM dd, yyyy HH:mm').format(log.timestamp);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing16, vertical: AppThemeConstants.spacing4),
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                        child: const Icon(Icons.history, size: 20),
                      ),
                      title: Text(log.description, style: theme.textTheme.titleSmall),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: AppThemeConstants.spacing4),
                        child: Text('${log.staffName ?? "System"} • ${log.actionType.name}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ),
                      trailing: Text(dateStr, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
