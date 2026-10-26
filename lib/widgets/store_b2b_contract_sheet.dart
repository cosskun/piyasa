import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import '../models/item.dart';
import '../models/store.dart';
import 'game_toast.dart';

class StoreB2BContractSheet extends StatelessWidget {
  final RetailStore store;
  final GameController controller;

  const StoreB2BContractSheet({
    super.key,
    required this.store,
    required this.controller,
  });

  static void show(BuildContext context, {required RetailStore store, required GameController controller}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StoreB2BContractSheet(store: store, controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFmt = NumberFormat("#,##0", "tr_TR");
    final contracts = StoreB2BContract.getContractsForStore(store);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131D2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Çekme Tutamacı
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Başlık
              Row(
                children: [
                  Text(store.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                store.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.25) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE),
                                ),
                              ),
                              child: Text(
                                'Sv. ${store.level}',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Kurumsal B2B Sözleşmeleri & Toplu İhaleler',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Bilgi Notu
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.handshake_outlined, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Otel, restoran ve kurumlara toplu mal vererek depodaki yüzlerce stoğu tek seferde yüksek kâr ve prestijle eritin!',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Sözleşmeler Listesi
              if (contracts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      'Bu mağaza türü için henüz aktif B2B sözleşmesi bulunmuyor.',
                      style: TextStyle(color: isDark ? Colors.grey : const Color(0xFF64748B)),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: contracts.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      final c = contracts[idx];
                      final item = ItemRegistry.get(c.itemId);
                      final inWh = controller.warehouse[c.itemId] ?? 0;
                      final isLevelSufficient = store.level >= c.minStoreLevel;
                      final isStockSufficient = inWh >= c.requiredQuantity;
                      final canFulfill = isLevelSufficient && isStockSufficient;

                      final progress = (inWh / c.requiredQuantity).clamp(0.0, 1.0);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A263D) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: canFulfill
                                ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.6) : const Color(0xFF86EFAC))
                                : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                            width: canFulfill ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Üst Rozet & Müşteri
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD97706).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    c.badge,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                                Text(
                                  c.clientName,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Başlık & Açıklama
                            Text(
                              c.title,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              c.description,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey[400] : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Gereken Ürün & Depo Durumu
                            Row(
                              children: [
                                Text(item?.emoji ?? '📦', style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Gereken: ${c.requiredQuantity} adet ${item?.name ?? c.itemId}',
                                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                          ),
                                          Text(
                                            '$inWh / ${c.requiredQuantity} adet',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isStockSufficient
                                                  ? (isDark ? Colors.greenAccent : const Color(0xFF059669))
                                                  : Colors.redAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          minHeight: 5,
                                          backgroundColor: isDark ? Colors.black26 : const Color(0xFFE2E8F0),
                                          valueColor: AlwaysStoppedAnimation(
                                            isStockSufficient ? const Color(0xFF10B981) : Colors.orangeAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Ödül & Teslimat Butonu
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '+${currencyFmt.format(c.rewardCash)} ₺',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                                      ),
                                    ),
                                    Text(
                                      '+${c.rewardPrestige} Prestij Puanı',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: !isLevelSufficient
                                      ? null
                                      : (!isStockSufficient
                                          ? null
                                          : () {
                                              final err = controller.fulfillStoreB2BContract(store, c);
                                              if (err != null) {
                                                GameToast.showWarning(context, err, title: 'Teslimat Yapılamadı');
                                              } else {
                                                GameToast.showSuccess(
                                                  context,
                                                  '${c.clientName} sözleşmesi tamamlandı! +${currencyFmt.format(c.rewardCash)} ₺ ve +${c.rewardPrestige} Prestij kazanıldı! 🤝🎉',
                                                  title: 'B2B Sipariş Teslim Edildi',
                                                );
                                              }
                                            }),
                                  icon: Icon(
                                    !isLevelSufficient
                                        ? Icons.lock_outline_rounded
                                        : (!isStockSufficient ? Icons.inventory_2_outlined : Icons.check_circle_rounded),
                                    size: 15,
                                  ),
                                  label: Text(
                                    !isLevelSufficient
                                        ? 'Sv. ${c.minStoreLevel} Gerekli'
                                        : (!isStockSufficient ? 'Yetersiz Stok' : 'Teslim Et & Tahsil Et'),
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: canFulfill
                                        ? const Color(0xFF059669)
                                        : (isDark ? Colors.grey[800] : Colors.grey[300]),
                                    foregroundColor: canFulfill
                                        ? Colors.white
                                        : (isDark ? Colors.grey[500] : Colors.grey[600]),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
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
  }
}
