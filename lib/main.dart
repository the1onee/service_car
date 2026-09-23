import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:barrr/app.dart';
import 'package:barrr/firebase_options.dart';
import 'package:barrr/services/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }
  runApp(FanniApp(firebaseReady: firebaseReady));
}
