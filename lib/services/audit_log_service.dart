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

  static const String _storageKey = 'piyasa_audit_logs_v1';
  static const int maxStoredLogs = 500;

  final List<AuditLog> _logs = [];
  bool _initialized = false;

  List<AuditLog> get logs => List.unmodifiable(_logs);

  @visibleForTesting
  void resetForTesting() {
    _logs.clear();
    _initialized = false;
  }

  /// Yerel logları hafızaya yükler
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        _logs.clear();
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
    } catch (e) {
      debugPrint('AuditLogService: Log yükleme hatası: $e');
      _initialized = true;
    }
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
    unawaited(_saveToPrefs());

    // 2. Firebase Cloud Firestore'a senkronize et
    unawaited(fb.writeAuditLog(entry));

    return entry;
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listToSave = _logs.take(maxStoredLogs).map((l) => l.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(listToSave));
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
}
