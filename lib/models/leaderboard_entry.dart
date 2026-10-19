import 'player_level.dart';

enum LeaderboardPeriod {
  weekly,   // Haftanın En Çok Kazananı
  monthly,  // Ayın En Çok Kazananı
  allTime,  // Tüm Zamanlar
}

extension LeaderboardPeriodExtension on LeaderboardPeriod {
  String get title {
    switch (this) {
      case LeaderboardPeriod.weekly:
        return 'Haftanın En Çok Kazananı';
      case LeaderboardPeriod.monthly:
        return 'Ayın En Çok Kazananı';
      case LeaderboardPeriod.allTime:
        return 'Tüm Zamanlar';
    }
  }

  String get shortLabel {
    switch (this) {
      case LeaderboardPeriod.weekly:
        return 'Haftalık';
      case LeaderboardPeriod.monthly:
        return 'Aylık';
      case LeaderboardPeriod.allTime:
        return 'Tüm Zamanlar';
    }
  }

  String get icon {
    switch (this) {
      case LeaderboardPeriod.weekly:
        return '🗓️';
      case LeaderboardPeriod.monthly:
        return '📅';
      case LeaderboardPeriod.allTime:
        return '👑';
    }
  }

  String get badgeText {
    switch (this) {
      case LeaderboardPeriod.weekly:
        return 'Haftanın En Çok Kazananları';
      case LeaderboardPeriod.monthly:
        return 'Ayın En Çok Kazananları';
      case LeaderboardPeriod.allTime:
        return 'Tüm Zamanların Zirve Liderleri';
    }
  }
}

enum LeaderboardSortMode {
  netWorth,
  highestNetWorth,
  cash,
  properties,
}

extension LeaderboardSortModeExtension on LeaderboardSortMode {
  String get title {
    switch (this) {
      case LeaderboardSortMode.netWorth:
        return 'Mal Varlığı';
      case LeaderboardSortMode.highestNetWorth:
        return 'Zirve Servet';
      case LeaderboardSortMode.cash:
        return 'Nakti';
      case LeaderboardSortMode.properties:
        return 'Mülk Sayısı';
    }
  }

  String get shortLabel {
    switch (this) {
      case LeaderboardSortMode.netWorth:
        return 'Mal Varlığı';
      case LeaderboardSortMode.highestNetWorth:
        return 'Zirve Servet';
      case LeaderboardSortMode.cash:
        return 'Nakti';
      case LeaderboardSortMode.properties:
        return 'Mülk Sayısı';
    }
  }

  String get icon {
    switch (this) {
      case LeaderboardSortMode.netWorth:
        return '💰';
      case LeaderboardSortMode.highestNetWorth:
        return '👑';
      case LeaderboardSortMode.cash:
        return '💵';
      case LeaderboardSortMode.properties:
        return '🏭';
    }
  }
}

class LeaderboardEntry {
  final String uid;
  final String username;
  final String companyName;
  final double netWorth;
  final double highestNetWorth;
  final double cash;
  final double bankSavings;
  final int level;
  final String levelTitle;
  final String levelIcon;
  final int facilitiesCount;
  final int storesCount;
  final bool isOnline;
  final DateTime? lastActiveAt;
  final bool isBanned;
  final bool isCurrentUser;
  final bool isNpc;
  final int rank;

  // DÖNEMSEL KAZANÇLAR (Haftalık & Aylık)
  final double weeklyEarnings;
  final double monthlyEarnings;
  final double weeklyCashGain;
  final double monthlyCashGain;
  final int weeklyProperties;
  final int monthlyProperties;

  const LeaderboardEntry({
    required this.uid,
    required this.username,
    required this.companyName,
    required this.netWorth,
    required this.highestNetWorth,
    required this.cash,
    this.bankSavings = 0.0,
    required this.level,
    required this.levelTitle,
    required this.levelIcon,
    this.facilitiesCount = 0,
    this.storesCount = 0,
    this.isOnline = false,
    this.lastActiveAt,
    this.isBanned = false,
    this.isCurrentUser = false,
    this.isNpc = false,
    this.rank = 0,
    this.weeklyEarnings = 0.0,
    this.monthlyEarnings = 0.0,
    this.weeklyCashGain = 0.0,
    this.monthlyCashGain = 0.0,
    this.weeklyProperties = 0,
    this.monthlyProperties = 0,
  });

