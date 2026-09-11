import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/core/error/failure.dart';
import 'package:pos_system/features/billing/domain/cart_item.dart';
import 'package:pos_system/features/billing/domain/sale.dart';
import 'package:pos_system/providers/app_providers.dart';

import 'package:pos_system/features/auth/data/activity_log_repository.dart';

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository(
    ref.watch(databaseProvider),
    ref.watch(activityLogRepositoryProvider),
  );
});

class BillingRepository {
  final AppDatabase _db;
  final ActivityLogRepository _activityLogRepo;
  final _uuid = const Uuid();

  BillingRepository(this._db, this._activityLogRepo);

  Future<Either<Failure, Sale>> processSale({
    required List<CartItem> cart,
    required double subtotal,
    required double discount,
    required double total,
    required PaymentMethod paymentMethod,
    String? customerName,
    String? customerPhone,
    bool isCreditSale = false,
    double amountPaid = 0.0,
    double balanceDue = 0.0,
    double? amountTendered,
    double? changeDue,
    String? cashierName,
    String? staffId, // for activity logging
  }) async {
    try {
      final saleId = _uuid.v4();
      final now = DateTime.now();

      final saleItemsList = <SaleItem>[];

      await _db.transaction(() async {
        // 1. Insert Sale
        await _db.into(_db.sales).insert(
              SalesCompanion.insert(
                id: saleId,
                customerName: Value(customerName),
                customerPhone: Value(customerPhone),
                subtotal: subtotal,
                discount: Value(discount),
                total: total,
                paymentMethod: paymentMethod,
                isCreditSale: Value(isCreditSale),
                amountPaid: amountPaid,
                balanceDue: Value(balanceDue),
                amountTendered: Value(amountTendered),
                changeDue: Value(changeDue),
                cashierName: Value(cashierName),
                createdAt: Value(now),
              ),
            );

        // 2. Insert Sale Items, update stock, log movements, mark IMEIs sold
        for (final cartItem in cart) {
          if (cartItem.isSerialized) {
            for (final imei in cartItem.selectedImeis) {
              await _db.into(_db.saleItems).insert(
                    SaleItemsCompanion.insert(
                      saleId: saleId,
                      itemId: cartItem.itemId,
                      quantitySold: 1,
                      unitPriceAtSale: cartItem.unitPrice,
                      imeiSold: Value(imei),
                    ),
                  );

              await (_db.update(_db.itemImeis)
                    ..where((t) => t.imei.equals(imei) & t.itemId.equals(cartItem.itemId)))
                  .write(const ItemImeisCompanion(isSold: Value(true)));

              saleItemsList.add(SaleItem(
                itemId: cartItem.itemId,
                itemName: cartItem.itemName,
                quantitySold: 1,
                unitPriceAtSale: cartItem.unitPrice,
                imeiSold: imei,
              ));
            }
            
            // Deduct overall item quantity for serialized items
            final itemRow = await (_db.select(_db.items)..where((t) => t.id.equals(cartItem.itemId))).getSingle();
            await (_db.update(_db.items)..where((t) => t.id.equals(cartItem.itemId))).write(
              ItemsCompanion(quantity: Value(itemRow.quantity - cartItem.selectedImeis.length)),
            );
            
            await _db.into(_db.stockMovements).insert(
                  StockMovementsCompanion.insert(
                    itemId: cartItem.itemId,
                    saleId: Value(saleId),
                    changeAmount: -cartItem.selectedImeis.length,
                    reason: MovementReason.sale,
                  ),
                );

          } else {
            // Non-serialized item
            await _db.into(_db.saleItems).insert(
                  SaleItemsCompanion.insert(
                    saleId: saleId,
                    itemId: cartItem.itemId,
                    quantitySold: cartItem.quantity,
                    unitPriceAtSale: cartItem.unitPrice,
                  ),
                );

            final itemRow = await (_db.select(_db.items)..where((t) => t.id.equals(cartItem.itemId))).getSingle();
            await (_db.update(_db.items)..where((t) => t.id.equals(cartItem.itemId))).write(
              ItemsCompanion(quantity: Value(itemRow.quantity - cartItem.quantity)),
            );

            await _db.into(_db.stockMovements).insert(
                  StockMovementsCompanion.insert(
                    itemId: cartItem.itemId,
                    saleId: Value(saleId),
                    changeAmount: -cartItem.quantity,
                    reason: MovementReason.sale,
                  ),
                );

            saleItemsList.add(SaleItem(
              itemId: cartItem.itemId,
              itemName: cartItem.itemName,
              quantitySold: cartItem.quantity,
              unitPriceAtSale: cartItem.unitPrice,
            ));
          }
        }
      });

      await _activityLogRepo.logAction(
        staffId: staffId,
        actionType: ActivityActionType.sale_created,
        description: 'Completed sale of LKR $total (${paymentMethod.name})',
      );

      return Right(Sale(
        id: saleId,
        customerName: customerName,
        customerPhone: customerPhone,
        subtotal: subtotal,
        discount: discount,
        total: total,
        paymentMethod: paymentMethod,
        isCreditSale: isCreditSale,
        amountPaid: amountPaid,
        balanceDue: balanceDue,
        amountTendered: amountTendered,
        changeDue: changeDue,
        cashierName: cashierName,
        createdAt: now,
        items: saleItemsList,
      ));
    } catch (e, st) {
      return Left(Failure('Failed to process sale: $e', error: e, stackTrace: st));
    }
  }

  Future<Either<Failure, List<Sale>>> getSalesHistory({DateTime? startDate, DateTime? endDate}) async {
    try {
      final query = _db.select(_db.sales)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

      if (startDate != null && endDate != null) {
        query.where((t) => t.createdAt.isBetweenValues(startDate, endDate));
      }

      final salesRows = await query.get();
      final sales = <Sale>[];
      final saleIds = salesRows.map((r) => r.id).toList();
      
      final Map<String, List<SaleItem>> saleItemsMap = {};
      if (saleIds.isNotEmpty) {
        final itemsQuery = _db.select(_db.saleItems).join([
          innerJoin(_db.items, _db.items.id.equalsExp(_db.saleItems.itemId))
        ])..where(_db.saleItems.saleId.isIn(saleIds));
        
        final itemsResult = await itemsQuery.get();
        for (final res in itemsResult) {
          final saleItem = res.readTable(_db.saleItems);
          final item = res.readTable(_db.items);
          
          saleItemsMap.putIfAbsent(saleItem.saleId, () => []).add(SaleItem(
            itemId: item.id,
            itemName: item.name,
            quantitySold: saleItem.quantitySold,
            unitPriceAtSale: saleItem.unitPriceAtSale,
            imeiSold: saleItem.imeiSold,
          ));
        }
      }

      for (final row in salesRows) {
        final saleItems = saleItemsMap[row.id] ?? [];

        sales.add(Sale(
          id: row.id,
          customerName: row.customerName,
          customerPhone: row.customerPhone,
          subtotal: row.subtotal,
          discount: row.discount,
          total: row.total,
          paymentMethod: row.paymentMethod,
          isCreditSale: row.isCreditSale,
          amountPaid: row.amountPaid,
          balanceDue: row.balanceDue,
          amountTendered: row.amountTendered,
          changeDue: row.changeDue,
          cashierName: row.cashierName,
          createdAt: row.createdAt,
          items: saleItems,
        ));
      }

      return Right(sales);
    } catch (e, st) {
      return Left(Failure('Failed to load sales history', error: e, stackTrace: st));
    }
  }
}
