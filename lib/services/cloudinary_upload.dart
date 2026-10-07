import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:barrr/core/cloudinary_config.dart';

/// رفع صور مضغوطة إلى Cloudinary عبر unsigned preset (--dart-define).
class CloudinaryUpload {
  CloudinaryUpload({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const maxBytesAfterCompress = 600 * 1024;

  Future<XFile?> pickImage({
    ImageSource source = ImageSource.gallery,
    int imageQuality = 55,
    double maxWidth = 1280,
  }) {
    return _picker.pickImage(
      source: source,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
    );
  }

  /// يختار صورة مضغوطة ويرفعها. يرمي [StateError] برسالة `cancelled` عند الإلغاء.
  Future<String> pickAndUpload({
    required String folder,
    List<String> tags = const [],
    ImageSource source = ImageSource.gallery,
    int imageQuality = 55,
    double maxWidth = 1280,
  }) async {
    final file = await pickImage(
      source: source,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
    );
    if (file == null) throw StateError('cancelled');
    return upload(file, folder: folder, tags: tags);
  }

  Future<String> upload(
    XFile file, {
    required String folder,
    List<String> tags = const [],
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('الصورة فارغة.');
    }
    if (bytes.length > maxBytesAfterCompress) {
      throw StateError(
        'الصورة ما زالت كبيرة بعد الضغط. اختر صورة أوضح بحجم أصغر.',
      );
    }
    if (!CloudinaryConfig.isUnsignedConfigured) {
      throw StateError(
        'ارفع الصور يحتاج Cloud name من لوحة Cloudinary مع preset barrr_unsigned.',
      );
    }

    final filename = file.name.trim().isEmpty ? 'upload.jpg' : file.name;
    final request = http.MultipartRequest(
      'POST',
      CloudinaryConfig.uploadUri(),
    )
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      )
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset.trim();

    final folderTrim = folder.trim();
    if (folderTrim.isNotEmpty) {
      request.fields['folder'] = folderTrim;
    }
    if (tags.isNotEmpty) {
      request.fields['tags'] = tags.join(',');
    }

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      if (kDebugMode) {
        debugPrint('Cloudinary upload failed ${streamed.statusCode}: $body');
      }
      throw StateError(_cloudinaryErrorMessage(streamed.statusCode, body));
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw StateError('استجابة Cloudinary غير صالحة.');
    }
    final url = decoded['secure_url'] as String? ?? decoded['url'] as String?;
    if (url == null || url.trim().isEmpty) {
      throw StateError('لم يُرجع Cloudinary رابط الصورة.');
    }
    if (kDebugMode) {
      debugPrint('Cloudinary uploaded ${bytes.length}B → $url');
    }
    return url.trim();
  }

  static String _cloudinaryErrorMessage(int statusCode, String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) {
          final message = error['message']?.toString().trim();
          if (message != null && message.isNotEmpty) {
            return 'تعذّر رفع الصورة إلى Cloudinary: $message';
          }
        }
      }
    } catch (_) {}
    return 'تعذّر رفع الصورة إلى Cloudinary ($statusCode).';
  }
}
