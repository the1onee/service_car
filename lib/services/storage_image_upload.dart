import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// مجلدات Firebase Storage للصور المضغوطة.
class StorageFolders {
  static const parts = 'parts';
  static const receipts = 'receipts';
  static const profiles = 'profiles';
}

/// رفع صور مضغوطة إلى Firebase Storage وإرجاع رابط التنزيل.
class StorageImageUpload {
  StorageImageUpload({
    ImagePicker? picker,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _picker = picker ?? ImagePicker(),
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final ImagePicker _picker;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

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
    return upload(file, folder: folder);
  }

  Future<String> upload(
    XFile file, {
    required String folder,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('يجب تسجيل الدخول لرفع الصورة.');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('الصورة فارغة.');
    }
    if (bytes.length > maxBytesAfterCompress) {
      throw StateError(
        'الصورة ما زالت كبيرة بعد الضغط. اختر صورة أوضح بحجم أصغر.',
      );
    }

    final safeFolder = folder.trim().isEmpty ? 'misc' : folder.trim();
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_${user.uid.substring(0, 6)}.jpg';
    final ref = _storage.ref('uploads/$safeFolder/${user.uid}/$name');

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'uploadedBy': user.uid,
        'folder': safeFolder,
      },
    );

    await ref.putData(bytes, metadata).timeout(const Duration(seconds: 60));
    final url = await ref.getDownloadURL();
    if (kDebugMode) {
      debugPrint('Storage uploaded ${bytes.length}B → $url');
    }
    return url;
  }
}
