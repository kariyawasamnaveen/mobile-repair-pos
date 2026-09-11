import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/navigation/home_shell.dart';
import 'package:pos_system/features/auth/presentation/auth_controller.dart';
import 'package:pos_system/features/auth/presentation/bootstrap_owner_screen.dart';
import 'package:pos_system/features/auth/presentation/pin_login_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasStaffAsync = ref.watch(hasAnyStaffProvider);
    final currentUser = ref.watch(authStateProvider);

    return hasStaffAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (hasStaff) {
        if (!hasStaff) {
          return const BootstrapOwnerScreen();
        }

        if (currentUser == null) {
          return const PinLoginScreen();
        }

        return const HomeShell();
      },
    );
  }
}
