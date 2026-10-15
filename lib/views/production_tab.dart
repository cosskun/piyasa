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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: controller.ownedFacilities.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🚜', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 12),
                  Text(
                    'Henüz bir tarla veya fabrikanız yok!',
                    style: TextStyle(
                      fontSize: 18,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showBuyFacilitySheet(context),
                    icon: const Icon(Icons.add),
                    label: const Text('İlk Tarlanı Satın Al'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
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
                const SizedBox(height: 12),
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
                                    Row(
                                      children: [
                                        Text(
                                          fac.name,
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
                                            'Sv. ${fac.level}',
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
                              // Geliştirme Butonu (İkinci Doğrulama İle)
                              OutlinedButton.icon(
                                onPressed: () => _showUpgradeConfirmation(context, fac, currencyFmt, isDark),
                                icon: const Icon(Icons.arrow_upward, size: 14),
                                label: Text('${currencyFmt.format(fac.upgradeCost)} ₺'),
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
                          Text(
                            fac.statusMessage,
                            style: TextStyle(
                              fontSize: 11,
                              color: fac.statusMessage.contains('Dolu') || fac.statusMessage.contains('Bekleniyor')
                                  ? Colors.orangeAccent
                                  : (isDark ? Colors.white54 : const Color(0xFF64748B)),
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
                    '🌾 Yeni Tesis Satın Al',
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
                'Tarlalar ham madde üretir, fabrikalar bunları işler.',
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
                          bp.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          ),
                        ),
                        trailing: ElevatedButton(
                          onPressed: canAfford
                              ? () {
                                  controller.buyFacility(bp);
                                  Navigator.pop(ctx);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canAfford
                                ? (isDark ? Colors.green[600] : const Color(0xFF059669))
                                : (isDark ? Colors.grey[800] : const Color(0xFFCBD5E1)),
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

  void _showUpgradeConfirmation(
    BuildContext context,
    ProductionFacility fac,
    NumberFormat currencyFmt,
    bool isDark,
  ) {
    final nextLevel = fac.level + 1;
    final cost = fac.upgradeCost;
    final canAfford = controller.cash >= cost;

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
                            'Üretim süresi %10 kısalır (daha hızlı hasat)',
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
}

