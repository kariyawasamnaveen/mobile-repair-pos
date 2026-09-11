import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/core/theme/app_theme.dart';
import 'package:pos_system/features/suppliers/presentation/supplier_controller.dart';
import 'package:pos_system/features/suppliers/presentation/purchase_order_detail_screen.dart';

class PurchaseOrderListScreen extends ConsumerStatefulWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  ConsumerState<PurchaseOrderListScreen> createState() => _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState extends ConsumerState<PurchaseOrderListScreen> {
  PurchaseOrderStatus? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final posState = ref.watch(purchaseOrdersProvider(null));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _selectedStatus == null,
                    onSelected: (val) => setState(() => _selectedStatus = null),
                  ),
                  const SizedBox(width: 8),
                  ...PurchaseOrderStatus.values.map((status) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(status.name.toUpperCase()),
                      selected: _selectedStatus == status,
                      onSelected: (val) => setState(() => _selectedStatus = val ? status : null),
                    ),
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
      body: posState.when(
        data: (pos) {
          final filtered = _selectedStatus == null ? pos : pos.where((p) => p.status == _selectedStatus).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('No purchase orders found.'));
          }
          return ListView.builder(
            padding: AppThemeConstants.defaultPadding,
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final po = filtered[index];
              return Card(
                child: ListTile(
                  title: Text(po.poNumber, style: theme.textTheme.titleMedium),
                  subtitle: Text('${po.supplier?.name ?? 'Unknown'} • ${po.orderDate.toString().split(' ')[0]}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Rs ${po.totalAmount.toStringAsFixed(2)}'),
                      if (po.balanceDue > 0)
                        Text('Owe: Rs ${po.balanceDue.toStringAsFixed(2)}', style: TextStyle(color: AppTheme.errorColor, fontSize: 10)),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => PurchaseOrderDetailScreen(purchaseOrderId: po.id)));
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
