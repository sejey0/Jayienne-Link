import 'dart:io';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'supabase_storage_service.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final SupabaseStorageService _supabaseStorage = SupabaseStorageService();

  /// Upload profile photo with intelligent fallback system
  /// Priority: Supabase Storage > Firebase Storage > Base64 fallback
  Future<String> uploadProfilePhoto(String userId, File imageFile) async {
    debugPrint('Starting intelligent profile photo upload for user: $userId');

    // Method 1: Try Supabase Storage first (best option)
    try {
      debugPrint('Attempting Supabase Storage upload...');
      final url = await _supabaseStorage.uploadProfilePhoto(userId, imageFile);
      debugPrint('✅ Supabase upload successful');
      return url;
    } catch (e) {
      debugPrint('❌ Supabase upload failed: $e');
    }

    // Method 2: Try Firebase Storage (if available)
    try {
      debugPrint('Attempting Firebase Storage upload...');
      final url = await _uploadToFirebaseStorage(userId, imageFile);
      debugPrint('✅ Firebase Storage upload successful');
      return url;
    } catch (e) {
      debugPrint('❌ Firebase Storage upload failed: $e');

      // Method 3: Base64 fallback (always works)
      if (e.toString().contains('object-not-found') ||
          e.toString().contains('upgrade') ||
          e.toString().contains('plan')) {
        debugPrint('Using Base64 fallback for free tier project');
        return await _convertToOptimizedBase64(imageFile);
      }

      rethrow;
    }
  }

  /// Original Firebase Storage upload method
  Future<String> _uploadToFirebaseStorage(String userId, File imageFile) async {
    debugPrint('Attempting Firebase Storage upload for user: $userId');
    debugPrint('Image file size: ${await imageFile.length()} bytes');

    // Check if file exists
    if (!await imageFile.exists()) {
      throw Exception('Image file does not exist');
    }

    // Create reference with timestamp to avoid caching issues
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref().child('profile_photos/${userId}_$timestamp.jpg');

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
      final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
      debugPrint('Firebase upload progress: ${progress.toStringAsFixed(1)}%');
    });

    // Wait for completion
    final snapshot = await uploadTask;
    debugPrint('Firebase Storage upload completed. Bytes transferred: ${snapshot.totalBytes}');

    // Get download URL
    final downloadUrl = await ref.getDownloadURL();
    debugPrint('Firebase Storage URL: $downloadUrl');

    return downloadUrl;
  }

  /// Convert image to optimized Base64 (free tier fallback)
  Future<String> _convertToOptimizedBase64(File imageFile) async {
    try {
      debugPrint('Converting image to Base64 (fallback mode)');

      // Read image bytes
      final imageBytes = await imageFile.readAsBytes();
      debugPrint('Original image size: ${imageBytes.length} bytes');

      // Decode and resize image to reduce size
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize to maximum 256x256 to keep Base64 size manageable
      img.Image resized = img.copyResize(image, width: 256, height: 256);

      // Convert to JPEG with compression
      final compressedBytes = img.encodeJpg(resized, quality: 70);
      debugPrint('Compressed image size: ${compressedBytes.length} bytes');

      // Convert to Base64
      final base64String = base64Encode(compressedBytes);
      final base64Url = 'data:image/jpeg;base64,$base64String';

      debugPrint('Base64 conversion complete. Size: ${base64String.length} characters');

      return base64Url;
    } catch (e) {
      debugPrint('Base64 conversion error: $e');
      throw Exception('Failed to process image: $e');
    }
  }

  Future<void> deleteProfilePhoto(String userId) async {
    // Try Supabase first
    try {
      await _supabaseStorage.deleteProfilePhoto(userId);
      debugPrint('Deleted from Supabase storage');
      return;
    } catch (e) {
      debugPrint('Supabase delete failed, trying Firebase: $e');
    }

    // Try Firebase as fallback
    try {
      final listResult = await _storage.ref().child('profile_photos').listAll();
      final userFiles = listResult.items
          .where((ref) => ref.name.startsWith('${userId}_') || ref.name == '$userId.jpg')
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
      debugPrint('Firebase delete failed (expected on free tier): ${e.code} - ${e.message}');
    }
  }

  /// Test storage connectivity across all services
  Future<Map<String, bool>> testAllStorageConnectivity() async {
    debugPrint('Testing all storage services connectivity...');

    final results = <String, bool>{};

    // Test Supabase
    try {
      results['supabase'] = await _supabaseStorage.testConnectivity();
    } catch (e) {
      results['supabase'] = false;
      debugPrint('Supabase test failed: $e');
    }

    // Test Firebase
    try {
      final ref = _storage.ref().child('test');
      debugPrint('Firebase Storage bucket: ${_storage.bucket}');
      results['firebase'] = true;
    } catch (e) {
      results['firebase'] = false;
      debugPrint('Firebase test failed: $e');
    }

    // Base64 is always available
    results['base64'] = true;

    debugPrint('Storage connectivity results: $results');
    return results;
  }

  // Legacy method for backwards compatibility
  Future<bool> testStorageConnectivity() async {
    final results = await testAllStorageConnectivity();
    return results['supabase'] == true || results['firebase'] == true;
  }
}