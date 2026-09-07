import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  // Equivalente a environment.firebase de Ionic/Angular.
  // IMPORTANTE: appId actual es el de WEB. En Android/iOS FCM no funciona bien
  // hasta ejecutar `flutterfire configure` y usar firebase_options.dart.
  static const FirebaseOptions options = FirebaseOptions(
    apiKey: 'AIzaSyA3JW74IM8sdaj0KKvqP2sqZYqXkqKu0EU',
    appId: '1:1048381349716:web:4508eb9dd36d532241b2c1',
    messagingSenderId: '1048381349716',
    projectId: 'tochito-pro',
    authDomain: 'tochito-pro.firebaseapp.com',
    storageBucket: 'tochito-pro.firebasestorage.app',
    measurementId: 'G-5D7Q750X5M',
  );

  /// Web puede usar el appId anterior; móvil requiere appId android/ios en Firebase.
  static bool get isConfiguredForCurrentPlatform {
    if (kIsWeb) return true;
    return !options.appId.contains(':web:');
  }
}
