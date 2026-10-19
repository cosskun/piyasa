import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import '../services/firebase_service.dart';
import '../services/audit_log_service.dart';
import '../models/audit_log.dart';
import '../services/notification_service.dart';
import 'ledger_dialog.dart';

class ProfileScreen extends StatefulWidget {
  final GameController controller;
  final VoidCallback? onLoggedOut;

  const ProfileScreen({
    super.key,
    required this.controller,
    this.onLoggedOut,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _usernameController;
  late final TextEditingController _companyController;
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final fb = FirebaseService();
    _usernameController = TextEditingController(text: fb.username ?? '');
    _companyController = TextEditingController(text: fb.companyName);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _companyController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final fb = FirebaseService();
    final newUsername = _usernameController.text.trim();
    final newCompany = _companyController.text.trim();
    final currentPass = _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    // Şifre alanları kontrolü
    if (newPass.isNotEmpty) {
      if (newPass.length < 6) {
        setState(() => _errorMessage = 'Yeni şifreniz en az 6 karakter olmalıdır.');
        return;
      }
      if (newPass != confirmPass) {
        setState(() => _errorMessage = 'Yeni şifreler birbiriyle eşleşmiyor.');
        return;
      }
      if (currentPass.isEmpty) {
        setState(() => _errorMessage = 'Şifrenizi değiştirmek için lütfen mevcut şifrenizi girin.');
        return;
      }
    }

    final hasUsernameChange = newUsername != (fb.username ?? '');
    final hasCompanyChange = newCompany != fb.companyName;
    final hasPasswordChange = newPass.isNotEmpty;

    if (!hasUsernameChange && !hasCompanyChange && !hasPasswordChange) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Herhangi bir değişiklik yapılmadı.'),
          backgroundColor: Color(0xFF64748B),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final error = await fb.updateProfile(
        newUsername: hasUsernameChange ? newUsername : null,
        newCompanyName: hasCompanyChange ? newCompany : null,
        currentPassword: hasPasswordChange ? currentPass : null,
        newPassword: hasPasswordChange ? newPass : null,
      );

      if (!mounted) return;

      if (error != null) {
        setState(() {
          _errorMessage = error;
          _isSaving = false;
        });
        return;
      }

      // Şifre alanlarını temizle
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      // Log kaydı oluştur
      AuditLogService().log(
        category: LogCategory.auth,
        action: 'PROFILE_UPDATE',
        title: 'Profil Güncellendi',
        description: 'Kullanıcı adı: $newUsername, Şirket: $newCompany güncellendi.',
        cashAfter: widget.controller.cash,
      );

      // Oyun durumunu yeni şirket / kullanıcı bilgisiyle kaydet
      widget.controller.saveState();
      widget.controller.notifyListeners();

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Profil bilgileriniz başarıyla güncellendi!')),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Profil güncellenirken bir hata oluştu: $e';
          _isSaving = false;
        });
      }
    }
  }

  void _confirmLogout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Oturumu Kapat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Hesabınızdan çıkış yapmak istediğinize emin misiniz? Oyun ilerlemeniz yerel ve bulutta güvenle saklanmaktadır.',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'İptal',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop(); // Dialogu kapat
              Navigator.of(context).pop(); // ProfileScreen'i kapat

              final fb = FirebaseService();
              final username = fb.username ?? 'Oyuncu';

              AuditLogService().log(
                category: LogCategory.auth,
                action: 'AUTH_LOGOUT',
                title: 'Çıkış Yapıldı',
                description: '$username oturumu kapattı.',
                cashAfter: widget.controller.cash,
              );

              await fb.signOut();
              widget.controller.resetToNewGame();
              AuditLogService().clearInProcess();
              widget.onLoggedOut?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fb = FirebaseService();
    final c = widget.controller;
    final currencyFmt = NumberFormat("#,##0", "tr_TR");

    final username = fb.username ?? (fb.isGuest ? 'Misafir Oyuncu' : 'Oyuncu');
    final company = fb.companyName;
    final email = fb.email ?? (fb.isGuest ? 'Giriş yapılmadı (Misafir Modu)' : 'E-posta belirtilmedi');
    final isLoggedIn = fb.isLoggedIn;
    final isAdmin = fb.isAdmin;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F131D) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF161C2C) : Colors.white,
        elevation: 1,
        title: Text(
          'Kullanıcı Profili',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isAdmin
                    ? [const Color(0xFFDC2626), const Color(0xFFB91C1C)]
                    : (isLoggedIn
                        ? [const Color(0xFF0F766E), const Color(0xFF0D9488)]
                        : [const Color(0xFF64748B), const Color(0xFF475569)]),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAdmin ? Icons.shield_rounded : (isLoggedIn ? Icons.cloud_done_rounded : Icons.person_rounded),
                  size: 13,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  isAdmin ? 'YÖNETİCİ' : (isLoggedIn ? 'BULUT' : 'MİSAFİR'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ==========================================
                // 1. PROFİL ÖZET KARTI (HEADER)
                // ==========================================
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E293B), const Color(0xFF111827)]
                          : [Colors.white, const Color(0xFFF8FAFC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.amber.withOpacity(0.25) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black45 : Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Avatar
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F766E).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                username.isNotEmpty ? username[0].toUpperCase() : 'P',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        username,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Icon(Icons.verified, size: 16, color: Color(0xFF10B981)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  company,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      // İstatistik Rozetleri
                      Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _buildStatBadge(
                                isDark: isDark,
                                label: 'Seviye',
                                value: '${c.playerLevel} (${c.playerTitle})',
                                icon: Icons.military_tech_rounded,
                                iconColor: Colors.amberAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _buildStatBadge(
                                isDark: isDark,
                                label: 'Net Servet',
                                value: '${currencyFmt.format(c.netWorth)} ₺',
                                icon: Icons.account_balance_wallet_rounded,
                                iconColor: const Color(0xFF10B981),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _buildStatBadge(
                                isDark: isDark,
                                label: 'Kasa',
                                value: '${currencyFmt.format(c.cash)} ₺',
                                icon: Icons.payments_rounded,
                                iconColor: const Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Hata Bildirimi (Varsa)
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ==========================================
                // 2. KİMLİK & ŞİRKET BİLGİLERİ KARTI
                // ==========================================
                _buildCardSection(
                  isDark: isDark,
                  icon: Icons.badge_outlined,
                  title: 'Hesap & Şirket Bilgileri',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Kullanıcı Adı
                      Text(
                        'Kullanıcı Adı',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _usernameController,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: _inputDecoration(
                          isDark: isDark,
                          hintText: 'Yeni kullanıcı adınız',
                          prefixIcon: Icons.alternate_email_rounded,
                          helperText: 'Benzersiz olmalıdır (3-20 karakter, harf, rakam, _, .)',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Kullanıcı adı boş bırakılamaz.';
                          }
                          if (val.trim().length < 3 || val.trim().length > 20) {
                            return 'Kullanıcı adı 3 ile 20 karakter arasında olmalıdır.';
                          }
                          if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(val.trim())) {
                            return 'Sadece harf, rakam, nokta ve alt çizgi içerebilir.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      // Şirket Adı
                      Text(
                        'Şirket Adı',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _companyController,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: _inputDecoration(
                          isDark: isDark,
                          hintText: 'Şirket unvanınız',
                          prefixIcon: Icons.business_rounded,
                          helperText: 'Piyasada, borsada ve liderlik tablosunda görünecek unvan',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Şirket adı boş bırakılamaz.';
                          }
                          if (val.trim().length < 3 || val.trim().length > 30) {
                            return 'Şirket adı 3 ile 30 karakter arasında olmalıdır.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ==========================================
                // 3. GÜVENLİK & ŞİFRE DEĞİŞTİRME KARTI
                // ==========================================
                _buildCardSection(
                  isDark: isDark,
                  icon: Icons.lock_outline_rounded,
                  title: 'Güvenlik & Şifre Değiştir',
                  child: fb.isGuest
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Misafir modunda oynuyorsunuz. Şifre belirlemek ve verilerinizi tüm cihazlarınızla buluta eşitlemek için giriş ekranından bir hesap oluşturabilirsiniz.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Şifrenizi değiştirmek istemiyorsanız bu alanları boş bırakabilirsiniz.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Mevcut Şifre
                            TextFormField(
                              controller: _currentPasswordController,
                              obscureText: _obscureCurrent,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              decoration: _inputDecoration(
                                isDark: isDark,
                                hintText: 'Mevcut Şifreniz',
                                prefixIcon: Icons.lock_open_rounded,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                                    size: 18,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                  onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Yeni Şifre
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: _obscureNew,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              decoration: _inputDecoration(
                                isDark: isDark,
                                hintText: 'Yeni Şifre (en az 6 karakter)',
                                prefixIcon: Icons.vpn_key_rounded,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureNew ? Icons.visibility_off : Icons.visibility,
                                    size: 18,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Yeni Şifre (Tekrar)
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirm,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              decoration: _inputDecoration(
                                isDark: isDark,
                                hintText: 'Yeni Şifre (Tekrar)',
                                prefixIcon: Icons.check_circle_outline_rounded,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                                    size: 18,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 20),

                // ==========================================
                // 4. DEĞİŞİKLİKLERİ KAYDET BUTONU
                // ==========================================
                ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF0F766E).withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.save_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Değişiklikleri Kaydet',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 24),

                // ==========================================
                // 5. BİLDİRİM & ŞİRKET İŞLEMLERİ
                // ==========================================
                OutlinedButton.icon(
                  onPressed: () async {
                    final granted = await NotificationService().requestNotificationPermissions();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              granted ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                granted
                                    ? 'Bildirim izinleri aktif! Teklifler ve borsa hareketleri anında iletilecek.'
                                    : 'Bildirim izinleri kapalı veya reddedildi. Cihaz ayarlarından açabilirsiniz.',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: granted ? const Color(0xFF059669) : const Color(0xFFD97706),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: const Text('Bildirim İzinlerini Kontrol Et'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                    side: BorderSide(
                      color: isDark ? Colors.amberAccent.withOpacity(0.4) : const Color(0xFFD97706),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed: () => LedgerDialog.show(context),
                  icon: const Icon(Icons.history_edu_rounded, size: 18),
                  label: const Text('Şirket Defteri & İşlem Kayıtları'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.tealAccent : const Color(0xFF0F766E),
                    side: BorderSide(
                      color: isDark ? Colors.tealAccent.withOpacity(0.4) : const Color(0xFF0F766E),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 10),

                // Oturumu Kapat Butonu
                OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context),
                  icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFEF4444)),
                  label: const Text(
                    'Oturumu Kapat',
                    style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardSection({
    required bool isDark,
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: isDark ? Colors.amberAccent : const Color(0xFF0F766E)),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildStatBadge({
    required bool isDark,
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required bool isDark,
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
    String? helperText,
  }) {
    return InputDecoration(
      hintText: hintText,
      helperText: helperText,
      helperMaxLines: 2,
      helperStyle: TextStyle(
        fontSize: 11,
        color: isDark ? Colors.white38 : const Color(0xFF64748B),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF131D2D) : const Color(0xFFF8FAFC),
      prefixIcon: Icon(
        prefixIcon,
        size: 18,
        color: isDark ? Colors.amberAccent : const Color(0xFF0F766E),
      ),
      suffixIcon: suffixIcon,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }
}
