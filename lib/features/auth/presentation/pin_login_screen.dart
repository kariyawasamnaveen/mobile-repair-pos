import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/auth/data/auth_repository.dart';
import 'package:pos_system/features/auth/domain/auth_models.dart';
import 'package:pos_system/features/auth/presentation/auth_controller.dart';
import 'package:pos_system/features/auth/data/activity_log_repository.dart';
import 'package:pos_system/core/database/tables.dart';


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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pro Logo Composition (No image loading issues)
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5A5),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0EA5A5).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Positioned(
                            bottom: 15,
                            child: Icon(Icons.storefront_rounded, size: 60, color: Colors.white),
                          ),
                          Positioned(
                            right: 8,
                            top: 15,
                            child: Stack(
                              children: [
                                const Icon(Icons.bar_chart_rounded, size: 40, color: Color(0xFFF59E0B)),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: const Icon(Icons.arrow_outward_rounded, size: 18, color: Color(0xFFF59E0B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    Text(
                      'Welcome Back',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please login to continue',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Staff Selector
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<StaffMember>(
                              isExpanded: true,
                              value: _selectedStaff,
                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.onSurfaceVariant),
                              items: staffList.map((staff) {
                                return DropdownMenuItem<StaffMember>(
                                  value: staff,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: theme.colorScheme.primaryContainer,
                                        child: Text(
                                          staff.name.substring(0, 1).toUpperCase(),
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
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
                    
                    const SizedBox(height: 32),

                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    // Modern PIN dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        final isFilled = index < _pin.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: isFilled ? 16 : 12,
                          height: isFilled ? 16 : 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled ? const Color(0xFF0EA5A5) : theme.colorScheme.surfaceContainerHighest,
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 48),

                    // Pro Keypad
                    SizedBox(
                      width: 280,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: ['1', '2', '3'].map((e) => _buildKey(e, theme)).toList(),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: ['4', '5', '6'].map((e) => _buildKey(e, theme)).toList(),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: ['7', '8', '9'].map((e) => _buildKey(e, theme)).toList(),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildKey('clear', theme, icon: Icons.clear_rounded),
                              _buildKey('0', theme),
                              _buildKey('backspace', theme, icon: Icons.backspace_rounded),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Modern Login Button
                    SizedBox(
                      width: 320,
                      height: 56,
                      child: FilledButton(
                        onPressed: _pin.length >= 4 && !_isLoading ? _submitLogin : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5A5),
                          disabledBackgroundColor: const Color(0xFF0EA5A5).withValues(alpha: 0.3),
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
                                'Login',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Widget _buildKey(String value, ThemeData theme, {IconData? icon}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeypadTap(value),
        borderRadius: BorderRadius.circular(40),
        splashColor: const Color(0xFF0EA5A5).withValues(alpha: 0.1),
        highlightColor: Colors.transparent,
        child: Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, size: 28, color: theme.colorScheme.onSurfaceVariant)
                : Text(
                    value,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w400,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
