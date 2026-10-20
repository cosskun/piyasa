import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import '../models/facility.dart';
import '../models/item.dart';
import '../widgets/game_toast.dart';

class FacilitySupplyChain {
  final String id;
  final String title;
  final String emoji;
  final String description;
  final List<String> stepsBlueprintIds;

  const FacilitySupplyChain({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.stepsBlueprintIds,
  });
}

const List<FacilitySupplyChain> kDefaultSupplyChains = [
  FacilitySupplyChain(
    id: 'grain_bakery',
    title: 'Tahıl & Ekmek Zinciri',
    emoji: '🌾 ➡️ 🥣 ➡️ 🥖',
    description: 'Tarladan sofraya un ve ekmek üretim döngüsü',
    stepsBlueprintIds: ['wheat_farm', 'flour_mill', 'bakery_facility'],
  ),
  FacilitySupplyChain(
    id: 'dairy_cheese',
    title: 'Süt & Peynir Zinciri',
    emoji: '🐄 ➡️ 🧀',
    description: 'Çiftlikten mandıraya çiğ süt ve taze peynir üretimi',
    stepsBlueprintIds: ['dairy_farm', 'cheese_factory'],
  ),
  FacilitySupplyChain(
    id: 'potato_fries',
    title: 'Patates & Fast-Food Zinciri',
    emoji: '🥔 ➡️ 🍟',
    description: 'Patates hasadı ve endüstriyel çıtır patates imalatı',
    stepsBlueprintIds: ['potato_field', 'fries_processing'],
  ),
  FacilitySupplyChain(
    id: 'fruit_juice',
    title: 'Meyve & İçecek Sanayisi',
    emoji: '🍊 ➡️ 🧃',
    description: 'Narenciye bahçesi ve doğal meyve suyu dolum hattı',
    stepsBlueprintIds: ['fruit_orchard', 'juice_factory'],
  ),
  FacilitySupplyChain(
    id: 'coffee_chain',
    title: 'Kahve Plantasyonu & Kavurma',
    emoji: '🌿 ➡️ ☕',
    description: 'Tropikal kahve çekirdeği hasadı ve taze kahve kavurma',
    stepsBlueprintIds: ['coffee_plantation', 'coffee_roastery', 'coffee_brewery'],
  ),
  FacilitySupplyChain(
    id: 'textile_fashion',
    title: 'Tekstil & Moda Zinciri',
    emoji: '🧶 ➡️ 🧵 ➡️ 👗',
    description: 'Ham pamuk lifinden kumaş dokuma ve hazır giyim dikimi',
    stepsBlueprintIds: ['cotton_field', 'weaving_factory', 'garment_atelier'],
  ),
  FacilitySupplyChain(
    id: 'leather_fashion',
    title: 'Deri Sanayisi & Moda Zinciri',
    emoji: '🐄 ➡️ 🧳 ➡️ 🧥',
    description: 'Mandıradan ham deri, tabakhaneden işlenmiş deri ve konfeksiyonda deri ceket',
    stepsBlueprintIds: ['dairy_farm', 'leather_tannery', 'garment_atelier'],
  ),
  FacilitySupplyChain(
    id: 'cocoa_chocolate',
    title: 'Kakao & Gurme Çikolata',
    emoji: '🍫 + 🥛 ➡️ 🎁',
    description: 'Kakao ağacı ve süt harmanıyla artisan çikolata imalatı',
    stepsBlueprintIds: ['cocoa_plantation', 'chocolate_factory'],
  ),
  FacilitySupplyChain(
    id: 'timber_furniture',
    title: 'Ağaç & Mobilya Sanayisi',
    emoji: '🌲 ➡️ 🪚 ➡️ 🪑',
    description: 'Orman tomruğu, hızarda kereste ve tasarım ahşap mobilya',
    stepsBlueprintIds: ['lumber_camp', 'sawmill', 'furniture_factory'],
  ),
  FacilitySupplyChain(
    id: 'heavy_tech',
    title: 'Ağır Sanayi & Yüksek Teknoloji',
    emoji: '⛏️ + 🛢️ ➡️ 🏗️ + 🧪 ➡️ 🔬',
    description: 'Demir ve petrol madenciliğinden çelik, plastik ve akıllı telefon',
    stepsBlueprintIds: ['iron_mine', 'oil_derrick', 'steel_mill', 'petrochem_plant', 'electronics_factory'],
  ),
];

class ProductionTab extends StatefulWidget {
  final GameController controller;

  const ProductionTab({super.key, required this.controller});

