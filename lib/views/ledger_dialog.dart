import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/audit_log.dart';
import '../services/audit_log_service.dart';
import '../services/firebase_service.dart';

class LedgerDialog extends StatefulWidget {
  const LedgerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const LedgerDialog(),
    );
  }

  @override
  State<LedgerDialog> createState() => _LedgerDialogState();
}

class _LedgerDialogState extends State<LedgerDialog> {
  LogCategory? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  final currencyFmt = NumberFormat("#,##0", "tr_TR");
  final currencyPrecise = NumberFormat("#,##0.00", "tr_TR");
  final dateFormat = DateFormat('dd.MM.yyyy HH:mm:ss');

  @override
  void initState() {
    super.initState();
    AuditLogService().addListener(_onLogsUpdated);
  }

  @override
  void dispose() {
    AuditLogService().removeListener(_onLogsUpdated);
    _searchController.dispose();
    super.dispose();
  }

  void _onLogsUpdated() {
    if (mounted) setState(() {});
  }

  IconData _getCategoryIcon(LogCategory cat) {
    switch (cat) {
      case LogCategory.trade:
        return Icons.candlestick_chart;
      case LogCategory.facility:
        return Icons.factory;
      case LogCategory.retail:
        return Icons.storefront;
      case LogCategory.finance:
        return Icons.account_balance;
      case LogCategory.auth:
        return Icons.badge;
      case LogCategory.system:
        return Icons.settings_suggest;
    }
  }

  Color _getCategoryColor(LogCategory cat, bool isDark) {
    switch (cat) {
      case LogCategory.trade:
        return Colors.blueAccent;
      case LogCategory.facility:
        return Colors.amber[700]!;
      case LogCategory.retail:
        return const Color(0xFF0D9488);
      case LogCategory.finance:
        return Colors.deepPurpleAccent;
      case LogCategory.auth:
        return Colors.orangeAccent;
      case LogCategory.system:
        return isDark ? Colors.white60 : Colors.blueGrey;
    }
  }

  void _showLogDetail(AuditLog log, bool isDark) {
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
        child: SafeArea(
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
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getCategoryColor(log.category, isDark).withOpacity(0.2),
                    child: Icon(_getCategoryIcon(log.category), color: _getCategoryColor(log.category, isDark)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          dateFormat.format(log.timestamp),
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  if (log.amountChange != null)
                    Text(
                      '${log.amountChange! > 0 ? '+' : ''}${currencyPrecise.format(log.amountChange)} ₺',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: log.amountChange! > 0 ? const Color(0xFF10B981) : Colors.redAccent,
                      ),
                    ),
                ],
              ),
              const Divider(height: 24),
              Text(
                'Açıklama:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
              const SizedBox(height: 4),
              Text(
                log.description,
                style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('İşlem Sonrası Kasa:', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                  Text(
                    '${currencyPrecise.format(log.cashAfter)} ₺',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Oyuncu / UID:', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                  Text(
                    '${log.username} (${log.playerId})',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ],
              ),
              if (log.details.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Ayrıntılı İşlem Verileri:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: log.details.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${e.key}:', style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : const Color(0xFF64748B))),
                            Text('${e.value}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                child: const Text('Kapat'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final service = AuditLogService();
    final filteredLogs = service.getLogsFiltered(
      category: _selectedCategory,
      query: _searchController.text,
    );
    final totalIncome = service.totalIncome;
    final totalExpense = service.totalExpense;
    final netFlow = service.netFlow;
    final fb = FirebaseService();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. BAŞLIK & BULUT ROZETİ
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('📜', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Şirket Defteri & İşlem Logları',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              fb.isCloudConnected ? 'Cloud Firestore Senkronize ☁️' : 'Yerel Kayıt Modu 💾',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: fb.isCloudConnected ? const Color(0xFF10B981) : Colors.amber[700],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('• Toplam: ${service.logs.length} işlem',
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. FİNANSAL ÖZET KARTLARI
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Toplam Gelir', style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white60 : const Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(
                            '+${currencyFmt.format(totalIncome)} ₺',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 24, width: 1, color: isDark ? Colors.white24 : Colors.black12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Toplam Gider', style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white60 : const Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Text(
                              '-${currencyFmt.format(totalExpense)} ₺',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.redAccent),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(height: 24, width: 1, color: isDark ? Colors.white24 : Colors.black12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Net Akış', style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white60 : const Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Text(
                              '${netFlow >= 0 ? '+' : ''}${currencyFmt.format(netFlow)} ₺',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: netFlow >= 0 ? Colors.amberAccent : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. ARAMA VE KATEGORİ FİLTRELERİ
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Ürün, işlem veya açıklama ara...',
                  hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Kategori Butonları (Kaydırılabilir)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Tümü', null, isDark),
                    _buildFilterChip('🛒 Borsa & Pazar', LogCategory.trade, isDark),
                    _buildFilterChip('🏗️ Tesisler', LogCategory.facility, isDark),
                    _buildFilterChip('🏪 Dükkanlar', LogCategory.retail, isDark),
                    _buildFilterChip('🏦 Finans & Banka', LogCategory.finance, isDark),
                    _buildFilterChip('👤 Oturum', LogCategory.auth, isDark),
                    _buildFilterChip('⚙️ Sistem', LogCategory.system, isDark),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 4. İŞLEM LİSTESİ
              Expanded(
                child: filteredLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_toggle_off, size: 48, color: isDark ? Colors.white24 : Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Henüz kayıtlı bir işlem bulunamadı.',
                              style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredLogs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final log = filteredLogs[index];
                          final isIncome = log.amountChange != null && log.amountChange! > 0;
                          final isExpense = log.amountChange != null && log.amountChange! < 0;
                          final color = _getCategoryColor(log.category, isDark);

                          return InkWell(
                            onTap: () => _showLogDetail(log, isDark),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: color.withOpacity(0.18),
                                    child: Icon(_getCategoryIcon(log.category), size: 16, color: color),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                log.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            Text(
                                              dateFormat.format(log.timestamp),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          log.description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (log.amountChange != null)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${isIncome ? '+' : ''}${currencyFmt.format(log.amountChange)} ₺',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isIncome
                                              ? const Color(0xFF10B981)
                                              : (isExpense ? Colors.redAccent : Colors.grey),
                                          ),
                                        ),
                                        Text(
                                          'Kasa: ${currencyFmt.format(log.cashAfter)} ₺',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
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
  }

  Widget _buildFilterChip(String label, LogCategory? category, bool isDark) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white70 : const Color(0xFF475569)),
        ),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedCategory = category;
          });
        },
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        selectedColor: isDark ? const Color(0xFF0F766E) : const Color(0xFF0D9488),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
