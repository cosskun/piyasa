import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import '../models/facility.dart';
import '../models/item.dart';

class ProductionTab extends StatelessWidget {
  final GameController controller;

  const ProductionTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat("#,##0", "tr_TR");
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
      backgroundColor: Colors.transparent,
      body: controller.ownedFacilities.isEmpty
          ? _buildStarterOptionsView(context, isDark, currencyFmt)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Text(
                      'Tesislerim (${controller.ownedFacilities.length})',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showBuyFacilitySheet(context),
                      icon: const Icon(Icons.add_business, size: 18),
                      label: const Text('Yeni Tesis Al'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.amber[700] : const Color(0xFFD97706),
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Toplam Üretim Gücü Özeti
                Builder(
                  builder: (ctx) {
                    final totalPerMin = controller.ownedFacilities.fold<double>(
                      0.0,
                      (sum, f) => sum + f.itemsPerMinute,
                    );
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF16233B) : const Color(0xFFE6FFFA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF0D9488).withOpacity(0.4) : const Color(0xFF99F6E4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.speed, size: 20, color: Color(0xFF0D9488)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '⚡ Tesislerinizin Toplam Üretim Kapasitesi:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[300] : const Color(0xFF0F766E),
                              ),
                            ),
                          ),
                          Text(
                            '~${totalPerMin.toStringAsFixed(0)} adet / dk',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.tealAccent : const Color(0xFF0D9488),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                ...controller.ownedFacilities.map((fac) {
                  final outItem = ItemRegistry.get(fac.recipe.outputItemId);

                  return Card(
                    color: isDark ? const Color(0xFF1E2638) : Colors.white,
                    margin: const EdgeInsets.only(bottom: 14),
                    elevation: isDark ? 2 : 1.5,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: fac.type == FacilityType.agriculture
                            ? (isDark ? Colors.green.withOpacity(0.3) : const Color(0xFF10B981).withOpacity(0.4))
                            : (isDark ? Colors.blue.withOpacity(0.3) : const Color(0xFF3B82F6).withOpacity(0.4)),
                        width: 1.2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(fac.emoji, style: const TextStyle(fontSize: 28)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fac.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      fac.type == FacilityType.agriculture
                                          ? '🌿 Tarım: Hasat döngüsü'
                                          : '🏭 Fabrika: Reçete üretimi',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.blueGrey[800] : const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Sv. ${fac.level}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Geliştirme Butonu (İkinci Doğrulama İle)
                                  InkWell(
                                    onTap: () => _showUpgradeConfirmation(context, fac, currencyFmt, isDark),
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
                                            '${currencyFmt.format(fac.upgradeCost)} ₺',
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
                          const SizedBox(height: 14),

                          // Reçete / Çıktı bilgisi
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black12 : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? Colors.transparent : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  if (fac.recipe.inputs.isNotEmpty) ...[
                                    Text(
                                      'Girdi: ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.grey : const Color(0xFF64748B),
                                      ),
                                    ),
                                    ...fac.recipe.inputs.entries.map((e) {
                                      var item = ItemRegistry.get(e.key);
                                      return Text(
                                        '${e.value} ${item?.emoji ?? ''}  ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      );
                                    }),
                                    Icon(
                                      Icons.arrow_forward,
                                      size: 14,
                                      color: isDark ? Colors.grey : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    'Çıktı: +${fac.effectiveOutput} ${outItem?.emoji ?? ''} ${outItem?.name ?? ''}  (${fac.effectiveDuration.toStringAsFixed(1)} sn)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.greenAccent[400] : const Color(0xFF059669),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.speed, size: 13, color: isDark ? Colors.greenAccent : const Color(0xFF047857)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '⚡ Üretim Gücü: ~${fac.itemsPerMinute.toStringAsFixed(0)} adet / dk',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.greenAccent : const Color(0xFF047857),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // İlerleme Çubuğu
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: fac.progress,
                              minHeight: 8,
                              backgroundColor: isDark ? Colors.black38 : const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                fac.type == FacilityType.agriculture
                                    ? (isDark ? Colors.greenAccent[400]! : const Color(0xFF10B981))
                                    : (isDark ? Colors.cyanAccent[400]! : const Color(0xFF0284C7)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  fac.statusMessage,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: fac.statusMessage.contains('Dolu') || fac.statusMessage.contains('Bekleniyor')
                                        ? Colors.orangeAccent
                                        : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => _showSellFacilityConfirmation(context, fac, currencyFmt, isDark),
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
                                        Icons.sell_outlined,
                                        size: 12,
                                        color: isDark ? Colors.redAccent : const Color(0xFFDC2626),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Tesisi Sat (${currencyFmt.format(fac.resaleValue)} ₺)',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.redAccent : const Color(0xFFDC2626),
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
                  );
                }),
              ],
            ),
    ));
  }

  void _showBuyFacilitySheet(BuildContext context) {
    final currencyFmt = NumberFormat("#,##0", "tr_TR");
    final blueprints = ProductionFacility.getBlueprints();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF141926) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        int filterCategory = 0; // 0: Tümü, 1: Başlangıç (≤15k), 2: Tarım & Kaynak, 3: Fabrika
        const starterThreshold = 15000.0;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filteredBlueprints = blueprints.where((bp) {
              if (filterCategory == 1) return bp.purchaseCost <= starterThreshold;
              if (filterCategory == 2) return bp.type == FacilityType.agriculture;
              if (filterCategory == 3) return bp.type == FacilityType.factory;
              return true;
            }).toList();

            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '🌾 Yeni Tesis Satın Al (${filteredBlueprints.length})',
                        style: TextStyle(
                          fontSize: 18,
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
                    'Tesislerin dakika başı üretim kapasitelerini karşılaştırarak dilediğiniz adette satın alabilirsiniz.',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 10),

                  // Kategori Filtre Butonları
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Tümü (${blueprints.length})', filterCategory == 0, () {
                          setSheetState(() => filterCategory = 0);
                        }, isDark),
                        const SizedBox(width: 8),
                        _buildFilterChip('🌟 Başlangıç (≤15.000 ₺)', filterCategory == 1, () {
                          setSheetState(() => filterCategory = 1);
                        }, isDark),
                        const SizedBox(width: 8),
                        _buildFilterChip('🌾 Tarım & Kaynak (${blueprints.where((b) => b.type == FacilityType.agriculture).length})', filterCategory == 2, () {
                          setSheetState(() => filterCategory = 2);
                        }, isDark),
                        const SizedBox(width: 8),
                        _buildFilterChip('🏭 Fabrika & Sanayi (${blueprints.where((b) => b.type == FacilityType.factory).length})', filterCategory == 3, () {
                          setSheetState(() => filterCategory = 3);
                        }, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredBlueprints.length,
                      itemBuilder: (ctx, i) {
                        final bp = filteredBlueprints[i];
                        final canAfford = controller.cash >= bp.purchaseCost;
                        final outItem = ItemRegistry.get(bp.recipe.outputItemId);

                        return Card(
                          color: isDark ? const Color(0xFF1F283C) : const Color(0xFFF8FAFC),
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: bp.type == FacilityType.agriculture
                                  ? (isDark ? Colors.green.withOpacity(0.3) : const Color(0xFF10B981).withOpacity(0.35))
                                  : (isDark ? Colors.blue.withOpacity(0.3) : const Color(0xFF3B82F6).withOpacity(0.35)),
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: canAfford
                                ? () => _showBuyQuantityDialog(context, bp, isDark, currencyFmt)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
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
                                            fontSize: 14,
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
                                        const SizedBox(height: 4),
                                        // Üretim Reçetesi
                                        if (bp.recipe.inputs.isNotEmpty) ...[
                                          Text(
                                            'Girdi: ${bp.recipe.inputs.entries.map((e) => "${e.value}x ${ItemRegistry.get(e.key)?.name ?? e.key}").join(', ')}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.orangeAccent : const Color(0xFFD97706),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                        ],
                                        Text(
                                          'Çıktı: ${bp.recipe.outputAmount}x ${outItem?.name ?? bp.recipe.outputItemId} (Her ${bp.recipe.durationSeconds.toStringAsFixed(1)} sn)',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // DAKİKA BAŞI ÜRETİM BİLGİSİ ROZETİ
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF059669) : const Color(0xFF10B981),
                                              width: 0.6,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.speed, size: 11, color: isDark ? Colors.greenAccent : const Color(0xFF047857)),
                                              const SizedBox(width: 3),
                                              Text(
                                                '⚡ Dakikada: ~${bp.baseItemsPerMinute.toStringAsFixed(0)} adet',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? Colors.greenAccent : const Color(0xFF047857),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: canAfford
                                        ? () => _showBuyQuantityDialog(context, bp, isDark, currencyFmt)
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: canAfford
                                          ? (isDark ? Colors.green[600] : const Color(0xFF059669))
                                          : (isDark ? Colors.grey[800] : const Color(0xFFCBD5E1)),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '${currencyFmt.format(bp.purchaseCost)} ₺',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        ),
                                        if (canAfford) ...[
                                          const SizedBox(height: 1),
                                          const Text(
                                            'Adet Seç ›',
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white70),
                                          ),
                                        ],
                                      ],
                                    ),
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
              ),
            );
          },
        );
      },
    );
  }

  void _showBuyQuantityDialog(
    BuildContext context,
    ProductionFacility bp,
    bool isDark,
    NumberFormat currencyFmt,
  ) {
    int quantity = 1;
    final maxAffordable = max(1, (controller.cash / bp.purchaseCost).floor());

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF161F33) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final totalCost = bp.purchaseCost * quantity;
            final canAfford = controller.cash >= totalCost;
            final totalOutputPerMin = bp.baseItemsPerMinute * quantity;
            final outItem = ItemRegistry.get(bp.recipe.outputItemId);

            return Padding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(bp.emoji, style: const TextStyle(fontSize: 32)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bp.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Birim Fiyat: ${currencyFmt.format(bp.purchaseCost)} ₺ / adet',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    bp.description,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),

                  // Üretim Hızı & Reçete Bilgisi Kutusu
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E283E) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF0D9488).withOpacity(0.4) : const Color(0xFF99F6E4),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '⏱️ 1 Tesisin Üretim Hızı:',
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : const Color(0xFF475569)),
                            ),
                            Text(
                              '~${bp.baseItemsPerMinute.toStringAsFixed(0)} adet / dakika',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.tealAccent : const Color(0xFF0F766E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Döngü:',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                            ),
                            Text(
                              'Her ${bp.recipe.durationSeconds.toStringAsFixed(1)} sn\'de ${bp.recipe.outputAmount} adet ${outItem?.name ?? ""}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                        if (quantity > 1) ...[
                          const Divider(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '⚡ $quantity Tesis Toplam Üretim:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                                ),
                              ),
                              Text(
                                '~${totalOutputPerMin.toStringAsFixed(0)} adet / dakika',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Adet Seçici
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Satın Alınacak Adet:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: quantity > 1 ? () => setModalState(() => quantity--) : null,
                            icon: const Icon(Icons.remove_circle_outline),
                            color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF26344E) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$quantity',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: (quantity + 1) * bp.purchaseCost <= controller.cash
                                ? () => setModalState(() => quantity++)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                            color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Hızlı Adet Hapları (1x, 2x, 3x, 5x, Maks)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [1, 2, 3, 5, maxAffordable].toSet().map((q) {
                      final isCurrent = quantity == q;
                      final qAffordable = controller.cash >= bp.purchaseCost * q;
                      final label = q == maxAffordable && q > 1 ? 'Maks ($q)' : '${q}x';
                      return InkWell(
                        onTap: qAffordable ? () => setModalState(() => quantity = q) : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? const Color(0xFF0F766E)
                                : (isDark ? const Color(0xFF1E283E) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCurrent
                                  ? Colors.tealAccent
                                  : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                              color: isCurrent
                                  ? Colors.white
                                  : (qAffordable
                                      ? (isDark ? Colors.white70 : const Color(0xFF334155))
                                      : (isDark ? Colors.grey[600] : const Color(0xFF94A3B8))),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Toplam Tutar ve Satın Al Butonu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Toplam Tutar:', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey : const Color(0xFF64748B))),
                          Text(
                            '${currencyFmt.format(totalCost)} ₺',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: canAfford ? (isDark ? Colors.amberAccent : const Color(0xFFD97706)) : Colors.redAccent,
                            ),
                          ),
                          Text(
                            'Kalan Nakit: ${currencyFmt.format(controller.cash - totalCost)} ₺',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: canAfford ? (isDark ? Colors.greenAccent : const Color(0xFF059669)) : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: canAfford
                            ? () {
                                controller.buyFacility(bp, quantity: quantity);
                                Navigator.pop(modalCtx);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$quantity adet ${bp.name} başarıyla kuruldu! Üretime başlandı.'),
                                    backgroundColor: const Color(0xFF059669),
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(quantity > 1 ? '$quantity Tesis Al' : 'Satın Al'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showUpgradeConfirmation(
    BuildContext context,
    ProductionFacility fac,
    NumberFormat currencyFmt,
    bool isDark,
  ) {
    final nextLevel = fac.level + 1;
    final cost = fac.upgradeCost;
    final canAfford = controller.cash >= cost;
    final nextDuration = max(2.0, fac.recipe.durationSeconds * (1.0 - (nextLevel - 1) * 0.08));
    final nextOutput = nextLevel <= 2 ? fac.recipe.outputAmount : (fac.recipe.outputAmount * (1.0 + (nextLevel - 2) * 0.25)).round();
    final nextItemsPerMin = (nextOutput * 60.0) / nextDuration;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF182032) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Text(fac.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${fac.name} Yükseltilsin mi?',
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
                'Bu tesisi Seviye $nextLevel seviyesine yükseltmek istediğinizden emin misiniz?',
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
                    Row(
                      children: [
                        const Icon(Icons.speed, size: 16, color: Colors.blueAccent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '⚡ Dakika Başı Üretim: ~${fac.itemsPerMinute.toStringAsFixed(0)} adet ➔ ~${nextItemsPerMin.toStringAsFixed(0)} adet / dk',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.tealAccent : const Color(0xFF0F766E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.trending_up, size: 16, color: Colors.greenAccent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            nextLevel > 2 ? 'Hasat/üretim miktarı %20 artar' : 'Üretim verimi artar',
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
                      final err = controller.upgradeFacility(fac);
                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(err), backgroundColor: Colors.red[800]),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${fac.name} Seviye $nextLevel seviyesine yükseltildi! 🚀'),
                            backgroundColor: Colors.green[800],
                          ),
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

  void _showSellFacilityConfirmation(
    BuildContext context,
    ProductionFacility fac,
    NumberFormat currencyFmt,
    bool isDark,
  ) {
    final invested = fac.totalInvestedValue;
    final refund = fac.resaleValue;
    const depreciationPercent = 30; // %70 iade, %30 kesinti

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF182032) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Text(fac.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${fac.name} Satılsın mı?',
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
                'Bu tesisi satıp ikinci el likidasyon bedeliyle nakite dönüştürmek istediğinizden emin misiniz? Satılan tesisler geri alınamaz.',
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
                          'Seviye ${fac.level}',
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
                final err = controller.sellFacility(fac);
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: Colors.red[800]),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${fac.name} satıldı ve ${currencyFmt.format(refund)} ₺ kasanıza aktarıldı! 💰'),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.sell_outlined, size: 16),
              label: const Text('Evet, Tesisi Sat'),
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

  Widget _buildStarterOptionsView(BuildContext context, bool isDark, NumberFormat currencyFmt) {
    final blueprints = ProductionFacility.getBlueprints();
    final wheatFarm = blueprints.firstWhere((b) => b.id == 'wheat_farm');
    final potatoField = blueprints.firstWhere((b) => b.id == 'potato_field');
    final fruitOrchard = blueprints.firstWhere((b) => b.id == 'fruit_orchard');
    final cottonField = blueprints.firstWhere((b) => b.id == 'cotton_field');
    final dairyFarm = blueprints.firstWhere((b) => b.id == 'dairy_farm');
    final flourMill = blueprints.firstWhere((b) => b.id == 'flour_mill');

    final starterPackages = [
      _StarterPackageData(
        title: '🌾 Entegre Un & Fırın Sanayisi',
        subtitle: '2x Buğday Tarlası + 1x Un Değirmeni (3 Tesis)',
        description: 'Tarlalarda buğday yetiştirip değirmende kaliteli una dönüştürür. Katma değeri yüksek eksiksiz sanayi zinciri!',
        productionRateText: '⚡ Dakikada: ~200 Buğday & ~12 Un',
        cost: 2 * wheatFarm.purchaseCost + flourMill.purchaseCost,
        items: [
          MapEntry(wheatFarm, 2),
          MapEntry(flourMill, 1),
        ],
        highlightColor: const Color(0xFFD97706),
      ),
      _StarterPackageData(
        title: '🥗 Çeşitli Tarım & Bahçe İmparatorluğu',
        subtitle: '1x Buğday + 1x Patates + 1x Meyve (3 Tesis)',
        description: '3 farklı temel hammaddeyi aynı anda üreterek borsa dalgalanmalarına karşı riskini dağıt ve maksimum kazanç sağla.',
        productionRateText: '⚡ Dakikada: ~261 Hammadde (100 Buğday, 92 Patates, 69 Meyve)',
        cost: wheatFarm.purchaseCost + potatoField.purchaseCost + fruitOrchard.purchaseCost,
        items: [
          MapEntry(wheatFarm, 1),
          MapEntry(potatoField, 1),
          MapEntry(fruitOrchard, 1),
        ],
        highlightColor: const Color(0xFF10B981),
      ),
      _StarterPackageData(
        title: '🐄 Mandıra & Hayvancılık Zinciri',
        subtitle: '2x Mandıra Çiftliği + 1x Buğday Tarlası (3 Tesis)',
        description: 'Peynir ve çikolata üreticilerinin aradığı Çiğ Sütü toptan sağla, yanına buğday hasadıyla güçlü bir nakit akışı kur.',
        productionRateText: '⚡ Dakikada: ~96 Çiğ Süt & ~100 Buğday',
        cost: 2 * dairyFarm.purchaseCost + wheatFarm.purchaseCost,
        items: [
          MapEntry(dairyFarm, 2),
          MapEntry(wheatFarm, 1),
        ],
        highlightColor: const Color(0xFF0284C7),
      ),
      _StarterPackageData(
        title: '🧶 Pamuk & Tekstil Başlangıcı',
        subtitle: '2x Pamuk Arazisi + 1x Buğday Tarlası (3 Tesis)',
        description: 'Tekstil sanayisi ve dokuma fabrikalarının ham pamuk ihtiyacını karşıla, yüksek kar marjıyla hızla büyü.',
        productionRateText: '⚡ Dakikada: ~90 Ham Pamuk & ~100 Buğday',
        cost: 2 * cottonField.purchaseCost + wheatFarm.purchaseCost,
        items: [
          MapEntry(cottonField, 2),
          MapEntry(wheatFarm, 1),
        ],
        highlightColor: const Color(0xFF8B5CF6),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hoş Geldiniz & Sermaye Başlık Kartı
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
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🚜', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Girişimcilik Dünyasına Hoş Geldin!',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          'Başlangıç Nakiti: ${currencyFmt.format(controller.cash)} ₺',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.amberAccent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Başlangıç sermayenizle doğrudan 3 tesis birden kurabilirsiniz! İster hazır sektör paketlerinden birini seçin, ister tesis kataloğundan dilediğiniz adetlerde seçim yapın.',
                style: TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          '🚀 Hazır Başlangıç Sektör Paketleri (3 Tesis)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tek dokunuşla birbirini tamamlayan tesisleri kurup anında üretime geçin:',
          style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
        ),
        const SizedBox(height: 10),

        ...starterPackages.map((pkg) {
          final canAfford = controller.cash >= pkg.cost;
          return Card(
            color: isDark ? const Color(0xFF1E283E) : Colors.white,
            margin: const EdgeInsets.only(bottom: 12),
            elevation: isDark ? 2 : 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: pkg.highlightColor.withOpacity(0.4),
                width: 1.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          pkg.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: pkg.highlightColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: pkg.highlightColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          '${currencyFmt.format(pkg.cost)} ₺',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pkg.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.lightBlueAccent : const Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pkg.description,
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),

                  // Dakika başı üretim hızı kutusu
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.speed, size: 14, color: isDark ? Colors.greenAccent : const Color(0xFF047857)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            pkg.productionRateText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.greenAccent : const Color(0xFF047857),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Kalan Bakiye: ${currencyFmt.format(controller.cash - pkg.cost)} ₺',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: canAfford
                            ? () => _confirmBuyStarterPackage(
                                  context,
                                  pkg.title,
                                  pkg.items,
                                  pkg.cost,
                                  isDark,
                                  currencyFmt,
                                )
                            : null,
                        icon: const Icon(Icons.rocket_launch_outlined, size: 14),
                        label: const Text('Bu Paketi Kur 🚀', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 14),

        // Serbest Seçim / Tesis Kataloğu Butonu
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161F33) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Text(
                'Kendi tesislerini ve adetlerini serbestçe seçmek ister misin?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => _showBuyFacilitySheet(context),
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: const Text('📋 Tüm Tesis Kataloğu & Adet Seçimi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.amber[700] : const Color(0xFFD97706),
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmBuyStarterPackage(
    BuildContext context,
    String packageName,
    List<MapEntry<ProductionFacility, int>> items,
    double cost,
    bool isDark,
    NumberFormat currencyFmt,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF182032) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Text('🚀', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$packageName Kurulumu',
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
              'Bu paketi onaylayarak 3 tesisi birden kurup anında üretime başlayacaksınız:',
              style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            ...items.map((entry) {
              final fac = entry.key;
              final count = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(fac.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$count adet ${fac.name}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Text(
                      '⚡ ~${(fac.baseItemsPerMinute * count).toStringAsFixed(0)} /dk',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('Paket Toplam Tutarı:', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : const Color(0xFF64748B))),
                ),
                Text(
                  '${currencyFmt.format(cost)} ₺',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('Satın Alma Sonrası Kalan:', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF94A3B8))),
                ),
                Text(
                  '${currencyFmt.format(controller.cash - cost)} ₺',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Vazgeç', style: TextStyle(color: isDark ? Colors.grey : const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              final err = controller.buyStarterPackage(
                packageName: packageName,
                facilities: items,
              );
              if (err != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err), backgroundColor: Colors.red[800]),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🎉 $packageName kuruldu! 3 tesisiniz üretime başladı.'),
                    backgroundColor: const Color(0xFF059669),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Evet, Paketi Kur 🚀'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.amberAccent[700] : const Color(0xFFD97706))
              : (isDark ? const Color(0xFF1E283E) : const Color(0xFFF1F5F9)),
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
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}

class _StarterPackageData {
  final String title;
  final String subtitle;
  final String description;
  final String productionRateText;
  final double cost;
  final List<MapEntry<ProductionFacility, int>> items;
  final Color highlightColor;

  const _StarterPackageData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.productionRateText,
    required this.cost,
    required this.items,
    required this.highlightColor,
  });
}

