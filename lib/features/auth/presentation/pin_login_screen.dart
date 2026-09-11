import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/auth/data/auth_repository.dart';
import 'package:pos_system/features/auth/domain/auth_models.dart';
import 'package:pos_system/features/auth/presentation/auth_controller.dart';
import 'package:pos_system/features/auth/data/activity_log_repository.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/core/theme/app_theme.dart';

class PinLoginScreen extends ConsumerStatefulWidget {
  const PinLoginScreen({super.key});

  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen> {
  StaffMember? _selectedStaff;
  String _pin = '';
  bool _isLoading = false;
  String? _error;

  void _onKeypadTap(String value) {
    if (_isLoading) return;
    setState(() {
      _error = null;
      if (value == 'backspace') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (value == 'clear') {
        _pin = '';
      } else {
        if (_pin.length < 6) _pin += value;
      }
    });
  }

  Future<void> _submitLogin() async {
    if (_selectedStaff == null) {
      setState(() => _error = 'Please select your profile');
      return;
    }
    if (_pin.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final repo = ref.read(authRepositoryProvider);
    final res = await repo.login(_selectedStaff!.id, _pin);

    if (mounted) {
      res.fold(
        (l) => setState(() {
          _error = l.message; // Typically "Incorrect PIN" or similar
          _pin = ''; // Clear pin on error for security
          _isLoading = false;
        }),
        (staff) async {
          // Log the login activity
          await ref.read(activityLogRepositoryProvider).logAction(
                staffId: staff.id,
                actionType: ActivityActionType.staff_login,
                description: 'Logged in',
              );

          // Update session state
          ref.read(authStateProvider.notifier).state = staff;
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeStaffAsync = ref.watch(activeStaffProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppThemeConstants.spacing24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline, size: 64, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: AppThemeConstants.spacing24),
              Text(
                'Staff Login',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: AppThemeConstants.spacing32),
              
              // Staff Selector
              activeStaffAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (err, stack) => Text('Error loading staff: $err'),
                data: (staffList) {
                  if (staffList.isEmpty) return const Text('No active staff found.');
                  
                  // Ensure selected staff is in the list (or set to first)
                  if (_selectedStaff == null && staffList.isNotEmpty) {
                    _selectedStaff = staffList.first;
                  }

                  return Container(
                    width: 280,
                    padding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing16, vertical: AppThemeConstants.spacing4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(AppThemeConstants.radiusInput),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<StaffMember>(
                        isExpanded: true,
                        value: _selectedStaff,
                        items: staffList.map((staff) {
                          return DropdownMenuItem<StaffMember>(
                            value: staff,
                            child: Row(
                              children: [
                                Icon(Icons.person, color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: AppThemeConstants.spacing8),
                                Text(staff.name, style: theme.textTheme.titleMedium),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedStaff = val;
                            _pin = '';
                            _error = null;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: AppThemeConstants.spacing32),

              // Error Display
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppThemeConstants.spacing16),
                  child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
                ),

              // PIN display
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final isFilled = index < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing8),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled ? theme.colorScheme.primary : Colors.transparent,
                      border: Border.all(color: theme.colorScheme.primary, width: 2),
                    ),
                  );
                }),
              ),

              const SizedBox(height: AppThemeConstants.spacing32),

              // Keypad
              SizedBox(
                width: 280,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['1', '2', '3'].map((e) => _buildKey(e, theme)).toList(),
                    ),
                    const SizedBox(height: AppThemeConstants.spacing16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['4', '5', '6'].map((e) => _buildKey(e, theme)).toList(),
                    ),
                    const SizedBox(height: AppThemeConstants.spacing16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['7', '8', '9'].map((e) => _buildKey(e, theme)).toList(),
                    ),
                    const SizedBox(height: AppThemeConstants.spacing16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildKey('clear', theme, icon: Icons.clear),
                        _buildKey('0', theme),
                        _buildKey('backspace', theme, icon: Icons.backspace_outlined),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppThemeConstants.spacing32),

              // Enter Button
              SizedBox(
                width: 280,
                height: 56,
                child: ElevatedButton(
                  onPressed: _pin.length >= 4 && !_isLoading ? _submitLogin : null,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('ENTER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKey(String value, ThemeData theme, {IconData? icon}) {
    return InkWell(
      onTap: () => _onKeypadTap(value),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, size: 28, color: theme.colorScheme.onSurface)
              : Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }
}
