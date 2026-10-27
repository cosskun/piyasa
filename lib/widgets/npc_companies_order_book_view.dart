import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import '../models/npc_company.dart';
import '../models/item.dart';

class NpcCompaniesOrderBookView extends StatefulWidget {
  final GameController controller;

  const NpcCompaniesOrderBookView({
    super.key,
    required this.controller,
  });

  @override
  State<NpcCompaniesOrderBookView> createState() => _NpcCompaniesOrderBookViewState();
}

class _NpcCompaniesOrderBookViewState extends State<NpcCompaniesOrderBookView> {
  final TextEditingController _searchController = TextEditingController();
  static final NumberFormat _currencyFmt = NumberFormat("#,##0.00", "tr_TR");

  String _searchQuery = '';
  String _selectedSector = 'Tümü';
  int _filterMode = 0; // 0: Tümü, 1: Acil Alıcılar, 2: Depomdaki Malları Arayanlar, 3: Satış Teklifi Olanlar

  final List<String> _sectors = [
    'Tümü',
    'Tarım & Tahıl',
    'Değirmencilik',
    'Fırıncılık',
    'Mandıra & Şarküteri',
    'İplik & Kumaş',
    'Moda & Tasarım',
    'Kerestecilik',
    'Mobilya & Dekorasyon',
    'Kahve Endüstrisi',
    'Ağır Metalurji',
    'Petrokimya & Polimer',
    'Tüketici Elektroniği',
    'Ulusal Perakende',
    'Uluslararası Dış Ticaret',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = widget.controller;

    // Şirket filtreleme
    final filteredCompanies = c.npcCompanies.where((comp) {
      // 1. Arama sorgusu (Şirket adı, slogan veya talep ettiği/sattığı ürün adı)
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final nameMatch = comp.name.toLowerCase().contains(query);
        final sectorMatch = comp.sector.toLowerCase().contains(query);
        final itemMatch = comp.inputItemIds.any((id) => (ItemRegistry.get(id)?.name.toLowerCase().contains(query) ?? false)) ||
            comp.outputItemIds.any((id) => (ItemRegistry.get(id)?.name.toLowerCase().contains(query) ?? false));
        if (!nameMatch && !sectorMatch && !itemMatch) return false;
      }

      // 2. Sektör filtresi
      if (_selectedSector != 'Tümü' && !comp.sector.contains(_selectedSector)) {
        return false;
      }

      // 3. Durum filtre modu
      if (_filterMode == 1) {
        // Acil Alıcılar (Kritik kıtlık yaşayanlar)
        final hasCritical = comp.buyBids.values.any((b) => b.urgency == NpcBidUrgency.critical);
        if (!hasCritical) return false;
      } else if (_filterMode == 2) {
        // Depomdaki malları arayanlar
        final hasWarehouseMatch = comp.inputItemIds.any((id) => (c.warehouse[id] ?? 0) > 0);
        if (!hasWarehouseMatch) return false;
      } else if (_filterMode == 3) {
        // Satış teklifi olanlar
        if (comp.sellOffers.isEmpty) return false;
      }

      return true;
    }).toList();

    // İstatistiki özetler
    final criticalCount = c.npcCompanies.where((comp) => comp.buyBids.values.any((b) => b.urgency == NpcBidUrgency.critical)).length;
    final totalLiquidity = c.npcCompanies.fold<double>(0.0, (sum, comp) => sum + comp.capital);

