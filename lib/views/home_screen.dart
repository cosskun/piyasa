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
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final currencyFmt = NumberFormat("#,##0", "tr_TR");

    return Scaffold(
      backgroundColor: const Color(0xFF0F131D),
      body: SafeArea(
        child: Column(
          children: [
            // === ÜST BİLGİ VE FİNANS ÇUBUĞU (HUD) ===
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF161C2C),
                boxShadow: [
                  BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  // Logo & İsim
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('💰', style: TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PİYASA',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: Colors.amberAccent,
                            ),
                          ),
                          Text(
                            'Ticaret & Borsa',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Nakit Göstergesi
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D121D),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Kasadaki Nakit', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(
                          '${currencyFmt.format(c.cash)} ₺',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Net Servet
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D121D),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Net Servet', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(
                          '${currencyFmt.format(c.netWorth)} ₺',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.amberAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Depo Butonu
                  InkWell(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => InventorySheet(controller: c),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '${c.currentWarehouseWeight.toInt()} kg',
                            style: const TextStyle(fontSize: 12, color: Colors.white),
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
                    icon: const Icon(Icons.account_balance, size: 16),
                    label: const Text('Banka'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
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
        decoration: const BoxDecoration(
          color: Color(0xFF141926),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) => setState(() => _currentTabIndex = index),
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.amberAccent,
          unselectedItemColor: Colors.grey,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.agriculture),
              activeIcon: Icon(Icons.agriculture, color: Colors.amberAccent),
              label: '🌾 Tesislerim (Üretim)',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.candlestick_chart),
              activeIcon: Icon(Icons.candlestick_chart, color: Colors.amberAccent),
              label: '📊 Hammadde Borsası',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.storefront),
              activeIcon: Icon(Icons.storefront, color: Colors.amberAccent),
              label: '🏪 Dükkanlarım (Perakende)',
            ),
          ],
        ),
      ),
    );
  }
}
