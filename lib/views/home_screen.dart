import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import 'production_tab.dart';
import 'market_tab.dart';
import 'retail_tab.dart';
import 'bank_dialog.dart';
import 'inventory_sheet.dart';

class HomeScreen extends StatefulWidget {
  final GameController controller;

  const HomeScreen({super.key, required this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (widget.controller.latestNotificationToast != null) {
      final msg = widget.controller.latestNotificationToast!;
      widget.controller.clearNotificationToast();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  msg.contains('ONAYLANDI')
                      ? Icons.check_circle_outline
                      : (msg.contains('REDDEDİLDİ') ? Icons.cancel_outlined : Icons.notifications_active),
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    msg,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: msg.contains('ONAYLANDI')
                ? const Color(0xFF059669)
                : (msg.contains('REDDEDİLDİ') ? const Color(0xFFDC2626) : const Color(0xFF2563EB)),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      });
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final currencyFmt = NumberFormat("#,##0", "tr_TR");
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // === ÜST BİLGİ VE FİNANS ÇUBUĞU (HUD) ===
            Container(
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
                  // 1. Satır: Logo & Hızlı İşlem Butonları (Banka, Depo, Tema)
                  Row(
                    children: [
                      // Logo & İsim
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.amber.withOpacity(0.2) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('💰', style: TextStyle(fontSize: 22)),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PİYASA',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  color: isDark ? Colors.amberAccent : const Color(0xFF0F766E),
                                ),
                              ),
                              Text(
                                'Ticaret & Borsa',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Depo Butonu
                      InkWell(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => InventorySheet(controller: c),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.blueGrey[800] : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? Colors.transparent : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 16,
                                color: isDark ? Colors.white : const Color(0xFF334155),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${c.currentWarehouseWeight.toInt()} kg',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Banka Butonu
                      ElevatedButton.icon(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => BankDialog(controller: c),
                        ),
                        icon: const Icon(Icons.account_balance, size: 15),
                        label: const Text('Banka'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.blueAccent[700] : const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Tema Değiştirme Butonu (Dark / Light)
                      IconButton(
                        onPressed: () => c.toggleTheme(),
                        icon: Icon(
                          isDark ? Icons.light_mode : Icons.dark_mode,
                          color: isDark ? Colors.amberAccent : const Color(0xFF475569),
                        ),
                        tooltip: isDark ? 'Açık Temaya Geç' : 'Karanlık Temaya Geç',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 2. Satır: Nakit & Net Servet Finansal Kartları
                  Row(
                    children: [
                      // Nakit Göstergesi
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0D121D) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? Colors.greenAccent.withOpacity(0.4)
                                  : const Color(0xFF10B981).withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 18,
                                color: isDark ? Colors.greenAccent : const Color(0xFF059669),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Kasadaki Nakit',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? Colors.grey : const Color(0xFF047857),
                                      ),
                                    ),
                                    Text(
                                      '${currencyFmt.format(c.cash)} ₺',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.greenAccent : const Color(0xFF065F46),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Net Servet Göstergesi
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0D121D) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? Colors.amber.withOpacity(0.4)
                                  : const Color(0xFFF59E0B).withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.trending_up,
                                size: 18,
                                color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Net Servet',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? Colors.grey : const Color(0xFFB45309),
                                      ),
                                    ),
                                    Text(
                                      '${currencyFmt.format(c.netWorth)} ₺',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.amberAccent : const Color(0xFF92400E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // === SEÇİLEN SAYFA ===
            Expanded(
              child: IndexedStack(
                index: _currentTabIndex,
                children: [
                  ProductionTab(controller: c),
                  MarketTab(controller: c),
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
            selectedFontSize: 13,
            unselectedFontSize: 12,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            elevation: 0,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.agriculture_outlined),
                activeIcon: Icon(Icons.agriculture),
                label: 'Tesislerim',
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
}
