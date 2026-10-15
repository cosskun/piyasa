import 'dart:math';

class PlayerLevelInfo {
  final int level;
  final String title;
  final double minNetWorth;
  final String perkDescription;
  final String icon;

  const PlayerLevelInfo({
    required this.level,
    required this.title,
    required this.minNetWorth,
    required this.perkDescription,
    this.icon = '⭐',
  });

  static const List<PlayerLevelInfo> tiers = [
    PlayerLevelInfo(
      level: 1,
      title: 'Yeni Girişimci',
      minNetWorth: 0.0,
      perkDescription: 'Ticaret dünyasına ilk adım. Pazar ve hammadde alım-satımı.',
      icon: '🌱',
    ),
    PlayerLevelInfo(
      level: 2,
      title: 'Esnaf',
      minNetWorth: 25000.0,
      perkDescription: 'Yerel ticarette güven kazandınız. Küçük ölçekli üretim.',
      icon: '🏪',
    ),
    PlayerLevelInfo(
      level: 3,
      title: 'Tüccar',
      minNetWorth: 50000.0,
      perkDescription: 'Piyasa dalgalanmalarını avantaja çeviren aktif tüccar.',
      icon: '⚖️',
    ),
    PlayerLevelInfo(
      level: 4,
      title: 'KOBİ Sahibi',
      minNetWorth: 100000.0,
      perkDescription: 'Genişleyen işletmeler ve organize mağaza zincirleri.',
      icon: '💼',
    ),
    PlayerLevelInfo(
      level: 5,
      title: 'Sanayici',
      minNetWorth: 200000.0,
      perkDescription: '🔓 Banka Kredisi Açıldı! Yüksek hacimli fabrika yatırımları.',
      icon: '🏭',
    ),
    PlayerLevelInfo(
      level: 6,
      title: 'İş İnsanı',
      minNetWorth: 400000.0,
      perkDescription: 'Genişletilmiş kredi limiti (+%100). Çoklu üretim hatları.',
      icon: '👔',
    ),
    PlayerLevelInfo(
      level: 7,
      title: 'Holding Sahibi',
      minNetWorth: 800000.0,
      perkDescription: 'Katlanan kredi limiti. Sektörler arası sermaye gücü.',
      icon: '🏢',
    ),
    PlayerLevelInfo(
      level: 8,
      title: 'Finans Devi',
      minNetWorth: 1600000.0,
      perkDescription: 'Milyonluk sermaye ve yüksek banka kredisi olanakları.',
      icon: '💎',
    ),
    PlayerLevelInfo(
      level: 9,
      title: 'Piyasa Baronu',
      minNetWorth: 3200000.0,
      perkDescription: 'Piyasa arz ve talebini yönlendiren devasa sermaye.',
      icon: '👑',
    ),
    PlayerLevelInfo(
      level: 10,
      title: 'Ticaret İmparatoru',
      minNetWorth: 6400000.0,
      perkDescription: 'Zirvedesiniz! En üst düzey banka kredi limitleri ve piyasa hakimiyeti.',
      icon: '🏆',
    ),
  ];

  static PlayerLevelInfo getInfoForLevel(int level) {
    if (level <= 0) return tiers.first;
    if (level <= tiers.length) return tiers[level - 1];
    return PlayerLevelInfo(
      level: level,
      title: 'Global Kartel (Sv. $level)',
      minNetWorth: tiers.last.minNetWorth * pow(1.5, level - tiers.length),
      perkDescription: 'Sınırsız sermaye ve global pazar liderliği.',
      icon: '👑',
    );
  }
}
