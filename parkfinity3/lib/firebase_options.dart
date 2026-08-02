// Firebase config for ParkFinity (project: parkfinity-f8544).
// Hand-written from android/app/google-services.json — Android values only
// (the platform we ship push on). Other platforms fall through with a clear
// error rather than silently misconfiguring.
//
// Safe to commit: these are public client identifiers, not secrets. The FCM
// server credential lives only in the send-push edge function secret.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured for Firebase.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'FirebaseOptions are not configured for $defaultTargetPlatform. '
          'Run flutterfire configure to add this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDpCXq0PiWCqxFf98n4tfwTxa1zo32Qr0g',
    appId: '1:88683294038:android:ff72aff6ea4f644565baf7',
    messagingSenderId: '88683294038',
    projectId: 'parkfinity-f8544',
    storageBucket: 'parkfinity-f8544.firebasestorage.app',
  );
}
