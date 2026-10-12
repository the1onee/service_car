import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:barrr/app.dart';
import 'package:barrr/core/app_brand.dart';
import 'package:barrr/core/app_error_widget.dart';
import 'package:barrr/core/user_error.dart';
import 'package:barrr/features/shell/auth_gate.dart';
import 'package:barrr/firebase_options.dart';
import 'package:barrr/services/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installGlobalErrorHandlers();
  configureProductionErrorPresentation();
  await AppBrand.load();
  runApp(const _BootApp());
}

void _installGlobalErrorHandlers() {
  FlutterError.onError = (details) {
    logUserError(details.exception, details.stack, 'flutter');
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    logUserError(error, stack, 'platform');
    return true;
  };
}

/// أول إطار فوراً، ثم تهيئة Firebase بعيداً عن الشاشة الفارغة.
class _BootApp extends StatefulWidget {
  const _BootApp();

  @override
  State<_BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<_BootApp> {
  bool? _firebaseReady;
  var _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFirebase());
  }

  Future<void> _initFirebase() async {
    if (_started) return;
    _started = true;
    var firebaseReady = false;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      }
      firebaseReady = true;
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        firebaseReady = true;
      } else {
        logUserError(e, null, 'firebase_init');
      }
    } catch (e, st) {
      logUserError(e, st, 'firebase_init');
    }
    if (!mounted) return;
    setState(() => _firebaseReady = firebaseReady);
  }

  @override
  Widget build(BuildContext context) {
    final ready = _firebaseReady;
    if (ready == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BrandSplash(),
      );
    }
    return FanniApp(firebaseReady: ready);
  }
}
