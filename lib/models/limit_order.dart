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

  Map<String, dynamic> toJson() => {
    'id': id,
    'itemId': itemId,
    'targetPrice': targetPrice,
    'quantity': quantity,
    'totalReservedCost': totalReservedCost,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'executedAt': executedAt?.toIso8601String(),
    'executedPrice': executedPrice,
    'statusMessage': statusMessage,
  };

  static LimitBuyOrder fromJson(Map<String, dynamic> json) {
    return LimitBuyOrder(
      id: json['id'] as String,
      itemId: json['itemId'] as String,
      targetPrice: (json['targetPrice'] as num).toDouble(),
      quantity: (json['quantity'] as num).toInt(),
      totalReservedCost: (json['totalReservedCost'] as num).toDouble(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      status: LimitOrderStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => LimitOrderStatus.pending,
      ),
      executedAt: json['executedAt'] != null ? DateTime.tryParse(json['executedAt'] as String) : null,
      executedPrice: (json['executedPrice'] as num?)?.toDouble(),
      statusMessage: json['statusMessage'] as String?,
    );
  }
}
