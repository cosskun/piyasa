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

  static const String _localPlayerIdKey = 'piyasa_player_unique_id';
  static const String _localCompanyNameKey = 'piyasa_player_company_name';
  static const String _localUsernameKey = 'piyasa_player_username';
  static const String _localIsGuestKey = 'piyasa_is_guest';
  static const String _localOfflineSalesKey = 'piyasa_unclaimed_market_sales';

  bool get isCloudConnected => _initialized && FirebaseConfig.isConfigured && _firestore != null;
  String get playerId => _playerId ?? 'player_guest';
  String get companyName => _companyName ?? 'Piyasa Holding';
  String? get username => _username;
  bool get isLoggedIn => _auth?.currentUser != null;
  bool get isGuest => _isGuest;
  bool get isAuthenticated => isLoggedIn || _isGuest;
  String? get email => _auth?.currentUser?.email;

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
    if (FirebaseConfig.isConfigured) {
      try {
        await Firebase.initializeApp(options: FirebaseConfig.currentPlatform);
        _firestore = FirebaseFirestore.instance;
        _auth = FirebaseAuth.instance;
        _initialized = true;

        // Kullanıcı önceden oturum açmış mı kontrol et
        if (_auth!.currentUser != null) {
          _playerId = _auth!.currentUser!.uid;
          await prefs.setString(_localPlayerIdKey, _playerId!);

          // Kullanıcı profilini Firestore'dan çek
          try {
            final playerDoc = await _firestore!.collection('players').doc(_playerId).get();
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
            }
          } catch (e) {
            debugPrint('FirebaseService: Oyuncu profili çekilemedi: $e');
          }
        }
        debugPrint('FirebaseService: Bulut bağlantısı başarıyla kuruldu! (UID: $_playerId, LoggedIn: $isLoggedIn)');
      } catch (e) {
        debugPrint('FirebaseService: Bulut başlatma hatası, yerel modda devam ediliyor: $e');
        _initialized = false;
      }
    } else {
      debugPrint('FirebaseService: Yapılandırma anahtarları henüz girilmedi, yerel + simüle mod devrede.');
      _initialized = false;
    }
  }

  // ==========================================
  // OYUNCU MAL VARLIĞI BULUT SENKRONİZASYONU
  // ==========================================
  Future<void> syncPlayerAssetsToCloud(Map<String, dynamic> assetData) async {
    if (!isCloudConnected) return;

    try {
      final docRef = _firestore!.collection('players').doc(playerId);
      assetData['updatedAt'] = FieldValue.serverTimestamp();
      assetData['companyName'] = companyName;
      await docRef.set(assetData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirebaseService: Mal varlığı buluta kaydedilemedi: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchPlayerAssetsFromCloud() async {
    if (!isCloudConnected) return null;

    try {
      final docRef = _firestore!.collection('players').doc(playerId);
      final snapshot = await docRef.get();
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

      final snapshot = await salesRef.get();
      final sales = <Map<String, dynamic>>[];

      final batch = _firestore!.batch();
      for (var doc in snapshot.docs) {
        sales.add(doc.data());
        batch.update(doc.reference, {'isClaimed': true});
      }
      await batch.commit();

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

  /// Kullanıcı adının daha önce alınıp alınmadığını kontrol eder (Case-insensitive)
  Future<bool> isUsernameAvailable(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean.length < 3 || clean.length > 20) return false;
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(clean)) return false;

    if (!isCloudConnected) return true;

    try {
      final doc = await _firestore!.collection('usernames').doc(clean).get();
      return !doc.exists;
    } catch (e) {
      debugPrint('FirebaseService: Kullanıcı adı kontrol hatası: $e');
      return true;
    }
  }

  /// Benzersiz kullanıcı adı ve e-posta ile yeni oyuncu hesabı oluşturur
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

    if (cleanPassword.length < 6) {
      return 'Şifreniz en az 6 karakterden oluşmalıdır.';
    }

    final effectiveCompanyName = (companyName != null && companyName.trim().isNotEmpty)
        ? companyName.trim()
        : '$cleanUsername Holding';

    if (!isCloudConnected) {
      final prefs = await SharedPreferences.getInstance();
      _username = cleanUsername;
      _companyName = effectiveCompanyName;
      _isGuest = false;
      await prefs.setString(_localUsernameKey, _username!);
      await prefs.setString(_localCompanyNameKey, _companyName!);
      await prefs.setBool(_localIsGuestKey, false);
      return null;
    }

    try {
      // 1. Kullanıcı adının benzersizliğini kontrol et (Koleksiyon: usernames/{username_lowercase})
      final usernameDoc = await _firestore!.collection('usernames').doc(normalizedUsername).get();
      if (usernameDoc.exists) {
        return 'Bu kullanıcı adı zaten kullanımda. Lütfen başka bir kullanıcı adı seçin.';
      }

      // 2. Firebase Auth ile kayıt oluştur (E-posta benzersizliği Firebase tarafından otomatik denetlenir)
      final userCredential = await _auth!.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: cleanPassword,
      );

      final user = userCredential.user;
      if (user == null) {
        return 'Kayıt sırasında bir hata oluştu. Lütfen tekrar deneyin.';
      }

      _playerId = user.uid;
      _username = cleanUsername;
      _companyName = effectiveCompanyName;
      _isGuest = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localPlayerIdKey, _playerId!);
      await prefs.setString(_localUsernameKey, _username!);
      await prefs.setString(_localCompanyNameKey, _companyName!);
      await prefs.setBool(_localIsGuestKey, false);

      // 3. Kullanıcı adını rezerve et ve oyuncu profilini Firestore'a kaydet
      final batch = _firestore!.batch();
      batch.set(_firestore!.collection('usernames').doc(normalizedUsername), {
        'uid': user.uid,
        'displayUsername': cleanUsername,
        'email': cleanEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(_firestore!.collection('players').doc(user.uid), {
        'uid': user.uid,
        'username': cleanUsername,
        'username_lowercase': normalizedUsername,
        'email': cleanEmail,
        'companyName': effectiveCompanyName,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
      return null; // Başarılı!
    } on FirebaseAuthException catch (e) {
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
      final prefs = await SharedPreferences.getInstance();
      _username = cleanIdentifier;
      _companyName = '$_username Holding';
      _isGuest = false;
      await prefs.setString(_localUsernameKey, _username!);
      await prefs.setString(_localCompanyNameKey, _companyName!);
      await prefs.setBool(_localIsGuestKey, false);
      return null;
    }

    try {
      String targetEmail = cleanIdentifier;

      // Kullanıcı adı ile giriş yapılıyorsa önce e-postasını sorgula
      if (!cleanIdentifier.contains('@')) {
        final normalized = cleanIdentifier.toLowerCase();
        final usernameDoc = await _firestore!.collection('usernames').doc(normalized).get();
        if (!usernameDoc.exists) {
          return 'Bu kullanıcı adına ait bir hesap bulunamadı.';
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
      );

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
        final playerDoc = await _firestore!.collection('players').doc(user.uid).get();
        if (playerDoc.exists && playerDoc.data() != null) {
          final data = playerDoc.data()!;
          _username = data['username'] as String? ?? cleanIdentifier;
          _companyName = data['companyName'] as String? ?? '$_username Holding';
          await prefs.setString(_localUsernameKey, _username!);
          await prefs.setString(_localCompanyNameKey, _companyName!);
        }
      } catch (e) {
        debugPrint('FirebaseService: Profil çekilemedi: $e');
      }

      return null; // Başarılı!
    } on FirebaseAuthException catch (e) {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_localIsGuestKey, true);
  }

  /// Çıkış yapma
  Future<void> signOut() async {
    try {
      await _auth?.signOut();
    } catch (e) {
      debugPrint('FirebaseService: signOut hatası: $e');
    }
    _isGuest = false;
    _username = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localIsGuestKey);
    await prefs.remove(_localUsernameKey);
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
}
