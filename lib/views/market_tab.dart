import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import '../models/item.dart';
import '../models/market_item.dart';
import '../models/market_listing.dart';
import '../models/market_offer.dart';

class MarketTab extends StatefulWidget {
  final GameController controller;

  const MarketTab({super.key, required this.controller});

  @override
  State<MarketTab> createState() => _MarketTabState();
}

class _MarketTabState extends State<MarketTab> {
  int _mainTab = 0; // 0: Borsa & Toptan, 1: Oyuncu Pazarı, 2: Teklifler
  int _pazarSubTab = 0; // 0: Topluluk İlanları, 1: Benim İlanlarım
  int _offerSubTab = 0; // 0: Gelen Teklifler, 1: Verilen Teklifler
  ItemCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = widget.controller;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // === 1. ÜST ANA SEKMELER (BORSA / OYUNCU PAZARI / TEKLİFLER) ===
          Container(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E283E) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildTopTabItem(
                  index: 0,
                  label: 'Borsa',
                  icon: Icons.candlestick_chart_outlined,
                  badgeCount: 0,
                  isDark: isDark,
                ),
                const SizedBox(width: 4),
                _buildTopTabItem(
                  index: 1,
                  label: 'Oyuncu Pazarı',
                  icon: Icons.storefront_outlined,
                  badgeCount: c.communityListings.length,
                  isDark: isDark,
                ),
                const SizedBox(width: 4),
                _buildTopTabItem(
                  index: 2,
                  label: 'Teklifler',
                  icon: Icons.local_offer_outlined,
                  badgeCount: c.totalActiveOffersBadge,
                  isDark: isDark,
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
  }

