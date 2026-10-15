import 'dart:math';

enum FacilityType { agriculture, factory }

class FacilityRecipe {
  final Map<String, int> inputs; // Girdiler (Örn: {'wheat': 2})
  final String outputItemId;     // Çıktı (Örn: 'flour')
  final int outputAmount;        // Kaç adet çıkıyor
  final double durationSeconds;  // Kaç saniyede bir

  const FacilityRecipe({
    required this.inputs,
    required this.outputItemId,
    required this.outputAmount,
    required this.durationSeconds,
  });

  /// Dakika başı üretilen adet (60 saniye / durationSeconds * outputAmount)
  double get itemsPerMinute => (outputAmount * 60.0) / durationSeconds;
}

class ProductionFacility {
  final String id;
  final String blueprintId;
  final String name;
  final String emoji;
  final String description;
  final FacilityType type;
  final FacilityRecipe recipe;
  final double purchaseCost;
  final double baseUpgradeCost;

  int level;
  double progress; // 0.0 - 1.0
  bool isProducing;
  String statusMessage;

  ProductionFacility({
    required this.id,
    String? blueprintId,
    required this.name,
    required this.emoji,
    required this.description,
    required this.type,
    required this.recipe,
    required this.purchaseCost,
    required this.baseUpgradeCost,
    this.level = 1,
    this.progress = 0.0,
    this.isProducing = true,
    this.statusMessage = 'Üretim Hazır',
  }) : blueprintId = blueprintId ?? id;

  double get upgradeCost => baseUpgradeCost * pow(1.5, level - 1);
  double get effectiveDuration => max(2.0, recipe.durationSeconds * (1.0 - (level - 1) * 0.08));
  int get effectiveOutput => level <= 2 ? recipe.outputAmount : (recipe.outputAmount * (1.0 + (level - 2) * 0.25)).round();

  /// Dakika başı mevcut seviyedeki üretim adedi
  double get itemsPerMinute => (effectiveOutput * 60.0) / effectiveDuration;

  /// Temel (1. Seviye) dakika başı üretim adedi
  double get baseItemsPerMinute => recipe.itemsPerMinute;

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

