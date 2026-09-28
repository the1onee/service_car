import 'package:image_picker/image_picker.dart';
import 'package:barrr/core/cloudinary_config.dart';
import 'package:barrr/services/cloudinary_upload.dart';

/// رفع صورة الملف الشخصي إلى Cloudinary.
class ProfilePhotoUpload {
  ProfilePhotoUpload({CloudinaryUpload? uploader})
      : _uploader = uploader ?? CloudinaryUpload();

  final CloudinaryUpload _uploader;

  Future<XFile?> pickPhoto() {
    return _uploader.pickImage(imageQuality: 70, maxWidth: 800);
  }

  Future<String> uploadPhoto(XFile file) {
    return _uploader.upload(
      file,
      folder: CloudinaryConfig.folderProfiles,
      tags: const ['profile'],
    );
  }

  Future<String> pickAndUpload() {
    return _uploader.pickAndUpload(
      folder: CloudinaryConfig.folderProfiles,
      tags: const ['profile'],
      imageQuality: 70,
      maxWidth: 800,
    );
  }
}