  Widget _buildTopTabItem({
    required int index,
    required String label,
    required IconData icon,
    required int badgeCount,
    required bool isDark,
    bool isAlert = false,
  }) {
    final isSelected = _mainTab == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _mainTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? const Color(0xFF2E3E60) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? (isDark ? Colors.amberAccent : const Color(0xFF0F766E))
                    : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isAlert ? Colors.redAccent : (isDark ? Colors.teal[700] : const Color(0xFF0D9488)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
    final currencyFmt = NumberFormat("#,##0.00", "tr_TR");

    final items = widget.controller.marketItems.values.where((m) {
      if (_selectedCategory == null) return true;
      return m.data.category == _selectedCategory;
    }).toList();

    return Column(
      children: [
        // Kategori Filtre Butonları
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Tüm Borsa', null, isDark),
                const SizedBox(width: 6),
                _buildFilterChip('🌾 Tarlalar (Hammadde)', ItemCategory.rawMaterial, isDark),
                const SizedBox(width: 6),
                _buildFilterChip('🏭 Fabrika (Ara Mamul)', ItemCategory.intermediate, isDark),
                const SizedBox(width: 6),
                _buildFilterChip('🥖 Perakende Mamuller', ItemCategory.finishedGood, isDark),
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
                  '⚡ Hızlı Sat: Anında %15 iskonto ile sıcak nakit al. 🏷️ İlan Ver: Kendi fiyatını belirle ve pazara çıkar.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : const Color(0xFF1E40AF),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Emtia Listesi
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final mItem = items[i];
              final inStock = widget.controller.warehouse[mItem.itemId] ?? 0;
              final isPositive = mItem.lastChangePercent >= 0;

              return Card(
                color: isDark ? const Color(0xFF1B2234) : Colors.white,
                margin: const EdgeInsets.only(bottom: 10),
                elevation: isDark ? 2 : 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isPositive
                        ? (isDark ? Colors.green.withOpacity(0.2) : const Color(0xFF10B981).withOpacity(0.3))
                        : (isDark ? Colors.red.withOpacity(0.2) : const Color(0xFFEF4444).withOpacity(0.3)),
                    width: 1.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
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
                      Divider(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0), height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Borsa Gösterge',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                '${currencyFmt.format(mItem.currentPrice)} ₺',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hızlı Satış (-%15)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.orangeAccent : const Color(0xFFD97706),
                                ),
                              ),
                              Text(
                                '${currencyFmt.format(mItem.quickSellPrice)} ₺',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.orangeAccent : const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: inStock > 0
                                  ? (isDark ? Colors.amber.withOpacity(0.15) : const Color(0xFFFEF3C7))
                                  : (isDark ? Colors.black26 : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
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
                                    fontSize: 11,
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
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showTradeDialog(context, mItem, isBuy: true, isDark: isDark),
                              icon: const Icon(Icons.shopping_cart_checkout, size: 14),
                              label: Text('Hızlı Al (${mItem.quickBuyPrice} ₺)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF263B66) : const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: inStock > 0
                                  ? () => _showTradeDialog(context, mItem, isBuy: false, isDark: isDark)
                                  : null,
                              icon: const Icon(Icons.bolt, size: 14),
                              label: Text('Hızlı Sat (${mItem.quickSellPrice} ₺)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: inStock > 0
                                    ? (isDark ? const Color(0xFF8B4513) : const Color(0xFFD97706))
                                    : (isDark ? Colors.grey[800] : const Color(0xFFCBD5E1)),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: inStock > 0
                              ? () => _showCreateListingDialog(context, mItem, isDark: isDark)
                              : null,
                          icon: const Icon(Icons.sell_outlined, size: 15),
                          label: Text(
                            inStock > 0
                                ? '🏷️ Kendi Fiyatınla İlan Ver (Daha Yüksek Kâr)'
                                : '🏷️ İlan Ver (Deponda Stok Yok)',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: inStock > 0
                                ? (isDark ? const Color(0xFF0F766E) : const Color(0xFF059669))
                                : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                            foregroundColor: inStock > 0
                                ? Colors.white
                                : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
    );
  }

  // ==========================================
  // TAB 2: OYUNCU PAZARI (DİĞER OYUNCULAR & BENİM İLANLARIM)
  // ==========================================
  Widget _buildCommunityMarketParentView(bool isDark) {
    return Column(
      children: [
        // Alt Sekme Seçici: Topluluk İlanları vs Benim İlanlarım
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
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: _pazarSubTab == 0
                          ? (isDark ? const Color(0xFF243452) : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Diğer Oyuncuların İlanları (${widget.controller.communityListings.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _pazarSubTab == 0 ? FontWeight.bold : FontWeight.normal,
                          color: _pazarSubTab == 0
                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                              : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _pazarSubTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: _pazarSubTab == 1
                          ? (isDark ? const Color(0xFF243452) : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Benim Satış İlanlarım (${widget.controller.activeListings.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _pazarSubTab == 1 ? FontWeight.bold : FontWeight.normal,
                          color: _pazarSubTab == 1
                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                              : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
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

  // Diğer Oyuncuların İlanları Listesi
  Widget _buildCommunityListingsList(bool isDark) {
    final currencyFmt = NumberFormat("#,##0.00", "tr_TR");
    final listings = widget.controller.communityListings;

    if (listings.isEmpty) {
      return Center(
        child: Text(
          'Şu anda pazarda aktif ilan yok.',
          style: TextStyle(color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      itemCount: listings.length,
      itemBuilder: (ctx, i) {
        final listing = listings[i];
        final mItem = widget.controller.marketItems[listing.itemId];
        final marketPrice = mItem?.currentPrice ?? listing.pricePerUnit;
        final isDiscounted = listing.pricePerUnit < marketPrice;

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
                // Satıcı ve Ürün
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(listing.item.emoji, style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person_outline, size: 14, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  listing.sellerName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.lightBlueAccent : const Color(0xFF0284C7),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            listing.item.name,
                            style: TextStyle(
                              fontSize: 15,
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
                          '${currencyFmt.format(listing.pricePerUnit)} ₺',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                          ),
                        ),
                        Text(
                          isDiscounted ? '🔥 Piyasa Altı' : 'Borsa: ${currencyFmt.format(marketPrice)} ₺',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isDiscounted ? FontWeight.bold : FontWeight.normal,
                            color: isDiscounted ? Colors.green : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Mevcut Miktar & Aksiyon Butonları
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Kalan: ${listing.remainingQuantity} adet',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Doğrudan Satın Al Butonu
                    ElevatedButton.icon(
                      onPressed: () => _showDirectBuyDialog(context, listing, isDark),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 14),
                      label: const Text('Satın Al'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF263B66) : const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Teklif Ver (Pazarlık) Butonu
                    ElevatedButton.icon(
                      onPressed: () => _showMakeOfferDialog(context, listing, isDark),
                      icon: const Icon(Icons.question_answer_outlined, size: 14),
                      label: const Text('Teklif Ver'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF8B4513) : const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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

  // Oyuncunun Kendi Satış İlanları Listesi
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      itemCount: activeListings.length,
      itemBuilder: (ctx, i) {
        final listing = activeListings[i];
        final progress = (listing.soldQuantity / listing.initialQuantity).clamp(0.0, 1.0);

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
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
  // TAB 3: TEKLİFLER SAYFASI (GELEN VE VERİLEN TEKLİFLER)
  // ==========================================
  Widget _buildOffersParentView(bool isDark) {
    final c = widget.controller;
    final incomingOffers = c.offers.where((o) => o.direction == OfferDirection.incoming).toList();
    final outgoingOffers = c.offers.where((o) => o.direction == OfferDirection.outgoing).toList();

    return Column(
      children: [
        // Gelen vs Verilen Teklifler Sekme Başlığı
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
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: _offerSubTab == 0
                          ? (isDark ? const Color(0xFF243452) : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.call_received, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Gelen Teklifler (${incomingOffers.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _offerSubTab == 0 ? FontWeight.bold : FontWeight.normal,
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
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _offerSubTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: _offerSubTab == 1
                          ? (isDark ? const Color(0xFF243452) : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.call_made, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Verilen Teklifler (${outgoingOffers.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _offerSubTab == 1 ? FontWeight.bold : FontWeight.normal,
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

  // 1. GELEN TEKLİFLER LİSTESİ (Diğer oyuncular bizim ilana teklif vermiş)
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      itemCount: incomingOffers.length,
      itemBuilder: (ctx, i) {
        final offer = incomingOffers[i];
        final isPending = offer.status == OfferStatus.pending;
        final isAccepted = offer.status == OfferStatus.accepted || offer.status == OfferStatus.completed;

        return Card(
          color: isDark ? const Color(0xFF1B2234) : Colors.white,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isPending
                  ? Colors.amberAccent.withOpacity(0.5)
                  : (isAccepted ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.2)),
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

                // Alıcı Notu
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

                // Butonlar
                if (isPending) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            widget.controller.rejectIncomingOffer(offer);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Teklif reddedildi.')),
                            );
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(err), backgroundColor: Colors.red[800]),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Teklif onaylandı! +${currencyFmt.format(offer.totalOfferedPrice)} ₺ kasaya eklendi.',
                                  ),
                                  backgroundColor: Colors.green[800],
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text('Onayla & Sat'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.greenAccent[700] : const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
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
                      isAccepted ? '✔️ Satış Onaylandı & Tamamlandı' : '❌ Reddedildi',
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

  // 2. VERİLEN TEKLİFLER LİSTESİ (Bizim diğer satıcılara verdiğimiz teklifler)
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      itemCount: outgoingOffers.length,
      itemBuilder: (ctx, i) {
        final offer = outgoingOffers[i];
        final isAccepted = offer.status == OfferStatus.accepted;
        final isPending = offer.status == OfferStatus.pending;
        final isCompleted = offer.status == OfferStatus.completed;
        final isRejected = offer.status == OfferStatus.rejected;

        return Card(
          color: isDark ? const Color(0xFF1B2234) : Colors.white,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isAccepted
                  ? Colors.greenAccent
                  : (isPending ? Colors.amberAccent.withOpacity(0.4) : (isCompleted ? Colors.blue.withOpacity(0.3) : Colors.red.withOpacity(0.3))),
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

                // DURUM VE SATIN ALMA AKSİYONU
                if (isAccepted) ...[
                  // ÖZEL ONAYLANDI BANNERI & SATIN AL BUTONU
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(err), backgroundColor: Colors.red[800]),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${offer.quantity} adet ${offer.item.name} depoya alındı! (${currencyFmt.format(offer.totalOfferedPrice)} ₺ ödendi)',
                                    ),
                                    backgroundColor: Colors.green[800],
                                  ),
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
                          'Satıcı teklifinizi değerlendiriyor...',
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

  // Diğer Oyuncunun İlanına Teklif Verme Dialogu
  void _showMakeOfferDialog(BuildContext context, MarketListing listing, bool isDark) {
    int qty = min(10, listing.remainingQuantity);
    double offeredPrice = double.parse((listing.pricePerUnit * 0.90).toStringAsFixed(2)); // Varsayılan %10 indirimli teklif

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

                    // Miktar Seçimi
                    Text(
                      'Teklif Edilecek Miktar:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: qty > 1 ? () => setModalState(() => qty = (qty - 5).clamp(1, listing.remainingQuantity)) : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black38 : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$qty Adet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: qty < listing.remainingQuantity
                              ? () => setModalState(() => qty = (qty + 5).clamp(1, listing.remainingQuantity))
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Birim Fiyat Teklifi
                    Text(
                      'Teklif Ettiğiniz Birim Fiyat (1 adet için):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: offeredPrice > 0.5 ? () => setModalState(() => offeredPrice = max(0.5, offeredPrice - 0.50)) : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black38 : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${offeredPrice.toStringAsFixed(2)} ₺',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setModalState(() => offeredPrice += 0.50),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Hızlı Teklif Şablonları
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _quickQtyBtn(
                          setModalState,
                          () => offeredPrice = double.parse((listing.pricePerUnit * 0.95).toStringAsFixed(2)),
                          '-%5',
                          isDark,
                        ),
                        const SizedBox(width: 6),
                        _quickQtyBtn(
                          setModalState,
                          () => offeredPrice = double.parse((listing.pricePerUnit * 0.85).toStringAsFixed(2)),
                          '-%15',
                          isDark,
                        ),
                        const SizedBox(width: 6),
                        _quickQtyBtn(
                          setModalState,
                          () => offeredPrice = double.parse((listing.pricePerUnit * 0.75).toStringAsFixed(2)),
                          '-%25',
                          isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Geri Bildirim Kutusu
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

                    // Hesap Özeti
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Toplam Teklif Tutarı:', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF64748B))),
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
                    final err = widget.controller.makeOfferOnListing(listing, qty, offeredPrice);
                    Navigator.pop(ctx);
                    if (err != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err), backgroundColor: Colors.red[800]),
                      );
                    } else {
                      setState(() {
                        _mainTab = 2; // Teklifler sekmesine geç
                        _offerSubTab = 1; // Verilen teklifler
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Teklifiniz "${listing.sellerName}" satıcısına iletildi. Birkaç saniye içinde yanıt gelecektir.',
                          ),
                          backgroundColor: Colors.blueGrey[800],
                        ),
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

  // Diğer Oyuncunun İlanından Doğrudan Satın Alma Dialogu
  void _showDirectBuyDialog(BuildContext context, MarketListing listing, bool isDark) {
    int qty = min(10, listing.remainingQuantity);

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
                        onPressed: qty > 1 ? () => setModalState(() => qty = (qty - 5).clamp(1, listing.remainingQuantity)) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black38 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$qty Adet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: qty < listing.remainingQuantity
                            ? () => setModalState(() => qty = (qty + 5).clamp(1, listing.remainingQuantity))
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
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
                    final err = widget.controller.buyFromCommunityListing(listing, qty);
                    Navigator.pop(ctx);
                    if (err != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err), backgroundColor: Colors.red[800]),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$qty adet ${listing.item.name} satın alındı ve depoya eklendi!'),
                          backgroundColor: Colors.green[800],
                        ),
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

  // Kendi Fiyatınla İlan Açma Dialogu
  void _showCreateListingDialog(BuildContext context, MarketItem mItem, {required bool isDark}) {
    final inStock = widget.controller.warehouse[mItem.itemId] ?? 0;
    int qty = inStock >= 10 ? 10 : inStock;
    double customPrice = mItem.currentPrice;

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
                          Text(
                            'Piyasa Göstergesi:\n${marketPrice.toStringAsFixed(2)} ₺ / adet',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                          ),
                          Text(
                            'Depondaki Stok:\n$inStock adet',
                            textAlign: TextAlign.end,
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.amberAccent : const Color(0xFFD97706)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Miktar Seçimi
                    Text(
                      'Satışa Çıkarılacak Miktar:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: qty > 1 ? () => setModalState(() => qty = (qty - 5).clamp(1, inStock)) : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black38 : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$qty Adet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: qty < inStock ? () => setModalState(() => qty = (qty + 5).clamp(1, inStock)) : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _quickQtyBtn(setModalState, () => qty = min(10, inStock), '10', isDark),
                        const SizedBox(width: 4),
                        _quickQtyBtn(setModalState, () => qty = min(50, inStock), '50', isDark),
                        const SizedBox(width: 4),
                        _quickQtyBtn(setModalState, () => qty = inStock, 'Tümü ($inStock)', isDark),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Fiyat Seçimi
                    Text(
                      'Birim Satış Fiyatınız (1 adet için):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: customPrice > 0.5 ? () => setModalState(() => customPrice = max(0.5, customPrice - 0.50)) : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black38 : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${customPrice.toStringAsFixed(2)} ₺',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setModalState(() => customPrice += 0.50),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _quickQtyBtn(
                          setModalState,
                          () => customPrice = double.parse((marketPrice * 0.90).toStringAsFixed(2)),
                          '-%10',
                          isDark,
                        ),
                        const SizedBox(width: 6),
                        _quickQtyBtn(
                          setModalState,
                          () => customPrice = marketPrice,
                          'Borsa',
                          isDark,
                        ),
                        const SizedBox(width: 6),
                        _quickQtyBtn(
                          setModalState,
                          () => customPrice = double.parse((marketPrice * 1.20).toStringAsFixed(2)),
                          '+%20',
                          isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Alıcı Talebi Geri Bildirimi
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

                    // Kazanç Karşılaştırması
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Toplam Kazanç:', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF64748B))),
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
                    final err = widget.controller.createListing(mItem.itemId, qty, customPrice);
                    Navigator.pop(ctx);
                    if (err != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err), backgroundColor: Colors.red[800]),
                      );
                    } else {
                      setState(() {
                        _mainTab = 1; // Oyuncu Pazarı
                        _pazarSubTab = 1; // Benim İlanlarım
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '$qty adet ${mItem.data.name} ${customPrice.toStringAsFixed(2)} ₺ fiyattan pazara çıkarıldı!',
                          ),
                          backgroundColor: Colors.green[800],
                        ),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err), backgroundColor: Colors.red[800]),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${listing.item.name} ilanı iptal edildi ve mallar depoya döndü.'),
                    backgroundColor: Colors.blueGrey[800],
                  ),
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

  // Hızlı Al / Hızlı Sat Dialogu
  void _showTradeDialog(BuildContext context, dynamic mItem, {required bool isBuy, required bool isDark}) {
    int qty = 10;
    final inStock = widget.controller.warehouse[mItem.itemId] ?? 0;
    final maxCanSell = inStock;

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
                            ? () => setDialogState(() => qty = (qty - 5).clamp(1, isBuy ? 10000 : maxCanSell))
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$qty Adet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.amber : const Color(0xFFD97706),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: (!isBuy && qty >= maxCanSell)
                            ? null
                            : () => setDialogState(() => qty = (qty + 5).clamp(1, isBuy ? 10000 : maxCanSell)),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _quickQtyBtn(setDialogState, () => qty = min(10, isBuy ? 10 : maxCanSell), '10', isDark),
                      const SizedBox(width: 4),
                      _quickQtyBtn(setDialogState, () => qty = min(50, isBuy ? 50 : maxCanSell), '50', isDark),
                      const SizedBox(width: 4),
                      _quickQtyBtn(setDialogState, () => qty = min(100, isBuy ? 100 : maxCanSell), '100', isDark),
                      if (!isBuy && maxCanSell > 0) ...[
                        const SizedBox(width: 4),
                        _quickQtyBtn(setDialogState, () => qty = maxCanSell, 'Tümü ($maxCanSell)', isDark),
                      ],
                    ],
                  ),
                  Divider(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0), height: 20),
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
                    String? err;
                    if (isBuy) {
                      err = widget.controller.buyFromMarket(mItem.itemId, qty);
                    } else {
                      err = widget.controller.sellToMarket(mItem.itemId, qty);
                    }
                    Navigator.pop(ctx);
                    if (err != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err), backgroundColor: Colors.red[800]),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isBuy
                                ? '$qty adet ${mItem.data.name} depoya alındı!'
                                : '$qty adet ${mItem.data.name} anında sisteme satıldı! (+${total.toStringAsFixed(0)} ₺)',
                          ),
                          backgroundColor: Colors.green[800],
                        ),
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

  Widget _buildFilterChip(String label, ItemCategory? cat, bool isDark) {
    final isSelected = _selectedCategory == cat;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedCategory = cat),
      selectedColor: isDark ? Colors.blueAccent[700] : const Color(0xFF0F766E),
      backgroundColor: isDark ? const Color(0xFF1E283E) : const Color(0xFFE2E8F0),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : const Color(0xFF334155)),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 11,
      ),
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
}
