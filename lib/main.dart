import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:barrr/app.dart';
import 'package:barrr/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }
  runApp(FanniApp(firebaseReady: firebaseReady));
}
