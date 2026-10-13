import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// خدمة الصوتيات والمؤثرات الصوتية للتطبيق — تشغيل التنبيهات وقبول العروض.
class AppSoundService {
  AppSoundService._();

  static AudioPlayer? _player;
  static bool isEnabled = true;

  static AudioPlayer get _client => _player ??= AudioPlayer();

  /// تشغيل نغمة العرض (البطريق) عند استلام أو إرسال عرض جديد.
  static Future<void> playOfferPenguin() async {
    if (!isEnabled) return;
    try {
      final player = _client;
      await player.stop();
      await player.setAsset('assets/sounds/offer_penguin.wav');
      await player.play();
    } catch (e) {
      debugPrint('AppSoundService.playOfferPenguin error: $e');
    }
  }

  /// تشغيل صوت قبول العميل للعرض أو الطلب.
  static Future<void> playAcceptClient() async {
    if (!isEnabled) return;
    try {
      final player = _client;
      await player.stop();
      await player.setAsset('assets/sounds/accept_client.wav');
      await player.play();
    } catch (e) {
      debugPrint('AppSoundService.playAcceptClient error: $e');
    }
  }

  /// تنظيف وتحرير الموارد.
  static void dispose() {
    _player?.dispose();
    _player = null;
  }
}
