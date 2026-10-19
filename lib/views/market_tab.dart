import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import '../models/item.dart';
import '../models/market_item.dart';
import '../models/market_listing.dart';
import '../models/market_offer.dart';
import '../models/limit_order.dart';
import '../services/firebase_service.dart';
import '../widgets/game_toast.dart';

enum MarketFilter {
  all, // Tüm Borsa
  rawMaterials, // Hammaddeler (Tarlalar)
  intermediate, // Ara Mamuller (Fabrikalar)
  finishedGoods, // Perakende Mamuller
}

class MarketTab extends StatefulWidget {
  final GameController controller;

  const MarketTab({super.key, required this.controller});

  @override
  State<MarketTab> createState() => MarketTabState();
}

class MarketTabState extends State<MarketTab> {
  int _mainTab = 0; // 0: Borsa & Toptan, 1: Oyuncu Pazarı, 2: Teklifler
  int _borsaSubTab = 0; // 0: Canlı Borsa Fiyatları, 1: Alış Emirlerim
  int _pazarSubTab = 0; // 0: Topluluk İlanları, 1: Benim İlanlarım
  int _offerSubTab = 0; // 0: Gelen Teklifler, 1: Verilen Teklifler
  MarketFilter _currentFilter = MarketFilter.all; // Varsayılan olarak Tüm Borsa
  static final NumberFormat _currencyFmt = NumberFormat("#,##0.00", "tr_TR");

  final ScrollController _categoryScrollController = ScrollController();
  final TextEditingController _communitySearchController = TextEditingController();
  String _communitySearchQuery = '';
  int _communityCategoryFilter = 0; // 0: Tümü, 1: Hammadde, 2: Ara Mamul, 3: Nihai Ürün, 4: Resmi Rezerv, 5: Oyuncular
  int _communitySortMode = 0; // 0: En Uygun Fiyat, 1: En Çok Stok, 2: En Yeni, 3: Fırsatlar
  bool _isCatalogSidebarOpen = false; // Sol açılır/kapanır ürün katalog paneli
  String? _selectedCatalogItemId; // Seçili ürün (null = tümü)

  void switchToOffers({int subTab = 0}) {
    if (!mounted) return;
    setState(() {
      _mainTab = 2; // Teklifler
      _offerSubTab = subTab; // 0: Gelen Teklifler, 1: Verilen Teklifler
    });
  }

  void switchToOrders() {
    if (!mounted) return;
    setState(() {
      _mainTab = 0; // Borsa
      _borsaSubTab = 1; // Alış Emirlerim
    });
  }

  void switchToCommunityListings({int subTab = 0}) {
    if (!mounted) return;
    setState(() {
      _mainTab = 1; // Oyuncu Pazarı
      _pazarSubTab = subTab;
    });
  }

  void switchToBorsa() {
    if (!mounted) return;
    setState(() {
      _mainTab = 0; // Borsa
      _borsaSubTab = 0; // Canlı Fiyatlar
    });
  }

