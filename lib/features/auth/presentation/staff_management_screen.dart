import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/auth/domain/auth_models.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/features/auth/presentation/staff_management_controller.dart';
import 'package:pos_system/core/theme/app_theme.dart';

class StaffManagementScreen extends ConsumerWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffMembersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Staff',
            onPressed: () => _showStaffDialog(context, ref),
          ),
        ],
      ),
      body: staffAsync.when(
        data: (staffList) {
          if (staffList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: AppThemeConstants.spacing16),
                  Text('No staff members found.', style: theme.textTheme.titleMedium),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: AppThemeConstants.defaultPadding,
            itemCount: staffList.length,
            itemBuilder: (context, index) {
              final staff = staffList[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing16, vertical: AppThemeConstants.spacing8),
                  leading: CircleAvatar(
                    backgroundColor: staff.isActive ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: staff.isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                    child: Text(staff.name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  title: Text(staff.name, style: theme.textTheme.titleMedium),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: AppThemeConstants.spacing4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing8, vertical: AppThemeConstants.spacing4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            staff.role.name.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Switch(
                    value: staff.isActive,
                    activeThumbColor: theme.colorScheme.primary,
                    onChanged: staff.role == StaffRole.owner && staffList.where((s) => s.role == StaffRole.owner && s.isActive).length <= 1
                      ? null // Prevent deactivating the last active owner
                      : (value) {
                          ref.read(staffMembersProvider.notifier).toggleStaffStatus(staff.id, value);
                        },
                  ),
                  onTap: () => _showStaffDialog(context, ref, staff: staff),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  void _showStaffDialog(BuildContext context, WidgetRef ref, {StaffMember? staff}) {
    showDialog(
      context: context,
      builder: (context) => _StaffDialog(staff: staff),
    );
  }
}

class _StaffDialog extends ConsumerStatefulWidget {
  final StaffMember? staff;
  const _StaffDialog({this.staff});

  @override
  ConsumerState<_StaffDialog> createState() => _StaffDialogState();
}

class _StaffDialogState extends ConsumerState<_StaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  StaffRole _role = StaffRole.cashier;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.staff != null) {
      _nameController.text = widget.staff!.name;
      _role = widget.staff!.role;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String? error;
    if (widget.staff == null) {
      error = await ref.read(staffMembersProvider.notifier).addStaff(
        name: _nameController.text.trim(),
        pin: _pinController.text.trim(),
        role: _role,
      );
    } else {
      error = await ref.read(staffMembersProvider.notifier).updateStaff(
        id: widget.staff!.id,
        name: _nameController.text.trim(),
        role: _role,
        newPin: _pinController.text.isNotEmpty ? _pinController.text.trim() : null,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.staff == null ? 'Add Staff Member' : 'Edit Staff Member'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppThemeConstants.spacing16),
              DropdownButtonFormField<StaffRole>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: StaffRole.values.map((r) => DropdownMenuItem(
                  value: r,
                  child: Text(r.name.toUpperCase()),
                )).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _role = val);
                },
              ),
              const SizedBox(height: AppThemeConstants.spacing16),
              TextFormField(
                controller: _pinController,
                decoration: InputDecoration(
                  labelText: widget.staff == null ? 'PIN (4-6 digits)' : 'New PIN (optional)',
                  prefixIcon: const Icon(Icons.dialpad),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: (val) {
                  if (widget.staff == null && (val == null || val.isEmpty)) {
                    return 'Required for new staff';
                  }
                  if (val != null && val.isNotEmpty && (val.length < 4 || val.length > 6)) {
                    return 'Must be 4-6 digits';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
              : const Text('Save'),
        ),
      ],
    );
  }
}
