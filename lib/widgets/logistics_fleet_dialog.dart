import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import '../models/logistics.dart';
import 'game_toast.dart';

class LogisticsFleetDialog extends StatelessWidget {
  final GameController controller;

  const LogisticsFleetDialog({super.key, required this.controller});

  static void show(BuildContext context, {required GameController controller}) {
    showDialog(
      context: context,
      builder: (ctx) => LogisticsFleetDialog(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFmt = NumberFormat("#,##0", "tr_TR");

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final currentTier = controller.currentLogisticsTier;
        final tiers = LogisticsFleetTier.tiers;

        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E283C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Başlık & Kapat Butonu
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('🚚', style: TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Şirket Lojistik & Araç Filosu',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Depo ve mağazalar arası navlun masraflarını düşürün.',
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
                  const SizedBox(height: 16),

                  // Mevcut Durum Kartı
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E3A8A), const Color(0xFF1E293B)]
                            : [const Color(0xFFDBEAFE), const Color(0xFFEFF6FF)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.4) : const Color(0xFF93C5FD),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(currentTier.emoji, style: const TextStyle(fontSize: 32)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.blueAccent.withValues(alpha: 0.3) : const Color(0xFF2563EB),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'KADEME ${currentTier.tier}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      currentTier.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentTier.shippingCostPerItem > 0
                                    ? 'Navlun Maliyeti: ${currentTier.shippingCostPerItem.toStringAsFixed(2)} ₺ / parça'
                                    : '🎉 Sıfır Navlun Masrafı (Ücretsiz İç Sevkiyat)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: currentTier.shippingCostPerItem == 0
                                      ? (isDark ? Colors.greenAccent : const Color(0xFF059669))
                                      : (isDark ? Colors.grey[300] : const Color(0xFF334155)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Kademeler Listesi
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: tiers.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final tier = tiers[idx];
                        final isCurrent = tier.tier == controller.logisticsFleetTier;
                        final isUnlocked = tier.tier <= controller.logisticsFleetTier;
                        final isNext = tier.tier == controller.logisticsFleetTier + 1;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? (isDark ? const Color(0xFF0F253E) : const Color(0xFFF0FDF4))
                                : (isDark ? const Color(0xFF131C2E) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrent
                                  ? (isDark ? Colors.tealAccent.withValues(alpha: 0.6) : const Color(0xFF10B981))
                                  : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                              width: isCurrent ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(tier.emoji, style: const TextStyle(fontSize: 22)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Kademe ${tier.tier}: ${tier.name}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          tier.description,
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
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'AKTİF FİLO',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                      ),
                                    )
                                  else if (isUnlocked)
                                    const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF10B981))
                                  else if (isNext)
                                    ElevatedButton(
                                      onPressed: () {
                                        final err = controller.upgradeLogisticsFleet();
                                        if (err != null) {
                                          GameToast.showWarning(context, err, title: 'Yükseltme Yapılamadı');
                                        } else {
                                          GameToast.showSuccess(
                                            context,
                                            'Tebrikler! Lojistik filonuz ${tier.name} kademesine yükseltildi! 🚚💨',
                                            title: 'Filo Geliştirildi',
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: Text(
                                        '${currencyFmt.format(tier.purchaseCost)} ₺ Al',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  else
                                    const Icon(Icons.lock_outline_rounded, size: 16, color: Colors.grey),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.local_shipping_outlined, size: 13, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    tier.shippingCostPerItem > 0
                                        ? 'Parça Başı Navlun: ${tier.shippingCostPerItem.toStringAsFixed(2)} ₺'
                                        : 'Sıfır Navlun Masrafı (Ücretsiz)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey[300] : const Color(0xFF475569),
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
            ),
          ),
        );
      },
    );
  }
}
