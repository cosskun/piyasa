import 'dart:math';

enum FacilityType { agriculture, factory }

class FacilityRecipe {
  final String? name;            // Reçete Adı (Örn: 'Pamuklu Tişört Dikimi')
  final Map<String, int> inputs; // Girdiler (Örn: {'wheat': 2})
  final String outputItemId;     // Çıktı (Örn: 'flour')
  final int outputAmount;        // Kaç adet çıkıyor
  final double durationSeconds;  // Kaç saniyede bir

  const FacilityRecipe({
    this.name,
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
  FacilityRecipe recipe;
  final List<FacilityRecipe> availableRecipes;
  int activeRecipeIndex;
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
    required FacilityRecipe recipe,
    List<FacilityRecipe>? availableRecipes,
    this.activeRecipeIndex = 0,
    required this.purchaseCost,
    required this.baseUpgradeCost,
    this.level = 1,
    this.progress = 0.0,
    this.isProducing = true,
    this.statusMessage = 'Üretim Hazır',
  })  : blueprintId = blueprintId ?? id,
        availableRecipes = (availableRecipes != null && availableRecipes.isNotEmpty)
            ? availableRecipes
            : [recipe],
        recipe = (availableRecipes != null && availableRecipes.isNotEmpty)
            ? availableRecipes[activeRecipeIndex.clamp(0, availableRecipes.length - 1)]
            : recipe;

