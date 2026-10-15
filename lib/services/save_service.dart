import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/game_controller.dart';

class SaveService {
  static final SaveService _instance = SaveService._internal();
  factory SaveService() => _instance;
  SaveService._internal();

  static const String saveKey = 'piyasa_save_state_v1';
  bool _isSaving = false;
  bool _pendingSaveRequested = false;
  GameController? _pendingController;
  final List<Completer<void>> _pendingWaiters = [];

  @visibleForTesting
  void resetForTesting() {
    _isSaving = false;
    _pendingSaveRequested = false;
    _pendingController = null;
    _pendingWaiters.clear();
  }

  /// Oyuncunun mevcut oyun durumunu yerel depolamaya (SharedPreferences) asenkron kaydeder.
  /// Hızlı arka arkaya gelen kaydetme çağrılarını biriktirerek diski yormaz ve kilitlenmeyi önler.
  Future<void> save(GameController controller) async {
    if (_isSaving) {
      _pendingSaveRequested = true;
      _pendingController = controller;
      final completer = Completer<void>();
      _pendingWaiters.add(completer);
      return completer.future;
    }

    _isSaving = true;
    try {
      await _performSave(controller);
    } finally {
      _isSaving = false;
      if (_pendingSaveRequested && _pendingController != null) {
        _pendingSaveRequested = false;
        final nextController = _pendingController!;
        _pendingController = null;
        final waiters = List<Completer<void>>.from(_pendingWaiters);
        _pendingWaiters.clear();

        try {
          await save(nextController);
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

  Future<void> _performSave(GameController controller) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
      final data = controller.toSaveJson();
      final jsonStr = jsonEncode(data);
      await prefs.setString(saveKey, jsonStr).timeout(const Duration(seconds: 2));
    } catch (e, stack) {
      debugPrint('SaveService save error: $e\n$stack');
    }
  }

  /// Kaydedilmiş oyun verisini yerel depolamadan okur ve controller'a yükler
  Future<bool> load(GameController controller) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
      final jsonStr = prefs.getString(saveKey);
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

  /// Kaydı temizleyip sıfırlar (Yeni oyun için)
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
      await prefs.remove(saveKey);
    } catch (e) {
      debugPrint('SaveService clear error: $e');
    }
  }
}
