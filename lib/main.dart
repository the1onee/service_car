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

var _messagingHandlerBound = false;

void _installGlobalErrorHandlers() {
  FlutterError.onError = (details) {
    logUserError(details.exception, details.stack, 'flutter');
    final msg = details.exceptionAsString();
    if (msg.contains('ListTile background color or ink splashes may be invisible')) {
      return;
    }
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
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFirebase());
  }

  Future<void> _initFirebase() async {
    if (_busy) return;
    _busy = true;
    if (mounted) setState(() => _firebaseReady = null);

    var firebaseReady = false;
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        firebaseReady = true;
        break;
      } on FirebaseException catch (e) {
        if (e.code == 'duplicate-app') {
          firebaseReady = true;
          break;
        }
        lastError = e;
        logUserError(e, null, 'firebase_init');
      } catch (e, st) {
        lastError = e;
        logUserError(e, st, 'firebase_init');
      }
      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }

    if (firebaseReady && !kIsWeb) {
      try {
        if (!_messagingHandlerBound) {
          FirebaseMessaging.onBackgroundMessage(
            firebaseMessagingBackgroundHandler,
          );
          _messagingHandlerBound = true;
        }
      } catch (e, st) {
        logUserError(e, st, 'firebase_addons');
      }
    } else if (lastError != null) {
      logUserError(lastError, null, 'firebase_init_exhausted');
    }

    _busy = false;
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
    return FanniApp(
      firebaseReady: ready,
      onRetryFirebase: _initFirebase,
    );
  }
}
