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

  /// iOS için Firebase yapılandırması
  /// NOT: Firebase Console'da iOS uygulaması eklendiğinde üretilen iOS App ID buraya yazılır.
  /// Geçerli bir iOS App ID olmadan Firebase iOS SDK native NSException fırlatıp uygulamanın çökmesine yol açar.
  static const FirebaseOptions? ios = null;

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
