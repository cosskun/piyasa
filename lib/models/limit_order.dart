import 'item.dart';

enum LimitOrderStatus {
  pending,   // Fiyatın hedef seviyeye düşmesi bekleniyor
  completed, // Hedef fiyata ulaştı ve sistem tarafından otomatik satın alındı
  cancelled, // Oyuncu tarafından iptal edildi ve bakiye iade edildi
}

class LimitBuyOrder {
  final String id;
  final String itemId;
  final double targetPrice;
  final int quantity;
  final double totalReservedCost;
  final DateTime createdAt;

  LimitOrderStatus status;
  DateTime? executedAt;
  double? executedPrice;
  String? statusMessage;

  LimitBuyOrder({
    required this.id,
    required this.itemId,
    required this.targetPrice,
    required this.quantity,
    required this.totalReservedCost,
    required this.createdAt,
    this.status = LimitOrderStatus.pending,
    this.executedAt,
    this.executedPrice,
    this.statusMessage,
  });

  ItemData get item => ItemRegistry.get(itemId)!;
  bool get isPending => status == LimitOrderStatus.pending;
  bool get isCompleted => status == LimitOrderStatus.completed;
  bool get isCancelled => status == LimitOrderStatus.cancelled;
}
