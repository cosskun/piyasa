import 'item.dart';

class MarketListing {
  final String id;
  final String itemId;
  final int initialQuantity;
  int remainingQuantity;
  final double pricePerUnit;
  final DateTime listedAt;
  final String sellerName;
  final bool isPlayerListing;
  double totalEarned;
  double saleProgressTimer;

  MarketListing({
    required this.id,
    required this.itemId,
    required this.initialQuantity,
    required this.remainingQuantity,
    required this.pricePerUnit,
    required this.listedAt,
    this.sellerName = 'Siz',
    this.isPlayerListing = true,
    this.totalEarned = 0.0,
    this.saleProgressTimer = 0.0,
  });

  ItemData get item => ItemRegistry.get(itemId)!;
  int get soldQuantity => initialQuantity - remainingQuantity;
  bool get isCompleted => remainingQuantity <= 0;
  bool get isCommunityListing => !isPlayerListing;

  Map<String, dynamic> toJson() => {
    'id': id,
    'itemId': itemId,
    'initialQuantity': initialQuantity,
    'remainingQuantity': remainingQuantity,
    'pricePerUnit': pricePerUnit,
    'listedAt': listedAt.toIso8601String(),
    'sellerName': sellerName,
    'isPlayerListing': isPlayerListing,
    'totalEarned': totalEarned,
  };

  static MarketListing fromJson(Map<String, dynamic> json) {
    return MarketListing(
      id: json['id'] as String,
      itemId: json['itemId'] as String,
      initialQuantity: (json['initialQuantity'] as num).toInt(),
      remainingQuantity: (json['remainingQuantity'] as num).toInt(),
      pricePerUnit: (json['pricePerUnit'] as num).toDouble(),
      listedAt: DateTime.tryParse(json['listedAt'] as String? ?? '') ?? DateTime.now(),
      sellerName: json['sellerName'] as String? ?? 'Siz',
      isPlayerListing: json['isPlayerListing'] as bool? ?? true,
      totalEarned: (json['totalEarned'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
