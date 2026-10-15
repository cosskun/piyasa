import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import '../models/item.dart';

class MarketTab extends StatefulWidget {
  final GameController controller;

  const MarketTab({super.key, required this.controller});

  @override
  State<MarketTab> createState() => _MarketTabState();
}

class _MarketTabState extends State<MarketTab> {
  ItemCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat("#,##0.00", "tr_TR");
    final items = widget.controller.marketItems.values.where((m) {
      if (_selectedCategory == null) return true;
      return m.data.category == _selectedCategory;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Kategori Filtre Butonları
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Tüm Borsa', null),
                  const SizedBox(width: 8),
                  _buildFilterChip('🌾 Tarlalar (Hammadde)', ItemCategory.rawMaterial),
                  const SizedBox(width: 8),
                  _buildFilterChip('🏭 Fabrika (Ara Mamul)', ItemCategory.intermediate),
                  const SizedBox(width: 8),
                  _buildFilterChip('🥖 Perakende Mamuller', ItemCategory.finishedGood),
                ],
              ),
            ),
          ),

          // Bilgi Kartı
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E283E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.lightBlueAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pazar Fiyatları her 15 saniyede bir arz-talebe göre güncellenir. Tarladan çıkan malı hemen pazara toptan satıp nakite çevirebilirsiniz.',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Emtia Listesi
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final mItem = items[i];
                final inStock = widget.controller.warehouse[mItem.itemId] ?? 0;
                final isPositive = mItem.lastChangePercent >= 0;

                return Card(
                  color: const Color(0xFF1B2234),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isPositive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(mItem.data.emoji, style: const TextStyle(fontSize: 26)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mItem.data.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    mItem.data.description,
                                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Fiyat Değişim Rozeti
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPositive
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${isPositive ? '▲ +' : '▼ '}${mItem.lastChangePercent}%',
                                style: TextStyle(
                                  color: isPositive ? Colors.greenAccent : Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 20),

                        // Fiyat ve Depo Bilgisi
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Toptan Alış', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                                Text(
                                  '${currencyFmt.format(mItem.wholesaleBuyPrice)} ₺',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.lightBlueAccent,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Pazara Satış', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                                Text(
                                  '${currencyFmt.format(mItem.wholesaleSellPrice)} ₺',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.greenAccent,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: inStock > 0 ? Colors.amber.withOpacity(0.15) : Colors.black26,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warehouse_outlined, size: 14, color: Colors.amberAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Deponda: $inStock',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: inStock > 0 ? Colors.amberAccent : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Al / Sat Aksiyon Butonları
                        Row(
                          children: [
                            // Pazardan Toptan Satın Al Butonu
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showTradeDialog(context, mItem, isBuy: true),
                                icon: const Icon(Icons.shopping_cart_checkout, size: 16),
                                label: const Text('Toptan Al'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF263B66),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Pazara Toptan Sat Butonu (Sıcak Nakit!)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: inStock > 0
                                    ? () => _showTradeDialog(context, mItem, isBuy: false)
                                    : null,
                                icon: const Icon(Icons.sell_outlined, size: 16),
                                label: const Text('Pazara Sat'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: inStock > 0 ? Colors.green[700] : Colors.grey[800],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, ItemCategory? cat) {
    final isSelected = _selectedCategory == cat;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedCategory = cat),
      selectedColor: Colors.blueAccent[700],
      backgroundColor: const Color(0xFF1E283E),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[300],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  void _showTradeDialog(BuildContext context, dynamic mItem, {required bool isBuy}) {
    int qty = 10;
    final inStock = widget.controller.warehouse[mItem.itemId] ?? 0;
    final maxCanSell = inStock;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final unitPrice = isBuy ? mItem.wholesaleBuyPrice : mItem.wholesaleSellPrice;
            final total = unitPrice * qty;

            return AlertDialog(
              backgroundColor: const Color(0xFF182032),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Text(mItem.data.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text(
                    isBuy ? '${mItem.data.name} Satın Al' : '${mItem.data.name} Pazara Sat',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isBuy
                        ? 'Fabrikada işlemek veya dükkanında satmak için toptan al.'
                        : 'Tarladan/fabrikadan çıkan malı anında nakite çevir.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: qty > 1 ? () => setDialogState(() => qty = (qty - 5).clamp(1, 10000)) : null,
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.white70),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$qty Adet',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setDialogState(() => qty += 5),
                        icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Hızlı seçim butonları
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _quickQtyBtn(setDialogState, () => qty = 10, '10'),
                      const SizedBox(width: 6),
                      _quickQtyBtn(setDialogState, () => qty = 50, '50'),
                      const SizedBox(width: 6),
                      _quickQtyBtn(setDialogState, () => qty = 100, '100'),
                      if (!isBuy && maxCanSell > 0) ...[
                        const SizedBox(width: 6),
                        _quickQtyBtn(setDialogState, () => qty = maxCanSell, 'Tümü ($maxCanSell)'),
                      ],
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Toplam Tutar:', style: TextStyle(color: Colors.white70)),
                      Text(
                        '${total.toStringAsFixed(2)} ₺',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isBuy ? Colors.lightBlueAccent : Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Vazgeç', style: TextStyle(color: Colors.grey)),
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
                                : '$qty adet ${mItem.data.name} pazara satıldı! (+${total.toStringAsFixed(0)} ₺)',
                          ),
                          backgroundColor: Colors.green[800],
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBuy ? Colors.blueAccent[700] : Colors.greenAccent[700],
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isBuy ? 'Satın Al' : 'Pazara Sat'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _quickQtyBtn(void Function(void Function()) setDialogState, VoidCallback onTap, String label) {
    return InkWell(
      onTap: () => setDialogState(onTap),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ),
    );
  }
}
