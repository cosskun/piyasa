/// Şirket Lojistik & Araç Filosu Kademeleri
class LogisticsFleetTier {
  final int tier;
  final String id;
  final String name;
  final String emoji;
  final String description;
  final double shippingCostPerItem; // Depodan dükkana parça başı nakliye bedeli
  final double restockSpeedSeconds;  // Raf ikmal / intikal süresi katsayısı
  final double purchaseCost;         // Filoyu bu kademeye yükseltme ücreti

  const LogisticsFleetTier({
    required this.tier,
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.shippingCostPerItem,
    required this.restockSpeedSeconds,
    required this.purchaseCost,
  });

  static const List<LogisticsFleetTier> tiers = [
    LogisticsFleetTier(
      tier: 1,
      id: 'tier_1_van',
      name: 'Kiralık Kamyonet & Hamal',
      emoji: '🛻',
      description: 'Dış kaynaklı kiralık nakliye. Yüksek birim maliyet ve yavaş ikmal.',
      shippingCostPerItem: 0.30,
      restockSpeedSeconds: 8.0,
      purchaseCost: 0.0,
    ),
    LogisticsFleetTier(
      tier: 2,
      id: 'tier_2_panelvan',
      name: 'Şirket Panelvanı',
      emoji: '🚐',
      description: 'Küçük ticari araç filosu. Maliyeti yarıya düşürür, sevkiyatı hızlandırır.',
      shippingCostPerItem: 0.15,
      restockSpeedSeconds: 4.0,
      purchaseCost: 15000.0,
    ),
    LogisticsFleetTier(
      tier: 3,
      id: 'tier_3_truck',
      name: 'Ağır Taşımacılık Kamyonu',
      emoji: '🚛',
      description: 'Büyük tonajlı nakliye kamyonları. Sembolik nakliye maliyeti.',
      shippingCostPerItem: 0.05,
      restockSpeedSeconds: 2.0,
      purchaseCost: 60000.0,
    ),
    LogisticsFleetTier(
      tier: 4,
      id: 'tier_4_tir',
      name: 'Entegre Tır Filosu & Lojistik Üssü',
      emoji: '🚚💨',
      description: 'Holding lojistik filosu. Sıfır navlun masrafı ve ışık hızında tam otomatik sevkiyat.',
      shippingCostPerItem: 0.00,
      restockSpeedSeconds: 0.5,
      purchaseCost: 200000.0,
    ),
  ];

  static LogisticsFleetTier getTier(int tier) {
    final clamped = tier.clamp(1, tiers.length);
    return tiers[clamped - 1];
  }
}