  ProductionFacility copy({String? newId}) {
    return ProductionFacility(
      id: newId ?? '${id}_${DateTime.now().millisecondsSinceEpoch}',
      blueprintId: blueprintId,
      name: name,
      emoji: emoji,
      description: description,
      type: type,
      recipe: recipe,
      purchaseCost: purchaseCost,
      baseUpgradeCost: baseUpgradeCost,
      level: level,
      progress: progress,
      isProducing: isProducing,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'blueprintId': blueprintId,
    'level': level,
    'progress': progress,
    'isProducing': isProducing,
  };

  static ProductionFacility? fromJson(Map<String, dynamic> json) {
    final bpId = json['blueprintId'] as String? ?? json['id'] as String;
    final blueprints = getBlueprints();
    final match = blueprints.firstWhere(
      (b) => b.id == bpId || bpId.startsWith(b.id),
      orElse: () => blueprints.first,
    );
    final fac = match.copy(newId: json['id'] as String?);
    fac.level = (json['level'] as num?)?.toInt() ?? 1;
    fac.progress = (json['progress'] as num?)?.toDouble() ?? 0.0;
    fac.isProducing = json['isProducing'] as bool? ?? true;
    return fac;
  }

  static List<ProductionFacility> getBlueprints() {
    return [
      // ==========================================
      // 1. TARIM, MADENCİLİK VE DOĞAL KAYNAKLAR (Girdisiz Hammadde Üretimi)
      // ==========================================
      ProductionFacility(
        id: 'wheat_farm',
        name: 'Buğday Tarlası',
        emoji: '🌾',
        description: 'Bereketli tarla. Her hasatta un fabrikalarına gidecek buğday üretir.',
        type: FacilityType.agriculture,
        recipe: const FacilityRecipe(
          inputs: {},
          outputItemId: 'wheat',
          outputAmount: 10,
          durationSeconds: 6.0,
        ),
        purchaseCost: 5000.0,
        baseUpgradeCost: 2500.0,
      ),
      ProductionFacility(
        id: 'potato_field',
        name: 'Patates Tarlası',
        emoji: '🥔',
        description: 'Taze patates yetiştirir. Fast food zincirleri ve cips tesisleri için idealdir.',
        type: FacilityType.agriculture,
        recipe: const FacilityRecipe(
          inputs: {},
          outputItemId: 'potato',
          outputAmount: 10,
          durationSeconds: 6.5,
        ),
        purchaseCost: 6500.0,
        baseUpgradeCost: 3250.0,
      ),
      ProductionFacility(
        id: 'fruit_orchard',
        name: 'Meyve Bahçesi',
        emoji: '🍊',
        description: 'Meyve suyu ve içecek üretimi için taze narenciye yetiştirir.',
        type: FacilityType.agriculture,
        recipe: const FacilityRecipe(
          inputs: {},
          outputItemId: 'fruit',
          outputAmount: 8,
          durationSeconds: 7.0,
        ),
        purchaseCost: 7500.0,
        baseUpgradeCost: 3750.0,
      ),
      ProductionFacility(
        id: 'cotton_field',
        name: 'Pamuk Arazisi',
        emoji: '🧶',
        description: 'Tekstil sanayisi için lifli ham pamuk toplar.',
        type: FacilityType.agriculture,
        recipe: const FacilityRecipe(
          inputs: {},
          outputItemId: 'cotton',
          outputAmount: 6,
          durationSeconds: 8.0,
        ),
        purchaseCost: 8500.0,
        baseUpgradeCost: 4250.0,
      ),
      ProductionFacility(
        id: 'dairy_farm',
        name: 'Mandıra Çiftliği',
        emoji: '🐄',
        description: 'Sağmal inek çiftliği. Peynir ve çikolata üretimi için çiğ süt sağlar.',
        type: FacilityType.agriculture,
        recipe: const FacilityRecipe(
          inputs: {},
          outputItemId: 'milk',
          outputAmount: 6,
          durationSeconds: 7.5,
        ),
        purchaseCost: 8000.0,
        baseUpgradeCost: 4000.0,
      ),
      ProductionFacility(
        id: 'coffee_plantation',
        name: 'Kahve Plantasyonu',
        emoji: '🌿',
        description: 'Yüksek rakımlı tropikal tarla. Özel kahve çekirdekleri hasat eder.',
        type: FacilityType.agriculture,
        recipe: const FacilityRecipe(
          inputs: {},
          outputItemId: 'coffee_bean',
          outputAmount: 5,
          durationSeconds: 8.5,
        ),
        purchaseCost: 14000.0,
        baseUpgradeCost: 7000.0,
      ),
      ProductionFacility(
        id: 'lumber_camp',
        name: 'Orman İşletmesi & Kereste Kampı',
        emoji: '🌲',
        description: 'Sürdürülebilir ormancılık. Mobilya ve inşaat için masif ham tomruk keser.',
        type: FacilityType.agriculture,
        recipe: const FacilityRecipe(
          inputs: {},
          outputItemId: 'wood_log',
          outputAmount: 6,
          durationSeconds: 8.0,
        ),
        purchaseCost: 15000.0,
        baseUpgradeCost: 7500.0,
      ),
      ProductionFacility(
        id: 'cocoa_plantation',
        name: 'Kakao Plantasyonu',
        emoji: '🍫',
        description: 'Ekvatoral aromatik kakao ağaçları. Çikolata sanayisinin temel girdisi.',
        type: FacilityType.agriculture,
        recipe: const FacilityRecipe(
          inputs: {},
          outputItemId: 'cocoa',
          outputAmount: 5,
          durationSeconds: 9.0,
        ),
        purchaseCost: 34000.0,
        baseUpgradeCost: 17000.0,
      ),
      ProductionFacility(
        id: 'iron_mine',
        name: 'Demir Madeni Ocağı',
        emoji: '⛏️',
        description: 'Derin maden galerilerinden ağır sanayi için ham demir cevheri çıkarır.',
        type: FacilityType.agriculture,
        recipe: const FacilityRecipe(
          inputs: {},
          outputItemId: 'iron_ore',
          outputAmount: 4,
          durationSeconds: 9.5,
        ),
        purchaseCost: 48000.0,
        baseUpgradeCost: 24000.0,
      ),
      ProductionFacility(
        id: 'oil_derrick',
        name: 'Petrol Sondaj Kulesi',
        emoji: '🛢️',
        description: 'Zengin rezervlerden siyah altın çeker. Petrokimya ve plastik üretiminin temeli.',
        type: FacilityType.agriculture,
        recipe: const FacilityRecipe(
          inputs: {},
          outputItemId: 'crude_oil',
          outputAmount: 4,
          durationSeconds: 10.0,
        ),
        purchaseCost: 70000.0,
        baseUpgradeCost: 35000.0,
      ),

      // ==========================================
      // 2. SANAYİ VE İMALAT FABRİKALARI (Hammaddeleri İşler ve Değer Katar)
      // ==========================================
      ProductionFacility(
        id: 'flour_mill',
        name: 'Un Değirmeni',
        emoji: '🥣',
        description: '2 çuval Buğdayı öğüterek 1 çuval kaliteli Un üretir.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          inputs: {'wheat': 2},
          outputItemId: 'flour',
          outputAmount: 1,
          durationSeconds: 5.0,
        ),
        purchaseCost: 12000.0,
        baseUpgradeCost: 6000.0,
      ),
      ProductionFacility(
        id: 'bakery_facility',
        name: 'Endüstriyel Ekmek Fırını',
        emoji: '🥖',
        description: '1 çuval Unu işleyip 2 somun taze Ekmek pişirir. Büfelerin ana tedarikçisi.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          inputs: {'flour': 1},
          outputItemId: 'bread',
          outputAmount: 2,
          durationSeconds: 4.5,
        ),
        purchaseCost: 14000.0,
        baseUpgradeCost: 7000.0,
      ),
      ProductionFacility(
        id: 'fries_processing',
        name: 'Patates İşleme & Kızartma Tesisi',
        emoji: '🍟',
        description: '2 adet taze Patatesi işleyip 1 külah Çıtır Patates üretir.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          inputs: {'potato': 2},
          outputItemId: 'french_fries',
          outputAmount: 1,
          durationSeconds: 5.0,
        ),
        purchaseCost: 16000.0,
        baseUpgradeCost: 8000.0,
      ),
      ProductionFacility(
        id: 'juice_factory',
        name: 'Meyve Suyu Dolum Tesisi',
        emoji: '🧃',
        description: '2 adet taze Meyveyi sıkarak 1 şişe doğal Meyve Suyu üretir.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          inputs: {'fruit': 2},
          outputItemId: 'juice',
          outputAmount: 1,
          durationSeconds: 5.5,
        ),
        purchaseCost: 18000.0,
        baseUpgradeCost: 9000.0,
      ),
      ProductionFacility(
        id: 'coffee_roastery',
        name: 'Kahve Kavurma & Çekme Tesisi',
        emoji: '☕',
        description: '1 adet çiğ Kahve Çekirdeğini fırınlayıp 1 paket taze Kavrulmuş Kahve yapar.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          inputs: {'coffee_bean': 1},
          outputItemId: 'roasted_coffee',
          outputAmount: 1,
          durationSeconds: 5.0,
        ),
        purchaseCost: 42000.0,
        baseUpgradeCost: 21000.0,
      ),
      ProductionFacility(
        id: 'weaving_factory',
        name: 'Dokuma & İplik Fabrikası',
        emoji: '🧵',
        description: '2 adet Ham Pamuğu işleyip 1 rulo Dokuma Kumaş üretir.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          inputs: {'cotton': 2},
          outputItemId: 'fabric',
          outputAmount: 1,
          durationSeconds: 6.5,
        ),
        purchaseCost: 50000.0,
        baseUpgradeCost: 25000.0,
      ),
      ProductionFacility(
        id: 'cheese_factory',
        name: 'Peynir Mandırası',
        emoji: '🧀',
        description: '2 litre Çiğ Sütü mayalayarak 1 kalıp sofralık taze Peynir üretir.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          inputs: {'milk': 2},
          outputItemId: 'cheese',
          outputAmount: 1,
          durationSeconds: 5.5,
        ),
        purchaseCost: 11000.0,
        baseUpgradeCost: 5500.0,
      ),
      ProductionFacility(
        id: 'sawmill',
        name: 'Hızar & Kereste Atölyesi',
        emoji: '🪚',
        description: '2 adet Ham Tomruğu hızardan geçirip 1 adet İşlenmiş Kereste yapar.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          inputs: {'wood_log': 2},
          outputItemId: 'plank',
          outputAmount: 1,
          durationSeconds: 6.5,
        ),
        purchaseCost: 55000.0,
        baseUpgradeCost: 27500.0,
      ),
      ProductionFacility(
        id: 'garment_atelier',
        name: 'Konfeksiyon & Dikim Atölyesi',
        emoji: '👗',
        description: '2 rulo Kumaşı dikip 1 adet şık Hazır Giyim kıyafeti üretir.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          inputs: {'fabric': 2},
          outputItemId: 'clothes',
          outputAmount: 1,
          durationSeconds: 7.0,
        ),
        purchaseCost: 68000.0,
        baseUpgradeCost: 34000.0,
      ),
      ProductionFacility(
        id: 'chocolate_factory',
        name: 'Artisan Çikolata Fabrikası',
        emoji: '🍫',
        description: '2 Kakao ve 1 Çiğ Sütü harmanlayarak 1 kutu Gurme Çikolata üretir.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          inputs: {'cocoa': 2, 'milk': 1},
          outputItemId: 'gourmet_chocolate',
          outputAmount: 1,
          durationSeconds: 7.5,
        ),
        purchaseCost: 80000.0,
        baseUpgradeCost: 40000.0,
      ),
      ProductionFacility(
        id: 'furniture_factory',
        name: 'Mobilya & Marangozluk Fabrikası',
        emoji: '🪑',
        description: '2 adet İşlenmiş Keresteden 1 adet Tasarım Ahşap Sandalye imal eder.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          inputs: {'plank': 2},
          outputItemId: 'furniture_chair',
          outputAmount: 1,
          durationSeconds: 8.0,
        ),
        purchaseCost: 98000.0,
        baseUpgradeCost: 49000.0,
      ),
      ProductionFacility(
        id: 'steel_mill',
        name: 'Demir-Çelik Dökümhanesi',
        emoji: '🏗️',
        description: '2 adet Demir Cevherini yüksek fırında eriterek 1 adet Çelik Külçe döker.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          inputs: {'iron_ore': 2},
          outputItemId: 'steel_ingot',
          outputAmount: 1,
          durationSeconds: 8.5,
        ),
        purchaseCost: 115000.0,
        baseUpgradeCost: 57500.0,
      ),
      ProductionFacility(
        id: 'petrochem_plant',
        name: 'Petrokimya & Polimer Tesisi',
        emoji: '🧪',
        description: '1 varil Ham Petrolü rafine ederek 1 torba Sanayi Plastiği granülü üretir.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          inputs: {'crude_oil': 1},
          outputItemId: 'plastic_pellet',
          outputAmount: 1,
          durationSeconds: 7.5,
        ),
        purchaseCost: 130000.0,
        baseUpgradeCost: 65000.0,
      ),
      ProductionFacility(
        id: 'electronics_factory',
        name: 'Yüksek Teknoloji & Çip Fabrikası',
        emoji: '🔬',
        description: '1 Çelik Külçe ve 1 Sanayi Plastiğini mikro çiplerle birleştirip 1 Akıllı Telefon üretir.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          inputs: {'steel_ingot': 1, 'plastic_pellet': 1},
          outputItemId: 'smartphone',
          outputAmount: 1,
          durationSeconds: 10.0,
        ),
        purchaseCost: 240000.0,
        baseUpgradeCost: 120000.0,
      ),
    ];
  }
}
