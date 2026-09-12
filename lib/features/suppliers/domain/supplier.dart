import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/core/database/app_database.dart';

class Supplier {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;

  const Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.notes,
    required this.isActive,
    required this.createdAt,
  });

  factory Supplier.fromEntity(SupplierEntity e) => Supplier(
    id: e.id,
    name: e.name,
    phone: e.phone,
    address: e.address,
    notes: e.notes,
    isActive: e.isActive,
    createdAt: e.createdAt,
  );
}

class PurchaseOrder {
  final String id;
  final String poNumber;
  final String supplierId;
  final PurchaseOrderStatus status;
  final DateTime orderDate;
  final DateTime? expectedDate;
  final double totalAmount;
  final double amountPaid;
  final double balanceDue;
  final String? notes;
  final DateTime createdAt;
  final List<PurchaseOrderItem> items;
  final Supplier? supplier; // To hold resolved supplier if needed
  final String? branchId;

  const PurchaseOrder({
    required this.id,
    required this.poNumber,
    required this.supplierId,
    required this.status,
    required this.orderDate,
    this.expectedDate,
    required this.totalAmount,
    required this.amountPaid,
    required this.balanceDue,
    this.notes,
    required this.createdAt,
    this.items = const [],
    this.supplier,
    this.branchId,
  });

  factory PurchaseOrder.fromEntity(PurchaseOrderEntity e, {List<PurchaseOrderItem> items = const [], Supplier? supplier}) => PurchaseOrder(
    id: e.id,
    poNumber: e.poNumber,
    supplierId: e.supplierId,
    status: e.status,
    orderDate: e.orderDate,
    expectedDate: e.expectedDate,
    totalAmount: e.totalAmount,
    amountPaid: e.amountPaid,
    balanceDue: e.balanceDue,
    notes: e.notes,
    createdAt: e.createdAt,
    items: items,
    supplier: supplier,
    branchId: e.branchId,
  );

  PurchaseOrder copyWith({
    String? id,
    String? poNumber,
    String? supplierId,
    PurchaseOrderStatus? status,
    DateTime? orderDate,
    DateTime? expectedDate,
    double? totalAmount,
    double? amountPaid,
    double? balanceDue,
    String? notes,
    DateTime? createdAt,
    List<PurchaseOrderItem>? items,
    Supplier? supplier,
    String? branchId,
  }) {
    return PurchaseOrder(
      id: id ?? this.id,
      poNumber: poNumber ?? this.poNumber,
      supplierId: supplierId ?? this.supplierId,
      status: status ?? this.status,
      orderDate: orderDate ?? this.orderDate,
      expectedDate: expectedDate ?? this.expectedDate,
      totalAmount: totalAmount ?? this.totalAmount,
      amountPaid: amountPaid ?? this.amountPaid,
      balanceDue: balanceDue ?? this.balanceDue,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
      supplier: supplier ?? this.supplier,
      branchId: branchId ?? this.branchId,
    );
  }
}

class PurchaseOrderItem {
  final int id;
  final String purchaseOrderId;
  final String? itemId;
  final String? itemNameText;
  final int quantityOrdered;
  final int quantityReceived;
  final double unitCost;
  final double lineTotal;

  String get displayName => itemNameText ?? 'Unknown Item';

  const PurchaseOrderItem({
    required this.id,
    required this.purchaseOrderId,
    this.itemId,
    this.itemNameText,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.unitCost,
    required this.lineTotal,
  });

  factory PurchaseOrderItem.fromEntity(PurchaseOrderItemEntity e) => PurchaseOrderItem(
    id: e.id,
    purchaseOrderId: e.purchaseOrderId,
    itemId: e.itemId,
    itemNameText: e.itemNameText,
    quantityOrdered: e.quantityOrdered,
    quantityReceived: e.quantityReceived,
    unitCost: e.unitCost,
    lineTotal: e.lineTotal,
  );
}

class SupplierPayment {
  final String id;
  final String supplierId;
  final String? purchaseOrderId;
  final double amount;
  final CreditPaymentMethod paymentMethod;
  final DateTime paidAt;
  final String? notes;

  const SupplierPayment({
    required this.id,
    required this.supplierId,
    this.purchaseOrderId,
    required this.amount,
    required this.paymentMethod,
    required this.paidAt,
    this.notes,
  });

  factory SupplierPayment.fromEntity(SupplierPaymentEntity e) => SupplierPayment(
    id: e.id,
    supplierId: e.supplierId,
    purchaseOrderId: e.purchaseOrderId,
    amount: e.amount,
    paymentMethod: e.paymentMethod,
    paidAt: e.paidAt,
    notes: e.notes,
  );
}

class SupplierWithBalance {
  final Supplier supplier;
  final double balanceDue;

  const SupplierWithBalance({
    required this.supplier,
    required this.balanceDue,
  });
}