  void setRecipeIndex(int index) {
    if (index >= 0 && index < availableRecipes.length) {
      activeRecipeIndex = index;
      recipe = availableRecipes[index];
      progress = 0.0;
      statusMessage = 'Reçete Değiştirildi';
    }
  }

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
      availableRecipes: availableRecipes,
      activeRecipeIndex: activeRecipeIndex,
      purchaseCost: purchaseCost,
      baseUpgradeCost: baseUpgradeCost,
      level: level,
      progress: progress,
      isProducing: isProducing,
      statusMessage: statusMessage,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'blueprintId': blueprintId,
    'level': level,
    'progress': progress,
    'isProducing': isProducing,
    'activeRecipeIndex': activeRecipeIndex,
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
    final rIndex = (json['activeRecipeIndex'] as num?)?.toInt() ?? 0;
    fac.setRecipeIndex(rIndex);
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
        description: 'Çiğ süt sağımı yapar veya besicilikle ham deri üretir.',
        type: FacilityType.agriculture,
        recipe: const FacilityRecipe(
          name: 'Çiğ Süt Sağımı',
          inputs: {},
          outputItemId: 'milk',
          outputAmount: 6,
          durationSeconds: 7.5,
        ),
        availableRecipes: const [
          FacilityRecipe(
            name: 'Çiğ Süt Sağımı',
            inputs: {},
            outputItemId: 'milk',
            outputAmount: 6,
            durationSeconds: 7.5,
          ),
          FacilityRecipe(
            name: 'Ham Deri Hasadı',
            inputs: {},
            outputItemId: 'raw_leather',
            outputAmount: 4,
            durationSeconds: 8.0,
          ),
        ],
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
        name: 'Endüstriyel Fırın & Pastane',
        emoji: '🥖',
        description: 'Ekmek, tereyağlı kruvasan ve çikolatalı yaş pasta pişirir.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          name: 'Somun Ekmek Pişirme',
          inputs: {'flour': 1},
          outputItemId: 'bread',
          outputAmount: 2,
          durationSeconds: 4.5,
        ),
        availableRecipes: const [
          FacilityRecipe(
            name: 'Somun Ekmek Pişirme',
            inputs: {'flour': 1},
            outputItemId: 'bread',
            outputAmount: 2,
            durationSeconds: 4.5,
          ),
          FacilityRecipe(
            name: 'Tereyağlı Kruvasan',
            inputs: {'flour': 1, 'milk': 1},
            outputItemId: 'croissant',
            outputAmount: 2,
            durationSeconds: 5.5,
          ),
          FacilityRecipe(
            name: 'Çikolatalı Yaş Pasta',
            inputs: {'flour': 2, 'cocoa': 1},
            outputItemId: 'pastry_cake',
            outputAmount: 1,
            durationSeconds: 7.0,
          ),
        ],
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
        id: 'coffee_brewery',
        name: 'Kahve Demleme & İçecek Tesisi',
        emoji: '☕',
        description: 'Kavrulmuş kahveden filtre kahve ve kremalı sütlü latte hazırlar.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          name: 'Sıcak Filtre Kahve Demleme',
          inputs: {'roasted_coffee': 1},
          outputItemId: 'coffee_cup',
          outputAmount: 2,
          durationSeconds: 5.5,
        ),
        availableRecipes: const [
          FacilityRecipe(
            name: 'Sıcak Filtre Kahve Demleme',
            inputs: {'roasted_coffee': 1},
            outputItemId: 'coffee_cup',
            outputAmount: 2,
            durationSeconds: 5.5,
          ),
          FacilityRecipe(
            name: 'Kremalı Sütlü Cafe Latte',
            inputs: {'roasted_coffee': 1, 'milk': 1},
            outputItemId: 'coffee_latte',
            outputAmount: 2,
            durationSeconds: 6.0,
          ),
        ],
        purchaseCost: 55000.0,
        baseUpgradeCost: 27500.0,
      ),
      ProductionFacility(
        id: 'weaving_factory',
        name: 'Dokuma & İplik Fabrikası',
        emoji: '🧵',
        description: '2 adet Ham Pamuğu işleyip 1 rulo Dokuma Kumaş üretir.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          name: 'Dokuma Kumaş Üretimi',
          inputs: {'cotton': 2},
          outputItemId: 'fabric',
          outputAmount: 1,
          durationSeconds: 6.5,
        ),
        purchaseCost: 50000.0,
        baseUpgradeCost: 25000.0,
      ),
      ProductionFacility(
        id: 'leather_tannery',
        name: 'Deri İşleme & Tabakhane',
        emoji: '🧳',
        description: 'Ham deriyi kimyasallarla tabaklayıp 1 rulo lüks İşlenmiş Deri üretir.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          name: 'Deri Tabaklama',
          inputs: {'raw_leather': 1},
          outputItemId: 'processed_leather',
          outputAmount: 1,
          durationSeconds: 6.0,
        ),
        purchaseCost: 45000.0,
        baseUpgradeCost: 22500.0,
      ),
      ProductionFacility(
        id: 'cheese_factory',
        name: 'Süt Ürünleri & Mandıra Tesisi',
        emoji: '🧀',
        description: 'Sütü mayalayarak peynir, tereyağı ve süzme yoğurt üretir.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          name: 'Kalıp Peynir Mayalama',
          inputs: {'milk': 2},
          outputItemId: 'cheese',
          outputAmount: 1,
          durationSeconds: 5.5,
        ),
        availableRecipes: const [
          FacilityRecipe(
            name: 'Kalıp Peynir Mayalama',
            inputs: {'milk': 2},
            outputItemId: 'cheese',
            outputAmount: 1,
            durationSeconds: 5.5,
          ),
          FacilityRecipe(
            name: 'Köy Tereyağı Çalkalama',
            inputs: {'milk': 2},
            outputItemId: 'butter',
            outputAmount: 1,
            durationSeconds: 5.0,
          ),
          FacilityRecipe(
            name: 'Süzme Yoğurt Fermantasyonu',
            inputs: {'milk': 1},
            outputItemId: 'yogurt',
            outputAmount: 1,
            durationSeconds: 4.5,
          ),
        ],
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
          name: 'Kereste Biçme',
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
        name: 'Konfeksiyon & Terzi Fabrikası',
        emoji: '👗',
        description: 'Kumaş ve deriyi işleyerek tişört, kazak, hırka, deri ceket ve abiye elbiseler diker.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          name: 'Pamuklu Tişört Dikimi',
          inputs: {'fabric': 1},
          outputItemId: 'cotton_tshirt',
          outputAmount: 2,
          durationSeconds: 5.5,
        ),
        availableRecipes: const [
          FacilityRecipe(
            name: 'Pamuklu Tişört Dikimi',
            inputs: {'fabric': 1},
            outputItemId: 'cotton_tshirt',
            outputAmount: 2,
            durationSeconds: 5.5,
          ),
          FacilityRecipe(
            name: 'Triko Kazak Örme',
            inputs: {'fabric': 2},
            outputItemId: 'wool_sweater',
            outputAmount: 1,
            durationSeconds: 6.5,
          ),
          FacilityRecipe(
            name: 'Düğmeli Hırka Dikimi',
            inputs: {'fabric': 2},
            outputItemId: 'cardigan',
            outputAmount: 1,
            durationSeconds: 7.0,
          ),
          FacilityRecipe(
            name: 'Hakiki Deri Ceket Dikimi',
            inputs: {'processed_leather': 2},
            outputItemId: 'leather_jacket',
            outputAmount: 1,
            durationSeconds: 8.0,
          ),
          FacilityRecipe(
            name: 'Lüks Gece Elbisesi',
            inputs: {'fabric': 3},
            outputItemId: 'designer_dress',
            outputAmount: 1,
            durationSeconds: 8.5,
          ),
          FacilityRecipe(
            name: 'Hazır Giyim (Klasik)',
            inputs: {'fabric': 2},
            outputItemId: 'clothes',
            outputAmount: 1,
            durationSeconds: 7.0,
          ),
        ],
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
          name: 'Gurme Kutu Çikolata',
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
        description: 'Keresteyi işleyip sandalye, yemek masası ve masif gardırop üretir.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          name: 'Tasarım Ahşap Sandalye',
          inputs: {'plank': 2},
          outputItemId: 'furniture_chair',
          outputAmount: 1,
          durationSeconds: 8.0,
        ),
        availableRecipes: const [
          FacilityRecipe(
            name: 'Tasarım Ahşap Sandalye',
            inputs: {'plank': 2},
            outputItemId: 'furniture_chair',
            outputAmount: 1,
            durationSeconds: 8.0,
          ),
          FacilityRecipe(
            name: 'Masif Yemek Masası',
            inputs: {'plank': 4},
            outputItemId: 'furniture_table',
            outputAmount: 1,
            durationSeconds: 9.5,
          ),
          FacilityRecipe(
            name: 'Masif Elbise Dolabı',
            inputs: {'plank': 6},
            outputItemId: 'furniture_wardrobe',
            outputAmount: 1,
            durationSeconds: 11.0,
          ),
        ],
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
        description: 'Çelik ve plastiği mikroçiplerle birleştirip telefon, laptop ve akıllı saat üretir.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          name: 'Akıllı Telefon Montajı',
          inputs: {'steel_ingot': 1, 'plastic_pellet': 1},
          outputItemId: 'smartphone',
          outputAmount: 1,
          durationSeconds: 10.0,
        ),
        availableRecipes: const [
          FacilityRecipe(
            name: 'Akıllı Telefon Montajı',
            inputs: {'steel_ingot': 1, 'plastic_pellet': 1},
            outputItemId: 'smartphone',
            outputAmount: 1,
            durationSeconds: 10.0,
          ),
          FacilityRecipe(
            name: 'Dizüstü Bilgisayar (Laptop)',
            inputs: {'steel_ingot': 2, 'plastic_pellet': 2},
            outputItemId: 'laptop',
            outputAmount: 1,
            durationSeconds: 14.0,
          ),
          FacilityRecipe(
            name: 'Akıllı Kol Saati',
            inputs: {'steel_ingot': 1, 'plastic_pellet': 1},
            outputItemId: 'smartwatch',
            outputAmount: 2,
            durationSeconds: 8.0,
          ),
        ],
        purchaseCost: 240000.0,
        baseUpgradeCost: 120000.0,
      ),
    ];
  }
}
