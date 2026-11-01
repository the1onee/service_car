// Firebase options for the isolated car-services-iraq-staging project.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class StagingFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS || TargetPlatform.macOS => ios,
      TargetPlatform.windows => web,
      TargetPlatform.linux => throw UnsupportedError(
          'Staging Firebase is not configured for Linux.',
        ),
      _ => throw UnsupportedError(
          'Staging Firebase is not supported on this platform.',
        ),
    };
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBcI_HE95NrlaGcBO2HnGEMkaPs9pbgBGY',
    appId: '1:747129120691:web:c2b9fa6c83c9dd1e3dcdc6',
    messagingSenderId: '747129120691',
    projectId: 'car-services-iraq-staging',
    authDomain: 'car-services-iraq-staging.firebaseapp.com',
    storageBucket: 'car-services-iraq-staging.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD-YRAXHT9I68janjnY1DGoDr9UUssEyqI',
    appId: '1:747129120691:android:bbc2fe86d2338e9c3dcdc6',
    messagingSenderId: '747129120691',
    projectId: 'car-services-iraq-staging',
    storageBucket: 'car-services-iraq-staging.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDY_gzr7YbESjWF6csuSKpoCtJTLBppUIE',
    appId: '1:747129120691:ios:22603cfd20dd96ba3dcdc6',
    messagingSenderId: '747129120691',
    projectId: 'car-services-iraq-staging',
    storageBucket: 'car-services-iraq-staging.firebasestorage.app',
    iosBundleId: 'com.albatariq.app.staging',
  );
}
