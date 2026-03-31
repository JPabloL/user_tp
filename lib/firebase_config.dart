import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  // Equivalente a environment.firebase de Ionic/Angular.
  // Nota: este appId corresponde al registro web.
  // Para producción móvil conviene usar flutterfire configure
  // para obtener appId específico de Android/iOS.
  static const FirebaseOptions options = FirebaseOptions(
    apiKey: 'AIzaSyA3JW74IM8sdaj0KKvqP2sqZYqXkqKu0EU',
    appId: '1:1048381349716:web:4508eb9dd36d532241b2c1',
    messagingSenderId: '1048381349716',
    projectId: 'tochito-pro',
    authDomain: 'tochito-pro.firebaseapp.com',
    storageBucket: 'tochito-pro.firebasestorage.app',
    measurementId: 'G-5D7Q750X5M',
  );
}
