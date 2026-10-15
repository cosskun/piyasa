import 'item.dart';

enum OfferStatus {
  pending, // Beklemede (satıcı düşünüyor)
  accepted, // Onaylandı (satın alınabilir)
  rejected, // Reddedildi
  completed, // Satın alma tamamlandı
  expired, // Normal fiyattan başkasına satıldı veya geçersiz kaldı
}

enum OfferDirection {
  incoming, // Diğer oyuncuların bizim ilanımıza verdiği teklif (Gelen Teklif)
  outgoing, // Bizim diğer oyuncunun ilanına verdiğimiz teklif (Verilen Teklif)
}

class MarketOffer {
  final String id;
  final String listingId;
  final String itemId;
  final String buyerName;
  final String sellerName;
  final int quantity;
  final double originalPricePerUnit;
  final double offeredPricePerUnit;
  final OfferDirection direction;
  OfferStatus status;
  final DateTime createdAt;
  double decisionTimer;
  final String message;

  MarketOffer({
    required this.id,
    required this.listingId,
    required this.itemId,
    required this.buyerName,
    required this.sellerName,
    required this.quantity,
    required this.originalPricePerUnit,
    required this.offeredPricePerUnit,
    required this.direction,
    this.status = OfferStatus.pending,
    required this.createdAt,
    this.decisionTimer = 0.0,
    this.message = 'Şu fiyata olur mu?',
  });

  ItemData get item => ItemRegistry.get(itemId)!;
  double get totalOfferedPrice => quantity * offeredPricePerUnit;
  double get totalOriginalPrice => quantity * originalPricePerUnit;
  double get discountPercent =>
      originalPricePerUnit > 0 ? ((originalPricePerUnit - offeredPricePerUnit) / originalPricePerUnit) * 100 : 0.0;
}
