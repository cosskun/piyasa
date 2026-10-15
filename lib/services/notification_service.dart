import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<String> _selectNotificationStream =
      StreamController<String>.broadcast();
  Stream<String> get onNotificationTapped => _selectNotificationStream.stream;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Android ayarları
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      // iOS / Darwin ayarları
      final DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      final InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            _selectNotificationStream.add(response.payload!);
          }
        },
      );

      // Android 13+ bildirim izni
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }

      // iOS bildirim izni
      final iosPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error (platform may not support): $e');
    }
  }

  // 1. Yeni Gelen Teklif Bildirimi (Oyuncunun ilanına başkası teklif verince)
  Future<void> showIncomingOfferNotification({
    required String buyerName,
    required String itemName,
    required int quantity,
    required double price,
  }) async {
    await _showNotification(
      id: 101,
      title: '📩 Yeni Teklif Geldi!',
      body: '$buyerName, $quantity adet $itemName için birim başı $price ₺ teklif etti. İncelemek için dokunun.',
      payload: 'offer_incoming',
    );
  }

  // 2. Verilen Teklif Karar Bildirimi (Onaylandı veya Reddedildi)
  Future<void> showOfferDecisionNotification({
    required String sellerName,
    required String itemName,
    required int quantity,
    required double price,
    required bool accepted,
  }) async {
    if (accepted) {
      await _showNotification(
        id: 102,
        title: '🔔 Teklifiniz Onaylandı!',
        body: '$sellerName, $quantity adet $itemName teklifinizi ($price ₺) kabul etti! Satın almak için dokunun.',
        payload: 'offer_outgoing',
      );
    } else {
      await _showNotification(
        id: 103,
        title: '❌ Teklif Reddedildi',
        body: '$sellerName, $quantity adet $itemName için verdiğiniz teklifi çok düşük buldu.',
        payload: 'offer_outgoing',
      );
    }
  }

  // 3. Otomatik Alış Emri Gerçekleşti Bildirimi
  Future<void> showLimitOrderExecutedNotification({
    required String itemName,
    required int quantity,
    required double price,
  }) async {
    await _showNotification(
      id: 104,
      title: '🎯 Alış Emri Gerçekleşti!',
      body: 'Piyasa fiyatı hedefinize indi: $quantity adet $itemName birim başı $price ₺ fiyattan satın alındı ve deponuza eklendi.',
      payload: 'order_limit',
    );
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'piyasa_game_notifications',
        'Piyasa Bildirimleri',
        channelDescription: 'Teklifler, borsa alımları ve pazar bildirimleri',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Local notification show error: $e');
    }
  }
}
