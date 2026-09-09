import 'package:pos_system/core/database/tables.dart';

class StockMovement {
  final int id;
  final String itemId;
  final int changeAmount;
  final MovementReason reason;
  final DateTime timestamp;

  const StockMovement({
    required this.id,
    required this.itemId,
    required this.changeAmount,
    required this.reason,
    required this.timestamp,
  });
}
