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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: controller.ownedStores.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🏪', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 12),
                  const Text(
                    'Henüz bir perakende dükkanınız yok!',
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'İster sadece toptan pazarda ticaret yapın, isterseniz dükkan açıp müşterilere perakende kârla satın.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showBuyStoreSheet(context),
                    icon: const Icon(Icons.storefront),
                    label: const Text('İlk Dükkanını Aç'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[700],
                      foregroundColor: Colors.black,
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
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showBuyStoreSheet(context),
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Yeni Dükkan Aç'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[700],
                        foregroundColor: Colors.black,
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
                    color: const Color(0xFF1E2638),
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.amber.withOpacity(0.3)),
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
                                  color: Colors.black26,
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
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blueGrey[800],
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Sv. ${store.level}',
                                            style: const TextStyle(fontSize: 11, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Satılan: ${prod?.emoji ?? ''} ${prod?.name ?? ''} (Birim Satış: ${store.retailPrice.toStringAsFixed(0)} ₺)',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                    ),
                                  ],
                                ),
                              ),
                              // Geliştir Butonu
                              OutlinedButton.icon(
                                onPressed: () {
                                  final err = controller.upgradeStore(store);
                                  if (err != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(err), backgroundColor: Colors.red[800]),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.arrow_upward, size: 14),
                                label: Text('${currencyFmt.format(store.upgradeCost)} ₺'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.amberAccent,
                                  side: const BorderSide(color: Colors.amberAccent),
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
                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                              Row(
                                children: [
                                  Text(
                                    'Depodan Otomatik Çek',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                                  ),
                                  Switch(
                                    value: store.autoRestock,
                                    onChanged: (val) {
                                      store.autoRestock = val;
                                      controller.notifyListeners();
                                    },
                                    activeColor: Colors.greenAccent,
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
                              backgroundColor: Colors.black38,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                shelfRatio > 0.2 ? Colors.amberAccent : Colors.redAccent,
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
                                  color: store.shelfStock > 0 ? Colors.greenAccent[400] : Colors.orangeAccent,
                                ),
                              ),
                              Text(
                                'Toplam Ciro: ${currencyFmt.format(store.totalRevenue)} ₺',
                                style: const TextStyle(fontSize: 11, color: Colors.white54),
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

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141926),
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
                  const Text(
                    '🏪 Yeni Dükkan Aç',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Text(
                'Dükkanlar müşterilere perakende satış yaparak düzenli nakit akışı sağlar.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: blueprints.length,
                  itemBuilder: (ctx, i) {
                    final bp = blueprints[i];
                    final canAfford = controller.cash >= bp.purchaseCost;

                    return Card(
                      color: const Color(0xFF1F283C),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: Text(bp.emoji, style: const TextStyle(fontSize: 32)),
                        title: Text(
                          bp.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        subtitle: Text(
                          '${bp.description}\nBirim Satış: ${bp.retailPrice.toStringAsFixed(0)} ₺',
                          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        ),
                        trailing: ElevatedButton(
                          onPressed: canAfford
                              ? () {
                                  controller.buyStore(bp);
                                  Navigator.pop(ctx);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canAfford ? Colors.amber[700] : Colors.grey[800],
                            foregroundColor: Colors.black,
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
}
