import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/auth/data/auth_repository.dart';
import 'package:pos_system/features/auth/presentation/auth_controller.dart';
import 'package:pos_system/core/theme/app_theme.dart';

class BootstrapOwnerScreen extends ConsumerStatefulWidget {
  const BootstrapOwnerScreen({super.key});

  @override
  ConsumerState<BootstrapOwnerScreen> createState() => _BootstrapOwnerScreenState();
}

class _BootstrapOwnerScreenState extends ConsumerState<BootstrapOwnerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _businessAccountIdController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _businessAccountIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_pinController.text != _confirmPinController.text) {
      setState(() => _error = 'PINs do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final repo = ref.read(authRepositoryProvider);
    final res = await repo.createFirstOwner(
      _nameController.text.trim(), 
      _pinController.text,
      _businessAccountIdController.text.trim(),
    );
    
    if (mounted) {
      res.fold(
        (l) => setState(() {
          _error = l.message;
          _isLoading = false;
        }),
        (owner) {
          // Log them in immediately
          ref.read(authStateProvider.notifier).state = owner;
          // Refresh the hasAnyStaff provider so AuthGate stops showing this screen
          ref.invalidate(hasAnyStaffProvider);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Setup First Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppThemeConstants.spacing24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(AppThemeConstants.spacing32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppThemeConstants.spacing24),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.security, size: 48, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: AppThemeConstants.spacing24),
                      Text(
                        'Welcome to POS System',
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppThemeConstants.spacing8),
                      Text(
                        'Please create an Owner account to get started.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppThemeConstants.spacing32),
                      
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(AppThemeConstants.spacing12),
                          margin: const EdgeInsets.only(bottom: AppThemeConstants.spacing16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(AppThemeConstants.radiusInput),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
                              const SizedBox(width: AppThemeConstants.spacing8),
                              Expanded(
                                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                              ),
                            ],
                          ),
                        ),
                        
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Your Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: AppThemeConstants.spacing16),
                      TextFormField(
                        controller: _pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: 'Create PIN (4-6 digits)',
                          prefixIcon: Icon(Icons.dialpad),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 4) return 'Minimum 4 digits';
                          if (int.tryParse(v) == null) return 'Must be numeric';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppThemeConstants.spacing16),
                      TextFormField(
                        controller: _confirmPinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: 'Confirm PIN',
                          prefixIcon: Icon(Icons.dialpad),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppThemeConstants.spacing24),
                      const Divider(),
                      const SizedBox(height: AppThemeConstants.spacing16),
                      Text(
                        'Multi-Tenant Setup',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppThemeConstants.spacing8),
                      Text(
                        'If you\'re setting up an additional branch for an existing business, enter the SAME Business Account ID used on your other branch\'s device. If this is a new business, create a new unique ID (e.g. a long random string or UUID).',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppThemeConstants.spacing16),
                      TextFormField(
                        controller: _businessAccountIdController,
                        decoration: const InputDecoration(
                          labelText: 'Business Account ID',
                          prefixIcon: Icon(Icons.business),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: AppThemeConstants.spacing32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading 
                              ? const SizedBox(
                                  height: 20, 
                                  width: 20, 
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                                ) 
                              : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
