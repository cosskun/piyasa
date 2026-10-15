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
}
