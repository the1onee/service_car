// File generated for project car-services-iraq.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  /// Debug يتصل بـ car-services-iraq-staging. Release وProfile يبقيان على الإنتاج.
  static bool get useStaging => kDebugMode;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return useStaging ? stagingWeb : web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return useStaging ? stagingAndroid : android;
      case TargetPlatform.iOS:
        return useStaging ? stagingIos : ios;
      case TargetPlatform.macOS:
        return useStaging ? stagingIos : ios;
      case TargetPlatform.windows:
        return useStaging ? stagingWeb : web;
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
    appId: '1:500429219707:android:a0114f5317c107a0cdffde',
    messagingSenderId: '500429219707',
    projectId: 'car-services-iraq',
    storageBucket: 'car-services-iraq.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBtJv1B4RiGVcyEsLpusr1dgBplcke350Q',
    appId: '1:500429219707:ios:254fcdf740f46789cdffde',
    messagingSenderId: '500429219707',
    projectId: 'car-services-iraq',
    storageBucket: 'car-services-iraq.firebasestorage.app',
    iosBundleId: 'com.albatariq.app',
  );

  static const FirebaseOptions stagingWeb = FirebaseOptions(
    apiKey: 'AIzaSyBcI_HE95NrlaGcBO2HnGEMkaPs9pbgBGY',
    appId: '1:747129120691:web:c2b9fa6c83c9dd1e3dcdc6',
    messagingSenderId: '747129120691',
    projectId: 'car-services-iraq-staging',
    authDomain: 'car-services-iraq-staging.firebaseapp.com',
    storageBucket: 'car-services-iraq-staging.firebasestorage.app',
  );

  static const FirebaseOptions stagingAndroid = FirebaseOptions(
    apiKey: 'AIzaSyD-YRAXHT9I68janjnY1DGoDr9UUssEyqI',
    appId: '1:747129120691:android:33335397af7a73073dcdc6',
    messagingSenderId: '747129120691',
    projectId: 'car-services-iraq-staging',
    storageBucket: 'car-services-iraq-staging.firebasestorage.app',
  );

  static const FirebaseOptions stagingIos = FirebaseOptions(
    apiKey: 'AIzaSyDY_gzr7YbESjWF6csuSKpoCtJTLBppUIE',
    appId: '1:747129120691:ios:97e1765ea371490f3dcdc6',
    messagingSenderId: '747129120691',
    projectId: 'car-services-iraq-staging',
    storageBucket: 'car-services-iraq-staging.firebasestorage.app',
    iosBundleId: 'com.albatariq.app',
  );
}
