import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_config.dart';
import '../models/market_listing.dart';
import '../models/market_offer.dart';
import '../models/audit_log.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  bool _initialized = false;
  String? _playerId;
  String? _companyName;
  String? _username;
  bool _isGuest = false;

  // Baş Yönetici (Admin) Yetkilendirme Bilgileri
  static const String adminEmail = 'furkanc28@gmail.com';
  static const String adminUsername = 'COSSKUN';

  String _role = 'user';
  bool _isBanned = false;
  String? _banReason;
  StreamSubscription<DocumentSnapshot>? _banSubscription;
  final ValueNotifier<bool> isBannedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> banReasonNotifier = ValueNotifier<String?>(null);

  static const String _localPlayerIdKey = 'piyasa_player_unique_id';
  static const String _localCompanyNameKey = 'piyasa_player_company_name';
  static const String _localUsernameKey = 'piyasa_player_username';
  static const String _localIsGuestKey = 'piyasa_is_guest';
  static const String _localOfflineSalesKey = 'piyasa_unclaimed_market_sales';
  static const String _localAccountsKey = 'piyasa_registered_accounts_v2';

  bool get isCloudConnected => _initialized && FirebaseConfig.isConfigured && _firestore != null;
  String get playerId => _playerId ?? 'player_guest';
  String get companyName => _companyName ?? 'Piyasa Holding';
  String? get username => _username;
  bool get isLoggedIn => _auth?.currentUser != null || (!isCloudConnected && _username != null && _username!.isNotEmpty);
  bool get isGuest => _isGuest;
  bool get isAuthenticated => isLoggedIn || _isGuest;
  String? get email => _auth?.currentUser?.email;

  bool get isAdmin {
    if (_role == 'admin') return true;
    final currEmail = (email ?? '').trim().toLowerCase();
    if (currEmail.isNotEmpty && currEmail == adminEmail.toLowerCase()) return true;
    final currUser = (_username ?? '').trim().toUpperCase();
    if (currUser.isNotEmpty && currUser == adminUsername.toUpperCase()) return true;
    return false;
  }

  bool get isBanned => _isBanned;
  String? get banReason => _banReason;
  String get role => _role;

  void _listenToBanStatus(String uid) {
    _banSubscription?.cancel();
    if (!isCloudConnected || _firestore == null) return;
    try {
      _banSubscription = _firestore!.collection('players').doc(uid).snapshots().listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;
          final banned = data['isBanned'] == true;
          final reason = data['banReason'] as String?;
          final roleStr = data['role'] as String? ?? 'user';
          _role = roleStr;
          _isBanned = banned;
          _banReason = reason;
          isBannedNotifier.value = banned;
          banReasonNotifier.value = reason;
        }
      }, onError: (e) {
        debugPrint('FirebaseService: Ban dinleyici hatası: $e');
      });
    } catch (e) {
      debugPrint('FirebaseService: _listenToBanStatus hatası: $e');
    }
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    _playerId = prefs.getString(_localPlayerIdKey);
    if (_playerId == null || _playerId!.isEmpty) {
      _playerId = 'ply_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
      await prefs.setString(_localPlayerIdKey, _playerId!);
    }

    _companyName = prefs.getString(_localCompanyNameKey);
    if (_companyName == null || _companyName!.isEmpty) {
      _companyName = 'Piyasa Holding';
      await prefs.setString(_localCompanyNameKey, _companyName!);
    }

    _username = prefs.getString(_localUsernameKey);
    _isGuest = prefs.getBool(_localIsGuestKey) ?? false;

    // 2. Firebase Bulut Bağlantısı
    if (FirebaseConfig.isConfigured && FirebaseConfig.currentPlatform != null) {
      try {
        await Firebase.initializeApp(options: FirebaseConfig.currentPlatform!).timeout(const Duration(seconds: 5));
        _firestore = FirebaseFirestore.instance;
        _auth = FirebaseAuth.instance;
        _initialized = true;

        // Kullanıcı önceden oturum açmış mı kontrol et
        if (_auth!.currentUser != null) {
          _playerId = _auth!.currentUser!.uid;
          await prefs.setString(_localPlayerIdKey, _playerId!);

          // Kullanıcı profilini Firestore'dan çek
          try {
            final playerDoc = await _firestore!.collection('players').doc(_playerId).get().timeout(const Duration(seconds: 4));
            if (playerDoc.exists && playerDoc.data() != null) {
              final data = playerDoc.data()!;
              if (data['username'] != null) {
                _username = data['username'] as String;
                await prefs.setString(_localUsernameKey, _username!);
              }
              if (data['companyName'] != null) {
                _companyName = data['companyName'] as String;
                await prefs.setString(_localCompanyNameKey, _companyName!);
              }
              if (data['role'] != null) {
                _role = data['role'] as String;
              }
              _isBanned = data['isBanned'] == true;
              _banReason = data['banReason'] as String?;
              isBannedNotifier.value = _isBanned;
              banReasonNotifier.value = _banReason;

              if (isAdmin && _role != 'admin') {
                _role = 'admin';
                _firestore!.collection('players').doc(_playerId).set({'role': 'admin'}, SetOptions(merge: true));
              }
              _listenToBanStatus(_playerId!);
            }
          } catch (e) {
            debugPrint('FirebaseService: Oyuncu profili çekilemedi: $e');
          }
        }
        debugPrint('FirebaseService: Bulut bağlantısı başarıyla kuruldu! (UID: $_playerId, LoggedIn: $isLoggedIn, Admin: $isAdmin)');
      } catch (e) {
        debugPrint('FirebaseService: Bulut başlatma hatası, yerel modda devam ediliyor: $e');
        _initialized = false;
      }
    } else {
      debugPrint('FirebaseService: Yapılandırma anahtarları henüz girilmedi, yerel + simüle mod devrede.');
      _initialized = false;
    }

    // Bilinmeyen / geçersiz kullanıcıları arka planda otomatik temizle
    unawaited(cleanupUnknownPlayers());
  }

  // ==========================================
  // OYUNCU MAL VARLIĞI BULUT SENKRONİZASYONU
  // ==========================================
  Future<void> syncPlayerAssetsToCloud(Map<String, dynamic> assetData, {String? targetPlayerId}) async {
    final targetId = (targetPlayerId != null && targetPlayerId.isNotEmpty) ? targetPlayerId : playerId;

    // 1. Yerel hesap havuzunu güncelle (Offline / Local modda da sıralama için anlık yansıtır)
    try {
      final localAccounts = await getLocalAccounts();
      for (var acc in localAccounts.values) {
        if (acc['uid'] == targetId) {
          if (assetData.containsKey('netWorth')) acc['netWorth'] = assetData['netWorth'];
          if (assetData.containsKey('highestNetWorth')) acc['highestNetWorth'] = assetData['highestNetWorth'];
          if (assetData.containsKey('cash')) acc['cash'] = assetData['cash'];
          if (assetData.containsKey('playerLevel')) acc['level'] = assetData['playerLevel'];
          if (assetData.containsKey('playerTitle')) acc['levelTitle'] = assetData['playerTitle'];
          if (assetData.containsKey('companyName')) acc['companyName'] = assetData['companyName'];
          if (assetData.containsKey('totalFacilitiesCount')) acc['facilitiesCount'] = assetData['totalFacilitiesCount'];
          if (assetData.containsKey('totalStoresCount')) acc['storesCount'] = assetData['totalStoresCount'];
          acc['lastActiveAt'] = DateTime.now().toIso8601String();
          await saveLocalAccount(acc);
          break;
        }
      }
    } catch (e) {
      debugPrint('FirebaseService: Yerel hesap servet güncelleme hatası: $e');
    }

    if (!isCloudConnected) return;

    try {
      final docRef = _firestore!.collection('players').doc(targetId);
      assetData['updatedAt'] = FieldValue.serverTimestamp();
      assetData['companyName'] = companyName;
      if (_username != null && _username!.isNotEmpty) {
        assetData['username'] = _username;
      }
      await docRef.set(assetData, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('FirebaseService: Mal varlığı buluta kaydedilemedi: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchPlayerAssetsFromCloud({String? targetPlayerId}) async {
    if (!isCloudConnected) return null;

    final targetId = (targetPlayerId != null && targetPlayerId.isNotEmpty) ? targetPlayerId : playerId;
    try {
      final docRef = _firestore!.collection('players').doc(targetId);
      final snapshot = await docRef.get().timeout(const Duration(seconds: 4));
      if (snapshot.exists && snapshot.data() != null) {
        return snapshot.data()!;
      }
    } catch (e) {
      debugPrint('FirebaseService: Buluttan mal varlığı çekilemedi: $e');
    }
    return null;
  }

  // ==========================================
  // CANLI ORTAK OYUNCU PAZARI (MARKET LISTINGS)
  // ==========================================
  /// Oyuncu offline olsa dahi tüm dünyadaki oyuncuların görebileceği ortak pazar ilanı oluşturur
  Future<void> publishListingToMarket(MarketListing listing) async {
    if (!isCloudConnected) return;

    try {
      final docRef = _firestore!.collection('market_listings').doc(listing.id);
      final data = listing.toJson();
      data['sellerId'] = playerId;
      data['sellerName'] = companyName;
      data['isCompleted'] = false;
      data['serverCreatedAt'] = FieldValue.serverTimestamp();
      await docRef.set(data);
    } catch (e) {
      debugPrint('FirebaseService: İlan pazara yüklenemedi: $e');
    }
  }

  /// Ortak pazardaki canlı ilanları anlık akış (Stream) olarak dinler
  Stream<List<MarketListing>> streamPublicMarketListings() {
    if (!isCloudConnected) {
      return const Stream.empty();
    }

    return _firestore!
        .collection('market_listings')
        .where('isCompleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['isPlayerListing'] = (data['sellerId'] == playerId);
        return MarketListing.fromJson(data);
      }).toList();
    });
  }

  /// Canlı pazardan ürün satın alma (Satıcı offline olsa bile gerçekleşir)
  Future<bool> buyFromPublicMarket({
    required MarketListing listing,
    required int quantityToBuy,
  }) async {
    if (!isCloudConnected) return false;

    try {
      final docRef = _firestore!.collection('market_listings').doc(listing.id);
      return await _firestore!.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return false;

        final currentRemaining = (snapshot.get('remainingQuantity') as num).toInt();
        if (currentRemaining < quantityToBuy) return false;

        final newRemaining = currentRemaining - quantityToBuy;
        final isCompleted = newRemaining <= 0;
        final revenue = quantityToBuy * listing.pricePerUnit;

        transaction.update(docRef, {
          'remainingQuantity': newRemaining,
          'isCompleted': isCompleted,
          'totalEarned': FieldValue.increment(revenue),
        });

        // Satıcı için çevrimdışı satış kaydı oluştur (satıcı oyunu açtığında tahsil eder)
        final sellerId = snapshot.get('sellerId') as String?;
        if (sellerId != null && sellerId != playerId) {
          final saleRef = _firestore!
              .collection('players')
              .doc(sellerId)
              .collection('offline_sales')
              .doc();

          transaction.set(saleRef, {
            'listingId': listing.id,
            'buyerName': companyName,
            'itemId': listing.itemId,
            'quantity': quantityToBuy,
            'pricePerUnit': listing.pricePerUnit,
            'totalRevenue': revenue,
            'timestamp': FieldValue.serverTimestamp(),
            'isClaimed': false,
          });

          // Satıcının online kasasına doğrudan bakiye ekleme
          transaction.update(_firestore!.collection('players').doc(sellerId), {
            'cash': FieldValue.increment(revenue),
          });
        }

        return true;
      });
    } catch (e) {
      debugPrint('FirebaseService: Satın alma işlemi başarısız: $e');
      return false;
    }
  }

  /// Satıcının kapalıyken pazarda satılan ürünlerinin raporunu çeker ve onaylar
  Future<List<Map<String, dynamic>>> claimOfflineSales() async {
    if (!isCloudConnected) {
      // Yerel mod simülasyonu
      final prefs = await SharedPreferences.getInstance();
      final localSales = prefs.getStringList(_localOfflineSalesKey) ?? [];
      await prefs.remove(_localOfflineSalesKey);
      return localSales.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
    }

    try {
      final salesRef = _firestore!
          .collection('players')
          .doc(playerId)
          .collection('offline_sales')
          .where('isClaimed', isEqualTo: false);

      final snapshot = await salesRef.get().timeout(const Duration(seconds: 4));
      final sales = <Map<String, dynamic>>[];

      final batch = _firestore!.batch();
      for (var doc in snapshot.docs) {
        sales.add(doc.data());
        batch.update(doc.reference, {'isClaimed': true});
      }
      await batch.commit().timeout(const Duration(seconds: 4));

      return sales;
    } catch (e) {
      debugPrint('FirebaseService: Çevrimdışı satışlar çekilemedi: $e');
      return [];
    }
  }

  /// Yerel modda çevrimdışı satış kaydetme simülasyonu
  Future<void> recordMockOfflineSale(Map<String, dynamic> saleData) async {
    final prefs = await SharedPreferences.getInstance();
    final localSales = prefs.getStringList(_localOfflineSalesKey) ?? [];
    localSales.add(jsonEncode(saleData));
    await prefs.setStringList(_localOfflineSalesKey, localSales);
  }

  /// Pazar ilanını buluttan siler
  Future<void> cancelListingInMarket(String listingId) async {
    if (!isCloudConnected) return;

    try {
      await _firestore!.collection('market_listings').doc(listingId).delete();
    } catch (e) {
      debugPrint('FirebaseService: İlan pazardan kaldırılamadı: $e');
    }
  }

  // ==========================================
  // KULLANICI GİRİŞ, KAYIT VE HESAP YÖNETİMİ
  // ==========================================

  /// Yerel kayıtlı hesaplar havuzunu getirir
  Future<Map<String, Map<String, dynamic>>> getLocalAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localAccountsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <String, Map<String, dynamic>>{};
      decoded.forEach((key, val) {
        if (val is Map<String, dynamic>) {
          result[key] = val;
        } else if (val is Map) {
          result[key] = Map<String, dynamic>.from(val);
        }
      });
      return result;
    } catch (e) {
      debugPrint('FirebaseService: getLocalAccounts decode error: $e');
      return {};
    }
  }

  /// Yerel hesabı kaydeder veya günceller
  Future<void> saveLocalAccount(Map<String, dynamic> accountData) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getLocalAccounts();
    final usernameLower = (accountData['username_lowercase'] as String? ??
            accountData['username'] as String? ??
            '')
        .trim()
        .toLowerCase();
    if (usernameLower.isNotEmpty) {
      accounts[usernameLower] = accountData;
      await prefs.setString(_localAccountsKey, jsonEncode(accounts));
    }
  }

  /// Kullanıcı adının daha önce alınıp alınmadığını kontrol eder (Case-insensitive)
  Future<bool> isUsernameAvailable(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean.length < 3 || clean.length > 20) return false;
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(clean)) return false;

    // 1. Yerel veritabanında benzersizlik kontrolü
    final localAccounts = await getLocalAccounts();
    if (localAccounts.containsKey(clean)) return false;

    if (!isCloudConnected) return true;

    try {
      final doc = await _firestore!.collection('usernames').doc(clean).get().timeout(const Duration(seconds: 4));
      return !doc.exists;
    } catch (e) {
      debugPrint('FirebaseService: Kullanıcı adı kontrol hatası: $e');
      return true;
    }
  }

  /// Benzersiz kullanıcı adı ve e-posta ile yeni oyuncu hesabı oluşturur
  /// NOT: Kayıt işlemi başarılı olduğunda ASLA otomatik oturum açılmaz, kullanıcı giriş ekranına yönlendirilir.
  Future<String?> registerWithEmail({
    required String email,
    required String password,
    required String username,
    String? companyName,
  }) async {
    final cleanUsername = username.trim();
    final normalizedUsername = cleanUsername.toLowerCase();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanUsername.length < 3 || cleanUsername.length > 20) {
      return 'Kullanıcı adı 3 ile 20 karakter arasında olmalıdır.';
    }

    final validUsernameRegex = RegExp(r'^[a-zA-Z0-9_.]+$');
    if (!validUsernameRegex.hasMatch(cleanUsername)) {
      return 'Kullanıcı adı sadece harf, rakam, nokta ve alt çizgi içerebilir.';
    }

    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      return 'Lütfen geçerli bir e-posta adresi girin.';
    }

    if (cleanPassword.length < 6) {
      return 'Şifreniz en az 6 karakterden oluşmalıdır.';
    }

    // 1. Yerel veritabanında benzersizlik denetimi (Kullanıcı adı & E-posta)
    final localAccounts = await getLocalAccounts();
    if (localAccounts.containsKey(normalizedUsername)) {
      return 'Bu kullanıcı adı zaten kullanımda. Lütfen başka bir kullanıcı adı seçin.';
    }
    for (var acc in localAccounts.values) {
      final accEmail = (acc['email'] as String? ?? '').toLowerCase();
      if (accEmail == cleanEmail) {
        return 'Bu e-posta adresiyle zaten kayıtlı bir hesap bulunmaktadır.';
      }
    }

    final effectiveCompanyName = (companyName != null && companyName.trim().isNotEmpty)
        ? companyName.trim()
        : '$cleanUsername Holding';

    final isAdminUser = cleanEmail == adminEmail.toLowerCase() ||
        cleanUsername.toUpperCase() == adminUsername.toUpperCase();

    if (!isCloudConnected) {
      // Yerel modda yeni benzersiz oyuncu kimliği oluştur ve kaydet
      final newUid = 'ply_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
      await saveLocalAccount({
        'uid': newUid,
        'username': cleanUsername,
        'username_lowercase': normalizedUsername,
        'email': cleanEmail,
        'password': cleanPassword,
        'companyName': effectiveCompanyName,
        'role': isAdminUser ? 'admin' : 'user',
        'isBanned': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Otomatik giriş YAPILMAZ!
      _username = null;
      _companyName = null;
      _playerId = null;
      _isGuest = false;

      return null;
    }

    try {
      // 1. Bulutta kullanıcı adının benzersizliğini kontrol et (Koleksiyon: usernames/{username_lowercase})
      final usernameDoc = await _firestore!
          .collection('usernames')
          .doc(normalizedUsername)
          .get()
          .timeout(const Duration(seconds: 7));
      if (usernameDoc.exists) {
        return 'Bu kullanıcı adı zaten kullanımda. Lütfen başka bir kullanıcı adı seçin.';
      }

      // 2. Firebase Auth ile kayıt oluştur (E-posta benzersizliği Firebase tarafından otomatik denetlenir)
      final userCredential = await _auth!
          .createUserWithEmailAndPassword(
            email: cleanEmail,
            password: cleanPassword,
          )
          .timeout(const Duration(seconds: 8));

      final user = userCredential.user;
      if (user == null) {
        return 'Kayıt sırasında bir hata oluştu. Lütfen tekrar deneyin.';
      }

      final uid = user.uid;

      // 3. Kullanıcı adını rezerve et ve oyuncu profilini Firestore'a kaydet
      final batch = _firestore!.batch();
      batch.set(_firestore!.collection('usernames').doc(normalizedUsername), {
        'uid': uid,
        'displayUsername': cleanUsername,
        'email': cleanEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(_firestore!.collection('players').doc(uid), {
        'uid': uid,
        'username': cleanUsername,
        'username_lowercase': normalizedUsername,
        'email': cleanEmail,
        'companyName': effectiveCompanyName,
        'role': isAdminUser ? 'admin' : 'user',
        'isBanned': false,
        'cash': 10000.0,
        'netWorth': 10000.0,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit().timeout(const Duration(seconds: 6));

      // Yerel hesap havuzuna da ekle
      await saveLocalAccount({
        'uid': uid,
        'username': cleanUsername,
        'username_lowercase': normalizedUsername,
        'email': cleanEmail,
        'password': cleanPassword,
        'companyName': effectiveCompanyName,
        'role': isAdminUser ? 'admin' : 'user',
        'isBanned': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      // KESİNLİKLE OTOMATİK GİRİŞ YAPILMAZ! Firebase Auth otomatik oturum açtığı için çıkış yapıyoruz:
      try {
        await _auth!.signOut().timeout(const Duration(seconds: 4));
      } catch (_) {}
      _playerId = null;
      _username = null;
      _companyName = null;
      _isGuest = false;

      return null; // Başarılı!
    } on TimeoutException {
      // Buluta bağlanamadı (zaman aşımı), güvenli yerel hesap olarak kaydet ve kullanıcının giriş yapmasını sağla
      final newUid = 'ply_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
      await saveLocalAccount({
        'uid': newUid,
        'username': cleanUsername,
        'username_lowercase': normalizedUsername,
        'email': cleanEmail,
        'password': cleanPassword,
        'companyName': effectiveCompanyName,
        'role': isAdminUser ? 'admin' : 'user',
        'isBanned': false,
        'createdAt': DateTime.now().toIso8601String(),
      });
      _playerId = null;
      _username = null;
      _companyName = null;
      _isGuest = false;
      return null;
    } on FirebaseAuthException catch (e) {
      final isConfigError = e.code == 'operation-not-allowed' ||
          e.code == 'configuration-not-found' ||
          (e.message != null && e.message!.contains('CONFIGURATION_NOT_FOUND'));

      if (isConfigError && _firestore != null) {
        // Firebase Auth henüz Console'da açılmamışsa doğrudan Firestore Bulut hesabı oluşturuyoruz
        try {
          final newUid = 'ply_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
          final batch = _firestore!.batch();
          batch.set(_firestore!.collection('usernames').doc(normalizedUsername), {
            'uid': newUid,
            'displayUsername': cleanUsername,
            'email': cleanEmail,
            'password': cleanPassword,
            'authProvider': 'firestore_cloud',
            'createdAt': FieldValue.serverTimestamp(),
          });
          batch.set(_firestore!.collection('players').doc(newUid), {
            'uid': newUid,
            'username': cleanUsername,
            'username_lowercase': normalizedUsername,
            'email': cleanEmail,
            'password': cleanPassword,
            'companyName': effectiveCompanyName,
            'role': isAdminUser ? 'admin' : 'user',
            'isBanned': false,
            'cash': 10000.0,
            'netWorth': 10000.0,
            'authProvider': 'firestore_cloud',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          await batch.commit().timeout(const Duration(seconds: 6));

          await saveLocalAccount({
            'uid': newUid,
            'username': cleanUsername,
            'username_lowercase': normalizedUsername,
            'email': cleanEmail,
            'password': cleanPassword,
            'companyName': effectiveCompanyName,
            'role': isAdminUser ? 'admin' : 'user',
            'isBanned': false,
            'authProvider': 'firestore_cloud',
            'createdAt': DateTime.now().toIso8601String(),
          });

          return null; // Başarıyla Firestore bulutuna kaydedildi!
        } catch (cloudErr) {
          debugPrint('Firestore bulut hesabı oluşturma hatası: $cloudErr');
          return 'Firebase Authentication ayarlarında E-posta/Şifre sağlayıcısı henüz etkinleştirilmemiş (CONFIGURATION_NOT_FOUND). Lütfen Firebase Console -> Authentication -> Sign-in method üzerinden etkinleştirin.';
        }
      }

      switch (e.code) {
        case 'email-already-in-use':
          return 'Bu e-posta adresiyle zaten kayıtlı bir hesap bulunmaktadır.';
        case 'invalid-email':
          return 'Lütfen geçerli bir e-posta adresi girin.';
        case 'weak-password':
          return 'Şifreniz çok zayıf. En az 6 karakterli daha güçlü bir şifre belirleyin.';
        case 'operation-not-allowed':
          return 'Firebase Authentication ayarlarında E-posta/Şifre sağlayıcısı henüz etkinleştirilmemiş.';
        default:
          if (e.message != null && e.message!.contains('CONFIGURATION_NOT_FOUND')) {
            return 'Firebase Authentication ayarlarında E-posta/Şifre sağlayıcısı henüz etkinleştirilmemiş (CONFIGURATION_NOT_FOUND). Lütfen Firebase Console -> Authentication -> Sign-in method üzerinden etkinleştirin.';
          }
          return e.message ?? 'Kayıt işlemi başarısız oldu (${e.code}).';
      }
    } catch (e) {
      return 'Bağlantı hatası: $e';
    }
  }

  /// Kullanıcı adı VEYA E-posta ile giriş yapma
  Future<String?> loginWithEmailOrUsername({
    required String identifier,
    required String password,
  }) async {
    final cleanIdentifier = identifier.trim();
    final cleanPassword = password.trim();

    if (cleanIdentifier.isEmpty || cleanPassword.isEmpty) {
      return 'Lütfen kullanıcı adı / e-posta ve şifrenizi girin.';
    }

    if (!isCloudConnected) {
      final localAccounts = await getLocalAccounts();
      final norm = cleanIdentifier.toLowerCase();
      Map<String, dynamic>? matchedAccount;

      if (localAccounts.containsKey(norm)) {
        matchedAccount = localAccounts[norm];
      } else {
        for (var acc in localAccounts.values) {
          final accEmail = (acc['email'] as String? ?? '').toLowerCase();
          if (accEmail == norm) {
            matchedAccount = acc;
            break;
          }
        }
      }

      if (matchedAccount == null) {
        return 'Kullanıcı adı veya e-posta adresi bulunamadı.';
      }

      if (matchedAccount['password'] != cleanPassword) {
        return 'Şifreniz hatalı. Lütfen kontrol edip tekrar deneyin.';
      }

      if (matchedAccount['isBanned'] == true) {
        _isBanned = true;
        _banReason = matchedAccount['banReason'] as String? ?? 'Oyun kurallarını ihlal';
        isBannedNotifier.value = true;
        banReasonNotifier.value = _banReason;
        return 'HESAP_BANLANDI: $_banReason';
      }

      _playerId = matchedAccount['uid'] as String?;
      _username = matchedAccount['username'] as String? ?? cleanIdentifier;
      _companyName = matchedAccount['companyName'] as String? ?? '$_username Holding';
      _role = matchedAccount['role'] as String? ?? (isAdmin ? 'admin' : 'user');
      _isGuest = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localPlayerIdKey, _playerId!);
      await prefs.setString(_localUsernameKey, _username!);
      await prefs.setString(_localCompanyNameKey, _companyName!);
      await prefs.setBool(_localIsGuestKey, false);

      await setPlayerOnlineStatus(isOnline: true);
      return null;
    }

    try {
      String targetEmail = cleanIdentifier;

      // Kullanıcı adı ile giriş yapılıyorsa önce e-postasını sorgula
      if (!cleanIdentifier.contains('@')) {
        final normalized = cleanIdentifier.toLowerCase();
        DocumentSnapshot<Map<String, dynamic>>? usernameDoc;
        try {
          usernameDoc = await _firestore!
              .collection('usernames')
              .doc(normalized)
              .get()
              .timeout(const Duration(seconds: 6));
        } catch (e) {
          debugPrint('FirebaseService: Firestore username çekilemedi (zaman aşımı veya ağ hatası): $e');
        }

        if (usernameDoc == null || !usernameDoc.exists) {
          // Yerel hesap havuzunda varsa yerelden buluta aktararak giriş yap
          final localAccounts = await getLocalAccounts();
          if (localAccounts.containsKey(normalized)) {
            final locAcc = localAccounts[normalized]!;
            if (locAcc['password'] == cleanPassword) {
              _playerId = locAcc['uid'] as String?;
              _username = locAcc['username'] as String? ?? cleanIdentifier;
              _companyName = locAcc['companyName'] as String? ?? '$_username Holding';
              _role = locAcc['role'] as String? ?? (isAdmin ? 'admin' : 'user');
              _isGuest = false;

              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_localPlayerIdKey, _playerId!);
              await prefs.setString(_localUsernameKey, _username!);
              await prefs.setString(_localCompanyNameKey, _companyName!);
              await prefs.setBool(_localIsGuestKey, false);

              // Bu yerel hesabı buluta da senkronize et (arkaplanda)
              try {
                final batch = _firestore!.batch();
                batch.set(_firestore!.collection('usernames').doc(normalized), {
                  'uid': _playerId,
                  'displayUsername': _username,
                  'email': locAcc['email'] ?? '',
                  'password': cleanPassword,
                  'authProvider': 'firestore_cloud',
                  'createdAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                batch.set(_firestore!.collection('players').doc(_playerId), {
                  'uid': _playerId,
                  'username': _username,
                  'username_lowercase': normalized,
                  'email': locAcc['email'] ?? '',
                  'password': cleanPassword,
                  'companyName': _companyName,
                  'role': _role,
                  'isBanned': false,
                  'authProvider': 'firestore_cloud',
                  'createdAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                await batch.commit().timeout(const Duration(seconds: 4));
              } catch (_) {}

              await setPlayerOnlineStatus(isOnline: true);
              return null;
            } else {
              return 'Şifreniz hatalı. Lütfen kontrol edip tekrar deneyin.';
            }
          }
          if (usernameDoc == null) {
            return 'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.';
          }
          return 'Bu kullanıcı adına ait bir hesap bulunamadı.';
        }

        // Firestore bulut hesabı kontrolü (Auth servisi kapalıyken oluşturulmuşsa)
        final uData = usernameDoc.data();
        if (uData != null && uData['password'] != null) {
          if (uData['password'] == cleanPassword) {
            final uid = uData['uid'] as String;
            _playerId = uid;
            _username = uData['displayUsername'] as String? ?? cleanIdentifier;
            _companyName = '$_username Holding';
            _role = isAdmin ? 'admin' : 'user';
            _isGuest = false;

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_localPlayerIdKey, _playerId!);
            await prefs.setString(_localUsernameKey, _username!);
            await prefs.setString(_localCompanyNameKey, _companyName!);
            await prefs.setBool(_localIsGuestKey, false);

            try {
              final pDoc = await _firestore!.collection('players').doc(uid).get().timeout(const Duration(seconds: 4));
              if (pDoc.exists && pDoc.data() != null) {
                final pData = pDoc.data()!;
                _companyName = pData['companyName'] as String? ?? _companyName;
                _role = pData['role'] as String? ?? _role;
                await prefs.setString(_localCompanyNameKey, _companyName!);
              }
            } catch (_) {}

            await setPlayerOnlineStatus(isOnline: true);
            return null; // Başarıyla giriş yapıldı!
          } else {
            return 'Şifreniz hatalı. Lütfen kontrol edip tekrar deneyin.';
          }
        }

        final emailFromDoc = usernameDoc.get('email') as String?;
        if (emailFromDoc == null || emailFromDoc.isEmpty) {
          return 'Kullanıcı hesabı doğrulanamadı.';
        }
        targetEmail = emailFromDoc;
      }

      final userCredential = await _auth!.signInWithEmailAndPassword(
        email: targetEmail,
        password: cleanPassword,
      ).timeout(const Duration(seconds: 8));

      final user = userCredential.user;
      if (user == null) {
        return 'Giriş yapılamadı.';
      }

      _playerId = user.uid;
      _isGuest = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localPlayerIdKey, _playerId!);
      await prefs.setBool(_localIsGuestKey, false);

      // Profil bilgilerini Firestore'dan çek
      try {
        final playerDoc = await _firestore!.collection('players').doc(user.uid).get().timeout(const Duration(seconds: 4));
        if (playerDoc.exists && playerDoc.data() != null) {
          final data = playerDoc.data()!;
          _username = data['username'] as String? ?? cleanIdentifier;
          _companyName = data['companyName'] as String? ?? '$_username Holding';
          await prefs.setString(_localUsernameKey, _username!);
          await prefs.setString(_localCompanyNameKey, _companyName!);

          if (data['isBanned'] == true) {
            _isBanned = true;
            _banReason = data['banReason'] as String? ?? 'Oyun kurallarını ihlal';
            isBannedNotifier.value = true;
            banReasonNotifier.value = _banReason;
            await _auth!.signOut().timeout(const Duration(seconds: 4));
            return 'HESAP_BANLANDI: $_banReason';
          }

          if (data['role'] != null) {
            _role = data['role'] as String;
          }
          if (isAdmin && _role != 'admin') {
            _role = 'admin';
            _firestore!.collection('players').doc(user.uid).set({'role': 'admin'}, SetOptions(merge: true));
          }
          _listenToBanStatus(user.uid);

          // Yerel hesap havuzuna da kaydet
          await saveLocalAccount({
            'uid': user.uid,
            'username': _username,
            'username_lowercase': (_username ?? '').toLowerCase(),
            'email': targetEmail,
            'password': cleanPassword,
            'companyName': _companyName,
            'role': _role,
            'isBanned': _isBanned,
            'createdAt': DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        debugPrint('FirebaseService: Profil çekilemedi: $e');
      }

      await setPlayerOnlineStatus(isOnline: true);
      return null; // Başarılı!
    } on TimeoutException {
      // Zaman aşımında yerel hesap havuzunu kontrol et
      final normalized = cleanIdentifier.toLowerCase();
      final localAccounts = await getLocalAccounts();
      if (localAccounts.containsKey(normalized)) {
        final locAcc = localAccounts[normalized]!;
        if (locAcc['password'] == cleanPassword) {
          _playerId = locAcc['uid'] as String?;
          _username = locAcc['username'] as String? ?? cleanIdentifier;
          _companyName = locAcc['companyName'] as String? ?? '$_username Holding';
          _role = locAcc['role'] as String? ?? (isAdmin ? 'admin' : 'user');
          _isGuest = false;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_localPlayerIdKey, _playerId!);
          await prefs.setString(_localUsernameKey, _username!);
          await prefs.setString(_localCompanyNameKey, _companyName!);
          await prefs.setBool(_localIsGuestKey, false);
          return null;
        } else {
          return 'Şifreniz hatalı. Lütfen kontrol edip tekrar deneyin.';
        }
      }
      return 'Sunucuya bağlanılamadı (Zaman aşımı). Lütfen internet bağlantınızı kontrol ediniz.';
    } on FirebaseAuthException catch (e) {
      final isConfigError = e.code == 'operation-not-allowed' ||
          e.code == 'configuration-not-found' ||
          (e.message != null && e.message!.contains('CONFIGURATION_NOT_FOUND'));

      if (isConfigError) {
        return 'Firebase Authentication ayarlarında E-posta/Şifre sağlayıcısı henüz etkinleştirilmemiş (CONFIGURATION_NOT_FOUND). Lütfen Firebase Console -> Authentication -> Sign-in method üzerinden etkinleştirin.';
      }

      switch (e.code) {
        case 'user-not-found':
          return 'Bu e-posta adresine ait bir hesap bulunamadı.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Şifreniz hatalı. Lütfen kontrol edip tekrar deneyin.';
        case 'invalid-email':
          return 'Geçersiz bir e-posta adresi biçimi.';
        case 'user-disabled':
          return 'Bu hesap devre dışı bırakılmıştır.';
        case 'too-many-requests':
          return 'Çok fazla başarısız deneme yapıldı. Lütfen biraz bekleyin.';
        case 'operation-not-allowed':
          return 'Firebase Authentication ayarlarında E-posta/Şifre sağlayıcısı henüz etkinleştirilmemiş. Lütfen Firebase Console üzerinden etkinleştirin.';
        default:
          return e.message ?? 'Giriş yapılamadı (${e.code}).';
      }
    } catch (e) {
      return 'Giriş sırasında hata oluştu: $e';
    }
  }

  /// Misafir oyuncu olarak oturum açmadan devam etme
  Future<void> continueAsGuest() async {
    _isGuest = true;
    _username = 'Misafir Oyuncu';
    _companyName = 'Misafir Holding';
    _playerId ??= 'ply_guest_${DateTime.now().millisecondsSinceEpoch}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_localIsGuestKey, true);
    await prefs.setString(_localPlayerIdKey, _playerId!);
    await prefs.setString(_localUsernameKey, _username!);
    await prefs.setString(_localCompanyNameKey, _companyName!);
    await setPlayerOnlineStatus(isOnline: true);
  }

  /// Çıkış yapma
  Future<void> signOut() async {
    await setPlayerOnlineStatus(isOnline: false);
    _banSubscription?.cancel();
    _isBanned = false;
    _banReason = null;
    _role = 'user';
    isBannedNotifier.value = false;
    banReasonNotifier.value = null;

    try {
      await _auth?.signOut();
    } catch (e) {
      debugPrint('FirebaseService: signOut hatası: $e');
    }
    _isGuest = false;
    _username = null;
    _companyName = null;
    _playerId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localIsGuestKey);
    await prefs.remove(_localUsernameKey);
    await prefs.remove(_localCompanyNameKey);
    await prefs.remove(_localPlayerIdKey);
  }

  // ==========================================
  // BULUT DENETİM VE İŞLEM LOGLARI (AUDIT LOGS)
  // ==========================================
  /// Oyuncunun yaptığı her işlemi (alım, satım, kredi, giriş) Firestore'a kaydeder
  Future<void> writeAuditLog(AuditLog log) async {
    if (!isCloudConnected) return;

    try {
      final logData = log.toFirestore();
      final batch = _firestore!.batch();

      // 1. Oyuncunun kendi alt koleksiyonu: players/{uid}/activity_logs/{logId}
      final playerLogRef = _firestore!
          .collection('players')
          .doc(playerId)
          .collection('activity_logs')
          .doc(log.id);
      batch.set(playerLogRef, logData);

      // 2. Global denetim koleksiyonu (bütün oyuncuların logları burada toplanır): audit_logs/{logId}
      final globalLogRef = _firestore!.collection('audit_logs').doc(log.id);
      batch.set(globalLogRef, logData);

      await batch.commit();
      debugPrint('FirebaseService: İşlem logu Firestore\'a başarıyla yazıldı (${log.action})');
    } catch (e) {
      debugPrint('FirebaseService: Denetim logu buluta kaydedilemedi: $e');
    }
  }

  // ==========================================
  // YÖNETİCİ (ADMIN) & ANTI-CHEAT PANEL METOTLARI
  // ==========================================

  /// Oyuncunun çevrimiçi / çevrimdışı durumunu günceller
  Future<void> setPlayerOnlineStatus({required bool isOnline}) async {
    final pid = playerId;
    if (pid.isEmpty) return;

    final nowIso = DateTime.now().toIso8601String();

    // 1. Yerel hesap havuzunda güncelle
    try {
      final localAccounts = await getLocalAccounts();
      for (var acc in localAccounts.values) {
        if (acc['uid'] == pid) {
          acc['isOnline'] = isOnline;
          acc['lastActiveAt'] = nowIso;
          await saveLocalAccount(acc);
          break;
        }
      }
    } catch (e) {
      debugPrint('FirebaseService: setPlayerOnlineStatus yerel hata: $e');
    }

    // 2. Cloud Firestore'da güncelle
    if (isCloudConnected && _firestore != null) {
      try {
        await _firestore!.collection('players').doc(pid).set({
          'isOnline': isOnline,
          'lastActiveAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('FirebaseService: setPlayerOnlineStatus bulut hata: $e');
      }
    }
  }

  /// Cihazdaki belirli bir oyuncunun yerel loglarını okur
  Future<List<AuditLog>> getLocalAuditLogsForPlayer(String targetUid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'piyasa_audit_logs_v2_$targetUid';
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
        return list;
      }
    } catch (e) {
      debugPrint('FirebaseService: getLocalAuditLogsForPlayer error: $e');
    }
    return [];
  }

  /// Cihazdaki tüm yerel oyuncuların loglarını birleştirip getirir
  Future<List<AuditLog>> getAllLocalAuditLogs() async {
    final Map<String, AuditLog> map = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('piyasa_audit_logs_v2_'));
      for (final k in keys) {
        final raw = prefs.getString(k);
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw) as List;
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final log = AuditLog.fromJson(item);
              map[log.id] = log;
            } else if (item is Map) {
              final log = AuditLog.fromJson(Map<String, dynamic>.from(item));
              map[log.id] = log;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('FirebaseService: getAllLocalAuditLogs error: $e');
    }
    final list = map.values.toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  /// Sistemdeki tüm oyuncuları anlık olarak dinler
  Stream<List<Map<String, dynamic>>> streamAllPlayers() {
    if (!isCloudConnected || _firestore == null) {
      return Stream.fromFuture(getLocalAccounts()).map((accounts) {
        if (accounts.isEmpty) {
          return [
            {
              'uid': playerId,
              'username': username ?? 'COSSKUN',
              'email': email ?? adminEmail,
              'companyName': companyName,
              'cash': 10000.0,
              'netWorth': 10000.0,
              'level': 1,
              'isBanned': false,
              'isOnline': true,
              'lastActiveAt': DateTime.now().toIso8601String(),
              'role': isAdmin ? 'admin' : 'user',
            }
          ];
        }
        return accounts.values.toList();
      }).asBroadcastStream();
    }

    return _firestore!
        .collection('players')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['uid'] = doc.id;
              return data;
            }).toList());
  }

  /// Belirtilen oyuncunun tüm işlem defteri loglarını hem yerel hem buluttan birleştirerek dinler
  Stream<List<AuditLog>> streamPlayerAuditLogs(String targetUid) {
    if (!isCloudConnected || _firestore == null) {
      return Stream.fromFuture(getLocalAuditLogsForPlayer(targetUid)).asBroadcastStream();
    }

    return _firestore!
        .collection('players')
        .doc(targetUid)
        .collection('activity_logs')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .asyncMap((snapshot) async {
      final cloudLogs = snapshot.docs.map((doc) => AuditLog.fromJson(doc.data())).toList();
      final localLogs = await getLocalAuditLogsForPlayer(targetUid);
      final Map<String, AuditLog> combined = {};
      for (var l in cloudLogs) {
        combined[l.id] = l;
      }
      for (var l in localLogs) {
        combined[l.id] = l;
      }
      final result = combined.values.toList();
      result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return result;
    });
  }

  /// Tüm sunucudaki global denetim loglarını yerel ve bulut kaynaklarından birleştirerek dinler
  Stream<List<AuditLog>> streamGlobalAuditLogs({int limit = 100}) {
    if (!isCloudConnected || _firestore == null) {
      return Stream.fromFuture(getAllLocalAuditLogs()).asBroadcastStream();
    }

    return _firestore!
        .collection('audit_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
      final cloudLogs = snapshot.docs.map((doc) => AuditLog.fromJson(doc.data())).toList();
      final localLogs = await getAllLocalAuditLogs();
      final Map<String, AuditLog> combined = {};
      for (var l in cloudLogs) {
        combined[l.id] = l;
      }
      for (var l in localLogs) {
        combined[l.id] = l;
      }
      final result = combined.values.toList();
      result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return result.take(limit).toList();
    });
  }

  /// Oyuncu hesabını banlar ve pazardaki açık ilanlarını otomatik iptal eder
  Future<String?> banPlayer({required String targetUid, required String reason}) async {
    if (!isAdmin) return 'Bu işlem için yönetici yetkiniz bulunmamaktadır.';
    final cleanReason = reason.trim().isEmpty ? 'Oyun kurallarına aykırı hareket ve hile tespiti' : reason.trim();

    // Yerel hesap havuzunda güncelle
    final localAccounts = await getLocalAccounts();
    for (var acc in localAccounts.values) {
      if (acc['uid'] == targetUid) {
        acc['isBanned'] = true;
        acc['banReason'] = cleanReason;
        await saveLocalAccount(acc);
        break;
      }
    }

    if (!isCloudConnected || _firestore == null) return null;

    try {
      await _firestore!.collection('players').doc(targetUid).set({
        'isBanned': true,
        'banReason': cleanReason,
        'bannedAt': FieldValue.serverTimestamp(),
        'bannedBy': username ?? email ?? 'Admin',
      }, SetOptions(merge: true));

      // Pazardaki açık ilanlarını kapat
      final openListings = await _firestore!
          .collection('market_listings')
          .where('sellerId', isEqualTo: targetUid)
          .where('isCompleted', isEqualTo: false)
          .get();

      if (openListings.docs.isNotEmpty) {
        final batch = _firestore!.batch();
        for (final doc in openListings.docs) {
          batch.update(doc.reference, {'isCompleted': true, 'cancelledByAdmin': true});
        }
        await batch.commit();
      }

      // Denetim loguna ban işlemini yaz
      await writeAuditLog(AuditLog(
        id: 'ban_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        playerId: targetUid,
        username: 'Admin ($username)',
        category: LogCategory.auth,
        action: 'ADMIN_BAN_PLAYER',
        title: 'Oyuncu Hesabı Banlandı',
        description: 'Oyuncu hesabı askıya alındı. Sebep: $cleanReason',
        amountChange: 0,
        cashAfter: 0,
        details: {'targetUid': targetUid, 'reason': cleanReason},
      ));

      return null;
    } catch (e) {
      return 'Banlama hatası: $e';
    }
  }

  /// Banlı oyuncunun banını kaldırır
  Future<String?> unbanPlayer({required String targetUid}) async {
    if (!isAdmin) return 'Bu işlem için yönetici yetkiniz bulunmamaktadır.';

    // Yerel hesap havuzunda güncelle
    final localAccounts = await getLocalAccounts();
    for (var acc in localAccounts.values) {
      if (acc['uid'] == targetUid) {
        acc['isBanned'] = false;
        acc.remove('banReason');
        await saveLocalAccount(acc);
        break;
      }
    }

    if (!isCloudConnected || _firestore == null) return null;

    try {
      await _firestore!.collection('players').doc(targetUid).update({
        'isBanned': false,
        'banReason': FieldValue.delete(),
        'unbannedAt': FieldValue.serverTimestamp(),
        'unbannedBy': username ?? email ?? 'Admin',
      });

      await writeAuditLog(AuditLog(
        id: 'unban_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        playerId: targetUid,
        username: 'Admin ($username)',
        category: LogCategory.auth,
        action: 'ADMIN_UNBAN_PLAYER',
        title: 'Oyuncu Banı Kaldırıldı',
        description: 'Oyuncu hesabı tekrar aktif edildi.',
        amountChange: 0,
        cashAfter: 0,
        details: {'targetUid': targetUid},
      ));

      return null;
    } catch (e) {
      return 'Ban kaldırma hatası: $e';
    }
  }

  /// Oyuncuyu hem yerelden hem buluttan kalıcı olarak siler
  Future<String?> deletePlayer({required String targetUid}) async {
    try {
      // 1. Yerel hesap havuzundan sil
      final localAccounts = await getLocalAccounts();
      String? keyToRemove;
      for (final entry in localAccounts.entries) {
        if (entry.value['uid'] == targetUid) {
          keyToRemove = entry.key;
          break;
        }
      }
      if (keyToRemove != null) {
        localAccounts.remove(keyToRemove);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_localAccountsKey, jsonEncode(localAccounts));
      }

      // 2. Cloud Firestore'dan sil
      if (isCloudConnected && _firestore != null) {
        // İlgili oyuncunun açık pazar ilanlarını sil
        final openListings = await _firestore!
            .collection('market_listings')
            .where('sellerId', isEqualTo: targetUid)
            .get();
        if (openListings.docs.isNotEmpty) {
          final batch = _firestore!.batch();
          for (final doc in openListings.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }

        // Oyuncu dokümanını sil
        await _firestore!.collection('players').doc(targetUid).delete();

        // Denetim loguna yaz
        await writeAuditLog(AuditLog(
          id: 'del_${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          playerId: targetUid,
          username: 'Admin ($username)',
          category: LogCategory.auth,
          action: 'ADMIN_DELETE_PLAYER',
          title: 'Oyuncu Hesabı Silindi',
          description: 'Oyuncu hesabı veritabanından kalıcı olarak silindi.',
          amountChange: 0,
          cashAfter: 0,
          details: {'targetUid': targetUid},
        ));
      }

      return null;
    } catch (e) {
      return 'Oyuncu silme hatası: $e';
    }
  }

  /// Bilinmeyen, misafir veya bot oyuncu kayıtlarını yerelden ve bulut veritabanından temizler
  Future<int> cleanupUnknownPlayers() async {
    int deletedCount = 0;

    // 1. Yerel hesap havuzunu temizle
    try {
      final localAccounts = await getLocalAccounts();
      final keysToRemove = <String>[];
      for (final entry in localAccounts.entries) {
        final acc = entry.value;
        final uname = acc['username']?.toString().trim();
        final uid = acc['uid']?.toString() ?? '';
        final isNpc = acc['isNpc'] == true;
        if (uname == null ||
            uname.isEmpty ||
            uname == 'Bilinmeyen Oyuncu' ||
            uname == 'Misafir Oyuncu' ||
            isNpc ||
            uid.startsWith('ply_guest_') ||
            uid.startsWith('npc_')) {
          keysToRemove.add(entry.key);
        }
      }
      if (keysToRemove.isNotEmpty) {
        for (final k in keysToRemove) {
          localAccounts.remove(k);
          deletedCount++;
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_localAccountsKey, jsonEncode(localAccounts));
      }
    } catch (e) {
      debugPrint('FirebaseService: Yerel bilinmeyen oyuncuları temizleme hatası: $e');
    }

    // 2. Cloud Firestore'daki bilinmeyen / geçersiz kayıtları temizle
    if (isCloudConnected && _firestore != null) {
      try {
        final snapshot = await _firestore!.collection('players').get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final uname = data['username']?.toString().trim();
          final isNpc = data['isNpc'] == true;
          final uid = doc.id;
          if (uname == null ||
              uname.isEmpty ||
              uname == 'Bilinmeyen Oyuncu' ||
              uname == 'Misafir Oyuncu' ||
              isNpc ||
              uid.startsWith('ply_guest_') ||
              uid.startsWith('npc_')) {
            await doc.reference.delete();
            deletedCount++;
          }
        }
      } catch (e) {
        debugPrint('FirebaseService: Bulut bilinmeyen oyuncuları temizleme hatası: $e');
      }
    }

    return deletedCount;
  }
}
