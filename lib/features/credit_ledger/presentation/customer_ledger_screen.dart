import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/credit_ledger/domain/credit_ledger_models.dart';
import 'package:pos_system/features/credit_ledger/presentation/credit_ledger_controller.dart';
import 'package:pos_system/features/credit_ledger/presentation/customer_detail_screen.dart';

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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search by name or phone',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: state.when(
            data: (customers) {
              if (customers.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 56, color: Colors.green),
                      SizedBox(height: 12),
                      Text(
                        'No outstanding balances — all settled!',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                );
              }
              final visible = _filtered(customers);
              if (visible.isEmpty) {
                return const Center(
                    child: Text('No customers match your search.'));
              }
              return ListView.separated(
                itemCount: visible.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final customer = visible[index];
                  return _CustomerLedgerTile(
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
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error: $err'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () =>
                        ref.read(customerLedgerProvider.notifier).load(),
                    child: const Text('Retry'),
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
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: colorScheme.errorContainer,
        child: Icon(Icons.person, color: colorScheme.onErrorContainer),
      ),
      title: Text(
        customer.customerName?.isNotEmpty == true
            ? customer.customerName!
            : customer.customerPhone,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        customer.customerPhone,
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'LKR ${customer.totalOutstanding.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: colorScheme.error,
            ),
          ),
          Text(
            '${customer.unpaidSaleCount} sale${customer.unpaidSaleCount == 1 ? '' : 's'}',
            style:
                TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
