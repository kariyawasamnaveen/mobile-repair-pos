import 'package:pos_system/core/database/app_database.dart' show DiscountRuleEntity;
import 'package:pos_system/core/database/tables.dart' show DiscountType, DiscountScope;

class DiscountRule {
  final String id;
  final String name;
  final DiscountType type;
  final double value;
  final DiscountScope scope;
  final String? scopeReference;
  final double? minPurchaseAmount;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final String? branchId;

  DiscountRule({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    required this.scope,
    this.scopeReference,
    this.minPurchaseAmount,
    required this.isActive,
    this.startDate,
    this.endDate,
    required this.createdAt,
    this.branchId,
  });

  factory DiscountRule.fromEntity(DiscountRuleEntity entity) {
    return DiscountRule(
      id: entity.id,
      name: entity.name,
      type: entity.type,
      value: entity.value,
      scope: entity.scope,
      scopeReference: entity.scopeReference,
      minPurchaseAmount: entity.minPurchaseAmount,
      isActive: entity.isActive,
      startDate: entity.startDate,
      endDate: entity.endDate,
      createdAt: entity.createdAt,
      branchId: entity.branchId,
    );
  }

  bool isValidForDate(DateTime date) {
    if (startDate != null && date.isBefore(startDate!)) return false;
    if (endDate != null && date.isAfter(endDate!)) return false;
    return true;
  }
}
