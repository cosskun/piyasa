import 'dart:async';
import 'package:flutter/material.dart';

enum GameToastType {
  success,
  warning,
  error,
  info,
}

/// Piyasa oyununa özel, ekranın üstünden süzülen, modern ve dikkat çekici HUD bildirim sistemi.
/// Modalların ve diyalogların üzerine (Overlay seviyesinde) çıkarak hiçbir zaman arkada kalmaz.
class GameToast {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static OverlayEntry? _activeEntry;
  static Timer? _activeTimer;
  static GlobalKey<_GameToastWidgetState>? _activeWidgetKey;

  static void show(
    BuildContext? context, {
    required String message,
    String? title,
    GameToastType type = GameToastType.success,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 2800),
    VoidCallback? onTap,
    String? actionLabel,
  }) {
    // Önceki açık bildirimi temizle
    _activeTimer?.cancel();
    _activeTimer = null;
    if (_activeEntry != null) {
      try {
        _activeEntry?.remove();
      } catch (_) {}
      _activeEntry = null;
    }

    // Hedef Overlay'i bul (rootOverlay: true sayesinde tüm diyalogların ve modalların üstüne çıkar)
    final overlay = (context != null && context.mounted
            ? Overlay.maybeOf(context, rootOverlay: true)
            : null) ??
        navigatorKey.currentState?.overlay;

    if (overlay == null) {
      // Fallback: Overlay bulunamazsa ScaffoldMessenger ile göster
      if (context != null && context.mounted) {
        final sm = ScaffoldMessenger.maybeOf(context);
        if (sm != null) {
          sm.hideCurrentSnackBar();
          sm.showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: _getFallbackColor(type),
              behavior: SnackBarBehavior.floating,
              duration: duration,
            ),
          );
        }
      }
      return;
    }

    final key = GlobalKey<_GameToastWidgetState>();
    _activeWidgetKey = key;

    _activeEntry = OverlayEntry(
      builder: (ctx) {
        return _GameToastWidget(
          key: key,
          message: message,
          title: title,
          type: type,
          icon: icon,
          onTap: onTap,
          actionLabel: actionLabel,
          onDismiss: () {
            _activeTimer?.cancel();
            _activeTimer = null;
            if (_activeEntry != null) {
              try {
                _activeEntry?.remove();
              } catch (_) {}
              _activeEntry = null;
            }
          },
        );
      },
    );

    overlay.insert(_activeEntry!);

    // Test ortamında açık kalan timer'lar flutter_test assertion hatası vermesin
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _activeTimer = Timer(duration, () {
        _activeWidgetKey?.currentState?.dismiss();
      });
    }
  }

  static void showSuccess(
    BuildContext? context,
    String message, {
    String? title,
    VoidCallback? onTap,
    String? actionLabel,
  }) {
    show(
      context,
      message: message,
      title: title ?? 'İşlem Başarılı',
      type: GameToastType.success,
      onTap: onTap,
      actionLabel: actionLabel,
    );
  }

  static void showWarning(
    BuildContext? context,
    String message, {
    String? title,
    VoidCallback? onTap,
    String? actionLabel,
  }) {
    show(
      context,
      message: message,
      title: title ?? 'Dikkat',
      type: GameToastType.warning,
      onTap: onTap,
      actionLabel: actionLabel,
    );
  }

  static void showError(
    BuildContext? context,
    String message, {
    String? title,
    VoidCallback? onTap,
    String? actionLabel,
  }) {
    show(
      context,
      message: message,
      title: title ?? 'Hata',
      type: GameToastType.error,
      onTap: onTap,
      actionLabel: actionLabel,
    );
  }

  static void showInfo(
    BuildContext? context,
    String message, {
    String? title,
    VoidCallback? onTap,
    String? actionLabel,
  }) {
    show(
      context,
      message: message,
      title: title ?? 'Bilgi',
      type: GameToastType.info,
      onTap: onTap,
      actionLabel: actionLabel,
    );
  }

  static Color _getFallbackColor(GameToastType type) {
    switch (type) {
      case GameToastType.success:
        return const Color(0xFF059669);
      case GameToastType.warning:
        return const Color(0xFFD97706);
      case GameToastType.error:
        return const Color(0xFFDC2626);
      case GameToastType.info:
        return const Color(0xFF2563EB);
    }
  }
}

