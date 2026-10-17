import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/game_controller.dart';
import 'firebase_service.dart';

class SaveService {
  static final SaveService _instance = SaveService._internal();
  factory SaveService() => _instance;
  SaveService._internal();

  static const String _baseSaveKey = 'piyasa_save_state_v2';
  static const String _lastActiveSaveKey = 'piyasa_last_active_save_v2';
  static const String _lastActivePlayerIdKey = 'piyasa_last_active_player_id';

  bool _isSaving = false;
  bool _pendingSaveRequested = false;
  Map<String, dynamic>? _pendingData;
  String? _pendingPlayerId;
  final List<Completer<void>> _pendingWaiters = [];

  String getSaveKeyForPlayer([String? playerId]) {
    final effectiveId = (playerId != null && playerId.isNotEmpty)
        ? playerId
        : (FirebaseService().playerId.isNotEmpty ? FirebaseService().playerId : 'guest');
    return '${_baseSaveKey}_$effectiveId';
  }

  @visibleForTesting
  void resetForTesting() {
    _isSaving = false;
    _pendingSaveRequested = false;
    _pendingData = null;
    _pendingPlayerId = null;
    _pendingWaiters.clear();
  }

  /// Doğrudan Map/JSON verisini yerel depolamaya (SharedPreferences) kaydeder.
  Future<void> saveDirectData(Map<String, dynamic> data, {String? playerId}) async {
    final effectiveId = (playerId != null && playerId.isNotEmpty)
        ? playerId
        : (FirebaseService().playerId.isNotEmpty ? FirebaseService().playerId : 'guest');

    if (_isSaving) {
      _pendingSaveRequested = true;
      _pendingData = data;
      _pendingPlayerId = effectiveId;
      final completer = Completer<void>();
      _pendingWaiters.add(completer);
      return completer.future;
    }

    _isSaving = true;
    try {
      await _performSaveData(data, effectiveId);
    } finally {
      _isSaving = false;
      if (_pendingSaveRequested && _pendingData != null) {
        _pendingSaveRequested = false;
        final nextData = _pendingData!;
        final nextPlayerId = _pendingPlayerId;
        _pendingData = null;
        _pendingPlayerId = null;
        final waiters = List<Completer<void>>.from(_pendingWaiters);
        _pendingWaiters.clear();

        try {
          await saveDirectData(nextData, playerId: nextPlayerId);
          for (final c in waiters) {
            if (!c.isCompleted) c.complete();
          }
        } catch (e) {
          for (final c in waiters) {
            if (!c.isCompleted) c.completeError(e);
          }
        }
      } else {
        for (final c in _pendingWaiters) {
          if (!c.isCompleted) c.complete();
        }
        _pendingWaiters.clear();
      }
    }
  }

  /// Oyuncunun mevcut oyun durumunu oyuncuya özel anahtarla yerel depolamaya (SharedPreferences) kaydeder.
  Future<void> save(GameController controller, {String? playerId}) async {
    final data = controller.toSaveJson();
    return saveDirectData(data, playerId: playerId);
  }

