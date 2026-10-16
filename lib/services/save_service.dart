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
  bool _isSaving = false;
  bool _pendingSaveRequested = false;
  GameController? _pendingController;
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
    _pendingController = null;
    _pendingPlayerId = null;
    _pendingWaiters.clear();
  }

  /// Oyuncunun mevcut oyun durumunu oyuncuya özel anahtarla yerel depolamaya (SharedPreferences) kaydeder.
  Future<void> save(GameController controller, {String? playerId}) async {
    final effectiveId = (playerId != null && playerId.isNotEmpty)
        ? playerId
        : (FirebaseService().playerId.isNotEmpty ? FirebaseService().playerId : 'guest');

    if (_isSaving) {
      _pendingSaveRequested = true;
      _pendingController = controller;
      _pendingPlayerId = effectiveId;
      final completer = Completer<void>();
      _pendingWaiters.add(completer);
      return completer.future;
    }

    _isSaving = true;
    try {
      await _performSave(controller, effectiveId);
    } finally {
      _isSaving = false;
      if (_pendingSaveRequested && _pendingController != null) {
        _pendingSaveRequested = false;
        final nextController = _pendingController!;
        final nextPlayerId = _pendingPlayerId;
        _pendingController = null;
        _pendingPlayerId = null;
        final waiters = List<Completer<void>>.from(_pendingWaiters);
        _pendingWaiters.clear();

        try {
          await save(nextController, playerId: nextPlayerId);
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

  Future<void> _performSave(GameController controller, String effectivePlayerId) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
      final data = controller.toSaveJson();
      final jsonStr = jsonEncode(data);
      final key = getSaveKeyForPlayer(effectivePlayerId);
      await prefs.setString(key, jsonStr).timeout(const Duration(seconds: 2));
    } catch (e, stack) {
      debugPrint('SaveService save error: $e\n$stack');
    }
  }

  /// Belirli bir oyuncuya ait kaydedilmiş oyun verisini yerel depolamadan okur ve controller'a yükler
  Future<bool> load(GameController controller, {String? playerId}) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
      final effectivePlayerId = (playerId != null && playerId.isNotEmpty)
          ? playerId
          : (FirebaseService().playerId.isNotEmpty ? FirebaseService().playerId : 'guest');
      final key = getSaveKeyForPlayer(effectivePlayerId);
      final jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
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
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
      final effectivePlayerId = (playerId != null && playerId.isNotEmpty)
          ? playerId
          : (FirebaseService().playerId.isNotEmpty ? FirebaseService().playerId : 'guest');
      final key = getSaveKeyForPlayer(effectivePlayerId);
      final jsonStr = prefs.getString(key);
      return jsonStr != null && jsonStr.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Belirli bir oyuncunun kaydını temizler
  Future<void> clear({String? playerId}) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
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