    return Column(
      children: [
        // === 1. ÜST BİLGİ & PİYASA İNTEL ÇUBUĞU ===
        Container(
          margin: const EdgeInsets.fromLTRB(14, 4, 14, 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFFF8FAFC), const Color(0xFFEEF2F6)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.corporate_fare_rounded, size: 18, color: Color(0xFF3B82F6)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          '${c.npcCompanies.length} Aktif Piyasa Şirketi',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Canlı Emirler',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '🔥 $criticalCount Acil Alıcı  •  💼 Toplam Likidite: ${_currencyFmt.format(totalLiquidity)} ₺',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // === 2. ARAMA VE FİLTRELEME ÇUBUĞU ===
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Şirket veya ürün ara (buğday, un, kumaş)...',
                      hintStyle: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(Icons.search, size: 17, color: Color(0xFF64748B)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // === 3. FİLTRE MODU SEÇİCİLER (CHIPS) ===
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          child: Row(
            children: [
              _buildFilterChip(label: 'Tümü', mode: 0, isDark: isDark),
              const SizedBox(width: 6),
              _buildFilterChip(label: '🔥 Acil Alıcılar', mode: 1, isDark: isDark),
              const SizedBox(width: 6),
              _buildFilterChip(label: '📦 Depomdaki Mallar', mode: 2, isDark: isDark),
              const SizedBox(width: 6),
              _buildFilterChip(label: '📤 Satış Teklifleri', mode: 3, isDark: isDark),
            ],
          ),
        ),

        // === 4. SEKTÖR LİSTESİ (YATAY KAYDIRMA) ===
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          child: Row(
            children: _sectors.map((sec) {
              final isSelected = _selectedSector == sec;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(sec, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedSector = sec);
                  },
                  selectedColor: const Color(0xFF2563EB),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
                  ),
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 4),

        // === 5. ŞİRKET LİSTESİ ===
        Expanded(
          child: filteredCompanies.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                  itemCount: filteredCompanies.length,
                  itemBuilder: (context, index) {
                    return _buildCompanyCard(filteredCompanies[index], isDark, c);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({required String label, required int mode, required bool isDark}) {
    final isSelected = _filterMode == mode;
    return InkWell(
      onTap: () => setState(() => _filterMode = mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyCard(NpcCompany comp, bool isDark, GameController c) {
    Color strategyColor;
    String strategyLabel;
    switch (comp.strategy) {
      case NpcStrategy.aggressive:
        strategyColor = const Color(0xFFF59E0B);
        strategyLabel = '⚡ Agresif Alıcı';
        break;
      case NpcStrategy.balanced:
        strategyColor = const Color(0xFF3B82F6);
        strategyLabel = '⚖️ Dengeli Sanayici';
        break;
      case NpcStrategy.bargainHunter:
        strategyColor = const Color(0xFF8B5CF6);
        strategyLabel = '🎯 Fırsatçı Tüccar';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Şirket Başlığı & Profil
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: Center(
                    child: Text(comp.emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              comp.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: strategyColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: strategyColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              strategyLabel,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: strategyColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        comp.motto,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Metrik Çubuğu (Kasa, Depo, Durum)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              border: Border.symmetric(
                horizontal: BorderSide(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, size: 13, color: Colors.green),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Kasa: ${_currencyFmt.format(comp.capital)} ₺',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 13, color: Colors.blue),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Depo: ${comp.totalStoredItems}/${comp.maxStorageCapacity}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Şirket Alış Emirleri (Oyuncudan Satın Alır - Oyuncu Satabilir)
          if (comp.buyBids.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  const Icon(Icons.call_received_rounded, size: 13, color: Colors.green),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'ŞİRKETİN ALIŞ EMİRLERİ (Deponuzdan Satın)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            ...comp.buyBids.entries.map((bidEntry) {
              final itemId = bidEntry.key;
              final bid = bidEntry.value;
              final item = ItemRegistry.get(itemId);
              final playerStock = c.warehouse[itemId] ?? 0;
              final isCritical = bid.urgency == NpcBidUrgency.critical;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isCritical
                      ? Colors.orange.withValues(alpha: isDark ? 0.12 : 0.08)
                      : (isDark ? const Color(0xFF162032) : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: isCritical
                        ? Colors.orange.withValues(alpha: 0.4)
                        : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    Text(item?.emoji ?? '📦', style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item?.name ?? itemId,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCritical) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '🔥 ACİL (+%12)',
                                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.orange),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'Alış: ${_currencyFmt.format(bid.pricePerUnit)} ₺ • Talep: ${bid.demandedQuantity} adet (Sizde: $playerStock)',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: playerStock > 0 && comp.capital >= bid.pricePerUnit
                          ? () => _showDirectSellSheet(context, comp: comp, itemId: itemId, bid: bid)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isDark ? Colors.white10 : Colors.grey[300],
                        disabledForegroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        minimumSize: const Size(60, 30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                        elevation: 0,
                      ),
                      child: const Text('Sat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }),
          ],

          // Şirket Satış Teklifleri (Şirket Satar - Oyuncu Satın Alabilir)
          if (comp.sellOffers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  const Icon(Icons.call_made_rounded, size: 13, color: Colors.blue),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'ŞİRKETİN SATIŞ TEKLİFLERİ (Fabrikanız İçin Satın Alın)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            ...comp.sellOffers.entries.map((offerEntry) {
              final itemId = offerEntry.key;
              final offer = offerEntry.value;
              final item = ItemRegistry.get(itemId);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF162032) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Text(item?.emoji ?? '📦', style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item?.name ?? itemId,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Satış: ${_currencyFmt.format(offer.pricePerUnit)} ₺ • Mevcut: ${offer.availableQuantity} adet',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: offer.availableQuantity > 0 && c.cash >= offer.pricePerUnit
                          ? () => _showDirectBuySheet(context, comp: comp, itemId: itemId, offer: offer)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isDark ? Colors.white10 : Colors.grey[300],
                        disabledForegroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        minimumSize: const Size(60, 30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                        elevation: 0,
                      ),
                      child: const Text('Satın Al', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: isDark ? Colors.grey[600] : Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'Aramanıza uygun piyasa şirketi bulunamadı.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Filtreleri temizleyerek veya farklı bir ürün aratarak tekrar deneyin.',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // === ANINDA ŞİRKETE SATIŞ MODALI ===
  void _showDirectSellSheet(BuildContext context, {
    required NpcCompany comp,
    required String itemId,
    required NpcBuyBid bid,
  }) {
    final c = widget.controller;
    final item = ItemRegistry.get(itemId);
    final playerStock = c.warehouse[itemId] ?? 0;
    final maxByCapital = bid.pricePerUnit > 0 ? (comp.capital / bid.pricePerUnit).floor() : 0;
    final maxSellable = max(0, min(playerStock, min(bid.demandedQuantity, maxByCapital)));

    int selectedQty = max(1, min(maxSellable, 25));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final totalRevenue = selectedQty * bid.pricePerUnit;

            return Container(
              padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(modalCtx).viewInsets.bottom + 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(item?.emoji ?? '📦', style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${comp.name} Şirketine Satış',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Ürün: ${item?.name ?? itemId}  •  Birim Fiyat: ${_currencyFmt.format(bid.pricePerUnit)} ₺',
                              style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Satılacak Miktar:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[300] : const Color(0xFF334155))),
                      Text('$selectedQty adet', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    ],
                  ),
                  Slider(
                    value: selectedQty.toDouble(),
                    min: 1.0,
                    max: max(1.0, maxSellable.toDouble()),
                    divisions: max(1, maxSellable - 1),
                    activeColor: const Color(0xFF10B981),
                    onChanged: maxSellable > 1
                        ? (val) => setModalState(() => selectedQty = val.round())
                        : null,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildQuickQtyPill('25%', (maxSellable * 0.25).round(), (q) => setModalState(() => selectedQty = max(1, q)), isDark),
                      const SizedBox(width: 6),
                      _buildQuickQtyPill('50%', (maxSellable * 0.50).round(), (q) => setModalState(() => selectedQty = max(1, q)), isDark),
                      const SizedBox(width: 6),
                      _buildQuickQtyPill('MAX ($maxSellable)', maxSellable, (q) => setModalState(() => selectedQty = max(1, q)), isDark),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kasanıza Geçecek Net:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                        Text(
                          '+${_currencyFmt.format(totalRevenue)} ₺',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: selectedQty > 0
                          ? () {
                              Navigator.pop(ctx);
                              final error = c.sellToNpcCompany(
                                company: comp,
                                itemId: itemId,
                                quantity: selectedQty,
                              );
                              if (error != null) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🤝 $selectedQty adet ${item?.name} ${comp.name} şirketine başarıyla satıldı! (+${_currencyFmt.format(totalRevenue)} ₺)'),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('Anında Sat & Nakiti Al', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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

  // === ANINDA ŞİRKETTEN SATIN ALMA MODALI ===
  void _showDirectBuySheet(BuildContext context, {
    required NpcCompany comp,
    required String itemId,
    required NpcSellOffer offer,
  }) {
    final c = widget.controller;
    final item = ItemRegistry.get(itemId);
    final maxByCash = offer.pricePerUnit > 0 ? (c.cash / offer.pricePerUnit).floor() : 0;
    final weight = item?.weight ?? 1.0;
    final maxByWarehouse = weight > 0 ? ((c.maxWarehouseCapacity - c.currentWarehouseWeight) / weight).floor() : 0;
    final maxBuyable = max(0, min(offer.availableQuantity, min(maxByCash, maxByWarehouse)));

    int selectedQty = max(1, min(maxBuyable, 20));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final totalCost = selectedQty * offer.pricePerUnit;

            return Container(
              padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(modalCtx).viewInsets.bottom + 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(item?.emoji ?? '📦', style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${comp.name} Şirketinden Alım',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Ürün: ${item?.name ?? itemId}  •  Birim Fiyat: ${_currencyFmt.format(offer.pricePerUnit)} ₺',
                              style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Satın Alınacak Miktar:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[300] : const Color(0xFF334155))),
                      Text('$selectedQty adet', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    ],
                  ),
                  Slider(
                    value: selectedQty.toDouble(),
                    min: 1.0,
                    max: max(1.0, maxBuyable.toDouble()),
                    divisions: max(1, maxBuyable - 1),
                    activeColor: const Color(0xFF2563EB),
                    onChanged: maxBuyable > 1
                        ? (val) => setModalState(() => selectedQty = val.round())
                        : null,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildQuickQtyPill('25%', (maxBuyable * 0.25).round(), (q) => setModalState(() => selectedQty = max(1, q)), isDark),
                      const SizedBox(width: 6),
                      _buildQuickQtyPill('50%', (maxBuyable * 0.50).round(), (q) => setModalState(() => selectedQty = max(1, q)), isDark),
                      const SizedBox(width: 6),
                      _buildQuickQtyPill('MAX ($maxBuyable)', maxBuyable, (q) => setModalState(() => selectedQty = max(1, q)), isDark),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Ödenecek Toplam Tutar:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        Text(
                          '${_currencyFmt.format(totalCost)} ₺',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: selectedQty > 0
                          ? () {
                              Navigator.pop(ctx);
                              final error = c.buyFromNpcCompany(
                                company: comp,
                                itemId: itemId,
                                quantity: selectedQty,
                              );
                              if (error != null) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('📦 $selectedQty adet ${item?.name} ${comp.name} şirketinden teslim alındı! (-${_currencyFmt.format(totalCost)} ₺)'),
                                    backgroundColor: const Color(0xFF2563EB),
                                  ),
                                );
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('Depoma Satın Al', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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

  Widget _buildQuickQtyPill(String label, int qty, Function(int) onSelect, bool isDark) {
    return InkWell(
      onTap: () => onSelect(qty),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey[300] : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
