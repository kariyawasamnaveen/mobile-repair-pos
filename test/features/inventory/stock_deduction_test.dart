import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/features/billing/data/billing_repository.dart';
import 'package:pos_system/features/billing/domain/cart_item.dart';
import 'package:pos_system/features/auth/data/activity_log_repository.dart';
import 'package:pos_system/features/settings/data/settings_repository.dart';
import 'package:pos_system/features/inventory/data/inventory_repository.dart';
import 'package:pos_system/features/suppliers/data/supplier_repository.dart';
import 'package:pos_system/core/database/tables.dart';

void main() {
  group('Stock Deduction Logic', () {
    late AppDatabase db;
    late BillingRepository billingRepo;
    late InventoryRepository inventoryRepo;
    late SupplierRepository supplierRepo;
    late ActivityLogRepository activityLogRepo;
    late SettingsRepository settingsRepo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      activityLogRepo = ActivityLogRepository(db);
      settingsRepo = SettingsRepository(db, activityLogRepo);
      billingRepo = BillingRepository(db, activityLogRepo, settingsRepo);
      inventoryRepo = InventoryRepository(db, activityLogRepo, settingsRepo);
      supplierRepo = SupplierRepository(db, activityLogRepo, settingsRepo, null);
    });

    tearDown(() async {
      await db.close();
    });

    test('Selling a non-serialized item reduces quantity by the sold amount', () async {
      // Setup item
      final itemId = 'ITEM-001';
      await db.into(db.items).insert(ItemsCompanion.insert(
        id: itemId,
        internalCode: '001',
        name: 'Accessory',
        category: ItemCategory.accessory,
        purchasePrice: 50.0,
        sellingPrice: 100.0,
        quantity: const Value(10),
        reorderLevel: const Value(5),
      ));

      final cartItem = CartItem(
        itemId: itemId,
        itemName: 'Accessory',
        unitPrice: 100.0,
        quantity: 3,
        selectedImeis: [],
        maxQuantity: 10,
        isSerialized: false,
      );

      final result = await billingRepo.processSale(
        cart: [cartItem],
        subtotal: 300.0,
        discount: 0.0,
        total: 300.0,
        paymentMethod: PaymentMethod.cash,
        amountTendered: 300.0,
      );

      expect(result.isRight(), isTrue);

      // Verify stock
      final itemRow = await (db.select(db.items)..where((t) => t.id.equals(itemId))).getSingle();
      expect(itemRow.quantity, equals(7)); // 10 - 3 = 7

      // Verify stock movement
      final movements = await (db.select(db.stockMovements)..where((t) => t.itemId.equals(itemId))).get();
      expect(movements.length, equals(1));
      expect(movements.first.changeAmount, equals(-3));
      expect(movements.first.reason, equals(MovementReason.sale));
    });

    test('Selling a serialized item marks IMEI sold and reduces effective quantity by 1', () async {
      final itemId = 'PHONE-001';
      await db.into(db.items).insert(ItemsCompanion.insert(
        id: itemId,
        internalCode: 'P001',
        name: 'Phone',
        category: ItemCategory.phone,
        purchasePrice: 500.0,
        sellingPrice: 1000.0,
        quantity: const Value(2),
        reorderLevel: const Value(1),
      ));

      await db.into(db.itemImeis).insert(ItemImeisCompanion.insert(
        itemId: itemId, imei: 'IMEI-111', isSold: const Value(false),
      ));
      await db.into(db.itemImeis).insert(ItemImeisCompanion.insert(
        itemId: itemId, imei: 'IMEI-222', isSold: const Value(false),
      ));

      final cartItem = CartItem(
        itemId: itemId,
        itemName: 'Phone',
        unitPrice: 1000.0,
        quantity: 1,
        selectedImeis: ['IMEI-111'],
        maxQuantity: 2,
        isSerialized: true,
      );

      final result = await billingRepo.processSale(
        cart: [cartItem],
        subtotal: 1000.0,
        discount: 0.0,
        total: 1000.0,
        paymentMethod: PaymentMethod.cash,
        amountTendered: 1000.0,
      );

      expect(result.isRight(), isTrue);

      // Verify stock
      final itemRow = await (db.select(db.items)..where((t) => t.id.equals(itemId))).getSingle();
      expect(itemRow.quantity, equals(1)); // 2 - 1 = 1

      // Verify IMEI status
      final soldImei = await (db.select(db.itemImeis)..where((t) => t.imei.equals('IMEI-111'))).getSingle();
      expect(soldImei.isSold, isTrue);

      final unsoldImei = await (db.select(db.itemImeis)..where((t) => t.imei.equals('IMEI-222'))).getSingle();
      expect(unsoldImei.isSold, isFalse);

      // Verify stock movement
      final movements = await (db.select(db.stockMovements)..where((t) => t.itemId.equals(itemId))).get();
      expect(movements.length, equals(1));
      expect(movements.first.changeAmount, equals(-1));
      expect(movements.first.reason, equals(MovementReason.sale));
    });

    test('Receiving a Purchase Order item increases quantity by the received amount', () async {
      final supplierId = 'SUP-01';
      await db.into(db.suppliers).insert(SuppliersCompanion.insert(
        id: supplierId, name: 'Test Supplier',
      ));

      final itemId = 'ITEM-PO';
      await db.into(db.items).insert(ItemsCompanion.insert(
        id: itemId,
        internalCode: 'IPO',
        name: 'PO Item',
        category: ItemCategory.accessory,
        purchasePrice: 50.0,
        sellingPrice: 100.0,
        quantity: const Value(5),
        reorderLevel: const Value(2),
      ));

      final poId = 'PO-001';
      await db.into(db.purchaseOrders).insert(PurchaseOrdersCompanion.insert(
        id: poId, supplierId: supplierId, poNumber: 'PO-001',
        orderDate: Value(DateTime.now()), totalAmount: const Value(1000.0), status: const Value(PurchaseOrderStatus.ordered),
      ));

      final poItemId = await db.into(db.purchaseOrderItems).insert(PurchaseOrderItemsCompanion.insert(
        purchaseOrderId: poId, itemId: Value(itemId), quantityOrdered: 10,
        unitCost: 100.0, lineTotal: 1000.0,
      ));

      final result = await supplierRepo.receiveItems(poId, {poItemId: 4});
      expect(result.isRight(), isTrue);

      final itemRow = await (db.select(db.items)..where((t) => t.id.equals(itemId))).getSingle();
      expect(itemRow.quantity, equals(9)); // 5 + 4 = 9

      // Verify stock movement
      final movements = await (db.select(db.stockMovements)..where((t) => t.itemId.equals(itemId))).get();
      expect(movements.length, equals(1));
      expect(movements.first.changeAmount, equals(4));
      expect(movements.first.reason, equals(MovementReason.purchaseReceived));
    });

    test('Attempting to deduct more than available stock is rejected unless allowed', () async {
      final itemId = 'ITEM-NEG';
      await db.into(db.items).insert(ItemsCompanion.insert(
        id: itemId,
        internalCode: 'INEG',
        name: 'Negative Item',
        category: ItemCategory.accessory,
        purchasePrice: 50.0,
        sellingPrice: 100.0,
        quantity: const Value(2),
        reorderLevel: const Value(0),
      ));

      // Attempt to adjust stock by -5 with allowNegative = false
      final result1 = await inventoryRepo.adjustStock(itemId, -5, MovementReason.adjustment, allowNegative: false);
      expect(result1.isLeft(), isTrue);
      expect(result1.fold((l) => l.message, (r) => ''), contains('Failed to adjust stock'));

      // Verify stock remains 2
      final itemRow1 = await (db.select(db.items)..where((t) => t.id.equals(itemId))).getSingle();
      expect(itemRow1.quantity, equals(2));

      // Attempt to adjust stock by -5 with allowNegative = true
      final result2 = await inventoryRepo.adjustStock(itemId, -5, MovementReason.adjustment, allowNegative: true);
      expect(result2.isRight(), isTrue);

      // Verify stock is now -3
      final itemRow2 = await (db.select(db.items)..where((t) => t.id.equals(itemId))).getSingle();
      expect(itemRow2.quantity, equals(-3));
    });
  });
}
