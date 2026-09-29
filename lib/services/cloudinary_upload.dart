import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:barrr/core/cloudinary_config.dart';

/// رفع صور مضغوطة إلى Cloudinary.
/// يفضّل الرفع الموقّع عبر [getCloudinaryUploadSign]، وإلا unsigned عبر --dart-define.
class CloudinaryUpload {
  CloudinaryUpload({
    ImagePicker? picker,
    FirebaseFunctions? functions,
  })  : _picker = picker ?? ImagePicker(),
        _functions = functions;

  final ImagePicker _picker;
  final FirebaseFunctions? _functions;

  static const maxBytesAfterCompress = 600 * 1024;

  FirebaseFunctions get _fns =>
      _functions ?? FirebaseFunctions.instance;

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

    final filename = file.name.trim().isEmpty ? 'upload.jpg' : file.name;
    final signed = await _trySignedParams(folder);
    if (signed == null && !CloudinaryConfig.isUnsignedConfigured) {
      throw StateError(
        'ارفع الصور يحتاج Cloud name من لوحة Cloudinary مع preset barrr_unsigned.',
      );
    }

    final request = http.MultipartRequest(
      'POST',
      CloudinaryConfig.uploadUri(signed?['cloudName'] as String?),
    )..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

    if (signed != null) {
      request.fields['api_key'] = '${signed['apiKey']}';
      request.fields['timestamp'] = '${signed['timestamp']}';
      request.fields['signature'] = '${signed['signature']}';
      request.fields['folder'] = '${signed['folder']}';
      if (tags.isNotEmpty) {
        request.fields['tags'] = tags.join(',');
      }
    } else {
      request.fields['upload_preset'] = CloudinaryConfig.uploadPreset.trim();
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

  Future<Map<String, dynamic>?> _trySignedParams(String folder) async {
    try {
      final result = await _fns
          .httpsCallable('getCloudinaryUploadSign')
          .call(<String, dynamic>{'folder': folder});
      final data = result.data;
      if (data is! Map) return null;
      final map = Map<String, dynamic>.from(data);
      if (map['cloudName'] == null ||
          map['apiKey'] == null ||
          map['signature'] == null ||
          map['timestamp'] == null) {
        return null;
      }
      return map;
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('Cloudinary signed upload unavailable: ${e.code} ${e.message}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Cloudinary signed upload unavailable: $e');
      }
      return null;
    }
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
