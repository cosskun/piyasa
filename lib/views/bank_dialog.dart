import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../controllers/game_controller.dart';
import '../models/bank_loan.dart';

class BankDialog extends StatefulWidget {
  final GameController controller;

  const BankDialog({super.key, required this.controller});

  @override
  State<BankDialog> createState() => _BankDialogState();
}

class _BankDialogState extends State<BankDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Vadeli Mevduat Durumu
  int _savingsModeIndex = 0; // 0: Para Yatır, 1: Para Çek
  late TextEditingController _savingsAmountController;
  double _savingsAmount = 1000.0;

  // Özel Kredi Hesaplayıcı Durumu
  double _customLoanAmount = 15000.0;
  int _customLoanDays = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Başlangıç için mantıklı bir mevduat tutarı (kasanın bir kısmı veya 1.000 ₺)
    final initialAmount = widget.controller.cash > 0
        ? min(1000.0, widget.controller.cash)
        : 1000.0;
    _savingsAmount = initialAmount;
    _savingsAmountController = TextEditingController(text: initialAmount.toInt().toString());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _savingsAmountController.dispose();
    super.dispose();
  }

  void _closeDialog() {
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _updateSavingsAmount(double amount, double maxLimit) {
    final clamped = amount.clamp(0.0, max(0.0, maxLimit)).toDouble();
    setState(() {
      _savingsAmount = clamped;
      _savingsAmountController.text = clamped.toInt().toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat("#,##0", "tr_TR");
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final c = widget.controller;

          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. ÜST BAŞLIK & KAPATMA BUTONU
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F766E).withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text('🏦', style: TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Merkez Ticaret Bankası',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _closeDialog,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 2. ÖZET FİNANS ŞERİDİ (AYRI 3 ŞIK KART - ÇAKIŞMA / TAŞMA ASLA OLMAZ)
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeaderMetricCard(
                          title: 'Vadesiz Kasa',
                          amount: '${currencyFmt.format(c.cash)} ₺',
                          icon: Icons.account_balance_wallet_outlined,
                          color: const Color(0xFF10B981),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildHeaderMetricCard(
                          title: 'Vadeli Mevduat',
                          amount: '${currencyFmt.format(c.bankSavings)} ₺',
                          icon: Icons.savings_outlined,
                          color: const Color(0xFFF59E0B),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildHeaderMetricCard(
                          title: 'Toplam Borç',
                          amount: '${currencyFmt.format(c.activeLoan)} ₺',
                          icon: Icons.receipt_long_outlined,
                          color: const Color(0xFFEF4444),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 3. SEGMENTED TAB SWITCHER
                  Container(
                    height: 40,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF64748B),
                      labelPadding: EdgeInsets.zero,
                      tabs: [
                        Tab(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text('💰', style: TextStyle(fontSize: 14)),
                                SizedBox(width: 6),
                                Text(
                                  'Vadeli Mevduat',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Tab(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text('💳', style: TextStyle(fontSize: 14)),
                                SizedBox(width: 6),
                                Text(
                                  'Kredi & Ödeme Planı',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 4. İÇERİK SEKME GÖRÜNÜMÜ
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDynamicSavingsView(c, isDark),
                        _buildDetailedLoanView(c, isDark),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Divider(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0), height: 1),
                  const SizedBox(height: 8),

                  // 5. ALT KAPAT BUTONU (TEK SATIR & ÖZEL TASARIM)
                  _buildCustomButton(
                    onPressed: _closeDialog,
                    label: 'Kapat / Oyuna Dön',
                    icon: Icons.check_circle_outline,
                    gradientColors: [
                      isDark ? const Color(0xFF2E3E60) : const Color(0xFF334155),
                      isDark ? const Color(0xFF1E283E) : const Color(0xFF1E293B),
                    ],
                    shadowColor: Colors.black26,
                    verticalPadding: 9,
                    fontSize: 13,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // ÜST BİLGİ KARTLARI (KASA / MEVDUAT / BORÇ)
  // ==========================================
  Widget _buildHeaderMetricCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.12) : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? color.withOpacity(0.3) : color.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DİNAMİK VADELİ MEVDUAT EKRANI (FAİZ & MEVDUAT İŞLEMLERİ)
  // ==========================================
  Widget _buildDynamicSavingsView(GameController c, bool isDark) {
    final currencyFmt = NumberFormat("#,##0", "tr_TR");
    final isDepositMode = _savingsModeIndex == 0;
    final maxLimit = isDepositMode ? c.cash : c.bankSavings;

    // Saatlik faiz: %0.50 (Her 60 saniyede bir oyun içi tahakkuk)
    final expectedHourlyEarnings = _savingsAmount * 0.005;
    final expectedDailyEarnings = expectedHourlyEarnings * 24;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bilgilendirme Rozeti
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF143026), const Color(0xFF0D1F18)]
                    : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.tealAccent.withOpacity(0.3) : const Color(0xFFA7F3D0),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up, size: 18, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    maxLines: 2,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : const Color(0xFF065F46),
                      ),
                      children: const [
                        TextSpan(
                          text: 'Saatlik Mevduat Getirisi: %0.50  ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: '(Her 60 sn döngüde bir faiz otomatik işler)'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // İŞLEM TÜRÜ SEÇİCİ (YATIR / ÇEK)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B2234) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSegmentButton(
                    label: '📥 Kasadan Faize Yatır',
                    isSelected: isDepositMode,
                    activeColor: const Color(0xFF059669),
                    isDark: isDark,
                    onTap: () {
                      setState(() {
                        _savingsModeIndex = 0;
                        _updateSavingsAmount(min(1000.0, c.cash), c.cash);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildSegmentButton(
                    label: '📤 Mevduattan Çek',
                    isSelected: !isDepositMode,
                    activeColor: const Color(0xFFD97706),
                    isDark: isDark,
                    onTap: () {
                      setState(() {
                        _savingsModeIndex = 1;
                        _updateSavingsAmount(min(1000.0, c.bankSavings), c.bankSavings);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // DİNAMİK TUTAR GİRİŞ KUTUSU
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF182032) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDepositMode
                    ? (isDark ? const Color(0xFF059669).withOpacity(0.5) : const Color(0xFFA7F3D0))
                    : (isDark ? const Color(0xFFD97706).withOpacity(0.5) : const Color(0xFFFDE68A)),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isDepositMode ? 'Yatırılacak Miktar (₺):' : 'Çekilecek Miktar (₺):',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    Text(
                      isDepositMode
                          ? 'Mevcut Kasa: ${currencyFmt.format(c.cash)} ₺'
                          : 'Mevcut Mevduat: ${currencyFmt.format(c.bankSavings)} ₺',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDepositMode
                            ? (isDark ? Colors.greenAccent : const Color(0xFF059669))
                            : (isDark ? Colors.amberAccent : const Color(0xFFD97706)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Dinamik Tutar Girişi (TextField + Silme + Maksimum Butonu)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '₺',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDepositMode ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _savingsAmountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: const InputDecoration(
                            hintText: '0',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (val) {
                            final parsed = double.tryParse(val) ?? 0.0;
                            setState(() {
                              _savingsAmount = parsed;
                            });
                          },
                        ),
                      ),
                      if (_savingsAmountController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: Colors.grey,
                          onPressed: () {
                            setState(() {
                              _savingsAmount = 0.0;
                              _savingsAmountController.clear();
                            });
                          },
                        ),
                      const SizedBox(width: 6),
                      // MAKSİMUM KISAYOL BUTONU
                      InkWell(
                        onTap: () => _updateSavingsAmount(maxLimit, maxLimit),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDepositMode
                                ? (isDark ? const Color(0xFF065F46) : const Color(0xFFD1FAE5))
                                : (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Maksimum',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDepositMode
                                  ? (isDark ? Colors.greenAccent : const Color(0xFF047857))
                                  : (isDark ? Colors.amberAccent : const Color(0xFFB45309)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // DİNAMİK MİKTAR KAYDIRICI (SLIDER)
                if (maxLimit > 0) ...[
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: _savingsAmount.clamp(0.0, maxLimit),
                      min: 0.0,
                      max: maxLimit,
                      divisions: maxLimit > 100 ? min(100, max(1, (maxLimit / 100).round())) : null,
                      activeColor: isDepositMode ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      inactiveColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      onChanged: (val) {
                        setState(() {
                          _savingsAmount = val;
                          _savingsAmountController.text = val.toInt().toString();
                        });
                      },
                    ),
                  ),
                ],

                // HIZLI TUTAR & YÜZDE BUTONLARI (TEK SATIR ÇİPLER)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickAmountChip('+1.000 ₺', () {
                        _updateSavingsAmount(_savingsAmount + 1000, maxLimit);
                      }, isDark),
                      const SizedBox(width: 6),
                      _buildQuickAmountChip('+5.000 ₺', () {
                        _updateSavingsAmount(_savingsAmount + 5000, maxLimit);
                      }, isDark),
                      const SizedBox(width: 6),
                      _buildQuickAmountChip('+25.000 ₺', () {
                        _updateSavingsAmount(_savingsAmount + 25000, maxLimit);
                      }, isDark),
                      const SizedBox(width: 6),
                      _buildQuickAmountChip('%25', () {
                        _updateSavingsAmount(maxLimit * 0.25, maxLimit);
                      }, isDark),
                      const SizedBox(width: 6),
                      _buildQuickAmountChip('%50', () {
                        _updateSavingsAmount(maxLimit * 0.50, maxLimit);
                      }, isDark),
                      const SizedBox(width: 6),
                      _buildQuickAmountChip('%100 (Tümü)', () {
                        _updateSavingsAmount(maxLimit, maxLimit);
                      }, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // TAHMİNİ GETİRİ & BAKİYE SİMÜLASYONU KARTI
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141C2B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: isDepositMode
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSimItem(
                        'Döngü Başı (60 sn)',
                        '+${currencyFmt.format(expectedHourlyEarnings)} ₺',
                        Colors.greenAccent,
                        isDark,
                      ),
                      _buildSimItem(
                        '24 Döngü Getirisi',
                        '+${currencyFmt.format(expectedDailyEarnings)} ₺',
                        Colors.amberAccent,
                        isDark,
                      ),
                      _buildSimItem(
                        'Kalan Kasa',
                        '${currencyFmt.format(max(0.0, c.cash - _savingsAmount))} ₺',
                        isDark ? Colors.white70 : const Color(0xFF475569),
                        isDark,
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSimItem(
                        'Kasaya Geçecek',
                        '+${currencyFmt.format(min(_savingsAmount, c.bankSavings))} ₺',
                        Colors.greenAccent,
                        isDark,
                      ),
                      _buildSimItem(
                        'Kalan Mevduat',
                        '${currencyFmt.format(max(0.0, c.bankSavings - _savingsAmount))} ₺',
                        Colors.amberAccent,
                        isDark,
                      ),
                      _buildSimItem(
                        'Yeni Kasa',
                        '${currencyFmt.format(c.cash + min(_savingsAmount, c.bankSavings))} ₺',
                        isDark ? Colors.white70 : const Color(0xFF475569),
                        isDark,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),

          // ÖZEL BUTONLAR (TEK SATIR VE ULTRA MODERN GRADIENT TASARIM)
          if (isDepositMode) ...[
            _buildCustomButton(
              onPressed: () {
                if (_savingsAmount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lütfen yatırılacak tutarı girin.')),
                  );
                  return;
                }
                if (c.cash < _savingsAmount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Yetersiz nakit! Kasanızda ${currencyFmt.format(c.cash)} ₺ var.'),
                    ),
                  );
                  return;
                }
                final err = c.depositToBank(_savingsAmount);
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${currencyFmt.format(_savingsAmount)} ₺ vadeli hesaba yatırıldı!'),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                  setState(() {
                    _savingsAmount = min(1000.0, c.cash);
                    _savingsAmountController.text = _savingsAmount.toInt().toString();
                  });
                }
              },
              label: _savingsAmount > 0
                  ? '${currencyFmt.format(_savingsAmount)} ₺ Kasadan Faize Yatır'
                  : 'Faize Yatır',
              icon: Icons.arrow_upward,
              gradientColors: const [Color(0xFF059669), Color(0xFF10B981)],
              shadowColor: const Color(0xFF059669),
              verticalPadding: 11,
              fontSize: 13,
            ),
            const SizedBox(height: 6),
            _buildCustomButton(
              onPressed: c.cash > 0
                  ? () {
                      final all = c.cash;
                      c.depositToBank(all);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Tüm kasanız (${currencyFmt.format(all)} ₺) faize yatırıldı!'),
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                      setState(() {
                        _savingsAmount = 0.0;
                        _savingsAmountController.clear();
                      });
                    }
                  : null,
              label: 'Tüm Kasayı Yatır (${currencyFmt.format(c.cash)} ₺)',
              icon: Icons.bolt,
              isOutlined: true,
              gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
              verticalPadding: 9,
              fontSize: 12,
            ),
          ] else ...[
            _buildCustomButton(
              onPressed: () {
                if (_savingsAmount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lütfen çekilecek tutarı girin.')),
                  );
                  return;
                }
                if (c.bankSavings < _savingsAmount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Mevduatınızda bu kadar para yok! Mevcut: ${currencyFmt.format(c.bankSavings)} ₺'),
                    ),
                  );
                  return;
                }
                final err = c.withdrawFromBank(_savingsAmount);
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${currencyFmt.format(_savingsAmount)} ₺ kasanıza aktarıldı!'),
                      backgroundColor: const Color(0xFFD97706),
                    ),
                  );
                  setState(() {
                    _savingsAmount = min(1000.0, c.bankSavings);
                    _savingsAmountController.text = _savingsAmount.toInt().toString();
                  });
                }
              },
              label: _savingsAmount > 0
                  ? '${currencyFmt.format(min(_savingsAmount, c.bankSavings))} ₺ Mevduattan Kasaya Çek'
                  : 'Mevduatı Çek',
              icon: Icons.arrow_downward,
              gradientColors: const [Color(0xFFD97706), Color(0xFFF59E0B)],
              shadowColor: const Color(0xFFD97706),
              verticalPadding: 11,
              fontSize: 13,
            ),
            const SizedBox(height: 6),
            _buildCustomButton(
              onPressed: c.bankSavings > 0
                  ? () {
                      final all = c.bankSavings;
                      c.withdrawFromBank(all);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Tüm mevduatınız (${currencyFmt.format(all)} ₺) kasanıza çekildi!'),
                          backgroundColor: const Color(0xFFD97706),
                        ),
                      );
                      setState(() {
                        _savingsAmount = 0.0;
                        _savingsAmountController.clear();
                      });
                    }
                  : null,
              label: 'Tüm Mevduatı Çek (${currencyFmt.format(c.bankSavings)} ₺)',
              icon: Icons.account_balance_wallet,
              isOutlined: true,
              gradientColors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
              verticalPadding: 9,
              fontSize: 12,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAmountChip(String label, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E283E) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildSimItem(String title, String val, Color valColor, bool isDark) {
    return Column(
      children: [
        Text(
          title,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            val,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: valColor,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // AYRINTILI KREDİ EKRANI (ÖDEME PLANI & FAİZ KADEMELERİ)
  // ==========================================
  Widget _buildDetailedLoanView(GameController c, bool isDark) {
    final currencyFmt = NumberFormat("#,##0", "tr_TR");

    // EĞER OYUNCUNUN AKTİF BİR KREDİSİ VARSA:
    if (c.currentLoan != null && !c.currentLoan!.isFullyPaid) {
      final loan = c.currentLoan!;
      final earlyPayoffCost = loan.remainingPrincipal + (loan.remainingInterest * 0.5);

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Aktif Kredi Başlık Kartı
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E283E) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.blueAccent.withOpacity(0.4) : const Color(0xFFBFDBFE),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('📑', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loan.title,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber[700],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Faiz: %${(loan.interestRate * 100).toStringAsFixed(1)}',
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // İlerleme Çubuğu (Ödenen Gün / Taksit)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: loan.paymentProgress,
                      minHeight: 7,
                      backgroundColor: isDark ? Colors.black38 : const Color(0xFFCBD5E1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? Colors.greenAccent : const Color(0xFF059669),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ödenen: ${loan.paidInstallments} / ${loan.totalInstallments} Gün',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                      Text(
                        'Kalan: ${loan.remainingInstallmentsCount} Gün',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                  Divider(
                    color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                    height: 14,
                  ),

                  // Kalan Borç Detayı
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('Kalan Anapara',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.grey : const Color(0xFF64748B))),
                          FittedBox(
                            child: Text('${currencyFmt.format(loan.remainingPrincipal)} ₺',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text('Kalan Faiz',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.grey : const Color(0xFF64748B))),
                          FittedBox(
                            child: Text('${currencyFmt.format(loan.remainingInterest)} ₺',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.orange[400])),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text('Günlük Taksit',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.grey : const Color(0xFF64748B))),
                          FittedBox(
                            child: Text('${currencyFmt.format(loan.singleInstallmentAmount)} ₺',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.green)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ÖDEME AKSIYON BUTONLARI (TEK SATIR VE ÖZEL GRADIENT)
            _buildCustomButton(
              onPressed: c.cash >= loan.singleInstallmentAmount ? () => c.payLoanInstallment() : null,
              label: '1 Günlük Taksit Öde (${currencyFmt.format(loan.singleInstallmentAmount)} ₺)',
              icon: Icons.payment,
              gradientColors: const [Color(0xFF059669), Color(0xFF10B981)],
              shadowColor: const Color(0xFF059669),
              verticalPadding: 10,
              fontSize: 12,
            ),
            const SizedBox(height: 6),
            _buildCustomButton(
              onPressed: c.cash >= earlyPayoffCost ? () => c.repayEntireLoanEarly() : null,
              label: 'Erken Kapat: ${currencyFmt.format(earlyPayoffCost)} ₺ (%50 İndirimli)',
              icon: Icons.flash_on,
              gradientColors: const [Color(0xFFD97706), Color(0xFFF59E0B)],
              shadowColor: const Color(0xFFD97706),
              verticalPadding: 10,
              fontSize: 12,
            ),
            const SizedBox(height: 8),

            // Ödeme Planını Görüntüle Butonu
            _buildCustomButton(
              onPressed: () => _showAmortizationScheduleDialog(
                context,
                title: loan.title,
                principal: loan.principal,
                interestRate: loan.interestRate,
                installments: loan.totalInstallments,
                schedule: loan.schedule,
                isDark: isDark,
              ),
              label: '📋 Günlük Ödeme Tablosunu ve Taksitleri Gör',
              icon: Icons.calendar_month,
              isOutlined: true,
              gradientColors: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
              verticalPadding: 9,
              fontSize: 12,
            ),
          ],
        ),
      );
    }

    // AKTİF KREDİ YOKSA -> YENİ KREDİ ÇEKME & PLAN SEÇME
    final maxLimit = c.maxLoanLimit;
    _customLoanAmount = _customLoanAmount.clamp(5000.0, maxLimit).toDouble();
    final customRate = c.getInterestRateForAmount(_customLoanAmount);
    final customSchedule = BankLoan.generateSchedule(
      principal: _customLoanAmount,
      interestRatePerPeriod: customRate,
      installments: _customLoanDays,
    );
    final customDailyPayment = customSchedule.first.totalAmount;
    final customTotalRepay = customDailyPayment * _customLoanDays;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kredi Limiti Bilgisi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E283E) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.blueAccent.withOpacity(0.3) : const Color(0xFFBFDBFE),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 16, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Net Servetinize Göre Kullanılabilir Kredi Limiti: ${currencyFmt.format(maxLimit)} ₺',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E40AF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 1. HAZIR KREDİ PAKETLERİ (Kademeli Faiz Oranları)
          Text(
            'Kademeli Kredi Paketleri:',
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildLoanPackageCard(
                c: c,
                title: 'Mikro İşletme',
                emoji: '🌱',
                amount: min(10000.0, maxLimit),
                days: 10,
                rateText: '%0.8 Faiz',
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              _buildLoanPackageCard(
                c: c,
                title: 'KOBİ Büyüme',
                emoji: '📈',
                amount: min(35000.0, maxLimit),
                days: 15,
                rateText: '%1.2 Faiz',
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              _buildLoanPackageCard(
                c: c,
                title: 'Sanayi Mega',
                emoji: '🏭',
                amount: min(80000.0, maxLimit),
                days: 20,
                rateText: '%1.6 Faiz',
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. ÖZEL KREDİ HESAPLAYICI (Kullanıcı İstediği Tutarı ve Günü Seçer)
          Text(
            '⚙️ Özel Tutar & Vade Belirle:',
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF182032) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Çekilecek Tutar:',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${currencyFmt.format(_customLoanAmount)} ₺',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _customLoanAmount,
                  min: 5000.0,
                  max: maxLimit > 5000 ? maxLimit : 5000.0,
                  divisions: max(1, ((maxLimit - 5000) / 2500).round()),
                  activeColor: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                  onChanged: (val) => setState(() => _customLoanAmount = val),
                ),

                // Vade (Gün Sayısı) Seçimi
                Row(
                  children: [
                    Text('Vade:',
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
                    const SizedBox(width: 8),
                    _dayChoiceChip(5, isDark),
                    const SizedBox(width: 5),
                    _dayChoiceChip(10, isDark),
                    const SizedBox(width: 5),
                    _dayChoiceChip(15, isDark),
                    const SizedBox(width: 5),
                    _dayChoiceChip(20, isDark),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),

                // Hesaplanan Faiz & Günlük Taksit Özeti
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Kademeli Faiz Oranı:',
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
                    Text('%${(customRate * 100).toStringAsFixed(1)} (Günlük)',
                        maxLines: 1,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11, color: Colors.amber)),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Günlük Taksit:',
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
                    Text('${currencyFmt.format(customDailyPayment)} ₺ / Gün',
                        maxLines: 1,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Toplam Geri Ödeme:',
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
                    Text('${currencyFmt.format(customTotalRepay)} ₺',
                        maxLines: 1,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),

                // Aksiyon Butonları (Ödeme Planı İncele & Krediyi Çek)
                Row(
                  children: [
                    Expanded(
                      child: _buildCustomButton(
                        onPressed: () => _showAmortizationScheduleDialog(
                          context,
                          title: 'Özel Kredi',
                          principal: _customLoanAmount,
                          interestRate: customRate,
                          installments: _customLoanDays,
                          schedule: customSchedule,
                          isDark: isDark,
                        ),
                        label: 'Ödeme Planı',
                        icon: Icons.calendar_today,
                        isOutlined: true,
                        gradientColors: const [Color(0xFF64748B), Color(0xFF475569)],
                        verticalPadding: 8,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCustomButton(
                        onPressed: () {
                          final err = c.takeDetailedLoan(
                            principal: _customLoanAmount,
                            installments: _customLoanDays,
                            title: 'Özel İşletme Kredisi',
                          );
                          if (err != null) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '${currencyFmt.format(_customLoanAmount)} ₺ kredi kasanıza aktarıldı!'),
                                backgroundColor: const Color(0xFF059669),
                              ),
                            );
                          }
                        },
                        label: 'Krediyi Çek',
                        icon: Icons.check,
                        gradientColors: const [Color(0xFF2563EB), Color(0xFF3B82F6)],
                        shadowColor: const Color(0xFF2563EB),
                        verticalPadding: 8,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanPackageCard({
    required GameController c,
    required String title,
    required String emoji,
    required double amount,
    required int days,
    required String rateText,
    required bool isDark,
  }) {
    final currencyFmt = NumberFormat("#,##0", "tr_TR");
    final rate = c.getInterestRateForAmount(amount);
    final schedule = BankLoan.generateSchedule(
      principal: amount,
      interestRatePerPeriod: rate,
      installments: days,
    );
    final dailyPayment = schedule.first.totalAmount;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF182032) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${currencyFmt.format(amount)} ₺',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                ),
              ),
            ),
            Text(
              '$days Gün • $rateText',
              maxLines: 1,
              style: TextStyle(
                fontSize: 9,
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => _showAmortizationScheduleDialog(
                context,
                title: title,
                principal: amount,
                interestRate: rate,
                installments: days,
                schedule: schedule,
                isDark: isDark,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Plan: ${currencyFmt.format(dailyPayment)} ₺/gün',
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _buildCustomButton(
              onPressed: () {
                final err = c.takeDetailedLoan(principal: amount, installments: days, title: title);
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$title (${currencyFmt.format(amount)} ₺) kasanıza aktarıldı!'),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                }
              },
              label: 'Krediyi Çek',
              gradientColors: const [Color(0xFF2563EB), Color(0xFF3B82F6)],
              shadowColor: const Color(0xFF2563EB),
              verticalPadding: 5,
              fontSize: 10,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayChoiceChip(int days, bool isDark) {
    final isSelected = _customLoanDays == days;
    return InkWell(
      onTap: () => setState(() => _customLoanDays = days),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.amberAccent[700] : const Color(0xFFD97706))
              : (isDark ? Colors.black26 : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          '$days Gün',
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey[300] : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // ÖDEME PLANI DETAY DİYALOĞU (GÜNLÜK TAKSİTLER TABLOSU)
  // ==========================================
  void _showAmortizationScheduleDialog(
    BuildContext context, {
    required String title,
    required double principal,
    required double interestRate,
    required int installments,
    required List<LoanInstallment> schedule,
    required bool isDark,
  }) {
    final currencyFmt = NumberFormat("#,##0.00", "tr_TR");
    final totalInterest = principal * interestRate * installments;
    final totalPayable = principal + totalInterest;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        title: Row(
          children: [
            const Icon(Icons.table_chart_outlined, color: Colors.blueAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$title - Günlük Ödeme Planı',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Özet Şerit
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _planHeaderItem('Anapara', '${currencyFmt.format(principal)} ₺', isDark),
                    _planHeaderItem(
                      'Toplam Faiz',
                      '${currencyFmt.format(totalInterest)} ₺',
                      isDark,
                      isWarn: true,
                    ),
                    _planHeaderItem('Toplam Borç', '${currencyFmt.format(totalPayable)} ₺', isDark),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Tablo Başlıkları
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E283E) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 45,
                      child: Text('Gün', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: Text('Anapara',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: Text('Faiz',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: Text('Taksit',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: Text('Kalan Borç',
                          textAlign: TextAlign.end,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // Taksit Satırları
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: schedule.length,
                  itemBuilder: (c, idx) {
                    final item = schedule[idx];
                    final isEven = idx % 2 == 0;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      decoration: BoxDecoration(
                        color: isEven
                            ? (isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC))
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 45,
                            child: Text(
                              '${item.installmentNumber}. Gün',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${currencyFmt.format(item.principalAmount)} ₺',
                              maxLines: 1,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155)),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${currencyFmt.format(item.interestAmount)} ₺',
                              maxLines: 1,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.orangeAccent : const Color(0xFFEA580C)),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${currencyFmt.format(item.totalAmount)} ₺',
                              maxLines: 1,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${currencyFmt.format(item.remainingBalanceAfter)} ₺',
                              maxLines: 1,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          _buildCustomButton(
            onPressed: () => Navigator.pop(ctx),
            label: 'Anladım / Kapat',
            gradientColors: [
              isDark ? const Color(0xFF2E3E60) : const Color(0xFF334155),
              isDark ? const Color(0xFF1E283E) : const Color(0xFF1E293B),
            ],
            verticalPadding: 7,
            fontSize: 11,
          ),
        ],
      ),
    );
  }

  Widget _planHeaderItem(String title, String val, bool isDark, {bool isWarn = false}) {
    return Column(
      children: [
        Text(title,
            style: TextStyle(fontSize: 10, color: isDark ? Colors.grey : const Color(0xFF64748B))),
        Text(
          val,
          maxLines: 1,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isWarn ? Colors.orangeAccent : (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // ÖZEL TEK SATIR GRADIENT BUTON BİLEŞENİ
  // (ASLA 2 SATIRA BÖLÜNMEZ, MODERN VE GÖSTERİŞLİ)
  // ==========================================
  Widget _buildCustomButton({
    required VoidCallback? onPressed,
    required String label,
    IconData? icon,
    required List<Color> gradientColors,
    Color shadowColor = Colors.black26,
    bool isOutlined = false,
    double verticalPadding = 10,
    double fontSize = 12,
  }) {
    final isEnabled = onPressed != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: isEnabled && !isOutlined
                ? LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isOutlined
                ? Colors.transparent
                : (!isEnabled ? Colors.grey.withOpacity(0.18) : null),
            border: isOutlined
                ? Border.all(
                    color: isEnabled ? gradientColors.first : Colors.grey.withOpacity(0.3),
                    width: 1.5,
                  )
                : null,
            boxShadow: isEnabled && !isOutlined
                ? [
                    BoxShadow(
                      color: shadowColor.withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: fontSize + 3,
                    color: isOutlined
                        ? (isEnabled ? gradientColors.first : Colors.grey)
                        : (isEnabled ? Colors.white : Colors.grey[400]),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: isOutlined
                        ? (isEnabled ? gradientColors.first : Colors.grey)
                        : (isEnabled ? Colors.white : Colors.grey[400]),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
