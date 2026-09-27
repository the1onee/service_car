/// إعدادات Cloudinary للرفع من التطبيق.
///
/// **لا تضع أسراراً في المصدر.** مرّر القيم عند التشغيل/البناء:
/// ```
/// flutter run --dart-define=CLOUDINARY_CLOUD_NAME=xxx --dart-define=CLOUDINARY_UPLOAD_PRESET=barrr_unsigned
/// ```
/// أو اعتمد على دالة `getCloudinaryUploadSign` (رفع موقّع عبر Cloud Functions).
class CloudinaryConfig {
  CloudinaryConfig._();

  /// من Cloudinary Dashboard → Cloud name (عبر --dart-define فقط).
  static const cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: '',
  );

  /// Upload preset بوضع Unsigned (مثال الاسم: barrr_unsigned) عبر --dart-define فقط.
  static const uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: '',
  );

  static bool get isUnsignedConfigured =>
      cloudName.trim().isNotEmpty && uploadPreset.trim().isNotEmpty;

  /// للتوافق مع الاستدعاءات القديمة؛ يعني أن الرفع غير الموقّع جاهز.
  static bool get isConfigured => isUnsignedConfigured;

  static Uri uploadUri([String? cloud]) {
    final name = (cloud ?? cloudName).trim();
    if (name.isEmpty) {
      throw StateError(
        'Cloudinary غير مضبوط. مرّر CLOUDINARY_CLOUD_NAME و CLOUDINARY_UPLOAD_PRESET '
        'عبر --dart-define، أو فعّل getCloudinaryUploadSign في Cloud Functions.',
      );
    }
    return Uri.parse('https://api.cloudinary.com/v1_1/$name/image/upload');
  }

  static const folderParts = 'barrr/parts';
  static const folderReceipts = 'barrr/receipts';
  static const folderProfiles = 'barrr/profiles';
}
