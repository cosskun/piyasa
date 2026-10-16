import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/audit_log_service.dart';
import '../models/audit_log.dart';
import 'banned_dialog.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true; // true: Giriş Yap, false: Kayıt Ol
  bool _isLoading = false;
  String? _errorMessage;

  // Giriş Yap Kontrolcüleri
  final TextEditingController _loginIdentifierController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();
  bool _obscureLoginPassword = true;

  // Kayıt Ol Kontrolcüleri
  final TextEditingController _regUsernameController = TextEditingController();
  final TextEditingController _regCompanyNameController = TextEditingController();
  final TextEditingController _regEmailController = TextEditingController();
  final TextEditingController _regPasswordController = TextEditingController();
  final TextEditingController _regConfirmPasswordController = TextEditingController();
  bool _obscureRegPassword = true;
  bool _obscureRegConfirmPassword = true;

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _loginIdentifierController.dispose();
    _loginPasswordController.dispose();
    _regUsernameController.dispose();
    _regCompanyNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _loginIdentifierController.text.trim();
    final password = _loginPasswordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Lütfen kullanıcı adı / e-posta ve şifrenizi girin.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await FirebaseService().loginWithEmailOrUsername(
      identifier: identifier,
      password: password,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = error.startsWith('HESAP_BANLANDI:') ? 'Hesabınız askıya alınmıştır.' : error;
      });
      if (error.startsWith('HESAP_BANLANDI:')) {
        final reason = error.replaceFirst('HESAP_BANLANDI:', '').trim();
        BannedDialog.show(context, reason: reason);
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      AuditLogService().log(
        category: LogCategory.auth,
        action: 'AUTH_LOGIN',
        title: 'Oturum Açıldı',
        description: '$identifier başarıyla giriş yaptı.',
        cashAfter: 0.0,
        details: {'identifier': identifier},
      );
      widget.onAuthenticated();
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _regUsernameController.text.trim();
    final companyName = _regCompanyNameController.text.trim();
    final email = _regEmailController.text.trim();
    final password = _regPasswordController.text.trim();
    final confirmPassword = _regConfirmPasswordController.text.trim();

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'Girdiğiniz şifreler birbiriyle eşleşmiyor.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await FirebaseService().registerWithEmail(
      email: email,
      password: password,
      username: username,
      companyName: companyName.isNotEmpty ? companyName : null,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      AuditLogService().log(
        category: LogCategory.auth,
        action: 'AUTH_REGISTER',
        title: 'Yeni Hesap Kaydı',
        description: '$username şirketiyle sisteme kayıt oldu.',
        cashAfter: 10000.0,
        details: {
          'username': username,
          'email': email,
          'companyName': companyName.isNotEmpty ? companyName : '$username Holding',
        },
      );
      widget.onAuthenticated();
    }
  }

  Future<void> _handleGuestLogin() async {
    setState(() {
      _isLoading = true;
    });
    await FirebaseService().continueAsGuest();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
    AuditLogService().log(
      category: LogCategory.auth,
      action: 'AUTH_GUEST',
      title: 'Misafir Girişi',
      description: 'Misafir oyuncu moduyla oyuna başlandı.',
      cashAfter: 10000.0,
    );
    widget.onAuthenticated();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. OYUN LOGOSU VE BAŞLIK
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD97706).withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset(
                          'Assets/icon/app_icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFF0F766E),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: Colors.amberAccent,
                                size: 48,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'PİYASA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: isDark ? Colors.amberAccent : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ticaret, Üretim & Borsa Simülasyonu',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. SEKMELER (GİRİŞ YAP / KAYIT OL)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isLogin = true;
                                _errorMessage = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isLogin
                                    ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _isLogin
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Text(
                                'Giriş Yap',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _isLogin ? FontWeight.bold : FontWeight.w500,
                                  color: _isLogin
                                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                      : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isLogin = false;
                                _errorMessage = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isLogin
                                    ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: !_isLogin
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Text(
                                'Kayıt Ol',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: !_isLogin ? FontWeight.bold : FontWeight.w500,
                                  color: !_isLogin
                                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                      : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. HATA BİLDİRİMİ
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(fontSize: 12.5, color: Colors.redAccent, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 4. FORMLAR
                  if (_isLogin) _buildLoginForm(isDark) else _buildRegisterForm(isDark),

                  const SizedBox(height: 16),

                  // 5. MİSAFİR GİRİŞİ SEÇENEĞİ
                  Row(
                    children: [
                      Expanded(child: Divider(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'veya',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                        ),
                      ),
                      Expanded(child: Divider(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1))),
                    ],
                  ),
                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGuestLogin,
                    icon: const Icon(Icons.person_outline, size: 18),
                    label: const Text('Hesapsız Hızlı Başla (Misafir Modu)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : const Color(0xFF475569),
                      side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // === GİRİŞ FORMU ===
  Widget _buildLoginForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          controller: _loginIdentifierController,
          label: 'Kullanıcı Adı veya E-posta',
          hint: 'örn: ahmet_holding veya ornek@mail.com',
          icon: Icons.person_outline,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _loginPasswordController,
          label: 'Şifre',
          hint: '••••••••',
          icon: Icons.lock_outline,
          isDark: isDark,
          obscureText: _obscureLoginPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureLoginPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: isDark ? Colors.white60 : Colors.black45,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _obscureLoginPassword = !_obscureLoginPassword;
              });
            },
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.amber[600] : const Color(0xFFD97706),
            foregroundColor: isDark ? Colors.black : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                )
              : const Text(
                  'Oyuna Giriş Yap ›',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  // === KAYIT FORMU ===
  Widget _buildRegisterForm(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField(
            controller: _regUsernameController,
            label: 'Kullanıcı Adı (Benzersiz)',
            hint: 'örn: anadolu_tuccari',
            icon: Icons.alternate_email,
            isDark: isDark,
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Kullanıcı adı boş bırakılamaz.';
              if (val.trim().length < 3) return 'En az 3 karakter olmalıdır.';
              if (val.trim().length > 20) return 'En fazla 20 karakter olabilir.';
              if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(val.trim())) {
                return 'Yalnızca harf, rakam, nokta ve alt çizgi kullanılabilir.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _regCompanyNameController,
            label: 'Şirket Adı (İsteğe Bağlı)',
            hint: 'örn: Anadolu Dış Ticaret A.Ş.',
            icon: Icons.business_outlined,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _regEmailController,
            label: 'E-posta Adresi (Benzersiz)',
            hint: 'ornek@mail.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            isDark: isDark,
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'E-posta adresi boş bırakılamaz.';
              if (!val.contains('@') || !val.contains('.')) return 'Lütfen geçerli bir e-posta adresi girin.';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _regPasswordController,
            label: 'Şifre',
            hint: 'En az 6 karakter',
            icon: Icons.lock_outline,
            isDark: isDark,
            obscureText: _obscureRegPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureRegPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: isDark ? Colors.white60 : Colors.black45,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscureRegPassword = !_obscureRegPassword;
                });
              },
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Şifre boş bırakılamaz.';
              if (val.trim().length < 6) return 'Şifre en az 6 karakter olmalıdır.';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _regConfirmPasswordController,
            label: 'Şifre Tekrarı',
            hint: 'Şifrenizi tekrar girin',
            icon: Icons.lock_reset_outlined,
            isDark: isDark,
            obscureText: _obscureRegConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureRegConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: isDark ? Colors.white60 : Colors.black45,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscureRegConfirmPassword = !_obscureRegConfirmPassword;
                });
              },
            ),
            validator: (val) {
              if (val != _regPasswordController.text) return 'Şifreler eşleşmiyor.';
              return null;
            },
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : const Text(
                    'Şirketini Kur & Kayıt Ol ›',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8), fontSize: 13),
        labelStyle: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569), fontSize: 13.5),
        prefixIcon: Icon(icon, size: 20, color: isDark ? Colors.amberAccent : const Color(0xFF0F766E)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }
}
