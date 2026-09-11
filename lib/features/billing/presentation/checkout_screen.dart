import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/core/scanning/camera_scanner_sheet.dart';
import 'package:pos_system/features/billing/presentation/billing_controller.dart';
import 'package:pos_system/features/inventory/domain/item.dart';
import 'package:pos_system/features/inventory/presentation/inventory_controller.dart';
import 'package:pos_system/features/billing/presentation/payment_screen.dart';
import 'package:pos_system/core/theme/app_theme.dart';
import 'package:pos_system/features/settings/presentation/settings_controller.dart';

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
    final theme = Theme.of(context);

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
                  icon: const Icon(Icons.shopping_cart_outlined),
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
                        color: theme.colorScheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$totalItems',
                        style: TextStyle(color: theme.colorScheme.onError, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppThemeConstants.spacing8),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: AppThemeConstants.defaultPadding,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search / Scan Items',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (val) {
                        ref.read(inventoryControllerProvider.notifier).setSearchQuery(val);
                      },
                    ),
                  ),
                  const SizedBox(width: AppThemeConstants.spacing8),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppThemeConstants.radiusInput),
                    ),
                    child: IconButton(
                      tooltip: 'Scan barcode with camera',
                      icon: Icon(Icons.qr_code_scanner, size: 28, color: theme.colorScheme.onSecondaryContainer),
                      onPressed: () async {
                        final result = await showCameraScannerSheet(context);
                        if (result != null) _handleScan(result);
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: inventoryState.when(
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: AppThemeConstants.spacing16),
                          Text('No items found.', style: theme.textTheme.titleMedium),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final outOfStock = item.quantity <= 0;
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing16, vertical: AppThemeConstants.spacing8),
                          title: Text(item.name, style: theme.textTheme.titleMedium?.copyWith(
                            color: outOfStock ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                          )),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: AppThemeConstants.spacing4),
                            child: Row(
                              children: [
                                Text('LKR ${item.sellingPrice}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                                const SizedBox(width: AppThemeConstants.spacing12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: outOfStock ? theme.colorScheme.errorContainer : theme.colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Stock: ${item.quantity}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: outOfStock ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.add_shopping_cart, color: outOfStock ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary),
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
    
    final settings = ref.watch(storeSettingsProvider).valueOrNull;
    final isTaxEnabled = settings?.isTaxEnabled ?? false;
    final taxRate = settings?.taxRate ?? 0.0;
    final taxName = settings?.taxName ?? 'Tax';
    final isTaxInclusive = settings?.isTaxInclusive ?? false;

    double total = subtotal - discount;
    double? taxAmount;

    if (isTaxEnabled && taxRate > 0) {
      if (isTaxInclusive) {
        taxAmount = total - (total / (1 + taxRate / 100));
      } else {
        taxAmount = total * (taxRate / 100);
        total += taxAmount;
      }
    }

    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppThemeConstants.radiusDialog)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle and Title
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppThemeConstants.spacing12),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppThemeConstants.spacing12),
                Text('Current Cart', style: theme.textTheme.titleLarge),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          
          // Cart Items List
          Flexible(
            child: cart.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppThemeConstants.spacing32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.remove_shopping_cart_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: AppThemeConstants.spacing16),
                        Text('Cart is empty', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: AppThemeConstants.spacing8),
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final cartItem = cart[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing16, vertical: AppThemeConstants.spacing4),
                        child: Padding(
                          padding: const EdgeInsets.all(AppThemeConstants.spacing12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(cartItem.itemName, style: theme.textTheme.titleMedium)),
                                  const SizedBox(width: AppThemeConstants.spacing8),
                                  Text('LKR ${cartItem.total}', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
                                ],
                              ),
                              if (cartItem.isSerialized) ...[
                                for (final imei in cartItem.selectedImeis)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('  IMEI: $imei', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                      IconButton(
                                        icon: Icon(Icons.close, size: 16, color: theme.colorScheme.error),
                                        onPressed: () => ref.read(cartProvider.notifier).removeImei(cartItem.itemId, imei),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  )
                              ] else ...[
                                const SizedBox(height: AppThemeConstants.spacing8),
                                Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.remove, size: 20, color: theme.colorScheme.onSurface),
                                            padding: const EdgeInsets.all(AppThemeConstants.spacing4),
                                            constraints: const BoxConstraints(),
                                            onPressed: () => ref.read(cartProvider.notifier).updateQuantity(cartItem.itemId, cartItem.quantity - 1),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing8),
                                            child: Text('${cartItem.quantity}', style: theme.textTheme.titleMedium),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.add, size: 20, color: theme.colorScheme.onSurface),
                                            padding: const EdgeInsets.all(AppThemeConstants.spacing4),
                                            constraints: const BoxConstraints(),
                                            onPressed: () => ref.read(cartProvider.notifier).updateQuantity(cartItem.itemId, cartItem.quantity + 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppThemeConstants.spacing12),
                                    Expanded(
                                      child: Text(
                                        '@ LKR ${cartItem.unitPrice}',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        textAlign: TextAlign.right,
                                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
              left: AppThemeConstants.spacing16, right: AppThemeConstants.spacing16, top: AppThemeConstants.spacing16, 
              bottom: MediaQuery.of(context).padding.bottom + AppThemeConstants.spacing16
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal:', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(width: AppThemeConstants.spacing8),
                    Expanded(
                      child: Text(
                        'LKR $subtotal',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppThemeConstants.spacing8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Discount:', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(width: AppThemeConstants.spacing8),
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          isDense: true, 
                          hintText: '0.0',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary)),
                          contentPadding: const EdgeInsets.symmetric(vertical: AppThemeConstants.spacing4),
                        ),
                        onChanged: (val) {
                          final d = double.tryParse(val) ?? 0.0;
                          ref.read(discountProvider.notifier).state = d;
                        },
                      ),
                    ),
                  ],
                ),
                if (isTaxEnabled && taxAmount != null) ...[
                  const SizedBox(height: AppThemeConstants.spacing8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$taxName ($taxRate%${isTaxInclusive ? ' incl.' : ''}):', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(width: AppThemeConstants.spacing8),
                      Expanded(
                        child: Text(
                          'LKR ${taxAmount.toStringAsFixed(2)}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          textAlign: TextAlign.right,
                          style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
                Divider(height: AppThemeConstants.spacing24, color: theme.dividerColor),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total:', style: theme.textTheme.titleLarge),
                    const SizedBox(width: AppThemeConstants.spacing8),
                    Expanded(
                      child: Text(
                        'LKR $total',
                        style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppThemeConstants.spacing16),
                FilledButton(
                  onPressed: cart.isEmpty ? null : () {
                    // Close the bottom sheet first
                    Navigator.pop(context);
                    // Then navigate to payment
                    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const PaymentScreen()));
                  },
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
