import 'package:image_picker/image_picker.dart';
import 'package:barrr/core/cloudinary_config.dart';
import 'package:barrr/services/cloudinary_upload.dart';

/// رفع فاتورة شحن المحفظة إلى Cloudinary (مضغوطة).
class WalletTopUpUpload {
  WalletTopUpUpload({CloudinaryUpload? uploader})
      : _uploader = uploader ?? CloudinaryUpload();

  final CloudinaryUpload _uploader;

  Future<XFile?> pickReceipt() {
    return _uploader.pickImage(imageQuality: 55, maxWidth: 900);
  }

  Future<String> uploadReceipt(XFile file) {
    return _uploader.upload(
      file,
      folder: CloudinaryConfig.folderReceipts,
      tags: const ['wallet_top_up'],
    );
  }

  /// يختار صورة مضغوطة ويرفعها؛ يرمي `cancelled` عند الإلغاء.
  Future<String> pickAndUpload() {
    return _uploader.pickAndUpload(
      folder: CloudinaryConfig.folderReceipts,
      tags: const ['wallet_top_up'],
      imageQuality: 55,
      maxWidth: 900,
    );
  }
}