  LeaderboardEntry copyWithRank(int newRank) {
    return LeaderboardEntry(
      uid: uid,
      username: username,
      companyName: companyName,
      netWorth: netWorth,
      highestNetWorth: highestNetWorth,
      cash: cash,
      bankSavings: bankSavings,
      level: level,
      levelTitle: levelTitle,
      levelIcon: levelIcon,
      facilitiesCount: facilitiesCount,
      storesCount: storesCount,
      isOnline: isOnline,
      lastActiveAt: lastActiveAt,
      isBanned: isBanned,
      isCurrentUser: isCurrentUser,
      isNpc: isNpc,
      rank: newRank,
      weeklyEarnings: weeklyEarnings,
      monthlyEarnings: monthlyEarnings,
      weeklyCashGain: weeklyCashGain,
      monthlyCashGain: monthlyCashGain,
      weeklyProperties: weeklyProperties,
      monthlyProperties: monthlyProperties,
    );
  }

  double getSortValue(LeaderboardSortMode mode, [LeaderboardPeriod period = LeaderboardPeriod.allTime]) {
    switch (period) {
      case LeaderboardPeriod.allTime:
        switch (mode) {
          case LeaderboardSortMode.netWorth:
            return netWorth;
          case LeaderboardSortMode.highestNetWorth:
            return highestNetWorth;
          case LeaderboardSortMode.cash:
            return cash;
          case LeaderboardSortMode.properties:
            return (facilitiesCount + storesCount).toDouble();
        }
      case LeaderboardPeriod.weekly:
        switch (mode) {
          case LeaderboardSortMode.netWorth:
            return weeklyEarnings > 0 ? weeklyEarnings : (netWorth * 0.18).roundToDouble();
          case LeaderboardSortMode.highestNetWorth:
            return weeklyEarnings > 0 ? weeklyEarnings : (netWorth * 0.18).roundToDouble();
          case LeaderboardSortMode.cash:
            return weeklyCashGain > 0 ? weeklyCashGain : (cash * 0.22).roundToDouble();
          case LeaderboardSortMode.properties:
            return (weeklyProperties > 0 ? weeklyProperties : (facilitiesCount + storesCount)).toDouble();
        }
      case LeaderboardPeriod.monthly:
        switch (mode) {
          case LeaderboardSortMode.netWorth:
            return monthlyEarnings > 0 ? monthlyEarnings : (netWorth * 0.55).roundToDouble();
          case LeaderboardSortMode.highestNetWorth:
            return monthlyEarnings > 0 ? monthlyEarnings : (netWorth * 0.55).roundToDouble();
          case LeaderboardSortMode.cash:
            return monthlyCashGain > 0 ? monthlyCashGain : (cash * 0.60).roundToDouble();
          case LeaderboardSortMode.properties:
            return (monthlyProperties > 0 ? monthlyProperties : (facilitiesCount + storesCount)).toDouble();
        }
    }
  }

  factory LeaderboardEntry.fromMap(Map<String, dynamic> data, {String? currentUid}) {
    final uid = data['uid'] as String? ?? '';
    final username = data['username'] as String? ?? 'Bilinmeyen Oyuncu';
    final companyName = data['companyName'] as String? ?? '$username Holding';
    final cash = (data['cash'] as num?)?.toDouble() ?? 10000.0;
    final bankSavings = (data['bankSavings'] as num?)?.toDouble() ?? 0.0;

    double netWorth = 0.0;
    if (data.containsKey('netWorth') && data['netWorth'] != null) {
      netWorth = (data['netWorth'] as num).toDouble();
    } else {
      netWorth = cash + bankSavings;
    }

    double highest = netWorth;
    if (data.containsKey('highestNetWorth') && data['highestNetWorth'] != null) {
      highest = (data['highestNetWorth'] as num).toDouble();
    }

    int level = (data['level'] as num?)?.toInt() ??
        (data['playerLevel'] as num?)?.toInt() ??
        1;
    final levelInfo = PlayerLevelInfo.getInfoForLevel(level);

    int facilities = 0;
    if (data.containsKey('totalFacilitiesCount')) {
      facilities = (data['totalFacilitiesCount'] as num).toInt();
    } else if (data.containsKey('ownedFacilities') && data['ownedFacilities'] is List) {
      facilities = (data['ownedFacilities'] as List).length;
    } else if (data.containsKey('facilitiesCount')) {
      facilities = (data['facilitiesCount'] as num).toInt();
    }

    int stores = 0;
    if (data.containsKey('totalStoresCount')) {
      stores = (data['totalStoresCount'] as num).toInt();
    } else if (data.containsKey('ownedStores') && data['ownedStores'] is List) {
      stores = (data['ownedStores'] as List).length;
    } else if (data.containsKey('storesCount')) {
      stores = (data['storesCount'] as num).toInt();
    }

    DateTime? lastActive;
    if (data['lastActiveAt'] != null) {
      if (data['lastActiveAt'] is String) {
        lastActive = DateTime.tryParse(data['lastActiveAt'] as String);
      }
    }

    final weeklyEarnings = (data['weeklyEarnings'] as num?)?.toDouble() ??
        ((data['weeklyNetWorthGain'] as num?)?.toDouble() ?? (netWorth * 0.18).roundToDouble());
    final monthlyEarnings = (data['monthlyEarnings'] as num?)?.toDouble() ??
        ((data['monthlyNetWorthGain'] as num?)?.toDouble() ?? (netWorth * 0.55).roundToDouble());
    final weeklyCashGain = (data['weeklyCashGain'] as num?)?.toDouble() ?? (cash * 0.22).roundToDouble();
    final monthlyCashGain = (data['monthlyCashGain'] as num?)?.toDouble() ?? (cash * 0.60).roundToDouble();
    final weeklyProperties = (data['weeklyProperties'] as num?)?.toInt() ?? (facilities + stores);
    final monthlyProperties = (data['monthlyProperties'] as num?)?.toInt() ?? (facilities + stores);

    return LeaderboardEntry(
      uid: uid,
      username: username,
      companyName: companyName,
      netWorth: netWorth,
      highestNetWorth: highest > netWorth ? highest : netWorth,
      cash: cash,
      bankSavings: bankSavings,
      level: level,
      levelTitle: data['playerTitle'] as String? ?? levelInfo.title,
      levelIcon: levelInfo.icon,
      facilitiesCount: facilities,
      storesCount: stores,
      isOnline: data['isOnline'] == true,
      lastActiveAt: lastActive,
      isBanned: data['isBanned'] == true,
      isCurrentUser: currentUid != null && currentUid.isNotEmpty && uid == currentUid,
      isNpc: data['isNpc'] == true,
      rank: 0,
      weeklyEarnings: weeklyEarnings,
      monthlyEarnings: monthlyEarnings,
      weeklyCashGain: weeklyCashGain,
      monthlyCashGain: monthlyCashGain,
      weeklyProperties: weeklyProperties,
      monthlyProperties: monthlyProperties,
    );
  }

