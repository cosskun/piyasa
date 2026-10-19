import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import '../models/facility.dart';
import '../models/item.dart';
import '../models/store.dart';
import '../widgets/game_toast.dart';

class WarehouseTab extends StatefulWidget {
  final GameController controller;

  const WarehouseTab({super.key, required this.controller});

  @override
  State<WarehouseTab> createState() => _WarehouseTabState();
}

class _WarehouseTabState extends State<WarehouseTab> {
  int _selectedSubTab = 0; // 0: Hammaddeler, 1: Ürünler

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final c = widget.controller;
        final currencyFmt = NumberFormat("#,##0", "tr_TR");

        final usedWeight = c.currentWarehouseWeight;
        final maxWeight = c.maxWarehouseCapacity;
        final ratio = (usedWeight / maxWeight).clamp(0.0, 1.0);

    // Tüm hammaddeler ve ürünler listesi
    final allRawMaterials = ItemRegistry.items.values
        .where((i) => i.category == ItemCategory.rawMaterial)
        .toList();

    final allProducts = ItemRegistry.items.values
        .where((i) => i.category == ItemCategory.intermediate || i.category == ItemCategory.finishedGood)
        .toList();

    // Stokta olan ürün sayıları
    final rawInStockCount = allRawMaterials.where((i) => (c.warehouse[i.id] ?? 0) > 0).length;
    final productInStockCount = allProducts.where((i) => (c.warehouse[i.id] ?? 0) > 0).length;

