import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:barrr/core/api_config.dart';

/// رفع صور مضغوطة عبر سيرفر البطريق (التوقيع وCloudinary على السيرفر).
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
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('سجّل الدخول لرفع الصورة.');
    }
    final res = await http
        .post(
          ApiConfig.uri('/api/uploads').replace(
            queryParameters: {'folder': folder.trim()},
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/octet-stream',
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      if (kDebugMode) {
        debugPrint('Upload failed ${res.statusCode}: ${res.body}');
      }
      throw StateError(_uploadErrorMessage(res.statusCode, res.body));
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw StateError('استجابة الرفع غير صالحة.');
    }
    final url = decoded['url'] as String?;
    if (url == null || url.trim().isEmpty) {
      throw StateError('لم يُرجع السيرفر رابط الصورة.');
    }
    if (kDebugMode) {
      debugPrint('Uploaded ${bytes.length}B → $url');
    }
    return url.trim();
  }

  static String _uploadErrorMessage(int statusCode, String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final message = decoded['message']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}
    if (statusCode == 401) return 'سجّل الدخول لرفع الصورة.';
    return 'تعذّر رفع الصورة ($statusCode).';
  }
}
