import 'dart:math';

class RetailStore {
  final String id;
  final String blueprintId;
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
    String? blueprintId,
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
  }) : blueprintId = blueprintId ?? id;

  double get upgradeCost => baseUpgradeCost * pow(1.5, level - 1);
  double get effectiveInterval => max(0.8, saleIntervalSeconds - (level - 1) * 0.25);

  /// Toplam yatırılan sermaye bedeli (Satın alma maliyeti + yapılan seviye geliştirme harcamaları)
  double get totalInvestedValue {
    double total = purchaseCost;
    for (int lvl = 1; lvl < level; lvl++) {
      total += baseUpgradeCost * pow(1.5, lvl - 1);
    }
    return total;
  }

  /// Geri satış / Nakite dönüştürme bedeli (%70 ikinci el likidasyon oranı)
  double get resaleValue => (totalInvestedValue * 0.70).roundToDouble();

  RetailStore copy({String? newId}) {
    return RetailStore(
      id: newId ?? '${id}_${DateTime.now().millisecondsSinceEpoch}',
      blueprintId: blueprintId,
      name: name,
      emoji: emoji,
      description: description,
      productItemId: productItemId,
      purchaseCost: purchaseCost,
      baseUpgradeCost: baseUpgradeCost,
      shelfCapacity: shelfCapacity,
      retailPrice: retailPrice,
      saleIntervalSeconds: saleIntervalSeconds,
      level: level,
      shelfStock: shelfStock,
      autoRestock: autoRestock,
      totalRevenue: totalRevenue,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'blueprintId': blueprintId,
    'level': level,
    'shelfCapacity': shelfCapacity,
    'shelfStock': shelfStock,
    'retailPrice': retailPrice,
    'autoRestock': autoRestock,
    'totalRevenue': totalRevenue,
  };

  static RetailStore? fromJson(Map<String, dynamic> json) {
    final bpId = json['blueprintId'] as String? ?? json['id'] as String;
    final blueprints = getBlueprints();
    final match = blueprints.firstWhere(
      (b) => b.id == bpId || bpId.startsWith(b.id),
      orElse: () => blueprints.first,
    );
    final store = match.copy(newId: json['id'] as String?);
    store.level = (json['level'] as num?)?.toInt() ?? 1;
    store.shelfCapacity = (json['shelfCapacity'] as num?)?.toInt() ?? match.shelfCapacity;
    store.shelfStock = (json['shelfStock'] as num?)?.toInt() ?? 0;
    store.retailPrice = (json['retailPrice'] as num?)?.toDouble() ?? match.retailPrice;
    store.autoRestock = json['autoRestock'] as bool? ?? true;
    store.totalRevenue = (json['totalRevenue'] as num?)?.toDouble() ?? 0.0;
    return store;
  }

  static List<RetailStore> getBlueprints() {
    return [
      RetailStore(
        id: 'kiosk_bread',
        name: 'Köşe Büfe & Simitçi',
        emoji: '🏪',
        description: 'Hızlı ayaküstü perakende. Taze somun ekmek ve sıcak unlu mamul satışı.',
        productItemId: 'bread',
        purchaseCost: 4500.0,
        baseUpgradeCost: 2200.0,
        shelfCapacity: 50,
        retailPrice: 18.0,
        saleIntervalSeconds: 2.5,
      ),
      RetailStore(
        id: 'juice_bar',
        name: 'Vitamin Meyve Barı',
        emoji: '🥤',
        description: 'Taze sıkılmış doğal meyve suları ve detoks içecekleri perakendesi.',
        productItemId: 'juice',
        purchaseCost: 14000.0,
        baseUpgradeCost: 7000.0,
        shelfCapacity: 40,
        retailPrice: 48.0,
        saleIntervalSeconds: 3.2,
      ),
      RetailStore(
        id: 'fast_food_joint',
        name: 'Fast-Food & Patatesçi',
        emoji: '🍟',
        description: 'Sıcak ve çıtır altın patates külahları. Gençlerin en çok rağbet ettiği lezzet durağı.',
        productItemId: 'french_fries',
        purchaseCost: 18000.0,
        baseUpgradeCost: 9000.0,
        shelfCapacity: 45,
        retailPrice: 42.0,
        saleIntervalSeconds: 2.8,
      ),
      RetailStore(
        id: 'coffee_house',
        name: '3. Nesil Kahve Dükkanı',
        emoji: '☕',
        description: 'Özel fırınlanmış aromatik kahve paketleri ve gurme kahve çeşitleri.',
        productItemId: 'roasted_coffee',
        purchaseCost: 26000.0,
        baseUpgradeCost: 13000.0,
        shelfCapacity: 35,
        retailPrice: 85.0,
        saleIntervalSeconds: 3.5,
      ),
      RetailStore(
        id: 'delicatessen_shop',
        name: 'Gurme Şarküteri & Peynirci',
        emoji: '🧀',
        description: 'Sofralık doğal köy peynirleri ve mandıra lezzetleri perakendesi.',
        productItemId: 'cheese',
        purchaseCost: 35000.0,
        baseUpgradeCost: 17500.0,
        shelfCapacity: 30,
        retailPrice: 115.0,
        saleIntervalSeconds: 4.2,
      ),
      RetailStore(
        id: 'clothing_boutique',
        name: 'Moda & Giyim Butiği',
        emoji: '👗',
        description: 'Kaliteli hazır giyim, gömlek, ceket ve pantolon perakende satışı.',
        productItemId: 'clothes',
        purchaseCost: 48000.0,
        baseUpgradeCost: 24000.0,
        shelfCapacity: 25,
        retailPrice: 260.0,
        saleIntervalSeconds: 5.5,
      ),
      RetailStore(
        id: 'chocolatier_shop',
        name: 'Artisan Çikolata Butiği',
        emoji: '🍫',
        description: 'El yapımı özel çikolatalar ve şık kutu hediyelikler satan prestijli butik.',
        productItemId: 'gourmet_chocolate',
        purchaseCost: 65000.0,
        baseUpgradeCost: 32500.0,
        shelfCapacity: 25,
        retailPrice: 210.0,
        saleIntervalSeconds: 4.8,
      ),
      RetailStore(
        id: 'furniture_showroom',
        name: 'Tasarım Mobilya Mağazası',
        emoji: '🛋️',
        description: 'Doğal ahşap salon mobilyaları, modern sandalyeler ve dekorasyon ürünleri.',
        productItemId: 'furniture_chair',
        purchaseCost: 110000.0,
        baseUpgradeCost: 55000.0,
        shelfCapacity: 20,
        retailPrice: 320.0,
        saleIntervalSeconds: 6.5,
      ),
      RetailStore(
        id: 'electronics_store',
        name: 'Teknoloji & Telefon Mağazası',
        emoji: '📱',
        description: 'En son model akıllı telefonlar ve akıllı cihazlar satan yüksek kârlı teknoloji zinciri.',
        productItemId: 'smartphone',
        purchaseCost: 240000.0,
        baseUpgradeCost: 120000.0,
        shelfCapacity: 15,
        retailPrice: 680.0,
        saleIntervalSeconds: 7.5,
      ),
    ];
  }
}
