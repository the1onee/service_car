// File generated for project car-services-iraq.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
        return web;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC01_6BudF63GLe2myMax7io-OxWzNPcrs',
    appId: '1:500429219707:web:8b462a2849c3e20acdffde',
    messagingSenderId: '500429219707',
    projectId: 'car-services-iraq',
    authDomain: 'car-services-iraq.firebaseapp.com',
    storageBucket: 'car-services-iraq.firebasestorage.app',
    measurementId: 'G-G0C4S627DF',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD5gXhU8YdyPJvem0R7PKec463BXqToHdU',
    appId: '1:500429219707:android:ea9ef8f0500be088cdffde',
    messagingSenderId: '500429219707',
    projectId: 'car-services-iraq',
    storageBucket: 'car-services-iraq.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBtJv1B4RiGVcyEsLpusr1dgBplcke350Q',
    appId: '1:500429219707:ios:3eb1afce134a5a9ecdffde',
    messagingSenderId: '500429219707',
    projectId: 'car-services-iraq',
    storageBucket: 'car-services-iraq.firebasestorage.app',
    iosBundleId: 'com.barrr.barrr',
  );
}
