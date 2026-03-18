import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AppFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    throw UnsupportedError(
      'AppFirebaseOptions are configured for web only in this project.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_WEB_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_WEB_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    measurementId: String.fromEnvironment('FIREBASE_MEASUREMENT_ID'),
  );
}
