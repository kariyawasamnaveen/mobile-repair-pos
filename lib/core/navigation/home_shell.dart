import 'package:flutter/material.dart';
import 'package:pos_system/features/billing/presentation/checkout_screen.dart';
import 'package:pos_system/features/billing/presentation/sales_and_ledger_screen.dart';
import 'package:pos_system/features/inventory/presentation/inventory_screen.dart';
import 'package:pos_system/features/repair_jobs/presentation/repair_job_list_screen.dart';
import 'package:pos_system/features/settings/presentation/settings_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/backup/backup_service.dart';
import 'package:pos_system/features/settings/data/settings_repository.dart';
import 'package:pos_system/features/auth/presentation/auth_controller.dart';
import 'dart:developer' as developer;

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkAndRunBackup();
  }

  Future<void> _checkAndRunBackup() async {
    try {
      final settingsRepo = ref.read(settingsRepositoryProvider);
      final lastBackupRes = await settingsRepo.getLastBackupTime();
      if (lastBackupRes.isRight()) {
        final lastBackup = lastBackupRes.getRight().toNullable();
        if (lastBackup == null || DateTime.now().difference(lastBackup).inHours >= 24) {
          developer.log('Triggering automatic daily backup...', name: 'HomeShell');
          final backupService = ref.read(backupServiceProvider);
          // Run in background without awaiting or blocking UI
          backupService.backupDatabase().then((res) {
            res.fold(
              (failure) => developer.log('Auto backup failed: ${failure.message}', name: 'HomeShell'),
              (_) => developer.log('Auto backup succeeded', name: 'HomeShell'),
            );
          });
        }
      }
    } catch (e) {
      developer.log('Failed to check backup status: $e', name: 'HomeShell');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider);
    if (user == null) return const Scaffold(body: Center(child: Text('Not logged in')));

    final List<Widget> pages = [];
    final List<NavigationDestination> destinations = [];

    // Owner gets everything.
    // Cashier gets Checkout, Inventory, Repairs, Sales.
    // Technician gets only Repairs.

    if (user.isOwner || user.isCashier) {
      pages.add(const CheckoutScreen());
      destinations.add(const NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Checkout'));
      
      pages.add(const InventoryScreen());
      destinations.add(const NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Inventory'));
    }

    if (user.isOwner || user.isCashier || user.isTechnician) {
      pages.add(const RepairJobListScreen());
      destinations.add(const NavigationDestination(icon: Icon(Icons.build), label: 'Repairs'));
    }

    if (user.isOwner || user.isCashier) {
      pages.add(const SalesAndLedgerScreen());
      destinations.add(const NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Sales'));
    }

    // Everyone gets Settings (for Logout)
    pages.add(const SettingsScreen());
    destinations.add(const NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'));

    // Ensure _selectedIndex is valid
    if (_selectedIndex >= pages.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: destinations,
      ),
    );
  }
}
