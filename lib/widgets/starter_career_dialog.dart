import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import '../widgets/game_toast.dart';

class StarterCareerDialog extends StatelessWidget {
  final GameController controller;

  const StarterCareerDialog({
    super.key,
    required this.controller,
  });

  static Future<void> show(BuildContext context, GameController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StarterCareerDialog(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.blueAccent.withOpacity(0.3) : const Color(0xFF93C5FD),
                  ),
                ),
                child: const Text('🎯', style: TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ticaret Kariyerini Seç',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'İmparatorluğunu hangi sektörde başlatmak istersin?',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Career Option 1: 🌾 Tahıl & Fırıncılık
                  _buildCareerCard(
                    context: context,
                    isDark: isDark,
                    careerId: 'grain_bakery',
                    emoji: '🌾',
                    badge: 'Tavsiye Edilen • Hızlı Akış',
                    badgeColor: const Color(0xFFD97706),
                    title: 'Tahıl & Fırıncılık Yolu',
                    subtitle: 'Tarladan Sofraya Taze Ekmek İmparatorluğu',
                    facilityName: 'Buğday Tarlası (🌾)',
                    storeName: 'Köşe Büfe & Fırın (🏪)',
                    initialStock: '50 Buğday + 20 Ekmek (Rafta 15)',
                    cash: '5.000 ₺ Nakit Sermaye',
                    description:
                        'Tarlada buğday hasat edin, fırınınızda taze ekmek satın. Un değirmeni ve endüstriyel fırın kurarak mahallenin en büyük unlu mamul tedarikçisi olun.',
                    accentColor: const Color(0xFFF59E0B),
                  ),

                  const SizedBox(height: 12),

                  // Career Option 2: 🐄 Mandıra & Şarküteri
                  _buildCareerCard(
                    context: context,
                    isDark: isDark,
                    careerId: 'dairy_cheese',
                    emoji: '🐄',
                    badge: 'Yüksek Talep • Mandıra',
                    badgeColor: const Color(0xFF059669),
                    title: 'Mandıra & Şarküteri Yolu',
                    subtitle: 'Çiftlik Sütünden Altın Peynirlere',
                    facilityName: 'Mandıra Çiftliği (🐄)',
                    storeName: 'Gurme Şarküteri (🧀)',
                    initialStock: '40 Çiftlik Sütü + 20 Köy Peyniri (Rafta 15)',
                    cash: '5.000 ₺ Nakit Sermaye',
                    description:
                        'Mandırada doğal çiftlik sütü üretin, şarküterinizde köy peyniri satın. Süt işleme tesisiyle tereyağı ve yoğurt çeşitlerine açılarak yüksek kâr marjı yakalayın.',
                    accentColor: const Color(0xFF10B981),
                  ),

                  const SizedBox(height: 12),

                  // Career Option 3: ☕ Kahve & Kafe Kültürü
                  _buildCareerCard(
                    context: context,
                    isDark: isDark,
                    careerId: 'coffee_barista',
                    emoji: '☕',
                    badge: 'Yüksek Kâr Marjı • Gurme',
                    badgeColor: const Color(0xFF8B5CF6),
                    title: 'Kahve & Kafe Kültürü Yolu',
                    subtitle: 'Tropikal Plantasyondan 3. Nesil Kafeye',
                    facilityName: 'Kahve Plantasyonu (🌿)',
                    storeName: '3. Nesil Kahve Dükkanı (☕)',
                    initialStock: '35 Kahve Çekirdeği + 20 Sıcak Kahve (Rafta 15)',
                    cash: '5.000 ₺ Nakit Sermaye',
                    description:
                        'Tropikal plantasyonda aromatik kahve çekirdekleri hasat edin, kafenizde sıcak filtre kahve satın. Kavurma ve demleme tesisleriyle gurme baristalık dünyasını yönetin.',
                    accentColor: const Color(0xFF9333EA),
                  ),

                  const SizedBox(height: 16),

                  // Custom Sandbox Option
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      controller.applyStarterCareerPath('custom_sandbox');
                      GameToast.showInfo(
                        context,
                        '10.000 ₺ başlangıç sermayenizle serbest girişimciliğe başladınız! 🛠️',
                        title: 'Serbest Girişimci',
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🛠️', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Kendi Yolumu Kendim Çizeceğim (10.000 ₺ Serbest Başlangıç)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCareerCard({
    required BuildContext context,
    required bool isDark,
    required String careerId,
    required String emoji,
    required String badge,
    required Color badgeColor,
    required String title,
    required String subtitle,
    required String facilityName,
    required String storeName,
    required String initialStock,
    required String cash,
    required String description,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withOpacity(isDark ? 0.4 : 0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: badgeColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Starter Assets Grid
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withOpacity(0.6) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildAssetRow(Icons.precision_manufacturing_outlined, 'Tesis:', facilityName, isDark),
                const SizedBox(height: 4),
                _buildAssetRow(Icons.storefront_outlined, 'Dükkan:', storeName, isDark),
                const SizedBox(height: 4),
                _buildAssetRow(Icons.inventory_2_outlined, 'Başlangıç Deposu:', initialStock, isDark),
                const SizedBox(height: 4),
                _buildAssetRow(Icons.account_balance_wallet_outlined, 'Nakit:', cash, isDark, highlight: true),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Text(
            description,
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 10),

          // Select Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                controller.applyStarterCareerPath(careerId);
                GameToast.showSuccess(
                  context,
                  '$title ile ticaret imparatorluğunuz başladı! 🚀',
                  title: 'Kariyer Başlatıldı',
                );
              },
              icon: const Icon(Icons.rocket_launch_rounded, size: 16),
              label: Text(
                'Bu Kariyer ile Başla',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetRow(IconData icon, String label, String value, bool isDark, {bool highlight = false}) {
    return Row(
      children: [
        Icon(icon, size: 13, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: highlight
                  ? const Color(0xFF10B981)
                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
