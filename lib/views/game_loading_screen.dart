import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import '../services/firebase_service.dart';
import '../services/audit_log_service.dart';

class GameLoadingScreen extends StatefulWidget {
  final GameController controller;
  final VoidCallback onLoaded;
  final Duration minDuration;

  const GameLoadingScreen({
    super.key,
    required this.controller,
    required this.onLoaded,
    this.minDuration = const Duration(milliseconds: 2600),
  });

  @override
  State<GameLoadingScreen> createState() => _GameLoadingScreenState();
}

class _GameLoadingScreenState extends State<GameLoadingScreen> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _slideController;
  late final AnimationController _progressController;
  late final Animation<double> _pulseAnimation;

  double _progress = 0.0;
  String _statusMessage = '🌾 Tarlalarınız sürülüyor, tohumlar ekiliyor...';
  bool _dataLoaded = false;
  bool _minDurationPassed = false;
  bool _completed = false;

  final List<_LoadingBadgeData> _badges = const [
    _LoadingBadgeData(
      icon: Icons.agriculture_rounded,
      title: 'Tarlalar',
      subtitle: 'Sürülüyor & Ekiliyor',
      color: Color(0xFF10B981),
      gradientColors: [Color(0xFF064E3B), Color(0xFF047857)],
    ),
    _LoadingBadgeData(
      icon: Icons.factory_rounded,
      title: 'Fabrikalar',
      subtitle: 'Bacalar Tütüyor',
      color: Color(0xFFF59E0B),
      gradientColors: [Color(0xFF78350F), Color(0xFFD97706)],
    ),
    _LoadingBadgeData(
      icon: Icons.storefront_rounded,
      title: 'Marketler',
      subtitle: 'Raflar Düzenleniyor',
      color: Color(0xFF06B6D4),
      gradientColors: [Color(0xFF164E63), Color(0xFF0891B2)],
    ),
    _LoadingBadgeData(
      icon: Icons.inventory_2_rounded,
      title: 'Depo & Lojistik',
      subtitle: 'Stoklar Sayılıyor',
      color: Color(0xFF8B5CF6),
      gradientColors: [Color(0xFF4C1D95), Color(0xFF6D28D9)],
    ),
    _LoadingBadgeData(
      icon: Icons.trending_up_rounded,
      title: 'Borsa & Pazar',
      subtitle: 'Fiyatlar Dengeleniyor',
      color: Color(0xFFEC4899),
      gradientColors: [Color(0xFF831843), Color(0xFFBE185D)],
    ),
    _LoadingBadgeData(
      icon: Icons.account_balance_rounded,
      title: 'Banka & Finans',
      subtitle: 'Hesaplar Eşitleniyor',
      color: Color(0xFF3B82F6),
      gradientColors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
    ),
  ];

  @override
  void initState() {
    super.initState();

    // 1. Logo nefes alma / pulse animasyonu
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 2. Ortadaki logoların sağdan sola kesintisiz akış animasyonu
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // 3. İlerleme çubuğu animasyonu
    _progressController = AnimationController(
      vsync: this,
      duration: widget.minDuration,
    );

    _progressController.addListener(() {
      final val = _progressController.value;
      setState(() {
        _progress = val;
        _updateStatusMessage(val);
      });
    });

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _minDurationPassed = true;
        _checkAndFinish();
      }
    });

    _progressController.forward();
    _startLoadingData();
  }

  void _updateStatusMessage(double val) {
    if (val < 0.20) {
      _statusMessage = '🌾 Tarlalarınız ve arazileriniz hazırlanıyor...';
    } else if (val < 0.40) {
      _statusMessage = '🏭 Fabrikalarınızın bacaları tütüyor, makineler ısınıyor...';
    } else if (val < 0.60) {
      _statusMessage = '🏪 Market ve dükkan raflarınız düzenleniyor...';
    } else if (val < 0.80) {
      _statusMessage = '📦 Depo envanteriniz ve hammadde stoklarınız sayılıyor...';
    } else if (val < 0.95) {
      _statusMessage = '📈 Borsa fiyatları ve ortak pazar verileri eşitleniyor...';
    } else {
      _statusMessage = '🚀 Şirketiniz hazır! Piyasaya giriş yapılıyor...';
    }
  }

  Future<void> _startLoadingData() async {
    try {
      final pid = FirebaseService().playerId;
      if (!widget.controller.hasLoadedFromStorage) {
        await widget.controller.loadFromStorage(playerId: pid);
      }
      await AuditLogService().initializeForPlayer(pid);
    } catch (e) {
      debugPrint('GameLoadingScreen load error: $e');
    } finally {
      if (mounted) {
        _dataLoaded = true;
        _checkAndFinish();
      }
    }
  }

  void _checkAndFinish() {
    if (_dataLoaded && _minDurationPassed && !_completed && mounted) {
      _completed = true;
      widget.controller.clearNotificationToast();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          widget.controller.clearNotificationToast();
          widget.onLoaded();
        }
      });
    }
  }

  @override
  void dispose() {
    widget.controller.clearNotificationToast();
    _pulseController.dispose();
    _slideController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyName = FirebaseService().companyName;
    final username = FirebaseService().username ?? (FirebaseService().isGuest ? 'Misafir' : 'Ortak');
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Stack(
        children: [
          // 1. Atmosferik Arka Plan & Işık Hüzmeleri
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.4),
                  radius: 1.2,
                  colors: [
                    Color(0xFF0F2B26), // Zümrüt parıltısı
                    Color(0xFF0F172A), // Koyu lacivert
                    Color(0xFF070A12), // Derin gece siyahı
                  ],
                ),
              ),
            ),
          ),

          // Üst parıltı çemberi
          Positioned(
            top: -60,
            left: screenWidth / 2 - 140,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFF59E0B).withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Alt parıltı çemberi
          Positioned(
            bottom: -50,
            left: screenWidth / 2 - 160,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 2. Ana İçerik
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 12),

                // ÜST KISIM: 3D LOGO, BAŞLIK & ŞİRKET BİLGİSİ
                Column(
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                              blurRadius: 28,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.25),
                              blurRadius: 36,
                              offset: const Offset(0, 16),
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.7),
                            width: 2.2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFF0F766E),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: Colors.amberAccent,
                                size: 52,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFFDE68A), Color(0xFFF59E0B), Color(0xFFD97706)],
                      ).createShader(bounds),
                      child: const Text(
                        'PİYASA',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$companyName • $username',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),

                // ORTA KISIM: SAĞDAN SOLA DOĞRU AKAN LOGOLAR & KARTLAR
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sync_rounded, size: 14, color: Colors.amberAccent),
                          SizedBox(width: 6),
                          Text(
                            'DÜNYANIZ HAZIRLANIYOR',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: Colors.amberAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Sağdan Sola Sürekli Kayan Kart Şeridi
                    SizedBox(
                      height: 130,
                      child: AnimatedBuilder(
                        animation: _slideController,
                        builder: (context, _) {
                          // Tek bir tam döngü genişliği
                          const cardWidth = 148.0;
                          const cardSpacing = 12.0;
                          final totalCycleWidth = (cardWidth + cardSpacing) * _badges.length;
                          final offset = _slideController.value * totalCycleWidth;

                          return ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.centerLeft,
                              minWidth: 0.0,
                              maxWidth: double.infinity,
                              child: Transform.translate(
                                offset: Offset(-offset, 0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 3 kez tekrarlanarak ekran genişliğini her cihazda tamamen doldurur ve kesintisiz akar
                                    for (int cycle = 0; cycle < 3; cycle++)
                                      for (final badge in _badges)
                                        Padding(
                                          padding: const EdgeInsets.only(right: cardSpacing),
                                          child: _buildBadgeCard(badge, cardWidth),
                                        ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                // ALT KISIM: DURUM MESAJI & GLOWING İLERLEME ÇUBUĞU
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  child: Column(
                    children: [
                      // Dinamik değişen durum mesajı
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _statusMessage,
                          key: ValueKey<String>(_statusMessage),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // İlerleme Çubuğu (Glow & Gradient)
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final fillWidth = constraints.maxWidth * _progress;
                            return Stack(
                              children: [
                                Container(
                                  width: fillWidth,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF047857),
                                        Color(0xFF10B981),
                                        Color(0xFFF59E0B),
                                        Color(0xFFFDE68A),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Alt Bilgi & Yüzde
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Veriler Eşitleniyor...',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white38,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '%${(_progress * 100).toInt()}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.w900,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(_LoadingBadgeData badge, double width) {
    return Container(
      width: width,
      height: 124,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            badge.gradientColors[0].withValues(alpha: 0.85),
            badge.gradientColors[1].withValues(alpha: 0.95),
          ],
        ),
        border: Border.all(
          color: badge.color.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: badge.color.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Icon(badge.icon, size: 24, color: Colors.white),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.7),
                  boxShadow: [
                    BoxShadow(
                      color: badge.color,
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                badge.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                badge.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingBadgeData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final List<Color> gradientColors;

  const _LoadingBadgeData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.gradientColors,
  });
}
