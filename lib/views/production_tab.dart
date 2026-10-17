import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import '../models/facility.dart';
import '../models/item.dart';

class ProductionTab extends StatefulWidget {
  final GameController controller;

  const ProductionTab({super.key, required this.controller});

  @override
  State<ProductionTab> createState() => _ProductionTabState();
}

class _ProductionTabState extends State<ProductionTab> {
  int _selectedCategoryIndex = 0; // 0: Tümü, 1: Tarım & Kaynak, 2: Fabrika & Sanayi

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final currencyFmt = NumberFormat("#,##0", "tr_TR");
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.ownedFacilities.isEmpty) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: _buildEmptyState(context, isDark, currencyFmt),
          );
        }

        final blueprints = ProductionFacility.getBlueprints();
        final bpOrder = {for (int i = 0; i < blueprints.length; i++) blueprints[i].id: i};

        final totalCount = controller.ownedFacilities.length;
        final agriCount = controller.ownedFacilities.where((f) => f.type == FacilityType.agriculture).length;
        final factoryCount = controller.ownedFacilities.where((f) => f.type == FacilityType.factory).length;

        // Kategoriye göre filtrele
        final filteredFacilities = controller.ownedFacilities.where((fac) {
          if (_selectedCategoryIndex == 1) return fac.type == FacilityType.agriculture;
          if (_selectedCategoryIndex == 2) return fac.type == FacilityType.factory;
          return true;
        }).toList();

        // Aynı tür tesisleri alt alta getirmek için blueprint sırasına göre sırala
        filteredFacilities.sort((a, b) {
          final orderA = bpOrder[a.blueprintId] ?? 999;
          final orderB = bpOrder[b.blueprintId] ?? 999;
          if (orderA != orderB) {
            return orderA.compareTo(orderB);
          }
          final idxA = controller.ownedFacilities.indexOf(a);
          final idxB = controller.ownedFacilities.indexOf(b);
          return idxA.compareTo(idxB);
        });

        // Blueprint türü başına sahip olunan tesis haritası
        final Map<String, List<ProductionFacility>> sameTypeMap = {};
        for (final f in controller.ownedFacilities) {
          sameTypeMap.putIfAbsent(f.blueprintId, () => []).add(f);
        }

        final displayedTotalPerMin = filteredFacilities.fold<double>(
          0.0,
          (sum, f) => sum + f.itemsPerMinute,
        );

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  Text(
                    'Tesislerim ($totalCount)',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showBuyFacilitySheet(
                      context,
                      initialCategory: _selectedCategoryIndex == 1 ? 2 : (_selectedCategoryIndex == 2 ? 3 : 0),
                    ),
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
              const SizedBox(height: 12),

              // Kategori Sekmeleri (Tabs)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryTabItem(
                      index: 0,
                      title: 'Tümü',
                      count: totalCount,
                      icon: Icons.dashboard_outlined,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryTabItem(
                      index: 1,
                      title: '🌾 Tarım & Kaynak',
                      count: agriCount,
                      icon: Icons.agriculture_outlined,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryTabItem(
                      index: 2,
                      title: '🏭 Fabrika & Sanayi',
                      count: factoryCount,
                      icon: Icons.factory_outlined,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Toplam Üretim Gücü Özeti
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF132238), const Color(0xFF0E1A2B)]
                        : [const Color(0xFFF0FDFA), const Color(0xFFE6FFFA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF0D9488).withValues(alpha: 0.35)
                        : const Color(0xFF99F6E4),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withValues(alpha: isDark ? 0.1 : 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _selectedCategoryIndex == 1
                            ? Icons.agriculture_rounded
                            : (_selectedCategoryIndex == 2
                                ? Icons.factory_rounded
                                : Icons.speed_rounded),
                        size: 20,
                        color: isDark ? Colors.tealAccent : const Color(0xFF0D9488),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _selectedCategoryIndex == 0
                                  ? 'Toplam Üretim Kapasitesi'
                                  : (_selectedCategoryIndex == 1
                                      ? 'Tarım Üretim Kapasitesi'
                                      : 'Fabrika Üretim Kapasitesi'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                                color: isDark ? Colors.white : const Color(0xFF0F766E),
                              ),
                            ),
                          ),
                          const SizedBox(height: 1.5),
                          Text(
                            _selectedCategoryIndex == 0
                                ? '${filteredFacilities.length} aktif tesis devrede'
                                : (_selectedCategoryIndex == 1
                                    ? '${filteredFacilities.length} tarım tesisi devrede'
                                    : '${filteredFacilities.length} fabrika devrede'),
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0D9488).withValues(alpha: 0.22)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.tealAccent.withValues(alpha: 0.4)
                              : const Color(0xFF5EEAD4),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: Color(0xFF0D9488),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '~${displayedTotalPerMin.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.tealAccent : const Color(0xFF0D9488),
                            ),
                          ),
                          Text(
                            ' adet / dk',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.grey.shade400 : const Color(0xFF0F766E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (filteredFacilities.isEmpty)
                _buildEmptyCategoryView(context, isDark)
              else
                ..._buildFacilityListWithGroupHeaders(
                  context,
                  filteredFacilities,
                  sameTypeMap,
                  isDark,
                  currencyFmt,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryTabItem({
    required int index,
    required String title,
    required int count,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _selectedCategoryIndex == index;
    final primaryColor = index == 1
        ? (isDark ? Colors.greenAccent[400]! : const Color(0xFF10B981))
        : (index == 2
            ? (isDark ? Colors.blueAccent[400]! : const Color(0xFF3B82F6))
            : (isDark ? Colors.amberAccent[400]! : const Color(0xFFD97706)));

    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategoryIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? primaryColor.withOpacity(0.2) : primaryColor.withOpacity(0.12))
              : (isDark ? const Color(0xFF1E283C) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? primaryColor
                  : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor
                    : (isDark ? Colors.black26 : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? Colors.white70 : const Color(0xFF334155)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCategoryView(BuildContext context, bool isDark) {
    final isAgri = _selectedCategoryIndex == 1;
    final title = isAgri
        ? 'Henüz Tarım & Hammadde Tesisiniz Yok'
        : 'Henüz Fabrika & Sanayi Tesisiniz Yok';
    final desc = isAgri
        ? 'Tarlalar, maden ocakları veya çiftlikler kurarak sanayi tesislerinizin ihtiyacı olan hammaddeleri üretebilirsiniz.'
        : 'Tarlalarınızdan çıkan hammaddeleri işleyerek katma değerli nihai ürünler üretmek için yeni bir fabrika kurabilirsiniz.';
    final emoji = isAgri ? '🌾' : '🏭';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E283C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showBuyFacilitySheet(
              context,
              initialCategory: isAgri ? 2 : 3,
            ),
            icon: const Icon(Icons.add_business, size: 16),
            label: Text(isAgri ? 'Yeni Tarım Tesisi Satın Al' : 'Yeni Fabrika Satın Al'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.amber[700] : const Color(0xFFD97706),
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  String _getFacilityPluralTitle(String name) {
    if (name.contains('Buğday Tarlası')) return 'Buğday Tarlaları';
    if (name.contains('Patates Tarlası')) return 'Patates Tarlaları';
    if (name.contains('Pamuk Tarlası')) return 'Pamuk Tarlaları';
    if (name.contains('Meyve Bahçesi')) return 'Meyve Bahçeleri';
    if (name.contains('Mandıra Çiftliği')) return 'Mandıra Çiftlikleri';
    if (name.contains('Kahve Plantasyonu')) return 'Kahve Plantasyonları';
    if (name.contains('Kakao Plantasyonu')) return 'Kakao Plantasyonları';
    if (name.contains('Orman İşletmesi') || name.contains('Kereste')) return 'Kereste Kampları';
    if (name.contains('Demir Madeni') || name.contains('Maden Ocağı')) return 'Demir Maden Ocakları';
    if (name.contains('Petrol Sondaj') || name.contains('Sondaj Kulesi')) return 'Petrol Sondaj Kuleleri';
    if (name.contains('Un Değirmeni')) return 'Un Değirmenleri';
    if (name.contains('Ekmek Fırını')) return 'Ekmek Fırınları';
    if (name.contains('Patates İşleme')) return 'Patates İşleme Tesisleri';
    if (name.contains('Meyve Suyu')) return 'Meyve Suyu Tesisleri';
    if (name.contains('Kahve Kavurma')) return 'Kahve Kavurma Tesisleri';
    if (name.contains('Dokuma')) return 'Dokuma & İplik Fabrikaları';
    if (name.contains('Peynir Mandırası')) return 'Peynir Mandıraları';
    if (name.contains('Mobilya')) return 'Mobilya İmalathaneleri';
    if (name.contains('Çikolata Fabrikası')) return 'Çikolata Fabrikaları';
    if (name.contains('Çelik Döküm')) return 'Çelik Döküm Fabrikaları';
    if (name.contains('Elektronik')) return 'Elektronik Montaj Tesisleri';
    if (name.contains('Otomobil Fabrikası')) return 'Otomobil Fabrikaları';

    if (name.endsWith('Tarlası')) return name.replaceAll('Tarlası', 'Tarlaları');
    if (name.endsWith('Fabrikası')) return name.replaceAll('Fabrikası', 'Fabrikaları');
    if (name.endsWith('Çiftliği')) return name.replaceAll('Çiftliği', 'Çiftlikleri');
    if (name.endsWith('Bahçesi')) return name.replaceAll('Bahçesi', 'Bahçeleri');
    if (name.endsWith('Tesisi')) return name.replaceAll('Tesisi', 'Tesisleri');
    if (name.endsWith('Değirmeni')) return name.replaceAll('Değirmeni', 'Değirmenleri');
    if (name.endsWith('Fırını')) return name.replaceAll('Fırını', 'Fırınları');
    if (name.endsWith('Ocağı')) return name.replaceAll('Ocağı', 'Ocakları');
    if (name.endsWith('Kulesi')) return name.replaceAll('Kulesi', 'Kuleleri');
    return '$name Tesisleri';
  }

  String _getFacilityUnitCountText(String name, int count) {
    if (name.contains('Tarla') || name.contains('Tarlası')) return '($count tarla)';
    if (name.contains('Bahçe') || name.contains('Bahçesi')) return '($count bahçe)';
    if (name.contains('Çiftlik') || name.contains('Çiftliği')) return '($count çiftlik)';
    if (name.contains('Plantasyon')) return '($count plantasyon)';
    if (name.contains('Değirmen') || name.contains('Değirmeni')) return '($count değirmen)';
    if (name.contains('Fırın') || name.contains('Fırını')) return '($count fırın)';
    if (name.contains('Fabrika') || name.contains('Fabrikası')) return '($count fabrika)';
    if (name.contains('İmalathane')) return '($count atölye)';
    if (name.contains('Maden') || name.contains('Ocak')) return '($count ocak)';
    if (name.contains('Sondaj') || name.contains('Kule')) return '($count kule)';
    if (name.contains('Orman') || name.contains('Kereste')) return '($count kamp)';
    if (name.contains('Mandıra')) return '($count mandıra)';
    return '($count tesis)';
  }

  List<Widget> _buildFacilityListWithGroupHeaders(
    BuildContext context,
    List<ProductionFacility> filteredFacilities,
    Map<String, List<ProductionFacility>> sameTypeMap,
    bool isDark,
    NumberFormat currencyFmt,
  ) {
    final widgets = <Widget>[];

    for (int i = 0; i < filteredFacilities.length; i++) {
      final fac = filteredFacilities[i];
      final sameTypeFacilities = sameTypeMap[fac.blueprintId] ?? [fac];
      final isMultiple = sameTypeFacilities.length > 1;
      final facIndex = sameTypeFacilities.indexOf(fac) + 1;
      final isFirstOfGroup = i == 0 || filteredFacilities[i - 1].blueprintId != fac.blueprintId;

      // Aynı türden birden fazla tesis varsa, grubun ilk elemanının üstünde zarif bir küme başlığı göster
      if (isFirstOfGroup && isMultiple) {
        final groupTotalPerMin = sameTypeFacilities.fold<double>(
          0.0,
          (sum, f) => sum + f.itemsPerMinute,
        );
        final pluralTitle = _getFacilityPluralTitle(fac.name);
        final unitCountText = _getFacilityUnitCountText(fac.name, sameTypeFacilities.length);

        widgets.add(
          Container(
            margin: EdgeInsets.only(top: i == 0 ? 0 : 10, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF16233B), const Color(0xFF0F172A)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.tealAccent.withValues(alpha: 0.25) : const Color(0xFFCBD5E1),
                width: 1.1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(fac.emoji, style: const TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pluralTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        unitCountText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.tealAccent.shade100 : const Color(0xFF0D9488),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0D9488).withValues(alpha: 0.2)
                        : const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF0D9488).withValues(alpha: 0.4)
                          : const Color(0xFF99F6E4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.speed_rounded,
                        size: 12,
                        color: isDark ? Colors.tealAccent : const Color(0xFF0F766E),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Toplam ~${groupTotalPerMin.toStringAsFixed(0)} adet / dk',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.tealAccent : const Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      widgets.add(_buildFacilityCard(context, fac, isMultiple, facIndex, isDark, currencyFmt));
    }

    return widgets;
  }

  Widget _buildFacilityCard(
    BuildContext context,
    ProductionFacility fac,
    bool isMultiple,
    int facIndex,
    bool isDark,
    NumberFormat currencyFmt,
  ) {
    final controller = widget.controller;
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
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(
                            fac.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          if (isMultiple)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.amber.withOpacity(0.18) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? Colors.amberAccent.withOpacity(0.6) : const Color(0xFFF59E0B),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '#$facIndex',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                        ],
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
                              value: fac.isProducing ? fac.progress : 0.0,
                              minHeight: 8,
                              backgroundColor: isDark ? Colors.black38 : const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                !fac.isProducing
                                    ? Colors.grey
                                    : (fac.type == FacilityType.agriculture
                                        ? (isDark ? Colors.greenAccent[400]! : const Color(0xFF10B981))
                                        : (isDark ? Colors.cyanAccent[400]! : const Color(0xFF0284C7))),
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
                                    fontWeight: !fac.isProducing ? FontWeight.bold : FontWeight.normal,
                                    color: !fac.isProducing
                                        ? Colors.orangeAccent
                                        : (fac.statusMessage.contains('Dolu') || fac.statusMessage.contains('Bekleniyor')
                                            ? Colors.orangeAccent
                                            : (isDark ? Colors.white54 : const Color(0xFF64748B))),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Üretimi Durdur / Başlat Butonu
                              InkWell(
                                onTap: () => controller.toggleFacilityProducing(fac),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: fac.isProducing
                                        ? (isDark ? Colors.amber.withOpacity(0.12) : const Color(0xFFFEF3C7))
                                        : (isDark ? Colors.green.withOpacity(0.18) : const Color(0xFFD1FAE5)),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: fac.isProducing
                                          ? (isDark ? Colors.amberAccent.withOpacity(0.6) : const Color(0xFFD97706))
                                          : (isDark ? Colors.greenAccent : const Color(0xFF059669)),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        fac.isProducing ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                        size: 12,
                                        color: fac.isProducing
                                            ? (isDark ? Colors.amberAccent : const Color(0xFFB45309))
                                            : (isDark ? Colors.greenAccent : const Color(0xFF047857)),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        fac.isProducing ? 'Durdur' : 'Başlat',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: fac.isProducing
                                              ? (isDark ? Colors.amberAccent : const Color(0xFFB45309))
                                              : (isDark ? Colors.greenAccent : const Color(0xFF047857)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: InkWell(
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
                          ),
                        ],
                      ),
                    ),
                  );
  }

  void _showBuyFacilitySheet(BuildContext context, {int initialCategory = 0}) {
    final controller = widget.controller;
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
        int filterCategory = initialCategory; // 0: Tümü, 1: Başlangıç (≤15k), 2: Tarım & Kaynak, 3: Fabrika
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
                      Expanded(
                        child: Text(
                          '🌾 Yeni Tesis Satın Al (${filteredBlueprints.length})',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Text(
                    'Tesislerin üretim kapasitelerini inceleyerek bütçenize uygun tesisleri satın alabilirsiniz.',
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
                                ? () {
                                    controller.buyFacility(bp, quantity: 1);
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${bp.name} satın alındı ve üretime başladı! 🎉'),
                                        backgroundColor: const Color(0xFF059669),
                                      ),
                                    );
                                  }
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
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
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
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: canAfford
                                        ? () {
                                            controller.buyFacility(bp, quantity: 1);
                                            Navigator.pop(ctx);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('${bp.name} satın alındı ve üretime başladı! 🎉'),
                                                backgroundColor: const Color(0xFF059669),
                                              ),
                                            );
                                          }
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: canAfford
                                          ? (isDark ? Colors.green[600] : const Color(0xFF059669))
                                          : (isDark ? Colors.grey[800] : const Color(0xFFCBD5E1)),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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


  void _showUpgradeConfirmation(
    BuildContext context,
    ProductionFacility fac,
    NumberFormat currencyFmt,
    bool isDark,
  ) {
    final controller = widget.controller;
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
                    Expanded(
                      child: Text(
                        'Yetersiz Bakiye! Kasadaki para yetmiyor.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
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
    final controller = widget.controller;
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

  Widget _buildEmptyState(BuildContext context, bool isDark, NumberFormat currencyFmt) {
    final controller = widget.controller;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE6FFFA),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.tealAccent.withOpacity(0.3) : const Color(0xFF99F6E4),
                  width: 2,
                ),
              ),
              child: const Text('🚜', style: TextStyle(fontSize: 56)),
            ),
            const SizedBox(height: 20),
            Text(
              'Henüz bir üretim tesisiniz yok!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${currencyFmt.format(controller.cash)} ₺ başlangıç sermayenizle tarlalar veya fabrikalar kurabilir, ürettiğiniz hammaddeleri toptan pazarda veya dükkanlarınızda satarak büyütebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showBuyFacilitySheet(context),
              icon: const Icon(Icons.add_business, size: 20),
              label: const Text(
                '🌾 İlk Tesisini Satın Al',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.amber[700] : const Color(0xFFD97706),
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ],
        ),
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

