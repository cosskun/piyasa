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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: controller.ownedFacilities.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🚜', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 12),
                  const Text(
                    'Henüz bir tarla veya fabrikanız yok!',
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showBuyFacilitySheet(context),
                    icon: const Icon(Icons.add),
                    label: const Text('İlk Tarlanı Satın Al'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  )
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
                      'Tesislerim (${controller.ownedFacilities.length})',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showBuyFacilitySheet(context),
                      icon: const Icon(Icons.add_business, size: 18),
                      label: const Text('Yeni Tesis Al'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[700],
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...controller.ownedFacilities.map((fac) {
                  final outItem = ItemRegistry.get(fac.recipe.outputItemId);

                  return Card(
                    color: const Color(0xFF1E2638),
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: fac.type == FacilityType.agriculture
                            ? Colors.green.withOpacity(0.3)
                            : Colors.blue.withOpacity(0.3),
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
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(fac.emoji, style: const TextStyle(fontSize: 28)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          fac.name,
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
                                            'Sv. ${fac.level}',
                                            style: const TextStyle(fontSize: 11, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      fac.type == FacilityType.agriculture
                                          ? '🌿 Tarım: Hasat döngüsü'
                                          : '🏭 Fabrika: Reçete üretimi',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                    ),
                                  ],
                                ),
                              ),
                              // Geliştirme Butonu
                              OutlinedButton.icon(
                                onPressed: () {
                                  final err = controller.upgradeFacility(fac);
                                  if (err != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(err), backgroundColor: Colors.red[800]),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.arrow_upward, size: 14),
                                label: Text('${currencyFmt.format(fac.upgradeCost)} ₺'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.amberAccent,
                                  side: const BorderSide(color: Colors.amberAccent),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Reçete / Çıktı bilgisi
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                if (fac.recipe.inputs.isNotEmpty) ...[
                                  const Text('Girdi: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  ...fac.recipe.inputs.entries.map((e) {
                                    var item = ItemRegistry.get(e.key);
                                    return Text(
                                      '${e.value} ${item?.emoji ?? ''}  ',
                                      style: const TextStyle(fontSize: 12, color: Colors.white),
                                    );
                                  }),
                                  const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  'Çıktı: +${fac.effectiveOutput} ${outItem?.emoji ?? ''} ${outItem?.name ?? ''}  (${fac.effectiveDuration.toStringAsFixed(1)} sn)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.greenAccent[400],
                                    fontWeight: FontWeight.bold,
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
                              backgroundColor: Colors.black38,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                fac.type == FacilityType.agriculture
                                    ? Colors.greenAccent[400]!
                                    : Colors.cyanAccent[400]!,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            fac.statusMessage,
                            style: TextStyle(
                              fontSize: 11,
                              color: fac.statusMessage.contains('Dolu') || fac.statusMessage.contains('Bekleniyor')
                                  ? Colors.orangeAccent
                                  : Colors.white54,
                            ),
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

  void _showBuyFacilitySheet(BuildContext context) {
    final currencyFmt = NumberFormat("#,##0", "tr_TR");
    final blueprints = ProductionFacility.getBlueprints();

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
                    '🌾 Yeni Tesis Satın Al',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Text(
                'Tarlalar ham madde üretir, fabrikalar bunları işler.',
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
                          bp.description,
                          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        ),
                        trailing: ElevatedButton(
                          onPressed: canAfford
                              ? () {
                                  controller.buyFacility(bp);
                                  Navigator.pop(ctx);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canAfford ? Colors.green[600] : Colors.grey[800],
                            foregroundColor: Colors.white,
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
