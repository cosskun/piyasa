import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class BannedDialog extends StatelessWidget {
  final String? reason;
  final VoidCallback? onLoggedOut;

  const BannedDialog({
    super.key,
    this.reason,
    this.onLoggedOut,
  });

  static Future<void> show(BuildContext context, {String? reason, VoidCallback? onLoggedOut}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => BannedDialog(
        reason: reason,
        onLoggedOut: onLoggedOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveReason = (reason != null && reason!.trim().isNotEmpty)
        ? reason!
        : 'Şüpheli işlem veya oyun kuralları ihlali';

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1418),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withValues(alpha: 0.25),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Kırmızı rozet
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4), width: 2),
                ),
                child: const Icon(
                  Icons.gavel_rounded,
                  color: Colors.redAccent,
                  size: 40,
                ),
              ),
              const SizedBox(height: 18),

              // Başlık
              const Text(
                'HESABINIZ ASKIYA ALINDI',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Erişim Kısıtlaması & Güvenlik Uyarısı',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.redAccent.shade100,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),

              // Ban Sebebi Kutusu
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kısıtlama Nedeni:',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      effectiveReason,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Bilgilendirme Metni
              Text(
                'Bu hesap pazar manipülasyonu, anormal işlem hacmi veya oyun kurallarına aykırı hile girişimi gerekçesiyle yönetici tarafından süresiz olarak askıya alınmıştır.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),

              // İletişim
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mail_outline_rounded, color: Colors.grey.shade400, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        'İtiraz: furkanc28@gmail.com',
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Çıkış Yap Butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await FirebaseService().signOut();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                    onLoggedOut?.call();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text(
                    'Oturumu Kapat',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
