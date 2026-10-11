import 'package:flutter/foundation.dart';

/// عنوان باكند الإشعارات ورمز واتساب على VPS (بدون Cloud Functions).
///
/// عند البناء/التشغيل للإنتاج:
/// ```
/// flutter run --dart-define=BARRR_API_BASE=https://api.your-domain.com
/// ```
class ApiConfig {
  ApiConfig._();

  static const _fromEnv = String.fromEnvironment('BARRR_API_BASE');

  /// إنتاج: https://albatariq.com — تجاوز عبر `--dart-define=BARRR_API_BASE=...`.
  static const productionBase = 'https://albatariq.com';

  /// أولوية: dart-define ثم إنتاج في release ثم محلي حسب المنصة.
  static String get baseUrl {
    final env = _fromEnv.trim();
    if (env.isNotEmpty) return env.replaceAll(RegExp(r'/+$'), '');
    if (kReleaseMode) return productionBase;
    // محاكي أندرويد يصل للمضيف عبر 10.0.2.2
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8787';
    }
    return 'http://127.0.0.1:8787';
  }

  static Uri uri(String path) {
    final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p');
  }
}
