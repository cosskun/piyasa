import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audit_log.dart';
import 'firebase_service.dart';

class AuditLogService extends ChangeNotifier {
  static final AuditLogService _instance = AuditLogService._internal();
  factory AuditLogService() => _instance;
  AuditLogService._internal();

  static const String _baseStorageKey = 'piyasa_audit_logs_v2';
  static const int maxStoredLogs = 500;

  final List<AuditLog> _logs = [];
  bool _initialized = false;
  String? _currentPlayerId;

  List<AuditLog> get logs => List.unmodifiable(_logs);

  String _getStorageKey([String? playerId]) {
    final effectiveId = (playerId != null && playerId.isNotEmpty)
        ? playerId
        : (FirebaseService().playerId.isNotEmpty ? FirebaseService().playerId : 'guest');
    return '${_baseStorageKey}_$effectiveId';
  }

  @visibleForTesting
  void resetForTesting() {
    _logs.clear();
    _initialized = false;
    _currentPlayerId = null;
  }

  /// Aktif oturumdaki logları hafızadan temizler (Çıkış yapıldığında çağrılır)
  void clearInProcess() {
    _logs.clear();
    _initialized = false;
    _currentPlayerId = null;
    notifyListeners();
  }

  /// Belirli bir oyuncuya ait yerel logları hafızaya yükler
  Future<void> initializeForPlayer(String? playerId) async {
    final effectiveId = (playerId != null && playerId.isNotEmpty)
        ? playerId
        : (FirebaseService().playerId.isNotEmpty ? FirebaseService().playerId : 'guest');

    _logs.clear();
    _currentPlayerId = effectiveId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(effectiveId);
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _logs.add(AuditLog.fromJson(item));
          } else if (item is Map) {
            _logs.add(AuditLog.fromJson(Map<String, dynamic>.from(item)));
          }
        }
        // En yeni log en başta
        _logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('AuditLogService: Log yükleme hatası: $e');
      _initialized = true;
    }
  }

  /// Genel başlatma (mevcut oturumdaki oyuncu için)
  Future<void> initialize() async {
    if (_initialized && _currentPlayerId == FirebaseService().playerId) return;
    await initializeForPlayer(FirebaseService().playerId);
  }

  /// Yeni bir denetim ve işlem logu kaydeder
  Future<AuditLog> log({
    required LogCategory category,
    required String action,
    required String title,
    required String description,
    double? amountChange,
    required double cashAfter,
    Map<String, dynamic> details = const {},
    DateTime? customTimestamp,
  }) async {
    final fb = FirebaseService();
    final logId = 'log_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final currentUsername = fb.username ?? (fb.isGuest ? 'Misafir' : 'Oyuncu');
    final currentPlayerId = fb.playerId;

    final entry = AuditLog(
      id: logId,
      timestamp: customTimestamp ?? DateTime.now(),
      playerId: currentPlayerId,
      username: currentUsername,
      category: category,
      action: action,
      title: title,
      description: description,
      amountChange: amountChange,
      cashAfter: cashAfter,
      details: details,
    );

    _logs.insert(0, entry);
    if (_logs.length > maxStoredLogs) {
      _logs.removeRange(maxStoredLogs, _logs.length);
    }

    notifyListeners();

    // 1. Yerel depolamaya kaydet
    unawaited(_saveToPrefs(currentPlayerId));

    // 2. Firebase Cloud Firestore'a senkronize et
    unawaited(fb.writeAuditLog(entry));

    return entry;
  }

  Future<void> _saveToPrefs(String playerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listToSave = _logs.take(maxStoredLogs).map((l) => l.toJson()).toList();
      final key = _getStorageKey(playerId);
      await prefs.setString(key, jsonEncode(listToSave));
    } catch (e) {
      debugPrint('AuditLogService: Yerel log kaydetme hatası: $e');
    }
  }

  /// Filtrelenmiş logları getirir
  List<AuditLog> getLogsFiltered({LogCategory? category, String? query}) {
    return _logs.where((log) {
      if (category != null && log.category != category) {
        return false;
      }
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchesTitle = log.title.toLowerCase().contains(q);
        final matchesDesc = log.description.toLowerCase().contains(q);
        final matchesAction = log.action.toLowerCase().contains(q);
        if (!matchesTitle && !matchesDesc && !matchesAction) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// Toplam gelir (pozitif para girişleri)
  double get totalIncome {
    return _logs.fold(0.0, (sum, log) {
      if (log.amountChange != null && log.amountChange! > 0) {
        return sum + log.amountChange!;
      }
      return sum;
    });
  }

  /// Toplam gider (negatif para çıkışları - mutlak değer)
  double get totalExpense {
    return _logs.fold(0.0, (sum, log) {
      if (log.amountChange != null && log.amountChange! < 0) {
        return sum + log.amountChange!.abs();
      }
      return sum;
    });
  }

  /// Net finansal akış (Gelir - Gider)
  double get netFlow => totalIncome - totalExpense;

  /// Belirli bir zamandan sonraki toplam pozitif gelir (nakit kazancı)
  double getIncomeSince(DateTime since) {
    return _logs.where((l) => l.timestamp.isAfter(since)).fold(0.0, (sum, log) {
      if (log.amountChange != null && log.amountChange! > 0) {
        return sum + log.amountChange!;
      }
      return sum;
    });
  }

  /// Belirli bir zamandan sonraki net finansal akış / kâr
  double getNetProfitSince(DateTime since) {
    return _logs.where((l) => l.timestamp.isAfter(since)).fold(0.0, (sum, log) {
      if (log.amountChange != null) {
        return sum + log.amountChange!;
      }
      return sum;
    });
  }

  /// Belirli bir oyuncuya ait kaydedilmiş yerel logları getirir
  Future<List<AuditLog>> getLogsForPlayer(String playerId) async {
    if (playerId == _currentPlayerId && _logs.isNotEmpty) {
      return List.unmodifiable(_logs);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(playerId);
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        final list = <AuditLog>[];
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            list.add(AuditLog.fromJson(item));
          } else if (item is Map) {
            list.add(AuditLog.fromJson(Map<String, dynamic>.from(item)));
          }
        }
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return list;
      }
    } catch (e) {
      debugPrint('AuditLogService: getLogsForPlayer error: $e');
    }
    return [];
  }

  /// Cihazdaki tüm yerel hesaplara ait işlem loglarını birleştirip getirir
  Future<List<AuditLog>> getAllLocalLogs() async {
    final Map<String, AuditLog> combined = {};
    for (var l in _logs) {
      combined[l.id] = l;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_baseStorageKey));
      for (final k in keys) {
        final raw = prefs.getString(k);
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw) as List;
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final log = AuditLog.fromJson(item);
              combined[log.id] = log;
            } else if (item is Map) {
              final log = AuditLog.fromJson(Map<String, dynamic>.from(item));
              combined[log.id] = log;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('AuditLogService: getAllLocalLogs error: $e');
    }
    final sorted = combined.values.toList();
    sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted;
  }
}
