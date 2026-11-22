// Generado por `flutterfire configure` (proyecto fittrack360-98c44).
// ignore_for_file: lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opciones Firebase por plataforma (Android, iOS, Web).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Plataforma no soportada para Firebase en FitTrack360.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDqOMDV3QxmO62yG6LfPJGWddRwsw8NoDE',
    appId: '1:789152481670:android:1d8ae95f891d6de9adac07',
    messagingSenderId: '789152481670',
    projectId: 'fittrack360-98c44',
    storageBucket: 'fittrack360-98c44.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAAW_L9q7ZpiJq454BDr5VxxVwGQTuvg2E',
    appId: '1:789152481670:ios:eeae26eecab50364adac07',
    messagingSenderId: '789152481670',
    projectId: 'fittrack360-98c44',
    storageBucket: 'fittrack360-98c44.firebasestorage.app',
    iosBundleId: 'com.example.fitTrack360',
    iosClientId:
        '789152481670-66iaj9seukv91d1d8dc8c5p11c46jk26.apps.googleusercontent.com',
  );
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD_02t3ykq7FHBTlUAX13s0Jd_EdobLFbg',
    appId: '1:789152481670:web:7bdac4e29c2620d8adac07',
    messagingSenderId: '789152481670',
    projectId: 'fittrack360-98c44',
    authDomain: 'fittrack360-98c44.firebaseapp.com',
    storageBucket: 'fittrack360-98c44.firebasestorage.app',
  );
}
