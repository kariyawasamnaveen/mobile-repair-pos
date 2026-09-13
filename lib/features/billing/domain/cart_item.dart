
import 'package:pos_system/core/database/tables.dart' show ItemCategory;

class CartItem {
  final String itemId;
  final String itemName;
  final ItemCategory? category;
  final String? barcode;
  final double unitPrice;
  final int maxQuantity;
  final bool isSerialized;
  
  int quantity;
  List<String> selectedImeis;

  CartItem({
    required this.itemId,
    required this.itemName,
    this.category,
    this.barcode,
    required this.unitPrice,
    required this.maxQuantity,
    required this.isSerialized,
    this.quantity = 1,
    this.selectedImeis = const [],
  });

  double get total => unitPrice * quantity;

  CartItem copyWith({
    int? quantity,
    List<String>? selectedImeis,
  }) {
    return CartItem(
      itemId: itemId,
      itemName: itemName,
      category: category,
      barcode: barcode,
      unitPrice: unitPrice,
      maxQuantity: maxQuantity,
      isSerialized: isSerialized,
      quantity: quantity ?? this.quantity,
      selectedImeis: selectedImeis ?? this.selectedImeis,
    );
  }
}
