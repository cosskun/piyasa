enum ItemCategory {
  rawMaterial,  // Tarım, Madencilik ve Doğal Hammaddeler
  intermediate, // Fabrika Ara Mamulleri ve Sanayi Bileşenleri
  finishedGood, // Perakende Tüketici Ürünleri ve Nihai Mallar
}

extension ItemCategoryExtension on ItemCategory {
  String get nameTr {
    switch (this) {
      case ItemCategory.rawMaterial:
        return 'Hammadde';
      case ItemCategory.intermediate:
        return 'Ara Mamul';
      case ItemCategory.finishedGood:
        return 'Nihai Ürün';
    }
  }
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
    // ==========================================
    // 1. HAMMADDELER (TARIM, MADEN, ORMAN & ENERJİ)
    // ==========================================
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
    'potato': ItemData(
      id: 'potato',
      name: 'Taze Patates',
      emoji: '🥔',
      description: 'Bereketli topraktan sökülen patatesler. Fast food ve gıda sanayisinin vazgeçilmezi.',
      category: ItemCategory.rawMaterial,
      basePrice: 10.0,
      minPrice: 6.0,
      maxPrice: 18.0,
      retailSuggestedPrice: 13.0,
      weight: 1.0,
    ),
    'fruit': ItemData(
      id: 'fruit',
      name: 'Taze Meyve',
      emoji: '🍊',
      description: 'Bahçelerden toplanan narenciye ve meyveler. İçecek ve gıda dolumu için.',
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
      description: 'Mandıralardan sağılan taze inek sütü. Peynir, çikolata ve kahve için.',
      category: ItemCategory.rawMaterial,
      basePrice: 15.0,
      minPrice: 10.0,
      maxPrice: 25.0,
      retailSuggestedPrice: 19.0,
      weight: 1.0,
    ),
    'cotton': ItemData(
      id: 'cotton',
      name: 'Ham Pamuk',
      emoji: '🧶',
      description: 'Tekstilin temeli. Tarlalardan toplanıp dokuma fabrikalarına gider.',
      category: ItemCategory.rawMaterial,
      basePrice: 18.0,
      minPrice: 12.0,
      maxPrice: 30.0,
      retailSuggestedPrice: 22.0,
      weight: 0.8,
    ),
    'wood_log': ItemData(
      id: 'wood_log',
      name: 'Ham Tomruk',
      emoji: '🪵',
      description: 'Orman kamplarından kesilen masif tomruklar. Kereste ve mobilya sanayisine gider.',
      category: ItemCategory.rawMaterial,
      basePrice: 28.0,
      minPrice: 18.0,
      maxPrice: 48.0,
      retailSuggestedPrice: 36.0,
      weight: 1.5,
    ),
    'coffee_bean': ItemData(
      id: 'coffee_bean',
      name: 'Kahve Çekirdeği',
      emoji: '🫘',
      description: 'Plantasyonlardan toplanan aromatik çiğ kahve çekirdeği.',
      category: ItemCategory.rawMaterial,
      basePrice: 35.0,
      minPrice: 20.0,
      maxPrice: 55.0,
      retailSuggestedPrice: 42.0,
      weight: 0.5,
    ),
    'cocoa': ItemData(
      id: 'cocoa',
      name: 'Kakao Çekirdeği',
      emoji: '🍫',
      description: 'Tropikal plantasyonlardan toplanan aromatik kakao. Çikolata fabrikalarının temeli.',
      category: ItemCategory.rawMaterial,
      basePrice: 42.0,
      minPrice: 26.0,
      maxPrice: 70.0,
      retailSuggestedPrice: 52.0,
      weight: 0.5,
    ),
    'iron_ore': ItemData(
      id: 'iron_ore',
      name: 'Demir Cevheri',
      emoji: '⛏️',
      description: 'Derin yeraltı ocaklarından çıkarılan ham demir. Çelik dökümhanelerinin yakıtı.',
      category: ItemCategory.rawMaterial,
      basePrice: 50.0,
      minPrice: 32.0,
      maxPrice: 85.0,
      retailSuggestedPrice: 65.0,
      weight: 2.0,
    ),
    'crude_oil': ItemData(
      id: 'crude_oil',
      name: 'Ham Petrol Varili',
      emoji: '🛢️',
      description: 'Sondaj kulelerinden çıkarılan siyah altın. Petrokimya ve plastik sanayisi için.',
      category: ItemCategory.rawMaterial,
      basePrice: 70.0,
      minPrice: 45.0,
      maxPrice: 120.0,
      retailSuggestedPrice: 90.0,
      weight: 1.8,
    ),

