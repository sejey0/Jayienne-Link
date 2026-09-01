import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import '../providers/debug_provider.dart';

class SupabaseStorageService {
  static const String _bucketName = 'profile-photos';
  static const String _chatBucketName = 'chat-photos';
  static const String _secretMediaBucketName = 'secret-media';
  static const String _legacySecretMediaBucketName = 'secret_media';

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Upload profile photo to Supabase Storage
  Future<String> uploadProfilePhoto(String userId, File imageFile) async {
    if (DebugProvider.isOfflineForced) {
      throw const SocketException('Simulated Offline Mode: Cannot upload photo while offline');
    }
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

      // Fall back to Base64 data URI so profile creation still succeeds
      // when Supabase Storage RLS policies are not configured yet.
      if (e is StorageException ||
          e.toString().contains('row-level security policy') ||
          e.toString().contains('Unauthorized')) {
        debugPrint(
            '⚠️ Storage RLS blocked upload. Falling back to Base64 image storage.');
        final fileBytes = await imageFile.readAsBytes();
        final optimizedBytes = await _optimizeImage(fileBytes);
        final base64Image = base64Encode(optimizedBytes);
        return 'data:image/jpeg;base64,$base64Image';
      }

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
  Future<Uint8List> _optimizeImage(
    Uint8List imageBytes, {
    int maxDimension = 512,
    int quality = 85,
  }) async {
    try {
      final params = _ImageOptimizeParams(
        imageBytes,
        maxDimension,
        quality,
      );
      return await compute(_optimizeImageIsolate, params);
    } catch (e) {
      debugPrint('Image optimization failed: $e');
      // Return original if optimization fails
      return imageBytes;
    }
  }

  /// Upload secret media (images and videos)
  Future<String> uploadSecretMedia(
      String userId, File mediaFile, String mediaType) async {
    if (DebugProvider.isOfflineForced) {
      throw const SocketException('Simulated Offline Mode: Cannot upload secret media while offline');
    }
    try {
      debugPrint(
          'Starting secret media upload for user: $userId, type: $mediaType');

      // Check if file exists
      if (!await mediaFile.exists()) {
        throw Exception('Media file does not exist');
      }

      final fileBytes = await mediaFile.readAsBytes();
      debugPrint('Media file size: ${fileBytes.length} bytes');

      // Create unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(mediaFile.path).toLowerCase();
      final fileName =
          '${userId}_${timestamp}_${DateTime.now().toIso8601String().replaceAll(':', '-')}$fileExtension';

      final uploadPath = '$userId/$mediaType/$fileName';

      debugPrint(
          'Uploading to Supabase Storage: $_secretMediaBucketName/$uploadPath');

      // Determine content type
      String contentType = 'application/octet-stream';
      if (mediaType == 'image') {
        contentType = _getImageContentType(fileExtension);
      } else if (mediaType == 'video') {
        contentType = _getVideoContentType(fileExtension);
      }

      // Upload to Supabase Storage (supports both new and legacy bucket names)
      final bucketUsed = await _uploadSecretMediaToAvailableBucket(
        uploadPath: uploadPath,
        fileBytes: fileBytes,
        contentType: contentType,
      );

      // Get public URL
      final publicUrl =
          _supabase.storage.from(bucketUsed).getPublicUrl(uploadPath);

      debugPrint('Secret media upload successful: $publicUrl');

      return publicUrl;
    } catch (e) {
      debugPrint('Secret media upload failed: $e');
      rethrow;
    }
  }

  Future<String> _uploadSecretMediaToAvailableBucket({
    required String uploadPath,
    required Uint8List fileBytes,
    required String contentType,
  }) async {
    final candidateBuckets = <String>[
      _secretMediaBucketName,
      _legacySecretMediaBucketName,
    ];

    StorageException? lastStorageError;
    Object? lastError;

    for (final bucket in candidateBuckets) {
      try {
        await _supabase.storage.from(bucket).uploadBinary(
              uploadPath,
              fileBytes,
              fileOptions: FileOptions(
                upsert: true,
                contentType: contentType,
              ),
            );
        debugPrint('Secret media uploaded using bucket: $bucket');
        return bucket;
      } on StorageException catch (e) {
        lastStorageError = e;
        lastError = e;
        final message = e.message.toLowerCase();
        if (message.contains('bucket not found')) {
          debugPrint('Bucket "$bucket" not found, trying next candidate...');
          continue;
        }
        rethrow;
      } catch (e) {
        lastError = e;
        rethrow;
      }
    }

    throw Exception(
      'Secret media storage bucket not found. Create either "$_secretMediaBucketName" or "$_legacySecretMediaBucketName" in Supabase Storage. Last error: ${lastStorageError?.message ?? lastError}',
    );
  }

  /// Upload chat photo to Supabase Storage
  Future<String> uploadChatPhoto(String userId, File imageFile) async {
    try {
      debugPrint('Starting Supabase chat photo upload for user: $userId');

      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      final fileBytes = await imageFile.readAsBytes();
      debugPrint('Original image size: ${fileBytes.length} bytes');

      final optimizedBytes = await _optimizeImage(
        fileBytes,
        maxDimension: 1280,
        quality: 80,
      );
      debugPrint('Optimized image size: ${optimizedBytes.length} bytes');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(imageFile.path).toLowerCase();
      final fileName = 'chat_${userId}_$timestamp$fileExtension';

      debugPrint('Uploading to Supabase Storage: $_chatBucketName/$fileName');

      await _supabase.storage
          .from(_chatBucketName)
          .uploadBinary(fileName, optimizedBytes,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ));

      final publicUrl =
          _supabase.storage.from(_chatBucketName).getPublicUrl(fileName);

      debugPrint('Chat photo upload successful: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Chat photo upload failed: $e');

      if (e is StorageException ||
          e.toString().contains('row-level security policy') ||
          e.toString().contains('Unauthorized')) {
        debugPrint(
            '⚠️ Storage RLS blocked upload. Falling back to Base64 image storage.');
        final fileBytes = await imageFile.readAsBytes();
        final optimizedBytes = await _optimizeImage(
          fileBytes,
          maxDimension: 1280,
          quality: 80,
        );
        final base64Image = base64Encode(optimizedBytes);
        return 'data:image/jpeg;base64,$base64Image';
      }

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

  /// Delete chat photo from Supabase Storage using its public URL
  Future<void> deleteChatPhotoByUrl(String imageUrl) async {
    if (imageUrl.startsWith('data:image/')) {
      return;
    }

    try {
      final uri = Uri.parse(imageUrl);
      final segments = uri.pathSegments;
      final bucketIndex = segments.indexOf(_chatBucketName);
      if (bucketIndex == -1) {
        return;
      }

      final objectPath = segments.sublist(bucketIndex + 1).join('/');
      if (objectPath.isEmpty) {
        return;
      }

      await _supabase.storage.from(_chatBucketName).remove([objectPath]);
      debugPrint('Deleted chat photo from storage: $objectPath');
    } catch (e) {
      debugPrint('Chat photo delete failed: $e');
      throw Exception('Storage cleanup failed: $e');
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
    if (DebugProvider.isOfflineForced) {
      debugPrint('❌ Supabase storage connectivity blocked: Simulated Offline Mode');
      return false;
    }
    try {
      debugPrint('Testing Supabase connectivity...');

      // Try to list files in the bucket (should work even if empty)
      await _supabase.storage.from(_bucketName).list();

      debugPrint('✅ Supabase connectivity: OK');
      return true;
    } catch (e) {
      debugPrint('❌ Supabase connectivity failed: $e');
      return false;
    }
  }

  /// Get storage usage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    if (DebugProvider.isOfflineForced) {
      return {'error': 'Simulated Offline Mode Active (Disconnected from cloud)'};
    }
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

      // Test if profile bucket exists by trying to list files.
      await _supabase.storage.from(_bucketName).list();
      // Test if chat bucket exists.
      await _supabase.storage.from(_chatBucketName).list();
      // Test if secret media bucket exists.
      await _supabase.storage.from(_secretMediaBucketName).list();

      debugPrint(
          '✅ Supabase storage buckets ready: $_bucketName, $_chatBucketName, $_secretMediaBucketName');
      return true;
    } catch (e) {
      debugPrint('❌ Supabase storage initialization failed: $e');
      debugPrint(
          '💡 Make sure these buckets exist in Supabase: "$_bucketName", "$_chatBucketName", "$_secretMediaBucketName"');
      return false;
    }
  }
}

