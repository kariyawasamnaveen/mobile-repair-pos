import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/features/credit_ledger/domain/credit_ledger_models.dart';
import 'package:pos_system/features/credit_ledger/presentation/credit_ledger_controller.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final String customerPhone;
  final String? customerName;

  const CustomerDetailScreen({
    super.key,
    required this.customerPhone,
    this.customerName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(customerDetailProvider(customerPhone));

    final totalOutstanding = state.sales.valueOrNull?.fold(
          0.0,
          (sum, s) => sum + s.balanceDue,
        ) ??
        0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          customerName?.isNotEmpty == true ? customerName! : customerPhone,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(customerDetailProvider(customerPhone).notifier).load(),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Balance header ─────────────────────────────────────────────────
                _BalanceHeader(
                  customerPhone: customerPhone,
                  customerName: customerName,
                  totalOutstanding: totalOutstanding,
                ),
                const SizedBox(height: 16),

                // ── Credit Sales list ──────────────────────────────────────────────
                const _SectionHeader(title: 'Credit Sales', icon: Icons.receipt_long),
              ]),
            ),
          ),
          
          state.sales.when(
            data: (sales) {
              if (sales.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text('No credit sales found.'),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: sales.length,
                  itemBuilder: (context, index) => _CreditSaleTile(sale: sales[index]),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error loading sales: $e'))),
          ),
          
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                // ── Collect Payment button ─────────────────────────────────────────
                if (totalOutstanding > 0)
                  ElevatedButton.icon(
                    onPressed: () => _showCollectPaymentSheet(
                      context,
                      ref,
                      outstanding: totalOutstanding,
                      sales: state.sales.valueOrNull ?? [],
                    ),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('COLLECT PAYMENT'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                const SizedBox(height: 24),

                // ── Payment History ────────────────────────────────────────────────
                const _SectionHeader(title: 'Payment History', icon: Icons.history),
              ]),
            ),
          ),
          
          state.payments.when(
            data: (payments) {
              if (payments.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text('No payments recorded yet.'),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: payments.length,
                  itemBuilder: (context, index) => _PaymentHistoryTile(payment: payments[index]),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error loading payment history: $e'))),
          ),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  void _showCollectPaymentSheet(
    BuildContext context,
    WidgetRef ref, {
    required double outstanding,
    required List<CreditSaleSummary> sales,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CollectPaymentSheet(
        customerPhone: customerPhone,
        outstanding: outstanding,
        sales: sales.where((s) => !s.isSettled).toList(),
        onPaymentRecorded: () {
          ref.read(customerDetailProvider(customerPhone).notifier).load();
        },
      ),
    );
  }
}

// ── Balance header ─────────────────────────────────────────────────────────────

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({
    required this.customerPhone,
    required this.customerName,
    required this.totalOutstanding,
  });

  final String customerPhone;
  final String? customerName;
  final double totalOutstanding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colorScheme.error,
              child: Icon(Icons.person, color: colorScheme.onError, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (customerName?.isNotEmpty == true)
                    Text(
                      customerName!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  Text(customerPhone),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Total Owed', style: TextStyle(fontSize: 12)),
                Text(
                  'LKR ${totalOutstanding.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ── Credit sale tile ─────────────────────────────────────────────────────────

class _CreditSaleTile extends StatelessWidget {
  const _CreditSaleTile({required this.sale});
  final CreditSaleSummary sale;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settled = sale.isSettled;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              settled ? Icons.check_circle : Icons.radio_button_unchecked,
              color: settled ? Colors.green : colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sale.saleId.substring(0, 8).toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                  ),
                  Text(
                    sale.createdAt.toString().split('.')[0],
                    style: TextStyle(
                        fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Total: LKR ${sale.total.toStringAsFixed(2)}'),
                Text(
                  'Paid: LKR ${sale.amountPaid.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
                Text(
                  settled
                      ? 'Settled'
                      : 'Due: LKR ${sale.balanceDue.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: settled ? Colors.green : colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Payment history tile ─────────────────────────────────────────────────────

class _PaymentHistoryTile extends StatelessWidget {
  const _PaymentHistoryTile({required this.payment});
  final CreditPayment payment;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: const Icon(Icons.payments, color: Colors.green),
        ),
        title: Text(
          'LKR ${payment.amount.toStringAsFixed(2)} · ${payment.paymentMethod.name.toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(payment.collectedAt.toString().split('.')[0]),
            if (payment.saleId != null)
              Text(
                'Applied to: ${payment.saleId!.substring(0, 8).toUpperCase()}',
                style: TextStyle(
                    fontSize: 11, color: colorScheme.onSurfaceVariant),
              ),
            if (payment.notes?.isNotEmpty == true)
              Text(
                payment.notes!,
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Collect Payment bottom sheet ─────────────────────────────────────────────

class CollectPaymentSheet extends ConsumerStatefulWidget {
  final String customerPhone;
  final double outstanding;
  final List<CreditSaleSummary> sales;
  final VoidCallback onPaymentRecorded;

  const CollectPaymentSheet({
    super.key,
    required this.customerPhone,
    required this.outstanding,
    required this.sales,
    required this.onPaymentRecorded,
  });

  @override
  ConsumerState<CollectPaymentSheet> createState() => _CollectPaymentSheetState();
}

class _CollectPaymentSheetState extends ConsumerState<CollectPaymentSheet> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  CreditPaymentMethod _paymentMethod = CreditPaymentMethod.cash;
  // null = FIFO general payment; non-null = targeted sale
  String? _targetSaleId;
  bool _isSubmitting = false;
  String? _amountError;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _maxAmount {
    if (_targetSaleId == null) return widget.outstanding;
    final sale = widget.sales.firstWhere(
      (s) => s.saleId == _targetSaleId,
      orElse: () => widget.sales.first,
    );
    return sale.balanceDue;
  }

  String? _validateAmount(String? val) {
    final parsed = double.tryParse(val ?? '');
    if (parsed == null || parsed <= 0) return 'Enter a valid amount';
    if (parsed > _maxAmount + 0.001) {
      return 'Cannot exceed outstanding balance of LKR ${_maxAmount.toStringAsFixed(2)}';
    }
    return null;
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    final amountErr = _validateAmount(_amountController.text.trim());
    if (amountErr != null) {
      setState(() => _amountError = amountErr);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _amountError = null;
    });

    final result = await ref
        .read(customerDetailProvider(widget.customerPhone).notifier)
        .recordPayment(
          customerPhone: widget.customerPhone,
          targetSaleId: _targetSaleId,
          amount: amount!,
          paymentMethod: _paymentMethod,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          onSuccess: widget.onPaymentRecorded,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: Colors.red,
          ),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment recorded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 24 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Collect Payment',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Total outstanding: LKR ${widget.outstanding.toStringAsFixed(2)}',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          // Sale selector (optional)
          if (widget.sales.length > 1) ...[
            DropdownButtonFormField<String?>(
              initialValue: _targetSaleId,
              decoration: const InputDecoration(
                labelText: 'Apply to (optional)',
                border: OutlineInputBorder(),
                helperText: 'Leave blank to auto-apply to oldest sale first',
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Auto — oldest sale first'),
                ),
                ...widget.sales.map((s) => DropdownMenuItem(
                      value: s.saleId,
                      child: Text(
                        '${s.saleId.substring(0, 8).toUpperCase()} · Due LKR ${s.balanceDue.toStringAsFixed(2)}',
                      ),
                    )),
              ],
              onChanged: (val) => setState(() {
                _targetSaleId = val;
                _amountError = null;
              }),
            ),
            const SizedBox(height: 16),
          ],

          // Amount field
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: 'LKR ',
              border: const OutlineInputBorder(),
              errorText: _amountError,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() => _amountError = null),
          ),
          const SizedBox(height: 4),
          // Quick-fill buttons
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: Text('Full (${_maxAmount.toStringAsFixed(2)})'),
                onPressed: () {
                  _amountController.text = _maxAmount.toStringAsFixed(2);
                  setState(() => _amountError = null);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Payment method
          SegmentedButton<CreditPaymentMethod>(
            segments: const [
              ButtonSegment(
                  value: CreditPaymentMethod.cash, label: Text('Cash')),
              ButtonSegment(
                  value: CreditPaymentMethod.card, label: Text('Card')),
            ],
            selected: {_paymentMethod},
            onSelectionChanged: (s) =>
                setState(() => _paymentMethod = s.first),
          ),
          const SizedBox(height: 16),

          // Notes field
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('RECORD PAYMENT'),
          ),
        ],
      ),
    );
  }
}
