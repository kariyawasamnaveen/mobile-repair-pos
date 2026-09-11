import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/credit_ledger/domain/credit_ledger_models.dart';
import 'package:pos_system/features/credit_ledger/presentation/credit_ledger_controller.dart';
import 'package:pos_system/features/credit_ledger/presentation/customer_detail_screen.dart';
import 'package:pos_system/core/theme/app_theme.dart';

/// Body-only widget — embedded in SalesAndLedgerScreen's TabBarView.
/// Lists all customers with outstanding balances, sorted highest-first.
class CustomerLedgerScreen extends ConsumerStatefulWidget {
  const CustomerLedgerScreen({super.key});

  @override
  ConsumerState<CustomerLedgerScreen> createState() =>
      _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends ConsumerState<CustomerLedgerScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CustomerBalance> _filtered(List<CustomerBalance> customers) {
    if (_query.isEmpty) return customers;
    final q = _query.toLowerCase();
    return customers.where((c) {
      return c.customerPhone.contains(q) ||
          (c.customerName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerLedgerProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: AppThemeConstants.defaultPadding,
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search by name or phone',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: state.when(
            data: (customers) {
              if (customers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: AppTheme.successColor),
                      const SizedBox(height: AppThemeConstants.spacing16),
                      Text(
                        'No outstanding balances — all settled!',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                );
              }
              final visible = _filtered(customers);
              if (visible.isEmpty) {
                return Center(child: Text('No customers match your search.', style: theme.textTheme.titleMedium));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing16, vertical: AppThemeConstants.spacing8),
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final customer = visible[index];
                  return Card(
                    child: _CustomerLedgerTile(
                      customer: customer,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => CustomerDetailScreen(
                              customerPhone: customer.customerPhone,
                              customerName: customer.customerName,
                            ),
                          ),
                        );
                        if (mounted) {
                          ref.read(customerLedgerProvider.notifier).load();
                        }
                      },
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error: $err', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
                  const SizedBox(height: AppThemeConstants.spacing8),
                  FilledButton.icon(
                    onPressed: () => ref.read(customerLedgerProvider.notifier).load(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Customer tile ─────────────────────────────────────────────────────────────

class _CustomerLedgerTile extends StatelessWidget {
  const _CustomerLedgerTile({
    required this.customer,
    required this.onTap,
  });

  final CustomerBalance customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing16, vertical: AppThemeConstants.spacing8),
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: colorScheme.errorContainer,
        child: Icon(Icons.person, color: colorScheme.onErrorContainer),
      ),
      title: Text(
        customer.customerName?.isNotEmpty == true
            ? customer.customerName!
            : customer.customerPhone,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Text(
        customer.customerPhone,
        style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'LKR ${customer.totalOutstanding.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.error,
            ),
          ),
          Text(
            '${customer.unpaidSaleCount} sale${customer.unpaidSaleCount == 1 ? '' : 's'}',
            style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