  @override
  State<ProductionTab> createState() => _ProductionTabState();
}

class _ProductionTabState extends State<ProductionTab> {
  int _selectedCategoryIndex = 0; // 0: Tümü, 1: Tarım & Kaynak, 2: Fabrika & Sanayi
  int _selectedViewMode = 0; // 0: Konsolide & Akordeon (Varsayılan), 1: Tedarik Zinciri (Akış)
  final Set<String> _collapsedBlueprintIds = {}; // Varsayılan olarak tüm gruplar açık başlar

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
            physics: const BouncingScrollPhysics(),
            cacheExtent: 600,
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
              const SizedBox(height: 10),

              // ==========================================
              // GÖRÜNÜM MODU SEÇİCİ (1. Konsolide / 2. Tedarik Zinciri)
              // ==========================================
              Container(
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131C2E) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildViewModeToggleBtn(
                        mode: 0,
                        icon: Icons.layers_rounded,
                        label: 'Konsolide (Akordeon)',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildViewModeToggleBtn(
                        mode: 1,
                        icon: Icons.alt_route_rounded,
                        label: 'Tedarik Zinciri',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ==========================================
              // CANLI NET ÜRETİM BİLANÇOSU BARI
              // ==========================================
              _buildNetProductionBalanceBar(context, controller, isDark),

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
              else if (_selectedViewMode == 1)
                _buildSupplyChainView(context, controller, isDark, currencyFmt)
              else
                ..._buildConsolidatedFacilityList(
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
    if (name.contains('Tabakhane')) return 'Deri Tabakhaneleri';
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
    if (name.contains('Tabakhane')) return '($count tabakhane)';
    return '($count tesis)';
  }

  Widget _buildViewModeToggleBtn({
    required int mode,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _selectedViewMode == mode;
    return InkWell(
      onTap: () {
        if (_selectedViewMode != mode) {
          setState(() {
            _selectedViewMode = mode;
          });
        }
      },
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (mode == 0
                  ? (isDark ? const Color(0xFF0D9488) : const Color(0xFF0F766E))
                  : (isDark ? const Color(0xFF2563EB) : const Color(0xFF1D4ED8)))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (mode == 0 ? const Color(0xFF0D9488) : const Color(0xFF2563EB))
                        .withValues(alpha: 0.35),
                    blurRadius: 6,
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
              size: 15,
              color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetProductionBalanceBar(
    BuildContext context,
    GameController controller,
    bool isDark,
  ) {
    // Toplam üretim çıktılarını topla
    final Map<String, double> prodMap = {};
    for (final f in controller.ownedFacilities) {
      if (f.isProducing) {
        prodMap[f.recipe.outputItemId] = (prodMap[f.recipe.outputItemId] ?? 0.0) + f.itemsPerMinute;
      }
    }

    if (prodMap.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B132B) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFA7F3D0),
        ),
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
                    const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Net Üretim Akışı (Canlı Bilanço)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${prodMap.length} Çeşit Ürün',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : const Color(0xFF047857),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: prodMap.entries.map((entry) {
                final item = ItemRegistry.get(entry.key);
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF132A24) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF059669).withValues(alpha: 0.4) : const Color(0xFF6EE7B7),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item?.emoji ?? '📦', style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        '+${entry.value.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '/dk',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey[400] : const Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 1. KONSOLİDE & AKORDEON GÖRÜNÜM LİSTESİ
  // ==========================================
  List<Widget> _buildConsolidatedFacilityList(
    BuildContext context,
    List<ProductionFacility> filteredFacilities,
    Map<String, List<ProductionFacility>> sameTypeMap,
    bool isDark,
    NumberFormat currencyFmt,
  ) {
    final widgets = <Widget>[];
    final seenBlueprints = <String>{};

    for (final fac in filteredFacilities) {
      if (seenBlueprints.contains(fac.blueprintId)) continue;
      seenBlueprints.add(fac.blueprintId);

      final group = sameTypeMap[fac.blueprintId] ?? [fac];
      widgets.add(
        _buildConsolidatedGroupCard(
          context,
          fac.blueprintId,
          group,
          isDark,
          currencyFmt,
        ),
      );
    }

    return widgets;
  }

  Widget _buildConsolidatedGroupCard(
    BuildContext context,
    String blueprintId,
    List<ProductionFacility> group,
    bool isDark,
    NumberFormat currencyFmt,
  ) {
    final firstFac = group.first;
    final isMultiple = group.length > 1;
    final isExpanded = !_collapsedBlueprintIds.contains(blueprintId);
    final activeCount = group.where((f) => f.isProducing).length;
    final totalCount = group.length;

    final groupTotalPerMin = group.fold<double>(0.0, (sum, f) => sum + f.itemsPerMinute);
    final pluralTitle = _getFacilityPluralTitle(firstFac.name);
    final unitCountText = _getFacilityUnitCountText(firstFac.name, totalCount);

    // Seviye dağılımı özeti
    final Map<int, int> levelMap = {};
    for (final f in group) {
      levelMap[f.level] = (levelMap[f.level] ?? 0) + 1;
    }
    final sortedLevels = levelMap.keys.toList()..sort();
    final levelSummary = sortedLevels.map((lvl) => '${levelMap[lvl]}x Sv.$lvl').join(', ');

    // Ortalama üretim ilerlemesi
    final activeFacilities = group.where((f) => f.isProducing).toList();
    final avgProgress = activeFacilities.isEmpty
        ? 0.0
        : activeFacilities.fold<double>(0.0, (s, f) => s + f.progress) / activeFacilities.length;

    // Toplam geliştirme maliyeti
    final totalUpgradeCost = group.fold<double>(0.0, (s, f) => s + f.upgradeCost);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E283C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: firstFac.type == FacilityType.agriculture
              ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFF86EFAC))
              : (isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.4) : const Color(0xFF93C5FD)),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==========================================
          // 1. KONSOLİDE KART BAŞLIĞI (AKORDEON TETİKLEYİCİ)
          // ==========================================
          InkWell(
            onTap: () {
              setState(() {
                if (_collapsedBlueprintIds.contains(blueprintId)) {
                  _collapsedBlueprintIds.remove(blueprintId);
                } else {
                  _collapsedBlueprintIds.add(blueprintId);
                }
              });
            },
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: Radius.circular(isExpanded ? 0 : 16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Emoji Kutusu
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(firstFac.emoji, style: const TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 10),

                      // İsim & Özet
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    isMultiple ? pluralTitle : firstFac.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                if (isMultiple) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF0D9488).withValues(alpha: 0.25)
                                          : const Color(0xFFCCFBF1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF14B8A6).withValues(alpha: 0.4)
                                            : const Color(0xFF5EEAD4),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      unitCountText,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                Text(
                                  '⚡ ~${groupTotalPerMin.toStringAsFixed(0)}/dk',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.tealAccent : const Color(0xFF0D9488),
                                  ),
                                ),
                                Text(
                                  '•',
                                  style: TextStyle(color: isDark ? Colors.grey : const Color(0xFF94A3B8)),
                                ),
                                Text(
                                  levelSummary,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            if (firstFac.availableRecipes.length > 1) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.4) : const Color(0xFFBFDBFE),
                                          width: 0.6,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.tune_rounded, size: 10, color: Color(0xFF3B82F6)),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              isMultiple
                                                  ? '${group.map((f) => f.recipe.outputItemId).toSet().length} Farklı Üretim Bandı'
                                                  : 'Reçete: ${firstFac.recipe.name ?? (ItemRegistry.get(firstFac.recipe.outputItemId)?.name ?? firstFac.recipe.outputItemId)}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Aktiflik Durumu ve Ok
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: activeCount == totalCount
                                  ? (isDark ? const Color(0xFF065F46) : const Color(0xFFD1FAE5))
                                  : (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$activeCount/$totalCount Aktif',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: activeCount == totalCount
                                    ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46))
                                    : (isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Ortalama İlerleme Çubuğu
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: avgProgress,
                      minHeight: 5,
                      backgroundColor: isDark ? Colors.black38 : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        activeCount == 0
                            ? Colors.grey
                            : (firstFac.type == FacilityType.agriculture
                                ? const Color(0xFF10B981)
                                : const Color(0xFF3B82F6)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ==========================================
          // 2. AÇILIR AKORDEON ALANI (ALT TESİS SATIRLARI)
          // ==========================================
          if (isExpanded) ...[
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141C2B) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Toplu İşlem Butonları (Eğer birden fazla tesis varsa)
                  if (isMultiple)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _batchToggleFacilityGroup(group),
                              icon: Icon(
                                activeCount > 0 ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                size: 14,
                              ),
                              label: Text(
                                activeCount > 0 ? 'Tümünü Durdur' : 'Tümünü Başlat',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                                side: BorderSide(
                                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                                ),
                              ),
                            ),
                          ),
                          if (firstFac.availableRecipes.length > 1) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showRecipeSelectionSheet(context, firstFac, batchGroup: group),
                                icon: const Icon(Icons.tune_rounded, size: 14),
                                label: const Text(
                                  'Toplu Reçete',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                                  foregroundColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                  side: BorderSide(
                                    color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : const Color(0xFF93C5FD),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _batchUpgradeFacilityGroup(
                                group,
                                totalUpgradeCost,
                                pluralTitle,
                              ),
                              icon: const Icon(Icons.arrow_upward_rounded, size: 14),
                              label: Text(
                                'Tümünü Bas (${currencyFmt.format(totalUpgradeCost)} ₺)',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFFD97706) : const Color(0xFFF59E0B),
                                foregroundColor: isDark ? Colors.black : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Her Bir Tesis Satırı
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(10),
                    itemCount: group.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final fac = group[idx];
                      return _buildConsolidatedSubRow(
                        ctx,
                        fac,
                        idx + 1,
                        isDark,
                        currencyFmt,
                        isMultiple: isMultiple,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConsolidatedSubRow(
    BuildContext context,
    ProductionFacility fac,
    int facIndex,
    bool isDark,
    NumberFormat currencyFmt, {
    bool isMultiple = false,
  }) {
    final controller = widget.controller;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E283C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // #1 / #2 Rozeti
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.amber.withValues(alpha: 0.18) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? Colors.amberAccent.withValues(alpha: 0.6) : const Color(0xFFF59E0B),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '#$facIndex',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Çoklu tesis durumunda bireysel tesis adını göster (örn: Buğday Tarlası)
              if (isMultiple) ...[
                Flexible(
                  child: Text(
                    fac.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],

              // Seviye
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Sv. ${fac.level}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Üretim hızı
              Flexible(
                child: Text(
                  '+${fac.itemsPerMinute.toStringAsFixed(0)}/dk',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.greenAccent[400] : const Color(0xFF059669),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Geliştirme Butonu
              InkWell(
                onTap: () => _showUpgradeConfirmation(context, fac, currencyFmt, isDark),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.amber.withValues(alpha: 0.15) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_upward_rounded,
                        size: 11,
                        color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${currencyFmt.format(fac.upgradeCost)} ₺',
                        style: TextStyle(
                          fontSize: 10.5,
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
          const SizedBox(height: 8),

          // Aktif Reçete & Çıktı Çubuğu
          Builder(
            builder: (ctx) {
              final activeRecipe = fac.recipe;
              final outItem = ItemRegistry.get(activeRecipe.outputItemId);
              final hasMultipleRecipes = fac.availableRecipes.length > 1;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141C2B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasMultipleRecipes
                        ? (isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.35) : const Color(0xFF93C5FD))
                        : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(outItem?.emoji ?? '📦', style: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  activeRecipe.name ?? (outItem?.name ?? activeRecipe.outputItemId),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (hasMultipleRecipes) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${fac.availableRecipes.length} Reçete',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activeRecipe.inputs.isEmpty
                                ? '🌱 Doğal Üretim: +${fac.effectiveOutput} adet / ${fac.effectiveDuration.toStringAsFixed(1)}s'
                                : 'Girdi: ${activeRecipe.inputs.entries.map((e) => "${e.value}x ${ItemRegistry.get(e.key)?.emoji ?? ''}${ItemRegistry.get(e.key)?.name ?? e.key}").join(', ')} ➔ +${fac.effectiveOutput} ${outItem?.emoji ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasMultipleRecipes) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _showRecipeSelectionSheet(context, fac),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            ),
                            borderRadius: BorderRadius.circular(7),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.swap_horiz_rounded, size: 13, color: Colors.white),
                              SizedBox(width: 3),
                              Text(
                                'Reçete Seç ▾',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          // İlerleme Çubuğu
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fac.isProducing ? fac.progress : 0.0,
              minHeight: 6,
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

          // Durum Mesajı
          Row(
            children: [
              Expanded(
                child: Text(
                  fac.statusMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: !fac.isProducing ? FontWeight.bold : FontWeight.normal,
                    color: !fac.isProducing
                        ? Colors.orangeAccent
                        : (fac.statusMessage.contains('Dolu') || fac.statusMessage.contains('Bekleniyor')
                            ? Colors.orangeAccent
                            : (isDark ? Colors.white54 : const Color(0xFF64748B))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Eylem Butonları
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 6,
            children: [
              // Üretimi Durdur / Başlat Butonu
              InkWell(
                onTap: () => controller.toggleFacilityProducing(fac),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: fac.isProducing
                        ? (isDark ? Colors.amber.withValues(alpha: 0.12) : const Color(0xFFFEF3C7))
                        : (isDark ? Colors.green.withValues(alpha: 0.18) : const Color(0xFFD1FAE5)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: fac.isProducing
                          ? (isDark ? Colors.amberAccent.withValues(alpha: 0.6) : const Color(0xFFD97706))
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

              // Tesisi Sat Butonu
              InkWell(
                onTap: () => _showSellFacilityConfirmation(context, fac, currencyFmt, isDark),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.red.withValues(alpha: 0.12) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? Colors.redAccent.withValues(alpha: 0.5) : const Color(0xFFFCA5A5),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sell_outlined,
                        size: 11,
                        color: isDark ? Colors.redAccent : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Tesisi Sat (${currencyFmt.format(fac.resaleValue)} ₺)',
                        style: TextStyle(
                          fontSize: 10,
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
    );
  }

  void _batchToggleFacilityGroup(List<ProductionFacility> group) {
    final anyProducing = group.any((f) => f.isProducing);
    for (final f in group) {
      if (anyProducing && f.isProducing) {
        widget.controller.toggleFacilityProducing(f);
      } else if (!anyProducing && !f.isProducing) {
        widget.controller.toggleFacilityProducing(f);
      }
    }
    GameToast.showInfo(
      context,
      anyProducing ? 'Gruptaki tüm tesisler durduruldu.' : 'Gruptaki tüm tesisler başlatıldı.',
      title: 'Toplu Durum',
    );
  }

  void _batchUpgradeFacilityGroup(
    List<ProductionFacility> group,
    double totalCost,
    String pluralTitle,
  ) {
    final controller = widget.controller;
    final currencyFmt = NumberFormat("#,##0", "tr_TR");

    if (controller.cash < totalCost) {
      GameToast.showWarning(
        context,
        'Yetersiz bakiye! Gerekli: ${currencyFmt.format(totalCost)} ₺ (Kasanız: ${currencyFmt.format(controller.cash)} ₺)',
        title: 'Bakiye Yetersiz',
      );
      return;
    }

    for (final f in group) {
      controller.upgradeFacility(f);
    }

    GameToast.showSuccess(
      context,
      '$pluralTitle (${group.length} tesis) 1 seviye geliştirildi! ⚡',
      title: 'Toplu Geliştirme',
    );
  }

  // ==========================================
  // 2. TEDARİK ZİNCİRİ (AKIŞ ŞEMASI) GÖRÜNÜMÜ
  // ==========================================
  Widget _buildSupplyChainView(
    BuildContext context,
    GameController controller,
    bool isDark,
    NumberFormat currencyFmt,
  ) {
    final allBlueprints = ProductionFacility.getBlueprints();
    final bpMap = {for (final b in allBlueprints) b.id: b};

    final visibleChains = kDefaultSupplyChains.where((chain) {
      if (_selectedCategoryIndex == 1) {
        return chain.stepsBlueprintIds.any((id) => bpMap[id]?.type == FacilityType.agriculture);
      }
      if (_selectedCategoryIndex == 2) {
        return chain.stepsBlueprintIds.any((id) => bpMap[id]?.type == FacilityType.factory);
      }
      return true;
    }).toList();

    // Sahip olunan tesis sayısına göre sırala (oyuncunun tesisleri olan zincirler üstte çıksın)
    visibleChains.sort((a, b) {
      final countA = controller.ownedFacilities.where((f) => a.stepsBlueprintIds.contains(f.blueprintId)).length;
      final countB = controller.ownedFacilities.where((f) => b.stepsBlueprintIds.contains(f.blueprintId)).length;
      return countB.compareTo(countA);
    });

    return Column(
      children: visibleChains.map((chain) {
        return _buildSupplyChainCard(
          context,
          chain,
          bpMap,
          controller,
          isDark,
          currencyFmt,
        );
      }).toList(),
    );
  }

  Widget _buildSupplyChainCard(
    BuildContext context,
    FacilitySupplyChain chain,
    Map<String, ProductionFacility> bpMap,
    GameController controller,
    bool isDark,
    NumberFormat currencyFmt,
  ) {
    final ownedInChain = controller.ownedFacilities.where((f) => chain.stepsBlueprintIds.contains(f.blueprintId)).toList();
    final hasAnyOwned = ownedInChain.isNotEmpty;

    // Zincir içi girdi / çıktı dengesini hesapla
    final firstStepBpId = chain.stepsBlueprintIds.first;
    final firstStepBp = bpMap[firstStepBpId];
    final firstStepOwned = ownedInChain.where((f) => f.blueprintId == firstStepBpId).toList();
    final rawProductionPerMin = firstStepOwned.where((f) => f.isProducing).fold<double>(0.0, (s, f) => s + f.itemsPerMinute);

    double rawConsumptionPerMin = 0.0;
    if (firstStepBp != null) {
      final rawItemId = firstStepBp.recipe.outputItemId;
      for (final fac in ownedInChain) {
        if (fac.isProducing && fac.recipe.inputs.containsKey(rawItemId)) {
          final neededPerCycle = fac.recipe.inputs[rawItemId]!;
          rawConsumptionPerMin += (neededPerCycle * 60.0) / fac.effectiveDuration;
        }
      }
    }

    final hasFactory = ownedInChain.any((f) => f.type == FacilityType.factory);

    String statusText;
    Color statusBgColor;
    Color statusTextColor;
    IconData statusIcon;

    if (!hasAnyOwned) {
      statusText = 'Henüz Başlanmadı';
      statusBgColor = isDark ? const Color(0xFF334155).withValues(alpha: 0.3) : const Color(0xFFF1F5F9);
      statusTextColor = isDark ? Colors.grey[400]! : const Color(0xFF64748B);
      statusIcon = Icons.info_outline_rounded;
    } else if (hasFactory && firstStepOwned.isEmpty) {
      statusText = 'Tarlanız Yok (Depo / Borsa)';
      statusBgColor = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFDBEAFE);
      statusTextColor = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF);
      statusIcon = Icons.storefront_rounded;
    } else if (hasFactory && rawProductionPerMin < rawConsumptionPerMin) {
      final deficit = rawConsumptionPerMin - rawProductionPerMin;
      statusText = 'Hammadde Açığı (-${deficit.toStringAsFixed(0)} /dk)';
      statusBgColor = isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7);
      statusTextColor = isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
      statusIcon = Icons.warning_amber_rounded;
    } else if (hasFactory && rawProductionPerMin >= rawConsumptionPerMin) {
      final surplus = rawProductionPerMin - rawConsumptionPerMin;
      statusText = surplus > 1.0
          ? 'Kendi Kendine Yetiyor (+${surplus.toStringAsFixed(0)} /dk Fazla)'
          : 'Tam Dengede';
      statusBgColor = isDark ? const Color(0xFF065F46).withValues(alpha: 0.3) : const Color(0xFFD1FAE5);
      statusTextColor = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46);
      statusIcon = Icons.check_circle_rounded;
    } else {
      statusText = 'Hammadde İhracatı (+${rawProductionPerMin.toStringAsFixed(0)} /dk)';
      statusBgColor = isDark ? const Color(0xFF0F766E).withValues(alpha: 0.3) : const Color(0xFFCCFBF1);
      statusTextColor = isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E);
      statusIcon = Icons.agriculture_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E283C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasAnyOwned
              ? (isDark ? const Color(0xFF0D9488).withValues(alpha: 0.4) : const Color(0xFF5EEAD4))
              : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          width: hasAnyOwned ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık & Durum
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              chain.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        chain.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusTextColor.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusTextColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Adımlar (Steps)
            for (int i = 0; i < chain.stepsBlueprintIds.length; i++) ...[
              if (i > 0)
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131C2E) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_downward_rounded,
                          size: 11,
                          color: isDark ? Colors.tealAccent : const Color(0xFF0D9488),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Girdi Olarak Besliyor',
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
              _buildSupplyChainStepRow(
                context,
                chain.stepsBlueprintIds[i],
                i + 1,
                bpMap,
                controller,
                isDark,
                currencyFmt,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSupplyChainStepRow(
    BuildContext context,
    String blueprintId,
    int stepNumber,
    Map<String, ProductionFacility> bpMap,
    GameController controller,
    bool isDark,
    NumberFormat currencyFmt,
  ) {
    final bp = bpMap[blueprintId];
    if (bp == null) return const SizedBox.shrink();

    final ownedList = controller.ownedFacilities.where((f) => f.blueprintId == blueprintId).toList();
    final ownedCount = ownedList.length;
    final isOwned = ownedCount > 0;
    final activeCount = ownedList.where((f) => f.isProducing).length;
    final totalProd = ownedList.where((f) => f.isProducing).fold<double>(0.0, (s, f) => s + f.itemsPerMinute);
    final outItem = ItemRegistry.get(bp.recipe.outputItemId);

    final stepLabel = stepNumber == 1
        ? '1. Basamak: Hammadde'
        : (stepNumber == 2 ? '2. Basamak: Ara İşleme' : '3. Basamak: Nihai Ürün');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141C2B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOwned
              ? (isDark ? const Color(0xFF0D9488).withValues(alpha: 0.35) : const Color(0xFF99F6E4))
              : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          // Emoji
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
            ),
            alignment: Alignment.center,
            child: Text(bp.emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 10),

          // Bilgiler
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      stepLabel,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isOwned
                            ? (isDark ? const Color(0xFF065F46) : const Color(0xFFD1FAE5))
                            : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isOwned ? '$ownedCount Adet ($activeCount Aktif)' : 'Henüz Yok',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isOwned
                              ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46))
                              : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  bp.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      isOwned
                          ? 'Üretim: +${totalProd.toStringAsFixed(0)} ${outItem?.emoji ?? ''}/dk'
                          : 'Temel: ~${bp.recipe.itemsPerMinute.toStringAsFixed(0)} ${outItem?.emoji ?? ''}/dk',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isOwned
                            ? (isDark ? Colors.greenAccent[400] : const Color(0xFF059669))
                            : (isDark ? Colors.grey : const Color(0xFF64748B)),
                      ),
                    ),
                    if (bp.recipe.inputs.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text('•', style: TextStyle(color: isDark ? Colors.grey : const Color(0xFF94A3B8))),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Girdi: ${bp.recipe.inputs.entries.map((e) => '${e.value} ${ItemRegistry.get(e.key)?.emoji ?? ''}').join(', ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Eylem Butonu
          if (!isOwned)
            ElevatedButton(
              onPressed: () => _showBuyFacilitySheet(context, initialCategory: bp.type == FacilityType.agriculture ? 2 : 3),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFFD97706) : const Color(0xFFF59E0B),
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Al (${currencyFmt.format(bp.purchaseCost)} ₺)',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            )
          else
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _selectedViewMode = 0; // Konsolide görünüme dön
                  _collapsedBlueprintIds.remove(blueprintId); // Grubunu aç
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                side: BorderSide(color: isDark ? Colors.tealAccent : const Color(0xFF0D9488)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded, size: 11, color: isDark ? Colors.tealAccent : const Color(0xFF0D9488)),
                  const SizedBox(width: 3),
                  Text(
                    'Yönet',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.tealAccent : const Color(0xFF0D9488),
                    ),
                  ),
                ],
              ),
            ),
        ],
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
                                    GameToast.showSuccess(
                                      context,
                                      '${bp.name} satın alındı ve üretime başladı! 🎉',
                                      title: 'Tesis Kuruldu',
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
                                        if (bp.availableRecipes.length > 1) ...[
                                          const SizedBox(height: 3),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(5),
                                              border: Border.all(
                                                color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.4) : const Color(0xFFBFDBFE),
                                                width: 0.6,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.tune_rounded, size: 10, color: Color(0xFF3B82F6)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '✨ ${bp.availableRecipes.length} Farklı Reçete Desteği',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
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
                                              Flexible(
                                                child: Text(
                                                  '⚡ Dakikada: ~${bp.baseItemsPerMinute.toStringAsFixed(0)} adet',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.greenAccent : const Color(0xFF047857),
                                                  ),
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
                                        ? () {
                                            controller.buyFacility(bp, quantity: 1);
                                            Navigator.pop(ctx);
                                            GameToast.showSuccess(
                                              context,
                                              '${bp.name} satın alındı ve üretime başladı! 🎉',
                                              title: 'Tesis Kuruldu',
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

  void _showRecipeSelectionSheet(
    BuildContext context,
    ProductionFacility facility, {
    List<ProductionFacility>? batchGroup,
  }) {
    final controller = widget.controller;
    final currencyFmt = NumberFormat("#,##0", "tr_TR");
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recipes = facility.availableRecipes;

    // Eğer birden fazla aynı tür tesis varsa toplu uygulama seçeneği
    final matchingFacilities = batchGroup ??
        controller.ownedFacilities.where((f) => f.blueprintId == facility.blueprintId).toList();
    final bool canBatch = matchingFacilities.length > 1;
    bool applyToAll = batchGroup != null && batchGroup.length > 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF141926) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sürükleme Tutamacı
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Başlık Satırı
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(facility.emoji, style: const TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${facility.name} - Üretim Reçetesi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Üretim hattını değiştirmek istediğiniz ürünü seçin.',
                              style: TextStyle(
                                fontSize: 11.5,
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

                  // Toplu Uygulama Onay Kutusu
                  if (canBatch) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          setSheetState(() => applyToAll = !applyToAll);
                        },
                        child: Row(
                          children: [
                            Checkbox(
                              value: applyToAll,
                              onChanged: (val) {
                                setSheetState(() => applyToAll = val ?? false);
                              },
                              activeColor: const Color(0xFF2563EB),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Bu seçimi gruptaki tüm (${matchingFacilities.length}) tesise uygula',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Reçete Listesi
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: recipes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final recipe = recipes[i];
                        final isCurrent = facility.activeRecipeIndex == i;
                        final outItem = ItemRegistry.get(recipe.outputItemId);

                        // Girdi bilgileri
                        final List<Widget> inputWidgets = [];

                        if (recipe.inputs.isEmpty) {
                          inputWidgets.add(
                            Text(
                              '🌱 Doğal Hammadde (Girdi gerektirmez)',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.tealAccent : const Color(0xFF0D9488),
                              ),
                            ),
                          );
                        } else {
                          for (final entry in recipe.inputs.entries) {
                            final inItem = ItemRegistry.get(entry.key);
                            final currentStock = controller.warehouse[entry.key] ?? 0;
                            final needed = entry.value;
                            final isEnough = currentStock >= needed;

                            inputWidgets.add(
                              Container(
                                margin: const EdgeInsets.only(right: 6, bottom: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isEnough
                                      ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
                                      : (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isEnough
                                        ? (isDark ? const Color(0xFF10B981) : const Color(0xFF34D399))
                                        : (isDark ? const Color(0xFFF59E0B) : const Color(0xFFFBBF24)),
                                    width: 0.7,
                                  ),
                                ),
                                child: Text(
                                  '${inItem?.emoji ?? ''} ${inItem?.name ?? entry.key}: $needed (Depo: $currentStock)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isEnough
                                        ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46))
                                        : (isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E)),
                                  ),
                                ),
                              ),
                            );
                          }
                        }

                        final retailPotential = (outItem?.retailSuggestedPrice ?? outItem?.basePrice ?? 0.0) * recipe.outputAmount;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFEFF6FF))
                                : (isDark ? const Color(0xFF1E283C) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isCurrent
                                  ? const Color(0xFF3B82F6)
                                  : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                              width: isCurrent ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Üst Başlık & Aktif Rozeti
                              Row(
                                children: [
                                  Text(
                                    outItem?.emoji ?? '📦',
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          recipe.name ?? (outItem?.name ?? recipe.outputItemId),
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          outItem?.description ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isCurrent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF10B981), width: 1),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                                          SizedBox(width: 3),
                                          Text(
                                            'AKTİF BAND',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF10B981),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Girdiler
                              Wrap(
                                children: inputWidgets,
                              ),
                              const SizedBox(height: 6),

                              // Çıktı & Hız & Piyasa Getirisi
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black26 : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Çıktı & Hız',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            '+${recipe.outputAmount}x ${outItem?.name ?? ''} (${recipe.durationSeconds.toStringAsFixed(1)}s)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 24,
                                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Perakende Değeri',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            '~${currencyFmt.format(retailPotential)} ₺ / döngü',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Reçeteyi Uygula Butonu
                              if (!isCurrent)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      if (applyToAll && canBatch) {
                                        for (final f in matchingFacilities) {
                                          controller.setFacilityRecipe(f, i);
                                        }
                                        Navigator.pop(ctx);
                                        GameToast.showSuccess(
                                          context,
                                          '${matchingFacilities.length} tesis ${recipe.name ?? outItem?.name} üretimine ayarlandı!',
                                          title: 'Toplu Reçete Güncellendi',
                                        );
                                      } else {
                                        controller.setFacilityRecipe(facility, i);
                                        Navigator.pop(ctx);
                                        GameToast.showSuccess(
                                          context,
                                          '${facility.name} artık ${recipe.name ?? outItem?.name} üretiyor!',
                                          title: 'Reçete Değiştirildi',
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.flash_on_rounded, size: 14),
                                    label: Text(
                                      applyToAll && canBatch
                                          ? 'Tüm ${facility.name} Tesislerini Bu Reçeteye Ayarla'
                                          : 'Bu Reçeteye Geç',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
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
                        GameToast.showError(context, err, title: 'Yükseltme Başarısız');
                      } else {
                        GameToast.showSuccess(
                          context,
                          '${fac.name} Seviye $nextLevel seviyesine yükseltildi! 🚀',
                          title: 'Tesis Yükseltildi',
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
                  GameToast.showError(context, err, title: 'Satış Başarısız');
                } else {
                  GameToast.showSuccess(
                    context,
                    '${fac.name} satıldı ve ${currencyFmt.format(refund)} ₺ kasanıza aktarıldı! 💰',
                    title: 'Tesis Satıldı',
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

