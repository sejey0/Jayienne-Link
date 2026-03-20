import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;

class SupabaseStorageService {
  static const String _bucketName = 'profile-photos';

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Upload profile photo to Supabase Storage
  Future<String> uploadProfilePhoto(String userId, File imageFile) async {
    try {
      debugPrint('Starting Supabase profile photo upload for user: $userId');

      // Check if file exists
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      final fileBytes = await imageFile.readAsBytes();
      debugPrint('Original image size: ${fileBytes.length} bytes');

      // Optimize image to reduce size and improve performance
      final optimizedBytes = await _optimizeImage(fileBytes);
      debugPrint('Optimized image size: ${optimizedBytes.length} bytes');

      // Create unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(imageFile.path).toLowerCase();
      final fileName = '${userId}_$timestamp$fileExtension';

      debugPrint('Uploading to Supabase Storage: $_bucketName/$fileName');

      // Upload to Supabase Storage
      await _supabase.storage
          .from(_bucketName)
          .uploadBinary(fileName, optimizedBytes,
              fileOptions: const FileOptions(
                upsert: true, // Replace if exists
                contentType: 'image/jpeg',
              ));

      // Get public URL
      final publicUrl =
          _supabase.storage.from(_bucketName).getPublicUrl(fileName);

      debugPrint('Supabase upload successful: $publicUrl');

      // Clean up old photos (optional)
      await _cleanupOldPhotos(userId, fileName);

      return publicUrl;
    } catch (e) {
      debugPrint('Supabase upload failed: $e');

      // Provide specific error messages
      if (e.toString().contains('JWT')) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (e.toString().contains('storage')) {
        throw Exception('Storage service unavailable. Please try again later.');
      } else if (e.toString().contains('size')) {
        throw Exception(
            'Image file is too large. Please choose a smaller image.');
      } else {
        throw Exception('Upload failed: ${e.toString()}');
      }
    }
  }

  /// Optimize image for faster uploads and smaller storage
  Future<Uint8List> _optimizeImage(Uint8List imageBytes) async {
    try {
      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize if too large (max 512x512 for profile photos)
      if (image.width > 512 || image.height > 512) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? 512 : null,
          height: image.height > image.width ? 512 : null,
          maintainAspect: true,
        );
        debugPrint('Image resized to: ${image.width}x${image.height}');
      }

      // Convert to JPEG with good quality compression
      final optimizedBytes = img.encodeJpg(image, quality: 85);

      return Uint8List.fromList(optimizedBytes);
    } catch (e) {
      debugPrint('Image optimization failed: $e');
      // Return original if optimization fails
      return imageBytes;
    }
  }

  /// Clean up old profile photos to save storage space
  Future<void> _cleanupOldPhotos(String userId, String currentFileName) async {
    try {
      // List all files in the bucket
      final files = await _supabase.storage.from(_bucketName).list();

      // Find old files for this user
      final oldFiles = files
          .where((file) =>
              file.name.startsWith('${userId}_') &&
              file.name != currentFileName)
          .toList();

      // Delete old files
      for (final file in oldFiles) {
        try {
          await _supabase.storage.from(_bucketName).remove([file.name]);
          debugPrint('Cleaned up old photo: ${file.name}');
        } catch (e) {
          debugPrint('Failed to cleanup ${file.name}: $e');
        }
      }
    } catch (e) {
      debugPrint('Cleanup failed: $e');
      // Don't throw - cleanup is optional
    }
  }

  /// Delete profile photo
  Future<void> deleteProfilePhoto(String userId) async {
    try {
      // List all files for this user
      final files = await _supabase.storage.from(_bucketName).list();

      final userFiles = files
          .where((file) => file.name.startsWith('${userId}_'))
          .map((file) => file.name)
          .toList();

      if (userFiles.isNotEmpty) {
        await _supabase.storage.from(_bucketName).remove(userFiles);
        debugPrint('Deleted ${userFiles.length} photos for user: $userId');
      }
    } catch (e) {
      debugPrint('Delete failed: $e');
      throw Exception('Failed to delete profile photo: $e');
    }
  }

  /// Test Supabase connectivity
  Future<bool> testConnectivity() async {
    try {
      debugPrint('Testing Supabase connectivity...');

      // Try to list files in the bucket (should work even if empty)
      await _supabase.storage
          .from(_bucketName)
          .list();

      debugPrint('✅ Supabase connectivity: OK');
      return true;
    } catch (e) {
      debugPrint('❌ Supabase connectivity failed: $e');
      return false;
    }
  }

  /// Get storage usage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final files = await _supabase.storage.from(_bucketName).list();

      final totalFiles = files.length;
      final totalSize = files.fold<num>(
          0, (sum, file) => sum + ((file.metadata?['size'] as num?) ?? 0));

      return {
        'total_files': totalFiles,
        'total_size_bytes': totalSize.toInt(),
        'total_size_mb': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'bucket_name': _bucketName,
      };
    } catch (e) {
      debugPrint('Failed to get storage stats: $e');
      return {'error': e.toString()};
    }
  }

  /// Initialize Supabase storage (create bucket if needed)
  Future<bool> initializeStorage() async {
    try {
      debugPrint('Initializing Supabase storage...');

      // Test if bucket exists by trying to list files
      await _supabase.storage
          .from(_bucketName)
          .list();

      debugPrint('✅ Supabase storage bucket ready: $_bucketName');
      return true;
    } catch (e) {
      debugPrint('❌ Supabase storage initialization failed: $e');
      debugPrint(
          '💡 Make sure the "$_bucketName" bucket exists in your Supabase dashboard');
      return false;
    }
  }
}
