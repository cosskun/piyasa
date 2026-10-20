import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import '../models/facility.dart';
import '../models/item.dart';
import '../models/store.dart';
import '../widgets/game_toast.dart';

class RetailTab extends StatefulWidget {
  final GameController controller;

  const RetailTab({super.key, required this.controller});

  @override
  State<RetailTab> createState() => _RetailTabState();
}

class _RetailTabState extends State<RetailTab> {
  GameController get controller => widget.controller;

  int _selectedFilterIndex = 0; // 0: Tümü, 1: Stoğu Bitenler, 2: Satışta, 3: Durdurulanlar
  int _selectedViewMode = 0; // 0: Dükkanlarım (Akordeon), 1: Hızlı Raf Matrisi
  final Set<String> _collapsedStoreIds = {};

  List<RetailStore> _getFilteredStores() {
    final stores = controller.ownedStores;
    switch (_selectedFilterIndex) {
      case 1: // Stoğu Bitenler
        return stores.where((s) => s.productSlots.any((slot) => slot.shelfStock == 0)).toList();
      case 2: // Satışta
        return stores.where((s) => s.isSelling).toList();
      case 3: // Durdurulanlar
        return stores.where((s) => !s.isSelling).toList();
      default:
        return stores;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat("#,##0", "tr_TR");
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.transparent,
        body: controller.ownedStores.isEmpty
            ? _buildEmptyState(context, isDark)
            : ListView(
                physics: const BouncingScrollPhysics(),
                cacheExtent: 600,
                padding: const EdgeInsets.all(16),
                children: [
                  // Dükkanlarım Başlığı & Yeni Dükkan Aç Butonu
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Dükkanlarım (${controller.ownedStores.length})',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showBuyStoreSheet(context),
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                        label: const Text('Yeni Dükkan Aç'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.amber[700] : const Color(0xFFD97706),
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 1. Yönetici Komuta & KPI Paneli
                  _buildExecutiveCommandBar(context, isDark, currencyFmt),
                  const SizedBox(height: 12),

                  // 2. Acil Müdahale Radarı (Tükenen Raflar)
                  _buildBottleneckRadar(context, isDark),

                  // 3. Filtreler & Görünüm Modu Değiştirici
                  _buildFilterAndModeRow(context, isDark),
                  const SizedBox(height: 12),

                  // 4. İçerik (Görünüm Moduna Göre)
                  if (_selectedViewMode == 0) ...[
                    // Dükkan Kartları (Akordeon)
                    if (_getFilteredStores().isEmpty)
                      _buildNoFilteredStoresNotice(isDark)
                    else
                      ..._getFilteredStores().map(
                        (store) => _buildStoreCard(context, store, isDark, currencyFmt),
                      ),
                  ] else ...[
                    // Hızlı Raf & Fiyat Matrisi
                    _buildShelfMatrixView(context, isDark, currencyFmt),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏪', style: TextStyle(fontSize: 54)),
            const SizedBox(height: 12),
            Text(
              'Henüz bir perakende dükkanınız yok!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'İster sadece toptan pazarda ticaret yapın, isterseniz dükkan açıp müşterilere perakende kârla satın.\nDükkanlarınızı geliştirdikçe aynı anda 5 farklı ürüne kadar satabilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey : const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showBuyStoreSheet(context),
              icon: const Icon(Icons.storefront),
              label: const Text('İlk Dükkanını Aç'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.amber[700] : const Color(0xFFD97706),
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveCommandBar(BuildContext context, bool isDark, NumberFormat currencyFmt) {
    final totalRevPerMin = controller.getTotalRetailRevenuePerMinute();
    final activeStores = controller.ownedStores.where((s) => s.isSelling).length;
    int totalSlots = 0;
    int filledSlots = 0;
    for (final s in controller.ownedStores) {
      totalSlots += s.productSlots.length;
      filledSlots += s.productSlots.where((slot) => slot.shelfStock > 0).length;
    }

    final anySelling = controller.ownedStores.any((s) => s.isSelling);
    final allAutoRestock = controller.ownedStores.isNotEmpty &&
        controller.ownedStores.every((s) => s.productSlots.every((slot) => slot.autoRestock));

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E2638), const Color(0xFF131A2A)]
              : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3 KPI Kutusu (Kompakt tek satır)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '⚡ Ciro',
                        style: TextStyle(fontSize: 9.5, color: Colors.white60),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${currencyFmt.format(totalRevPerMin.round())} ₺/dk',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFBBF24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '🏪 Dükkan',
                        style: TextStyle(fontSize: 9.5, color: Colors.white60),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$activeStores/${controller.ownedStores.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF34D399),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '📦 Dolu Raf',
                        style: TextStyle(fontSize: 9.5, color: Colors.white60),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$filledSlots/$totalSlots',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: filledSlots < totalSlots ? const Color(0xFFFB923C) : const Color(0xFF60A5FA),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Toplu Aksiyon Butonları
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              // Tüm Rafları Doldur Butonu
              InkWell(
                onTap: () {
                  final refilled = controller.refillAllStoreShelves();
                  if (refilled > 0) {
                    GameToast.showSuccess(context, 'Toplam $refilled adet ürün depodan dükkan raflarına dolduruldu!');
                  } else {
                    GameToast.showWarning(context, 'Doldurulacak boş raf bulunamadı veya depoda ürün kalmadı!');
                  }
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_rounded, size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Tüm Rafları Doldur',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              // Tümünü Başlat / Durdur Butonu
              InkWell(
                onTap: () {
                  controller.toggleAllStoresSelling(!anySelling);
                  if (!anySelling) {
                    GameToast.showSuccess(context, 'Tüm dükkanlarda satışlar başlatıldı!');
                  } else {
                    GameToast.showInfo(context, 'Tüm dükkanlarda satışlar durduruldu!');
                  }
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: anySelling ? const Color(0xFFDC2626).withOpacity(0.85) : const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        anySelling ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        anySelling ? 'Tümünü Durdur' : 'Tümünü Başlat',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              // Otomatik İkmal (Tümü) Butonu
              InkWell(
                onTap: () {
                  controller.setAllStoresAutoRestock(!allAutoRestock);
                  if (!allAutoRestock) {
                    GameToast.showSuccess(context, 'Tüm dükkan raflarında otomatik ikmal açıldı!');
                  } else {
                    GameToast.showInfo(context, 'Tüm dükkan raflarında otomatik ikmal kapatıldı!');
                  }
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        allAutoRestock ? Icons.sync_rounded : Icons.sync_disabled_rounded,
                        size: 13,
                        color: allAutoRestock ? const Color(0xFF34D399) : Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        allAutoRestock ? 'Oto-İkmal: Açık' : 'Oto-İkmal: Kapalı',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: allAutoRestock ? const Color(0xFF34D399) : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottleneckRadar(BuildContext context, bool isDark) {
    final bottlenecks = controller.getRetailBottlenecks();
    if (bottlenecks.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3B1219) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFFE11D48).withOpacity(0.5) : const Color(0xFFFCA5A5),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFE11D48)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '⚠️ ${bottlenecks.length} rafta stok tükendi!',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.redAccent : const Color(0xFFB91C1C),
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              final refilled = controller.refillAllStoreShelves();
              if (refilled > 0) {
                GameToast.showSuccess(context, '$refilled adet ürün acil olarak raflara dolduruldu!');
              } else {
                GameToast.showWarning(context, 'Bu ürünler deponuzda kalmamış! Fabrikalarınızda üretin veya toptan pazardan alın.');
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE11D48),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Depodan Doldur',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndModeRow(BuildContext context, bool isDark) {
    final stores = controller.ownedStores;
    final emptyCount = stores.where((s) => s.productSlots.any((slot) => slot.shelfStock == 0)).length;
    final sellingCount = stores.where((s) => s.isSelling).length;
    final pausedCount = stores.where((s) => !s.isSelling).length;

    return Row(
      children: [
        // Filtre Sekmeleri (Yatay Kaydırılabilir)
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Tümü (${stores.length})', 0, isDark),
                const SizedBox(width: 5),
                _buildFilterChip('⚠️ Stoğu Bitenler ($emptyCount)', 1, isDark),
                const SizedBox(width: 5),
                _buildFilterChip('🟢 Satışta ($sellingCount)', 2, isDark),
                const SizedBox(width: 5),
                _buildFilterChip('⏸️ Durdurulanlar ($pausedCount)', 3, isDark),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Görünüm Modu Değiştirici
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFCBD5E1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildViewModeToggleBtn(0, Icons.view_agenda_rounded, 'Dükkan', isDark),
              _buildViewModeToggleBtn(1, Icons.table_chart_rounded, 'Matris', isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, int index, bool isDark) {
    final isSelected = _selectedFilterIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedFilterIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.amber[700] : const Color(0xFFD97706))
              : (isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? Colors.white70 : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _buildViewModeToggleBtn(int mode, IconData icon, String tooltip, bool isDark) {
    final isSelected = _selectedViewMode == mode;
    return InkWell(
      onTap: () => setState(() => _selectedViewMode = mode),
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.amber[700] : const Color(0xFFD97706))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? (isDark ? Colors.black : Colors.white)
                  : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 4),
            Text(
              tooltip,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFilteredStoresNotice(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            'Seçilen filtreye uygun dükkan bulunamadı.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _selectedFilterIndex = 0),
            child: const Text('Filtreyi Temizle (Tümü)'),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreCard(
    BuildContext context,
    RetailStore store,
    bool isDark,
    NumberFormat currencyFmt,
  ) {
    final isCollapsed = _collapsedStoreIds.contains(store.id);

    return Card(
      color: isDark ? const Color(0xFF1E2638) : Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isDark ? 2 : 1.5,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.amber.withOpacity(0.3) : const Color(0xFFF59E0B).withOpacity(0.4),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık, Seviye, Geliştir ve Akordeon Aç/Kapa
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _showStoreDetailSheet(context, store),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(store.emoji, style: const TextStyle(fontSize: 30)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _showStoreDetailSheet(context, store),
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                store.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.info_outline_rounded,
                              size: 15,
                              color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          store.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ℹ️ Satılabilen ürünleri ve detayları gör >',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                          ),
                        ),
                        // Kompakt Raf Önizleme Çipleri
                        if (store.productSlots.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: store.productSlots.map((slot) {
                                final item = ItemRegistry.get(slot.itemId);
                                final isOut = slot.shelfStock == 0;
                                return Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isOut
                                        ? (isDark ? const Color(0xFF4C0519) : const Color(0xFFFEE2E2))
                                        : (isDark ? Colors.black26 : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isOut
                                          ? (isDark ? Colors.redAccent.withOpacity(0.5) : const Color(0xFFFCA5A5))
                                          : Colors.transparent,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    '${item?.emoji ?? "📦"} ${slot.shelfStock}/${slot.shelfCapacity}${isOut ? " ⚠️" : ""}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isOut
                                          ? (isDark ? Colors.redAccent : const Color(0xFFB91C1C))
                                          : (isDark ? Colors.grey[300] : const Color(0xFF334155)),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.blueGrey[800] : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Sv. ${store.level}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Akordeon Aç / Kapa Butonu
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (_collapsedStoreIds.contains(store.id)) {
                                _collapsedStoreIds.remove(store.id);
                              } else {
                                _collapsedStoreIds.add(store.id);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              isCollapsed
                                  ? Icons.keyboard_arrow_down_rounded
                                  : Icons.keyboard_arrow_up_rounded,
                              size: 18,
                              color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Geliştir Butonu
                    InkWell(
                      onTap: () => _showUpgradeStoreConfirmation(context, store, currencyFmt, isDark),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.amber.withOpacity(0.12) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_upward,
                              size: 13,
                              color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${currencyFmt.format(store.upgradeCost)} ₺',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Eğer kart kapalıysa sadece özet durum şeridini göster
            if (isCollapsed) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () {
                  setState(() => _collapsedStoreIds.remove(store.id));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        !store.isSelling
                            ? Icons.pause_circle_filled
                            : (store.shelfStock > 0 ? Icons.storefront : Icons.storefront_outlined),
                        size: 14,
                        color: !store.isSelling
                            ? Colors.redAccent
                            : (store.shelfStock > 0
                                ? (isDark ? Colors.greenAccent : const Color(0xFF059669))
                                : Colors.orangeAccent),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          store.statusMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: !store.isSelling
                                ? Colors.redAccent
                                : (store.shelfStock > 0
                                    ? (isDark ? Colors.greenAccent[400] : const Color(0xFF059669))
                                    : Colors.orangeAccent),
                          ),
                        ),
                      ),
                      Text(
                        'Ciro: ${currencyFmt.format(store.totalRevenue)} ₺ • Rafları Gör ▼',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Kart AÇIK olduğunda detaylar:
              const SizedBox(height: 12),

              // Durum & Ciro Şeridi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          !store.isSelling
                              ? Icons.pause_circle_filled
                              : (store.shelfStock > 0 ? Icons.storefront : Icons.storefront_outlined),
                          size: 14,
                          color: !store.isSelling
                              ? Colors.redAccent
                              : (store.shelfStock > 0
                                  ? (isDark ? Colors.greenAccent : const Color(0xFF059669))
                                  : Colors.orangeAccent),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            store.statusMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: !store.isSelling
                                  ? Colors.redAccent
                                  : (store.shelfStock > 0
                                      ? (isDark ? Colors.greenAccent[400] : const Color(0xFF059669))
                                      : Colors.orangeAccent),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Satışı Durdur / Başlat Butonu
                        InkWell(
                          onTap: () => controller.toggleStoreSelling(store),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: store.isSelling
                                  ? (isDark ? Colors.red.withOpacity(0.14) : const Color(0xFFFEE2E2))
                                  : (isDark ? Colors.green.withOpacity(0.18) : const Color(0xFFD1FAE5)),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: store.isSelling
                                    ? (isDark ? Colors.redAccent.withOpacity(0.5) : const Color(0xFFEF4444))
                                    : (isDark ? Colors.greenAccent : const Color(0xFF10B981)),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  store.isSelling ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  size: 13,
                                  color: store.isSelling
                                      ? (isDark ? Colors.redAccent : const Color(0xFFDC2626))
                                      : (isDark ? Colors.greenAccent : const Color(0xFF059669)),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  store.isSelling ? 'Satışı Durdur' : 'Satışı Başlat',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: store.isSelling
                                        ? (isDark ? Colors.redAccent : const Color(0xFFDC2626))
                                        : (isDark ? Colors.greenAccent : const Color(0xFF059669)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          'Ciro: ${currencyFmt.format(store.totalRevenue)} ₺',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Ürün Rafları Başlığı (X / Y Raflar - Maks. 5)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.shelves, size: 16, color: Color(0xFFD97706)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Ürün Rafları (${store.productSlots.length} / ${store.maxProductSlots})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Maks. 5 Ürün',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Her bir ürün rafı kutucuğu
              ...store.productSlots.map((slot) => _buildProductSlotTile(context, store, slot, isDark, currencyFmt)),

              // Yeni Ürün Rafı Ekle Butonu
              if (store.productSlots.length < store.maxProductSlots) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => _showAddProductSlotSheet(context, store),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.amber.withOpacity(0.08) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.amberAccent.withOpacity(0.5) : const Color(0xFFF59E0B),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 16,
                          color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Yeni Ürün Rafı Ekle (${store.productSlots.length}/${store.maxProductSlots})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (store.level < 5) ...[
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Daha fazla ürün satmak için Seviye ${store.level + 1}\'e yükseltin! (Maksimum 5 ürün rafı)',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(height: 22),

              // Alt Alan: Devret / Sat
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Toplam Rafta: ${store.shelfStock} adet',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: InkWell(
                      onTap: () => _showSellStoreConfirmation(context, store, currencyFmt, isDark),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.red.withOpacity(0.12) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? Colors.redAccent.withOpacity(0.5) : const Color(0xFFFCA5A5),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              size: 12,
                              color: isDark ? Colors.redAccent : const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Dükkanı Devret / Sat (${currencyFmt.format(store.resaleValue)} ₺)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.redAccent : const Color(0xFFDC2626),
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShelfMatrixView(
    BuildContext context,
    bool isDark,
    NumberFormat currencyFmt,
  ) {
    final filteredStores = _getFilteredStores();
    if (filteredStores.isEmpty) {
      return _buildNoFilteredStoresNotice(isDark);
    }

    return Column(
      children: filteredStores.map((store) {
        return Card(
          color: isDark ? const Color(0xFF1E2638) : Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isDark ? 2 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık Satırı
                Row(
                  children: [
                    Text(store.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        store.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blueGrey[800] : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Sv. ${store.level}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => controller.toggleStoreSelling(store),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: store.isSelling
                              ? (isDark ? Colors.green.withOpacity(0.2) : const Color(0xFFD1FAE5))
                              : (isDark ? Colors.red.withOpacity(0.2) : const Color(0xFFFEE2E2)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          store.isSelling ? 'Satışta' : 'Durduruldu',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: store.isSelling
                                ? (isDark ? Colors.greenAccent : const Color(0xFF059669))
                                : (isDark ? Colors.redAccent : const Color(0xFFDC2626)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                // Her bir rafın kompakt matris satırı
                if (store.productSlots.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Henüz raf eklenmemiş.',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey : const Color(0xFF64748B)),
                    ),
                  )
                else
                  ...store.productSlots.map((slot) {
                    final item = ItemRegistry.get(slot.itemId);
                    final inWh = controller.warehouse[slot.itemId] ?? 0;
                    final demandRatio = controller.getProductDemandRatio(slot.itemId, slot.retailPrice);
                    final demandPercent = (demandRatio * 100).round();
                    final isOutOfStock = slot.shelfStock == 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161C2C) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isOutOfStock
                              ? (isDark ? Colors.redAccent.withOpacity(0.3) : const Color(0xFFFCA5A5))
                              : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(item?.emoji ?? '📦', style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item?.name ?? slot.itemId,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'Raf: ${slot.shelfStock}/${slot.shelfCapacity}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isOutOfStock
                                            ? Colors.redAccent
                                            : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Depo: $inWh',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Hızlı Doldur Butonu
                          if (slot.shelfStock < slot.shelfCapacity && inWh > 0)
                            InkWell(
                              onTap: () {
                                final need = slot.shelfCapacity - slot.shelfStock;
                                final take = min(need, inWh);
                                controller.warehouse[slot.itemId] = inWh - take;
                                slot.shelfStock += take;
                                controller.notifyListeners();
                                controller.saveState();
                                GameToast.showSuccess(context, '$take adet ${item?.name ?? slot.itemId} rafa dolduruldu!');
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '+ Doldur',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.greenAccent : const Color(0xFF047857),
                                  ),
                                ),
                              ),
                            ),
                          // Fiyat ve Talep Butonu
                          InkWell(
                            onTap: () => _showSetSlotPriceDialog(context, store, slot, isDark),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.amber.withOpacity(0.15) : const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                  width: 0.8,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${slot.retailPrice.toStringAsFixed(0)} ₺',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                    ),
                                  ),
                                  Text(
                                    '%$demandPercent talep',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      color: demandPercent >= 100
                                          ? (isDark ? Colors.greenAccent : const Color(0xFF059669))
                                          : Colors.orangeAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Satışta / Durduruldu Switch
                          InkWell(
                            onTap: () {
                              controller.toggleStoreSlotSelling(store, slot, !slot.isSelling);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: slot.isSelling
                                    ? (isDark ? Colors.green.withOpacity(0.15) : const Color(0xFFD1FAE5))
                                    : (isDark ? Colors.red.withOpacity(0.15) : const Color(0xFFFEE2E2)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                slot.isSelling ? 'Satışta' : 'Durduruldu',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: slot.isSelling
                                      ? (isDark ? Colors.greenAccent : const Color(0xFF059669))
                                      : (isDark ? Colors.redAccent : const Color(0xFFDC2626)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProductSlotTile(
    BuildContext context,
    RetailStore store,
    StoreProductSlot slot,
    bool isDark,
    NumberFormat currencyFmt,
  ) {
    final item = ItemRegistry.get(slot.itemId);
    final shelfRatio = (slot.shelfStock / slot.shelfCapacity).clamp(0.0, 1.0);
    final inWh = controller.warehouse[slot.itemId] ?? 0;
    final refPrice = controller.getMarketRetailPrice(slot.itemId);
    final demandRatio = controller.getProductDemandRatio(slot.itemId, slot.retailPrice);
    final demandPercent = (demandRatio * 100).round();

    Color badgeBg;
    Color badgeText;
    String demandLabel;

    if (demandPercent >= 120) {
      badgeBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
      badgeText = isDark ? Colors.greenAccent : const Color(0xFF047857);
      demandLabel = '🔥 %$demandPercent (Yüksek Talep)';
    } else if (demandPercent >= 90) {
      badgeBg = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFDBEAFE);
      badgeText = isDark ? Colors.lightBlueAccent : const Color(0xFF1D4ED8);
      demandLabel = '⚡ %$demandPercent (Normal)';
    } else if (demandPercent >= 60) {
      badgeBg = isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
      badgeText = isDark ? Colors.amberAccent : const Color(0xFFB45309);
      demandLabel = '🐢 %$demandPercent (Düşük Talep)';
    } else {
      badgeBg = isDark ? const Color(0xFF4C0519) : const Color(0xFFFEE2E2);
      badgeText = isDark ? Colors.redAccent : const Color(0xFFB91C1C);
      demandLabel = '⚠️ %$demandPercent (Çok Pahalı)';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161C2C) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Satır: Ürün ikonu, Adı ve Eylem Butonları
          Row(
            children: [
              Text(item?.emoji ?? '📦', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item?.name ?? slot.itemId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Fiyat Değiştirme Butonu
              InkWell(
                onTap: () => _showSetSlotPriceDialog(context, store, slot, isDark),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.amber.withOpacity(0.12) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.amberAccent.withOpacity(0.6) : const Color(0xFFD97706),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit,
                        size: 11,
                        color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${slot.retailPrice.toStringAsFixed(0)} ₺',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 5),
              // Bu Ürünün Satışını Durdur / Başlat Butonu
              InkWell(
                onTap: () => controller.toggleStoreSlotSelling(store, slot),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: slot.isSelling
                        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
                        : (isDark ? const Color(0xFF4C0519) : const Color(0xFFFEE2E2)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: slot.isSelling
                          ? (isDark ? Colors.greenAccent : const Color(0xFF10B981))
                          : (isDark ? Colors.redAccent : const Color(0xFFEF4444)),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        slot.isSelling ? Icons.pause_circle_outline : Icons.play_circle_outline,
                        size: 12,
                        color: slot.isSelling
                            ? (isDark ? Colors.greenAccent : const Color(0xFF047857))
                            : (isDark ? Colors.redAccent : const Color(0xFFDC2626)),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        slot.isSelling ? 'Satışta' : 'Durduruldu',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: slot.isSelling
                              ? (isDark ? Colors.greenAccent : const Color(0xFF047857))
                              : (isDark ? Colors.redAccent : const Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (store.productSlots.length > 1) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _confirmRemoveSlot(context, store, slot),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: isDark ? Colors.grey[400] : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),

          // Piyasa Fiyatı ve Talep Oranı (Tek Satır, Asla Kırılmaz ve Bölünmez)
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Row(
              children: [
                Text(
                  'Piyasa: ${refPrice.toStringAsFixed(0)} ₺',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      demandLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: badgeText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),

          // Raf Stoğu & Depo Miktarı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Raf: ${slot.shelfStock} / ${slot.shelfCapacity} adet',
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
              Text(
                'Depoda: $inWh adet',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: inWh > 0 ? FontWeight.w600 : FontWeight.normal,
                  color: inWh > 0
                      ? (isDark ? Colors.blueAccent[100] : const Color(0xFF2563EB))
                      : (isDark ? Colors.grey[500] : const Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // İlerleme Çubuğu (Raf Doluluğu)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: shelfRatio,
              minHeight: 6,
              backgroundColor: isDark ? Colors.black38 : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                !slot.isSelling
                    ? Colors.grey
                    : (shelfRatio > 0.2
                        ? (isDark ? Colors.amberAccent : const Color(0xFFF59E0B))
                        : Colors.redAccent),
              ),
            ),
          ),
          // Müşteri Satın Alma Akışı
          if (slot.shelfStock > 0) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        !store.isSelling || !slot.isSelling
                            ? Icons.pause_circle_outline
                            : Icons.shopping_bag_outlined,
                        size: 11,
                        color: !store.isSelling || !slot.isSelling
                            ? Colors.redAccent
                            : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          !store.isSelling
                              ? 'Dükkan Satışları Durduruldu'
                              : (!slot.isSelling ? 'Bu Ürün Durduruldu' : 'Müşteri Alış İlerlemesi'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: !store.isSelling || !slot.isSelling ? FontWeight.bold : FontWeight.normal,
                            color: !store.isSelling || !slot.isSelling
                                ? Colors.redAccent
                                : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  !store.isSelling || !slot.isSelling
                      ? '⏸️ Durduruldu'
                      : (demandPercent >= 120 ? '🔥 Hızlı Akış' : (demandPercent < 80 ? '🐢 Yavaş Akış' : '⚡ Standart')),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: !store.isSelling || !slot.isSelling ? Colors.redAccent : badgeText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (!store.isSelling || !slot.isSelling)
                    ? 0.0
                    : slot.saleTimerProgress.clamp(0.0, 1.0),
                minHeight: 2.5,
                backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  (!store.isSelling || !slot.isSelling) ? Colors.redAccent : badgeText,
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),

          // Otomatik İkmal & Depodan Ekle Butonu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Depodan Otomatik Çek',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.72,
                    child: Switch(
                      value: slot.autoRestock,
                      onChanged: (val) {
                        controller.toggleStoreSlotAutoRestock(slot, val);
                      },
                      activeThumbColor: isDark ? Colors.greenAccent : const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
              if (inWh > 0 && slot.shelfStock < slot.shelfCapacity)
                ElevatedButton.icon(
                  onPressed: () {
                    final err = controller.restockStoreSlot(store, slot, 20);
                    if (err != null) {
                      GameToast.showWarning(context, err, title: 'Raf Doldurulamadı');
                    } else {
                      GameToast.showSuccess(
                        context,
                        '${item?.name ?? slot.itemId} rafına +20 adet eklendi! 🛒',
                        title: 'Rafa Eklendi',
                      );
                    }
                  },
                  icon: const Icon(Icons.add_shopping_cart, size: 12),
                  label: const Text('Rafa Ekle (+20)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.amber[700] : const Color(0xFFD97706),
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              else if (inWh == 0 && slot.shelfStock == 0)
                const Text(
                  '⚠️ Depo Boş',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSetSlotPriceDialog(
    BuildContext context,
    RetailStore store,
    StoreProductSlot slot,
    bool isDark,
  ) {
    final item = ItemRegistry.get(slot.itemId);
    final mItem = controller.marketItems[slot.itemId];
    final refPrice = controller.getMarketRetailPrice(slot.itemId);
    final priceCtrl = TextEditingController(text: slot.retailPrice.toStringAsFixed(0));
    double selectedPrice = slot.retailPrice;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final demandRatio = controller.getProductDemandRatio(slot.itemId, selectedPrice);
            final demandPercent = (demandRatio * 100).round();

            Color demandColor;
            String demandTitle;
            String demandDesc;

            if (demandPercent >= 130) {
              demandColor = isDark ? Colors.greenAccent : const Color(0xFF059669);
              demandTitle = '🔥 Çok Yüksek Talep';
              demandDesc = 'Fiyat piyasanın altında! Müşteriler mağazanıza akın edecek ve raflarınız kapış kapış satılacaktır.';
            } else if (demandPercent >= 105) {
              demandColor = isDark ? Colors.greenAccent : const Color(0xFF059669);
              demandTitle = '🔥 Yüksek Talep';
              demandDesc = 'İndirimli fiyat sayesinde satışlar standarttan daha hızlı gerçekleşir.';
            } else if (demandPercent >= 90) {
              demandColor = isDark ? Colors.lightBlueAccent : const Color(0xFF2563EB);
              demandTitle = '⚡ Dengeli Piyasa Talebi';
              demandDesc = 'Piyasa fiyatı ile tam uyumlu. Düzenli ve standart hızda müşteri akışı sağlanır.';
            } else if (demandPercent >= 60) {
              demandColor = isDark ? Colors.amberAccent : const Color(0xFFD97706);
              demandTitle = '🐢 Düşük Talep';
              demandDesc = 'Fiyat piyasanın üzerinde. Birim başına kârınız yüksek ancak müşteriler daha seyrek satın alır.';
            } else {
              demandColor = Colors.redAccent;
              demandTitle = '⚠️ Aşırı Pahalı';
              demandDesc = 'Fiyat piyasa ortalamasının çok üstünde! Müşterilerin çoğu pahalı bulup almaktan vazgeçecektir.';
            }

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              backgroundColor: isDark ? const Color(0xFF182032) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Text(item?.emoji ?? '🏷️', style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${item?.name ?? slot.itemId} Satış Fiyatı',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Belirlediğiniz fiyat piyasa fiyatının üstüne çıktıkça satın alınma hızı düşer, altına indikçe talep artarak satışlar hızlanır.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Piyasa ve Maliyet Referans Kartı
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Piyasa Perakende Fiyatı:', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[300] : const Color(0xFF64748B))),
                              Text('${refPrice.toStringAsFixed(0)} ₺', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isDark ? Colors.amberAccent : const Color(0xFFD97706))),
                            ],
                          ),
                          if (mItem != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Borsa Alış (Maliyet):', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
                                Text('${mItem.wholesaleBuyPrice.toStringAsFixed(1)} ₺', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Fiyat Girişi ve - / + Butonları
                    Row(
                      children: [
                        IconButton(
                          onPressed: selectedPrice > 1
                              ? () {
                                  setDialogState(() {
                                    selectedPrice = max(1.0, selectedPrice - 1);
                                    priceCtrl.text = selectedPrice.toStringAsFixed(0);
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                          color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                        ),
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'Satış Fiyatı (₺)',
                              suffixText: '₺',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            onChanged: (val) {
                              final p = double.tryParse(val);
                              if (p != null && p > 0) {
                                setDialogState(() {
                                  selectedPrice = p;
                                });
                              }
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setDialogState(() {
                              selectedPrice = selectedPrice + 1;
                              priceCtrl.text = selectedPrice.toStringAsFixed(0);
                            });
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Hızlı Fiyat Şablonları (İndirimli, Piyasa, Kârlı, Lüks)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPresetChip(
                            '🔥 -%20 İndirim (${(refPrice * 0.8).round()} ₺)',
                            () {
                              setDialogState(() {
                                selectedPrice = (refPrice * 0.8).roundToDouble();
                                priceCtrl.text = selectedPrice.toStringAsFixed(0);
                              });
                            },
                            isDark,
                          ),
                          const SizedBox(width: 6),
                          _buildPresetChip(
                            '⚖️ Piyasa (${refPrice.round()} ₺)',
                            () {
                              setDialogState(() {
                                selectedPrice = refPrice.roundToDouble();
                                priceCtrl.text = selectedPrice.toStringAsFixed(0);
                              });
                            },
                            isDark,
                          ),
                          const SizedBox(width: 6),
                          _buildPresetChip(
                            '💼 +%25 Kâr (${(refPrice * 1.25).round()} ₺)',
                            () {
                              setDialogState(() {
                                selectedPrice = (refPrice * 1.25).roundToDouble();
                                priceCtrl.text = selectedPrice.toStringAsFixed(0);
                              });
                            },
                            isDark,
                          ),
                          const SizedBox(width: 6),
                          _buildPresetChip(
                            '💎 +%50 Lüks (${(refPrice * 1.5).round()} ₺)',
                            () {
                              setDialogState(() {
                                selectedPrice = (refPrice * 1.5).roundToDouble();
                                priceCtrl.text = selectedPrice.toStringAsFixed(0);
                              });
                            },
                            isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Canlı Müşteri Talebi & Satış Hızı Simülasyon Kartı
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: demandColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: demandColor.withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  demandTitle,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: demandColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: demandColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: demandColor.withOpacity(0.35)),
                                ),
                                child: Text(
                                  'Talep: %$demandPercent',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: demandColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: (demandPercent / 200.0).clamp(0.05, 1.0),
                              minHeight: 5,
                              backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(demandColor),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            demandDesc,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Vazgeç', style: TextStyle(color: isDark ? Colors.grey : const Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newPrice = double.tryParse(priceCtrl.text);
                    if (newPrice != null && newPrice > 0) {
                      controller.setStoreSlotRetailPrice(store, slot, newPrice);
                      Navigator.pop(ctx);
                      GameToast.showSuccess(
                        context,
                        '${item?.name ?? slot.itemId} birim satış fiyatı ${newPrice.toStringAsFixed(0)} ₺ olarak güncellendi. (Talep: %$demandPercent)',
                        title: 'Fiyat Güncellendi',
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.amber[700] : const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Fiyatı Onayla'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E283C) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? Colors.white12 : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailStatChip({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: isDark ? Colors.amberAccent : const Color(0xFFD97706)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  void _showStoreDetailSheet(BuildContext context, RetailStore store) {
    final currencyFmt = NumberFormat("#,##0", "tr_TR");
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF141926) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final ownedStore = controller.ownedStores.where((s) => s.id == store.id).firstOrNull;
            final isOwned = ownedStore != null;
            final activeStore = ownedStore ?? store;

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Üst Çizgi Tutamacı
                    Center(
                      child: Container(
                        width: 42,
                        height: 4.5,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),

                    // Başlık Alanı
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1F283C) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? Colors.amber.withOpacity(0.3) : const Color(0xFFF59E0B).withOpacity(0.4),
                            ),
                          ),
                          child: Text(activeStore.emoji, style: const TextStyle(fontSize: 32)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      activeStore.name,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isOwned
                                          ? (isDark ? Colors.blueGrey[800] : const Color(0xFFE2E8F0))
                                          : (isDark ? Colors.amber.withOpacity(0.2) : const Color(0xFFFEF3C7)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isOwned ? 'Sv. ${activeStore.level}' : 'Katalog Modeli',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: isOwned
                                            ? (isDark ? Colors.white : const Color(0xFF334155))
                                            : (isDark ? Colors.amberAccent : const Color(0xFFB45309)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                activeStore.description,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Özet Rozetler (Hız, Kapasite, Raf Sınırı)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildDetailStatChip(
                            icon: Icons.timer_outlined,
                            label: 'Hız: ${activeStore.effectiveInterval.toStringAsFixed(1)} sn/satış',
                            isDark: isDark,
                          ),
                          const SizedBox(width: 6),
                          _buildDetailStatChip(
                            icon: Icons.inventory_2_outlined,
                            label: 'Kapasite: ${activeStore.shelfCapacity} adet/raf',
                            isDark: isDark,
                          ),
                          const SizedBox(width: 6),
                          _buildDetailStatChip(
                            icon: Icons.shelves,
                            label: 'Raflar: ${activeStore.productSlots.length}/${activeStore.maxProductSlots} (Maks. 5)',
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 18),

                    // Kaydırılabilir İçerik
                    Expanded(
                      child: ListView(
                        children: [
                          // 1. Sahip olunan dükkan için: Genel Durum ve Dükkan Satış Butonu
                          if (isOwned) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A2234) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        'Toplam Ciro: ${currencyFmt.format(activeStore.totalRevenue)} ₺',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                        ),
                                      ),
                                      Text(
                                        'Raftaki Toplam: ${activeStore.shelfStock} adet',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        activeStore.statusMessage,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: !activeStore.isSelling
                                              ? Colors.redAccent
                                              : (activeStore.shelfStock > 0
                                                  ? (isDark ? Colors.greenAccent : const Color(0xFF059669))
                                                  : Colors.orangeAccent),
                                        ),
                                      ),
                                      // Tüm Dükkanı Durdur / Başlat Butonu
                                      InkWell(
                                        onTap: () => controller.toggleStoreSelling(activeStore),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: activeStore.isSelling
                                                ? (isDark ? Colors.red.withOpacity(0.18) : const Color(0xFFFEE2E2))
                                                : (isDark ? Colors.green.withOpacity(0.20) : const Color(0xFFD1FAE5)),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: activeStore.isSelling
                                                  ? (isDark ? Colors.redAccent : const Color(0xFFEF4444))
                                                  : (isDark ? Colors.greenAccent : const Color(0xFF10B981)),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                activeStore.isSelling ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                size: 13,
                                                color: activeStore.isSelling
                                                    ? (isDark ? Colors.redAccent : const Color(0xFFDC2626))
                                                    : (isDark ? Colors.greenAccent : const Color(0xFF059669)),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                activeStore.isSelling ? 'Satışları Durdur' : 'Satışları Başlat',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: activeStore.isSelling
                                                      ? (isDark ? Colors.redAccent : const Color(0xFFDC2626))
                                                      : (isDark ? Colors.greenAccent : const Color(0xFF059669)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Aktif Raflar Başlığı
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  '🛒 Aktif Satış Rafları (${activeStore.productSlots.length} / ${activeStore.maxProductSlots})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                if (activeStore.productSlots.length < activeStore.maxProductSlots)
                                  InkWell(
                                    onTap: () => _showAddProductSlotSheet(context, activeStore),
                                    child: Text(
                                      '➕ Raf Ekle',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Aktif Raflar Listesi
                            ...activeStore.productSlots.map((slot) {
                              final item = ItemRegistry.get(slot.itemId);
                              final inWh = controller.warehouse[slot.itemId] ?? 0;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1A2234) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: !slot.isSelling
                                        ? Colors.redAccent.withOpacity(0.4)
                                        : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Text(item?.emoji ?? '📦', style: const TextStyle(fontSize: 22)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item?.name ?? slot.itemId,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                              ),
                                              Text(
                                                'Fiyat: ${slot.retailPrice.toStringAsFixed(0)} ₺ • Raf: ${slot.shelfStock}/${slot.shelfCapacity} • Depoda: $inWh',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Fiyat Değiştir
                                        InkWell(
                                          onTap: () => _showSetSlotPriceDialog(context, activeStore, slot, isDark),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.amber.withOpacity(0.12) : const Color(0xFFFFFBEB),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isDark ? Colors.amberAccent.withOpacity(0.5) : const Color(0xFFD97706),
                                              ),
                                            ),
                                            child: Icon(Icons.edit, size: 12, color: isDark ? Colors.amberAccent : const Color(0xFFD97706)),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Ürünü Durdur / Başlat Butonu
                                        InkWell(
                                          onTap: () => controller.toggleStoreSlotSelling(activeStore, slot),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: slot.isSelling
                                                  ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
                                                  : (isDark ? const Color(0xFF4C0519) : const Color(0xFFFEE2E2)),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: slot.isSelling
                                                    ? (isDark ? Colors.greenAccent : const Color(0xFF10B981))
                                                    : (isDark ? Colors.redAccent : const Color(0xFFEF4444)),
                                              ),
                                            ),
                                            child: Text(
                                              slot.isSelling ? 'Satışta (Durdur)' : 'Durduruldu (Başlat)',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: slot.isSelling
                                                    ? (isDark ? Colors.greenAccent : const Color(0xFF047857))
                                                    : (isDark ? Colors.redAccent : const Color(0xFFDC2626)),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (activeStore.productSlots.length > 1) ...[
                                          const SizedBox(width: 6),
                                          InkWell(
                                            onTap: () => _confirmRemoveSlot(context, activeStore, slot),
                                            child: const Icon(Icons.close, size: 16, color: Colors.grey),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],

                          // 2. DÜKKANDA SATILABİLEN TÜM ÜRÜNLER KATALOĞU
                          Row(
                            children: [
                              const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFFD97706)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Satılabilen Tüm Ürünler Kataloğu (${activeStore.allowedProductIds.length} Çeşit)',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Bu mağazada satabileceğiniz tüm ürünlerin borsa maliyetleri, perakende satış fiyatları, kâr marjları ve üretim kaynakları:',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 10),

                          // Ürün Kartları
                          ...activeStore.allowedProductIds.map((itemId) {
                            final item = ItemRegistry.get(itemId);
                            final wholesalePrice = controller.marketItems[itemId]?.wholesaleBuyPrice ?? (item?.basePrice ?? 10.0);
                            final retailPrice = controller.getMarketRetailPrice(itemId);
                            final profitPerUnit = retailPrice - wholesalePrice;
                            final profitMargin = wholesalePrice > 0 ? ((profitPerUnit / wholesalePrice) * 100).round() : 0;
                            final inWarehouse = controller.warehouse[itemId] ?? 0;
                            final isOnShelf = isOwned && activeStore.productSlots.any((s) => s.itemId == itemId);
                            final slotRef = isOwned
                                ? activeStore.productSlots.where((s) => s.itemId == itemId).firstOrNull
                                : null;
                            final producerBp = ProductionFacility.getBlueprints()
                                .where((f) => f.recipe.outputItemId == itemId)
                                .firstOrNull;
                            final userOwnsProducer = controller.ownedFacilities.any((f) => f.recipe.outputItemId == itemId);

                            String categoryName;
                            switch (item?.category) {
                              case ItemCategory.rawMaterial:
                                categoryName = 'Hammadde';
                                break;
                              case ItemCategory.intermediate:
                                categoryName = 'İşlenmiş Mamul';
                                break;
                              default:
                                categoryName = 'Perakende / Tüketici';
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E283C) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isOnShelf
                                      ? (isDark ? Colors.amberAccent.withOpacity(0.5) : const Color(0xFFD97706))
                                      : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                                  width: isOnShelf ? 1.4 : 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Satır 1: İkon, İsim, Kategori ve Durum Rozeti
                                  Row(
                                    children: [
                                      Text(item?.emoji ?? '📦', style: const TextStyle(fontSize: 24)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 5,
                                              runSpacing: 2,
                                              children: [
                                                Text(
                                                  item?.name ?? itemId,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    categoryName,
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (item?.description != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                item!.description,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      // Durum Rozeti
                                      if (isOnShelf)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: slotRef?.isSelling == true
                                                ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
                                                : (isDark ? const Color(0xFF4C0519) : const Color(0xFFFEE2E2)),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: slotRef?.isSelling == true
                                                  ? (isDark ? Colors.greenAccent : const Color(0xFF10B981))
                                                  : (isDark ? Colors.redAccent : const Color(0xFFEF4444)),
                                            ),
                                          ),
                                          child: Text(
                                            slotRef?.isSelling == true ? '✅ Rafta (Satışta)' : '⏸️ Rafta (Durduruldu)',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: slotRef?.isSelling == true
                                                  ? (isDark ? Colors.greenAccent : const Color(0xFF047857))
                                                  : (isDark ? Colors.redAccent : const Color(0xFFDC2626)),
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: inWarehouse > 0
                                                ? (isDark ? Colors.blue.withOpacity(0.18) : const Color(0xFFDBEAFE))
                                                : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Depoda: $inWarehouse adet',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: inWarehouse > 0 ? FontWeight.bold : FontWeight.normal,
                                              color: inWarehouse > 0
                                                  ? (isDark ? Colors.lightBlueAccent : const Color(0xFF1D4ED8))
                                                  : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Satır 2: Fiyat ve Kâr Analizi
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            children: [
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  'Borsa Maliyeti',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  '~${wholesalePrice.toStringAsFixed(0)} ₺',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 2),
                                          child: Text('➔', style: TextStyle(fontSize: 10, color: isDark ? Colors.white30 : const Color(0xFFCBD5E1))),
                                        ),
                                        Expanded(
                                          child: Column(
                                            children: [
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  'Perakende Satış',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  '~${retailPrice.toStringAsFixed(0)} ₺',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 2),
                                          child: Text('➔', style: TextStyle(fontSize: 10, color: isDark ? Colors.white30 : const Color(0xFFCBD5E1))),
                                        ),
                                        Expanded(
                                          child: Column(
                                            children: [
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  'Adet Başı Kâr',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  '+${profitPerUnit.toStringAsFixed(0)} ₺ (%$profitMargin)',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: profitPerUnit >= 0
                                                        ? (isDark ? Colors.greenAccent : const Color(0xFF059669))
                                                        : Colors.redAccent,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Satır 3: Üretim Tesisi Bilgisi
                                  Row(
                                    children: [
                                      Icon(
                                        producerBp != null ? Icons.factory_outlined : Icons.public,
                                        size: 13,
                                        color: producerBp != null
                                            ? (userOwnsProducer
                                                ? (isDark ? Colors.greenAccent : const Color(0xFF059669))
                                                : (isDark ? Colors.amberAccent : const Color(0xFFD97706)))
                                            : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          producerBp != null
                                              ? (userOwnsProducer
                                                  ? 'Üretim Tesisi: ${producerBp.emoji} ${producerBp.name} (Tesisleriniz üretiyor ✅)'
                                                  : 'Üretim Tesisi: ${producerBp.emoji} ${producerBp.name} (Tesisini kurabilirsiniz)')
                                              : 'Kaynak: Doğrudan Toptan Borsa / İthalat',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: userOwnsProducer ? FontWeight.bold : FontWeight.normal,
                                            color: producerBp != null
                                                ? (userOwnsProducer
                                                    ? (isDark ? Colors.greenAccent : const Color(0xFF059669))
                                                    : (isDark ? Colors.white70 : const Color(0xFF475569)))
                                                : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Satır 4: Aksiyon Butonları
                                  if (isOwned) ...[
                                    const SizedBox(height: 8),
                                    if (isOnShelf && slotRef != null) ...[
                                      Row(
                                        children: [
                                          Expanded(
                                            child: InkWell(
                                              onTap: () => controller.toggleStoreSlotSelling(activeStore, slotRef),
                                              borderRadius: BorderRadius.circular(6),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: slotRef.isSelling
                                                      ? (isDark ? const Color(0xFF4C0519) : const Color(0xFFFEE2E2))
                                                      : (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5)),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: slotRef.isSelling
                                                        ? (isDark ? Colors.redAccent : const Color(0xFFEF4444))
                                                        : (isDark ? Colors.greenAccent : const Color(0xFF10B981)),
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    slotRef.isSelling ? '⏸️ Bu Ürünün Satışını Durdur' : '▶️ Bu Ürünün Satışını Başlat',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: slotRef.isSelling
                                                          ? (isDark ? Colors.redAccent : const Color(0xFFDC2626))
                                                          : (isDark ? Colors.greenAccent : const Color(0xFF059669)),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          InkWell(
                                            onTap: () => _showSetSlotPriceDialog(context, activeStore, slotRef, isDark),
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isDark ? Colors.amber.withOpacity(0.12) : const Color(0xFFFFFBEB),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: isDark ? Colors.amberAccent.withOpacity(0.5) : const Color(0xFFD97706),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit, size: 12, color: isDark ? Colors.amberAccent : const Color(0xFFD97706)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${slotRef.retailPrice.toStringAsFixed(0)} ₺',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      if (activeStore.productSlots.length < activeStore.maxProductSlots)
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              final err = controller.addProductSlotToStore(activeStore, itemId);
                                              if (err != null) {
                                                GameToast.showError(context, err, title: 'Raf Eklenemedi');
                                              } else {
                                                GameToast.showSuccess(
                                                  context,
                                                  '${item?.name ?? itemId} raflara eklendi! 🎉',
                                                  title: 'Rafa Eklendi',
                                                );
                                              }
                                            },
                                            icon: const Icon(Icons.add_circle_outline, size: 14),
                                            label: const Text('Bu Ürünü Rafa Ekle'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isDark ? Colors.amber[700] : const Color(0xFFD97706),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 7),
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(vertical: 5),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '🔒 Raflar Dolu (Daha fazla ürün için dükkanı Sv. ${activeStore.level + 1}\'e yükseltin)',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    // Sahip olunmayan dükkan kataloğu alt satın al butonu
                    if (!isOwned) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (controller.cash < activeStore.purchaseCost) {
                              GameToast.showWarning(
                                context,
                                'Yetersiz nakit bakiye! Dükkan için ${currencyFmt.format(activeStore.purchaseCost)} ₺ gerekiyor.',
                                title: 'Yetersiz Bakiye',
                              );
                              return;
                            }
                            controller.buyStore(activeStore);
                            Navigator.pop(ctx);
                            GameToast.showSuccess(
                              context,
                              '${activeStore.name} mağazası açıldı! 🎊',
                              title: 'Dükkan Açıldı',
                            );
                          },
                          icon: const Icon(Icons.storefront, size: 18),
                          label: Text('Bu Dükkanı Satın Al (${currencyFmt.format(activeStore.purchaseCost)} ₺)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddProductSlotSheet(BuildContext context, RetailStore store) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final availableItemIds = store.allowedProductIds
        .where((id) => !store.productSlots.any((s) => s.itemId == id))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF141926) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(store.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Text(
                        '➕ Yeni Ürün Rafı Ekle',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Text(
                '${store.name} mağazasında satabileceğiniz uygun ürünlerden birini seçin.',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              if (availableItemIds.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'Bu mağazada satılabilecek tüm ürün çeşitleri zaten raflarınızda mevcut!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? Colors.grey : const Color(0xFF64748B)),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: availableItemIds.length,
                    itemBuilder: (ctx, i) {
                      final itemId = availableItemIds[i];
                      final item = ItemRegistry.get(itemId);
                      final inWh = controller.warehouse[itemId] ?? 0;
                      final mItem = controller.marketItems[itemId];

                      return Card(
                        color: isDark ? const Color(0xFF1E283C) : const Color(0xFFF8FAFC),
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Text(item?.emoji ?? '📦', style: const TextStyle(fontSize: 28)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item?.name ?? itemId,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tavsiye Satış: ${item?.retailSuggestedPrice.toStringAsFixed(0)} ₺ • Borsa: ${mItem?.wholesaleBuyPrice.toStringAsFixed(0) ?? "-"} ₺',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Deponuzdaki Miktar: $inWh adet',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: inWh > 0
                                            ? (isDark ? Colors.blueAccent[100] : const Color(0xFF2563EB))
                                            : Colors.orangeAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  final err = controller.addProductSlotToStore(store, itemId);
                                  if (err != null) {
                                    GameToast.showError(context, err, title: 'Raf Eklenemedi');
                                  } else {
                                    GameToast.showSuccess(
                                      context,
                                      '${item?.name ?? itemId} dükkan rafına eklendi! 🎉',
                                      title: 'Rafa Eklendi',
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? Colors.amber[700] : const Color(0xFFD97706),
                                  foregroundColor: isDark ? Colors.black : Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                child: const Text(
                                  'Rafa Ekle',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmRemoveSlot(
    BuildContext context,
    RetailStore store,
    StoreProductSlot slot,
  ) {
    final item = ItemRegistry.get(slot.itemId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF182032) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            '${item?.name ?? slot.itemId} Rafı Kaldırılsın mı?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            'Bu ürünün satış rafını kaldırmak istediğinizden emin misiniz?\nRaftaki ${slot.shelfStock} adet ürün deponuza geri aktarılacaktır.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Vazgeç', style: TextStyle(color: isDark ? Colors.grey : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                final err = controller.removeProductSlotFromStore(store, slot);
                if (err != null) {
                  GameToast.showError(context, err, title: 'Raf Kaldırılamadı');
                } else {
                  GameToast.showInfo(
                    context,
                    '${item?.name ?? slot.itemId} rafı dükkandan kaldırıldı.',
                    title: 'Raf Kaldırıldı',
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Kaldır'),
            ),
          ],
        );
      },
    );
  }

  void _showBuyStoreSheet(BuildContext context) {
    final currencyFmt = NumberFormat("#,##0", "tr_TR");
    final blueprints = RetailStore.getBlueprints();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF141926) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '🏪 Yeni Dükkan Aç',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Text(
                'Dükkanlar müşterilere perakende satış yaparak düzenli nakit akışı sağlar.\nSeviye yükseldikçe mağazanızda en fazla 5 farklı ürün aynı anda satılabilir.',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: blueprints.length,
                  itemBuilder: (ctx, i) {
                    final bp = blueprints[i];
                    final canAfford = controller.cash >= bp.purchaseCost;
                    final allowedNames = bp.allowedProductIds
                        .map((id) => ItemRegistry.get(id)?.name ?? id)
                        .join(', ');

                    return Card(
                      color: isDark ? const Color(0xFF1F283C) : const Color(0xFFF8FAFC),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark ? Colors.amber.withOpacity(0.2) : const Color(0xFFD97706).withOpacity(0.3),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(bp.emoji, style: const TextStyle(fontSize: 30)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bp.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        bp.description,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: canAfford
                                      ? () {
                                          controller.buyStore(bp);
                                          Navigator.pop(ctx);
                                          GameToast.showSuccess(
                                            context,
                                            '${bp.name} mağazası açıldı! 🎊',
                                            title: 'Dükkan Açıldı',
                                          );
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: canAfford
                                        ? (isDark ? Colors.amber[700] : const Color(0xFFD97706))
                                        : (isDark ? Colors.grey[800] : const Color(0xFFCBD5E1)),
                                    foregroundColor: canAfford && !isDark ? Colors.white : (canAfford ? Colors.black : Colors.white),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '${currencyFmt.format(bp.purchaseCost)} ₺',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFFD97706)),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'Satılabilen Ürünler: $allowedNames',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Başlangıçta 1 ürün rafı • Seviye 5\'te 5 farklı ürün rafı kapasitesi',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _showStoreDetailSheet(context, bp),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.amber.withOpacity(0.10) : const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? Colors.amberAccent.withOpacity(0.5) : const Color(0xFFD97706),
                                    width: 0.9,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.menu_book_rounded,
                                      size: 13,
                                      color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Satılabilen Ürünleri ve Kâr Detaylarını İncele >',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUpgradeStoreConfirmation(
    BuildContext context,
    RetailStore store,
    NumberFormat currencyFmt,
    bool isDark,
  ) {
    final nextLevel = store.level + 1;
    final cost = store.upgradeCost;
    final canAfford = controller.cash >= cost;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF182032) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Text(store.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${store.name} Yükseltilsin mi?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bu dükkanı Seviye $nextLevel seviyesine yükseltmek istediğinizden emin misiniz?',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.transparent : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Yükseltme Bedeli:',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey : const Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '${currencyFmt.format(cost)} ₺',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: canAfford
                                ? (isDark ? Colors.amberAccent : const Color(0xFFD97706))
                                : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    if (store.level < 5) ...[
                      Row(
                        children: [
                          const Icon(Icons.add_business, size: 16, color: Colors.greenAccent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '+1 Yeni Ürün Rafı açılır (${min(5, nextLevel)} ürüne kadar)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      children: [
                        const Icon(Icons.shelves, size: 16, color: Colors.amberAccent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Tüm rafların kapasitesi +10 adet genişler',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.people_alt_outlined, size: 16, color: Colors.blueAccent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Müşteri gelme ve satış hızı artar',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!canAfford) ...[
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Colors.redAccent),
                    SizedBox(width: 4),
                    Text(
                      'Yetersiz Bakiye! Kasadaki para yetmiyor.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Vazgeç',
                style: TextStyle(color: isDark ? Colors.grey : const Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: canAfford
                  ? () {
                      Navigator.pop(ctx);
                      final err = controller.upgradeStore(store);
                      if (err != null) {
                        GameToast.showError(context, err, title: 'Yükseltme Başarısız');
                      } else {
                        GameToast.showSuccess(
                          context,
                          '${store.name} Seviye $nextLevel seviyesine yükseltildi! 🏪',
                          title: 'Dükkan Yükseltildi',
                        );
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.amber[700] : const Color(0xFFD97706),
                foregroundColor: Colors.white,
              ),
              child: const Text('Evet, Yükselt'),
            ),
          ],
        );
      },
    );
  }

  void _showSellStoreConfirmation(
    BuildContext context,
    RetailStore store,
    NumberFormat currencyFmt,
    bool isDark,
  ) {
    final invested = store.totalInvestedValue;
    final refund = store.resaleValue;
    const depreciationPercent = 30; // %70 iade, %30 kesinti

    final spaceLeft = max(0.0, controller.maxWarehouseCapacity - controller.currentWarehouseWeight);
    int totalCanFit = 0;
    for (var slot in store.productSlots) {
      final it = ItemRegistry.get(slot.itemId);
      final w = it?.weight ?? 1.0;
      final fit = (spaceLeft / w).floor();
      totalCanFit += min(slot.shelfStock, fit);
    }
    final toWarehouse = min(store.shelfStock, totalCanFit);
    final excess = store.shelfStock - toWarehouse;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF182032) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Text(store.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${store.name} Devredilsin mi?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bu dükkanı devredip ikinci el likidasyon bedeliyle nakite dönüştürmek istediğinizden emin misiniz? Dükkan mülklerinizden çıkarılacaktır.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.transparent : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mevcut Seviye:',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey : const Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          'Seviye ${store.level}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Toplam Yatırım:',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey : const Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '${currencyFmt.format(invested)} ₺',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'İkinci El Kesintisi:',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey : const Color(0xFF64748B),
                          ),
                        ),
                        const Text(
                          '-%$depreciationPercent (Amortisman)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kasanıza Geçecek Tutar:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '+${currencyFmt.format(refund)} ₺',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (store.shelfStock > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.teal.withOpacity(0.3) : const Color(0xFF86EFAC),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 15, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Text(
                            'Raftaki Ürünler (${store.shelfStock} adet):',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.tealAccent : const Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (toWarehouse > 0)
                        Text(
                          '• $toWarehouse adet ürün deponuza geri aktarılacak.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                          ),
                        ),
                      if (excess > 0)
                        Text(
                          '• Depoda yer olmayan $excess adet ürün toptan piyasa fiyatından hemen nakite çevrilecek.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Vazgeç',
                style: TextStyle(color: isDark ? Colors.grey : const Color(0xFF64748B)),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                final err = controller.sellStore(store);
                if (err != null) {
                  GameToast.showError(context, err, title: 'Devir Başarısız');
                } else {
                  GameToast.showSuccess(
                    context,
                    '${store.name} devredildi ve ${currencyFmt.format(refund)} ₺ kasanıza aktarıldı! 💰',
                    title: 'Dükkan Devredildi',
                  );
                }
              },
              icon: const Icon(Icons.storefront_outlined, size: 16),
              label: const Text('Evet, Dükkanı Sat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
}
