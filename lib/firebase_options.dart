import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError('רק Web נתמך כרגע');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD3T4M8MehRPnd5-BI71zn3AOo9ChhJmEE',
    appId: '1:897588072750:web:b0e7bd3edec76bedab2abf',
    messagingSenderId: '897588072750',
    projectId: 'gps-drivers-cc984',
    authDomain: 'gps-drivers-cc984.firebaseapp.com',
    storageBucket: 'gps-drivers-cc984.firebasestorage.app',
  );
}
