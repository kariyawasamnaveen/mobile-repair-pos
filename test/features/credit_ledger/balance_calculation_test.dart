import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/features/billing/data/billing_repository.dart';
import 'package:pos_system/features/billing/domain/cart_item.dart';
import 'package:pos_system/features/auth/data/activity_log_repository.dart';
import 'package:pos_system/features/settings/data/settings_repository.dart';
import 'package:pos_system/features/credit_ledger/data/credit_ledger_repository.dart';
import 'package:pos_system/core/database/tables.dart';

void main() {
  group('Naya Potha (Credit Ledger) Balance Logic', () {
    late AppDatabase db;
    late BillingRepository billingRepo;
    late CreditLedgerRepository creditRepo;
    late ActivityLogRepository activityLogRepo;
    late SettingsRepository settingsRepo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      activityLogRepo = ActivityLogRepository(db);
      settingsRepo = SettingsRepository(db, activityLogRepo);
      billingRepo = BillingRepository(db, activityLogRepo, settingsRepo);
      creditRepo = CreditLedgerRepository(db);
    });

    Future<void> setupItem(String id) async {
      await db.into(db.items).insert(ItemsCompanion.insert(
        id: id, internalCode: 'C_$id', name: id, category: ItemCategory.accessory,
        purchasePrice: 10.0, sellingPrice: 100.0, quantity: const Value(100), reorderLevel: const Value(5),
      ));
    }

    tearDown(() async {
      await db.close();
    });

    test('A credit sale with partial payment correctly computes balance_due = total - amount_paid', () async {
      await setupItem('ITEM-1');
      final cartItem = CartItem(
        itemId: 'ITEM-1', itemName: 'Item 1', unitPrice: 1000.0, quantity: 1, selectedImeis: [], maxQuantity: 10, isSerialized: false,
      );

      final result = await billingRepo.processSale(
        cart: [cartItem],
        subtotal: 1000.0,
        discount: 0.0,
        total: 1000.0,
        paymentMethod: PaymentMethod.credit,
        isCreditSale: true,
        amountPaid: 200.0,
        balanceDue: 800.0,
        customerName: 'Saman',
        customerPhone: '0771234567',
      );

      expect(result.isRight(), isTrue);
      
      final saleId = result.getRight().toNullable()!.id;
      final saleRow = await (db.select(db.sales)..where((t) => t.id.equals(saleId))).getSingle();
      
      expect(saleRow.balanceDue, equals(800.0)); // 1000 - 200
    });

    test('Recording a payment reduces balance_due correctly', () async {
      await setupItem('ITEM-1');
      final cartItem = CartItem(
        itemId: 'ITEM-1', itemName: 'Item 1', unitPrice: 1000.0, quantity: 1, selectedImeis: [], maxQuantity: 10, isSerialized: false,
      );

      final saleRes = await billingRepo.processSale(
        cart: [cartItem], subtotal: 1000.0, discount: 0.0, total: 1000.0,
        paymentMethod: PaymentMethod.credit, isCreditSale: true, amountPaid: 200.0, balanceDue: 800.0,
        customerName: 'Saman', customerPhone: '0771234567',
      );
      final saleId = saleRes.getRight().toNullable()!.id;

      final payRes = await creditRepo.recordPayment(
        customerPhone: '0771234567',
        amount: 300.0,
        targetSaleId: saleId,
        paymentMethod: CreditPaymentMethod.cash,
      );
      expect(payRes.isRight(), isTrue);

      final saleRow = await (db.select(db.sales)..where((t) => t.id.equals(saleId))).getSingle();
      expect(saleRow.balanceDue, equals(500.0)); // 800 - 300
    });

    test('FIFO payment application: general payment drains oldest sale first', () async {
      await setupItem('I1');
      final cartItem1 = CartItem(itemId: 'I1', itemName: 'I1', unitPrice: 1000.0, quantity: 1, selectedImeis: [], maxQuantity: 10, isSerialized: false);
      final sale1 = await billingRepo.processSale(
        cart: [cartItem1], subtotal: 1000.0, discount: 0.0, total: 1000.0,
        paymentMethod: PaymentMethod.credit, isCreditSale: true, amountPaid: 0.0, balanceDue: 1000.0,
        customerName: 'Saman', customerPhone: '0771234567',
      );

      // Simulate a small delay or just rely on autoincrement ID since sales are sorted by date
      await Future.delayed(const Duration(milliseconds: 10));

      await setupItem('I2');
      final cartItem2 = CartItem(itemId: 'I2', itemName: 'I2', unitPrice: 500.0, quantity: 1, selectedImeis: [], maxQuantity: 10, isSerialized: false);
      final sale2 = await billingRepo.processSale(
        cart: [cartItem2], subtotal: 500.0, discount: 0.0, total: 500.0,
        paymentMethod: PaymentMethod.credit, isCreditSale: true, amountPaid: 0.0, balanceDue: 500.0,
        customerName: 'Saman', customerPhone: '0771234567',
      );

      final sale1Id = sale1.getRight().toNullable()!.id;
      final sale2Id = sale2.getRight().toNullable()!.id;

      // Total owed is 1500. We pay 1200 generally (no specific saleId).
      // It should fully clear sale1 (1000 -> 0) and partially clear sale2 (500 -> 300).
      final payRes = await creditRepo.recordPayment(customerPhone: '0771234567', amount: 1200.0, paymentMethod: CreditPaymentMethod.cash);
      expect(payRes.isRight(), isTrue);

      final s1Row = await (db.select(db.sales)..where((t) => t.id.equals(sale1Id))).getSingle();
      final s2Row = await (db.select(db.sales)..where((t) => t.id.equals(sale2Id))).getSingle();

      expect(s1Row.balanceDue, equals(0.0));
      expect(s2Row.balanceDue, equals(300.0));
    });

    test('Overpayment (payment amount > outstanding balance) is rejected', () async {
      await setupItem('I1');
      final cartItem = CartItem(itemId: 'I1', itemName: 'I1', unitPrice: 1000.0, quantity: 1, selectedImeis: [], maxQuantity: 10, isSerialized: false);
      await billingRepo.processSale(
        cart: [cartItem], subtotal: 1000.0, discount: 0.0, total: 1000.0,
        paymentMethod: PaymentMethod.credit, isCreditSale: true, amountPaid: 200.0, balanceDue: 800.0,
        customerName: 'Saman', customerPhone: '0771234567',
      );

      // Balance is 800. Try to pay 900.
      final payRes = await creditRepo.recordPayment(customerPhone: '0771234567', amount: 900.0, paymentMethod: CreditPaymentMethod.cash);
      
      expect(payRes.isLeft(), isTrue);
      expect(payRes.fold((l) => l.message, (r) => ''), contains('exceeds total outstanding balance'));
    });

    test('Total outstanding balance correctly sums across all unpaid/partial sales', () async {
      await setupItem('I1');
      final cartItem = CartItem(itemId: 'I1', itemName: 'I1', unitPrice: 1000.0, quantity: 1, selectedImeis: [], maxQuantity: 10, isSerialized: false);
      await billingRepo.processSale(
        cart: [cartItem], subtotal: 1000.0, discount: 0.0, total: 1000.0,
        paymentMethod: PaymentMethod.credit, isCreditSale: true, amountPaid: 200.0, balanceDue: 800.0,
        customerName: 'Saman', customerPhone: '0771234567',
      );
      await billingRepo.processSale(
        cart: [cartItem], subtotal: 1000.0, discount: 0.0, total: 1000.0,
        paymentMethod: PaymentMethod.credit, isCreditSale: true, amountPaid: 500.0, balanceDue: 500.0,
        customerName: 'Saman', customerPhone: '0771234567',
      );

      // Customer should owe 800 + 500 = 1300
      final summaryRes = await creditRepo.getOutstandingCustomers();
      expect(summaryRes.isRight(), isTrue);
      
      final summaries = summaryRes.getRight().toNullable()!;
      expect(summaries.length, equals(1));
      expect(summaries.first.totalOutstanding, equals(1300.0));
    });
  });
}
