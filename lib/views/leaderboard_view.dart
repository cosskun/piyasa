import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import '../models/leaderboard_entry.dart';
import '../services/firebase_service.dart';
import '../services/leaderboard_service.dart';

class LeaderboardView extends StatefulWidget {
  final GameController controller;

  const LeaderboardView({super.key, required this.controller});

  static Future<void> show(BuildContext context, {required GameController controller}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LeaderboardView(controller: controller),
    );
  }

  @override
  State<LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends State<LeaderboardView> {
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'tr_TR');
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy HH:mm');
  final TextEditingController _searchController = TextEditingController();

  LeaderboardSortMode _sortMode = LeaderboardSortMode.netWorth;
  String _searchQuery = '';
  late Stream<List<LeaderboardEntry>> _leaderboardStream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    _leaderboardStream = LeaderboardService().streamLeaderboard(
      controller: widget.controller,
      sortMode: _sortMode,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _changeSortMode(LeaderboardSortMode mode) {
    if (_sortMode == mode) return;
    setState(() {
      _sortMode = mode;
      _initStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fb = FirebaseService();
    final isCloud = fb.isCloudConnected;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: StreamBuilder<List<LeaderboardEntry>>(
        stream: _leaderboardStream,
        builder: (context, snapshot) {
          final allEntries = snapshot.data ?? [];
          final filteredEntries = allEntries.where((e) {
            if (_searchQuery.isEmpty) return true;
            final q = _searchQuery.toLowerCase();
            return e.companyName.toLowerCase().contains(q) ||
                e.username.toLowerCase().contains(q);
          }).toList();

          final currentUserTarget = LeaderboardService().getNextRankTarget(
            rankedList: allEntries,
            sortMode: _sortMode,
          );

          LeaderboardEntry? currentUserEntry;
          try {
            currentUserEntry = allEntries.firstWhere((e) => e.isCurrentUser);
          } catch (_) {
            currentUserEntry = null;
          }

          return Column(
            children: [
              // Üst Sürükleme Çizgisi
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Başlık ve Canlılık Rozeti
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PİYASA LİDERLİK TABLOSU',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCloud ? const Color(0xFF10B981) : Colors.amber,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  isCloud ? 'Bulut Canlı Sıralama 🌐' : 'Yerel Cihaz & Kıyaslama Sıralaması 📱',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isCloud
                                        ? (isDark ? Colors.greenAccent : const Color(0xFF059669))
                                        : (isDark ? Colors.amberAccent : const Color(0xFFD97706)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Kapat',
                    ),
                  ],
                ),
              ),

              // Sıralama Kriteri Seçim Sekmeleri (Tabs)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  children: LeaderboardSortMode.values.map((mode) {
                    final isSelected = _sortMode == mode;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        showCheckmark: false,
                        avatar: Text(mode.icon, style: const TextStyle(fontSize: 14)),
                        label: Text(mode.shortLabel),
                        selected: isSelected,
                        onSelected: (_) => _changeSortMode(mode),
                        selectedColor: isDark ? const Color(0xFFD97706) : const Color(0xFFF59E0B),
                        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.amber
                                : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Arama Kutusu
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Şirket adı veya oyuncu ara...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                ),
              ),

              const SizedBox(height: 6),

              // Ana Sıralama Listesi & Podyum
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting && allEntries.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                    : filteredEntries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_search_rounded,
                                    size: 48,
                                    color: isDark ? Colors.white30 : const Color(0xFF94A3B8)),
                                const SizedBox(height: 10),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Aramanıza uygun şirket bulunamadı.'
                                      : 'Sıralama verisi yükleniyor...',
                                  style: TextStyle(
                                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: Colors.amber,
                            onRefresh: () async {
                              setState(() {
                                _initStream();
                              });
                            },
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 90),
                              itemCount: (_searchQuery.isEmpty && filteredEntries.length >= 3)
                                  ? filteredEntries.length + 1 // Podyum için +1
                                  : filteredEntries.length,
                              itemBuilder: (context, index) {
                                // Arama yoksa ve en az 3 şirket varsa en üstte Podyum (Podium) göster
                                if (_searchQuery.isEmpty && filteredEntries.length >= 3) {
                                  if (index == 0) {
                                    return _buildTop3Podium(
                                      top3: filteredEntries.take(3).toList(),
                                      isDark: isDark,
                                    );
                                  }
                                  final entry = filteredEntries[index - 1];
                                  return _buildPlayerRankCard(entry, isDark: isDark);
                                }

                                final entry = filteredEntries[index];
                                return _buildPlayerRankCard(entry, isDark: isDark);
                              },
                            ),
                          ),
              ),

              // Sabit Alt Bilgi Çubuğu: "Sizin Konumunuz & Hedef Fark"
              if (currentUserEntry != null)
                _buildStickyCurrentUserBar(
                  userEntry: currentUserEntry,
                  targetInfo: currentUserTarget,
                  isDark: isDark,
                ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // TOP 3 PODYUM (1., 2., 3. SIRADAKİLER)
  // ==========================================
  Widget _buildTop3Podium({
    required List<LeaderboardEntry> top3,
    required bool isDark,
  }) {
    if (top3.length < 3) return const SizedBox.shrink();

    final first = top3[0];
    final second = top3[1];
    final third = top3[2];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFFEF3C7).withValues(alpha: 0.5), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.amber.withValues(alpha: 0.25) : const Color(0xFFFDE68A),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('✨', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                'TİCARETİN ZİRVE LİDERLERİ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                ),
              ),
              const SizedBox(width: 4),
              const Text('✨', style: TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 2. Sıra (Gümüş / Sol)
              Expanded(
                child: _buildPodiumColumn(
                  entry: second,
                  rank: 2,
                  medalEmoji: '🥈',
                  color: const Color(0xFF94A3B8),
                  heightMultiplier: 0.85,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),

              // 1. Sıra (Altın / Orta - Daha yüksek)
              Expanded(
                child: _buildPodiumColumn(
                  entry: first,
                  rank: 1,
                  medalEmoji: '🥇',
                  color: const Color(0xFFF59E0B),
                  heightMultiplier: 1.0,
                  isDark: isDark,
                  isFirst: true,
                ),
              ),
              const SizedBox(width: 8),

              // 3. Sıra (Bronz / Sağ)
              Expanded(
                child: _buildPodiumColumn(
                  entry: third,
                  rank: 3,
                  medalEmoji: '🥉',
                  color: const Color(0xFFD97706),
                  heightMultiplier: 0.75,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn({
    required LeaderboardEntry entry,
    required int rank,
    required String medalEmoji,
    required Color color,
    required double heightMultiplier,
    required bool isDark,
    bool isFirst = false,
  }) {
    final sortVal = entry.getSortValue(_sortMode);

    return InkWell(
      onTap: () => _showPlayerPortfolioSheet(context, entry),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Taç veya Madalya Rozeti
          if (isFirst)
            const Text('👑', style: TextStyle(fontSize: 20))
          else
            Text(medalEmoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),

          // Avatar Dairesi
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: isFirst ? 54 : 44,
                height: isFirst ? 54 : 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.8), color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: isFirst ? Colors.amberAccent : Colors.white,
                    width: isFirst ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: isFirst ? 10 : 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    entry.companyName.isNotEmpty ? entry.companyName[0].toUpperCase() : 'P',
                    style: TextStyle(
                      fontSize: isFirst ? 20 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (entry.isOnline)
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Şirket Adı
          Text(
            entry.companyName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isFirst ? 12 : 11,
              fontWeight: FontWeight.bold,
              color: entry.isCurrentUser
                  ? (isDark ? Colors.amberAccent : const Color(0xFFD97706))
                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),

          // Sıralama Değeri
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatMetricValue(sortVal, _sortMode),
              style: TextStyle(
                fontSize: isFirst ? 12.5 : 11,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.greenAccent : const Color(0xFF059669),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Podyum Basamağı
          Container(
            height: 38 * heightMultiplier,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: isDark ? 0.35 : 0.25),
                  color.withValues(alpha: isDark ? 0.2 : 0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: isFirst ? 16 : 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // OYUNCU SIRALAMA KARTI (LİSTE ELEMANI)
  // ==========================================
  Widget _buildPlayerRankCard(LeaderboardEntry entry, {required bool isDark}) {
    final sortVal = entry.getSortValue(_sortMode);
    final isMe = entry.isCurrentUser;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isMe
            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF3C7))
            : (isDark ? const Color(0xFF161F30) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? (isDark ? Colors.amberAccent : const Color(0xFFF59E0B))
              : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0)),
          width: isMe ? 1.8 : 1.0,
        ),
        boxShadow: [
          if (isMe)
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showPlayerPortfolioSheet(context, entry),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Sıra Rozeti (#1, #2, #3 için madalya veya şık numara kutusu)
                Container(
                  width: 44,
                  alignment: Alignment.center,
                  child: _buildRankBadge(entry.rank),
                ),
                const SizedBox(width: 10),

                // Avatar ve Online Göstergesi
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isMe
                          ? const Color(0xFFF59E0B)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      child: Text(
                        entry.companyName.isNotEmpty ? entry.companyName[0].toUpperCase() : 'P',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isMe
                              ? Colors.white
                              : (isDark ? Colors.white70 : const Color(0xFF334155)),
                        ),
                      ),
                    ),
                    if (entry.isOnline)
                      Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF161F30) : Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // Şirket Adı & Oyuncu Bilgileri
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.companyName,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'SİZ',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '@${entry.username}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '•',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(entry.levelIcon, style: const TextStyle(fontSize: 9.5)),
                                const SizedBox(width: 3),
                                Text(
                                  'Sv. ${entry.level}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Sağ Taraf Metrik Değeri (Net Servet, Nakit vb.)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatMetricValue(sortVal, _sortMode),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                      ),
                    ),
                    if (_sortMode == LeaderboardSortMode.netWorth)
                      Text(
                        'Kasa: ~${_currencyFormat.format(entry.cash)} ₺',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                        ),
                      )
                    else if (_sortMode == LeaderboardSortMode.properties)
                      Text(
                        '${entry.facilitiesCount} Tesis • ${entry.storesCount} Dükkan',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                        ),
                      )
                    else
                      Text(
                        'Net: ~${_currencyFormat.format(entry.netWorth)} ₺',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) {
      return const Text('🥇', style: TextStyle(fontSize: 22));
    } else if (rank == 2) {
      return const Text('🥈', style: TextStyle(fontSize: 20));
    } else if (rank == 3) {
      return const Text('🥉', style: TextStyle(fontSize: 18));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF334155).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '#$rank',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ==========================================
  // SABİT ALT ÇUBUK: OYUNCUNUN KENDİ KONUMU
  // ==========================================
  Widget _buildStickyCurrentUserBar({
    required LeaderboardEntry userEntry,
    required ({LeaderboardEntry? aheadPlayer, double difference}) targetInfo,
    required bool isDark,
  }) {
    final ahead = targetInfo.aheadPlayer;
    final diff = targetInfo.difference;
    final isTop1 = userEntry.rank == 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Sıra Rozeti
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '#${userEntry.rank}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Şirketiniz ve Hedef Bilgisi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Şirketiniz: ${userEntry.companyName}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${_formatMetricValue(userEntry.getSortValue(_sortMode), _sortMode)})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (isTop1)
                    Text(
                      '👑 Tebrikler! Piyasanın Zirvesindesiniz!',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                      ),
                    )
                  else if (ahead != null)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '🚀 Sonraki Sıra: ${ahead.companyName} için +${_currencyFormat.format(diff)} ₺ gerekiyor',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Profil İncele Butonu
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, size: 22),
              color: Colors.amber,
              tooltip: 'Portföy Detayı',
              onPressed: () => _showPlayerPortfolioSheet(context, userEntry),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // OYUNCU PORTFÖYÜ VE ŞİRKET DETAY SHEETİ
  // ==========================================
  void _showPlayerPortfolioSheet(BuildContext context, LeaderboardEntry entry) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Şirket Başlığı
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF3C7),
                      child: Text(
                        entry.companyName.isNotEmpty ? entry.companyName[0].toUpperCase() : 'P',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.companyName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '@${entry.username} • ${entry.isNpc ? "Piyasa Kıyaslama Şirketi" : (entry.isOnline ? "🟢 Çevrimiçi" : "⚪ Çevrimdışı")}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber, width: 1.2),
                      ),
                      child: Text(
                        'Sıra #${entry.rank}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Seviye ve Ünvan
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(entry.levelIcon, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seviye ${entry.level} • ${entry.levelTitle}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Toplam net servet büyüklüğü sıralamasında ${entry.rank}. konumda.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Varlık Dağılımı Kartları
                Row(
                  children: [
                    Expanded(
                      child: _buildPortfolioItem(
                        title: 'Net Mal Varlığı',
                        value: '${_currencyFormat.format(entry.netWorth)} ₺',
                        icon: Icons.trending_up_rounded,
                        color: Colors.amber,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildPortfolioItem(
                        title: 'Zirve Servet',
                        value: '${_currencyFormat.format(entry.highestNetWorth)} ₺',
                        icon: Icons.military_tech_rounded,
                        color: Colors.purpleAccent,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildPortfolioItem(
                        title: 'Kasadaki Nakit',
                        value: '${_currencyFormat.format(entry.cash)} ₺',
                        icon: Icons.account_balance_wallet_outlined,
                        color: Colors.greenAccent,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildPortfolioItem(
                        title: 'Banka Mevduatı',
                        value: '${_currencyFormat.format(entry.bankSavings)} ₺',
                        icon: Icons.account_balance_rounded,
                        color: Colors.blueAccent,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildPortfolioItem(
                        title: 'Tesis Sayısı',
                        value: '${entry.facilitiesCount} Fabrika / Tarla',
                        icon: Icons.agriculture_rounded,
                        color: Colors.tealAccent,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildPortfolioItem(
                        title: 'Dükkan Sayısı',
                        value: '${entry.storesCount} Mağaza / Kiosk',
                        icon: Icons.storefront_rounded,
                        color: Colors.orangeAccent,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),

                if (entry.lastActiveAt != null) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Son Aktiflik: ${_dateFormat.format(entry.lastActiveAt!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPortfolioItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMetricValue(double val, LeaderboardSortMode mode) {
    if (mode == LeaderboardSortMode.properties) {
      return '${val.toInt()} Mülk';
    }
    return '${_currencyFormat.format(val)} ₺';
  }
}
