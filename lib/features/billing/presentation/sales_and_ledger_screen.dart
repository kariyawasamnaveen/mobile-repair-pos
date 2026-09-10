import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/billing/presentation/billing_controller.dart';
import 'package:pos_system/features/billing/presentation/receipt_screen.dart';
import 'package:pos_system/features/credit_ledger/presentation/customer_ledger_screen.dart';

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
              Tab(icon: Icon(Icons.receipt_long), text: 'History'),
              Tab(icon: Icon(Icons.account_balance_wallet), text: 'Naya Potha'),
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

    return salesState.when(
      data: (sales) {
        if (sales.isEmpty) {
          return const Center(child: Text('No sales found.'));
        }
        return ListView.builder(
          itemCount: sales.length,
          itemBuilder: (context, index) {
            final sale = sales[index];
            final hasOutstandingBalance =
                sale.isCreditSale && sale.balanceDue > 0;
            return ListTile(
              title: Text(
                  'Sale: ${sale.id.substring(0, 8).toUpperCase()} · LKR ${sale.total}'),
              subtitle: Text(
                '${sale.createdAt.toString().split('.')[0]} | '
                '${sale.paymentMethod.name.toUpperCase()}'
                '${hasOutstandingBalance ? ' · Due: LKR ${sale.balanceDue.toStringAsFixed(2)}' : ''}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasOutstandingBalance)
                    Tooltip(
                      message: 'Outstanding balance: LKR ${sale.balanceDue.toStringAsFixed(2)}',
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.error,
                        size: 20,
                      ),
                    ),
                  const Icon(Icons.receipt),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ReceiptScreen(sale: sale),
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
