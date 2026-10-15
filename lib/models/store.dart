import 'dart:math';

class RetailStore {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final String productItemId;
  final double purchaseCost;
  final double baseUpgradeCost;

  int level;
  int shelfCapacity;
  int shelfStock;
  double retailPrice;
  double saleIntervalSeconds;
  double timerProgress;
  bool autoRestock;
  double totalRevenue;
  String statusMessage;

  RetailStore({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.productItemId,
    required this.purchaseCost,
    required this.baseUpgradeCost,
    required this.shelfCapacity,
    required this.retailPrice,
    required this.saleIntervalSeconds,
    this.level = 1,
    this.shelfStock = 0,
    this.timerProgress = 0.0,
    this.autoRestock = true,
    this.totalRevenue = 0.0,
    this.statusMessage = 'Müşteri Bekleniyor',
  });

  double get upgradeCost => baseUpgradeCost * pow(1.5, level - 1);
  double get effectiveInterval => max(0.8, saleIntervalSeconds - (level - 1) * 0.25);

  RetailStore copy({String? newId}) {
    return RetailStore(
      id: newId ?? '${id}_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      emoji: emoji,
      description: description,
      productItemId: productItemId,
      purchaseCost: purchaseCost,
      baseUpgradeCost: baseUpgradeCost,
      shelfCapacity: shelfCapacity,
      retailPrice: retailPrice,
      saleIntervalSeconds: saleIntervalSeconds,
    );
  }

  static List<RetailStore> getBlueprints() {
    return [
      RetailStore(
        id: 'kiosk_bread',
        name: 'Köşe Büfe & Simitçi',
        emoji: '🏪',
        description: 'Hızlı ayaküstü perakende. Somun ekmek ve atıştırmalık satışı.',
        productItemId: 'bread',
        purchaseCost: 4500.0,
        baseUpgradeCost: 2200.0,
        shelfCapacity: 50,
        retailPrice: 15.0,
        saleIntervalSeconds: 2.5,
      ),
      RetailStore(
        id: 'juice_bar',
        name: 'Vitamin Meyve Barı',
        emoji: '🥤',
        description: 'Taze sıkılmış meyve suları ve detoks içecekleri.',
        productItemId: 'juice',
        purchaseCost: 14000.0,
        baseUpgradeCost: 7000.0,
        shelfCapacity: 40,
        retailPrice: 45.0,
        saleIntervalSeconds: 3.2,
      ),
      RetailStore(
        id: 'coffee_house',
        name: '3. Nesil Kahve Dükkanı',
        emoji: '☕',
        description: 'Özel demlenmiş aromatik filtre kahveler.',
        productItemId: 'coffee_cup',
        purchaseCost: 26000.0,
        baseUpgradeCost: 13000.0,
        shelfCapacity: 35,
        retailPrice: 60.0,
        saleIntervalSeconds: 3.8,
      ),
      RetailStore(
        id: 'clothing_boutique',
        name: 'Moda & Giyim Butiği',
        emoji: '👗',
        description: 'Kaliteli hazır giyim, gömlek ve pantolon perakende satışı.',
        productItemId: 'clothes',
        purchaseCost: 48000.0,
        baseUpgradeCost: 24000.0,
        shelfCapacity: 25,
        retailPrice: 250.0,
        saleIntervalSeconds: 5.5,
      ),
    ];
  }
}
