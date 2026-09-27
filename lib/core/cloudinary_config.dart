/// إعدادات Cloudinary للرفع غير الموقّع من التطبيق.
///
/// املأ [cloudName] و [uploadPreset] أدناه، أو مرّر عند التشغيل:
/// ```
/// flutter run --dart-define=CLOUDINARY_CLOUD_NAME=xxx --dart-define=CLOUDINARY_UPLOAD_PRESET=yyy
/// ```
class CloudinaryConfig {
  CloudinaryConfig._();

  /// من Cloudinary Dashboard → Cloud name
  static const cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'lzkmqtqp',
  );

  /// Upload preset بوضع Unsigned من Settings → Upload → Upload presets
  static const uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'barrr_unsigned)',
  );

  static bool get isConfigured =>
      cloudName.trim().isNotEmpty && uploadPreset.trim().isNotEmpty;

  static Uri uploadUri() {
    final name = cloudName.trim();
    if (name.isEmpty) {
      throw StateError(
        'Cloudinary غير مضبوط. أرسل cloud name و upload preset لوضعها في الإعدادات.',
      );
    }
    return Uri.parse('https://api.cloudinary.com/v1_1/$name/image/upload');
  }

  static const folderParts = 'barrr/parts';
  static const folderReceipts = 'barrr/receipts';
  static const folderProfiles = 'barrr/profiles';
}
