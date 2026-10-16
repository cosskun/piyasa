import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  /// Firebase Console -> Proje Ayarları -> Coskun-apps / Piyasa
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: "AIzaSyAcf5Df0no_7rlKl6KnQA08twrhH-MYkTw",
    appId: "1:842382725401:android:d2ccdd47a7c386bbf33588",
    messagingSenderId: "842382725401",
    projectId: "coskun-apps",
    storageBucket: "coskun-apps.firebasestorage.app",
  );

  /// Firebase yapılandırmasının girilip girilmediğini kontrol eder
  static bool get isConfigured {
    return currentPlatform.apiKey != "YOUR_API_KEY" &&
        currentPlatform.projectId != "YOUR_PROJECT_ID";
  }
}
