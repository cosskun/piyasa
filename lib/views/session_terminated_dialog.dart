import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class SessionTerminatedDialog extends StatelessWidget {
  final String? reason;
  final VoidCallback? onLoggedOut;

  const SessionTerminatedDialog({
    super.key,
    this.reason,
    this.onLoggedOut,
  });

  static Future<void> show(
    BuildContext context, {
    String? reason,
    VoidCallback? onLoggedOut,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => SessionTerminatedDialog(
        reason: reason,
        onLoggedOut: onLoggedOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveReason = (reason != null && reason!.trim().isNotEmpty)
        ? reason!
        : 'Hesabınıza başka bir cihazdan veya tarayıcıdan giriş yapıldı. Güvenliğiniz için bu cihazdaki oturumunuz kapatıldı.';

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: const Color(0xFF131A29),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.amberAccent.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amberAccent.withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cihaz uyarısı rozeti
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amberAccent.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.amberAccent.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.devices_other_rounded,
                  color: Colors.amberAccent,
                  size: 40,
                ),
              ),
              const SizedBox(height: 18),

              // Başlık
              const Text(
                'OTURUMUNUZ KAPATILDI',
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
                'Farklı Cihazdan Giriş Yapıldı',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.amberAccent.shade100,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),

              // Açıklama Kutusu
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.amberAccent.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.security_rounded,
                          color: Colors.amberAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Güvenlik Bildirimi:',
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
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Ek Bilgilendirme
              Text(
                'Aynı anda sadece tek bir cihazda aktif oturum açık kalabilir. Eğer bu girişi siz yapmadıysanız hesabınızı güvende tutmak için şifrenizi değiştiriniz.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),

              // Giriş Ekranına Dön Butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await FirebaseService().signOut();
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
                    }
                    onLoggedOut?.call();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text(
                    'Giriş Ekranına Dön',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
