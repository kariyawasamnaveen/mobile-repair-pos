// ignore_for_file: constant_identifier_names
import 'package:drift/drift.dart';

enum ItemCategory { phone, accessory, sparePart, other }
enum MovementReason { sale, restock, adjustment, returnItem, repairUsage, purchaseReceived }
enum PaymentMethod { cash, card, credit, qr }
enum RepairJobStatus { received, diagnosing, awaitingCustomerApproval, inProgress, readyForPickup, delivered, cancelled }
enum CreditPaymentMethod {
  cash,
  card,
  bankTransfer,
  qr,
}

enum DiscountType {
  percentage,
  fixedAmount,
}

enum DiscountScope {
  entireSale,
  specificCategory,
  specificItem,
}

enum PurchaseOrderStatus { draft, ordered, partiallyReceived, received, cancelled }
enum StaffRole { owner, cashier, technician }
enum ActivityActionType { sale_created, item_price_changed, stock_adjusted, repair_status_changed, payment_collected, settings_changed, staff_login, po_created, po_received, supplier_payment }

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
  TextColumn get branchId => text().references(Branches, #id).nullable()();

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
  TextColumn get branchId => text().references(Branches, #id).nullable()();
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
  RealColumn get taxAmount => real().nullable()();
  RealColumn get taxRateApplied => real().nullable()();
  RealColumn get total => real()();
  TextColumn get paymentMethod => textEnum<PaymentMethod>()();
  BoolColumn get isCreditSale => boolean().withDefault(const Constant(false))();
  RealColumn get amountPaid => real()();
  RealColumn get balanceDue => real().withDefault(const Constant(0.0))();
  RealColumn get amountTendered => real().nullable()();
  RealColumn get changeDue => real().nullable()();
  TextColumn get cashierName => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get branchId => text().references(Branches, #id).nullable()();
  TextColumn get appliedDiscountRuleName => text().nullable()();

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

@DataClassName('RepairJobEntity')
class RepairJobs extends Table {
  TextColumn get id => text()();
  TextColumn get jobNumber => text()(); // RJ-0001
  TextColumn get customerName => text()();
  TextColumn get customerPhone => text()();
  TextColumn get deviceModel => text().nullable()();
  TextColumn get deviceImei => text().nullable()();
  TextColumn get reportedIssue => text()();
  TextColumn get deviceConditionNotes => text()();
  TextColumn get status => textEnum<RepairJobStatus>()();
  TextColumn get assignedTechnicianName => text().nullable()();
  RealColumn get estimatedCost => real().nullable()();
  RealColumn get finalCost => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get statusUpdatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  TextColumn get branchId => text().references(Branches, #id).nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RepairStatusHistoryEntity')
class RepairStatusHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get jobId => text().references(RepairJobs, #id)();
  TextColumn get previousStatus => textEnum<RepairJobStatus>().nullable()();
  TextColumn get newStatus => textEnum<RepairJobStatus>()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('RepairJobPartEntity')
class RepairJobParts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get jobId => text().references(RepairJobs, #id)();
  TextColumn get itemId => text().references(Items, #id)();
  IntColumn get quantityUsed => integer()();
  RealColumn get unitPrice => real()();
}

/// Records each credit payment collected from a customer.
/// [saleId] is nullable — null means the payment was a general payment
/// and the repository applies it to the oldest outstanding sale(s).
@DataClassName('CreditPaymentEntity')
class CreditPayments extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get customerPhone => text()();
  TextColumn get saleId => text().nullable()(); // which sale this was applied to
  RealColumn get amount => real()();
  TextColumn get paymentMethod => textEnum<CreditPaymentMethod>()();
  DateTimeColumn get collectedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StaffMemberEntity')
class StaffMembers extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get name => text()();
  TextColumn get pinHash => text()();
  TextColumn get salt => text()();
  TextColumn get role => textEnum<StaffRole>()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('BranchEntity')
class Branches extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get name => text()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ActivityLogEntity')
class ActivityLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get staffId => text().nullable().references(StaffMembers, #id)();
  TextColumn get actionType => textEnum<ActivityActionType>()();
  TextColumn get description => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get branchId => text().references(Branches, #id).nullable()();
}

@DataClassName('SupplierEntity')
class Suppliers extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PurchaseOrderEntity')
class PurchaseOrders extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get poNumber => text().unique()(); // PO-0001
  TextColumn get supplierId => text().references(Suppliers, #id)();
  TextColumn get status => textEnum<PurchaseOrderStatus>().withDefault(const Constant('draft'))();
  DateTimeColumn get orderDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get expectedDate => dateTime().nullable()();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  RealColumn get amountPaid => real().withDefault(const Constant(0.0))();
  RealColumn get balanceDue => real().withDefault(const Constant(0.0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get branchId => text().references(Branches, #id).nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PurchaseOrderItemEntity')
class PurchaseOrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get purchaseOrderId => text().references(PurchaseOrders, #id)();
  TextColumn get itemId => text().nullable().references(Items, #id)();
  TextColumn get itemNameText => text().nullable()(); // fallback if item not in inventory
  IntColumn get quantityOrdered => integer()();
  IntColumn get quantityReceived => integer().withDefault(const Constant(0))();
  RealColumn get unitCost => real()();
  RealColumn get lineTotal => real()();
}

@DataClassName('SupplierPaymentEntity')
class SupplierPayments extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get supplierId => text().references(Suppliers, #id)();
  TextColumn get purchaseOrderId => text().nullable().references(PurchaseOrders, #id)();
  RealColumn get amount => real()();
  TextColumn get paymentMethod => textEnum<CreditPaymentMethod>()();
  DateTimeColumn get paidAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DiscountRuleEntity')
class DiscountRules extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => textEnum<DiscountType>()();
  RealColumn get value => real()();
  TextColumn get scope => textEnum<DiscountScope>()();
  TextColumn get scopeReference => text().nullable()();
  RealColumn get minPurchaseAmount => real().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get branchId => text().references(Branches, #id).nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
