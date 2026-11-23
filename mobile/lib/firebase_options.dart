// Firebase configuration for the "SmartEvents" project (smartevents-4de9c),
// in the same shape `flutterfire configure` produces. These are public client
// identifiers that ship inside every Firebase app; access is governed by
// Firebase security rules, not by keeping them secret.
//
// Re-running `flutterfire configure` in mobile/ regenerates this file (and adds
// android/app/google-services.json and ios/Runner/GoogleService-Info.plist).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Firebase is set up for Android, iOS and web only.');
    }
  }

  static const String _apiKey = 'AIzaSyCIOLvt4ylz2Y8y-k8XkyEHVsyu7eS6gYk';
  static const String _projectId = 'smartevents-4de9c';
  static const String _senderId = '845923271811';
  static const String _bucket = 'smartevents-4de9c.firebasestorage.app';

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:845923271811:web:f9eb5ffb8d3104f13987b6',
    messagingSenderId: _senderId,
    projectId: _projectId,
    authDomain: 'smartevents-4de9c.firebaseapp.com',
    storageBucket: _bucket,
    measurementId: 'G-92YNVL4JQ2',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:845923271811:android:374280b322e19c113987b6',
    messagingSenderId: _senderId,
    projectId: _projectId,
    storageBucket: _bucket,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:845923271811:ios:7910f7aa30d82c9f3987b6',
    messagingSenderId: _senderId,
    projectId: _projectId,
    storageBucket: _bucket,
    iosBundleId: 'com.smartevents.smartevents',
  );
}
