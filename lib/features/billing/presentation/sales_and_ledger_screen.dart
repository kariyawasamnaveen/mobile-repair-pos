import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/billing/presentation/billing_controller.dart';
import 'package:pos_system/features/billing/presentation/receipt_screen.dart';
import 'package:pos_system/features/credit_ledger/presentation/customer_ledger_screen.dart';
import 'package:pos_system/core/theme/app_theme.dart';
import 'package:pos_system/core/widgets/empty_state_widget.dart';

/// Combined Sales & Ledger tab — two sub-tabs so the nav bar stays at 5 items.
class SalesAndLedgerScreen extends StatelessWidget {
  const SalesAndLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sales'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'History'),
              Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'Naya Potha'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SalesHistoryTab(),
            CustomerLedgerScreen(),
          ],
        ),
      ),
    );
  }
}

// ── Sales History tab ────────────────────────────────────────────────────────

class _SalesHistoryTab extends ConsumerWidget {
  const _SalesHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesState = ref.watch(salesHistoryProvider);
    final theme = Theme.of(context);

    return salesState.when(
      data: (sales) {
        if (sales.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.receipt_outlined,
            title: 'No sales found',
            subtitle: 'Try adjusting your search or date range.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing16, vertical: AppThemeConstants.spacing8),
          itemCount: sales.length,
          itemBuilder: (context, index) {
            final sale = sales[index];
            final hasOutstandingBalance =
                sale.isCreditSale && sale.balanceDue > 0;
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing16, vertical: AppThemeConstants.spacing8),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Sale: ${sale.id.substring(0, 8).toUpperCase()}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      'LKR ${sale.total}',
                      style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: AppThemeConstants.spacing4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${sale.createdAt.toString().split('.')[0]} | ${sale.paymentMethod.name.toUpperCase()}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      if (hasOutstandingBalance)
                        Padding(
                          padding: const EdgeInsets.only(top: AppThemeConstants.spacing4),
                          child: Text(
                            'Due: LKR ${sale.balanceDue.toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasOutstandingBalance)
                      Tooltip(
                        message: 'Outstanding balance: LKR ${sale.balanceDue.toStringAsFixed(2)}',
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: theme.colorScheme.error,
                          size: 20,
                        ),
                      ),
                    const SizedBox(width: AppThemeConstants.spacing8),
                    Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ReceiptScreen(sale: sale),
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}
