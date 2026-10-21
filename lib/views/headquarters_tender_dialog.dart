import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import '../models/headquarters.dart';
import '../models/item.dart';
import '../models/tender.dart';
import '../widgets/game_toast.dart';

class HeadquartersTenderDialog extends StatefulWidget {
  final GameController controller;
  final int initialTabIndex;

  const HeadquartersTenderDialog({
    super.key,
    required this.controller,
    this.initialTabIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required GameController controller,
    int initialTabIndex = 0,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => HeadquartersTenderDialog(
        controller: controller,
        initialTabIndex: initialTabIndex,
      ),
    );
  }

  @override
  State<HeadquartersTenderDialog> createState() => _HeadquartersTenderDialogState();
}

class _HeadquartersTenderDialogState extends State<HeadquartersTenderDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _closeDialog() {
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFmt = NumberFormat("#,##0", "tr_TR");

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final c = widget.controller;
          final activeTendersCount = c.activeTenders.where((t) => !t.isCompleted).length;

          return ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 580,
              maxHeight: 760,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.corporate_fare_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Holding & Kamu İhaleleri',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Gökdelen İnşaatı & Devlet Tedarik Sözleşmeleri',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _closeDialog,
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        splashRadius: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // TabBar
                Container(
                  color: isDark ? const Color(0xFF161F30) : const Color(0xFFF1F5F9),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                    indicatorWeight: 3,
                    labelColor: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                    unselectedLabelColor: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                    tabs: [
                      const Tab(
                        icon: Icon(Icons.apartment_rounded, size: 18),
                        text: 'Holding Genel Merkezi',
                      ),
                      Tab(
                        icon: const Icon(Icons.gavel_rounded, size: 18),
                        text: 'Kamu İhaleleri ($activeTendersCount)',
                      ),
                    ],
                  ),
                ),

                // Content View
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildHeadquartersTab(context, c, isDark, currencyFmt),
                      _buildTendersTab(context, c, isDark, currencyFmt),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // TAB 1: HOLDING GENEL MERKEZİ (GÖKDELEN PROJESİ)
  // ===========================================================================
  Widget _buildHeadquartersTab(
    BuildContext context,
    GameController c,
    bool isDark,
    NumberFormat currencyFmt,
  ) {
    final currentLevelData = HeadquartersConfig.getLevel(c.hqLevel);
    final hasNext = c.hqLevel < HeadquartersConfig.levels.length - 1;
    final nextLevelData = hasNext ? HeadquartersConfig.getLevel(c.hqLevel + 1) : null;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Mevcut Genel Merkez Kartı
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.amber.withOpacity(0.3) : const Color(0xFFF59E0B).withOpacity(0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(isDark ? 0.1 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black38 : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? Colors.amber.withOpacity(0.4) : const Color(0xFFD97706).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      currentLevelData.emoji,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.amber.withOpacity(0.2) : const Color(0xFFD97706),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Sv. ${currentLevelData.level}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.amberAccent : Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                currentLevelData.name,
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
                        const SizedBox(height: 4),
                        Text(
                          currentLevelData.description,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Mevcut Avantajlar Rozetleri
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildBenefitBadge(
                    '⚡ Satış Hızı: +%${(currentLevelData.retailSpeedBoostPercent * 100).toInt()}',
                    isDark,
                    color: const Color(0xFF10B981),
                  ),
                  _buildBenefitBadge(
                    '📊 Borsa Kotası: +${currentLevelData.dailyQuotaBonus} Adet',
                    isDark,
                    color: const Color(0xFF3B82F6),
                  ),
                  _buildBenefitBadge(
                    '📉 OpEx Tasarrufu: %${(currentLevelData.opexDiscountPercent * 100).toInt()}',
                    isDark,
                    color: const Color(0xFF8B5CF6),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Yükseltme / İnşa Et Kartı
        if (hasNext && nextLevelData != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.arrow_upward_rounded, color: Color(0xFFD97706), size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Sonraki Seviye: ${nextLevelData.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  nextLevelData.perks,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final err = c.upgradeHeadquarters();
                      if (err != null) {
                        GameToast.showWarning(context, err);
                      } else {
                        GameToast.showSuccess(
                          context,
                          'Tebrikler! ${nextLevelData.name} inşası tamamlandı!',
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.cash >= nextLevelData.upgradeCost
                          ? const Color(0xFFD97706)
                          : Colors.grey.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.apartment_rounded, size: 17),
                        const SizedBox(width: 8),
                        Text(
                          'İnşa Et / Yükselt (${currencyFmt.format(nextLevelData.upgradeCost)} ₺)',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD97706), Color(0xFFB45309)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Text('👑', style: TextStyle(fontSize: 26)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Maksimum Genel Merkez Seviyesine Ulaşıldı!\nŞirketiniz dünya holdingleri zirvesinde.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // 3. Tüm Holding Seviyeleri Yol Haritası
        Text(
          'Holding Gelişim Yol Haritası',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        ...HeadquartersConfig.levels.map((lvl) {
          final isUnlocked = lvl.level <= c.hqLevel;
          final isCurrent = lvl.level == c.hqLevel;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isCurrent
                  ? (isDark ? Colors.amber.withOpacity(0.12) : const Color(0xFFFEF3C7))
                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrent
                    ? (isDark ? Colors.amberAccent : const Color(0xFFD97706))
                    : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                width: isCurrent ? 1.4 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Text(lvl.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Sv. ${lvl.level}: ${lvl.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Aktif',
                                style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lvl.perks,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isUnlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                  size: 18,
                  color: isUnlocked ? const Color(0xFF10B981) : Colors.grey,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBenefitBadge(String text, bool isDark, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: DEVLET & ŞEHİR İHALELERİ (TENDERS)
  // ===========================================================================
  Widget _buildTendersTab(
    BuildContext context,
    GameController c,
    bool isDark,
    NumberFormat currencyFmt,
  ) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Prestij Kartı
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF3B82F6).withOpacity(isDark ? 0.35 : 0.4),
              width: 1.1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.military_tech_rounded, size: 22, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Şirket Prestij Puanı: ${c.totalPrestigePoints} ⭐',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1D4ED8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kamu ihalelerini teslim ettikçe prestij ve yüksek toplu nakit kazanırsınız.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // İhale Listesi
        ...c.activeTenders.map((tender) => _buildTenderCard(context, c, tender, isDark, currencyFmt)),
      ],
    );
  }

  Widget _buildTenderCard(
    BuildContext context,
    GameController c,
    TenderContract tender,
    bool isDark,
    NumberFormat currencyFmt,
  ) {
    final item = ItemRegistry.get(tender.itemId);
    final inStock = c.warehouse[tender.itemId] ?? 0;
    final ratio = (inStock / tender.requiredAmount).clamp(0.0, 1.0);
    final percent = (ratio * 100).toInt();
    final canDeliver = inStock >= tender.requiredAmount && !tender.isCompleted;

    double rewardCash = tender.rewardCash;
    if (c.hqLevel >= 4) {
      rewardCash *= 1.25; // %25 Gökdelen Kamu İhale Primi
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tender.isCompleted
              ? (isDark ? Colors.white12 : const Color(0xFFE2E8F0))
              : (canDeliver ? const Color(0xFF10B981) : (isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
          width: canDeliver ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.12 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kurum & Başlık
          Row(
            children: [
              Text(tender.agencyEmoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tender.agency,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      tender.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              if (tender.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                      SizedBox(width: 3),
                      Text(
                        'Teslim Edildi',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            tender.description,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
              height: 1.3,
            ),
          ),

          const SizedBox(height: 10),

          // Gereksinim & İlerleme Çubuğu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Depodaki Stok: $inStock / ${tender.requiredAmount} adet',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
              Text(
                '%$percent',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: canDeliver ? const Color(0xFF10B981) : (isDark ? Colors.amberAccent : const Color(0xFFD97706)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                tender.isCompleted
                    ? Colors.grey
                    : (canDeliver ? const Color(0xFF10B981) : const Color(0xFFD97706)),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Kazanç ve Teslim Butonu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '+${currencyFmt.format(rewardCash)} ₺',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.greenAccent : const Color(0xFF047857),
                    ),
                  ),
                  Text(
                    '+${tender.rewardPrestige} Prestij Puanı',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
              if (!tender.isCompleted)
                ElevatedButton.icon(
                  onPressed: canDeliver
                      ? () {
                          final err = c.deliverTender(tender);
                          if (err != null) {
                            GameToast.showWarning(context, err);
                          } else {
                            GameToast.showSuccess(
                              context,
                              'İhale teslimatı başarıyla yapıldı! +${currencyFmt.format(rewardCash)} ₺ ve +${tender.rewardPrestige} Prestij kazandınız!',
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.local_shipping_rounded, size: 15),
                  label: Text(
                    canDeliver ? 'İhaleyi Teslim Et 🚚' : 'Eksik: ${tender.requiredAmount - inStock}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    disabledForegroundColor: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
