import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// هوية التطبيق — عدّل [assets/branding/brand.env] والشعار [assets/branding/logo.png]
/// دون تغيير كود Dart (أعد البناء بعد التعديل).
class AppBrand {
  AppBrand._();

  static const _defaultAppName = 'البطريق';
  static const _defaultTagline = 'خدمات سيارات موثوقة تصل إليك في أي مكان';
  static const _defaultLogoAsset = 'assets/branding/logo.png';
  static const _defaultSupportPhone = '07739601771';
  static const _defaultSupportEmail = 'mohammedabdullahyousef21@gmail.com';
  static const _defaultAboutBlurb =
      'البطريق يربطك بفنيين وورش موثوقين: صيانة، قطع، زيوت، غسيل، وسطحة — '
      'مع تتبع الطلب والدفع نقداً بينك وبين مقدّم الخدمة.';

  static String _env(String key, String fallback) {
    if (!dotenv.isInitialized) return fallback;
    final v = dotenv.env[key]?.trim();
    if (v == null || v.isEmpty) return fallback;
    return v;
  }

  /// رقم البناء (`+N` في pubspec) — يُقارن بـ `minAppBuild` لإجبار التحديث.
  static int buildNumber = 0;

  /// يُستدعى من [main] قبل [runApp].
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: 'assets/branding/brand.env');
    } catch (_) {
      // بدون الملف تبقى القيم الافتراضية أدناه.
    }
    try {
      final info = await PackageInfo.fromPlatform();
      buildNumber = int.tryParse(info.buildNumber) ?? 0;
    } catch (_) {}
  }

  static String get appName => _env('APP_NAME', _defaultAppName);

  static String get tagline => _env('TAGLINE', _defaultTagline);

  static String get logoAsset => _env('LOGO_ASSET', _defaultLogoAsset);

  static String get supportPhone => _env('SUPPORT_PHONE', _defaultSupportPhone);

  static String get aboutBlurb => _env('ABOUT_BLURB', _defaultAboutBlurb);

  static String get supportEmail => _env('SUPPORT_EMAIL', _defaultSupportEmail);
}
