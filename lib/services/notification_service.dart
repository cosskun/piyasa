import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _prefKeyNotificationPermissionRequested =
      'has_requested_notification_permission';

  static const int warehouseFullNotificationId = 301;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<String> _selectNotificationStream =
      StreamController<String>.broadcast();
  Stream<String> get onNotificationTapped => _selectNotificationStream.stream;

  bool _isInitialized = false;

  /// Test ve izleme değişkenleri
  int? lastShownNotificationId;
  String? lastShownTitle;
  String? lastShownBody;
  Duration? lastScheduledDelay;
  bool hasScheduledWarehouseFullNotification = false;

  /// Kullanıcı oyun içindeyken (foreground) telefon bildirim çubuğunu rahatsız etmeme bayrağı
  bool isAppInForeground = true;

  void setAppInForeground(bool inForeground) {
    isAppInForeground = inForeground;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('NotificationService: timezone init error: $e');
    }

    try {
      // Android ayarları
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      // iOS / Darwin ayarları (Başlangıçta kullanıcıyı boğmamak ve cold launch hatasını önlemek için otomatik izin kapalı)
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initSettings = InitializationSettings(
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

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error (platform may not support): $e');
    }
  }

  /// Android (13+) ve iOS sistem bildirim izinlerini kullanıcıdan ister.
  Future<bool> requestNotificationPermissions() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      bool? androidGranted = false;
      bool? iosGranted = false;

      // Android 13+ bildirim izni (POST_NOTIFICATIONS)
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        androidGranted = await androidPlugin.requestNotificationsPermission();
        debugPrint('NotificationService: Android bildirim izni sonucu: $androidGranted');
      }

      // iOS bildirim izni (Alert, Badge, Sound)
      final iosPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        iosGranted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('NotificationService: iOS bildirim izni sonucu: $iosGranted');
      }

      return (androidGranted ?? false) || (iosGranted ?? false);
    } catch (e) {
      debugPrint('NotificationService requestNotificationPermissions hatası: $e');
      return false;
    }
  }

  /// Sadece yeni kullanıcı kaydolduğunda veya yeni indirip ilk kez giriş yapıldığında çağrılır.
  /// Daha önce bu cihazda izin istenmişse kullanıcıyı tekrar rahatsız etmez.
  Future<bool> requestPermissionsOnFirstAuth({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyRequested = prefs.getBool(_prefKeyNotificationPermissionRequested) ?? false;
      if (alreadyRequested && !force) {
        debugPrint('NotificationService: Bildirim izni bu cihazda daha önce istendi, atlanıyor.');
        return false;
      }

      debugPrint('NotificationService: İlk giriş/kayıt tespit edildi, bildirim izinleri isteniyor...');
      final result = await requestNotificationPermissions();
      await prefs.setBool(_prefKeyNotificationPermissionRequested, true);
      return result;
    } catch (e) {
      debugPrint('NotificationService requestPermissionsOnFirstAuth hatası: $e');
      return false;
    }
  }

  /// Yeni kullanıcı kaydı açıldığında izin bayrağını sıfırlamak için
  Future<void> resetPermissionRequestState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyNotificationPermissionRequested);
    } catch (e) {
      debugPrint('NotificationService resetPermissionRequestState hatası: $e');
    }
  }

  /// Bu cihazda daha önce bildirim izni sorulup sorulmadığını döner
  Future<bool> hasRequestedPermissionsBefore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefKeyNotificationPermissionRequested) ?? false;
    } catch (e) {
      return false;
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

  // 4. Kredi Günlük Taksit Otomatik Ödeme Bildirimi
  Future<void> showLoanRepaidNotification({
    required String loanTitle,
    required int installmentNumber,
    required double amount,
    bool isOverdueSettlement = false,
  }) async {
    final title = isOverdueSettlement
        ? '💳 Gecikmeli Kredi Taksiti Tahsil Edildi'
        : '💳 Kredi Taksit Ödemesi Yapıldı';
    final body = isOverdueSettlement
        ? '$loanTitle kredisinin gecikmedeki $installmentNumber. gün taksiti (${amount.toStringAsFixed(0)} ₺) hesabınızdan tahsil edildi.'
        : '$loanTitle kredisinin $installmentNumber. gün taksiti (${amount.toStringAsFixed(0)} ₺) hesabınızdan otomatik ödendi.';

    await _showNotification(
      id: 201,
      title: title,
      body: body,
      payload: 'bank_loan',
    );
  }

  // 5. Kredi Taksit Gecikmesi & Ceza Bildirimi
  Future<void> showLoanOverduePenaltyNotification({
    required String loanTitle,
    required int installmentNumber,
    required double amount,
    required double penaltyAmount,
  }) async {
    await _showNotification(
      id: 202,
      title: '⚠️ Kredi Taksiti Gecikti! (Ceza İşliyor)',
      body: 'Hesabınızda yeterli bakiye bulunamadı! $loanTitle kredisinin $installmentNumber. gün taksitine (${amount.toStringAsFixed(0)} ₺) ceza eklendi (+${penaltyAmount.toStringAsFixed(0)} ₺). Lütfen hesabınıza bakiye yükleyiniz.',
      payload: 'bank_loan',
    );
  }

  // 6. Kredi Tamamen Ödendi Bildirimi
  Future<void> showLoanFullyPaidNotification({
    required String loanTitle,
  }) async {
    await _showNotification(
      id: 203,
      title: '🎉 Kredi Borcunuz Kapandı!',
      body: 'Tebrikler! $loanTitle kredisinin tüm taksitleri başarıyla ödendi ve banka borcunuz kapandı.',
      payload: 'bank_loan',
    );
  }

  // 7. Depo Tamamen Doldu Bildirimi (Anlık / Kritik Bildirim)
  Future<void> showWarehouseFullNotification({
    required double currentWeight,
    required double maxCapacity,
    bool force = true,
  }) async {
    await _showNotification(
      id: warehouseFullNotificationId,
      title: '📦 Deponuz Tamamen Doldu!',
      body:
          'Tarlalarınız ve fabrikalarınız üretim yapabilmek için depoda yer açılmasını bekliyor. Ürünlerinizi satın veya depoyu genişletin.',
      payload: 'warehouse_full',
      force: force,
    );
  }

  int _scheduleSequence = 0;

  /// Uygulama arka plana alındığında, deponun dolacağı tahmini zamana OS bildirimi kurar.
  Future<void> scheduleWarehouseFullNotification({
    required Duration delay,
    required double maxCapacity,
  }) async {
    final currentSeq = ++_scheduleSequence;
    lastScheduledDelay = delay;
    hasScheduledWarehouseFullNotification = true;

    if (delay <= Duration.zero) {
      await showWarehouseFullNotification(
        currentWeight: maxCapacity,
        maxCapacity: maxCapacity,
        force: true,
      );
      return;
    }

    if (!_isInitialized) {
      await initialize();
    }
    if (currentSeq != _scheduleSequence) return;

    try {
      await _notificationsPlugin.cancel(id: warehouseFullNotificationId);
      if (currentSeq != _scheduleSequence) return;

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'piyasa_warehouse_notifications',
        'Piyasa Depo Bildirimleri',
        channelDescription: 'Depo kapasite ve lojistik bildirimleri',
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
        presentBanner: true,
        presentList: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final tz.TZDateTime scheduledDate = tz.TZDateTime.now(tz.local).add(delay);

      await _notificationsPlugin.zonedSchedule(
        id: warehouseFullNotificationId,
        title: '📦 Deponuz Tamamen Doldu!',
        body:
            'Tarlalarınız ve fabrikalarınız üretim yapabilmek için depoda yer açılmasını bekliyor. Ürünlerinizi satın veya depoyu genişletin.',
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'warehouse_full',
      );
      debugPrint('NotificationService: Depo doluluk bildirimi ${delay.inSeconds} sn sonrasına planlandı ($scheduledDate).');
    } catch (e) {
      debugPrint('NotificationService scheduleWarehouseFullNotification hatası: $e');
    }
  }

  /// Bekleyen veya planlanmış depo doluluk bildirimini iptal eder.
  Future<void> cancelWarehouseFullNotification() async {
    _scheduleSequence++;
    hasScheduledWarehouseFullNotification = false;
    try {
      await _notificationsPlugin.cancel(id: warehouseFullNotificationId);
    } catch (e) {
      debugPrint('NotificationService cancelWarehouseFullNotification hatası: $e');
    }
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
    bool force = false,
  }) async {
    lastShownNotificationId = id;
    lastShownTitle = title;
    lastShownBody = body;

    // Kullanıcı oyunun içindeyse standart bildirimler telefon çubuğuna düşürülmez.
    // Ancak force == true ise (örneğin deponun tamamen dolması gibi kritik bildirimler)
    // iOS banner veya Android başlık bildirimi olarak ekranda gösterilir.
    if (isAppInForeground && !force) {
      return;
    }

    if (!_isInitialized) return;
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
        presentBanner: true,
        presentList: true,
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
