enum ItemCategory {
  rawMaterial,  // Tarım / Çiftlik Hammaddeleri
  intermediate, // Fabrika Ara Mamulleri
  finishedGood, // Perakende Tüketici Ürünleri
}

class ItemData {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final ItemCategory category;
  final double basePrice;
  final double minPrice;
  final double maxPrice;
  final double retailSuggestedPrice;
  final double weight; // kg

  const ItemData({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.category,
    required this.basePrice,
    required this.minPrice,
    required this.maxPrice,
    required this.retailSuggestedPrice,
    this.weight = 1.0,
  });
}

class ItemRegistry {
  static const Map<String, ItemData> items = {
    // 1. Tarım ve Hammadde
    'wheat': ItemData(
      id: 'wheat',
      name: 'Buğday',
      emoji: '🌾',
      description: 'Ekmek ve unun ana hammaddesi. Tarlalardan hasat edilir.',
      category: ItemCategory.rawMaterial,
      basePrice: 8.0,
      minPrice: 5.0,
      maxPrice: 15.0,
      retailSuggestedPrice: 10.0,
      weight: 1.0,
    ),
    'cotton': ItemData(
      id: 'cotton',
      name: 'Ham Pamuk',
      emoji: '🧶',
      description: 'Tekstilin temeli. Tarlalardan toplanıp dokuma fabrikasına gider.',
      category: ItemCategory.rawMaterial,
      basePrice: 18.0,
      minPrice: 12.0,
      maxPrice: 30.0,
      retailSuggestedPrice: 22.0,
      weight: 0.8,
    ),
    'fruit': ItemData(
      id: 'fruit',
      name: 'Taze Meyve',
      emoji: '🍊',
      description: 'Bahçelerden toplanan taze meyveler. Meyve suyu dolumu için.',
      category: ItemCategory.rawMaterial,
      basePrice: 12.0,
      minPrice: 7.0,
      maxPrice: 22.0,
      retailSuggestedPrice: 16.0,
      weight: 1.0,
    ),
    'milk': ItemData(
      id: 'milk',
      name: 'Çiğ Süt',
      emoji: '🥛',
      description: 'Mandıralardan sağılan taze inek sütü. Peynir ve kahve için.',
      category: ItemCategory.rawMaterial,
      basePrice: 15.0,
      minPrice: 10.0,
      maxPrice: 25.0,
      retailSuggestedPrice: 19.0,
      weight: 1.0,
    ),
    'coffee_bean': ItemData(
      id: 'coffee_bean',
      name: 'Kahve Çekirdeği',
      emoji: '☕',
      description: 'Plantasyonlardan toplanan aromatik çiğ kahve çekirdeği.',
      category: ItemCategory.rawMaterial,
      basePrice: 35.0,
      minPrice: 20.0,
      maxPrice: 55.0,
      retailSuggestedPrice: 42.0,
      weight: 0.5,
    ),

    // 2. Fabrika Ara Mamulleri
    'flour': ItemData(
      id: 'flour',
      name: 'Un (Çuval)',
      emoji: '🥣',
      description: 'Değirmende öğütülmüş kaliteli un. Fırınların ana ihtiyacı.',
      category: ItemCategory.intermediate,
      basePrice: 22.0,
      minPrice: 15.0,
      maxPrice: 38.0,
      retailSuggestedPrice: 28.0,
      weight: 1.0,
    ),
    'fabric': ItemData(
      id: 'fabric',
      name: 'Dokunmuş Kumaş',
      emoji: '🧵',
      description: 'Pamuktan dokunan kumaş. Tekstil atölyelerine gider.',
      category: ItemCategory.intermediate,
      basePrice: 52.0,
      minPrice: 35.0,
      maxPrice: 80.0,
      retailSuggestedPrice: 65.0,
      weight: 0.6,
    ),
    'cheese': ItemData(
      id: 'cheese',
      name: 'Kalıp Peynir',
      emoji: '🧀',
      description: 'Sütün mayalanmasıyla üretilen sofralık nefis peynir.',
      category: ItemCategory.intermediate,
      basePrice: 85.0,
      minPrice: 60.0,
      maxPrice: 135.0,
      retailSuggestedPrice: 105.0,
      weight: 1.0,
    ),

    // 3. Perakende Nihai Mamuller
    'bread': ItemData(
      id: 'bread',
      name: 'Somun Ekmek',
      emoji: '🥖',
      description: 'Fırında unla pişen ekmek. Büfelerin en hızlı satılan ürünü.',
      category: ItemCategory.finishedGood,
      basePrice: 10.0,
      minPrice: 8.0,
      maxPrice: 16.0,
      retailSuggestedPrice: 15.0,
      weight: 0.3,
    ),
    'clothes': ItemData(
      id: 'clothes',
      name: 'Hazır Giyim',
      emoji: '👕',
      description: 'Kumaşın dikilmesiyle üretilen şık kıyafetler.',
      category: ItemCategory.finishedGood,
      basePrice: 180.0,
      minPrice: 120.0,
      maxPrice: 290.0,
      retailSuggestedPrice: 250.0,
      weight: 0.5,
    ),
    'juice': ItemData(
      id: 'juice',
      name: 'Şişe Meyve Suyu',
      emoji: '🧃',
      description: 'Vitamin barlarının ve marketlerin vazgeçilmez içeceği.',
      category: ItemCategory.finishedGood,
      basePrice: 30.0,
      minPrice: 20.0,
      maxPrice: 48.0,
      retailSuggestedPrice: 45.0,
      weight: 0.5,
    ),
    'coffee_cup': ItemData(
      id: 'coffee_cup',
      name: 'Taze Sıcak Kahve',
      emoji: '☕',
      description: 'Kafelerde müşterilere servis edilen taze demlenmiş kahve.',
      category: ItemCategory.finishedGood,
      basePrice: 40.0,
      minPrice: 28.0,
      maxPrice: 68.0,
      retailSuggestedPrice: 60.0,
      weight: 0.2,
    ),
  };

  static ItemData? get(String id) => items[id];
  static List<ItemData> getAll() => items.values.toList();
}