    // ==========================================
    // 2. FABRİKA ARA MAMULLERİ (İŞLENMİŞ SANAYİ ÜRÜNLERİ)
    // ==========================================
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
      description: 'Pamuktan dokunan kumaş rulosu. Konfeksiyon atölyelerine gider.',
      category: ItemCategory.intermediate,
      basePrice: 52.0,
      minPrice: 35.0,
      maxPrice: 80.0,
      retailSuggestedPrice: 65.0,
      weight: 0.6,
    ),
    'roasted_coffee': ItemData(
      id: 'roasted_coffee',
      name: 'Kavrulmuş Kahve',
      emoji: '☕',
      description: 'Fırınlanıp öğütülmüş taze kahve. Kafe ve kahve dükkanlarının ana ihtiyacı.',
      category: ItemCategory.intermediate,
      basePrice: 65.0,
      minPrice: 45.0,
      maxPrice: 98.0,
      retailSuggestedPrice: 80.0,
      weight: 0.5,
    ),
    'plank': ItemData(
      id: 'plank',
      name: 'İşlenmiş Kereste',
      emoji: '🪚',
      description: 'Hızarda biçilmiş düzgün marangozluk tahtası. Mobilya atölyeleri için.',
      category: ItemCategory.intermediate,
      basePrice: 75.0,
      minPrice: 50.0,
      maxPrice: 125.0,
      retailSuggestedPrice: 95.0,
      weight: 1.2,
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
      retailSuggestedPrice: 110.0,
      weight: 1.0,
    ),
    'plastic_pellet': ItemData(
      id: 'plastic_pellet',
      name: 'Sanayi Plastiği',
      emoji: '🧪',
      description: 'Petrokimyadan üretilen polimer granül. Cihaz kasaları ve parçaları için.',
      category: ItemCategory.intermediate,
      basePrice: 115.0,
      minPrice: 75.0,
      maxPrice: 185.0,
      retailSuggestedPrice: 145.0,
      weight: 0.8,
    ),
    'steel_ingot': ItemData(
      id: 'steel_ingot',
      name: 'Çelik Külçe',
      emoji: '⚙️',
      description: 'Yüksek fırında saflaştırılmış sağlam çelik. İnşaat ve elektronik için.',
      category: ItemCategory.intermediate,
      basePrice: 140.0,
      minPrice: 95.0,
      maxPrice: 220.0,
      retailSuggestedPrice: 175.0,
      weight: 2.5,
    ),

    // ==========================================
    // 3. PERAKENDE NİHAİ TÜKETİCİ ÜRÜNLERİ
    // ==========================================
    'bread': ItemData(
      id: 'bread',
      name: 'Somun Ekmek',
      emoji: '🥖',
      description: 'Fırında unla pişen taze ekmek. Büfe ve marketlerin en hızlı satılan ürünü.',
      category: ItemCategory.finishedGood,
      basePrice: 12.0,
      minPrice: 8.0,
      maxPrice: 18.0,
      retailSuggestedPrice: 18.0,
      weight: 0.3,
    ),
    'french_fries': ItemData(
      id: 'french_fries',
      name: 'Çıtır Patates Külahı',
      emoji: '🍟',
      description: 'Altın sarısı çıtır patates külahı. Fast food mekanlarının vazgeçilmezi.',
      category: ItemCategory.finishedGood,
      basePrice: 30.0,
      minPrice: 20.0,
      maxPrice: 48.0,
      retailSuggestedPrice: 42.0,
      weight: 0.3,
    ),
    'juice': ItemData(
      id: 'juice',
      name: 'Şişe Meyve Suyu',
      emoji: '🧃',
      description: 'Vitamin barlarının ve marketlerin taze sıkılmış serinletici içeceği.',
      category: ItemCategory.finishedGood,
      basePrice: 32.0,
      minPrice: 20.0,
      maxPrice: 50.0,
      retailSuggestedPrice: 48.0,
      weight: 0.5,
    ),
    'coffee_cup': ItemData(
      id: 'coffee_cup',
      name: 'Sıcak Filtre Kahve',
      emoji: '☕',
      description: 'Kafelerde müşterilere servis edilen taze demlenmiş aromatik kahve.',
      category: ItemCategory.finishedGood,
      basePrice: 45.0,
      minPrice: 30.0,
      maxPrice: 75.0,
      retailSuggestedPrice: 65.0,
      weight: 0.2,
    ),
    'gourmet_chocolate': ItemData(
      id: 'gourmet_chocolate',
      name: 'Gurme Kutu Çikolata',
      emoji: '🎁',
      description: 'Süt ve kaliteli kakaodan üretilen lüks hediyelik kutu çikolata.',
      category: ItemCategory.finishedGood,
      basePrice: 150.0,
      minPrice: 100.0,
      maxPrice: 240.0,
      retailSuggestedPrice: 210.0,
      weight: 0.4,
    ),
    'clothes': ItemData(
      id: 'clothes',
      name: 'Hazır Giyim',
      emoji: '👕',
      description: 'Kumaşın dikilmesiyle üretilen şık ve kaliteli kıyafetler.',
      category: ItemCategory.finishedGood,
      basePrice: 185.0,
      minPrice: 125.0,
      maxPrice: 300.0,
      retailSuggestedPrice: 260.0,
      weight: 0.5,
    ),
    'furniture_chair': ItemData(
      id: 'furniture_chair',
      name: 'Tasarım Ahşap Sandalye',
      emoji: '🪑',
      description: 'Doğal keresteden üretilmiş dayanıklı ve şık salon sandalyesi.',
      category: ItemCategory.finishedGood,
      basePrice: 230.0,
      minPrice: 155.0,
      maxPrice: 360.0,
      retailSuggestedPrice: 320.0,
      weight: 2.0,
    ),
    'smartphone': ItemData(
      id: 'smartphone',
      name: 'Akıllı Telefon',
      emoji: '📱',
      description: 'Çelik ve yüksek teknoloji plastikten üretilmiş yeni nesil akıllı telefon.',
      category: ItemCategory.finishedGood,
      basePrice: 480.0,
      minPrice: 320.0,
      maxPrice: 760.0,
      retailSuggestedPrice: 680.0,
      weight: 0.3,
    ),
  };

  static ItemData? get(String id) => items[id];
  static List<ItemData> getAll() => items.values.toList();
}