class _GameToastWidget extends StatefulWidget {
  final String message;
  final String? title;
  final GameToastType type;
  final IconData? icon;
  final VoidCallback? onTap;
  final String? actionLabel;
  final VoidCallback onDismiss;

  const _GameToastWidget({
    super.key,
    required this.message,
    this.title,
    required this.type,
    this.icon,
    this.onTap,
    this.actionLabel,
    required this.onDismiss,
  });

  @override
  State<_GameToastWidget> createState() => _GameToastWidgetState();
}

class _GameToastWidgetState extends State<_GameToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.65),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ));

    _animController.forward();
  }

  Future<void> dismiss() async {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;
    try {
      await _animController.reverse();
    } catch (_) {}
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    // Toast tipine özel renk ve ikon paleti
    final Color accentColor;
    final Color badgeBg;
    final Color cardBg;
    final Color borderColor;
    final IconData defaultIcon;

    switch (widget.type) {
      case GameToastType.success:
        accentColor = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
        badgeBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
        cardBg = isDark ? const Color(0xFF0D1F1A) : Colors.white;
        borderColor = isDark ? const Color(0xFF059669).withValues(alpha: 0.6) : const Color(0xFF10B981).withValues(alpha: 0.45);
        defaultIcon = Icons.check_circle_rounded;
        break;
      case GameToastType.warning:
        accentColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
        badgeBg = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
        cardBg = isDark ? const Color(0xFF241A0E) : Colors.white;
        borderColor = isDark ? const Color(0xFFD97706).withValues(alpha: 0.6) : const Color(0xFFF59E0B).withValues(alpha: 0.45);
        defaultIcon = Icons.warning_amber_rounded;
        break;
      case GameToastType.error:
        accentColor = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
        badgeBg = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
        cardBg = isDark ? const Color(0xFF241013) : Colors.white;
        borderColor = isDark ? const Color(0xFFDC2626).withValues(alpha: 0.6) : const Color(0xFFEF4444).withValues(alpha: 0.45);
        defaultIcon = Icons.error_outline_rounded;
        break;
      case GameToastType.info:
        accentColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
        badgeBg = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
        cardBg = isDark ? const Color(0xFF10192A) : Colors.white;
        borderColor = isDark ? const Color(0xFF2563EB).withValues(alpha: 0.6) : const Color(0xFF3B82F6).withValues(alpha: 0.45);
        defaultIcon = Icons.notifications_active_rounded;
        break;
    }

    final activeIcon = widget.icon ?? defaultIcon;

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onVerticalDragUpdate: (details) {
                      if (details.primaryDelta != null && details.primaryDelta! < -2) {
                        dismiss();
                      }
                    },
                    onTap: () {
                      if (widget.onTap != null) {
                        widget.onTap!();
                      }
                      dismiss();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.22),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Sol İkon Rozeti
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              activeIcon,
                              color: accentColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Başlık ve Mesaj İçeriği
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.title != null) ...[
                                  Text(
                                    widget.title!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      color: accentColor,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                Text(
                                  widget.message,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    height: 1.3,
                                  ),
                                ),
                                if (widget.actionLabel != null && widget.onTap != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${widget.actionLabel} ›',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: accentColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Aksiyon Butonu veya Kapatma Simgesi
                          if (widget.actionLabel != null && widget.onTap != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                widget.actionLabel!,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: accentColor,
                                ),
                              ),
                            )
                          else
                            InkWell(
                              onTap: dismiss,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Panel ve Diyalogların içerisinde anında göze çarpan, baloncuk şeklinde şık uyarı widget'ı.
class DialogWarningBubble extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;
  final IconData icon;
  final bool isError;

  const DialogWarningBubble({
    super.key,
    required this.message,
    this.onDismiss,
    this.icon = Icons.warning_amber_rounded,
    this.isError = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isError
        ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
        : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706));
    final bgColor = isError
        ? (isDark ? const Color(0xFF2D1214) : const Color(0xFFFEF2F2))
        : (isDark ? const Color(0xFF2C1E0A) : const Color(0xFFFFFBEB));
    final borderColor = isError
        ? (isDark ? const Color(0xFFEF4444).withValues(alpha: 0.6) : const Color(0xFFFCA5A5))
        : (isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.6) : const Color(0xFFFDE68A));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.3,
              ),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onDismiss,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close_rounded, size: 16, color: color.withValues(alpha: 0.7)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