  static List<LeaderboardEntry> getBenchmarkRivals() {
    return const [
      LeaderboardEntry(
        uid: 'npc_kocer_sanayi',
        username: 'kocer_holding',
        companyName: 'Koçer Sanayi & Yatırım A.Ş.',
        netWorth: 8500000.0,
        highestNetWorth: 9200000.0,
        cash: 1850000.0,
        level: 10,
        levelTitle: 'Ticaret İmparatoru',
        levelIcon: '🏆',
        facilitiesCount: 14,
        storesCount: 18,
        isOnline: true,
        isNpc: true,
      ),
      LeaderboardEntry(
        uid: 'npc_anadolu_lojistik',
        username: 'anadolu_gida',
        companyName: 'Anadolu Mega Holding',
        netWorth: 4350000.0,
        highestNetWorth: 4350000.0,
        cash: 920000.0,
        level: 9,
        levelTitle: 'Piyasa Baronu',
        levelIcon: '👑',
        facilitiesCount: 9,
        storesCount: 12,
        isOnline: false,
        isNpc: true,
      ),
      LeaderboardEntry(
        uid: 'npc_ege_ciftlikleri',
        username: 'ege_tarim',
        companyName: 'Ege Tarım & Fabrikalar Birliği',
        netWorth: 1850000.0,
        highestNetWorth: 2100000.0,
        cash: 450000.0,
        level: 8,
        levelTitle: 'Finans Devi',
        levelIcon: '💎',
        facilitiesCount: 6,
        storesCount: 7,
        isOnline: true,
        isNpc: true,
      ),
      LeaderboardEntry(
        uid: 'npc_bogazici_ticaret',
        username: 'bogazici_ltd',
        companyName: 'Boğaziçi Uluslararası Ticaret',
        netWorth: 750000.0,
        highestNetWorth: 750000.0,
        cash: 195000.0,
        level: 6,
        levelTitle: 'İş İnsanı',
        levelIcon: '👔',
        facilitiesCount: 4,
        storesCount: 4,
        isOnline: false,
        isNpc: true,
      ),
      LeaderboardEntry(
        uid: 'npc_akdeniz_perakende',
        username: 'akdeniz_store',
        companyName: 'Akdeniz Perakende Zinciri',
        netWorth: 280000.0,
        highestNetWorth: 310000.0,
        cash: 72000.0,
        level: 5,
        levelTitle: 'Sanayici',
        levelIcon: '🏭',
        facilitiesCount: 2,
        storesCount: 3,
        isOnline: true,
        isNpc: true,
      ),
      LeaderboardEntry(
        uid: 'npc_marmara_depo',
        username: 'marmara_lojistik',
        companyName: 'Marmara Dağıtım & Antrepo',
        netWorth: 85000.0,
        highestNetWorth: 85000.0,
        cash: 28000.0,
        level: 3,
        levelTitle: 'Tüccar',
        levelIcon: '⚖️',
        facilitiesCount: 1,
        storesCount: 1,
        isOnline: false,
        isNpc: true,
      ),
    ];
  }
}
