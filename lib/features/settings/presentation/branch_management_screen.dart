import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/settings/domain/branch_models.dart';
import 'package:pos_system/features/settings/presentation/branch_management_controller.dart';
import 'package:pos_system/core/widgets/empty_state_widget.dart';
import 'package:pos_system/core/theme/app_theme.dart';

class BranchManagementScreen extends ConsumerWidget {
  const BranchManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Branch Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business),
            tooltip: 'Add Branch',
            onPressed: () => _showBranchDialog(context, ref),
          ),
        ],
      ),
      body: branchesAsync.when(
        data: (branchList) {
          if (branchList.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.storefront_outlined,
              title: 'No branches found',
              subtitle: 'Add a branch to start tracking multi-store sales.',
            );
          }
          return ListView.builder(
            padding: AppThemeConstants.defaultPadding,
            itemCount: branchList.length,
            itemBuilder: (context, index) {
              final branch = branchList[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing16, vertical: AppThemeConstants.spacing8),
                  leading: CircleAvatar(
                    backgroundColor: branch.isActive ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: branch.isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                    child: Text(branch.name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  title: Text(branch.name, style: theme.textTheme.titleMedium),
                  subtitle: Text(
                    branch.address ?? 'No address',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  trailing: Switch(
                    value: branch.isActive,
                    activeThumbColor: theme.colorScheme.primary,
                    onChanged: branchList.where((b) => b.isActive).length <= 1 && branch.isActive
                      ? null // Prevent deactivating the last active branch
                      : (value) {
                          ref.read(branchesProvider.notifier).toggleBranchStatus(branch.id, value);
                        },
                  ),
                  onTap: () => _showBranchDialog(context, ref, branch: branch),
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

  void _showBranchDialog(BuildContext context, WidgetRef ref, {Branch? branch}) {
    showDialog(
      context: context,
      builder: (context) => _BranchDialog(branch: branch),
    );
  }
}

class _BranchDialog extends ConsumerStatefulWidget {
  final Branch? branch;
  const _BranchDialog({this.branch});

  @override
  ConsumerState<_BranchDialog> createState() => _BranchDialogState();
}

class _BranchDialogState extends ConsumerState<_BranchDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.branch != null) {
      _nameController.text = widget.branch!.name;
      _addressController.text = widget.branch!.address ?? '';
      _phoneController.text = widget.branch!.phone ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String? error;
    if (widget.branch == null) {
      error = await ref.read(branchesProvider.notifier).addBranch(
        name: _nameController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      );
    } else {
      error = await ref.read(branchesProvider.notifier).updateBranch(
        id: widget.branch!.id,
        name: _nameController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
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
      title: Text(widget.branch == null ? 'Add Branch' : 'Edit Branch'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Branch Name',
                  prefixIcon: Icon(Icons.storefront),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppThemeConstants.spacing16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address (Optional)',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: AppThemeConstants.spacing16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone (Optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
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
        FilledButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Save'),
        ),
      ],
    );
  }
}
