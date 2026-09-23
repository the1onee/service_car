import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// رفع فاتورة الشحن بدون Firebase Storage: نضغط الصورة ونحفظها كـ data URL في Firestore.
class WalletTopUpUpload {
  final _picker = ImagePicker();

  Future<XFile?> pickReceipt() {
    return _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 55,
      maxWidth: 900,
    );
  }

  Future<String> toDataUrl(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > 700 * 1024) {
      throw StateError('صورة الفاتورة كبيرة جداً. اختر صورة أوضح بحجم أصغر.');
    }
    final mime = file.mimeType ?? 'image/jpeg';
    final b64 = base64Encode(bytes);
    if (kDebugMode) {
      debugPrint('Receipt data URL size=${bytes.length}');
    }
    return 'data:$mime;base64,$b64';
  }

  Future<String> pickAndEncode() async {
    final file = await pickReceipt();
    if (file == null) throw StateError('cancelled');
    return toDataUrl(file);
  }
}
