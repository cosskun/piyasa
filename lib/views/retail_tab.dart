import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import '../models/item.dart';
import '../models/store.dart';

class RetailTab extends StatelessWidget {
  final GameController controller;

  const RetailTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat("#,##0", "tr_TR");
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: controller.ownedStores.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🏪', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 12),
                  Text(
                    'Henüz bir perakende dükkanınız yok!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'İster sadece toptan pazarda ticaret yapın, isterseniz dükkan açıp müşterilere perakende kârla satın.',
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
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                ...controller.ownedStores.map((store) {
                  final prod = ItemRegistry.get(store.productItemId);
                  final shelfRatio = (store.shelfStock / store.shelfCapacity).clamp(0.0, 1.0);

                  return Card(
                    color: isDark ? const Color(0xFF1E2638) : Colors.white,
                    margin: const EdgeInsets.only(bottom: 14),
                    elevation: isDark ? 2 : 1.5,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(store.emoji, style: const TextStyle(fontSize: 28)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          store.name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Satılan: ${prod?.emoji ?? ''} ${prod?.name ?? ''} (Birim Satış: ${store.retailPrice.toStringAsFixed(0)} ₺)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Geliştir Butonu (Doğrulama İle)
                              OutlinedButton.icon(
                                onPressed: () => _showUpgradeStoreConfirmation(context, store, currencyFmt, isDark),
                                icon: const Icon(Icons.arrow_upward, size: 14),
                                label: Text('${currencyFmt.format(store.upgradeCost)} ₺'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                  side: BorderSide(
                                    color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Raf Durumu
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Raf Stoğu: ${store.shelfStock} / ${store.shelfCapacity}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    'Depodan Otomatik Çek',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                    ),
                                  ),
                                  Switch(
                                    value: store.autoRestock,
                                    onChanged: (val) {
                                      controller.toggleStoreAutoRestock(store, val);
                                    },
                                    activeThumbColor: isDark ? Colors.greenAccent : const Color(0xFF059669),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: shelfRatio,
                              minHeight: 8,
                              backgroundColor: isDark ? Colors.black38 : const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                shelfRatio > 0.2
                                    ? (isDark ? Colors.amberAccent : const Color(0xFFF59E0B))
                                    : Colors.redAccent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Müşteri Satış Sayacı
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                store.statusMessage,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: store.shelfStock > 0
                                      ? (isDark ? Colors.greenAccent[400] : const Color(0xFF059669))
                                      : Colors.orangeAccent,
                                ),
                              ),
                              Text(
                                'Toplam Ciro: ${currencyFmt.format(store.totalRevenue)} ₺',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
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
                'Dükkanlar müşterilere perakende satış yaparak düzenli nakit akışı sağlar.',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: blueprints.length,
                  itemBuilder: (ctx, i) {
                    final bp = blueprints[i];
                    final canAfford = controller.cash >= bp.purchaseCost;

                    return Card(
                      color: isDark ? const Color(0xFF1F283C) : const Color(0xFFF8FAFC),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark ? Colors.transparent : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: ListTile(
                        leading: Text(bp.emoji, style: const TextStyle(fontSize: 32)),
                        title: Text(
                          bp.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: Text(
                          '${bp.description}\nBirim Satış: ${bp.retailPrice.toStringAsFixed(0)} ₺',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          ),
                        ),
                        trailing: ElevatedButton(
                          onPressed: canAfford
                              ? () {
                                  controller.buyStore(bp);
                                  Navigator.pop(ctx);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canAfford
                                ? (isDark ? Colors.amber[700] : const Color(0xFFD97706))
                                : (isDark ? Colors.grey[800] : const Color(0xFFCBD5E1)),
                            foregroundColor: canAfford && !isDark ? Colors.white : Colors.black,
                          ),
                          child: Text('${currencyFmt.format(bp.purchaseCost)} ₺'),
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
                    Row(
                      children: [
                        const Icon(Icons.shelves, size: 16, color: Colors.amberAccent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Raf kapasitesi +25 adet genişler',
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(err), backgroundColor: Colors.red[800]),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${store.name} Seviye $nextLevel seviyesine yükseltildi! 🏪'),
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
}
