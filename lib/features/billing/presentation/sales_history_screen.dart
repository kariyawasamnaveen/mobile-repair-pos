import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/billing/presentation/billing_controller.dart';
import 'package:pos_system/features/billing/presentation/receipt_screen.dart';

class SalesHistoryScreen extends ConsumerWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesState = ref.watch(salesHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(salesHistoryProvider.notifier).loadSales(),
          ),
        ],
      ),
      body: salesState.when(
        data: (sales) {
          if (sales.isEmpty) return const Center(child: Text('No sales found.'));
          
          return ListView.builder(
            itemCount: sales.length,
            itemBuilder: (context, index) {
              final sale = sales[index];
              return ListTile(
                title: Text('Sale: ${sale.id.substring(0, 8).toUpperCase()} - LKR ${sale.total}'),
                subtitle: Text('${sale.createdAt.toString().split('.')[0]} | ${sale.paymentMethod.name.toUpperCase()}'),
                trailing: const Icon(Icons.receipt),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ReceiptScreen(sale: sale)));
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
