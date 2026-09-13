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
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo in a subtle teal circle for contrast
                  Container(
                    width: 100,
                    height: 100,
                    padding: const EdgeInsets.all(AppThemeConstants.spacing16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0EA5A5), // Brand teal
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/icon/splash_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: AppThemeConstants.spacing24),
                  
                  // Professional Typography for Title
                  Text(
                    'Staff Login',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppThemeConstants.spacing32),
                  
                  // Staff Selector with shadow and border
                  activeStaffAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (err, stack) => Text('Error loading staff: $err'),
                    data: (staffList) {
                      if (staffList.isEmpty) return const Text('No active staff found.');
                      
                      if (_selectedStaff == null && staffList.isNotEmpty) {
                        _selectedStaff = staffList.first;
                      }

                      return Container(
                        width: 320,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppThemeConstants.spacing16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<StaffMember>(
                            isExpanded: true,
                            value: _selectedStaff,
                            icon: Icon(Icons.arrow_drop_down_rounded, color: theme.colorScheme.primary),
                            items: staffList.map((staff) {
                              return DropdownMenuItem<StaffMember>(
                                value: staff,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: theme.colorScheme.primaryContainer,
                                      child: Icon(Icons.person, size: 18, color: theme.colorScheme.primary),
                                    ),
                                    const SizedBox(width: AppThemeConstants.spacing12),
                                    Text(
                                      staff.name,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  // Animated PIN dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      final isFilled = index < _pin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: isFilled ? 18 : 14,
                        height: isFilled ? 18 : 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled ? const Color(0xFF0EA5A5) : theme.colorScheme.surfaceContainerHighest,
                          border: isFilled ? null : Border.all(color: theme.colorScheme.outlineVariant, width: 1.5),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 40),

                  // Keypad
                  SizedBox(
                    width: 320,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: ['1', '2', '3'].map((e) => _buildKey(e, theme)).toList(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: ['4', '5', '6'].map((e) => _buildKey(e, theme)).toList(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: ['7', '8', '9'].map((e) => _buildKey(e, theme)).toList(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildKey('clear', theme, icon: Icons.clear_rounded),
                            _buildKey('0', theme),
                            _buildKey('backspace', theme, icon: Icons.backspace_rounded),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Branded Enter Button
                  SizedBox(
                    width: 320,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _pin.length >= 4 && !_isLoading ? _submitLogin : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5A5),
                        disabledBackgroundColor: const Color(0xFF0EA5A5).withValues(alpha: 0.5),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading 
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              'LOGIN',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKey(String value, ThemeData theme, {IconData? icon}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeypadTap(value),
        borderRadius: BorderRadius.circular(40),
        splashColor: const Color(0xFF0EA5A5).withValues(alpha: 0.2),
        highlightColor: const Color(0xFF0EA5A5).withValues(alpha: 0.1),
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, size: 28, color: theme.colorScheme.onSurface)
                : Text(
                    value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
