import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/offline_report.dart';
import '../models/item.dart';

class OfflineSummaryDialog extends StatelessWidget {
  final OfflineCatchUpReport report;

  const OfflineSummaryDialog({super.key, required this.report});

  static Future<void> show(BuildContext context, OfflineCatchUpReport report) {
    if (!report.hasAnyActivity) return Future.value();
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OfflineSummaryDialog(report: report),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFmt = NumberFormat("#,##0", "tr_TR");

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [Colors.white, const Color(0xFFF8FAFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.amber.withOpacity(0.3) : const Color(0xFFCBD5E1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.6) : Colors.black.withOpacity(0.12),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. ÜST İKON VE BAŞLIK
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text('🌟', style: TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Siz Yokken Şirketiniz Çalıştı!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 15,
                    color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Geçen Süre: ${report.formattedDuration}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. TESİS VE ÜRETİM KARTI
              if (report.producedItems.isNotEmpty || report.warehouseFull) ...[
                _buildSectionCard(
                  isDark: isDark,
                  icon: '🚜',
                  title: 'Üretim Tesisleri',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: report.producedItems.entries.map((entry) {
                          final item = ItemRegistry.get(entry.key);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${item?.emoji ?? '📦'} +${entry.value} ${item?.name ?? entry.key}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.greenAccent : const Color(0xFF065F46),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (report.warehouseFull) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.red.withOpacity(0.2) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 14, color: Colors.redAccent),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Deponuz tamamen doldu! Bazı üretimler beklemeye alındı.',
                                  style: TextStyle(fontSize: 10.5, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // 3. DÜKKAN SATIŞLARI KARTI
              if (report.retailItemsSold > 0) ...[
                _buildSectionCard(
                  isDark: isDark,
                  icon: '🏪',
                  title: 'Perakende Dükkanlarım',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${report.retailItemsSold} adet ürün satıldı',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+${currencyFmt.format(report.retailRevenue)} ₺',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // 4. PAZAR VE TEKLİF İŞLEMLERİ
              if (report.marketItemsSold > 0 || report.incomingOffersCount > 0) ...[
                _buildSectionCard(
                  isDark: isDark,
                  icon: '🏷️',
                  title: 'Oyuncu Pazarı & Teklifler',
                  child: Column(
                    children: [
                      if (report.marketItemsSold > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${report.marketItemsSold} adet pazar ilanı satışı',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '+${currencyFmt.format(report.marketRevenue)} ₺',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      if (report.incomingOffersCount > 0) ...[
                        if (report.marketItemsSold > 0) const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text('📩', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${report.incomingOffersCount} yeni pazarlık teklifi sizi bekliyor',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.lightBlueAccent : const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // 5. BANKA VE FİNANS KARTI
              if (report.bankInterestEarned > 0 ||
                  report.loanInstallmentsPaid > 0 ||
                  report.loanInstallmentsOverdue > 0) ...[
                _buildSectionCard(
                  isDark: isDark,
                  icon: '🏦',
                  title: 'Banka & Krediler',
                  child: Column(
                    children: [
                      if (report.bankInterestEarned > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Vadeli Mevduat Faizi',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '+${currencyFmt.format(report.bankInterestEarned)} ₺',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      if (report.loanInstallmentsPaid > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${report.loanInstallmentsPaid} Kredi Taksiti Ödendi',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '-${currencyFmt.format(report.totalLoanPaidAmount)} ₺',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (report.loanInstallmentsOverdue > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, size: 14, color: Colors.redAccent),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Yetersiz nakit nedeniyle ${report.loanInstallmentsOverdue} taksit gecikmeye girdi (+${currencyFmt.format(report.loanPenaltiesIncurred)} ₺ ceza)',
                                  style: const TextStyle(fontSize: 10.5, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // 6. NET KASA DEĞİŞİMİ ÖZETİ
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
                        : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.greenAccent.withOpacity(0.4) : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Net Kasa Kazancı:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.greenAccent : const Color(0xFF065F46),
                            ),
                          ),
                          Text(
                            'Kasanız: ${currencyFmt.format(report.endingCash)} ₺',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${report.netCashChange >= 0 ? '+' : ''}${currencyFmt.format(report.netCashChange)} ₺',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: report.netCashChange >= 0
                            ? (isDark ? Colors.greenAccent : const Color(0xFF059669))
                            : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 7. HARİKA, DEVAM ET BUTONU
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.amber[600] : const Color(0xFFD97706),
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 3,
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '🚀 Harika, Şirketi Yönetmeye Devam Et!',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required String icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161F30) : const Color(0xFFF1F5F9),
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
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