    // Depodaki toplam borsa değeri
    double totalWarehouseValue = 0.0;
    c.warehouse.forEach((itemId, count) {
      final mItem = c.marketItems[itemId];
      final item = ItemRegistry.get(itemId);
      final price = mItem?.currentPrice ?? item?.basePrice ?? 0.0;
      totalWarehouseValue += price * count;
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // === 1. DEPO VE SİLO KAPASİTE KARTI (HUD) ===
          Container(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161C2C) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : Colors.black.withOpacity(0.03),
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
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.amber.withOpacity(0.15) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('📦', style: TextStyle(fontSize: 20)),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Merkezi Depo & Silolarım',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Toplam Değer: ${currencyFmt.format(totalWarehouseValue)} ₺',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Kapasite Genişletme Butonu
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final cost = c.maxWarehouseCapacity * 5.0;
                          if (c.cash < cost) {
                            GameToast.showWarning(
                              context,
                              'Yetersiz nakit! Kapasite için ${currencyFmt.format(cost)} ₺ gerekiyor.',
                              title: 'Yetersiz Bakiye',
                            );
                            return;
                          }
                          final err = c.expandWarehouse();
                          if (err != null) {
                            GameToast.showError(context, err, title: 'Genişletme Başarısız');
                          } else {
                            GameToast.showSuccess(
                              context,
                              'Depo kapasitesi +500 kg genişletildi! 🏗️',
                              title: 'Depo Büyütüldü',
                            );
                          }
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 14),
                        label: Text('+500 kg (${currencyFmt.format(c.maxWarehouseCapacity * 5.0)} ₺)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.amber[700] : const Color(0xFFD97706),
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Doluluk Barı
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Doluluk: ${usedWeight.toStringAsFixed(0)} / ${maxWeight.toStringAsFixed(0)} kg (%${(ratio * 100).toInt()})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Boş: ${(maxWeight - usedWeight).clamp(0, maxWeight).toStringAsFixed(0)} kg',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: isDark ? Colors.black38 : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ratio > 0.88
                          ? Colors.redAccent
                          : (ratio > 0.65
                              ? (isDark ? Colors.amberAccent : const Color(0xFFF59E0B))
                              : (isDark ? Colors.greenAccent : const Color(0xFF10B981))),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // === 2. HAMMADDELER & ÜRÜNLER İKİ ANA ALT SEKME ===
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                Expanded(
                  child: _buildSubTabButton(
                    index: 0,
                    title: '🌾 Hammaddeler',
                    count: rawInStockCount,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildSubTabButton(
                    index: 1,
                    title: '📦 Ürünler',
                    count: productInStockCount,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),

          // === 3. SEÇİLİ KATEGORİDEKİ ÜRÜN LİSTESİ ===
          Expanded(
            child: _selectedSubTab == 0
                ? _buildItemsList(context, allRawMaterials, isRawMaterials: true, isDark: isDark)
                : _buildItemsList(context, allProducts, isRawMaterials: false, isDark: isDark),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildSubTabButton({
    required int index,
    required String title,
    required int count,
    required bool isDark,
  }) {
    final isSelected = _selectedSubTab == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedSubTab = index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? const Color(0xFF0D9488) : const Color(0xFF0F766E))
                          : (isDark ? const Color(0xFF334155) : const Color(0xFF94A3B8)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
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
      ),
    );
  }

  Widget _buildItemsList(
    BuildContext context,
    List<ItemData> items, {
    required bool isRawMaterials,
    required bool isDark,
  }) {
    final c = widget.controller;
    final currencyFmt = NumberFormat("#,##0", "tr_TR");

    // Depoda olanları en başa al, sonra stok miktarına göre sırala
    final sortedItems = List<ItemData>.from(items)..sort((a, b) {
      final stockA = c.warehouse[a.id] ?? 0;
      final stockB = c.warehouse[b.id] ?? 0;
      if (stockA > 0 && stockB == 0) return -1;
      if (stockA == 0 && stockB > 0) return 1;
      return stockB.compareTo(stockA);
    });

    final inStockItems = sortedItems.where((i) => (c.warehouse[i.id] ?? 0) > 0).toList();
    final outOfStockItems = sortedItems.where((i) => (c.warehouse[i.id] ?? 0) == 0).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      cacheExtent: 600,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: [
        // BÖLÜM 1: DEPODAKİ MEVCUT STOKLAR
        if (inStockItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 15,
                  color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                ),
                const SizedBox(width: 6),
                Text(
                  'Depodaki Stoklarım (${inStockItems.length})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          ...inStockItems.map((item) => _buildStockedItemCard(context, item, isDark, currencyFmt)),
          const SizedBox(height: 12),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161C2C) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Text(isRawMaterials ? '🌾' : '📦', style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRawMaterials
                            ? 'Deponuzda henüz hammadde bulunmuyor.'
                            : 'Deponuzda henüz işlenmiş ürün bulunmuyor.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isRawMaterials
                            ? 'Tarlalarınızdan üretim yapabilir veya toptan borsadan alabilirsiniz.'
                            : 'Fabrikalarınızdan üretim yapabilir veya toptan borsadan alabilirsiniz.',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // BÖLÜM 2: DİĞER TÜM KATALOG (Stokta Olmayanlar)
        if (outOfStockItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4, bottom: 8),
            child: Text(
              isRawMaterials ? 'Tüm Hammaddeler Kataloğu' : 'Tüm Ürünler Kataloğu',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
              ),
            ),
          ),
          ...outOfStockItems.map((item) => _buildOutOfStockItemCard(context, item, isDark, currencyFmt)),
        ],
      ],
    );
  }

