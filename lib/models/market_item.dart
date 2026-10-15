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

  // Oyuncu pazardan toptan alırken ödediği fiyat (%3 borsa payı)
  double get wholesaleBuyPrice => double.parse((currentPrice * 1.03).toStringAsFixed(2));

  // Oyuncunun pazara toptan satarken kazandığı net nakit (%3 komisyon kesintisi)
  double get wholesaleSellPrice => double.parse((currentPrice * 0.97).toStringAsFixed(2));

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
