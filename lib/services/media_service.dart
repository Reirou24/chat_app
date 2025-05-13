import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class MediaService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  //picks an image
  Future<File?> pickImage({required ImageSource source}) async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80, //COMPRESSES IMAGE TO REDUCE UPLOAD SIZE
      );

      if (pickedImage == null) return null;

      return File(pickedImage.path);
    } catch (e) {
      print("Error picking image: $e");
      return null;
    }
  }

  //picks a video
  Future<File?> pickVideo({required ImageSource source}) async {
    try {
      final XFile? pickedVideo = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 1), //VIDEO LENGTH
      );

      if (pickedVideo == null) return null;

      return File(pickedVideo.path);
    } catch (e) {
      print("Error picking video: $e");
      return null;
    }
  }

  //attach any file
  Future<File?> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result == null) return null;

      return File(result.files.single.path!);
    } catch (e) {
      print("Error picking file: $e");
      return null;
    }
  }

  //thumbnail for video
  Future<File?> generateVideoThumbnail(String videoPath) async {
    try {
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        quality: 50,
      );

      if (thumbnailPath == null) return null;

      return File(thumbnailPath);
    } catch (e) {
      print("Error generating video thumbnail: $e");
      return null;
    }
  }

  //upload to firebase
  Future<String?> uploadFile({required File file, required String folderName}) async {
    try {
      final String fileName = '${const Uuid().v4()}${path.extension(file.path)}';
      final Reference ref = _storage.ref().child('$folderName/$fileName');

      final UploadTask uploadTask = ref.putFile(file);
      final TaskSnapshot snapshot = await uploadTask;

      final String downloadURL = await snapshot.ref.getDownloadURL();

      return downloadURL;
    } catch (e) {
      print("Error uploading file: $e");
      return null;
    }
  }
}