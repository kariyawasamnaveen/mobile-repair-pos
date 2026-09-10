import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/reports/domain/reports_models.dart';
import 'package:pos_system/features/reports/presentation/reports_controller.dart';

class ReportsDashboardScreen extends ConsumerStatefulWidget {
  const ReportsDashboardScreen({super.key});

  @override
  ConsumerState<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends ConsumerState<ReportsDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final dateRangeType = ref.watch(dateRangeTypeProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: DropdownButton<DateRangeType>(
                value: dateRangeType,
                underline: const SizedBox(),
                icon: const Icon(Icons.calendar_today, size: 16),
                items: const [
                  DropdownMenuItem(value: DateRangeType.today, child: Text('Today')),
                  DropdownMenuItem(value: DateRangeType.thisWeek, child: Text('This Week')),
                  DropdownMenuItem(value: DateRangeType.thisMonth, child: Text('This Month')),
                  DropdownMenuItem(value: DateRangeType.custom, child: Text('Custom')),
                ],
                onChanged: (val) async {
                  if (val == DateRangeType.custom) {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      ref.read(customDateRangeProvider.notifier).state = DateRange(picked.start, picked.end.add(const Duration(days: 1, milliseconds: -1)));
                      ref.read(dateRangeTypeProvider.notifier).state = DateRangeType.custom;
                    }
                  } else if (val != null) {
                    ref.read(dateRangeTypeProvider.notifier).state = val;
                  }
                },
              ),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Summary'),
              Tab(text: 'Sales'),
              Tab(text: 'Repairs'),
              Tab(text: 'Inventory'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SummaryTab(),
            _SalesBreakdownTab(),
            _RepairsBreakdownTab(),
            _InventoryHealthTab(),
          ],
        ),
      ),
    );
  }
}

// ── Summary Tab ──────────────────────────────────────────────────────────────

class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardSummaryProvider);
    
    return state.when(
      data: (summary) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SummaryCard(
              title: 'Total Sales Revenue',
              value: 'LKR ${summary.totalSalesRevenue.toStringAsFixed(2)}',
              icon: Icons.attach_money,
              color: Colors.green,
            ),
            const SizedBox(height: 8),
            _SummaryCard(
              title: 'Total Transactions',
              value: summary.totalTransactions.toString(),
              icon: Icons.receipt,
              color: Colors.blue,
            ),
            const SizedBox(height: 8),
            _SummaryCard(
              title: 'Repair Jobs Revenue',
              value: 'LKR ${summary.totalRepairRevenue.toStringAsFixed(2)}',
              icon: Icons.build,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),
            const Text('Snapshots (Current)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            _SummaryCard(
              title: 'Outstanding Credit',
              value: 'LKR ${summary.outstandingCredit.toStringAsFixed(2)}',
              icon: Icons.account_balance_wallet,
              color: Colors.red,
            ),
            const SizedBox(height: 8),
            _SummaryCard(
              title: 'Low Stock Items',
              value: summary.lowStockItemsCount.toString(),
              icon: Icons.warning_amber_rounded,
              color: Colors.amber,
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontSize: 14)),
        subtitle: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
      ),
    );
  }
}

// ── Sales Breakdown Tab ──────────────────────────────────────────────────────

class _SalesBreakdownTab extends ConsumerWidget {
  const _SalesBreakdownTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(salesBreakdownProvider);
    
    return state.when(
      data: (data) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionHeader('Revenue by Payment Method'),
            ...data.revenueByMethod.entries.map((e) => ListTile(
              title: Text(e.key.toUpperCase()),
              trailing: Text('LKR ${e.value.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
            if (data.revenueByMethod.isEmpty) const Text('No sales found.'),
            
            const SizedBox(height: 24),
            const _SectionHeader('Top 5 Items (by Quantity)'),
            ...data.topSellingByQuantity.map((e) => ListTile(
              title: Text(e.itemName),
              trailing: Text('${e.totalQuantity} sold'),
            )),
            if (data.topSellingByQuantity.isEmpty) const Text('No items sold.'),

            const SizedBox(height: 24),
            const _SectionHeader('Top 5 Items (by Revenue)'),
            ...data.topSellingByRevenue.map((e) => ListTile(
              title: Text(e.itemName),
              trailing: Text('LKR ${e.totalRevenue.toStringAsFixed(2)}'),
            )),
            if (data.topSellingByRevenue.isEmpty) const Text('No items sold.'),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ── Repairs Breakdown Tab ────────────────────────────────────────────────────

class _RepairsBreakdownTab extends ConsumerWidget {
  const _RepairsBreakdownTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(repairJobsBreakdownProvider);
    
    return state.when(
      data: (data) {
        String avgTimeStr = 'N/A';
        if (data.averageTurnaroundTime != null) {
          final days = data.averageTurnaroundTime!.inDays;
          final hours = data.averageTurnaroundTime!.inHours % 24;
          avgTimeStr = days > 0 ? '$days days, $hours hrs' : '$hours hrs';
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionHeader('Average Turnaround Time'),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('For delivered jobs'),
              trailing: Text(avgTimeStr, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            
            const SizedBox(height: 24),
            const _SectionHeader('Jobs by Status'),
            ...data.jobsByStatus.entries.map((e) => ListTile(
              title: Text(e.key.toUpperCase()),
              trailing: Text(e.value.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
            if (data.jobsByStatus.isEmpty) const Text('No repair jobs found.'),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ── Inventory Health Tab ─────────────────────────────────────────────────────

class _InventoryHealthTab extends ConsumerWidget {
  const _InventoryHealthTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryHealthProvider);
    final summaryState = ref.watch(dashboardSummaryProvider);
    
    return state.when(
      data: (data) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionHeader('Total Inventory Value'),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'LKR ${data.totalValue.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            const _SectionHeader('Low Stock Alerts'),
            summaryState.maybeWhen(
              data: (summary) {
                if (summary.lowStockItemsCount == 0) {
                  return const ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text('Inventory is healthy'),
                  );
                }
                return ListTile(
                  leading: const Icon(Icons.warning, color: Colors.amber),
                  title: Text('${summary.lowStockItemsCount} items are low on stock'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to inventory tab if they want to manage it, or just show a message.
                    // The simplest is to just switch tabs on HomeShell, but HomeShell manages it.
                    // Easiest is to pop and tell user to go to inventory.
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please check the Inventory tab for low stock items.')));
                  },
                );
              },
              orElse: () => const SizedBox(),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
