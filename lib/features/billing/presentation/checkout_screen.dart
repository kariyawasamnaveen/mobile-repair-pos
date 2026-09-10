import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/core/scanning/camera_scanner_sheet.dart';
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart'), duration: Duration(seconds: 1)));
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _openCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const CartBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCartEmpty = ref.watch(cartProvider.select((cart) => cart.isEmpty));
    final totalItems = ref.watch(cartProvider.select((cart) => cart.fold<int>(0, (sum, item) => sum + item.quantity)));
    final inventoryState = ref.watch(inventoryControllerProvider);

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Checkout'),
          actions: [
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: () {
                    if (isCartEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty'), duration: Duration(seconds: 1)));
                    } else {
                      _openCartSheet();
                    }
                  },
                ),
                if (totalItems > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$totalItems',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
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
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Scan barcode with camera',
                    icon: const Icon(Icons.qr_code_scanner, size: 28),
                    onPressed: () async {
                      final result = await showCameraScannerSheet(context);
                      if (result != null) _handleScan(result);
                    },
                  ),
                ],
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
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text('LKR ${item.sellingPrice} | Stock: ${item.quantity}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_shopping_cart),
                          onPressed: outOfStock ? null : () {
                            if (item.category == ItemCategory.phone) {
                              _showImeiSelection(context, item);
                            } else {
                              ref.read(cartProvider.notifier).addItem(item);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart'), duration: Duration(seconds: 1)));
                            }
                          },
                        ),
                        onTap: outOfStock ? null : () {
                          if (item.category == ItemCategory.phone) {
                            _showImeiSelection(context, item);
                          } else {
                            ref.read(cartProvider.notifier).addItem(item);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart'), duration: Duration(seconds: 1)));
                          }
                        },
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
    );
  }
}

// ── Cart Bottom Sheet ────────────────────────────────────────────────────────

class CartBottomSheet extends ConsumerWidget {
  const CartBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final subtotal = ref.watch(cartProvider.notifier).subtotal;
    final discount = ref.watch(discountProvider);
    final total = subtotal - discount;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle and Title
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Current Cart', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Cart Items List
          Flexible(
            child: cart.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('Cart is empty', style: TextStyle(fontSize: 16)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final cartItem = cart[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(cartItem.itemName, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  const SizedBox(width: 8),
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
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  )
                              ] else ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => ref.read(cartProvider.notifier).updateQuantity(cartItem.itemId, cartItem.quantity - 1),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('${cartItem.quantity}', style: const TextStyle(fontSize: 16)),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => ref.read(cartProvider.notifier).updateQuantity(cartItem.itemId, cartItem.quantity + 1),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '@ LKR ${cartItem.unitPrice}',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
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
          
          // Totals and Proceed Button
          Container(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 16, 
              bottom: MediaQuery.of(context).padding.bottom + 16
            ),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'LKR $subtotal',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Discount:'),
                    const SizedBox(width: 8),
                    Expanded(
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
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'LKR $total',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: cart.isEmpty ? null : () {
                    // Close the bottom sheet first
                    Navigator.pop(context);
                    // Then navigate to payment
                    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const PaymentScreen()));
                  },
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('PROCEED TO PAYMENT'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
