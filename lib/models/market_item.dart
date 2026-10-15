import 'dart:math';
import 'item.dart';

class MarketItem {
  final String itemId;
  double currentPrice;
  int marketSupply;
  double lastChangePercent;
  final List<double> priceHistory;

  MarketItem({
    required this.itemId,
    required this.currentPrice,
    this.marketSupply = 3000,
    this.lastChangePercent = 0.0,
    List<double>? history,
  }) : priceHistory = history ?? [currentPrice];

  ItemData get data => ItemRegistry.get(itemId)!;

  // Hızlı Alış Fiyatı (Sistemden anında toptan çekme)
  double get quickBuyPrice => double.parse((currentPrice * 1.08).toStringAsFixed(2));

  // Hızlı Satış Fiyatı (Sisteme anında satıp acil nakite çevirme: Düşük kâr marjı, %15 iskonto)
  double get quickSellPrice => double.parse((currentPrice * 0.85).toStringAsFixed(2));

  // Geriye dönük uyumluluk için alias
  double get wholesaleBuyPrice => quickBuyPrice;
  double get wholesaleSellPrice => quickSellPrice;

  void updatePrice({double bias = 0.0, required Random rnd}) {
    // -%4 ile +%4 arası rastgele piyasa dalgalanması + alım/satım bias'ı
    double delta = (rnd.nextDouble() * 0.08 - 0.04) + bias;
    double oldPrice = currentPrice;
    double newPrice = currentPrice * (1.0 + delta);

    if (newPrice < data.minPrice) newPrice = data.minPrice;
    if (newPrice > data.maxPrice) newPrice = data.maxPrice;

    currentPrice = double.parse(newPrice.toStringAsFixed(2));
    lastChangePercent = double.parse((((currentPrice - oldPrice) / oldPrice) * 100).toStringAsFixed(1));

    priceHistory.add(currentPrice);
    if (priceHistory.length > 20) {
      priceHistory.removeAt(0);
    }
  }
}
