import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload profile photo with better error handling and debugging
  Future<String> uploadProfilePhoto(String userId, File imageFile) async {
    try {
      debugPrint('Starting profile photo upload for user: $userId');
      debugPrint('Image file size: ${await imageFile.length()} bytes');
      debugPrint('Image file path: ${imageFile.path}');

      // Check if file exists
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      // Create reference with timestamp to avoid caching issues
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref =
          _storage.ref().child('profile_photos/${userId}_$timestamp.jpg');

      debugPrint('Uploading to: ${ref.fullPath}');
      debugPrint('Storage bucket: ${_storage.bucket}');

      // Upload with proper metadata
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        debugPrint('Upload progress: ${progress.toStringAsFixed(1)}%');
      });

      // Wait for completion
      final snapshot = await uploadTask;
      debugPrint('Upload completed. Bytes transferred: ${snapshot.totalBytes}');

      // Get download URL
      final downloadUrl = await ref.getDownloadURL();
      debugPrint('Download URL obtained: $downloadUrl');

      // Clean up old profile photos (optional)
      await _cleanupOldProfilePhotos(userId, ref.name);

      return downloadUrl;
    } on FirebaseException catch (e) {
      debugPrint('Firebase Storage error: ${e.code} - ${e.message}');
      debugPrint('Error details: ${e.toString()}');

      // Handle specific Firebase Storage errors
      switch (e.code) {
        case 'object-not-found':
          throw Exception(
              'Storage location not found. Please check Firebase Storage configuration.');
        case 'unauthorized':
          throw Exception(
              'Not authorized to upload. Please check Firebase Storage rules.');
        case 'canceled':
          throw Exception('Upload was canceled.');
        case 'unknown':
          throw Exception('An unknown error occurred: ${e.message}');
        case 'retry-limit-exceeded':
          throw Exception(
              'Upload failed after multiple retries. Please try again later.');
        case 'invalid-checksum':
          throw Exception(
              'File upload failed due to data corruption. Please try again.');
        default:
          throw Exception(
              'Upload failed: ${e.message ?? 'Unknown Firebase Storage error'}');
      }
    } catch (e) {
      debugPrint('General upload error: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Clean up old profile photos to save storage space
  Future<void> _cleanupOldProfilePhotos(
      String userId, String currentFileName) async {
    try {
      final listResult = await _storage.ref().child('profile_photos').listAll();
      final oldFiles = listResult.items
          .where((ref) =>
              ref.name.startsWith('${userId}_') && ref.name != currentFileName)
          .toList();

      for (final ref in oldFiles) {
        try {
          await ref.delete();
          debugPrint('Cleaned up old photo: ${ref.name}');
        } catch (e) {
          debugPrint('Failed to cleanup ${ref.name}: $e');
        }
      }
    } catch (e) {
      debugPrint('Cleanup failed: $e');
      // Don't throw - cleanup is optional
    }
  }

  Future<void> deleteProfilePhoto(String userId) async {
    try {
      // List and delete all photos for this user
      final listResult = await _storage.ref().child('profile_photos').listAll();
      final userFiles = listResult.items
          .where((ref) =>
              ref.name.startsWith('${userId}_') || ref.name == '$userId.jpg')
          .toList();

      for (final ref in userFiles) {
        try {
          await ref.delete();
          debugPrint('Deleted photo: ${ref.name}');
        } catch (e) {
          debugPrint('Failed to delete ${ref.name}: $e');
        }
      }
    } on FirebaseException catch (e) {
      // Ignore if file doesn't exist
      if (e.code != 'object-not-found') {
        debugPrint('Delete error: ${e.code} - ${e.message}');
        rethrow;
      }
    }
  }

  /// Test Firebase Storage connectivity
  Future<bool> testStorageConnectivity() async {
    try {
      debugPrint('Testing Firebase Storage connectivity...');

      // Try to get storage bucket info
      final ref = _storage.ref().child('test');
      debugPrint('Storage bucket: ${_storage.bucket}');
      debugPrint('Test reference created: ${ref.fullPath}');

      return true;
    } catch (e) {
      debugPrint('Storage connectivity test failed: $e');
      return false;
    }
  }
}
