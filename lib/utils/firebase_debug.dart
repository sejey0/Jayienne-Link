import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Debug utility for Firebase Storage issues
class FirebaseDebugUtils {
  static Future<Map<String, dynamic>> diagnoseStorageIssue() async {
    final diagnosis = <String, dynamic>{};

    try {
      // 1. Check Firebase initialization
      diagnosis['firebase_initialized'] = Firebase.apps.isNotEmpty;
      if (Firebase.apps.isNotEmpty) {
        diagnosis['app_name'] = Firebase.app().name;
        diagnosis['project_id'] = Firebase.app().options.projectId;
      }

      // 2. Check Storage instance
      final storage = FirebaseStorage.instance;
      diagnosis['storage_bucket'] = storage.bucket;

      // 3. Test basic storage access
      try {
        final ref = storage.ref().child('test/debug.txt');
        diagnosis['can_create_reference'] = true;
        diagnosis['test_reference_path'] = ref.fullPath;
      } catch (e) {
        diagnosis['can_create_reference'] = false;
        diagnosis['reference_error'] = e.toString();
      }

      // 4. Test simple upload with dummy data
      try {
        await _testSimpleUpload();
        diagnosis['can_upload'] = true;
      } catch (e) {
        diagnosis['can_upload'] = false;
        diagnosis['upload_error'] = e.toString();
        diagnosis['upload_error_code'] =
            e is FirebaseException ? e.code : 'unknown';
      }

      // 5. Check storage rules (attempt to read)
      try {
        final ref = storage.ref().child('test/rules_test.txt');
        await ref.getDownloadURL();
        diagnosis['can_read_nonexistent'] = true;
      } catch (e) {
        diagnosis['can_read_nonexistent'] = false;
        diagnosis['read_error'] = e.toString();
        if (e is FirebaseException) {
          diagnosis['read_error_code'] = e.code;
          // Common error codes:
          // object-not-found: Normal for non-existent file
          // permission-denied: Rules issue
          // unauthorized: Authentication issue
        }
      }
    } catch (e) {
      diagnosis['general_error'] = e.toString();
    }

    return diagnosis;
  }

  static Future<void> _testSimpleUpload() async {
    try {
      // Create a simple test file
      final tempDir = await getTemporaryDirectory();
      final testFile = File('${tempDir.path}/firebase_test.txt');
      await testFile.writeAsString('Firebase Storage Test - ${DateTime.now()}');

      // Try uploading
      final storage = FirebaseStorage.instance;
      final ref = storage
          .ref()
          .child('debug/test_${DateTime.now().millisecondsSinceEpoch}.txt');

      await ref.putFile(testFile, SettableMetadata(contentType: 'text/plain'));

      // Clean up
      await testFile.delete();
      await ref.delete(); // Clean up the uploaded test file
    } catch (e) {
      rethrow; // Let the caller handle the error
    }
  }

  /// Print comprehensive Firebase Storage diagnosis
  static Future<void> printDiagnosis() async {
    debugPrint('=== FIREBASE STORAGE DIAGNOSIS ===');

    final diagnosis = await diagnoseStorageIssue();

    debugPrint(
        'Firebase App Initialized: ${diagnosis['firebase_initialized']}');
    if (diagnosis['app_name'] != null) {
      debugPrint('App Name: ${diagnosis['app_name']}');
      debugPrint('Project ID: ${diagnosis['project_id']}');
    }

    debugPrint('Storage Bucket: ${diagnosis['storage_bucket']}');
    debugPrint('Can Create References: ${diagnosis['can_create_reference']}');

    if (diagnosis['can_upload'] == true) {
      debugPrint('✅ Upload Test: PASSED');
    } else {
      debugPrint('❌ Upload Test: FAILED');
      debugPrint('Upload Error: ${diagnosis['upload_error']}');
      debugPrint('Error Code: ${diagnosis['upload_error_code']}');

      // Provide troubleshooting suggestions
      final errorCode = diagnosis['upload_error_code'];
      switch (errorCode) {
        case 'permission-denied':
          debugPrint(
              '💡 SOLUTION: Check Firebase Storage rules. They may be too restrictive.');
          break;
        case 'unauthorized':
          debugPrint('💡 SOLUTION: User may not be properly authenticated.');
          break;
        case 'object-not-found':
          debugPrint(
              '💡 SOLUTION: Storage bucket may not exist or be misconfigured.');
          break;
        case 'unauthenticated':
          debugPrint('💡 SOLUTION: User authentication required for upload.');
          break;
        default:
          debugPrint(
              '💡 SOLUTION: Check Firebase project configuration and internet connection.');
      }
    }

    if (diagnosis['read_error_code'] == 'permission-denied') {
      debugPrint(
          '⚠️  WARNING: Storage rules may be too restrictive for reading.');
    }

    debugPrint('=== END DIAGNOSIS ===');
  }

  /// Suggested Firebase Storage rules for development
  static String getSuggestedStorageRules() {
    return '''
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow users to upload their own profile photos
    match /profile_photos/{userId}_{timestamp}.jpg {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Legacy profile photo path (for backward compatibility)
    match /profile_photos/{userId}.jpg {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Debug/test files (remove in production)
    match /debug/{allPaths=**} {
      allow read, write: if request.auth != null;
    }

    match /test/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
    ''';
  }
}
