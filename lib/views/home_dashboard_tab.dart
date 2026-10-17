import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import '../services/firebase_service.dart';
import '../services/leaderboard_service.dart';
import '../models/leaderboard_entry.dart';

class HomeDashboardTab extends StatelessWidget {
  final GameController controller;
  final ValueChanged<int> onNavigateToTab;
  final VoidCallback onOpenBorsa;
  final VoidCallback onOpenPazar;
  final VoidCallback onOpenLeaderboard;
  final VoidCallback onOpenBank;
  final VoidCallback onOpenLedger;
  final VoidCallback onOpenAdmin;

  const HomeDashboardTab({
    super.key,
    required this.controller,
    required this.onNavigateToTab,
    required this.onOpenBorsa,
    required this.onOpenPazar,
    required this.onOpenLeaderboard,
    required this.onOpenBank,
    required this.onOpenLedger,
    required this.onOpenAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final currencyFmt = NumberFormat('#,##0', 'tr_TR');
        final fb = FirebaseService();
        final username = fb.username ?? (fb.isGuest ? 'Misafir Oyuncu' : 'COSSKUN');
        final companyName = fb.companyName;
        final isAdmin = fb.isAdmin || username.trim().toUpperCase() == FirebaseService.adminUsername.toUpperCase();

        final warehouseWeight = controller.currentWarehouseWeight;
        final warehouseCap = controller.maxWarehouseCapacity;
        final warehouseRatio = warehouseCap > 0 ? (warehouseWeight / warehouseCap).clamp(0.0, 1.0) : 0.0;
        final warehousePercent = (warehouseRatio * 100).toInt();
        final warehouseFreeSpace = (warehouseCap - warehouseWeight).clamp(0.0, double.infinity);

        Color warehouseBarColor;
        if (warehouseRatio >= 0.85) {
          warehouseBarColor = Colors.redAccent;
        } else if (warehouseRatio >= 0.65) {
          warehouseBarColor = Colors.amber;
        } else {
          warehouseBarColor = const Color(0xFF10B981);
        }

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ==========================================
          // 1. LOGOMUZ & ŞİRKET BİLGİ MERKEZİ (HERO BANNER)
          // ==========================================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFF0F766E), const Color(0xFF115E59)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black45 : const Color(0xFF0F766E).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.tealAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo, Piyasa Başlığı ve Canlı Göstergesi
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                      ),
                      child: const Text('💰', style: TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Text(
                                  'PİYASA',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    color: isDark ? Colors.amberAccent : Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
                                      SizedBox(width: 3),
                                      Text(
                                        'CANLI',
                                        style: TextStyle(
                                          color: Color(0xFF10B981),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isAdmin) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: const Text(
                                      'YÖNETİCİ',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$companyName • $username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.teal.shade100,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Liderlik Sıralaması Canlı Teaser Bandı
                StreamBuilder<List<LeaderboardEntry>>(
                  stream: LeaderboardService().streamLeaderboard(controller: controller),
                  builder: (context, snapshot) {
                    int? myRank;
                    if (snapshot.hasData && snapshot.data != null) {
                      final list = snapshot.data!;
                      final me = list.where((e) => e.isCurrentUser).firstOrNull;
                      if (me != null) {
                        myRank = me.rank;
                      }
                    }

                    return InkWell(
                      onTap: onOpenLeaderboard,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0B132B).withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text('🏆', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                myRank != null
                                    ? 'Liderlik Tablosunda Sıranız: #$myRank'
                                    : 'Liderlik Sıralamanızı Görün',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Tabloyu Aç ›',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ==========================================
          // 2. KASADAKİ NAKİT & NET SERVET KARTLARI
          // ==========================================
          Row(
            children: [
              // Kasadaki Nakit Kartı
              Expanded(
                child: InkWell(
                  onTap: onOpenLedger,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0D1829) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.greenAccent.withValues(alpha: 0.4)
                            : const Color(0xFF10B981).withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: isDark ? 0.08 : 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 15,
                              color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'Kasadaki Nakit',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey.shade400 : const Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${currencyFmt.format(controller.cash)} ₺',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.greenAccent : const Color(0xFF065F46),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Net Servet Kartı
              Expanded(
                child: InkWell(
                  onTap: onOpenLeaderboard,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F1B12) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.amber.withValues(alpha: 0.5)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: isDark ? 0.08 : 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.trending_up_rounded,
                              size: 15,
                              color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'Net Servet',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey.shade400 : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${currencyFmt.format(controller.netWorth)} ₺',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.amberAccent : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ==========================================
          // 3. SİLO & DEPO DOLULUK MİKTARI KARTI (ÖZEL)
          // ==========================================
          InkWell(
            onTap: () => onNavigateToTab(2),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF131D2D)]
                      : [Colors.white, const Color(0xFFF8FAFC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: warehouseBarColor.withValues(alpha: isDark ? 0.4 : 0.5),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: warehouseBarColor.withValues(alpha: isDark ? 0.08 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: warehouseBarColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('🌾', style: TextStyle(fontSize: 16)),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Merkezi Silo & Depo Doluluğu',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    '${warehouseFreeSpace.toInt()} kg boş alan kaldı',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: warehouseBarColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: warehouseBarColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          '%$warehousePercent Dolu',
                          style: TextStyle(
                            color: warehouseBarColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Doluluk İlerleme Çubuğu (Progress Bar)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: warehouseRatio,
                      minHeight: 8,
                      backgroundColor: isDark ? Colors.black45 : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(warehouseBarColor),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${warehouseWeight.toInt()} / ${warehouseCap.toInt()} kg',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Depoya Git',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.amberAccent : const Color(0xFF0F766E),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: isDark ? Colors.amberAccent : const Color(0xFF0F766E),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ==========================================
          // 4. BANKA BUTONU & COSSKUN ADMIN BUTONU
          // ==========================================
          Row(
            children: [
              // Banka Butonu
              Expanded(
                flex: isAdmin ? 5 : 1,
                child: ElevatedButton.icon(
                  onPressed: onOpenBank,
                  icon: const Icon(Icons.account_balance_rounded, size: 17),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Banka & Kredi (${currencyFmt.format(controller.bankSavings)} ₺)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              ),

              // Cosskun Hesabı İçin Yönetici Paneli Butonu
              if (isAdmin) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: onOpenAdmin,
                    icon: const Icon(Icons.security_rounded, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Admin Paneli',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 18),

          // ==========================================
          // 5. ANA İŞLEM MERKEZLERİ (HIZLI ERİŞİM HUB GRID)
          // ==========================================
          Row(
            children: [
              Icon(
                Icons.grid_view_rounded,
                size: 18,
                color: isDark ? Colors.amberAccent : const Color(0xFF0F766E),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hızlı İşlem Merkezleri',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2 Kolonlu Modern Hub Kartları Grid'i
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 10) / 2;

              final hubItems = <_HubItemData>[
                _HubItemData(
                  title: 'Liderlik Tablosu',
                  subtitle: 'Zirvedeki şirketler',
                  badgeText: '🏆 Sıralama',
                  icon: Icons.emoji_events_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  bgGradient: [
                    const Color(0xFFF59E0B).withValues(alpha: 0.18),
                    const Color(0xFFD97706).withValues(alpha: 0.08),
                  ],
                  borderColor: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  onTap: onOpenLeaderboard,
                ),
                _HubItemData(
                  title: 'Tesislerim',
                  subtitle: '${controller.ownedFacilities.length} Tesis devrede',
                  badgeText: 'Üretim',
                  icon: Icons.agriculture_rounded,
                  iconColor: const Color(0xFF10B981),
                  bgGradient: [
                    const Color(0xFF10B981).withValues(alpha: 0.18),
                    const Color(0xFF059669).withValues(alpha: 0.08),
                  ],
                  borderColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                  onTap: () => onNavigateToTab(1),
                ),
                _HubItemData(
                  title: 'Depom',
                  subtitle: '${warehouseWeight.toInt()} / ${warehouseCap.toInt()} kg',
                  badgeText: '%$warehousePercent Dolu',
                  icon: Icons.inventory_2_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  bgGradient: [
                    const Color(0xFF3B82F6).withValues(alpha: 0.18),
                    const Color(0xFF1D4ED8).withValues(alpha: 0.08),
                  ],
                  borderColor: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                  onTap: () => onNavigateToTab(2),
                ),
                _HubItemData(
                  title: 'Canlı Borsa',
                  subtitle: 'Emtia & toptan al-sat',
                  badgeText: 'Canlı Fiyat',
                  icon: Icons.candlestick_chart_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  bgGradient: [
                    const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                    const Color(0xFF6D28D9).withValues(alpha: 0.08),
                  ],
                  borderColor: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                  onTap: onOpenBorsa,
                ),
                _HubItemData(
                  title: 'Oyuncu Pazarı',
                  subtitle: '${controller.communityListings.length} Açık ilan',
                  badgeText: 'Küresel Pazar',
                  icon: Icons.store_mall_directory_rounded,
                  iconColor: const Color(0xFFF97316),
                  bgGradient: [
                    const Color(0xFFF97316).withValues(alpha: 0.18),
                    const Color(0xFFEA580C).withValues(alpha: 0.08),
                  ],
                  borderColor: const Color(0xFFF97316).withValues(alpha: 0.4),
                  onTap: onOpenPazar,
                ),
                _HubItemData(
                  title: 'Dükkanlarım',
                  subtitle: '${controller.ownedStores.length} Şube faaliyette',
                  badgeText: 'Perakende',
                  icon: Icons.storefront_rounded,
                  iconColor: const Color(0xFFEC4899),
                  bgGradient: [
                    const Color(0xFFEC4899).withValues(alpha: 0.18),
                    const Color(0xFFBE185D).withValues(alpha: 0.08),
                  ],
                  borderColor: const Color(0xFFEC4899).withValues(alpha: 0.4),
                  onTap: () => onNavigateToTab(4),
                ),
                _HubItemData(
                  title: 'Banka & Kredi',
                  subtitle: '${currencyFmt.format(controller.bankSavings)} ₺ mevduat',
                  badgeText: 'Finans',
                  icon: Icons.account_balance_rounded,
                  iconColor: const Color(0xFF06B6D4),
                  bgGradient: [
                    const Color(0xFF06B6D4).withValues(alpha: 0.18),
                    const Color(0xFF0891B2).withValues(alpha: 0.08),
                  ],
                  borderColor: const Color(0xFF06B6D4).withValues(alpha: 0.4),
                  onTap: onOpenBank,
                ),
                _HubItemData(
                  title: 'Şirket Defteri',
                  subtitle: 'Gelir-gider & denetim',
                  badgeText: 'Raporlar',
                  icon: Icons.history_edu_rounded,
                  iconColor: const Color(0xFF14B8A6),
                  bgGradient: [
                    const Color(0xFF14B8A6).withValues(alpha: 0.18),
                    const Color(0xFF0F766E).withValues(alpha: 0.08),
                  ],
                  borderColor: const Color(0xFF14B8A6).withValues(alpha: 0.4),
                  onTap: onOpenLedger,
                ),
                if (isAdmin)
                  _HubItemData(
                    title: 'Yönetici Paneli',
                    subtitle: 'Oyuncu kontrolü & ban',
                    badgeText: 'Admin',
                    icon: Icons.security_rounded,
                    iconColor: const Color(0xFFEF4444),
                    bgGradient: [
                      const Color(0xFFEF4444).withValues(alpha: 0.22),
                      const Color(0xFFB91C1C).withValues(alpha: 0.1),
                    ],
                    borderColor: const Color(0xFFEF4444).withValues(alpha: 0.5),
                    onTap: onOpenAdmin,
                  ),
              ];

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: hubItems.map((item) {
                  return SizedBox(
                    width: itemWidth,
                    child: _buildHubCard(item, isDark: isDark),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 20),

          // ==========================================
          // 6. CANLI ŞİRKET İSTATİSTİKLERİ
          // ==========================================
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.analytics_outlined, size: 18, color: Colors.blueAccent),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Şirket Durumu & İstatistikler',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 7, color: Colors.greenAccent),
                          SizedBox(width: 4),
                          Text(
                            'Faal',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        label: 'Üretim Tesisleri',
                        value: '${controller.ownedFacilities.length} Adet',
                        icon: Icons.factory_rounded,
                        color: Colors.greenAccent,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatItem(
                        label: 'Perakende Şubeler',
                        value: '${controller.ownedStores.length} Adet',
                        icon: Icons.store_rounded,
                        color: Colors.pinkAccent,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        label: 'Depo Ağırlığı',
                        value: '${warehouseWeight.toInt()} kg',
                        icon: Icons.inventory_2_outlined,
                        color: Colors.blueAccent,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatItem(
                        label: 'Banka Birikimi',
                        value: '${currencyFmt.format(controller.bankSavings)} ₺',
                        icon: Icons.savings_outlined,
                        color: Colors.amberAccent,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
      },
    );
  }

  Widget _buildHubCard(_HubItemData item, {required bool isDark}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      const Color(0xFF1E293B),
                      const Color(0xFF151E2E),
                    ]
                  : [
                      Colors.white,
                      const Color(0xFFF8FAFC),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.borderColor.withValues(alpha: isDark ? 0.35 : 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: item.iconColor.withValues(alpha: isDark ? 0.08 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: item.iconColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, color: item.iconColor, size: 21),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: item.iconColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.badgeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: item.iconColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HubItemData {
  final String title;
  final String subtitle;
  final String badgeText;
  final IconData icon;
  final Color iconColor;
  final List<Color> bgGradient;
  final Color borderColor;
  final VoidCallback onTap;

  const _HubItemData({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.icon,
    required this.iconColor,
    required this.bgGradient,
    required this.borderColor,
    required this.onTap,
  });
}
