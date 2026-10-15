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
}

class ProductionFacility {
  final String id;
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
  });

  double get upgradeCost => baseUpgradeCost * pow(1.5, level - 1);
  double get effectiveDuration => max(2.0, recipe.durationSeconds * (1.0 - (level - 1) * 0.08));
  int get effectiveOutput => level <= 2 ? recipe.outputAmount : (recipe.outputAmount * (1.0 + (level - 2) * 0.25)).round();

  ProductionFacility copy({String? newId}) {
    return ProductionFacility(
      id: newId ?? '${id}_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      emoji: emoji,
      description: description,
      type: type,
      recipe: recipe,
      purchaseCost: purchaseCost,
      baseUpgradeCost: baseUpgradeCost,
    );
  }

  static List<ProductionFacility> getBlueprints() {
    return [
      // 1. Tarım & Hammadde (Tarlalar & Çiftlikler)
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
        purchaseCost: 7500.0,
        baseUpgradeCost: 4000.0,
      ),
      ProductionFacility(
        id: 'cotton_field',
        name: 'Pamuk Arazisi',
        emoji: '🧶',
        description: 'Tekstil sanayisi için ham pamuk toplar.',
        type: FacilityType.agriculture,
        recipe: const FacilityRecipe(
          inputs: {},
          outputItemId: 'cotton',
          outputAmount: 6,
          durationSeconds: 8.0,
        ),
        purchaseCost: 16000.0,
        baseUpgradeCost: 8000.0,
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
        purchaseCost: 14000.0,
        baseUpgradeCost: 7000.0,
      ),
      ProductionFacility(
        id: 'dairy_farm',
        name: 'Mandıra Çiftliği',
        emoji: '🐄',
        description: 'Sağmal inek çiftliği. Peynir ve kahve üretimi için çiğ süt sağlar.',
        type: FacilityType.agriculture,
        recipe: const FacilityRecipe(
          inputs: {},
          outputItemId: 'milk',
          outputAmount: 6,
          durationSeconds: 7.5,
        ),
        purchaseCost: 22000.0,
        baseUpgradeCost: 11000.0,
      ),

      // 2. Sanayi & Fabrikalar (Hammaddeyi dönüştürür)
      ProductionFacility(
        id: 'flour_mill',
        name: 'Un Değirmeni',
        emoji: '⚙️',
        description: '2 çuval Buğdayı işleyip 1 çuval kaliteli Un üretir.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          inputs: {'wheat': 2},
          outputItemId: 'flour',
          outputAmount: 1,
          durationSeconds: 5.0,
        ),
        purchaseCost: 32000.0,
        baseUpgradeCost: 16000.0,
      ),
      ProductionFacility(
        id: 'weaving_factory',
        name: 'Dokuma & İplik Fabrikası',
        emoji: '🏭',
        description: '2 adet Ham Pamuğu işleyip 1 rulo Kumaş dokur.',
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
        description: '3 litre Çiğ Sütü mayalayıp 1 kalıp sofralık Peynir yapar.',
        type: FacilityType.factory,
        recipe: const FacilityRecipe(
          inputs: {'milk': 3},
          outputItemId: 'cheese',
          outputAmount: 1,
          durationSeconds: 7.0,
        ),
        purchaseCost: 60000.0,
        baseUpgradeCost: 30000.0,
      ),
    ];
  }
}
