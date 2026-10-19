import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import '../models/market_item.dart';
import '../services/firebase_service.dart';

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
        final isAdmin = fb.isAdmin ||
            (fb.username ?? '').trim().toUpperCase() == FirebaseService.adminUsername.toUpperCase();

        final warehouseWeight = controller.currentWarehouseWeight;
        final warehouseCap = controller.maxWarehouseCapacity;
        final warehouseRatio = warehouseCap > 0 ? (warehouseWeight / warehouseCap).clamp(0.0, 1.0) : 0.0;
        final warehousePercent = (warehouseRatio * 100).toInt();
        final warehouseFreeSpace = (warehouseCap - warehouseWeight).clamp(0.0, double.infinity);

        final bool isWarehouseFull = warehouseRatio >= 1.0;
        final bool isWarehouseNearFull = warehouseRatio >= 0.85 && !isWarehouseFull;
        final int pendingOffers = controller.pendingIncomingOffersCount;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==========================================
              // 1. AKILLI BİLDİRİM & AKSİYON KARTI
              // ==========================================
              _buildSmartActionCard(
                context: context,
                isDark: isDark,
                isWarehouseFull: isWarehouseFull,
                isWarehouseNearFull: isWarehouseNearFull,
                pendingOffers: pendingOffers,
                warehousePercent: warehousePercent,
                warehouseFreeSpace: warehouseFreeSpace,
              ),

              const SizedBox(height: 14),

              // ==========================================
              // 2. FİNANS & ŞİRKET YÖNETİMİ (BANKA & DEFTER)
              // ==========================================
              _buildFinanceSection(
                context: context,
                isDark: isDark,
                currencyFmt: currencyFmt,
              ),

              const SizedBox(height: 14),

              // ==========================================
              // 3. ŞİRKET NABZI (CANLI TEMEL GÖSTERGELER)
              // ==========================================
              _buildCompanyPulseSection(
                context: context,
                isDark: isDark,
                currencyFmt: currencyFmt,
                warehouseWeight: warehouseWeight,
                warehouseCap: warehouseCap,
                warehousePercent: warehousePercent,
                warehouseRatio: warehouseRatio,
              ),

              const SizedBox(height: 14),

              // ==========================================
              // 4. BORSA & FİYAT HAREKETLERİ (MINI WATCHLIST)
              // ==========================================
              _buildMarketWatchlist(
                context: context,
                isDark: isDark,
                currencyFmt: currencyFmt,
              ),

              // ==========================================
              // 5. YÖNETİCİ PANELİ (SADECE ADMİNLER İÇİN)
              // ==========================================
              if (isAdmin) ...[
                const SizedBox(height: 16),
                _buildAdminBanner(context: context, isDark: isDark),
              ],

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 1. AKILLI BİLDİRİM & AKSİYON KARTI
  // ---------------------------------------------------------------------------
  Widget _buildSmartActionCard({
    required BuildContext context,
    required bool isDark,
    required bool isWarehouseFull,
    required bool isWarehouseNearFull,
    required int pendingOffers,
    required int warehousePercent,
    required double warehouseFreeSpace,
  }) {
    if (isWarehouseFull) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF450A0A), const Color(0xFF1E293B)]
                : [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.2 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Depo Tamamen Doldu! (%100)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF991B1B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Üretim tesisleriniz durduruldu. Acilen toptan satış yapın veya depoyu büyütün.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.red.shade200 : const Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onNavigateToTab(2),
                icon: const Icon(Icons.inventory_2_rounded, size: 16),
                label: const Text('Depoya Git & Toptan Sat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 1,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isWarehouseNearFull) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF451A03), const Color(0xFF1E293B)]
                : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: Color(0xFFF59E0B), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Depo Kapasitesi Dolmak Üzere (%$warehousePercent)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Yalnızca ${warehouseFreeSpace.toInt()} kg boş alan kaldı. Tesislerin durmaması için satış yapın.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.amber.shade200 : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onNavigateToTab(2),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Depoyu İncele', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 1,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (pendingOffers > 0) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF311042), const Color(0xFF1E293B)]
                : [const Color(0xFFFAF5FF), const Color(0xFFF3E8FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF9333EA).withValues(alpha: 0.5), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9333EA).withValues(alpha: isDark ? 0.15 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9333EA).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_offer_rounded, color: Color(0xFFA855F7), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$pendingOffers Bekleyen Ticaret Teklifi!',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF6B21A8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Diğer oyuncular ürünlerinize teklif sundu. Kabul edip hemen nakite çevirebilirsiniz.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.purple.shade200 : const Color(0xFF7E22CE),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onOpenPazar,
                icon: const Icon(Icons.storefront_rounded, size: 16),
                label: const Text('Pazara Git & İncele', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9333EA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 1,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Normal / Tüm Operasyonlar Dengeli
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFF10B981).withValues(alpha: 0.35),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Operasyonlar Sorunsuz',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Faal 🟢',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${controller.ownedFacilities.length} üretim tesisi ve ${controller.ownedStores.length} şube aktif çalışıyor.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    );
  }

  // ---------------------------------------------------------------------------
  // 2. ŞİRKET NABZI (CANLI TEMEL GÖSTERGELER - 4'LÜ KART)
  // ---------------------------------------------------------------------------
  Widget _buildCompanyPulseSection({
    required BuildContext context,
    required bool isDark,
    required NumberFormat currencyFmt,
    required double warehouseWeight,
    required double warehouseCap,
    required int warehousePercent,
    required double warehouseRatio,
  }) {
    Color warehouseBarColor;
    if (warehouseRatio >= 0.85) {
      warehouseBarColor = Colors.redAccent;
    } else if (warehouseRatio >= 0.65) {
      warehouseBarColor = Colors.amber;
    } else {
      warehouseBarColor = const Color(0xFF10B981);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.insights_rounded,
                    size: 18,
                    color: isDark ? Colors.amberAccent : const Color(0xFF0F766E),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Şirket Nabzı',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
                  SizedBox(width: 4),
                  Text(
                    'Canlı',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 2x2 Gösterge Grid'i
        Row(
          children: [
            // 1. Saatlik Gelir Hızı
            Expanded(
              child: _buildPulseCard(
                isDark: isDark,
                icon: Icons.bolt_rounded,
                iconColor: Colors.amber,
                title: 'Saatlik Gelir',
                value: controller.statsHourlyRevenue > 0
                    ? '+${currencyFmt.format(controller.statsHourlyRevenue)} ₺/sa'
                    : '0 ₺/sa',
                subtext: 'Perakende & satışlar',
              ),
            ),
            const SizedBox(width: 10),

            // 2. Üretim Tesisleri
            Expanded(
              child: _buildPulseCard(
                isDark: isDark,
                icon: Icons.factory_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Tesisler',
                value: '${controller.ownedFacilities.where((f) => f.isProducing).length}/${controller.ownedFacilities.length} Devrede',
                subtext: 'Tesisleri Yönet ↗',
                onTap: () => onNavigateToTab(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // 3. Perakende Şubeler
            Expanded(
              child: _buildPulseCard(
                isDark: isDark,
                icon: Icons.storefront_rounded,
                iconColor: const Color(0xFFEC4899),
                title: 'Dükkanlar',
                value: '${controller.ownedStores.length} Şube Faal',
                subtext: 'Şubeleri Gör ↗',
                onTap: () => onNavigateToTab(4),
              ),
            ),
            const SizedBox(width: 10),

            // 4. Merkezi Silo & Depo
            Expanded(
              child: _buildPulseCard(
                isDark: isDark,
                icon: Icons.inventory_2_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: 'Depo Durumu',
                value: '%$warehousePercent (${warehouseWeight.toInt()} kg)',
                subtext: 'Depoya Git ↗',
                progress: warehouseRatio,
                progressColor: warehouseBarColor,
                onTap: () => onNavigateToTab(2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPulseCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtext,
    double? progress,
    Color? progressColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
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
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: isDark ? Colors.black38 : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor ?? iconColor),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                subtext,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: onTap != null
                      ? (isDark ? Colors.amberAccent : const Color(0xFF0F766E))
                      : (isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. BORSA & FİYAT HAREKETLERİ (MINI WATCHLIST)
  // ---------------------------------------------------------------------------
  Widget _buildMarketWatchlist({
    required BuildContext context,
    required bool isDark,
    required NumberFormat currencyFmt,
  }) {
    final watchlist = controller.marketItems.values.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
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
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.candlestick_chart_rounded, size: 16, color: Color(0xFF8B5CF6)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Borsa & Fiyat Hareketleri',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onOpenBorsa,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tüm Borsa',
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (watchlist.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Borsa verileri yükleniyor...',
                style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey : const Color(0xFF64748B)),
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < watchlist.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 14,
                      thickness: 0.6,
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  _buildWatchlistRow(watchlist[i], isDark: isDark, currencyFmt: currencyFmt),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildWatchlistRow(MarketItem item, {required bool isDark, required NumberFormat currencyFmt}) {
    final isUp = item.lastChangePercent >= 0;
    final changeColor = isUp ? const Color(0xFF10B981) : Colors.redAccent;

    return InkWell(
      onTap: onOpenBorsa,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(item.data.emoji, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.data.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Piyasa Arzı: ${item.marketSupply} kg',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${currencyFmt.format(item.currentPrice)} ₺',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUp ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                      size: 16,
                      color: changeColor,
                    ),
                    Text(
                      '${isUp ? '+' : ''}${item.lastChangePercent}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: changeColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. FİNANS & ŞİRKET YÖNETİMİ (BANKA & DEFTER)
  // ---------------------------------------------------------------------------
  Widget _buildFinanceSection({
    required BuildContext context,
    required bool isDark,
    required NumberFormat currencyFmt,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.account_balance_rounded,
              size: 18,
              color: isDark ? Colors.amberAccent : const Color(0xFF0F766E),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Finans & Şirket Muhasebesi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Banka Kartı
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onOpenBank,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E293B), const Color(0xFF111827)]
                            : [const Color(0xFFEFF6FF), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.35 : 0.4),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.1 : 0.04),
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
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.account_balance_rounded, size: 16, color: Color(0xFF3B82F6)),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, size: 11, color: isDark ? Colors.white38 : Colors.grey.shade400),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Banka & Kredi',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${currencyFmt.format(controller.bankSavings)} ₺',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Mevduat & Kredi ↗',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.blueAccent : const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Şirket Defteri Kartı
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onOpenLedger,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E293B), const Color(0xFF111827)]
                            : [const Color(0xFFECFDF5), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF0F766E).withValues(alpha: isDark ? 0.35 : 0.4),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F766E).withValues(alpha: isDark ? 0.1 : 0.04),
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
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F766E).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.history_edu_rounded, size: 16, color: Color(0xFF14B8A6)),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, size: 11, color: isDark ? Colors.white38 : Colors.grey.shade400),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Şirket Defteri',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Mali Kayıtlar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.tealAccent : const Color(0xFF0F766E),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Gelir & Giderler ↗',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.tealAccent : const Color(0xFF0D9488),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. YÖNETİCİ PANELİ (ADMİN BANNER)
  // ---------------------------------------------------------------------------
  Widget _buildAdminBanner({required BuildContext context, required bool isDark}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenAdmin,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF450A0A), const Color(0xFF1E293B)]
                  : [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.5), width: 1.1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withValues(alpha: isDark ? 0.15 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.security_rounded, color: Color(0xFFDC2626), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yönetici & Moderatör Paneli',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF991B1B),
                      ),
                    ),
                    Text(
                      'Oyuncu arama, para düzenleme, ban ve sunucu denetimi',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.red.shade200 : const Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Aç ↗',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
