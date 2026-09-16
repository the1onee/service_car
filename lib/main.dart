import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:barrr/app.dart';
import 'package:barrr/demo/demo_mode.dart';
import 'package:barrr/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = DemoMode.enabled;
  if (!DemoMode.enabled) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      firebaseReady = true;
    } catch (e) {
      debugPrint('Firebase init failed: $e');
    }
  }
  runApp(FanniApp(firebaseReady: firebaseReady));
}
