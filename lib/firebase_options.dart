import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for the `who-fed-snoop` Firebase project.
abstract final class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBMbvfWi2yg_6IppjLZqqm-VorlSbF8rk0',
    appId: '1:960156022232:web:9cccb184c0b365005eeead',
    messagingSenderId: '960156022232',
    projectId: 'who-fed-snoop',
    authDomain: 'who-fed-snoop.firebaseapp.com',
    storageBucket: 'who-fed-snoop.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCdxQCk4TF0MkGwRsWuYvGoNjCGC6HRLII',
    appId: '1:960156022232:android:d14a58210ef15a575eeead',
    messagingSenderId: '960156022232',
    projectId: 'who-fed-snoop',
    storageBucket: 'who-fed-snoop.firebasestorage.app',
  );
}