  @override
  void dispose() {
    _categoryScrollController.dispose();
    _communitySearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final c = widget.controller;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              // === 1. ÜST ANA SEKMELER (BORSA / OYUNCU PAZARI / TEKLİFLER) ===
              Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131C2E) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFCBD5E1).withOpacity(0.8),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    _buildTopTabItem(
                      index: 0,
                      label: 'Borsa',
                      icon: Icons.candlestick_chart_outlined,
                      badgeCount: c.pendingOrdersCount,
                      isDark: isDark,
                      flex: 26,
                      isAlert: c.pendingOrdersCount > 0,
                    ),
                    const SizedBox(width: 6),
                    _buildTopTabItem(
                      index: 1,
                      label: 'Oyuncu Pazarı',
                      icon: Icons.storefront_outlined,
                      badgeCount: c.communityListings.length,
                      isDark: isDark,
                      flex: 40,
                    ),
                    const SizedBox(width: 6),
                    _buildTopTabItem(
                      index: 2,
                      label: 'Teklifler',
                      icon: Icons.local_offer_outlined,
                      badgeCount: c.totalActiveOffersBadge,
                      isDark: isDark,
                      flex: 34,
                      isAlert: c.totalActiveOffersBadge > 0,
                    ),
                  ],
                ),
              ),

              // === 2. SEÇİLEN SEKMEYE GÖRE İÇERİK ===
              Expanded(
                child: _buildCurrentTabView(isDark),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopTabItem({
    required int index,
    required String label,
    required IconData icon,
    required int badgeCount,
    required bool isDark,
    required int flex,
    bool isAlert = false,
  }) {
    final isSelected = _mainTab == index;
    return Expanded(
      flex: flex,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _mainTab = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFF27354F) : Colors.white)
                  : (isDark ? const Color(0xFF182235) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F766E))
                    : (isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFCBD5E1)),
                width: isSelected ? 1.4 : 0.8,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F766E)).withOpacity(0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 1.5),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected
                      ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F766E))
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      letterSpacing: -0.2,
                      color: isSelected
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ),
                if (badgeCount > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    constraints: const BoxConstraints(minWidth: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isAlert
                          ? const Color(0xFFEF4444)
                          : (isSelected
                              ? (isDark ? const Color(0xFF0D9488) : const Color(0xFF0F766E))
                              : (isDark ? const Color(0xFF334155) : const Color(0xFF94A3B8))),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: isAlert
                          ? [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabView(bool isDark) {
    switch (_mainTab) {
      case 0:
        return _buildCommodityMarketView(isDark);
      case 1:
        return _buildCommunityMarketParentView(isDark);
      case 2:
        return _buildOffersParentView(isDark);
      default:
        return const SizedBox();
    }
  }

  // ==========================================
  // TAB 1: BORSA VE TOPTAN İŞLEMLER
  // ==========================================
  Widget _buildCommodityMarketView(bool isDark) {
    final currencyFmt = _currencyFmt;
    final warehouse = widget.controller.warehouse;

    final items = widget.controller.marketItems.values.where((m) {
      switch (_currentFilter) {
        case MarketFilter.rawMaterials:
          return m.data.category == ItemCategory.rawMaterial;
        case MarketFilter.intermediate:
          return m.data.category == ItemCategory.intermediate;
        case MarketFilter.finishedGoods:
          return m.data.category == ItemCategory.finishedGood;
        case MarketFilter.all:
        default:
          return true;
      }
    }).toList();

    return Column(
      children: [
        // Borsa Alt Sekmeler (Canlı Fiyatlar vs Alış Emirlerim)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E283E) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildBorsaSubTabButton(
                  title: '📊 Canlı Borsa Fiyatları',
                  isSelected: _borsaSubTab == 0,
                  isDark: isDark,
                  onTap: () => setState(() => _borsaSubTab = 0),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildBorsaSubTabButton(
                  title: '🎯 Alış Emirlerim (${widget.controller.pendingOrdersCount})',
                  isSelected: _borsaSubTab == 1,
                  isDark: isDark,
                  badgeCount: widget.controller.pendingOrdersCount,
                  onTap: () => setState(() => _borsaSubTab = 1),
                ),
              ),
            ],
          ),
        ),

        if (_borsaSubTab == 1)
          Expanded(child: _buildLimitOrdersView(isDark))
        else ...[
          // Kategori ve Filtre Butonları (Yatay Kaydırma Düzeltmesi)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: SingleChildScrollView(
              key: const PageStorageKey('market_category_chips_scroll'),
              controller: _categoryScrollController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  _buildFilterPill(
                    label: '🌐 Tüm Borsa',
                    filter: MarketFilter.all,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterPill(
                    label: '🌾 Hammadde Borsası',
                    filter: MarketFilter.rawMaterials,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterPill(
                    label: '🏭 Sanayi & Ara Mamul',
                    filter: MarketFilter.intermediate,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterPill(
                    label: '🏪 Tüketici Ürünleri',
                    filter: MarketFilter.finishedGoods,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),
          ),

        // Bilgi Kartı
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E283E) : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.blueAccent.withOpacity(0.3) : const Color(0xFFBFDBFE),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 17,
                color: isDark ? Colors.lightBlueAccent : const Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚡ Hızlı Sat: Anında nakit al. 📈 Satın Al: Toptan alıp fabrikanda veya dükkanında kullan.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : const Color(0xFF1E40AF),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Emtia Listesi veya Boş Durum
        Expanded(
          child: items.isEmpty
              ? _buildEmptyFilterView(isDark)
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final mItem = items[i];
                    final inStock = widget.controller.warehouse[mItem.itemId] ?? 0;
                    final isPositive = mItem.lastChangePercent >= 0;

                    return Card(
                      color: isDark ? const Color(0xFF1B2234) : Colors.white,
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: isDark ? 2 : 1.2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isPositive
                              ? (isDark ? Colors.green.withOpacity(0.2) : const Color(0xFF10B981).withOpacity(0.3))
                              : (isDark ? Colors.red.withOpacity(0.2) : const Color(0xFFEF4444).withOpacity(0.3)),
                          width: 1.2,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _showCommodityDetailSheet(context, mItem, isDark: isDark),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(mItem.data.emoji, style: const TextStyle(fontSize: 24)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          mItem.data.name,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          mItem.data.description,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isPositive
                                          ? (isDark ? Colors.green.withOpacity(0.15) : const Color(0xFFECFDF5))
                                          : (isDark ? Colors.red.withOpacity(0.15) : const Color(0xFFFEF2F2)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${isPositive ? '▲ +' : '▼ '}${mItem.lastChangePercent}%',
                                      style: TextStyle(
                                        color: isPositive
                                            ? (isDark ? Colors.greenAccent : const Color(0xFF059669))
                                            : (isDark ? Colors.redAccent : const Color(0xFFDC2626)),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Divider(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0), height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 23,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'Borsa Gösterge',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '${currencyFmt.format(mItem.currentPrice)} ₺',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    flex: 25,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'Hızlı Satış (-%15)',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isDark ? Colors.orangeAccent : const Color(0xFFD97706),
                                            ),
                                          ),
                                        ),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '${currencyFmt.format(mItem.quickSellPrice)} ₺',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.orangeAccent : const Color(0xFFD97706),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    flex: 22,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: inStock > 0
                                              ? (isDark ? Colors.amber.withOpacity(0.15) : const Color(0xFFFEF3C7))
                                              : (isDark ? Colors.black26 : const Color(0xFFF1F5F9)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.warehouse_outlined,
                                              size: 13,
                                              color: inStock > 0
                                                  ? (isDark ? Colors.amberAccent : const Color(0xFFD97706))
                                                  : Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Deponda: $inStock',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: inStock > 0
                                                    ? (isDark ? Colors.amberAccent : const Color(0xFF92400E))
                                                    : (isDark ? Colors.grey : const Color(0xFF64748B)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    flex: 16,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF24324D) : const Color(0xFFE0E7FF),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isDark ? Colors.lightBlueAccent.withOpacity(0.3) : const Color(0xFFC7D2FE),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'İşlemler',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.lightBlueAccent : const Color(0xFF3730A3),
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            Icon(
                                              Icons.chevron_right,
                                              size: 14,
                                              color: isDark ? Colors.lightBlueAccent : const Color(0xFF3730A3),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        ],
      ],
    );
  }

  Widget _buildEmptyFilterView(bool isDark) {
    const title = 'Bu Kategoride Ürün Bulunamadı';
    const subtitle = 'Seçilen borsa kategorisinde şu anda listelenen ürün bulunmuyor.';
    const icon = Icons.candlestick_chart_outlined;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E283E) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: isDark ? Colors.amberAccent : const Color(0xFFD97706)),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() => _currentFilter = MarketFilter.all),
              icon: const Icon(Icons.list_alt, size: 16),
              label: const Text('Tüm Borsayı Görüntüle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.blueAccent[700] : const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required MarketFilter filter,
    required bool isDark,
    String? badge,
    bool isHighlight = false,
  }) {
    final isSelected = _currentFilter == filter;

    Color bgColor;
    Color borderColor;
    Color textColor;

    if (isSelected) {
      if (isHighlight) {
        bgColor = isDark ? const Color(0xFFD97706) : const Color(0xFFD97706);
        borderColor = Colors.amberAccent;
        textColor = Colors.white;
      } else {
        bgColor = isDark ? const Color(0xFF0F766E) : const Color(0xFF0F766E);
        borderColor = isDark ? Colors.tealAccent : const Color(0xFF14B8A6);
        textColor = Colors.white;
      }
    } else {
      if (isHighlight) {
        bgColor = isDark ? const Color(0xFF261D10) : const Color(0xFFFEF3C7);
        borderColor = isDark ? Colors.amber.withOpacity(0.35) : const Color(0xFFFDE68A);
        textColor = isDark ? Colors.amberAccent : const Color(0xFFB45309);
      } else {
        bgColor = isDark ? const Color(0xFF1E283E) : const Color(0xFFF1F5F9);
        borderColor = isDark ? Colors.white12 : const Color(0xFFCBD5E1);
        textColor = isDark ? Colors.grey[300]! : const Color(0xFF334155);
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          setState(() {
            _currentFilter = filter;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (isHighlight ? Colors.amber : const Color(0xFF0F766E)).withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.25)
                        : (isHighlight
                            ? (isDark ? Colors.amberAccent : const Color(0xFFD97706))
                            : (isDark ? Colors.tealAccent.withOpacity(0.25) : const Color(0xFF0F766E).withOpacity(0.18))),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isHighlight
                              ? (isDark ? Colors.black87 : Colors.white)
                              : (isDark ? Colors.tealAccent : const Color(0xFF0F766E))),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: OYUNCU PAZARI (DİĞER OYUNCULAR & BENİM İLANLARIM)
  // ==========================================
  Widget _buildCommunityMarketParentView(bool isDark) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161F33) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _pazarSubTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                    decoration: BoxDecoration(
                      color: _pazarSubTab == 0
                          ? (isDark ? const Color(0xFF243452) : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _pazarSubTab == 0
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '🛒 Oyuncu İlanları (${widget.controller.communityListings.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _pazarSubTab == 0 ? FontWeight.bold : FontWeight.w600,
                            color: _pazarSubTab == 0
                                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _pazarSubTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                    decoration: BoxDecoration(
                      color: _pazarSubTab == 1
                          ? (isDark ? const Color(0xFF243452) : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _pazarSubTab == 1
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '📦 Benim İlanlarım (${widget.controller.activeListings.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _pazarSubTab == 1 ? FontWeight.bold : FontWeight.w600,
                            color: _pazarSubTab == 1
                                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _pazarSubTab == 0
              ? _buildCommunityListingsList(isDark)
              : _buildPlayerActiveListingsList(isDark),
        ),
      ],
    );
  }

  Widget _buildCommunityListingsList(bool isDark) {
    final currencyFmt = NumberFormat("#,##0.00", "tr_TR");
    final allListings = widget.controller.communityListings;

    if (allListings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_outlined, size: 48, color: isDark ? Colors.grey[600] : const Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                'Şu anda pazarda aktif ilan yok.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Piyasa rezervleri hazırlanıyor veya yeni oyuncu ilanları bekleniyor...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      );
    }

    // Kategori Sayaçları
    final countAll = allListings.length;
    final countRaw = allListings.where((l) => l.item.category == ItemCategory.rawMaterial).length;
    final countIntermediate = allListings.where((l) => l.item.category == ItemCategory.intermediate).length;
    final countFinished = allListings.where((l) => l.item.category == ItemCategory.finishedGood).length;
    final countReserve = allListings.where((l) => l.isOfficialReserve).length;
    final countPlayer = allListings.where((l) => !l.isOfficialReserve).length;

    // Yan katalog için benzersiz ürünler ve ilan sayıları
    final itemListingCounts = <String, int>{};
    for (var l in allListings) {
      itemListingCounts[l.itemId] = (itemListingCounts[l.itemId] ?? 0) + 1;
    }
    final sortedItemIds = itemListingCounts.keys.toList()
      ..sort((a, b) => (itemListingCounts[b] ?? 0).compareTo(itemListingCounts[a] ?? 0));

    // Filtreleme
    final filtered = allListings.where((listing) {
      if (_communityCategoryFilter == 1 && listing.item.category != ItemCategory.rawMaterial) return false;
      if (_communityCategoryFilter == 2 && listing.item.category != ItemCategory.intermediate) return false;
      if (_communityCategoryFilter == 3 && listing.item.category != ItemCategory.finishedGood) return false;
      if (_communityCategoryFilter == 4 && !listing.isOfficialReserve) return false;
      if (_communityCategoryFilter == 5 && listing.isOfficialReserve) return false;

      // Sol katalogdan tekil ürün seçimi
      if (_selectedCatalogItemId != null && listing.itemId != _selectedCatalogItemId) return false;

      if (_communitySearchQuery.isNotEmpty) {
        final query = _communitySearchQuery.toLowerCase();
        final matchItem = listing.item.name.toLowerCase().contains(query);
        final matchSeller = listing.sellerName.toLowerCase().contains(query);
        if (!matchItem && !matchSeller) return false;
      }

      return true;
    }).toList();

    // Sıralama
    filtered.sort((a, b) {
      final mA = widget.controller.marketItems[a.itemId];
      final mB = widget.controller.marketItems[b.itemId];
      final marketPriceA = mA?.currentPrice ?? a.pricePerUnit;
      final marketPriceB = mB?.currentPrice ?? b.pricePerUnit;

      switch (_communitySortMode) {
        case 0: // En Uygun Fiyat
          return a.pricePerUnit.compareTo(b.pricePerUnit);
        case 1: // En Çok Stok
          return b.remainingQuantity.compareTo(a.remainingQuantity);
        case 2: // En Yeni
          return b.listedAt.compareTo(a.listedAt);
        case 3: // Borsa Altı Fırsatlar (en çok tasarruf sağlayan)
          final discountA = marketPriceA - a.pricePerUnit;
          final discountB = marketPriceB - b.pricePerUnit;
          return discountB.compareTo(discountA);
        default:
          return 0;
      }
    });

    return Column(
      children: [
        // 1. ARAMA VE SIRALAMA ÇUBUĞU
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
          child: Row(
            children: [
              // Sol Katalog Paneli Aç/Kapat Butonu
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _isCatalogSidebarOpen = !_isCatalogSidebarOpen),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _isCatalogSidebarOpen
                        ? (isDark ? const Color(0xFF0F766E).withValues(alpha: 0.35) : const Color(0xFFCCFBF1))
                        : (isDark ? const Color(0xFF161E2E) : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isCatalogSidebarOpen
                          ? const Color(0xFF14B8A6)
                          : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isCatalogSidebarOpen ? Icons.view_sidebar_rounded : Icons.view_sidebar_outlined,
                        size: 18,
                        color: _isCatalogSidebarOpen
                            ? (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E))
                            : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Katalog',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: _isCatalogSidebarOpen
                              ? (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E))
                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161E2E) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: TextField(
                    controller: _communitySearchController,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ürün veya satıcı ara...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                      suffixIcon: _communitySearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                setState(() {
                                  _communitySearchController.clear();
                                  _communitySearchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() => _communitySearchQuery = val.trim()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Sıralama Menüsü
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161E2E) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                  ),
                ),
                child: PopupMenuButton<int>(
                  initialValue: _communitySortMode,
                  onSelected: (val) => setState(() => _communitySortMode = val),
                  tooltip: 'Sıralama Seçenekleri',
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: isDark ? const Color(0xFF1E283E) : Colors.white,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_vert_rounded,
                        size: 18,
                        color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _communitySortMode == 0
                            ? 'En Uygun'
                            : _communitySortMode == 1
                                ? 'Çok Stok'
                                : _communitySortMode == 2
                                    ? 'En Yeni'
                                    : 'Fırsatlar',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_drop_down, size: 16, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                    ],
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 0,
                      child: Row(
                        children: [
                          Icon(Icons.arrow_downward, size: 16, color: Colors.green),
                          SizedBox(width: 8),
                          Text('En Uygun Fiyat', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 1,
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('En Çok Stok', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 2,
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 16, color: Colors.amber),
                          SizedBox(width: 8),
                          Text('En Yeni İlanlar', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 3,
                      child: Row(
                        children: [
                          Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('🔥 Borsa Altı Fırsatlar', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. KATEGORİ FİLTRE ÇİPLERİ
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          child: Row(
            children: [
              _buildCategoryFilterChip(0, 'Tümü', countAll, isDark),
              const SizedBox(width: 6),
              _buildCategoryFilterChip(1, '🌾 Hammadde', countRaw, isDark),
              const SizedBox(width: 6),
              _buildCategoryFilterChip(2, '🏭 Ara Mamul', countIntermediate, isDark),
              const SizedBox(width: 6),
              _buildCategoryFilterChip(3, '🥖 Nihai Ürün', countFinished, isDark),
              const SizedBox(width: 6),
              _buildCategoryFilterChip(4, '🏛️ Piyasa Rezervi', countReserve, isDark, isReserve: true),
              const SizedBox(width: 6),
              _buildCategoryFilterChip(5, '👤 Oyuncular', countPlayer, isDark),
            ],
          ),
        ),

        // 3. SONUÇ BİLGİ ŞERİDİ (Filtre, Arama veya Katalog Seçimi aktifse)
        if (_communitySearchQuery.isNotEmpty || _communityCategoryFilter != 0 || _selectedCatalogItemId != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${filtered.length} ilan bulundu',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),
                    if (_selectedCatalogItemId != null) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => setState(() => _selectedCatalogItemId = null),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F766E).withValues(alpha: 0.35) : const Color(0xFFCCFBF1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF14B8A6).withValues(alpha: 0.5) : const Color(0xFF14B8A6),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${ItemRegistry.get(_selectedCatalogItemId!)?.emoji ?? '📦'} ${ItemRegistry.get(_selectedCatalogItemId!)?.name ?? _selectedCatalogItemId}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.close_rounded,
                                size: 12,
                                color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _communitySearchQuery = '';
                      _communitySearchController.clear();
                      _communityCategoryFilter = 0;
                      _selectedCatalogItemId = null;
                    });
                  },
                  child: Text(
                    'Filtreleri Temizle',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 4. İLAN LİSTESİ VEYA BOŞ DURUM (SOL KATALOG PANELİ İLE BİRLİKTE)
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Açılır / Kapanır Sol Katalog Paneli
              _buildCatalogSidebar(
                isDark: isDark,
                itemListingCounts: itemListingCounts,
                sortedItemIds: sortedItemIds,
                totalCount: allListings.length,
              ),

              // Ana İlan Alanı (2'li Zengin Vitrin Kartları Grid)
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 44,
                                color: isDark ? Colors.grey[600] : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Kriterlere uygun ilan bulunamadı.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Arama sözcüğünü veya kategori filtresini değiştirip tekrar deneyin.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _communitySearchQuery = '';
                                    _communitySearchController.clear();
                                    _communityCategoryFilter = 0;
                                    _selectedCatalogItemId = null;
                                  });
                                },
                                icon: const Icon(Icons.refresh, size: 14),
                                label: const Text('Filtreleri Sıfırla'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(10, 4, 14, 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          mainAxisExtent: 228,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          return _buildShowcaseGridCard(filtered[i], isDark, currencyFmt);
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCatalogSidebar({
    required bool isDark,
    required Map<String, int> itemListingCounts,
    required List<String> sortedItemIds,
    required int totalCount,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: _isCatalogSidebarOpen ? 92 : 0,
      child: _isCatalogSidebarOpen
          ? Container(
              margin: const EdgeInsets.only(left: 10, bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                ),
              ),
              child: Column(
                children: [
                  // Başlık & Kapatma Butonu
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A2438) : const Color(0xFFE2E8F0),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ÜRÜNLER',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _isCatalogSidebarOpen = false),
                          child: const Icon(Icons.chevron_left_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                  // Ürün Kartları Listesi
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(4),
                      itemCount: sortedItemIds.length + 1,
                      itemBuilder: (ctx, idx) {
                        if (idx == 0) {
                          final isSelected = _selectedCatalogItemId == null;
                          return InkWell(
                            onTap: () => setState(() => _selectedCatalogItemId = null),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? const Color(0xFF0F766E).withValues(alpha: 0.35) : const Color(0xFFCCFBF1))
                                    : (isDark ? const Color(0xFF1B2234) : Colors.white),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF14B8A6)
                                      : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Text('📦', style: TextStyle(fontSize: 18)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tümü',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected
                                          ? (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E))
                                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                    ),
                                  ),
                                  Text(
                                    '$totalCount İlan',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final itemId = sortedItemIds[idx - 1];
                        final item = ItemRegistry.get(itemId);
                        final count = itemListingCounts[itemId] ?? 0;
                        final isSelected = _selectedCatalogItemId == itemId;

                        return InkWell(
                          onTap: () => setState(() {
                            _selectedCatalogItemId = isSelected ? null : itemId;
                          }),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? const Color(0xFF0F766E).withValues(alpha: 0.35) : const Color(0xFFCCFBF1))
                                  : (isDark ? const Color(0xFF1B2234) : Colors.white),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF14B8A6)
                                    : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(item?.emoji ?? '📦', style: const TextStyle(fontSize: 18)),
                                const SizedBox(height: 2),
                                Text(
                                  item?.name ?? itemId,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected
                                        ? (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E))
                                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                ),
                                Text(
                                  '$count İlan',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
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
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildShowcaseGridCard(MarketListing listing, bool isDark, NumberFormat currencyFmt) {
    final mItem = widget.controller.marketItems[listing.itemId];
    final marketPrice = mItem?.currentPrice ?? listing.pricePerUnit;
    final isDiscounted = listing.pricePerUnit < marketPrice;
    final discountPct = isDiscounted ? ((marketPrice - listing.pricePerUnit) / marketPrice) * 100 : 0.0;
    final isOfficial = listing.isOfficialReserve;
    final isOwn = listing.isPlayerListing || (listing.sellerId != null && listing.sellerId == FirebaseService().playerId);

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: isOfficial
            ? (isDark ? const Color(0xFF132228) : const Color(0xFFF0FDF4))
            : (isDark ? const Color(0xFF1B2234) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOfficial
              ? (isDark ? const Color(0xFF0D9488).withValues(alpha: 0.5) : const Color(0xFF14B8A6).withValues(alpha: 0.6))
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          width: isOfficial ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Üst Rozet
          Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: isOfficial
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F766E).withValues(alpha: 0.3) : const Color(0xFFCCFBF1),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: isDark ? const Color(0xFF14B8A6).withValues(alpha: 0.5) : const Color(0xFF14B8A6),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            size: 10,
                            color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'RESMİ PİYASA REZERVİ',
                            style: TextStyle(
                              fontSize: 8.0,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    )
                  : isDiscounted
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: Colors.amber, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department, size: 10, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                '-%${discountPct.toStringAsFixed(0)} FIRSAT',
                                style: const TextStyle(
                                  fontSize: 8.0,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person, size: 10, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                              const SizedBox(width: 2),
                              Text(
                                'Oyuncu',
                                style: TextStyle(
                                  fontSize: 8.0,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ),

          const Spacer(),

          // 2. Ürün Vitrini (Büyük Emoji, İsim, Satıcı)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141E30) : const Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    listing.item.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  listing.item.name,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  isOwn ? 'Senin İlanın' : listing.sellerName,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: isOfficial
                        ? (isDark ? Colors.tealAccent.shade100 : const Color(0xFF047857))
                        : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                    fontWeight: isOfficial ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const Spacer(),

          // 3. Fiyat ve Stok Kutusu
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${currencyFmt.format(listing.pricePerUnit)} ₺',
                        style: const TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      if (isDiscounted) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${currencyFmt.format(marketPrice)} ₺',
                          style: TextStyle(
                            fontSize: 9.0,
                            decoration: TextDecoration.lineThrough,
                            color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  'Stok: ${listing.remainingQuantity} adet',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // 4. Aksiyon Butonları
          if (isOfficial)
            SizedBox(
              width: double.infinity,
              height: 28,
              child: ElevatedButton(
                onPressed: () => _showDirectBuyDialog(context, listing, isDark),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF0F766E) : const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_checkout, size: 12),
                      SizedBox(width: 4),
                      Text('Hemen Satın Al', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            )
          else if (isOwn)
            Container(
              width: double.infinity,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
              ),
              child: Text(
                'Senin İlanın',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 28,
                    child: ElevatedButton(
                      onPressed: () => _showDirectBuyDialog(context, listing, isDark),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF263B66) : const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Satın Al', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: SizedBox(
                    height: 28,
                    child: ElevatedButton(
                      onPressed: () => _showMakeOfferDialog(context, listing, isDark),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF8B4513) : const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Teklif Ver', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip(int index, String label, int count, bool isDark, {bool isReserve = false}) {
    final isSelected = _communityCategoryFilter == index;
    final activeColor = isReserve
        ? (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E))
        : (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7));

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _communityCategoryFilter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(isDark ? 0.25 : 0.15)
              : (isDark ? const Color(0xFF1E283E) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : activeColor)
                    : (isDark ? Colors.grey[400] : const Color(0xFF475569)),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerActiveListingsList(bool isDark) {
    final currencyFmt = NumberFormat("#,##0.00", "tr_TR");
    final activeListings = widget.controller.activeListings;

    if (activeListings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_outlined, size: 44, color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                'Aktif Satış İlanınız Yok',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Borsa sekmesinden mallarınızı istediğiniz fiyattan ilana çıkarabilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      cacheExtent: 600,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      itemCount: activeListings.length,
      itemBuilder: (ctx, i) {
        final listing = activeListings[i];
        final progress = (listing.soldQuantity / listing.initialQuantity).clamp(0.0, 1.0);
        final pendingOffer = widget.controller.offers
            .where((o) => o.listingId == listing.id && o.direction == OfferDirection.incoming && o.status == OfferStatus.pending)
            .firstOrNull;

        return Card(
          color: isDark ? const Color(0xFF1B2234) : Colors.white,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(listing.item.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            listing.item.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'İlan Fiyatı: ${currencyFmt.format(listing.pricePerUnit)} ₺',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Kazanılan: +${currencyFmt.format(listing.totalEarned)} ₺',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.black38 : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? Colors.greenAccent : const Color(0xFF10B981),
                    ),
                  ),
                ),
                if (pendingOffer != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.amber.withOpacity(0.12) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? Colors.amber.withOpacity(0.25) : const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.mark_email_unread_outlined, size: 12, color: isDark ? Colors.amberAccent : const Color(0xFFD97706)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${pendingOffer.buyerName} teklif verdi (${pendingOffer.quantity} adet @ ${currencyFmt.format(pendingOffer.offeredPricePerUnit)} ₺) • Ürünler rezerve edilmez, açık pazarda liste fiyatından satışı devam eder',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.amberAccent : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Satılan: ${listing.soldQuantity} / ${listing.initialQuantity} adet',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[300] : const Color(0xFF475569)),
                    ),
                    InkWell(
                      onTap: () => _confirmCancelListing(context, listing, isDark),
                      child: Text(
                        'İptal Et & Depoya Al',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.redAccent : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 3: TEKLİFLER SAYFASI
  // ==========================================
  Widget _buildOffersParentView(bool isDark) {
    final c = widget.controller;
    final incomingOffers = c.offers.where((o) => o.direction == OfferDirection.incoming).toList();
    final outgoingOffers = c.offers.where((o) => o.direction == OfferDirection.outgoing).toList();

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161F33) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _offerSubTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                    decoration: BoxDecoration(
                      color: _offerSubTab == 0
                          ? (isDark ? const Color(0xFF243452) : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _offerSubTab == 0
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.call_received, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Gelen Teklifler (${incomingOffers.length})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _offerSubTab == 0 ? FontWeight.bold : FontWeight.w600,
                                color: _offerSubTab == 0
                                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                    : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                              ),
                            ),
                            if (c.pendingIncomingOffersCount > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  '${c.pendingIncomingOffersCount}',
                                  style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _offerSubTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                    decoration: BoxDecoration(
                      color: _offerSubTab == 1
                          ? (isDark ? const Color(0xFF243452) : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _offerSubTab == 1
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.call_made, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Verilen Teklifler (${outgoingOffers.length})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _offerSubTab == 1 ? FontWeight.bold : FontWeight.w600,
                                color: _offerSubTab == 1
                                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                    : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                              ),
                            ),
                            if (c.acceptedOutgoingOffersCount > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  '${c.acceptedOutgoingOffersCount}',
                                  style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _offerSubTab == 0
              ? _buildIncomingOffersList(incomingOffers, isDark)
              : _buildOutgoingOffersList(outgoingOffers, isDark),
        ),
      ],
    );
  }

  Widget _buildIncomingOffersList(List<MarketOffer> incomingOffers, bool isDark) {
    final currencyFmt = NumberFormat("#,##0.00", "tr_TR");

    if (incomingOffers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 40, color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8)),
              const SizedBox(height: 10),
              Text(
                'Henüz Gelen Teklif Yok',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                'Pazara kendi fiyatınızla ilan açtığınızda diğer oyuncular pazarlık teklifleri iletecektir.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      cacheExtent: 600,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      itemCount: incomingOffers.length,
      itemBuilder: (ctx, i) {
        final offer = incomingOffers[i];
        final isPending = offer.status == OfferStatus.pending;
        final isAccepted = offer.status == OfferStatus.accepted || offer.status == OfferStatus.completed;
        final isExpired = offer.status == OfferStatus.expired;

        return Card(
          color: isDark ? const Color(0xFF1B2234) : Colors.white,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isPending
                  ? Colors.amberAccent.withOpacity(0.5)
                  : (isAccepted
                      ? Colors.green.withOpacity(0.3)
                      : (isExpired ? Colors.teal.withOpacity(0.4) : Colors.red.withOpacity(0.2))),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(offer.item.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alıcı: ${offer.buyerName}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.lightBlueAccent : const Color(0xFF0284C7),
                            ),
                          ),
                          Text(
                            '${offer.quantity} adet ${offer.item.name}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${currencyFmt.format(offer.offeredPricePerUnit)} ₺ / adet',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                          ),
                        ),
                        Text(
                          'İlanınız: ${currencyFmt.format(offer.originalPricePerUnit)} ₺',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '💬 "${offer.message}" (Toplam: ${currencyFmt.format(offer.totalOfferedPrice)} ₺)',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (isPending) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blueGrey.withOpacity(0.18) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_open_outlined, size: 12, color: isDark ? Colors.tealAccent : const Color(0xFF0F766E)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Ürünler rezerve edilmez. Siz onaylamadan önce pazarda tam liste fiyatından satılırsa satışı engellenmez.',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            widget.controller.rejectIncomingOffer(offer);
                            GameToast.showInfo(context, 'Teklif reddedildi.', title: 'Teklif Reddedildi');
                          },
                          icon: const Icon(Icons.close, size: 14),
                          label: const Text('Reddet'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final err = widget.controller.acceptIncomingOffer(offer);
                            if (err != null) {
                              GameToast.showError(context, err, title: 'Teklif Onaylanamadı');
                            } else {
                              GameToast.showSuccess(
                                context,
                                'Teklif onaylandı! Alıcıya (${offer.buyerName}) bildirim iletildi.',
                                title: 'Teklif Onaylandı',
                              );
                            }
                          },
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text('Teklifi Kabul Et'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.greenAccent[700] : const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (isExpired) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.teal.withOpacity(0.15) : const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.tealAccent.withOpacity(0.3) : const Color(0xFF14B8A6)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified_outlined, size: 14, color: isDark ? Colors.tealAccent : const Color(0xFF0F766E)),
                            const SizedBox(width: 6),
                            Text(
                              '🏷️ Normal Fiyattan Başkasına Satıldı (Teklif Düştü)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.tealAccent : const Color(0xFF0F766E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ürünleriniz rezerve edilmediği için açık pazarda tam liste fiyatınızdan (${currencyFmt.format(offer.originalPricePerUnit)} ₺) müşterilere satıldı.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isAccepted ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      offer.status == OfferStatus.completed
                          ? '🤝 Satış Başarıyla Tamamlandı (+${currencyFmt.format(offer.totalOfferedPrice)} ₺)'
                          : (isAccepted
                              ? '✔️ Teklifi Onayladınız • Alıcının Satın Alması Bekleniyor'
                              : '❌ Reddedildi'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isAccepted ? Colors.green : Colors.redAccent,
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
  }

  Widget _buildOutgoingOffersList(List<MarketOffer> outgoingOffers, bool isDark) {
    final currencyFmt = NumberFormat("#,##0.00", "tr_TR");

    if (outgoingOffers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.outbox_outlined, size: 40, color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8)),
              const SizedBox(height: 10),
              Text(
                'Henüz Verdiğiniz Bir Teklif Yok',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                'Oyuncu Pazarı sekmesinden beğendiğiniz bir ilana "Teklif Ver" butonuyla pazarlık teklifi iletebilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      cacheExtent: 600,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      itemCount: outgoingOffers.length,
      itemBuilder: (ctx, i) {
        final offer = outgoingOffers[i];
        final isAccepted = offer.status == OfferStatus.accepted;
        final isPending = offer.status == OfferStatus.pending;
        final isCompleted = offer.status == OfferStatus.completed;
        final isRejected = offer.status == OfferStatus.rejected;
        final isExpired = offer.status == OfferStatus.expired;

        return Card(
          color: isDark ? const Color(0xFF1B2234) : Colors.white,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isAccepted
                  ? Colors.greenAccent
                  : (isPending
                      ? Colors.amberAccent.withOpacity(0.4)
                      : (isCompleted
                          ? Colors.blue.withOpacity(0.3)
                          : (isExpired ? Colors.teal.withOpacity(0.4) : Colors.red.withOpacity(0.3)))),
              width: isAccepted ? 1.6 : 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(offer.item.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Satıcı: ${offer.sellerName}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.lightBlueAccent : const Color(0xFF0284C7),
                            ),
                          ),
                          Text(
                            '${offer.quantity} adet ${offer.item.name}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${currencyFmt.format(offer.offeredPricePerUnit)} ₺ / adet',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                          ),
                        ),
                        Text(
                          'İlan Fiyatı: ${currencyFmt.format(offer.originalPricePerUnit)} ₺',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (isAccepted) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0E3A2F) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 16, color: Colors.green),
                            SizedBox(width: 6),
                            Text(
                              'TEKLİFİNİZ ONAYLANDI!',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Satıcı teklifinizi kabul etti. Toplam Tutar: ${currencyFmt.format(offer.totalOfferedPrice)} ₺',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : const Color(0xFF065F46),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final err = widget.controller.buyAcceptedOffer(offer);
                              if (err != null) {
                                GameToast.showError(context, err, title: 'Satın Alma Hatası');
                              } else {
                                GameToast.showSuccess(
                                  context,
                                  '${offer.quantity} adet ${offer.item.name} depoya alındı! (${currencyFmt.format(offer.totalOfferedPrice)} ₺ ödendi) 📦',
                                  title: 'Satın Alma Başarılı',
                                );
                              }
                            },
                            icon: const Icon(Icons.shopping_cart, size: 16),
                            label: Text(
                              'Onaylanan Fiyattan Satın Al (${currencyFmt.format(offer.totalOfferedPrice)} ₺)',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isPending) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? Colors.transparent : const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Satıcı (${offer.sellerName}) teklifinizi değerlendiriyor... Onaylandığında bildirim alacaksınız.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isCompleted) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blue.withOpacity(0.12) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '✔️ Satın Alındı (Deponuza Eklendi)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.lightBlueAccent : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ] else if (isExpired) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.teal.withOpacity(0.12) : const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '🏷️ İlandaki Ürünler Başkasına Satıldı (Teklif Kapandı)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.tealAccent : const Color(0xFF0F766E),
                      ),
                    ),
                  ),
                ] else if (isRejected) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '❌ Satıcı Teklifi Çok Düşük Buldu ve Reddetti',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // DİYALOGLAR (TEKLİF VERME, DOĞRUDAN SATIN ALMA, İLAN AÇMA)
  // ==========================================

  void _showMakeOfferDialog(BuildContext context, MarketListing listing, bool isDark) {
    int qty = min(10, listing.remainingQuantity);
    double offeredPrice = double.parse((listing.pricePerUnit * 0.90).toStringAsFixed(2));

    final qtyController = TextEditingController(text: qty.toString());
    final priceController = TextEditingController(text: offeredPrice.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final totalOffered = qty * offeredPrice;
            final originalTotal = qty * listing.pricePerUnit;
            final discountRatio = (listing.pricePerUnit - offeredPrice) / listing.pricePerUnit;

            String feedback;
            Color feedbackColor;
            if (offeredPrice >= listing.pricePerUnit * 0.88) {
              feedback = '👍 Satıcının kabul etme ihtimali çok yüksek!';
              feedbackColor = Colors.green;
            } else if (offeredPrice >= listing.pricePerUnit * 0.75) {
              feedback = '⚖️ Makul bir pazarlık. Satıcı düşünebilir.';
              feedbackColor = Colors.amber;
            } else {
              feedback = '⚠️ Çok düşük teklif! Satıcı doğrudan reddedebilir.';
              feedbackColor = Colors.redAccent;
            }

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF182032) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Text(listing.item.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Teklif Ver (Pazarlık)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Satıcı: ${listing.sellerName}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.lightBlueAccent : const Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'İlan Fiyatı:\n${listing.pricePerUnit.toStringAsFixed(2)} ₺ / adet',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                          ),
                          Text(
                            'Mevcut Stok:\n${listing.remainingQuantity} adet',
                            textAlign: TextAlign.end,
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.amberAccent : const Color(0xFFD97706)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Teklif Edilecek Miktar:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: qty > 1
                              ? () {
                                  final newQty = (qty - 5).clamp(1, listing.remainingQuantity);
                                  setModalState(() {
                                    qty = newQty;
                                    qtyController.text = newQty.toString();
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        SizedBox(
                          width: 140,
                          height: 44,
                          child: TextField(
                            controller: qtyController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              filled: true,
                              fillColor: isDark ? Colors.black38 : const Color(0xFFF1F5F9),
                              suffixText: 'Adet',
                              suffixStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                  width: 1.8,
                                ),
                              ),
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val.trim());
                              if (parsed != null) {
                                setModalState(() {
                                  qty = parsed.clamp(1, listing.remainingQuantity);
                                });
                              }
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: qty < listing.remainingQuantity
                              ? () {
                                  final newQty = (qty + 5).clamp(1, listing.remainingQuantity);
                                  setModalState(() {
                                    qty = newQty;
                                    qtyController.text = newQty.toString();
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Teklif Ettiğiniz Birim Fiyat (1 adet için):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: offeredPrice > 0.5
                              ? () {
                                  final newPrice = max(0.10, offeredPrice - 0.50);
                                  setModalState(() {
                                    offeredPrice = double.parse(newPrice.toStringAsFixed(2));
                                    priceController.text = offeredPrice.toStringAsFixed(2);
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        SizedBox(
                          width: 140,
                          height: 44,
                          child: TextField(
                            controller: priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              filled: true,
                              fillColor: isDark ? Colors.black38 : const Color(0xFFF1F5F9),
                              suffixText: '₺',
                              suffixStyle: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                                  width: 1.8,
                                ),
                              ),
                            ),
                            onChanged: (val) {
                              final clean = val.trim().replaceAll(',', '.');
                              final parsed = double.tryParse(clean);
                              if (parsed != null && parsed > 0) {
                                setModalState(() {
                                  offeredPrice = parsed;
                                });
                              }
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            final newPrice = offeredPrice + 0.50;
                            setModalState(() {
                              offeredPrice = double.parse(newPrice.toStringAsFixed(2));
                              priceController.text = offeredPrice.toStringAsFixed(2);
                            });
                          },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _quickQtyBtn(
                          setModalState,
                          () {
                            offeredPrice = double.parse((listing.pricePerUnit * 0.95).toStringAsFixed(2));
                            priceController.text = offeredPrice.toStringAsFixed(2);
                          },
                          '-%5',
                          isDark,
                        ),
                        const SizedBox(width: 6),
                        _quickQtyBtn(
                          setModalState,
                          () {
                            offeredPrice = double.parse((listing.pricePerUnit * 0.85).toStringAsFixed(2));
                            priceController.text = offeredPrice.toStringAsFixed(2);
                          },
                          '-%15',
                          isDark,
                        ),
                        const SizedBox(width: 6),
                        _quickQtyBtn(
                          setModalState,
                          () {
                            offeredPrice = double.parse((listing.pricePerUnit * 0.75).toStringAsFixed(2));
                            priceController.text = offeredPrice.toStringAsFixed(2);
                          },
                          '-%25',
                          isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: feedbackColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: feedbackColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        feedback,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: feedbackColor),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('Toplam Teklif Tutarı:', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF64748B))),
                        ),
                        Text(
                          '${totalOffered.toStringAsFixed(2)} ₺',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.greenAccent : const Color(0xFF059669)),
                        ),
                      ],
                    ),
                    Text(
                      'Normalde: ${originalTotal.toStringAsFixed(2)} ₺ (%${(discountRatio * 100).toInt()} tasarruf)',
                      style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : const Color(0xFF94A3B8)),
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
                    final typedQty = int.tryParse(qtyController.text.trim()) ?? qty;
                    final finalQty = typedQty.clamp(1, listing.remainingQuantity);
                    final typedPrice = double.tryParse(priceController.text.trim().replaceAll(',', '.')) ?? offeredPrice;
                    final finalPrice = max(0.01, typedPrice);

                    final err = widget.controller.makeOfferOnListing(listing, finalQty, finalPrice);
                    Navigator.pop(ctx);
                    if (err != null) {
                      GameToast.showError(context, err, title: 'Teklif Gönderilemedi');
                    } else {
                      setState(() {
                        _mainTab = 2;
                        _offerSubTab = 1;
                      });
                      GameToast.showSuccess(
                        context,
                        'Teklifiniz "${listing.sellerName}" satıcısına iletildi. Satıcı yanıtladığında bildirim alacaksınız.',
                        title: 'Teklif Gönderildi',
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF8B4513) : const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Teklifi Gönder'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDirectBuyDialog(BuildContext context, MarketListing listing, bool isDark) {
    int qty = min(10, listing.remainingQuantity);
    final qtyController = TextEditingController(text: qty.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final total = qty * listing.pricePerUnit;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF182032) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Text(listing.item.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${listing.item.name} Satın Al',
                      style: TextStyle(
                        fontSize: 16,
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
                    'Satıcı: ${listing.sellerName}',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.lightBlueAccent : const Color(0xFF0284C7)),
                  ),
                  Text(
                    'Birim Fiyat: ${listing.pricePerUnit.toStringAsFixed(2)} ₺ (Stok: ${listing.remainingQuantity} adet)',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: qty > 1
                            ? () {
                                final newQty = (qty - 5).clamp(1, listing.remainingQuantity);
                                setModalState(() {
                                  qty = newQty;
                                  qtyController.text = newQty.toString();
                                });
                              }
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      SizedBox(
                        width: 140,
                        height: 44,
                        child: TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            filled: true,
                            fillColor: isDark ? Colors.black38 : const Color(0xFFF1F5F9),
                            suffixText: 'Adet',
                            suffixStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                width: 1.8,
                              ),
                            ),
                          ),
                          onChanged: (val) {
                            final parsed = int.tryParse(val.trim());
                            if (parsed != null) {
                              setModalState(() {
                                qty = parsed.clamp(1, listing.remainingQuantity);
                              });
                            }
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: qty < listing.remainingQuantity
                            ? () {
                                final newQty = (qty + 5).clamp(1, listing.remainingQuantity);
                                setModalState(() {
                                  qty = newQty;
                                  qtyController.text = newQty.toString();
                                });
                              }
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _quickQtyBtn(setModalState, () {
                        final newQty = min(10, listing.remainingQuantity);
                        qty = newQty;
                        qtyController.text = newQty.toString();
                      }, '10', isDark),
                      const SizedBox(width: 4),
                      _quickQtyBtn(setModalState, () {
                        final newQty = min(50, listing.remainingQuantity);
                        qty = newQty;
                        qtyController.text = newQty.toString();
                      }, '50', isDark),
                      const SizedBox(width: 4),
                      _quickQtyBtn(setModalState, () {
                        qty = listing.remainingQuantity;
                        qtyController.text = listing.remainingQuantity.toString();
                      }, 'Tümü (${listing.remainingQuantity})', isDark),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Toplam Tutar:', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF64748B))),
                      Text(
                        '${total.toStringAsFixed(2)} ₺',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.lightBlueAccent : const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Vazgeç', style: TextStyle(color: isDark ? Colors.grey : const Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: () {
                    final typedQty = int.tryParse(qtyController.text.trim()) ?? qty;
                    final finalQty = typedQty.clamp(1, listing.remainingQuantity);

                    final err = widget.controller.buyFromCommunityListing(listing, finalQty);
                    Navigator.pop(ctx);
                    if (err != null) {
                      GameToast.showError(context, err, title: 'Satın Alma Hatası');
                    } else {
                      GameToast.showSuccess(
                        context,
                        '$finalQty adet ${listing.item.name} satın alındı ve depoya eklendi! 📦',
                        title: 'Satın Alma Başarılı',
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF263B66) : const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Satın Al'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateListingDialog(BuildContext context, MarketItem mItem, {required bool isDark}) {
    final inStock = widget.controller.warehouse[mItem.itemId] ?? 0;
    int qty = inStock >= 10 ? 10 : (inStock > 0 ? inStock : 1);
    double customPrice = mItem.currentPrice;

    final qtyController = TextEditingController(text: qty.toString());
    final priceController = TextEditingController(text: customPrice.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final double marketPrice = mItem.currentPrice;
            final double totalRevenue = qty * customPrice;
            final double quickSellTotal = qty * mItem.quickSellPrice;
            final double profitDifference = totalRevenue - quickSellTotal;

            String demandFeedback;
            Color demandColor;
            if (customPrice <= marketPrice * 0.95) {
              demandFeedback = '🔥 Piyasanın altında! Alıcılar çok hızlı kapışır.';
              demandColor = Colors.green;
            } else if (customPrice <= marketPrice * 1.05) {
              demandFeedback = '⚖️ Piyasa seviyesi. Normal hızda satılır.';
              demandColor = isDark ? Colors.lightBlueAccent : const Color(0xFF0284C7);
            } else if (customPrice <= marketPrice * 1.25) {
              demandFeedback = '📈 Kârlı Fiyat. Biraz daha sabır gerektirir.';
              demandColor = Colors.amber;
            } else {
              demandFeedback = '💰 Yüksek Fiyat! Satılması uzun sürebilir.';
              demandColor = Colors.orange;
            }

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF182032) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Text(mItem.data.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${mItem.data.name} Pazara Çıkar',
                      style: TextStyle(
                        fontSize: 16,
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
                      'İstediğiniz fiyatı belirleyin. Alıcılar fiyatınıza göre doğrudan alabilir veya teklif gönderebilir.',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Piyasa Göstergesi:\n${marketPrice.toStringAsFixed(2)} ₺ / adet',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Depondaki Stok:\n$inStock adet',
                              textAlign: TextAlign.end,
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.amberAccent : const Color(0xFFD97706)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Satışa Çıkarılacak Miktar:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: qty > 1
                              ? () {
                                  final newQty = (qty - 5).clamp(1, max(1, inStock)).toInt();
                                  setModalState(() {
                                    qty = newQty;
                                    qtyController.text = newQty.toString();
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        SizedBox(
                          width: 140,
                          height: 44,
                          child: TextField(
                            controller: qtyController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              filled: true,
                              fillColor: isDark ? Colors.black38 : const Color(0xFFF1F5F9),
                              suffixText: 'Adet',
                              suffixStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                  width: 1.8,
                                ),
                              ),
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val.trim());
                              if (parsed != null) {
                                setModalState(() {
                                  qty = parsed.clamp(1, max(1, inStock)).toInt();
                                });
                              }
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: qty < inStock
                              ? () {
                                  final newQty = (qty + 5).clamp(1, max(1, inStock)).toInt();
                                  setModalState(() {
                                    qty = newQty;
                                    qtyController.text = newQty.toString();
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _quickQtyBtn(setModalState, () {
                          final newQty = min(10, inStock);
                          qty = newQty;
                          qtyController.text = newQty.toString();
                        }, '10', isDark),
                        _quickQtyBtn(setModalState, () {
                          final newQty = min(50, inStock);
                          qty = newQty;
                          qtyController.text = newQty.toString();
                        }, '50', isDark),
                        _quickQtyBtn(setModalState, () {
                          qty = inStock;
                          qtyController.text = inStock.toString();
                        }, 'Tümü ($inStock)', isDark),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Birim Satış Fiyatınız (1 adet için):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: customPrice > 0.5
                              ? () {
                                  final newPrice = max(0.10, customPrice - 0.50);
                                  setModalState(() {
                                    customPrice = double.parse(newPrice.toStringAsFixed(2));
                                    priceController.text = customPrice.toStringAsFixed(2);
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        SizedBox(
                          width: 140,
                          height: 44,
                          child: TextField(
                            controller: priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              filled: true,
                              fillColor: isDark ? Colors.black38 : const Color(0xFFF1F5F9),
                              suffixText: '₺',
                              suffixStyle: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                                  width: 1.8,
                                ),
                              ),
                            ),
                            onChanged: (val) {
                              final clean = val.trim().replaceAll(',', '.');
                              final parsed = double.tryParse(clean);
                              if (parsed != null && parsed > 0) {
                                setModalState(() {
                                  customPrice = parsed;
                                });
                              }
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            final newPrice = customPrice + 0.50;
                            setModalState(() {
                              customPrice = double.parse(newPrice.toStringAsFixed(2));
                              priceController.text = customPrice.toStringAsFixed(2);
                            });
                          },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _quickQtyBtn(
                          setModalState,
                          () {
                            customPrice = double.parse((marketPrice * 0.90).toStringAsFixed(2));
                            priceController.text = customPrice.toStringAsFixed(2);
                          },
                          '-%10',
                          isDark,
                        ),
                        _quickQtyBtn(
                          setModalState,
                          () {
                            customPrice = marketPrice;
                            priceController.text = customPrice.toStringAsFixed(2);
                          },
                          'Borsa',
                          isDark,
                        ),
                        _quickQtyBtn(
                          setModalState,
                          () {
                            customPrice = double.parse((marketPrice * 1.20).toStringAsFixed(2));
                            priceController.text = customPrice.toStringAsFixed(2);
                          },
                          '+%20',
                          isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: demandColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: demandColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        demandFeedback,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: demandColor),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('Toplam Kazanç:', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF64748B))),
                        ),
                        Text(
                          '${totalRevenue.toStringAsFixed(2)} ₺',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.greenAccent : const Color(0xFF059669)),
                        ),
                      ],
                    ),
                    Text(
                      'Hızlı Satışa Göre: ${profitDifference >= 0 ? '+' : ''}${profitDifference.toStringAsFixed(2)} ₺ daha fazla',
                      style: TextStyle(
                        fontSize: 10,
                        color: profitDifference >= 0 ? (isDark ? Colors.tealAccent : const Color(0xFF0D9488)) : Colors.redAccent,
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
                    final typedQty = int.tryParse(qtyController.text.trim()) ?? qty;
                    final finalQty = inStock > 0 ? typedQty.clamp(1, inStock).toInt() : typedQty;
                    final typedPrice = double.tryParse(priceController.text.trim().replaceAll(',', '.')) ?? customPrice;
                    final finalPrice = max(0.01, typedPrice);

                    final err = widget.controller.createListing(mItem.itemId, finalQty, finalPrice);
                    Navigator.pop(ctx);
                    if (err != null) {
                      GameToast.showError(context, err, title: 'İlan Verilemedi');
                    } else {
                      setState(() {
                        _mainTab = 1;
                        _pazarSubTab = 1;
                      });
                      GameToast.showSuccess(
                        context,
                        '$finalQty adet ${mItem.data.name} ${finalPrice.toStringAsFixed(2)} ₺ fiyattan pazara çıkarıldı! 🏷️',
                        title: 'İlan Pazara Çıkarıldı',
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.greenAccent[700] : const Color(0xFF059669),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('İlanı Pazara Çıkar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmCancelListing(BuildContext context, MarketListing listing, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF182032) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('İlanı İptal Et?'),
        content: Text(
          'Satılmamış olan ${listing.remainingQuantity} adet ${listing.item.name} deponuza iade edilecektir.',
          style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final err = widget.controller.cancelListing(listing);
              if (err != null) {
                GameToast.showError(context, err, title: 'İptal Edilemedi');
              } else {
                GameToast.showInfo(
                  context,
                  '${listing.item.name} ilanı iptal edildi ve mallar depoya döndü.',
                  title: 'İlan İptal Edildi',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('İptal Et ve Depoya Al'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ÜRÜN DETAY & AL-SAT İŞLEMLERİ AYRI EKRANI (MODAL SHEET)
  // ==========================================
  void _showCommodityDetailSheet(BuildContext context, MarketItem mItem, {required bool isDark}) {
    final currencyFmt = NumberFormat("#,##0.00", "tr_TR");
    final inStock = widget.controller.warehouse[mItem.itemId] ?? 0;
    final isPositive = mItem.lastChangePercent >= 0;

    String categoryName;
    switch (mItem.data.category) {
      case ItemCategory.rawMaterial:
        categoryName = '🌾 Doğal Hammadde / Tarım';
        break;
      case ItemCategory.intermediate:
        categoryName = '🏭 Fabrika Ara Mamulü';
        break;
      case ItemCategory.finishedGood:
        categoryName = '🥖 Nihai Tüketici Ürünü';
        break;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141A29) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            18,
            12,
            18,
            MediaQuery.of(sheetCtx).padding.bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tutamaç (Drag Handle)
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Başlık: Emoji, İsim, Kategori & Kapat
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(mItem.data.emoji, style: const TextStyle(fontSize: 34)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                mItem.data.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: isPositive
                                      ? (isDark ? Colors.green.withOpacity(0.2) : const Color(0xFFDCFCE7))
                                      : (isDark ? Colors.red.withOpacity(0.2) : const Color(0xFFFEE2E8)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${isPositive ? '▲ +' : '▼ '}${mItem.lastChangePercent}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isPositive
                                        ? (isDark ? Colors.greenAccent : const Color(0xFF15803D))
                                        : (isDark ? Colors.redAccent : const Color(0xFFB91C1C)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            categoryName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetCtx),
                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Açıklama
                Text(
                  mItem.data.description,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),

                // Finansal Özet Kartı
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B243B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CANLI BORSA FİYATI',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${currencyFmt.format(mItem.currentPrice)} ₺',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.amberAccent : const Color(0xFF0F766E),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: inStock > 0
                                  ? (isDark ? Colors.amber.withOpacity(0.18) : const Color(0xFFFEF3C7))
                                  : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warehouse_outlined,
                                  size: 15,
                                  color: inStock > 0
                                      ? (isDark ? Colors.amberAccent : const Color(0xFFD97706))
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Deponda: $inStock adet',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: inStock > 0
                                        ? (isDark ? Colors.amberAccent : const Color(0xFF92400E))
                                        : (isDark ? Colors.grey : const Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), height: 1),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.arrow_downward, size: 13, color: Colors.blueAccent),
                              const SizedBox(width: 4),
                              Text(
                                'Taban: ${currencyFmt.format(mItem.data.minPrice)} ₺',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.arrow_upward, size: 13, color: Colors.orangeAccent),
                              const SizedBox(width: 4),
                              Text(
                                'Tavan: ${currencyFmt.format(mItem.data.maxPrice)} ₺',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Birim: ${mItem.data.weight} kg',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // İŞLEMLER BAŞLIĞI
                Text(
                  'YAPMAK İSTEDİĞİNİZ İŞLEMİ SEÇİN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),

                // 1. HIZLI AL
                _buildActionOptionTile(
                  icon: Icons.shopping_cart_checkout,
                  iconColor: Colors.lightBlueAccent,
                  title: 'Borsadan Hızlı Al (${currencyFmt.format(mItem.quickBuyPrice)} ₺)',
                  subtitle: 'Borsadan anında satın al ve doğrudan depona aktar.',
                  badge: 'Anında Alım',
                  badgeColor: const Color(0xFF0284C7),
                  isDark: isDark,
                  isEnabled: true,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showTradeDialog(context, mItem, isBuy: true, isDark: isDark);
                  },
                ),
                const SizedBox(height: 8),

                // 2. HIZLI SAT
                _buildActionOptionTile(
                  icon: Icons.bolt,
                  iconColor: Colors.amberAccent,
                  title: 'Borsaya Hızlı Sat (${currencyFmt.format(mItem.quickSellPrice)} ₺)',
                  subtitle: inStock > 0
                      ? 'Depondaki stokları anında sıcak nakde çevir (-%15 iskonto).'
                      : 'Bu işlem için deponuzda en az 1 adet ${mItem.data.name} olmalıdır.',
                  badge: 'Sıcak Nakit',
                  badgeColor: const Color(0xFFD97706),
                  isDark: isDark,
                  isEnabled: inStock > 0,
                  onTap: inStock > 0
                      ? () {
                          Navigator.pop(sheetCtx);
                          _showTradeDialog(context, mItem, isBuy: false, isDark: isDark);
                        }
                      : null,
                ),
                const SizedBox(height: 8),

                // 3. ALIŞ EMRİ VER
                _buildActionOptionTile(
                  icon: Icons.track_changes,
                  iconColor: Colors.blueAccent,
                  title: 'Otomatik Alış Emri Ver (Limit Order)',
                  subtitle: 'Fiyat hedeflediğin seviyeye inince sistem otomatik olarak satın alır.',
                  badge: 'Düşük Fiyat',
                  badgeColor: const Color(0xFF2563EB),
                  isDark: isDark,
                  isEnabled: true,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showLimitBuyOrderDialog(context, mItem, isDark: isDark);
                  },
                ),
                const SizedBox(height: 8),

                // 4. İLAN VER
                _buildActionOptionTile(
                  icon: Icons.sell_outlined,
                  iconColor: Colors.greenAccent,
                  title: 'Oyuncu Pazarına İlan Ver',
                  subtitle: inStock > 0
                      ? 'Kendi istediğin satış fiyatını belirleyip pazara sun, daha yüksek kâr elde et.'
                      : 'İlan verebilmek için deponuzda en az 1 adet ${mItem.data.name} olmalıdır.',
                  badge: 'Yüksek Kâr',
                  badgeColor: const Color(0xFF059669),
                  isDark: isDark,
                  isEnabled: inStock > 0,
                  onTap: inStock > 0
                      ? () {
                          Navigator.pop(sheetCtx);
                          _showCreateListingDialog(context, mItem, isDark: isDark);
                        }
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required bool isDark,
    required bool isEnabled,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isEnabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isEnabled
                ? (isDark ? const Color(0xFF1E283E) : Colors.white)
                : (isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEnabled
                  ? (isDark ? Colors.white12 : const Color(0xFFE2E8F0))
                  : (isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? (isDark ? iconColor.withOpacity(0.15) : badgeColor.withOpacity(0.1))
                      : (isDark ? Colors.white10 : Colors.grey[300]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isEnabled ? (isDark ? iconColor : badgeColor) : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isEnabled
                                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                  : (isDark ? Colors.grey[600] : const Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                        if (isEnabled) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(isDark ? 0.25 : 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isEnabled
                            ? (isDark ? Colors.grey[400] : const Color(0xFF64748B))
                            : (isDark ? Colors.grey[600] : const Color(0xFF94A3B8)),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: isEnabled
                    ? (isDark ? Colors.grey[400] : const Color(0xFF94A3B8))
                    : (isDark ? Colors.white24 : Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTradeDialog(BuildContext context, dynamic mItem, {required bool isBuy, required bool isDark}) {
    int qty = 10;
    final inStock = widget.controller.warehouse[mItem.itemId] ?? 0;
    final maxCanSell = inStock;
    final qtyController = TextEditingController(text: qty.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final unitPrice = isBuy ? mItem.quickBuyPrice : mItem.quickSellPrice;
            final total = unitPrice * qty;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF182032) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Text(mItem.data.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isBuy ? '${mItem.data.name} Hızlı Satın Al' : '${mItem.data.name} Hızlı Sat (Acil Nakit)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isBuy
                        ? 'Fabrikada işlemek veya dükkanında satmak için borsadan toptan çek.'
                        : 'Malınızı anında sisteme satıp sıcak nakite çevirin (%15 acil nakit iskontosu uygulanır).',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey : const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: qty > 1
                            ? () {
                                final newQty = (qty - 5).clamp(1, isBuy ? 10000 : max(1, maxCanSell)).toInt();
                                setDialogState(() {
                                  qty = newQty;
                                  qtyController.text = newQty.toString();
                                });
                              }
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      SizedBox(
                        width: 140,
                        height: 44,
                        child: TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.amber : const Color(0xFFD97706),
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            filled: true,
                            fillColor: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                            suffixText: 'Adet',
                            suffixStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.amber : const Color(0xFFD97706),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark ? Colors.amber : const Color(0xFFD97706),
                                width: 1.8,
                              ),
                            ),
                          ),
                          onChanged: (val) {
                            final parsed = int.tryParse(val.trim());
                            if (parsed != null) {
                              setDialogState(() {
                                qty = parsed.clamp(1, isBuy ? 10000 : max(1, maxCanSell)).toInt();
                              });
                            }
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: (!isBuy && qty >= maxCanSell)
                            ? null
                            : () {
                                final newQty = (qty + 5).clamp(1, isBuy ? 10000 : max(1, maxCanSell)).toInt();
                                setDialogState(() {
                                  qty = newQty;
                                  qtyController.text = newQty.toString();
                                });
                              },
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _quickQtyBtn(setDialogState, () {
                        final newQty = min(10, isBuy ? 10 : maxCanSell);
                        qty = newQty;
                        qtyController.text = newQty.toString();
                      }, '10', isDark),
                      const SizedBox(width: 4),
                      _quickQtyBtn(setDialogState, () {
                        final newQty = min(50, isBuy ? 50 : maxCanSell);
                        qty = newQty;
                        qtyController.text = newQty.toString();
                      }, '50', isDark),
                      const SizedBox(width: 4),
                      _quickQtyBtn(setDialogState, () {
                        final newQty = min(100, isBuy ? 100 : maxCanSell);
                        qty = newQty;
                        qtyController.text = newQty.toString();
                      }, '100', isDark),
                      if (!isBuy && maxCanSell > 0) ...[
                        const SizedBox(width: 4),
                        _quickQtyBtn(setDialogState, () {
                          qty = maxCanSell;
                          qtyController.text = maxCanSell.toString();
                        }, 'Tümü ($maxCanSell)', isDark),
                      ],
                    ],
                  ),
                  Divider(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0), height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isBuy ? 'Birim Alış Fiyatı:' : 'Birim Satış Fiyatı:',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                      ),
                      Text(
                        '${unitPrice.toStringAsFixed(2)} ₺ / adet',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Toplam Tutar:', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B))),
                      Text(
                        '${total.toStringAsFixed(2)} ₺',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isBuy
                              ? (isDark ? Colors.lightBlueAccent : const Color(0xFF0284C7))
                              : (isDark ? Colors.greenAccent : const Color(0xFF059669)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Vazgeç', style: TextStyle(color: isDark ? Colors.grey : const Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: () {
                    final typedQty = int.tryParse(qtyController.text.trim()) ?? qty;
                    final finalQty = typedQty.clamp(1, isBuy ? 10000 : max(1, maxCanSell)).toInt();

                    String? err;
                    if (isBuy) {
                      err = widget.controller.buyFromMarket(mItem.itemId, finalQty);
                    } else {
                      err = widget.controller.sellToMarket(mItem.itemId, finalQty);
                    }
                    Navigator.pop(ctx);
                    if (err != null) {
                      GameToast.showError(context, err, title: 'İşlem Başarısız');
                    } else {
                      GameToast.showSuccess(
                        context,
                        isBuy
                            ? '$finalQty adet ${mItem.data.name} depoya alındı! 📦'
                            : '$finalQty adet ${mItem.data.name} anında satıldı! (+${(unitPrice * finalQty).toStringAsFixed(0)} ₺) 💰',
                        title: isBuy ? 'Satın Alındı' : 'Hızlı Satış Yapıldı',
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBuy
                        ? (isDark ? Colors.blueAccent[700] : const Color(0xFF0284C7))
                        : (isDark ? Colors.orangeAccent[700] : const Color(0xFFD97706)),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isBuy ? 'Satın Al' : 'Hızlı Sat'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _quickQtyBtn(void Function(void Function()) setDialogState, VoidCallback onTap, String label, bool isDark) {
    return InkWell(
      onTap: () => setDialogState(onTap),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? Colors.transparent : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // BORSA ALT SEKME BUTONU
  // ==========================================
  Widget _buildBorsaSubTabButton({
    required String title,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2E3E60) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // LİMİT ALIŞ EMİRLERİ LİSTE GÖRÜNÜMÜ
  // ==========================================
  Widget _buildLimitOrdersView(bool isDark) {
    final currencyFmt = NumberFormat("#,##0.00", "tr_TR");
    final c = widget.controller;
    final pendingOrders = c.limitBuyOrders.where((o) => o.isPending).toList();
    final pastOrders = c.limitBuyOrders.where((o) => !o.isPending).toList();
    final totalReserved = pendingOrders.fold<double>(0.0, (acc, o) => acc + o.totalReservedCost);

    return ListView(
      physics: const BouncingScrollPhysics(),
      cacheExtent: 600,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: [
        // 1. Bilgi & Özet Bannerı
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.blueAccent.withOpacity(0.3) : const Color(0xFFBFDBFE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.track_changes, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Otomatik Limit Alış Emirleri',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${pendingOrders.length} Aktif Emir',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Borsa fiyatları her 15 saniyede bir güncellenir. Fiyat belirlediğiniz hedef seviyeye düştüğünde sistem otomatik satın alır.',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
              if (totalReserved > 0) ...[
                const SizedBox(height: 8),
                Divider(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1), height: 1),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Emirler İçin Bloke Edilen Nakit:', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
                    Text(
                      '${currencyFmt.format(totalReserved)} ₺',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Aktif Emirler Başlığı
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Bekleyen Emirler (${pendingOrders.length})',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _borsaSubTab = 0),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('+ Yeni Emir Ver', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Aktif Emirler Listesi
        if (pendingOrders.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161F30) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text(
                  'Bekleyen alış emriniz bulunmuyor',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Canlı Borsa sekmesinden istediğiniz ürünün altına inerek "🎯 Alış Emri Ver" butonuna tıklayabilirsiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey : const Color(0xFF64748B)),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _borsaSubTab = 0),
                  icon: const Icon(Icons.storefront, size: 15),
                  label: const Text('Borsayı İncele'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
          )
        else
          ...pendingOrders.map((order) {
            final mItem = c.marketItems[order.itemId];
            final currentPrice = mItem?.currentPrice ?? order.item.basePrice;
            final diff = currentPrice - order.targetPrice;
            final diffPct = (diff / currentPrice * 100).clamp(0.0, 100.0);
            final isReady = currentPrice <= order.targetPrice;

            return Card(
              color: isDark ? const Color(0xFF1E283E) : Colors.white,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isReady
                      ? Colors.greenAccent
                      : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                  width: isReady ? 1.5 : 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(order.item.emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.item.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Sipariş: ${order.quantity} Adet • Teminat: ${currencyFmt.format(order.totalReservedCost)} ₺',
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        // İptal Butonu
                        OutlinedButton.icon(
                          onPressed: () {
                            c.cancelLimitBuyOrder(order);
                            GameToast.showInfo(
                              context,
                              '${order.item.name} alış emri iptal edildi, ${currencyFmt.format(order.totalReservedCost)} ₺ iade edildi.',
                              title: 'Emir İptal Edildi',
                            );
                          },
                          icon: const Icon(Icons.cancel_outlined, size: 14),
                          label: const Text('İptal Et'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Fiyat Karşılaştırma Kutusu
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('🎯 Hedef: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              Text(
                                '${order.targetPrice.toStringAsFixed(2)} ₺',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Text('📉 Anlık: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              Text(
                                '${currentPrice.toStringAsFixed(2)} ₺',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          isReady ? Icons.check_circle : Icons.hourglass_top,
                          size: 13,
                          color: isReady ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            isReady
                                ? 'Hedef seviyeye ulaşıldı! Bir sonraki borsa döngüsünde satın alınacak.'
                                : 'Fiyat %${diffPct.toStringAsFixed(1)} (${diff.toStringAsFixed(2)} ₺) daha düşerse otomatik alınacak.',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isReady ? Colors.greenAccent : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),

        // 3. Geçmiş / Tamamlanan Emirler
        if (pastOrders.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Geçmiş Emirler (${pastOrders.length})',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
          const SizedBox(height: 6),
          ...pastOrders.take(6).map((order) {
            final isDone = order.isCompleted;

            return Card(
              color: isDark ? const Color(0xFF161F30) : const Color(0xFFF8FAFC),
              margin: const EdgeInsets.only(bottom: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                dense: true,
                leading: Text(order.item.emoji, style: const TextStyle(fontSize: 20)),
                title: Text(
                  '${order.quantity} Adet ${order.item.name}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  order.statusMessage ?? (isDone ? 'Otomatik satın alındı' : 'İptal edildi'),
                  style: TextStyle(fontSize: 10, color: isDone ? Colors.green : Colors.grey),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDone ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isDone ? 'Tamamlandı' : 'İptal',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDone ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  // ==========================================
  // ALIŞ EMRİ VERME DİYALOĞU
  // ==========================================
  void _showLimitBuyOrderDialog(BuildContext context, dynamic mItem, {required bool isDark}) {
    final currencyFmt = NumberFormat("#,##0.00", "tr_TR");
    final currentPrice = mItem.currentPrice;

    // Varsayılan hedef fiyat: %10 altında
    double targetPrice = double.parse((currentPrice * 0.90).toStringAsFixed(2));
    int quantity = 25;

    final targetPriceController = TextEditingController(text: targetPrice.toStringAsFixed(2));
    final quantityController = TextEditingController(text: quantity.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final totalCost = targetPrice * quantity;
            final canAfford = widget.controller.cash >= totalCost;
            final itemData = mItem.data;
            final weightNeeded = quantity * itemData.weight;
            final fitsInWarehouse = widget.controller.currentWarehouseWeight + weightNeeded <= widget.controller.maxWarehouseCapacity;
            final potentialSaving = targetPrice < currentPrice ? (currentPrice - targetPrice) * quantity : 0.0;
            final discountPct = targetPrice < currentPrice
                ? ((currentPrice - targetPrice) / currentPrice * 100).clamp(0.0, 100.0)
                : 0.0;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF141A29) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blueAccent.withOpacity(0.2) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(itemData.emoji, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${itemData.name} Alış Emri',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Fiyat düşünce veya uygun pazar ilanında sistem otomatik alır',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Anlık Fiyat Şeridi
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E283E) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Anlık Borsa Fiyatı:', style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
                                Text(
                                  '${currencyFmt.format(currentPrice)} ₺',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Tarihsel Dip / Zirve:', style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
                                Text(
                                  '${mItem.data.minPrice.toStringAsFixed(0)} ₺ - ${mItem.data.maxPrice.toStringAsFixed(0)} ₺',
                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // HEDEF ALIŞ FİYATI
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Hedef Alış Fiyatı (₺):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF334155))),
                          if (targetPrice < currentPrice)
                            Text(
                              '%${discountPct.toStringAsFixed(1)} daha ucuz',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                            )
                          else if (targetPrice == currentPrice)
                            const Text(
                              '⚡ Anlık Borsa Seviyesi (Hemen Alınır)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                            )
                          else
                            const Text(
                              '⚡ Piyasa Üstü (Hemen Alınır)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Text('₺', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: targetPriceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                                onChanged: (val) {
                                  final p = double.tryParse(val.replaceAll(',', '.')) ?? targetPrice;
                                  setDialogState(() => targetPrice = p);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // İndirim Yüzdesi Kısayol Butonları
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPresetDiscountChip('Anlık Fiyat', currentPrice, targetPriceController, (val) => setDialogState(() => targetPrice = val), isDark),
                            const SizedBox(width: 6),
                            _buildPresetDiscountChip('-%5', currentPrice * 0.95, targetPriceController, (val) => setDialogState(() => targetPrice = val), isDark),
                            const SizedBox(width: 6),
                            _buildPresetDiscountChip('-%10', currentPrice * 0.90, targetPriceController, (val) => setDialogState(() => targetPrice = val), isDark),
                            const SizedBox(width: 6),
                            _buildPresetDiscountChip('-%15', currentPrice * 0.85, targetPriceController, (val) => setDialogState(() => targetPrice = val), isDark),
                            const SizedBox(width: 6),
                            _buildPresetDiscountChip('-%20', currentPrice * 0.80, targetPriceController, (val) => setDialogState(() => targetPrice = val), isDark),
                            const SizedBox(width: 6),
                            _buildPresetDiscountChip('Taban Fiyat', mItem.data.minPrice, targetPriceController, (val) => setDialogState(() => targetPrice = val), isDark),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ALINACAK MİKTAR
                      Text('Alınacak Miktar (Adet):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF334155))),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.blueAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: quantityController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                                onChanged: (val) {
                                  final q = int.tryParse(val) ?? quantity;
                                  setDialogState(() => quantity = q);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Miktar Kısayolları
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPresetQtyChip('10', 10, quantityController, (val) => setDialogState(() => quantity = val), isDark),
                            const SizedBox(width: 6),
                            _buildPresetQtyChip('25', 25, quantityController, (val) => setDialogState(() => quantity = val), isDark),
                            const SizedBox(width: 6),
                            _buildPresetQtyChip('50', 50, quantityController, (val) => setDialogState(() => quantity = val), isDark),
                            const SizedBox(width: 6),
                            _buildPresetQtyChip('100', 100, quantityController, (val) => setDialogState(() => quantity = val), isDark),
                            const SizedBox(width: 6),
                            _buildPresetQtyChip('250', 250, quantityController, (val) => setDialogState(() => quantity = val), isDark),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // SİPARİŞ & BLOKE ÖZETİ
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1B2234) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? Colors.blueAccent.withOpacity(0.3) : const Color(0xFFBFDBFE)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Bloke Edilecek Teminat:', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[300] : const Color(0xFF475569))),
                                Text(
                                  '${currencyFmt.format(totalCost)} ₺',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: canAfford ? (isDark ? Colors.amberAccent : const Color(0xFFD97706)) : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Kasadaki Nakdiniz:', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
                                Text('${currencyFmt.format(widget.controller.cash)} ₺', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (targetPrice < currentPrice) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Tahmini Tasarruf:', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
                                  Text('+${currencyFmt.format(potentialSaving)} ₺ kâr', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ] else ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('İcra Durumu:', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
                                  Text('Anında Eşleşme (Hemen Alınır)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.greenAccent : const Color(0xFF059669))),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Depoda Gereken Alan:', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
                                Text(
                                  '${weightNeeded.toStringAsFixed(1)} kg ${fitsInWarehouse ? "(Yeterli Alan Var)" : "(Depo Yetersiz!)"}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: fitsInWarehouse ? (isDark ? Colors.white70 : const Color(0xFF475569)) : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Vazgeç'),
                ),
                ElevatedButton.icon(
                  onPressed: canAfford && fitsInWarehouse && targetPrice > 0 && quantity > 0
                      ? () {
                          final err = widget.controller.placeLimitBuyOrder(
                            itemId: mItem.itemId,
                            targetPrice: targetPrice,
                            quantity: quantity,
                          );
                          Navigator.pop(ctx);
                          if (err != null) {
                            GameToast.showError(context, err, title: 'Emir Verilemedi');
                          } else {
                            final matchingOrder = widget.controller.limitBuyOrders.isNotEmpty
                                ? widget.controller.limitBuyOrders.first
                                : null;
                            final wasInstant = matchingOrder != null && matchingOrder.isCompleted;

                            GameToast.showSuccess(
                              context,
                              wasInstant
                                  ? '$quantity adet ${itemData.name} için emir verildi ve hemen satın alındı! 🎯'
                                  : '$quantity adet ${itemData.name} için ${targetPrice.toStringAsFixed(2)} ₺ alış emri verildi! 🎯',
                              title: wasInstant ? 'Alış Gerçekleşti' : 'Alış Emri Açıldı',
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Alış Emrini Oluştur'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPresetDiscountChip(
    String label,
    double price,
    TextEditingController controller,
    Function(double) onSelected,
    bool isDark,
  ) {
    return InkWell(
      onTap: () {
        final formatted = double.parse(price.toStringAsFixed(2));
        controller.text = formatted.toStringAsFixed(2);
        onSelected(formatted);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E283E) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.greenAccent : const Color(0xFF059669),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetQtyChip(
    String label,
    int qty,
    TextEditingController controller,
    Function(int) onSelected,
    bool isDark,
  ) {
    return InkWell(
      onTap: () {
        controller.text = qty.toString();
        onSelected(qty);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E283E) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          '$label Adet',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
          ),
        ),
      ),
    );
  }
}

