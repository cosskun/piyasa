import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  /// Android için Firebase yapılandırması (google-services.json'dan alınmıştır)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyAcf5Df0no_7rlKl6KnQA08twrhH-MYkTw",
    appId: "1:842382725401:android:d2ccdd47a7c386bbf33588",
    messagingSenderId: "842382725401",
    projectId: "coskun-apps",
    storageBucket: "coskun-apps.firebasestorage.app",
  );

  /// iOS için Firebase yapılandırması (GoogleService-Info.plist'ten alınmıştır)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyBJy8ya78M_ZArSwo35helvfUDa410oKqE",
    appId: "1:842382725401:ios:1448a8c03e5b1fd3f33588",
    messagingSenderId: "842382725401",
    projectId: "coskun-apps",
    storageBucket: "coskun-apps.firebasestorage.app",
    iosBundleId: "com.piyasa.piyasa",
  );

  /// Aktif platforma uygun FirebaseOptions seçimi
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return null;
    }
  }

  /// Aktif platform için geçerli yapılandırmanın olup olmadığını denetler
  static bool get isConfigured {
    final opts = currentPlatform;
    if (opts == null) return false;
    return opts.apiKey.isNotEmpty &&
        opts.projectId.isNotEmpty &&
        opts.appId.isNotEmpty;
  }
}
