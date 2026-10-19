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
    if (env.isNotEmpty) return env.replaceAll(RegExp(r'/+$'), '');
    return productionBase;
  }

  static Uri uri(String path) {
    final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p');
  }
}
