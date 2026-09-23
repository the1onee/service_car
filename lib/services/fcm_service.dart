import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:barrr/firebase_options.dart';
import 'package:barrr/services/user_repository.dart';

/// معالج الخلفية — يجب أن يكون دالة عليا ويُسجَّل قبل runApp.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class FcmService {
  FcmService(this._users, {this.messengerKey});

  final UserRepository _users;
  final GlobalKey<ScaffoldMessengerState>? messengerKey;

  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  var _listening = false;

  Future<void> init(String uid) async {
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _users.updateFcm(uid, token);
      }

      await _tokenSub?.cancel();
      _tokenSub = messaging.onTokenRefresh.listen((t) {
        if (t.isNotEmpty) _users.updateFcm(uid, t);
      });

      if (!_listening) {
        _listening = true;
        _foregroundSub = FirebaseMessaging.onMessage.listen(_showForeground);
        _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
        final initial = await messaging.getInitialMessage();
        if (initial != null) _onOpened(initial);
      }
    } catch (e, st) {
      debugPrint('FCM init failed: $e\n$st');
    }
  }

  void _showForeground(RemoteMessage message) {
    final title = message.notification?.title?.trim();
    final body = message.notification?.body?.trim();
    final text = [
      if (title != null && title.isNotEmpty) title,
      if (body != null && body.isNotEmpty) body,
    ].join('\n');
    if (text.isEmpty) return;

    final messenger = messengerKey?.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _onOpened(RemoteMessage message) {
    // الحمولة متاحة للتنقل لاحقاً (مثل jobId). حالياً يكفي العرض عند الفتح.
    debugPrint('FCM opened: ${message.messageId} data=${message.data}');
  }

  Future<void> dispose() async {
    await _tokenSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    _listening = false;
  }
}
