class HeadquartersLevel {
  final int level;
  final String name;
  final String emoji;
  final double upgradeCost;
  final String description;
  final String perks;
  final double retailSpeedBoostPercent;
  final int dailyQuotaBonus;
  final double opexDiscountPercent;

  const HeadquartersLevel({
    required this.level,
    required this.name,
    required this.emoji,
    required this.upgradeCost,
    required this.description,
    required this.perks,
    this.retailSpeedBoostPercent = 0.0,
    this.dailyQuotaBonus = 0,
    this.opexDiscountPercent = 0.0,
  });
}

class HeadquartersConfig {
  static const List<HeadquartersLevel> levels = [
    HeadquartersLevel(
      level: 0,
      name: 'Genel Merkez Arazisi',
      emoji: '🏗️',
      upgradeCost: 500000.0,
      description: 'Henüz genel merkez inşa edilmedi. Şirketinizi kurumsallaştırmak için ilk adımı atın.',
      perks: 'Kurumsal prestij kazanmak için İrtibat Ofisi inşa edin.',
    ),
    HeadquartersLevel(
      level: 1,
      name: 'İrtibat Ofisi & İdare Binası',
      emoji: '🏢',
      upgradeCost: 2500000.0,
      description: 'Şehrin iş merkezinde 3 katlı idari merkez. Resmi sözleşmeler ve şirket temsili burada yapılır.',
      perks: '✨ Şirket Rozeti + %3 Perakende Satış Hızı Artışı',
      retailSpeedBoostPercent: 0.03,
    ),
    HeadquartersLevel(
      level: 2,
      name: 'Prestij Plaza & Yönetim Kulesi',
      emoji: '🏢',
      upgradeCost: 7500000.0,
      description: '10 katlı modern cam plaza. Departmanlar arası koordinasyon ve piyasa istihbaratı sağlar.',
      perks: '📊 Günlük Borsa Kotası +300 Adet + %6 Perakende Satış Hızı',
      retailSpeedBoostPercent: 0.06,
      dailyQuotaBonus: 300,
    ),
    HeadquartersLevel(
      level: 3,
      name: 'Çift Kuleli Ticaret Kampüsü',
      emoji: '🏙️',
      upgradeCost: 20000000.0,
      description: 'İkiz kuleler, konferans salonları ve araştırma merkezi. Şirket verimliliğini zirveye taşır.',
      perks: '📉 İşletme Giderlerinde %15 Tasarruf + %10 Perakende Satış Hızı + 600 Kota Bonusu',
      retailSpeedBoostPercent: 0.10,
      dailyQuotaBonus: 600,
      opexDiscountPercent: 0.15,
    ),
    HeadquartersLevel(
      level: 4,
      name: 'Megapol Ticaret Merkezi (30 Katlı Gökdelen)',
      emoji: '🌆',
      upgradeCost: 50000000.0,
      description: 'Şehrin siluetinde parlayan 30 katlı mega gökdelen. Finans dünyasında mutlak ağırlık kazandırır.',
      perks: '🌟 Liderlikte Altın Gökdelen İkonu + İhalelerde %25 Ekstra Kâr + 1.200 Kota Bonusu',
      retailSpeedBoostPercent: 0.15,
      dailyQuotaBonus: 1200,
      opexDiscountPercent: 0.20,
    ),
    HeadquartersLevel(
      level: 5,
      name: 'Apex Piyasa Dünya Genel Merkezi (Gökdelen & Helipad)',
      emoji: '👑',
      upgradeCost: 0.0,
      description: 'Helikopter pisti, gökyüzü bahçeleri ve küresel borsa izleme kulesiyle dünya çapında anıt eser.',
      perks: '👑 "Piyasa Baronu/Baronesi" Unvanı + %25 Satış Hızı + Sınırsız Borsa Kotası + %25 Gider Tasarrufu',
      retailSpeedBoostPercent: 0.25,
      dailyQuotaBonus: 99999,
      opexDiscountPercent: 0.25,
    ),
  ];

  static HeadquartersLevel getLevel(int level) {
    if (level <= 0) return levels[0];
    if (level >= levels.length) return levels.last;
    return levels[level];
  }
}
