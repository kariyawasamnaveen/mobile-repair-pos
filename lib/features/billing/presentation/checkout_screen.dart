import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/features/billing/presentation/billing_controller.dart';
import 'package:pos_system/features/inventory/domain/item.dart';
import 'package:pos_system/features/inventory/presentation/inventory_controller.dart';
import 'package:pos_system/features/billing/presentation/payment_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  String _scanBuffer = '';

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_scanBuffer.isNotEmpty) {
        _handleScan(_scanBuffer);
        _scanBuffer = '';
      }
    } else {
      final char = event.character;
      if (char != null) _scanBuffer += char;
    }
  }

  void _handleScan(String query) {
    _searchController.text = query;
    ref.read(inventoryControllerProvider.notifier).setSearchQuery(query);
  }

  void _showImeiSelection(BuildContext context, Item item) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Select IMEI for ${item.name}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: item.imeis.length,
              itemBuilder: (ctx, index) {
                final imei = item.imeis[index];
                return ListTile(
                  title: Text(imei),
                  onTap: () {
                    ref.read(cartProvider.notifier).addItem(item, imei: imei);
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final subtotal = ref.watch(cartProvider.notifier).subtotal;
    final discount = ref.watch(discountProvider);
    final total = subtotal - discount;
    final inventoryState = ref.watch(inventoryControllerProvider);

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: Row(
          children: [
            // Left Side: Inventory Search & List
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search / Scan Items',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        ref.read(inventoryControllerProvider.notifier).setSearchQuery(val);
                      },
                    ),
                  ),
                  Expanded(
                    child: inventoryState.when(
                      data: (items) {
                        return ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final outOfStock = item.quantity <= 0;
                            return ListTile(
                              title: Text(item.name),
                              subtitle: Text('LKR ${item.sellingPrice} | Stock: ${item.quantity}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_shopping_cart),
                                onPressed: outOfStock ? null : () {
                                  if (item.category == ItemCategory.phone) {
                                    _showImeiSelection(context, item);
                                  } else {
                                    ref.read(cartProvider.notifier).addItem(item);
                                  }
                                },
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Center(child: Text('Error: $error')),
                    ),
                  ),
                ],
              ),
            ),
            
            const VerticalDivider(width: 1),
            
            // Right Side: Cart
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    child: const Center(child: Text('Current Cart', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  ),
                  Expanded(
                    child: cart.isEmpty
                        ? const Center(child: Text('Cart is empty'))
                        : ListView.builder(
                            itemCount: cart.length,
                            itemBuilder: (context, index) {
                              final cartItem = cart[index];
                              return Card(
                                margin: const EdgeInsets.all(4),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(child: Text(cartItem.itemName, style: const TextStyle(fontWeight: FontWeight.bold))),
                                          Text('LKR ${cartItem.total}'),
                                        ],
                                      ),
                                      if (cartItem.isSerialized) ...[
                                        for (final imei in cartItem.selectedImeis)
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('  IMEI: $imei', style: const TextStyle(fontSize: 12)),
                                              IconButton(
                                                icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                                onPressed: () => ref.read(cartProvider.notifier).removeImei(cartItem.itemId, imei),
                                              ),
                                            ],
                                          )
                                      ] else ...[
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove_circle_outline),
                                              onPressed: () => ref.read(cartProvider.notifier).updateQuantity(cartItem.itemId, cartItem.quantity - 1),
                                            ),
                                            Text('${cartItem.quantity}'),
                                            IconButton(
                                              icon: const Icon(Icons.add_circle_outline),
                                              onPressed: () => ref.read(cartProvider.notifier).updateQuantity(cartItem.itemId, cartItem.quantity + 1),
                                            ),
                                            const Spacer(),
                                            Text('@ LKR ${cartItem.unitPrice}'),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, -2))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal:'),
                            Text('LKR $subtotal'),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Discount:'),
                            SizedBox(
                              width: 100,
                              child: TextField(
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(isDense: true, hintText: '0.0'),
                                onChanged: (val) {
                                  final d = double.tryParse(val) ?? 0.0;
                                  ref.read(discountProvider.notifier).state = d;
                                },
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text('LKR $total', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: cart.isEmpty ? null : () {
                            Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const PaymentScreen()));
                          },
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                          child: const Text('PROCEED TO PAYMENT'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
