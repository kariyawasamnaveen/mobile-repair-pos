import 'package:drift/drift.dart';

enum ItemCategory { phone, accessory, sparePart, other }
enum MovementReason { sale, restock, adjustment, returnItem }
enum PaymentMethod { cash, card, credit }

@DataClassName('SettingItem')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  
  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('ItemEntity')
class Items extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get name => text()();
  TextColumn get internalCode => text().unique()(); // CAT-0001
  TextColumn get barcode => text().nullable()();
  TextColumn get category => textEnum<ItemCategory>()();
  RealColumn get purchasePrice => real()();
  RealColumn get sellingPrice => real()();
  IntColumn get quantity => integer().withDefault(const Constant(0))();
  IntColumn get reorderLevel => integer().withDefault(const Constant(5))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {barcode},
  ];
}

@DataClassName('StockMovementEntity')
class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get itemId => text().references(Items, #id)();
  TextColumn get saleId => text().nullable()(); // links movement to a specific sale
  IntColumn get changeAmount => integer()();
  TextColumn get reason => textEnum<MovementReason>()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('ItemImeiEntity')
class ItemImeis extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get itemId => text().references(Items, #id)();
  TextColumn get imei => text().unique()();
  BoolColumn get isSold => boolean().withDefault(const Constant(false))();
}

@DataClassName('SaleEntity')
class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get customerName => text().nullable()();
  TextColumn get customerPhone => text().nullable()();
  RealColumn get subtotal => real()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get total => real()();
  TextColumn get paymentMethod => textEnum<PaymentMethod>()();
  BoolColumn get isCreditSale => boolean().withDefault(const Constant(false))();
  RealColumn get amountPaid => real()();
  RealColumn get balanceDue => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SaleItemEntity')
class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get itemId => text().references(Items, #id)();
  IntColumn get quantitySold => integer()();
  RealColumn get unitPriceAtSale => real()();
  TextColumn get imeiSold => text().nullable()();
}
