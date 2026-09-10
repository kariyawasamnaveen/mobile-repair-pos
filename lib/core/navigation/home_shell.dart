import 'package:flutter/material.dart';
import 'package:pos_system/features/billing/presentation/checkout_screen.dart';
import 'package:pos_system/features/billing/presentation/sales_and_ledger_screen.dart';
import 'package:pos_system/features/inventory/presentation/inventory_screen.dart';
import 'package:pos_system/features/repair_jobs/presentation/repair_job_list_screen.dart';
import 'package:pos_system/features/settings/presentation/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  static const _pages = [
    CheckoutScreen(),
    InventoryScreen(),
    RepairJobListScreen(),
    SalesAndLedgerScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Checkout'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Inventory'),
          NavigationDestination(icon: Icon(Icons.build), label: 'Repairs'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Sales'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
