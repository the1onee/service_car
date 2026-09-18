import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:barrr/services/user_repository.dart';

class FcmService {
  FcmService(this._users);

  final UserRepository _users;

  Future<void> init(String uid) async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) {
        await _users.updateFcm(uid, token);
      }
      messaging.onTokenRefresh.listen((t) => _users.updateFcm(uid, t));
    } catch (_) {}
  }
}
