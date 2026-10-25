import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import '../services/notification_service.dart';
import 'production_tab.dart';
import 'market_tab.dart';
import 'retail_tab.dart';
import 'bank_dialog.dart';
import 'warehouse_tab.dart';
import '../models/player_level.dart';
import 'offline_summary_dialog.dart';
import 'ledger_dialog.dart';
import '../services/firebase_service.dart';
import '../services/audit_log_service.dart';
import '../models/audit_log.dart';
import 'admin_dashboard_view.dart';
import 'banned_dialog.dart';
import 'session_terminated_dialog.dart';
import 'leaderboard_view.dart';
import 'headquarters_tender_dialog.dart';
import 'home_dashboard_tab.dart';
import 'profile_screen.dart';
import '../widgets/game_toast.dart';
import '../widgets/starter_career_dialog.dart';

class HomeScreen extends StatefulWidget {
  final GameController controller;
  final VoidCallback? onLoggedOut;
  final bool autoPromptStarterCareer;

  const HomeScreen({
    super.key,
    required this.controller,
    this.onLoggedOut,
    this.autoPromptStarterCareer = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
  final GlobalKey<MarketTabState> _marketTabKey = GlobalKey<MarketTabState>();
  StreamSubscription<String>? _notificationSub;
  bool _isBanDialogShowing = false;
  bool _isSessionDialogShowing = false;
  bool _isStarterDialogShowing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
    FirebaseService().isBannedNotifier.addListener(_checkBanStatus);
    FirebaseService().isSessionTerminatedNotifier.addListener(_checkSessionStatus);
    _notificationSub =
        NotificationService().onNotificationTapped.listen(_handlePhoneNotificationTap);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOfflineReport();
      _checkBanStatus();
      _checkSessionStatus();
      _checkStarterCareerPath();
    });
  }

  void _checkStarterCareerPath() {
    if (!mounted || !widget.autoPromptStarterCareer) return;
    if (widget.controller.shouldPromptStarterPathSelection && !_isStarterDialogShowing) {
      _isStarterDialogShowing = true;
      StarterCareerDialog.show(context, widget.controller).then((_) {
        _isStarterDialogShowing = false;
      });
    }
  }

  void _checkBanStatus() {
    if (!mounted) return;
    if (FirebaseService().isBannedNotifier.value && !_isBanDialogShowing) {
      _isBanDialogShowing = true;
      final reason = FirebaseService().banReasonNotifier.value;
      BannedDialog.show(
        context,
        reason: reason,
        onLoggedOut: () {
          _isBanDialogShowing = false;
          widget.onLoggedOut?.call();
        },
      );
    }
  }

  void _checkSessionStatus() {
    if (!mounted) return;
    if (FirebaseService().isSessionTerminatedNotifier.value && !_isSessionDialogShowing) {
      _isSessionDialogShowing = true;
      final reason = FirebaseService().sessionTerminatedReasonNotifier.value;
      SessionTerminatedDialog.show(
        context,
        reason: reason,
        onLoggedOut: () {
          _isSessionDialogShowing = false;
          widget.onLoggedOut?.call();
        },
      );
    }
  }

  void _checkOfflineReport() {
    if (!mounted) return;
    if (widget.controller.latestOfflineReport != null) {
      final report = widget.controller.latestOfflineReport!;
      widget.controller.clearLatestOfflineReport();
      OfflineSummaryDialog.show(context, report);
    }
  }

  @override
  void dispose() {
    FirebaseService().isBannedNotifier.removeListener(_checkBanStatus);
    FirebaseService().isSessionTerminatedNotifier.removeListener(_checkSessionStatus);
    _notificationSub?.cancel();
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _handlePhoneNotificationTap(String payload) {
    if (!mounted) return;
    if (payload == 'warehouse_full') {
      setState(() {
        _currentTabIndex = 2; // Depo sekmesine geç (Ana Sayfa: 0, Tesisler: 1, Depo: 2, Borsa: 3)
      });
      return;
    }
    setState(() {
      _currentTabIndex = 3; // Borsa & Pazar sekmesine geç (Ana Sayfa: 0, Tesisler: 1, Depo: 2, Borsa: 3)
    });
    if (payload == 'offer_incoming') {
      _marketTabKey.currentState?.switchToOffers(subTab: 0);
    } else if (payload == 'offer_outgoing') {
      _marketTabKey.currentState?.switchToOffers(subTab: 1);
    } else if (payload == 'order_limit') {
      _marketTabKey.currentState?.switchToOrders();
    }
  }

  void _onControllerUpdate() {
    if (widget.controller.latestOfflineReport != null) {
      final report = widget.controller.latestOfflineReport!;
      widget.controller.clearLatestOfflineReport();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        OfflineSummaryDialog.show(context, report);
      });
    }

    if (widget.controller.latestNotificationToast != null) {
      final msg = widget.controller.latestNotificationToast!;
      widget.controller.clearNotificationToast();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final isIncomingOffer = msg.contains('TEKLİF GELDİ');
        final isOfferApproved = msg.contains('ONAYLANDI');
        final isOfferRejected = msg.contains('REDDEDİLDİ');
        final isLimitOrder = msg.contains('ALIŞ EMRİ');
        final isClickable = isIncomingOffer || isOfferApproved || isOfferRejected || isLimitOrder;

        void navigateFromToast() {
          setState(() {
            _currentTabIndex = 3; // Borsa & Pazar ana sekmesine geç
          });
          if (isIncomingOffer) {
            _marketTabKey.currentState?.switchToOffers(subTab: 0); // Gelen Teklifler
          } else if (isOfferApproved || isOfferRejected) {
            _marketTabKey.currentState?.switchToOffers(subTab: 1); // Verilen Teklifler
          } else if (isLimitOrder) {
            _marketTabKey.currentState?.switchToOrders(); // Alış Emirlerim
          }
        }

        final title = isIncomingOffer
            ? 'Yeni Teklif Geldi'
            : (isOfferApproved
                ? 'Teklif Onaylandı'
                : (isOfferRejected
                    ? 'Teklif Reddedildi'
                    : (isLimitOrder ? 'Alış Emri Tamamlandı' : 'Piyasa Bildirimi')));

        final type = isOfferApproved
            ? GameToastType.success
            : (isOfferRejected
                ? GameToastType.error
                : (isIncomingOffer ? GameToastType.info : GameToastType.warning));

        final icon = isOfferApproved
            ? Icons.check_circle_rounded
            : (isOfferRejected
                ? Icons.cancel_rounded
                : (isIncomingOffer
                    ? Icons.mark_email_unread_rounded
                    : (isLimitOrder ? Icons.track_changes : Icons.notifications_active_rounded)));

        GameToast.show(
          context,
          title: title,
          message: msg,
          type: type,
          icon: icon,
          actionLabel: isClickable ? 'İncele' : null,
          onTap: isClickable ? navigateFromToast : null,
          duration: const Duration(seconds: 4),
        );
      });
    }
  }

  void _showAccountSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fb = FirebaseService();
    final username = fb.username ?? (fb.isGuest ? 'Misafir Oyuncu' : 'Oyuncu');
    final company = fb.companyName;
    final email = fb.email ?? (fb.isGuest ? 'Giriş yapılmadı (Misafir Modu)' : 'Tanımlı değil');
    final isLoggedIn = fb.isLoggedIn;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    controller: widget.controller,
                    onLoggedOut: widget.onLoggedOut,
                  ),
                ));
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: isDark ? const Color(0xFF0F766E) : const Color(0xFFD1FAE5),
                      child: Text(
                        username.isNotEmpty ? username[0].toUpperCase() : 'P',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF065F46),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            company,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLoggedIn
                            ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                            : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isLoggedIn ? const Color(0xFF10B981) : Colors.grey.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        isLoggedIn ? 'Bulut Bağlı ☁️' : 'Misafir 👤',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isLoggedIn ? const Color(0xFF10B981) : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    controller: widget.controller,
                    onLoggedOut: widget.onLoggedOut,
                  ),
                ));
              },
              icon: const Icon(Icons.manage_accounts_rounded, size: 18),
              label: const Text('Profili ve Şirket Bilgilerini Düzenle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                AuditLogService().log(
                  category: LogCategory.auth,
                  action: 'AUTH_LOGOUT',
                  title: 'Çıkış Yapıldı',
                  description: '$username oturumu kapattı.',
                  cashAfter: widget.controller.cash,
                );
                await FirebaseService().signOut();
                widget.controller.resetToNewGame();
                AuditLogService().clearInProcess();
                widget.onLoggedOut?.call();
              },
              icon: const Icon(Icons.logout, size: 18),
              label: Text(isLoggedIn ? 'Oturumu Kapat' : 'Giriş / Kayıt Ekranına Dön'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFFDC2626) : const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // === ÜST BİLGİ VE FİNANS ÇUBUĞU (HUD) ===
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final c = widget.controller;
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final currencyFmt = NumberFormat("#,##0", "tr_TR");
                final fb = FirebaseService();

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161C2C) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black38 : Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 1. Satır: Kullanıcı & Şirket Profili (Sol) ve Hızlı Eylemler (Sağ)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Sol: Kullanıcı Profili & Şirket Bilgisi (Dokununca Hesap Menüsü Açılır)
                      Expanded(
                        child: InkWell(
                          onTap: () => _showAccountSheet(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 17,
                                  backgroundColor: isDark ? const Color(0xFF0F766E) : const Color(0xFFD1FAE5),
                                  child: Text(
                                    (fb.username != null && fb.username!.isNotEmpty)
                                        ? fb.username![0].toUpperCase()
                                        : 'P',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF065F46),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              (fb.username != null && fb.username!.isNotEmpty)
                                                  ? fb.username!
                                                  : 'Piyasa Taciri',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.2,
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.amber.withValues(alpha: 0.2) : const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(5),
                                              border: Border.all(
                                                color: isDark
                                                    ? Colors.amber.withValues(alpha: 0.4)
                                                    : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              'Lv.${c.playerLevel}',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w900,
                                                color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        fb.companyName.isNotEmpty ? fb.companyName : 'Piyasa Holding',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Sağ: Hızlı İşlem Butonları (Holding & İhaleler, Liderlik Tablosu, Tema, Profil)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Holding Genel Merkezi & İhaleler
                          InkWell(
                            onTap: () => HeadquartersTenderDialog.show(context, controller: c),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFFD97706).withValues(alpha: 0.18) : const Color(0xFFFEF3C7),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.apartment_rounded,
                                size: 16,
                                color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),

                          // Liderlik Tablosu
                          InkWell(
                            onTap: () => LeaderboardView.show(context, controller: c),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.amber.withValues(alpha: 0.15) : const Color(0xFFFEF3C7),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.emoji_events_rounded,
                                size: 16,
                                color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),

                          // Tema Butonu
                          InkWell(
                            onTap: () => c.toggleTheme(),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                size: 16,
                                color: isDark ? Colors.amberAccent : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),

                          // Profil / Hesap Butonu
                          InkWell(
                            onTap: () => _showAccountSheet(context),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person_outline_rounded,
                                size: 16,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 2. Satır: Nakit & Net Servet Finansal Kartları (Side-by-Side Glassmorphic)
                  Row(
                    children: [
                      // Nakit Göstergesi (Dokununca Şirket Defteri Açılır)
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => LedgerDialog.show(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF10B981).withValues(alpha: 0.35)
                                      : const Color(0xFF10B981).withValues(alpha: 0.45),
                                  width: 1.1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.account_balance_wallet_rounded,
                                      size: 17,
                                      color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Kasadaki Nakit',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.grey.shade400 : const Color(0xFF047857),
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '${currencyFmt.format(c.cash)} ₺',
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w900,
                                              color: isDark ? Colors.greenAccent : const Color(0xFF065F46),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Net Servet Göstergesi (Dokununca Liderlik Tablosu & Sıralama Açılır)
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => LeaderboardView.show(context, controller: c),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.amber.withValues(alpha: 0.35)
                                      : const Color(0xFFF59E0B).withValues(alpha: 0.45),
                                  width: 1.1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.trending_up_rounded,
                                      size: 17,
                                      color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Net Servet',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.grey.shade400 : const Color(0xFFB45309),
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '${currencyFmt.format(c.netWorth)} ₺',
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w900,
                                              color: isDark ? Colors.amberAccent : const Color(0xFF92400E),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 3. Satır: Oyuncu Seviyesi, Ünvan & İlerleme Çubuğu
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _showLevelProgressionDialog(context, c, isDark),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                              : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.amber.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '⭐ Sv. ${c.playerLevel}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  c.playerTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: c.levelProgress,
                                    minHeight: 4,
                                    backgroundColor: isDark ? Colors.black45 : const Color(0xFFE2E8F0),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${currencyFmt.format(c.netWorth)} / ${currencyFmt.format(c.nextLevelNetWorth)} ₺',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  ],
                ),
              );
            },
          ),

            // === SEÇİLEN SAYFA ===
            Expanded(
              child: IndexedStack(
                index: _currentTabIndex,
                children: [
                  HomeDashboardTab(
                    controller: c,
                    onNavigateToTab: (index) => setState(() => _currentTabIndex = index),
                    onOpenBorsa: () {
                      setState(() => _currentTabIndex = 3);
                      _marketTabKey.currentState?.switchToBorsa();
                    },
                    onOpenPazar: () {
                      setState(() => _currentTabIndex = 3);
                      _marketTabKey.currentState?.switchToCommunityListings();
                    },
                    onOpenLeaderboard: () => LeaderboardView.show(context, controller: c),
                    onOpenBank: () => showDialog(
                      context: context,
                      barrierDismissible: true,
                      builder: (_) => BankDialog(controller: c),
                    ),
                    onOpenLedger: () => LedgerDialog.show(context),
                    onOpenAdmin: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminDashboardView()),
                    ),
                  ),
                  ProductionTab(controller: c),
                  WarehouseTab(controller: c),
                  MarketTab(key: _marketTabKey, controller: c),
                  RetailTab(controller: c),
                ],
              ),
            ),
          ],
        ),
      ),

      // === ALT GEZİNME ÇUBUĞU (TABS) ===
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141926) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _currentTabIndex,
            onTap: (index) => setState(() => _currentTabIndex = index),
            backgroundColor: Colors.transparent,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: isDark ? Colors.amberAccent : const Color(0xFF0F766E),
            unselectedItemColor: isDark ? Colors.grey : const Color(0xFF64748B),
            selectedFontSize: 12,
            unselectedFontSize: 11,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            elevation: 0,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Ana Sayfa',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.agriculture_outlined),
                activeIcon: Icon(Icons.agriculture),
                label: 'Tesislerim',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                activeIcon: Icon(Icons.inventory_2),
                label: 'Depo',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: c.totalActiveOffersBadge > 0,
                  label: Text('${c.totalActiveOffersBadge}'),
                  backgroundColor: Colors.redAccent,
                  child: const Icon(Icons.candlestick_chart_outlined),
                ),
                activeIcon: Badge(
                  isLabelVisible: c.totalActiveOffersBadge > 0,
                  label: Text('${c.totalActiveOffersBadge}'),
                  backgroundColor: Colors.redAccent,
                  child: const Icon(Icons.candlestick_chart),
                ),
                label: 'Borsa & Pazar',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.storefront_outlined),
                activeIcon: Icon(Icons.storefront),
                label: 'Dükkanlarım',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLevelProgressionDialog(BuildContext context, GameController c, bool isDark) {
    final currencyFmt = NumberFormat("#,##0", "tr_TR");

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Oyuncu Seviyeleri ve Ünvanlar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Mevcut Seviye Özeti
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                            : [const Color(0xFFFEF3C7), const Color(0xFFFFFBEB)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.amber.withOpacity(0.4) : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '⭐ Seviye ${c.playerLevel}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                c.playerTitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF78350F),
                                ),
                              ),
                            ),
                            Text(
                              '${(c.levelProgress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: c.levelProgress,
                            minHeight: 6,
                            backgroundColor: isDark ? Colors.black45 : const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Net Servet: ${currencyFmt.format(c.netWorth)} ₺',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Sonraki: ${currencyFmt.format(c.nextLevelNetWorth)} ₺',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        LeaderboardView.show(context, controller: c);
                      },
                      icon: const Icon(Icons.emoji_events_rounded, size: 16),
                      label: const Text(
                        '🏆 Oyuncu Sıralamalarını & Liderliği İncele',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Seviye Kademeleri & Ayrıcalıklar:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Kademeler Listesi
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: PlayerLevelInfo.tiers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final tier = PlayerLevelInfo.tiers[index];
                        final isCurrent = tier.level == c.playerLevel;
                        final isUnlocked = tier.level <= c.playerLevel;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? (isDark ? const Color(0xFF292524) : const Color(0xFFFEF3C7))
                                : (isDark ? const Color(0xFF1E283E) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCurrent
                                  ? const Color(0xFFD97706)
                                  : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                              width: isCurrent ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(tier.icon, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Sv. ${tier.level} - ${tier.title}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          tier.minNetWorth == 0.0
                                              ? 'Başlangıç'
                                              : '${currencyFmt.format(tier.minNetWorth)} ₺',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isUnlocked
                                                ? (isDark ? Colors.greenAccent : const Color(0xFF059669))
                                                : (isDark ? Colors.grey : const Color(0xFF94A3B8)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      tier.perkDescription,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (isCurrent)
                                const Icon(Icons.star, size: 16, color: Color(0xFFD97706))
                              else if (isUnlocked)
                                const Icon(Icons.check_circle, size: 15, color: Color(0xFF10B981))
                              else
                                const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
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
