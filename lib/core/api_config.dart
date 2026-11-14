import 'package:barrr/core/app_environment.dart';

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

  /// إنتاج دائماً إلا إذا مُرر `--dart-define=BARRR_API_BASE=...`.
  /// الهاتف الحقيقي لا يصل إلى 10.0.2.2 (ذلك عنوان محاكي أندرويد فقط).
  static String get baseUrl {
    final env = _fromEnv.trim();
    if (AppEnvironmentConfig.isStaging && env.isEmpty) {
      throw StateError(
        'Staging requires an explicit BARRR_API_BASE. '
        'No production fallback is allowed.',
      );
    }
    final value =
        (env.isNotEmpty ? env : productionBase).replaceAll(RegExp(r'/+$'), '');
    AppEnvironmentConfig.validateApiBase(value);
    return value;
  }

  static Uri uri(String path) {
    final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p');
  }
}
