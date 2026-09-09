import 'package:pos_system/core/database/tables.dart';

class Item {
  final String id;
  final String name;
  final String internalCode;
  final String? barcode;
  final ItemCategory category;
  final double purchasePrice;
  final double sellingPrice;
  final int quantity;
  final int reorderLevel;
  final List<String> imeis;

  const Item({
    required this.id,
    required this.name,
    required this.internalCode,
    this.barcode,
    required this.category,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.quantity,
    required this.reorderLevel,
    this.imeis = const [],
  });
}
