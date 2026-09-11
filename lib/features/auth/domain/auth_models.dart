import 'package:pos_system/core/database/tables.dart';

class StaffMember {
  final String id;
  final String name;
  final StaffRole role;
  final bool isActive;
  final DateTime createdAt;

  StaffMember({
    required this.id,
    required this.name,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  bool get isOwner => role == StaffRole.owner;
  bool get isCashier => role == StaffRole.cashier;
  bool get isTechnician => role == StaffRole.technician;
}
