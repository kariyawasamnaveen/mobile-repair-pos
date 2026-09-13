import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/reports/domain/reports_models.dart';
import 'package:pos_system/features/reports/presentation/reports_controller.dart';
import 'package:pos_system/features/reports/domain/pdf_report_generator.dart';
import 'package:printing/printing.dart';
import 'package:pos_system/core/theme/app_theme.dart';
import 'package:pos_system/features/reports/presentation/combined_reports_screen.dart';

class ReportsDashboardScreen extends ConsumerStatefulWidget {
  const ReportsDashboardScreen({super.key});

  @override
  ConsumerState<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends ConsumerState<ReportsDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final dateRangeType = ref.watch(dateRangeTypeProvider);
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports'),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Generate Monthly Report',
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF Report...')));
                final res = await ref.read(pdfReportGeneratorProvider).generateMonthlyReport(DateTime.now());
                if (mounted) {
                  res.fold(
                    (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
                    (bytes) async {
                      await Printing.layoutPdf(
                        onLayout: (_) => bytes,
                        name: 'Monthly_Report_${DateTime.now().toIso8601String().split('T').first}.pdf',
                      );
                    },
                  );
                }
              },
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing8, vertical: AppThemeConstants.spacing8),
              padding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppThemeConstants.radiusInput),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DateRangeType>(
                  value: dateRangeType,
                  icon: Icon(Icons.calendar_today_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  dropdownColor: theme.colorScheme.surfaceContainerHighest,
                  style: theme.textTheme.bodyMedium,
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
            ),
            const SizedBox(width: AppThemeConstants.spacing8),
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
    final theme = Theme.of(context);
    
    return state.when(
      data: (summary) {
        return ListView(
          padding: AppThemeConstants.defaultPadding,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CombinedReportsScreen()),
                );
              },
              icon: const Icon(Icons.hub_outlined),
              label: const Text('Combined Multi-Branch Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: AppThemeConstants.spacing16),
            _SummaryCard(
              title: 'Total Sales Revenue',
              value: 'LKR ${summary.totalSalesRevenue.toStringAsFixed(2)}',
              icon: Icons.attach_money,
              color: AppTheme.successColor,
            ),
            const SizedBox(height: AppThemeConstants.spacing8),
            _SummaryCard(
              title: 'Total Transactions',
              value: summary.totalTransactions.toString(),
              icon: Icons.receipt_long_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppThemeConstants.spacing8),
            _SummaryCard(
              title: 'Repair Jobs Revenue',
              value: 'LKR ${summary.totalRepairRevenue.toStringAsFixed(2)}',
              icon: Icons.build_circle_outlined,
              color: AppTheme.warningColor,
            ),
            const SizedBox(height: AppThemeConstants.spacing8),
            _SummaryCard(
              title: 'Total Tax Collected',
              value: 'LKR ${summary.totalTaxCollected.toStringAsFixed(2)}',
              icon: Icons.account_balance,
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(height: AppThemeConstants.spacing8),
            _SummaryCard(
              title: 'Total Discounts Given',
              value: 'LKR ${summary.totalDiscounts.toStringAsFixed(2)}',
              icon: Icons.local_offer_outlined,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppThemeConstants.spacing24),
            Text('Snapshots (Current)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppThemeConstants.spacing8),
            _SummaryCard(
              title: 'Outstanding Credit',
              value: 'LKR ${summary.outstandingCredit.toStringAsFixed(2)}',
              icon: Icons.account_balance_wallet_outlined,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: AppThemeConstants.spacing8),
            _SummaryCard(
              key: const ValueKey('total_owed_card'),
              title: 'Total Owed to Suppliers',
              value: 'LKR ${summary.totalOwedToSuppliers.toStringAsFixed(2)}',
              icon: Icons.local_shipping_outlined,
              color: AppTheme.warningColor,
            ),
            const SizedBox(height: AppThemeConstants.spacing8),
            _SummaryCard(
              title: 'Low Stock Items',
              value: summary.lowStockItemsCount.toString(),
              icon: Icons.warning_amber_rounded,
              color: AppTheme.warningColor,
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

  const _SummaryCard({super.key, required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing16, vertical: AppThemeConstants.spacing8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppThemeConstants.spacing4),
          child: Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        ),
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
    final theme = Theme.of(context);
    
    return state.when(
      data: (data) {
        return ListView(
          padding: AppThemeConstants.defaultPadding,
          children: [
            const _SectionHeader('Revenue by Payment Method'),
            ...data.revenueByMethod.entries.map((e) => Card(
              margin: const EdgeInsets.only(bottom: AppThemeConstants.spacing8),
              child: ListTile(
                title: Text(e.key.toUpperCase(), style: theme.textTheme.titleMedium),
                trailing: Text('LKR ${e.value.toStringAsFixed(2)}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
            )),
            if (data.revenueByMethod.isEmpty) Padding(padding: const EdgeInsets.only(bottom: AppThemeConstants.spacing16), child: Text('No sales found.', style: theme.textTheme.bodyMedium)),
            
            const SizedBox(height: AppThemeConstants.spacing16),
            const _SectionHeader('Top 5 Items (by Quantity)'),
            ...data.topSellingByQuantity.map((e) => Card(
              margin: const EdgeInsets.only(bottom: AppThemeConstants.spacing8),
              child: ListTile(
                title: Text(e.itemName, style: theme.textTheme.titleMedium),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${e.totalQuantity} sold', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
              ),
            )),
            if (data.topSellingByQuantity.isEmpty) Padding(padding: const EdgeInsets.only(bottom: AppThemeConstants.spacing16), child: Text('No items sold.', style: theme.textTheme.bodyMedium)),

            const SizedBox(height: AppThemeConstants.spacing16),
            const _SectionHeader('Top 5 Items (by Revenue)'),
            ...data.topSellingByRevenue.map((e) => Card(
              margin: const EdgeInsets.only(bottom: AppThemeConstants.spacing8),
              child: ListTile(
                title: Text(e.itemName, style: theme.textTheme.titleMedium),
                trailing: Text('LKR ${e.totalRevenue.toStringAsFixed(2)}', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
              ),
            )),
            if (data.topSellingByRevenue.isEmpty) Padding(padding: const EdgeInsets.only(bottom: AppThemeConstants.spacing16), child: Text('No items sold.', style: theme.textTheme.bodyMedium)),
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
    final theme = Theme.of(context);
    
    return state.when(
      data: (data) {
        String avgTimeStr = 'N/A';
        if (data.averageTurnaroundTime != null) {
          final days = data.averageTurnaroundTime!.inDays;
          final hours = data.averageTurnaroundTime!.inHours % 24;
          avgTimeStr = days > 0 ? '$days days, $hours hrs' : '$hours hrs';
        }

        return ListView(
          padding: AppThemeConstants.defaultPadding,
          children: [
            const _SectionHeader('Average Turnaround Time'),
            Card(
              margin: const EdgeInsets.only(bottom: AppThemeConstants.spacing16),
              child: ListTile(
                leading: Icon(Icons.timer_outlined, color: theme.colorScheme.primary),
                title: Text('For delivered jobs', style: theme.textTheme.titleMedium),
                trailing: Text(avgTimeStr, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: AppThemeConstants.spacing8),
            const _SectionHeader('Jobs by Status'),
            ...data.jobsByStatus.entries.map((e) => Card(
              margin: const EdgeInsets.only(bottom: AppThemeConstants.spacing8),
              child: ListTile(
                title: Text(e.key.toUpperCase(), style: theme.textTheme.titleMedium),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing12, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(e.value.toString(), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer)),
                ),
              ),
            )),
            if (data.jobsByStatus.isEmpty) Padding(padding: const EdgeInsets.only(bottom: AppThemeConstants.spacing16), child: Text('No repair jobs found.', style: theme.textTheme.bodyMedium)),
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
    final theme = Theme.of(context);
    
    return state.when(
      data: (data) {
        return ListView(
          padding: AppThemeConstants.defaultPadding,
          children: [
            const _SectionHeader('Total Inventory Value'),
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppThemeConstants.spacing24),
                child: Center(
                  child: Text(
                    'LKR ${data.totalValue.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppThemeConstants.spacing24),
            
            const _SectionHeader('Low Stock Alerts'),
            summaryState.maybeWhen(
              data: (summary) {
                if (summary.lowStockItemsCount == 0) {
                  return Card(
                    child: ListTile(
                      leading: Icon(Icons.check_circle_outline, color: AppTheme.successColor),
                      title: Text('Inventory is healthy', style: theme.textTheme.titleMedium),
                    ),
                  );
                }
                return Card(
                  child: ListTile(
                    leading: Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor),
                    title: Text('${summary.lowStockItemsCount} items are low on stock', style: theme.textTheme.titleMedium),
                    trailing: Icon(Icons.chevron_right, size: 24, color: theme.colorScheme.onSurfaceVariant),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please check the Inventory tab for low stock items.')));
                    },
                  ),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppThemeConstants.spacing12),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
      ),
    );
  }
}
