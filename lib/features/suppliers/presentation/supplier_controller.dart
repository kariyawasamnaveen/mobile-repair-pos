import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/suppliers/data/supplier_repository.dart';
import 'package:pos_system/features/suppliers/domain/supplier.dart';

final suppliersProvider = FutureProvider.autoDispose<List<SupplierWithBalance>>((ref) async {
  final repo = ref.watch(supplierRepositoryProvider);
  final res = await repo.getSuppliersWithBalance();
  return res.fold((l) => throw l.message, (r) => r);
});

final supplierDetailProvider = FutureProvider.family.autoDispose<Supplier, String>((ref, id) async {
  final repo = ref.watch(supplierRepositoryProvider);
  final res = await repo.getSupplierById(id);
  return res.fold((l) => throw l.message, (r) => r);
});

final purchaseOrdersProvider = FutureProvider.family.autoDispose<List<PurchaseOrder>, String?>((ref, supplierId) async {
  final repo = ref.watch(supplierRepositoryProvider);
  final res = await repo.getPurchaseOrders(supplierId: supplierId);
  return res.fold((l) => throw l.message, (r) => r);
});

final purchaseOrderDetailProvider = FutureProvider.family.autoDispose<PurchaseOrder, String>((ref, id) async {
  final repo = ref.watch(supplierRepositoryProvider);
  final res = await repo.getPurchaseOrderById(id);
  return res.fold((l) => throw l.message, (r) => r);
});