  Widget _buildStockedItemCard(
    BuildContext context,
    ItemData item,
    bool isDark,
    NumberFormat currencyFmt,
  ) {
    final c = widget.controller;
    final count = c.warehouse[item.id] ?? 0;
    final mItem = c.marketItems[item.id];
    final currentPrice = mItem?.currentPrice ?? item.basePrice;
    final quickPrice = mItem?.quickSellPrice ?? (currentPrice * 0.85);
    final totalVal = currentPrice * count;
    final totalKg = count * item.weight;

    // Bu ürünü satabilen dükkanımız var mı?
    final matchingStore = c.ownedStores.where((s) => s.allowedProductIds.contains(item.id)).toList();

    return Card(
      color: isDark ? const Color(0xFF1E2638) : Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isDark ? 2 : 1.2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? Colors.amber.withOpacity(0.3) : const Color(0xFFF59E0B).withOpacity(0.35),
          width: 1.1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Satır: Emoji, İsim, Stok Rozeti
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(item.emoji, style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Birim: ${currentPrice.toStringAsFixed(1)} ₺ • Hızlı Satış: ${quickPrice.toStringAsFixed(1)} ₺',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.amber.withOpacity(0.18) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '$count Adet',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.amberAccent : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${totalKg.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Toplam Borsa Değeri Barı
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141A29) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tahmini Toplam Değeri:',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    '${currencyFmt.format(totalVal)} ₺',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Hızlı Eylem Butonları (Pazara Çıkar, Hızlı Sat, Dükkana Gönder)
            Row(
              children: [
                // 1. Pazara Çıkar (İlan Ver)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showPazaraCikarDialog(context, item, count, currentPrice, isDark),
                    icon: const Icon(Icons.storefront_outlined, size: 14),
                    label: const Text('Pazara Çıkar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Hızlı Sat (Anında Toptan Sat)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showHizliSatDialog(context, item, count, quickPrice, isDark),
                    icon: const Icon(Icons.flash_on, size: 14),
                    label: const Text('Hızlı Sat'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.orangeAccent : const Color(0xFFD97706),
                      side: BorderSide(color: isDark ? Colors.orangeAccent : const Color(0xFFD97706)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // 3. Dükkana Gönder (Eğer bu ürünü satan dükkanımız varsa)
                if (matchingStore.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showDukkanaGonderDialog(context, item, count, matchingStore, isDark),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.teal.withOpacity(0.18) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.tealAccent : const Color(0xFF10B981),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shelves,
                            size: 15,
                            color: isDark ? Colors.tealAccent : const Color(0xFF059669),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Dükkana Raf Yap',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.tealAccent : const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutOfStockItemCard(
    BuildContext context,
    ItemData item,
    bool isDark,
    NumberFormat currencyFmt,
  ) {
    final c = widget.controller;
    final mItem = c.marketItems[item.id];
    final buyPrice = mItem?.wholesaleBuyPrice ?? item.basePrice;

    // Bu ürünü üreten tesis var mı?
    final facilityBlueprints = ProductionFacility.getBlueprints();
    final producer = facilityBlueprints.firstWhere(
      (f) => f.recipe.outputItemId == item.id,
      orElse: () => facilityBlueprints.first,
    );
    final producesThis = producer.recipe.outputItemId == item.id;

    return Card(
      color: isDark ? const Color(0xFF141A28) : const Color(0xFFF8FAFC),
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    producesThis
                        ? 'Üretim: ${producer.emoji} ${producer.name}'
                        : 'Borsa Alış: ${buyPrice.toStringAsFixed(1)} ₺',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? Colors.grey[500] : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _showBorsadanAlDialog(context, item, buyPrice, isDark),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                foregroundColor: isDark ? Colors.white70 : const Color(0xFF334155),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Borsadan Al (${buyPrice.toStringAsFixed(0)} ₺)',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === DİYALOG 1: PAZARA ÇIKAR (KENDİ FİYATINLA İLAN VER) ===
  void _showPazaraCikarDialog(
    BuildContext context,
    ItemData item,
    int maxStock,
    double currentPrice,
    bool isDark,
  ) {
    final qtyCtrl = TextEditingController(text: maxStock.toString());
    final priceCtrl = TextEditingController(text: currentPrice.toStringAsFixed(2));
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final qty = int.tryParse(qtyCtrl.text) ?? 0;
            final price = double.tryParse(priceCtrl.text) ?? 0.0;
            final totalEarn = qty * price;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF182032) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Text(item.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${item.name} Pazara Çıkar',
                      style: TextStyle(
                        fontSize: 17,
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
                    'Deponuzdaki ${item.name} ürünlerini kendi belirlediğiniz fiyattan Oyuncu Pazarına çıkarın.',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : const Color(0xFF475569)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      setDialogState(() {
                        if (dialogError != null) dialogError = null;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Satılacak Miktar (Maks: $maxStock)',
                      prefixIcon: const Icon(Icons.numbers),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ActionChip(
                        label: const Text('%50', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          qtyCtrl.text = (maxStock ~/ 2).clamp(1, maxStock).toString();
                          setDialogState(() {
                            if (dialogError != null) dialogError = null;
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                      ActionChip(
                        label: const Text('Tümü', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          qtyCtrl.text = maxStock.toString();
                          setDialogState(() {
                            if (dialogError != null) dialogError = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) {
                      setDialogState(() {
                        if (dialogError != null) dialogError = null;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Birim Satış Fiyatı (₺)',
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Toplam Kazanç Beklentisi:', style: TextStyle(fontSize: 11.5)),
                        Text(
                          '${totalEarn.toStringAsFixed(2)} ₺',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    DialogWarningBubble(
                      message: dialogError!,
                      onDismiss: () => setDialogState(() => dialogError = null),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Vazgeç', style: TextStyle(color: isDark ? Colors.grey : const Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: () {
                    final q = int.tryParse(qtyCtrl.text) ?? 0;
                    final p = double.tryParse(priceCtrl.text) ?? 0.0;
                    final currentStock = widget.controller.warehouse[item.id] ?? 0;
                    if (currentStock <= 0) {
                      final msg = 'Deponuzda satılacak ${item.name} kalmadı!';
                      setDialogState(() => dialogError = msg);
                      GameToast.showWarning(context, msg, title: 'Yetersiz Stok');
                      return;
                    }
                    if (q <= 0 || q > currentStock || p <= 0) {
                      final msg = q > currentStock
                          ? 'Depoda sadece $currentStock adet var, $q adet çıkaramazsınız.'
                          : 'Lütfen geçerli bir miktar ve birim fiyat girin.';
                      setDialogState(() => dialogError = msg);
                      GameToast.showWarning(context, msg, title: 'Geçersiz Giriş');
                      return;
                    }
                    final err = widget.controller.createListing(item.id, q, p);
                    if (err != null) {
                      setDialogState(() => dialogError = err);
                      GameToast.showWarning(context, err, title: 'İlan Verilemedi');
                    } else {
                      Navigator.pop(ctx);
                      GameToast.showSuccess(
                        context,
                        '$q adet ${item.name} pazara çıkarıldı! 🏷️',
                        title: 'İlan Yayınlandı',
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.blue[700] : const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Pazara Çıkar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // === DİYALOG 2: HIZLI SAT (ANINDA TOPTAN SATIŞ) ===
  void _showHizliSatDialog(
    BuildContext context,
    ItemData item,
    int maxStock,
    double quickPrice,
    bool isDark,
  ) {
    int sellQty = maxStock > 0 ? maxStock : 0;
    final mItem = widget.controller.marketItems[item.id];
    final marketPrice = mItem?.currentPrice ?? item.basePrice;
    final effectiveMax = maxStock > 0 ? maxStock : 1;
    String? dialogError = maxStock <= 0 ? 'Deponuzda satılacak ${item.name} kalmadı!' : null;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final totalEarn = sellQty * quickPrice;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF182032) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.flash_on, color: Colors.orangeAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${item.name} Hızlı Sat',
                      style: TextStyle(
                        fontSize: 17,
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
                    'Beklemeden, toptan borsa fiyatından anında kasaya nakit geçirin.',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : const Color(0xFF475569)),
                  ),
                  const SizedBox(height: 12),
                  // Fiyat Bilgi Şeridi (Birim Satış ve Anlık Piyasa Değeri)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E283E) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Birim Satış Fiyatı:',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${quickPrice.toStringAsFixed(2)} ₺',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orangeAccent,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Anlık Borsa Değeri:',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${marketPrice.toStringAsFixed(2)} ₺',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Satılacak Miktar:', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : const Color(0xFF64748B))),
                      Text('$sellQty / $maxStock Adet', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: sellQty.clamp(1, effectiveMax).toDouble(),
                    min: 1,
                    max: effectiveMax.toDouble(),
                    divisions: effectiveMax > 1 ? effectiveMax - 1 : 1,
                    activeColor: Colors.orangeAccent,
                    onChanged: maxStock <= 0
                        ? null
                        : (val) {
                            setDialogState(() {
                              sellQty = val.toInt();
                              if (dialogError != null) dialogError = null;
                            });
                          },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ActionChip(
                        label: const Text('1 Adet', style: TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        onPressed: maxStock <= 0
                            ? null
                            : () {
                                setDialogState(() {
                                  sellQty = 1;
                                  if (dialogError != null) dialogError = null;
                                });
                              },
                      ),
                      if (maxStock >= 4) ...[
                        const SizedBox(width: 4),
                        ActionChip(
                          label: const Text('%50', style: TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setDialogState(() {
                              sellQty = (maxStock ~/ 2).clamp(1, maxStock);
                              if (dialogError != null) dialogError = null;
                            });
                          },
                        ),
                      ],
                      const SizedBox(width: 4),
                      ActionChip(
                        label: const Text('Tümü', style: TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        onPressed: maxStock <= 0
                            ? null
                            : () {
                                setDialogState(() {
                                  sellQty = maxStock;
                                  if (dialogError != null) dialogError = null;
                                });
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Birim Fiyat:', style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
                            Text('${quickPrice.toStringAsFixed(2)} ₺ / adet', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Kasanıza Geçecek Nakit:', style: TextStyle(fontSize: 11.5)),
                            Text(
                              '+${totalEarn.toStringAsFixed(2)} ₺',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    DialogWarningBubble(
                      message: dialogError!,
                      onDismiss: () => setDialogState(() => dialogError = null),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Vazgeç', style: TextStyle(color: isDark ? Colors.grey : const Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: maxStock <= 0
                      ? null
                      : () {
                          final currentStock = widget.controller.warehouse[item.id] ?? 0;
                          if (currentStock <= 0) {
                            final msg = 'Deponuzda hiç ${item.name} bulunmuyor! 📦';
                            setDialogState(() => dialogError = msg);
                            GameToast.showWarning(context, msg, title: 'Yetersiz Stok');
                            return;
                          }
                          if (sellQty <= 0) {
                            final msg = 'Lütfen satılacak miktarı belirleyin.';
                            setDialogState(() => dialogError = msg);
                            GameToast.showWarning(context, msg, title: 'Geçersiz Miktar');
                            return;
                          }
                          if (sellQty > currentStock) {
                            final msg = 'Depoda yeterli stok yok! (Mevcut: $currentStock adet)';
                            setDialogState(() {
                              dialogError = msg;
                              sellQty = currentStock;
                            });
                            GameToast.showWarning(context, msg, title: 'Yetersiz Stok');
                            return;
                          }

                          final err = widget.controller.sellToMarket(item.id, sellQty);
                          if (err != null) {
                            setDialogState(() => dialogError = err);
                            GameToast.showWarning(context, err, title: 'Satış Uyarısı');
                          } else {
                            Navigator.pop(ctx);
                            GameToast.showSuccess(
                              context,
                              '$sellQty adet ${item.name} satıldı ve +${totalEarn.toStringAsFixed(0)} ₺ kasaya eklendi! 💰',
                              title: 'Hızlı Satış Yapıldı',
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Anında Sat'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // === DİYALOG 3: DÜKKANA GÖNDER / RAFLARA AKTAR ===
  void _showDukkanaGonderDialog(
    BuildContext context,
    ItemData item,
    int stock,
    List<RetailStore> stores,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF141926) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(item.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text(
                    '${item.name} Dükkan Raflarına Aktar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Bu ürünü perakende satabileceğiniz dükkanlarınız:',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              ...stores.map((store) {
                final slot = store.productSlots.where((s) => s.itemId == item.id).firstOrNull;
                final canAddSlot = slot == null && store.productSlots.length < store.maxProductSlots;

                return Card(
                  color: isDark ? const Color(0xFF1E283C) : const Color(0xFFF8FAFC),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Text(store.emoji, style: const TextStyle(fontSize: 26)),
                    title: Text(store.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    subtitle: Text(
                      slot != null
                          ? 'Rafta: ${slot.shelfStock} / ${slot.shelfCapacity} adet'
                          : (canAddSlot ? 'Yeni ürün rafı olarak eklenebilir' : 'Maksimum raf sayısına ulaşıldı'),
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: slot != null
                        ? ElevatedButton(
                            onPressed: () {
                              final needed = slot.shelfCapacity - slot.shelfStock;
                              if (needed <= 0) {
                                GameToast.showWarning(
                                  context,
                                  'Bu mağazada bu ürünün rafı zaten dolu!',
                                  title: 'Raf Dolu',
                                );
                                return;
                              }
                              widget.controller.restockStoreSlot(store, slot, min(stock, needed));
                              Navigator.pop(ctx);
                              GameToast.showSuccess(
                                context,
                                '${store.name} raflarına ${item.name} aktarıldı! 🛒',
                                title: 'Raflara Eklendi',
                              );
                            },
                            child: const Text('Rafa Ekle', style: TextStyle(fontSize: 11)),
                          )
                        : (canAddSlot
                            ? ElevatedButton(
                                onPressed: () {
                                  widget.controller.addProductSlotToStore(store, item.id);
                                  Navigator.pop(ctx);
                                  GameToast.showSuccess(
                                    context,
                                    '${store.name} mağazasına ${item.name} yeni raf olarak eklendi! 🎉',
                                    title: 'Yeni Raf Açıldı',
                                  );
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                                child: const Text('Yeni Raf Aç', style: TextStyle(fontSize: 11)),
                              )
                            : null),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // === DİYALOG 4: BORSADAN SATIN AL ===
  void _showBorsadanAlDialog(
    BuildContext context,
    ItemData item,
    double buyPrice,
    bool isDark,
  ) {
    final c = widget.controller;
    final qtyCtrl = TextEditingController(text: '20');
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final qty = int.tryParse(qtyCtrl.text) ?? 0;
            final totalCost = qty * buyPrice;
            final canAfford = c.cash >= totalCost;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF182032) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Text(item.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${item.name} Satın Al',
                      style: TextStyle(
                        fontSize: 17,
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
                    'Toptan borsadan mal çekerek fabrikanızda işleyebilir veya dükkanınızda satabilirsiniz.',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : const Color(0xFF475569)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      setDialogState(() {
                        if (dialogError != null) dialogError = null;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Satın Alınacak Miktar',
                      prefixIcon: const Icon(Icons.shopping_basket_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Toplam Tutar:', style: TextStyle(fontSize: 12)),
                        Text(
                          '${totalCost.toStringAsFixed(2)} ₺',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: canAfford
                                ? (isDark ? Colors.amberAccent : const Color(0xFFD97706))
                                : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    DialogWarningBubble(
                      message: dialogError!,
                      onDismiss: () => setDialogState(() => dialogError = null),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Vazgeç', style: TextStyle(color: isDark ? Colors.grey : const Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: canAfford && qty > 0
                      ? () {
                          final err = c.buyFromMarket(item.id, qty);
                          if (err != null) {
                            setDialogState(() => dialogError = err);
                            GameToast.showWarning(context, err, title: 'Satın Alma Uyarısı');
                          } else {
                            Navigator.pop(ctx);
                            GameToast.showSuccess(
                              context,
                              '$qty adet ${item.name} satın alındı ve depoya aktarıldı! 📦',
                              title: 'Satın Alındı',
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.amber[700] : const Color(0xFFD97706),
                    foregroundColor: isDark ? Colors.black : Colors.white,
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
}
