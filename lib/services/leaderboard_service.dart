import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/leaderboard_entry.dart';
import '../controllers/game_controller.dart';
import 'firebase_service.dart';

class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();

  /// Sistemdeki tüm oyuncuları dinler, yerel controller verisi ve benchmark rakipleriyle harmanlayarak
  /// seçilen sıralama kriterine göre sıralanmış listeyi bir Stream olarak döndürür.
  Stream<List<LeaderboardEntry>> streamLeaderboard({
    required GameController controller,
    LeaderboardSortMode sortMode = LeaderboardSortMode.netWorth,
  }) {
    final fb = FirebaseService();
    final currentUid = fb.playerId;
    final currentUsername = fb.username ?? 'COSSKUN';
    final currentCompany = fb.companyName;

    return fb.streamAllPlayers().map((rawPlayers) {
      final Map<String, LeaderboardEntry> entryMap = {};

      // 1. Gerçek oyuncuları işle
      for (final raw in rawPlayers) {
        final entry = LeaderboardEntry.fromMap(raw, currentUid: currentUid);
        if (entry.uid.isNotEmpty) {
          entryMap[entry.uid] = entry;
        }
      }

      // 2. Aktif oturumdaki oyuncunun anlık güncel verisini controller'dan ez (canlı gerçek zamanlı yansıma)
      final liveCurrentUserEntry = LeaderboardEntry(
        uid: currentUid,
        username: currentUsername,
        companyName: currentCompany,
        netWorth: controller.netWorth,
        highestNetWorth: controller.highestNetWorth,
        cash: controller.cash,
        bankSavings: controller.bankSavings,
        level: controller.playerLevel,
        levelTitle: controller.playerTitle,
        levelIcon: controller.playerLevelInfo.icon,
        facilitiesCount: controller.ownedFacilities.length,
        storesCount: controller.ownedStores.length,
        isOnline: true,
        lastActiveAt: DateTime.now(),
        isBanned: fb.isBanned,
        isCurrentUser: true,
        isNpc: false,
      );
      entryMap[currentUid] = liveCurrentUserEntry;

      // 3. Eğer oyuncu sayısı azsa (örneğin offline yerel mod veya başlangıç sunucusu),
      // oyuncuya rekabet hedefi sunmak adına kıyaslama şirketlerini (benchmark rivals) ekle
      final List<LeaderboardEntry> list = entryMap.values.toList();
      if (list.length < 6) {
        for (final rival in LeaderboardEntry.getBenchmarkRivals()) {
          if (!entryMap.containsKey(rival.uid)) {
            list.add(rival);
          }
        }
      }

      // 4. Kriter bazında azalan sıralama (En yüksek değer en üstte)
      list.sort((a, b) {
        final valA = a.getSortValue(sortMode);
        final valB = b.getSortValue(sortMode);
        final cmp = valB.compareTo(valA);
        if (cmp != 0) return cmp;
        return a.username.compareTo(b.username);
      });

      // 5. Sıralama numaralarını (1, 2, 3...) atama
      final List<LeaderboardEntry> rankedList = [];
      for (int i = 0; i < list.length; i++) {
        rankedList.add(list[i].copyWithRank(i + 1));
      }

      return rankedList;
    }).asBroadcastStream();
  }

  /// Mevcut kullanıcının sıralamadaki bir üstündeki oyuncuya yetişmesi için gereken farkı ve üst oyuncuyu döner
  ({LeaderboardEntry? aheadPlayer, double difference}) getNextRankTarget({
    required List<LeaderboardEntry> rankedList,
    required LeaderboardSortMode sortMode,
  }) {
    final myIndex = rankedList.indexWhere((e) => e.isCurrentUser);
    if (myIndex <= 0) {
      // Ya bulunamadı ya da zaten 1. sırada (zirvede)
      return (aheadPlayer: null, difference: 0.0);
    }

    final ahead = rankedList[myIndex - 1];
    final me = rankedList[myIndex];
    final diff = ahead.getSortValue(sortMode) - me.getSortValue(sortMode);
    return (aheadPlayer: ahead, difference: diff > 0 ? diff : 0.0);
  }
}
