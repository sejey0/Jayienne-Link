import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/gallery_folder_model.dart';
import '../models/gallery_image_model.dart';

/// Dedicated service for the Couple Shared Gallery powered by Nhost.
/// Completely independent from Supabase.
class NhostGalleryService {
  static NhostGalleryService? _instance;

  NhostGalleryService._();

  static NhostGalleryService get instance {
    _instance ??= NhostGalleryService._();
    return _instance!;
  }

  String get subdomain =>
      dotenv.env['NHOST_SUBDOMAIN']?.trim() ?? 'bopujszsgpxyiotttgte';
  String get region =>
      dotenv.env['NHOST_REGION']?.trim() ?? 'ap-southeast-1';
  String get adminSecret =>
      dotenv.env['NHOST_ADMIN_SECRET']?.trim() ?? 'JayienneLinkNhost2026Secret';

  String get graphqlUrl =>
      'https://$subdomain.graphql.$region.nhost.run/v1';
  String get storageUrl =>
      'https://$subdomain.storage.$region.nhost.run/v1';
  String get hasuraUrl =>
      'https://$subdomain.hasura.$region.nhost.run';
  String get sqlQueryUrl =>
      '$hasuraUrl/v2/query';
  String get metadataUrl =>
      '$hasuraUrl/v1/metadata';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-hasura-admin-secret': adminSecret,
      };

  Map<String, String> get storageHeaders => {
        'x-hasura-admin-secret': adminSecret,
      };

  /// Light ping to keep Nhost free tier instance awake
  Future<void> pingKeepAlive() async {
    try {
      await http.post(
        Uri.parse(graphqlUrl),
        headers: _headers,
        body: jsonEncode({'query': 'query { __typename }'}),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  bool _hasBootstrapped = false;

  /// Ensures tables and Hasura tracking are provisioned in Nhost
  Future<void> ensureTablesProvisioned({bool force = false}) async {
    if (_hasBootstrapped && !force) return;
    try {
      final sql = '''
        CREATE TABLE IF NOT EXISTS public.gallery_folders (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            couple_id TEXT NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
            cover_image_url TEXT,
            created_by_id TEXT NOT NULL,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );

        CREATE TABLE IF NOT EXISTS public.gallery_images (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            folder_id UUID NOT NULL REFERENCES public.gallery_folders(id) ON DELETE CASCADE,
            couple_id TEXT NOT NULL,
            uploaded_by_id TEXT NOT NULL,
            image_url TEXT NOT NULL,
            file_id TEXT,
            caption TEXT,
            taken_at TIMESTAMPTZ,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            deleted_at TIMESTAMPTZ
        );

        ALTER TABLE public.gallery_images ADD COLUMN IF NOT EXISTS taken_at TIMESTAMPTZ;

        CREATE INDEX IF NOT EXISTS idx_gallery_folders_couple ON public.gallery_folders(couple_id);
        CREATE INDEX IF NOT EXISTS idx_gallery_images_folder ON public.gallery_images(folder_id);
      ''';

      // Execute SQL via Hasura run_sql endpoint
      final response = await http.post(
        Uri.parse(sqlQueryUrl),
        headers: _headers,
        body: jsonEncode({
          'type': 'run_sql',
          'args': {
            'source': 'default',
            'sql': sql,
            'cascade': false,
            'read_only': false,
          },
        }),
      );
      debugPrint('Nhost run_sql response (${response.statusCode}): ${response.body}');

      // Track tables in Hasura metadata
      await _trackTable('gallery_folders');
      await _trackTable('gallery_images');
      await _trackRelationship(
        tableName: 'gallery_folders',
        relationshipName: 'images',
        foreignKeyTable: 'gallery_images',
        isList: true,
      );

      // Force Hasura to reload GraphQL schema metadata immediately
      try {
        await http.post(
          Uri.parse(metadataUrl),
          headers: _headers,
          body: jsonEncode({
            'type': 'reload_metadata',
            'args': {
              'reload_remote_schemas': true,
              'reload_sources': true,
            },
          }),
        );
      } catch (_) {}

      _hasBootstrapped = true;
      debugPrint('NhostGalleryService: bootstrap complete');
    } catch (e) {
      debugPrint('NhostGalleryService bootstrap error: $e');
      _hasBootstrapped = false;
    }
  }

  Future<void> _trackTable(String tableName) async {
    // Hasura v2 pg_track_table
    try {
      final res = await http.post(
        Uri.parse(metadataUrl),
        headers: _headers,
        body: jsonEncode({
          'type': 'pg_track_table',
          'args': {
            'source': 'default',
            'table': {
              'schema': 'public',
              'name': tableName,
            },
          },
        }),
      );
      debugPrint('Track $tableName v2 response (${res.statusCode}): ${res.body}');
    } catch (_) {}

    // Hasura v1 track_table fallback
    try {
      await http.post(
        Uri.parse('$hasuraUrl/v1/query'),
        headers: _headers,
        body: jsonEncode({
          'type': 'track_table',
          'args': {
            'schema': 'public',
            'name': tableName,
          },
        }),
      );
    } catch (_) {}
  }

  Future<void> _trackRelationship({
    required String tableName,
    required String relationshipName,
    required String foreignKeyTable,
    required bool isList,
  }) async {
    try {
      await http.post(
        Uri.parse(metadataUrl),
        headers: _headers,
        body: jsonEncode({
          'type': isList ? 'pg_create_array_relationship' : 'pg_create_object_relationship',
          'args': {
            'source': 'default',
            'table': {'schema': 'public', 'name': tableName},
            'name': relationshipName,
            'using': {
              'foreign_key_constraint_on': {
                'table': {'schema': 'public', 'name': foreignKeyTable},
                'column': 'folder_id',
              }
            }
          },
        }),
      );
    } catch (_) {}
  }

  /// Execute GraphQL Query / Mutation against Nhost
  Future<Map<String, dynamic>> _executeGraphQL(
    String query, {
    Map<String, dynamic>? variables,
  }) async {
    final response = await http.post(
      Uri.parse(graphqlUrl),
      headers: _headers,
      body: jsonEncode({
        'query': query,
        if (variables != null) 'variables': variables,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Nhost GraphQL request failed: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data.containsKey('errors')) {
      final errors = data['errors'] as List<dynamic>;
      throw Exception('Nhost GraphQL Error: ${errors.first['message']}');
    }

    return (data['data'] as Map<String, dynamic>?) ?? {};
  }

  /// Fetch all gallery folders for the couple
  Future<List<GalleryFolderModel>> getFolders(String coupleId) async {
    await ensureTablesProvisioned();

    const query = r'''
      query GetGalleryFolders($coupleId: String!) {
        gallery_folders(
          where: { couple_id: { _eq: $coupleId } }
          order_by: { created_at: desc }
        ) {
          id
          couple_id
          name
          description
          cover_image_url
          created_by_id
          created_at
          updated_at
          images_aggregate(where: { deleted_at: { _is_null: true } }) {
            aggregate {
              count
            }
          }
        }
      }
    ''';

    try {
      final result = await _executeGraphQL(query, variables: {'coupleId': coupleId});
      final list = result['gallery_folders'] as List<dynamic>? ?? [];
      return list.map((item) => GalleryFolderModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      // Fallback query if images_aggregate relationship is not tracked yet
      const fallbackQuery = r'''
        query GetGalleryFoldersFallback($coupleId: String!) {
          gallery_folders(
            where: { couple_id: { _eq: $coupleId } }
            order_by: { created_at: desc }
          ) {
            id
            couple_id
            name
            description
            cover_image_url
            created_by_id
            created_at
            updated_at
          }
        }
      ''';
      final result = await _executeGraphQL(fallbackQuery, variables: {'coupleId': coupleId});
      final list = result['gallery_folders'] as List<dynamic>? ?? [];
      return list.map((item) => GalleryFolderModel.fromJson(item as Map<String, dynamic>)).toList();
    }
  }

  /// Create a new folder
  Future<GalleryFolderModel> createFolder({
    required String coupleId,
    required String createdById,
    required String name,
    String? description,
  }) async {
    await ensureTablesProvisioned();

    const mutation = r'''
      mutation CreateGalleryFolder(
        $coupleId: String!
        $name: String!
        $description: String
        $createdById: String!
      ) {
        insert_gallery_folders_one(
          object: {
            couple_id: $coupleId
            name: $name
            description: $description
            created_by_id: $createdById
          }
        ) {
          id
          couple_id
          name
          description
          cover_image_url
          created_by_id
          created_at
          updated_at
        }
      }
    ''';

    final result = await _executeGraphQL(mutation, variables: {
      'coupleId': coupleId,
      'name': name.trim(),
      'description': description?.trim().isEmpty ?? true ? null : description?.trim(),
      'createdById': createdById,
    });

    final folderData = result['insert_gallery_folders_one'] as Map<String, dynamic>;
    return GalleryFolderModel.fromJson(folderData);
  }

  /// Update folder name, description, or cover image
  Future<void> updateFolder({
    required String folderId,
    String? name,
    String? description,
    String? coverImageUrl,
  }) async {
    const mutation = r'''
      mutation UpdateGalleryFolder(
        $folderId: uuid!
        $name: String
        $description: String
        $coverImageUrl: String
      ) {
        update_gallery_folders_by_pk(
          pk_columns: { id: $folderId }
          _set: {
            name: $name
            description: $description
            cover_image_url: $coverImageUrl
          }
        ) {
          id
        }
      }
    ''';

    await _executeGraphQL(mutation, variables: {
      'folderId': folderId,
      if (name != null) 'name': name.trim(),
      if (description != null) 'description': description.trim(),
      if (coverImageUrl != null) 'coverImageUrl': coverImageUrl.trim(),
    });
  }

  /// Delete folder and all its images
  Future<void> deleteFolder(String folderId) async {
    const mutation = r'''
      mutation DeleteGalleryFolder($folderId: uuid!) {
        delete_gallery_folders_by_pk(id: $folderId) {
          id
        }
      }
    ''';

    await _executeGraphQL(mutation, variables: {'folderId': folderId});
  }

  /// Fetch images for a folder
  Future<List<GalleryImageModel>> getFolderImages({
    required String folderId,
    required String coupleId,
  }) async {
    await ensureTablesProvisioned();

    const query = r'''
      query GetFolderImages($folderId: uuid!, $coupleId: String!) {
        gallery_images(
          where: {
            folder_id: { _eq: $folderId }
            couple_id: { _eq: $coupleId }
            deleted_at: { _is_null: true }
          }
          order_by: { created_at: desc }
        ) {
          id
          folder_id
          couple_id
          uploaded_by_id
          image_url
          file_id
          caption
          taken_at
          created_at
          deleted_at
        }
      }
    ''';

    try {
      final result = await _executeGraphQL(query, variables: {
        'folderId': folderId,
        'coupleId': coupleId,
      });

      final list = result['gallery_images'] as List<dynamic>? ?? [];
      return list.map((item) => GalleryImageModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      if (e.toString().contains('taken_at')) {
        const fallbackQuery = r'''
          query GetFolderImagesFallback($folderId: uuid!, $coupleId: String!) {
            gallery_images(
              where: {
                folder_id: { _eq: $folderId }
                couple_id: { _eq: $coupleId }
                deleted_at: { _is_null: true }
              }
              order_by: { created_at: desc }
            ) {
              id
              folder_id
              couple_id
              uploaded_by_id
              image_url
              file_id
              caption
              created_at
              deleted_at
            }
          }
        ''';
        final result = await _executeGraphQL(fallbackQuery, variables: {
          'folderId': folderId,
          'coupleId': coupleId,
        });
        final list = result['gallery_images'] as List<dynamic>? ?? [];
        return list.map((item) => GalleryImageModel.fromJson(item as Map<String, dynamic>)).toList();
      }
      rethrow;
    }
  }

  /// Upload image bytes to Nhost Storage and create record in gallery_images
  Future<GalleryImageModel> uploadImage({
    required String folderId,
    required String coupleId,
    required String uploadedById,
    required Uint8List imageBytes,
    required String fileName,
    String? caption,
    DateTime? takenAt,
    bool updateFolderCoverIfEmpty = true,
  }) async {
    await ensureTablesProvisioned();

    // 1. Upload to Nhost Storage
    final uploadUri = Uri.parse('$storageUrl/files');
    final request = http.MultipartRequest('POST', uploadUri);
    request.headers['x-hasura-admin-secret'] = adminSecret;
    request.headers['x-nhost-bucket-id'] = 'default';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file[]',
        imageBytes,
        filename: fileName,
      ),
    );

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 201) {
      throw Exception('Nhost Storage upload failed (${streamedResponse.statusCode}): $responseBody');
    }

    final dynamic decoded = jsonDecode(responseBody);
    final String fileId;
    if (decoded is List && decoded.isNotEmpty) {
      final first = decoded.first as Map<String, dynamic>;
      fileId = (first['id'] as String?) ?? '';
    } else if (decoded is Map<String, dynamic>) {
      if (decoded['processedFiles'] is List && (decoded['processedFiles'] as List).isNotEmpty) {
        final first = (decoded['processedFiles'] as List).first as Map<String, dynamic>;
        fileId = (first['id'] as String?) ?? '';
      } else {
        fileId = (decoded['id'] as String?) ?? '';
      }
    } else {
      fileId = '';
    }

    if (fileId.isEmpty) {
      throw Exception('Invalid Nhost Storage response: missing file ID ($responseBody)');
    }

    // Direct public access URL provided by Nhost Storage
    final publicImageUrl = '$storageUrl/files/$fileId';

    // 2. Insert image metadata via GraphQL
    const insertMutation = r'''
      mutation InsertGalleryImage(
        $folderId: uuid!
        $coupleId: String!
        $uploadedById: String!
        $imageUrl: String!
        $fileId: String
        $caption: String
        $takenAt: timestamptz
      ) {
        insert_gallery_images_one(
          object: {
            folder_id: $folderId
            couple_id: $coupleId
            uploaded_by_id: $uploadedById
            image_url: $imageUrl
            file_id: $fileId
            caption: $caption
            taken_at: $takenAt
          }
        ) {
          id
          folder_id
          couple_id
          uploaded_by_id
          image_url
          file_id
          caption
          taken_at
          created_at
        }
      }
    ''';

    Map<String, dynamic> result;
    try {
      result = await _executeGraphQL(insertMutation, variables: {
        'folderId': folderId,
        'coupleId': coupleId,
        'uploadedById': uploadedById,
        'imageUrl': publicImageUrl,
        'fileId': fileId,
        'caption': caption?.trim().isEmpty ?? true ? null : caption?.trim(),
        'takenAt': takenAt?.toIso8601String(),
      });
    } catch (e) {
      if (e.toString().contains('taken_at')) {
        const fallbackInsertMutation = r'''
          mutation InsertGalleryImageFallback(
            $folderId: uuid!
            $coupleId: String!
            $uploadedById: String!
            $imageUrl: String!
            $fileId: String
            $caption: String
          ) {
            insert_gallery_images_one(
              object: {
                folder_id: $folderId
                couple_id: $coupleId
                uploaded_by_id: $uploadedById
                image_url: $imageUrl
                file_id: $fileId
                caption: $caption
              }
            ) {
              id
              folder_id
              couple_id
              uploaded_by_id
              image_url
              file_id
              caption
              created_at
            }
          }
        ''';
        result = await _executeGraphQL(fallbackInsertMutation, variables: {
          'folderId': folderId,
          'coupleId': coupleId,
          'uploadedById': uploadedById,
          'imageUrl': publicImageUrl,
          'fileId': fileId,
          'caption': caption?.trim().isEmpty ?? true ? null : caption?.trim(),
        });
      } else {
        rethrow;
      }
    }

    final imageObj = result['insert_gallery_images_one'] as Map<String, dynamic>;
    final createdImage = GalleryImageModel.fromJson(imageObj);

    // 3. Update folder cover image if requested
    if (updateFolderCoverIfEmpty) {
      try {
        await updateFolder(folderId: folderId, coverImageUrl: publicImageUrl);
      } catch (_) {}
    }

    return createdImage;
  }

  /// Delete image from Nhost GraphQL & Storage
  Future<void> deleteImage({
    required String imageId,
    String? fileId,
  }) async {
    const mutation = r'''
      mutation DeleteGalleryImage($imageId: uuid!) {
        delete_gallery_images_by_pk(id: $imageId) {
          id
          file_id
        }
      }
    ''';

    await _executeGraphQL(mutation, variables: {'imageId': imageId});

    // Clean up file in Nhost storage if fileId is present
    if (fileId != null && fileId.isNotEmpty) {
      try {
        await http.delete(
          Uri.parse('$storageUrl/files/$fileId'),
          headers: {'x-hasura-admin-secret': adminSecret},
        );
      } catch (e) {
        debugPrint('Nhost Storage delete warning: $e');
      }
    }
  }

  /// Delete multiple images from Nhost GraphQL & Storage in batch
  Future<void> deleteImagesBatch(List<GalleryImageModel> images) async {
    for (final image in images) {
      try {
        await deleteImage(imageId: image.id, fileId: image.fileId);
      } catch (e) {
        debugPrint('NhostGalleryService: batch delete error for ${image.id}: $e');
      }
    }
  }

  /// Update image caption and optional date taken
  Future<void> updateCaption({
    required String imageId,
    required String caption,
    DateTime? takenAt,
    bool clearTakenAt = false,
  }) async {
    const mutation = r'''
      mutation UpdateImageCaption($imageId: uuid!, $caption: String, $takenAt: timestamptz) {
        update_gallery_images_by_pk(
          pk_columns: { id: $imageId }
          _set: {
            caption: $caption
            taken_at: $takenAt
          }
        ) {
          id
          caption
          taken_at
        }
      }
    ''';

    try {
      await _executeGraphQL(mutation, variables: {
        'imageId': imageId,
        'caption': caption.trim(),
        'takenAt': clearTakenAt ? null : takenAt?.toIso8601String(),
      });
    } catch (e) {
      if (e.toString().contains('taken_at')) {
        const fallbackMutation = r'''
          mutation UpdateImageCaptionFallback($imageId: uuid!, $caption: String) {
            update_gallery_images_by_pk(
              pk_columns: { id: $imageId }
              _set: {
                caption: $caption
              }
            ) {
              id
              caption
            }
          }
        ''';
        await _executeGraphQL(fallbackMutation, variables: {
          'imageId': imageId,
          'caption': caption.trim(),
        });
      } else {
        rethrow;
      }
    }
  }
}
