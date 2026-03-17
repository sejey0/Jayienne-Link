import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadProfilePhoto(String userId, File imageFile) async {
    final ref = _storage.ref().child('profile_photos/$userId.jpg');
    await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await ref.getDownloadURL();
  }

  Future<void> deleteProfilePhoto(String userId) async {
    try {
      final ref = _storage.ref().child('profile_photos/$userId.jpg');
      await ref.delete();
    } on FirebaseException catch (e) {
      // Ignore if file doesn't exist
      if (e.code != 'object-not-found') rethrow;
    }
  }
}