  Future<void> _performSaveData(Map<String, dynamic> data, String effectivePlayerId) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 4));
      final jsonStr = jsonEncode(data);
      final key = getSaveKeyForPlayer(effectivePlayerId);
      await prefs.setString(key, jsonStr).timeout(const Duration(seconds: 4));
      // Genel cihaz yedeği ve son aktif oyuncu kimliği olarak da kaydet
      await prefs.setString(_lastActiveSaveKey, jsonStr).timeout(const Duration(seconds: 4));
      await prefs.setString(_lastActivePlayerIdKey, effectivePlayerId).timeout(const Duration(seconds: 4));
    } catch (e, stack) {
      debugPrint('SaveService save error: $e\n$stack');
    }
  }

  /// Yerel depolamadaki kayıtlı ham JSON verisini döndürür (hibrit karşılaştırma için)
  Future<Map<String, dynamic>?> getLocalSaveData({String? playerId}) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 4));
      final effectivePlayerId = (playerId != null && playerId.isNotEmpty)
          ? playerId
          : (FirebaseService().playerId.isNotEmpty ? FirebaseService().playerId : 'guest');
      final key = getSaveKeyForPlayer(effectivePlayerId);
      var jsonStr = prefs.getString(key);

      // Sadece misafir modundaysa VEYA cihazdaki son aktif oyuncu kimliği bu oyuncuyla eşleşiyorsa fallback kullan:
      if (jsonStr == null || jsonStr.isEmpty) {
        final lastActivePid = prefs.getString(_lastActivePlayerIdKey);
        if (effectivePlayerId == 'guest' ||
            effectivePlayerId == 'player_guest' ||
            (lastActivePid != null && lastActivePid == effectivePlayerId)) {
          jsonStr = prefs.getString(_lastActiveSaveKey);
        }
      }

      if (jsonStr != null && jsonStr.isNotEmpty) {
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('SaveService getLocalSaveData error: $e');
    }
    return null;
  }

  /// Son aktif genel yedek kaydı döndürür
  Future<Map<String, dynamic>?> getLastFallbackSaveData({String? forPlayerId}) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 4));
      final lastActivePid = prefs.getString(_lastActivePlayerIdKey);
      if (forPlayerId != null && forPlayerId.isNotEmpty && forPlayerId != 'guest' && forPlayerId != 'player_guest') {
        if (lastActivePid != null && lastActivePid != forPlayerId) {
          // Farklı bir oyuncu için fallback yüklenemez (profil izolasyonu)
          return null;
        }
      }
      final jsonStr = prefs.getString(_lastActiveSaveKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('SaveService getLastFallbackSaveData error: $e');
    }
    return null;
  }

  /// Cihazda herhangi bir geçerli yerel oyun kaydı olup olmadığını denetler
  Future<bool> hasAnyLocalSave() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 4));
      final lastSave = prefs.getString(_lastActiveSaveKey);
      if (lastSave != null && lastSave.isNotEmpty) return true;
      final keys = prefs.getKeys();
      for (final k in keys) {
        if (k.startsWith(_baseSaveKey)) {
          final val = prefs.getString(k);
          if (val != null && val.isNotEmpty) return true;
        }
      }
    } catch (e) {
      debugPrint('SaveService hasAnyLocalSave error: $e');
    }
    return false;
  }

  /// Belirli bir oyuncuya ait kaydedilmiş oyun verisini yerel depolamadan okur ve controller'a yükler
  Future<bool> load(GameController controller, {String? playerId}) async {
    try {
      final data = await getLocalSaveData(playerId: playerId);
      if (data != null) {
        controller.loadFromSaveJson(data);
        return true;
      }
    } catch (e) {
      debugPrint('SaveService load error: $e');
    }
    return false;
  }

  /// Oyuncuya ait kayıt olup olmadığını denetler
  Future<bool> hasSaveForPlayer({String? playerId}) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 4));
      final effectivePlayerId = (playerId != null && playerId.isNotEmpty)
          ? playerId
          : (FirebaseService().playerId.isNotEmpty ? FirebaseService().playerId : 'guest');
      final key = getSaveKeyForPlayer(effectivePlayerId);
      final jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) return true;
      final fallback = prefs.getString(_lastActiveSaveKey);
      return fallback != null && fallback.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Belirli bir oyuncunun kaydını temizler
  Future<void> clear({String? playerId}) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 4));
      final effectivePlayerId = (playerId != null && playerId.isNotEmpty)
          ? playerId
          : (FirebaseService().playerId.isNotEmpty ? FirebaseService().playerId : 'guest');
      final key = getSaveKeyForPlayer(effectivePlayerId);
      await prefs.remove(key);
    } catch (e) {
      debugPrint('SaveService clear error: $e');
    }
  }
}
