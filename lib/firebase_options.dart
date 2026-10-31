import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration for each platform this app runs on.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDUfTlfYMVAjG_VIiV2rD6QMy44lul1A8w',
    appId: '1:379921787569:web:756adb94056b7b80a21090',
    messagingSenderId: '379921787569',
    projectId: 'busapp-2437e',
    authDomain: 'busapp-2437e.firebaseapp.com',
    storageBucket: 'busapp-2437e.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDlMgJrI1-Wdz51XG4pk40neu533ImzAO8',
    appId: '1:379921787569:android:69cbe37931f2020ea21090',
    messagingSenderId: '379921787569',
    projectId: 'busapp-2437e',
    storageBucket: 'busapp-2437e.firebasestorage.app',
  );
}
