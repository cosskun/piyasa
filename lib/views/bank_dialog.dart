import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';

class BankDialog extends StatefulWidget {
  final GameController controller;

  const BankDialog({super.key, required this.controller});

  @override
  State<BankDialog> createState() => _BankDialogState();
}

class _BankDialogState extends State<BankDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double _depositInput = 1000;
  double _loanInput = 5000;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat("#,##0", "tr_TR");
    final c = widget.controller;

    return Dialog(
      backgroundColor: const Color(0xFF141A29),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🏦', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                const Text(
                  'Merkez Ticaret Bankası',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Özet Finans Kartı
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem('Vadesiz Kasa', '${currencyFmt.format(c.cash)} ₺', Colors.greenAccent),
                  _statItem('Vadeli Mevduat', '${currencyFmt.format(c.bankSavings)} ₺', Colors.amberAccent),
                  _statItem('Aktif Kredi Borcu', '${currencyFmt.format(c.activeLoan)} ₺', Colors.redAccent),
                ],
              ),
            ),
            const SizedBox(height: 12),

            TabBar(
              controller: _tabController,
              indicatorColor: Colors.amberAccent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Vadeli Mevduat (Faiz)'),
                Tab(text: 'Banka Kredisi'),
              ],
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 220,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 1. MEVDUAT
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💡 Paranızı vadeli hesaba yatırarak her saat %0.5 faiz geliri elde edin.',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: c.cash >= 1000 ? () => c.depositToBank(1000) : null,
                              icon: const Icon(Icons.arrow_upward, size: 16),
                              label: const Text('+1.000 ₺ Yatır'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: c.cash >= 5000 ? () => c.depositToBank(5000) : null,
                              icon: const Icon(Icons.arrow_upward, size: 16),
                              label: const Text('+5.000 ₺ Yatır'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: c.cash > 0 ? () => c.depositToBank(c.cash) : null,
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.greenAccent),
                              child: const Text('Tüm Kasayı Yatır'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: c.bankSavings > 0 ? () => c.withdrawFromBank(c.bankSavings) : null,
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.amberAccent),
                              child: const Text('Mevduatı Geri Çek'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // 2. KREDİ
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '⚠️ Büyümeyi hızlandırmak için kredi çekin. Kredinin saatlik %1.2 faiz yükü vardır.',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final err = c.takeLoan(5000);
                                if (err != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                }
                              },
                              icon: const Icon(Icons.attach_money, size: 16),
                              label: const Text('5.000 ₺ Kredi Çek'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent[700]),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final err = c.takeLoan(20000);
                                if (err != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                }
                              },
                              icon: const Icon(Icons.attach_money, size: 16),
                              label: const Text('20.000 ₺ Kredi Çek'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[700]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (c.activeLoan > 0)
                        ElevatedButton.icon(
                          onPressed: c.cash > 0 ? () => c.repayLoan(c.cash) : null,
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Kredi Borcunu Kapat'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent[700],
                            minimumSize: const Size.fromHeight(40),
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
    );
  }

  Widget _statItem(String label, String value, Color col) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: col)),
      ],
    );
  }
}