class _ImageOptimizeParams {
  final Uint8List bytes;
  final int maxDimension;
  final int quality;

  const _ImageOptimizeParams(this.bytes, this.maxDimension, this.quality);
}

Uint8List _optimizeImageIsolate(_ImageOptimizeParams params) {
  try {
    final image = img.decodeImage(params.bytes);
    if (image == null) {
      return params.bytes;
    }

    img.Image resized = image;
    if (image.width > params.maxDimension ||
        image.height > params.maxDimension) {
      resized = img.copyResize(
        image,
        width: image.width > image.height ? params.maxDimension : null,
        height: image.height > image.width ? params.maxDimension : null,
        maintainAspect: true,
      );
    }

    final optimizedBytes = img.encodeJpg(resized, quality: params.quality);
    return Uint8List.fromList(optimizedBytes);
  } catch (_) {
    return params.bytes;
  }
}

String _getImageContentType(String extension) {
  switch (extension.toLowerCase()) {
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.png':
      return 'image/png';
    case '.gif':
      return 'image/gif';
    case '.webp':
      return 'image/webp';
    default:
      return 'image/jpeg';
  }
}

String _getVideoContentType(String extension) {
  switch (extension.toLowerCase()) {
    case '.mp4':
      return 'video/mp4';
    case '.mov':
      return 'video/quicktime';
    case '.avi':
      return 'video/x-msvideo';
    case '.mkv':
      return 'video/x-matroska';
    case '.webm':
      return 'video/webm';
    default:
      return 'video/mp4';
  }
}
