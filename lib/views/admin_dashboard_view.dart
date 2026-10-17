import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../models/audit_log.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'tr_TR');
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber, width: 1.2),
              ),
              child: const Icon(Icons.security_rounded, color: Colors.amber, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YÖNETİCİ & GÜVENLİK PANELİ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'COSSKUN (furkanc28@gmail.com)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber.shade200,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.grey.shade400,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Oyuncular'),
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Global Defter'),
            Tab(icon: Icon(Icons.radar_rounded, size: 18), text: 'Hile Radarı'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PlayersTabView(
            onOpenLedger: _openPlayerLedgerSheet,
            onPromptBan: _promptBanPlayer,
            onPromptUnban: _confirmUnbanPlayer,
            onPromptDelete: _confirmDeletePlayer,
            onCleanupUnknown: _runCleanupUnknownPlayers,
          ),
          const _GlobalLogsTabView(),
          _AntiCheatTabView(
            onOpenLedger: _openPlayerLedgerSheet,
            onPromptBan: _promptBanPlayer,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // OYUNCU DEFTERİ DETAY BOTTOM SHEET
  // ==========================================
  void _openPlayerLedgerSheet(String targetUid, String username) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _PlayerLedgerBottomSheet(
        targetUid: targetUid,
        username: username,
        currencyFormat: _currencyFormat,
        dateFormat: _dateFormat,
      ),
    );
  }

  // ==========================================
  // BANLAMA & BAN KALDIRMA DİYALOGLARI
  // ==========================================
  void _promptBanPlayer(String targetUid, String username) {
    final reasonController = TextEditingController(text: 'Şüpheli pazar işlemi ve hile tespiti');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.gavel_rounded, color: Colors.redAccent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$username Banlansın mı?',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bu işlem oyuncunun hesabını anında askıya alacak, telefon ekranına kapatılamaz ban uyarısı çıkaracak ve pazardaki tüm açık ilanlarını iptal edecektir.',
                style: TextStyle(color: Colors.grey.shade300, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              const Text(
                'Ban Sebebi (Oyuncunun ekranında görünecektir):',
                style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: reasonController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final err = await FirebaseService().banPlayer(
                  targetUid: targetUid,
                  reason: reasonController.text,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(err ?? '$username başarıyla banlandı ve erişimi kesildi!'),
                      backgroundColor: err != null ? Colors.red : Colors.green.shade700,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.shade700),
              child: const Text('Evet, Hesabı Banla', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _confirmUnbanPlayer(String targetUid, String username) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            '$username Banı Kaldırılsın mı?',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Oyuncunun hesabı tekrar aktif hale getirilecek ve oyuna giriş yapmasına izin verilecektir.',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final err = await FirebaseService().unbanPlayer(targetUid: targetUid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(err ?? '$username oyuncusunun banı kaldırıldı!'),
                      backgroundColor: err != null ? Colors.red : Colors.green.shade700,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
              child: const Text('Banı Kaldır', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeletePlayer(String targetUid, String username) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$username Silinsin mi?',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'Bu işlem $username adlı oyuncuyu ve pazardaki tüm açık ilanlarını veritabanından kalıcı olarak silecektir. Bu işlem geri alınamaz!',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final err = await FirebaseService().deletePlayer(targetUid: targetUid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(err ?? '$username başarıyla veritabanından silindi!'),
                      backgroundColor: err != null ? Colors.red : Colors.green.shade700,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.shade700),
              child: const Text('Evet, Kalıcı Olarak Sil', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _runCleanupUnknownPlayers() async {
    final deleted = await FirebaseService().cleanupUnknownPlayers();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(deleted > 0
              ? '$deleted adet geçersiz/bilinmeyen kayıt veritabanından başarıyla temizlendi!'
              : 'Veritabanında silinecek bilinmeyen kayıt bulunamadı.'),
          backgroundColor: Colors.blueAccent.shade700,
        ),
      );
    }
  }
}

class _PlayerLedgerBottomSheet extends StatefulWidget {
  final String targetUid;
  final String username;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat;

  const _PlayerLedgerBottomSheet({
    required this.targetUid,
    required this.username,
    required this.currencyFormat,
    required this.dateFormat,
  });

  @override
  State<_PlayerLedgerBottomSheet> createState() => _PlayerLedgerBottomSheetState();
}

class _PlayerLedgerBottomSheetState extends State<_PlayerLedgerBottomSheet> {
  late final Stream<List<AuditLog>> _playerLogsStream;

  @override
  void initState() {
    super.initState();
    // Stream initState'te bir kez memoize edilerek sonsuz döngü ve titreme engellenir
    _playerLogsStream = FirebaseService().streamPlayerAuditLogs(widget.targetUid);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Tutamaç
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: Colors.amber, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.username} • Şirket Defteri',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'UID: ${widget.targetUid}',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12),
            Expanded(
              child: StreamBuilder<List<AuditLog>>(
                stream: _playerLogsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.amber));
                  }

                  final logs = snapshot.data ?? [];
                  if (logs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade600),
                          const SizedBox(height: 10),
                          Text(
                            'Bu oyuncuya ait işlem kaydı bulunamadı.',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return _buildLogCard(log);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogCard(AuditLog log) {
    final amt = log.amountChange ?? 0.0;
    final isIncome = amt > 0;
    final isExpense = amt < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: log.category.color.withValues(alpha: 0.15),
          radius: 18,
          child: Icon(log.category.icon, color: log.category.color, size: 18),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${log.username} • ${log.title}',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (amt != 0)
              Text(
                '${isIncome ? '+' : ''}${widget.currencyFormat.format(amt)} TL',
                style: TextStyle(
                  color: isIncome ? Colors.greenAccent : (isExpense ? Colors.redAccent : Colors.grey),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              log.description,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.dateFormat.format(log.timestamp),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
                Text(
                  'Kasa: ${widget.currencyFormat.format(log.cashAfter)} TL',
                  style: TextStyle(color: Colors.amber.shade200, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TAB 1: OYUNCULAR (PLAYERS TAB VIEW)
// ==========================================
enum _PlayerFilterTab { all, online, offline, banned }

class _PlayersTabView extends StatefulWidget {
  final void Function(String uid, String username) onOpenLedger;
  final void Function(String uid, String username) onPromptBan;
  final void Function(String uid, String username) onPromptUnban;
  final void Function(String uid, String username)? onPromptDelete;
  final VoidCallback? onCleanupUnknown;

  const _PlayersTabView({
    required this.onOpenLedger,
    required this.onPromptBan,
    required this.onPromptUnban,
    this.onPromptDelete,
    this.onCleanupUnknown,
  });

  @override
  State<_PlayersTabView> createState() => _PlayersTabViewState();
}

class _PlayersTabViewState extends State<_PlayersTabView> with AutomaticKeepAliveClientMixin {
  late Stream<List<Map<String, dynamic>>> _playersStream;
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'tr_TR');
  String _searchQuery = '';
  _PlayerFilterTab _activeFilterTab = _PlayerFilterTab.all;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _playersStream = FirebaseService().streamAllPlayers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _playersStream = FirebaseService().streamAllPlayers();
    });
  }

  bool _isPlayerOnline(Map<String, dynamic> player) {
    final bool rawIsOnline = player['isOnline'] == true;
    if (!rawIsOnline) return false;

    DateTime? lastActive;
    final dynamic rawVal = player['lastActiveAt'];
    if (rawVal != null) {
      if (rawVal is String) {
        lastActive = DateTime.tryParse(rawVal);
      } else if (rawVal is int) {
        lastActive = DateTime.fromMillisecondsSinceEpoch(rawVal);
      } else {
        try {
          lastActive = (rawVal as dynamic).toDate();
        } catch (_) {}
      }
    }

    if (lastActive == null) return true;
    return DateTime.now().difference(lastActive).inMinutes <= 3;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _playersStream,
      builder: (context, snapshot) {
        final players = snapshot.data ?? [];

        // Sayımları hesapla
        int onlineCount = 0;
        int offlineCount = 0;
        int bannedCount = 0;
        for (final p in players) {
          if (p['isBanned'] == true) {
            bannedCount++;
          } else if (_isPlayerOnline(p)) {
            onlineCount++;
          } else {
            offlineCount++;
          }
        }

        // Tab filtresine göre filtrele
        final tabFiltered = players.where((p) {
          final isBanned = p['isBanned'] == true;
          final isOnline = _isPlayerOnline(p);
          switch (_activeFilterTab) {
            case _PlayerFilterTab.all:
              return true;
            case _PlayerFilterTab.online:
              return isOnline && !isBanned;
            case _PlayerFilterTab.offline:
              return !isOnline && !isBanned;
            case _PlayerFilterTab.banned:
              return isBanned;
          }
        }).toList();

        // Arama sorgusuna göre filtrele
        final filtered = tabFiltered.where((p) {
          if (_searchQuery.isEmpty) return true;
          final uname = (p['username'] ?? '').toString().toLowerCase();
          final email = (p['email'] ?? '').toString().toLowerCase();
          final company = (p['companyName'] ?? '').toString().toLowerCase();
          final uid = (p['uid'] ?? '').toString().toLowerCase();
          return uname.contains(_searchQuery) ||
              email.contains(_searchQuery) ||
              company.contains(_searchQuery) ||
              uid.contains(_searchQuery);
        }).toList();

        return Column(
          children: [
            // Arama Kutusu
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              color: const Color(0xFF1E293B).withValues(alpha: 0.6),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Oyuncu adı, e-posta, şirket veya UID ara...',
                  hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.amber, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
              ),
            ),

            // Tablı Filtre Çubuğu (Tümü, Çevrimiçi, Çevrimdışı, Yasaklı)
            _buildFilterTabs(
              allCount: players.length,
              onlineCount: onlineCount,
              offlineCount: offlineCount,
              bannedCount: bannedCount,
            ),

            // Oyuncu Listesi Stream
            Expanded(
              child: RefreshIndicator(
                color: Colors.amber,
                backgroundColor: const Color(0xFF1E293B),
                onRefresh: _refresh,
                child: snapshot.connectionState == ConnectionState.waiting && players.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                    : (filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                              Center(
                                child: _buildEmptyState(),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(12),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final player = filtered[index];
                              return _buildPlayerCard(player);
                            },
                          )),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterTabs({
    required int allCount,
    required int onlineCount,
    required int offlineCount,
    required int bannedCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildFilterTabItem(
              tab: _PlayerFilterTab.all,
              title: 'Tümü',
              count: allCount,
              icon: Icons.people_alt_rounded,
              activeColor: Colors.amber,
            ),
            const SizedBox(width: 6),
            _buildFilterTabItem(
              tab: _PlayerFilterTab.online,
              title: 'Çevrimiçi',
              count: onlineCount,
              icon: Icons.fiber_manual_record_rounded,
              activeColor: const Color(0xFF10B981),
            ),
            const SizedBox(width: 6),
            _buildFilterTabItem(
              tab: _PlayerFilterTab.offline,
              title: 'Çevrimdışı',
              count: offlineCount,
              icon: Icons.cloud_off_rounded,
              activeColor: Colors.grey.shade400,
            ),
            const SizedBox(width: 6),
            _buildFilterTabItem(
              tab: _PlayerFilterTab.banned,
              title: 'Yasaklı',
              count: bannedCount,
              icon: Icons.block_rounded,
              activeColor: Colors.redAccent,
            ),
            if (widget.onCleanupUnknown != null) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: widget.onCleanupUnknown,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_delete_rounded, size: 13, color: Colors.redAccent),
                      SizedBox(width: 4),
                      Text(
                        'Bilinmeyenleri Temizle',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabItem({
    required _PlayerFilterTab tab,
    required String title,
    required int count,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _activeFilterTab == tab;
    return InkWell(
      onTap: () {
        setState(() {
          _activeFilterTab = tab;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.16)
              : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? activeColor : Colors.grey.shade400,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : Colors.grey.shade400,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? activeColor : Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    IconData icon;
    String message;
    Color iconColor;

    if (_searchQuery.isNotEmpty) {
      icon = Icons.search_off_rounded;
      message = 'Aramanıza uygun oyuncu bulunamadı.';
      iconColor = Colors.grey.shade500;
    } else {
      switch (_activeFilterTab) {
        case _PlayerFilterTab.online:
          icon = Icons.wifi_off_rounded;
          message = 'Şu an aktif çevrimiçi oyuncu bulunmuyor.';
          iconColor = Colors.teal.shade300;
          break;
        case _PlayerFilterTab.offline:
          icon = Icons.cloud_off_rounded;
          message = 'Çevrimdışı oyuncu bulunmuyor.';
          iconColor = Colors.grey.shade400;
          break;
        case _PlayerFilterTab.banned:
          icon = Icons.verified_user_rounded;
          message = 'Harika! Sistemde yasaklı (banlı) oyuncu bulunmuyor.';
          iconColor = const Color(0xFF10B981);
          break;
        case _PlayerFilterTab.all:
          icon = Icons.person_off_rounded;
          message = 'Sistemde kayıtlı oyuncu bulunamadı.';
          iconColor = Colors.grey.shade500;
          break;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: iconColor),
        const SizedBox(height: 12),
        Text(
          message,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPlayerCard(Map<String, dynamic> player) {
    final uid = player['uid']?.toString() ?? '';
    final username = player['username']?.toString() ?? 'Bilinmeyen Oyuncu';
    final email = player['email']?.toString() ?? 'E-posta yok';
    final companyName = player['companyName']?.toString() ?? '$username Holding';
    final cash = (player['cash'] is num) ? (player['cash'] as num).toDouble() : 0.0;
    final netWorth = (player['netWorth'] is num) ? (player['netWorth'] as num).toDouble() : cash;
    final level = (player['level'] is num) ? (player['level'] as num).toInt() : 1;
    final isBanned = player['isBanned'] == true;
    final banReason = player['banReason']?.toString() ?? '';
    final role = player['role']?.toString() ?? 'user';
    final isTargetAdmin = role == 'admin' || email.toLowerCase() == FirebaseService.adminEmail.toLowerCase();

    final bool isReallyOnline = _isPlayerOnline(player);
    DateTime? lastActive;
    final dynamic rawVal = player['lastActiveAt'];
    if (rawVal != null) {
      if (rawVal is String) {
        lastActive = DateTime.tryParse(rawVal);
      } else if (rawVal is int) {
        lastActive = DateTime.fromMillisecondsSinceEpoch(rawVal);
      } else {
        try {
          lastActive = (rawVal as dynamic).toDate();
        } catch (_) {}
      }
    }

    String lastSeenText = '';
    if (lastActive != null && !isReallyOnline) {
      final diff = DateTime.now().difference(lastActive);
      if (diff.inMinutes < 1) {
        lastSeenText = 'Az önce';
      } else if (diff.inMinutes < 60) {
        lastSeenText = '${diff.inMinutes} dk önce';
      } else if (diff.inHours < 24) {
        lastSeenText = '${diff.inHours} sa önce';
      } else {
        lastSeenText = '${diff.inDays} gün önce';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBanned
              ? Colors.redAccent.withValues(alpha: 0.6)
              : (isTargetAdmin ? Colors.amber.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08)),
          width: isBanned || isTargetAdmin ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isBanned
                    ? Colors.redAccent.withValues(alpha: 0.2)
                    : (isTargetAdmin ? Colors.amber.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.2)),
                child: Icon(
                  isBanned
                      ? Icons.block_rounded
                      : (isTargetAdmin ? Icons.verified_user_rounded : Icons.person_rounded),
                  color: isBanned ? Colors.redAccent : (isTargetAdmin ? Colors.amber : Colors.blueAccent),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            username,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isTargetAdmin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'YÖNETİCİ',
                              style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$companyName • $email',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isBanned
                          ? Colors.redAccent.withValues(alpha: 0.2)
                          : (isReallyOnline
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isBanned
                            ? Colors.redAccent
                            : (isReallyOnline ? Colors.green : Colors.grey.shade600),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isBanned
                                ? Colors.redAccent
                                : (isReallyOnline ? Colors.greenAccent : Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isBanned
                              ? 'BANLANDI'
                              : (isReallyOnline ? 'ÇEVRİMİÇİ' : 'ÇEVRİMDIŞI'),
                          style: TextStyle(
                            color: isBanned
                                ? Colors.redAccent
                                : (isReallyOnline ? Colors.greenAccent : Colors.grey.shade400),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (lastSeenText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      lastSeenText,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ],
          ),

          if (isBanned && banReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.redAccent, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ban Nedeni: $banReason',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Divider(color: Colors.white12, height: 20),

          // Finansal Bilgiler
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCol('Kasa', '${_currencyFormat.format(cash)} TL', Colors.greenAccent),
              _buildStatCol('Net Servet', '${_currencyFormat.format(netWorth)} TL', Colors.amberAccent),
              _buildStatCol('Seviye', 'Lvl $level', Colors.blueAccent),
            ],
          ),

          const SizedBox(height: 12),

          // Aksiyon Butonları
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => widget.onOpenLedger(uid, username),
                  icon: const Icon(Icons.menu_book_rounded, size: 16),
                  label: const Text('Defteri İncele', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              if (!isTargetAdmin) ...[
                isBanned
                    ? ElevatedButton.icon(
                        onPressed: () => widget.onPromptUnban(uid, username),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                        label: const Text('Banı Aç', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => widget.onPromptBan(uid, username),
                        icon: const Icon(Icons.gavel_rounded, size: 16),
                        label: const Text('Banla', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                if (widget.onPromptDelete != null) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => widget.onPromptDelete!(uid, username),
                    icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                    tooltip: 'Oyuncuyu Sil',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ==========================================
// TAB 2: GLOBAL İŞLEM AKIŞI (GLOBAL AUDIT LOGS)
// ==========================================
class _GlobalLogsTabView extends StatefulWidget {
  const _GlobalLogsTabView();

  @override
  State<_GlobalLogsTabView> createState() => _GlobalLogsTabViewState();
}

class _GlobalLogsTabViewState extends State<_GlobalLogsTabView> with AutomaticKeepAliveClientMixin {
  late Stream<List<AuditLog>> _logsStream;
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'tr_TR');
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy HH:mm:ss');
  LogCategory? _selectedLogCategory;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _logsStream = FirebaseService().streamGlobalAuditLogs(limit: 150);
  }

  Future<void> _refresh() async {
    setState(() {
      _logsStream = FirebaseService().streamGlobalAuditLogs(limit: 150);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        // Kategori Filtreleri
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Tüm İşlemler'),
                selected: _selectedLogCategory == null,
                selectedColor: Colors.amber,
                checkmarkColor: Colors.black,
                labelStyle: TextStyle(
                  color: _selectedLogCategory == null ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                backgroundColor: const Color(0xFF1E293B),
                onSelected: (val) => setState(() => _selectedLogCategory = null),
              ),
              const SizedBox(width: 8),
              ...LogCategory.values.map((cat) {
                final isSelected = _selectedLogCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat.label),
                    selected: isSelected,
                    selectedColor: cat.color,
                    checkmarkColor: Colors.black,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    backgroundColor: const Color(0xFF1E293B),
                    onSelected: (val) => setState(() => _selectedLogCategory = val ? cat : null),
                  ),
                );
              }),
            ],
          ),
        ),

        // Log Akışı
        Expanded(
          child: RefreshIndicator(
            color: Colors.amber,
            backgroundColor: const Color(0xFF1E293B),
            onRefresh: _refresh,
            child: StreamBuilder<List<AuditLog>>(
              stream: _logsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amber));
                }

                final logs = snapshot.data ?? [];
                final filtered = logs.where((l) {
                  if (_selectedLogCategory != null && l.category != _selectedLogCategory) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                      Center(
                        child: Text(
                          'Henüz kayıtlı bir işlem logu bulunmuyor.',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final log = filtered[index];
                    return _buildLogItemCard(log);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogItemCard(AuditLog log) {
    final amt = log.amountChange ?? 0.0;
    final isIncome = amt > 0;
    final isExpense = amt < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: log.category.color.withValues(alpha: 0.15),
          radius: 18,
          child: Icon(log.category.icon, color: log.category.color, size: 18),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${log.username} • ${log.title}',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (amt != 0)
              Text(
                '${isIncome ? '+' : ''}${_currencyFormat.format(amt)} TL',
                style: TextStyle(
                  color: isIncome ? Colors.greenAccent : (isExpense ? Colors.redAccent : Colors.grey),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              log.description,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _dateFormat.format(log.timestamp),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
                Text(
                  'Kasa: ${_currencyFormat.format(log.cashAfter)} TL',
                  style: TextStyle(color: Colors.amber.shade200, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TAB 3: HİLE & ŞÜPHELİ İŞLEM RADARI (ANTI-CHEAT)
// ==========================================
class _AntiCheatTabView extends StatefulWidget {
  final void Function(String uid, String username) onOpenLedger;
  final void Function(String uid, String username) onPromptBan;

  const _AntiCheatTabView({
    required this.onOpenLedger,
    required this.onPromptBan,
  });

  @override
  State<_AntiCheatTabView> createState() => _AntiCheatTabViewState();
}

class _AntiCheatTabViewState extends State<_AntiCheatTabView> with AutomaticKeepAliveClientMixin {
  late Stream<List<AuditLog>> _radarStream;
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'tr_TR');
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy HH:mm:ss');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _radarStream = FirebaseService().streamGlobalAuditLogs(limit: 200);
  }

  Future<void> _refresh() async {
    setState(() {
      _radarStream = FirebaseService().streamGlobalAuditLogs(limit: 200);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      color: Colors.amber,
      backgroundColor: const Color(0xFF1E293B),
      onRefresh: _refresh,
      child: StreamBuilder<List<AuditLog>>(
        stream: _radarStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.amber));
          }

          final allLogs = snapshot.data ?? [];

          final suspiciousLogs = allLogs.where((l) {
            final amt = l.amountChange ?? 0.0;
            final isLargeSpike = amt.abs() >= 1000000;
            final isHugeCash = l.cashAfter >= 10000000;
            final isNegativeCash = l.cashAfter < 0;
            return isLargeSpike || isHugeCash || isNegativeCash;
          }).toList();

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            children: [
              // Radar Başlık Bannerı
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade900.withValues(alpha: 0.6), const Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.crisis_alert_rounded, color: Colors.redAccent, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OTOMATİK HİLE & ANOMALİ RADARI',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Anormal para sıçramaları (≥ 1.000.000 TL) ve şüpheli kasa artışları anlık denetlenir.',
                            style: TextStyle(color: Colors.grey.shade300, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (suspiciousLogs.isEmpty) ...[
                SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, size: 64, color: Colors.green.withValues(alpha: 0.7)),
                      const SizedBox(height: 12),
                      const Text(
                        'Şu anda şüpheli bir işlem tespit edilmedi.',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tüm oyuncu defterleri ve pazar hareketleri normal aralıkta.',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ] else
                ...suspiciousLogs.map((log) => _buildSuspiciousCard(log)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSuspiciousCard(AuditLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4), width: 1.2),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'ŞÜPHELİ ANOMALİ',
                      style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                _dateFormat.format(log.timestamp),
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Oyuncu: ${log.username} (UID: ${log.playerId})',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'İşlem: ${log.title} - ${log.description}',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Tutar: ${_currencyFormat.format(log.amountChange)} TL',
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(width: 12),
              Text(
                'Kasa Sonrası: ${_currencyFormat.format(log.cashAfter)} TL',
                style: TextStyle(color: Colors.amber.shade200, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => widget.onOpenLedger(log.playerId, log.username),
                icon: const Icon(Icons.history_rounded, size: 15),
                label: const Text('Tüm Defterini İncele', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(foregroundColor: Colors.amberAccent),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => widget.onPromptBan(log.playerId, log.username),
                icon: const Icon(Icons.gavel_rounded, size: 15),
                label: const Text('Bu Oyuncuyu Banla', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
