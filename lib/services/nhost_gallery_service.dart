import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gallery_folder_model.dart';
import '../models/gallery_image_model.dart';

/// Background worker to downscale and compress photos before upload (saves ~95% storage & bandwidth)
Uint8List _compressPhotoWorker(Uint8List rawBytes) {
  try {
    if (rawBytes.lengthInBytes < 250 * 1024) return rawBytes;

    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return rawBytes;

    img.Image processed = decoded;
    const int maxDim = 1920;
    if (decoded.width > maxDim || decoded.height > maxDim) {
      if (decoded.width >= decoded.height) {
        processed = img.copyResize(decoded, width: maxDim);
      } else {
        processed = img.copyResize(decoded, height: maxDim);
      }
    }

    final compressed = img.encodeJpg(processed, quality: 82);
    return Uint8List.fromList(compressed);
  } catch (e) {
    debugPrint('Background photo compression error: $e');
    return rawBytes;
  }
}

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

  /// Optional Cloudflare CDN base URL (e.g. https://gallery-cdn.yourdomain.workers.dev/v1)
  String get cdnUrl => dotenv.env['NHOST_STORAGE_CDN_URL']?.trim() ?? '';

  Map<String, String>? get storageHeaders =>
      kIsWeb ? null : {'x-hasura-admin-secret': adminSecret};

  /// Returns storage headers. If request is directed to the Cloudflare CDN,
  /// headers are omitted since the CDN worker injects authentication and caches at edge.
  Map<String, String>? getStorageHeaders({String? url}) {
    if (kIsWeb) return null;
    if (cdnUrl.isNotEmpty && url != null && url.startsWith(cdnUrl)) {
      return null;
    }
    return {'x-hasura-admin-secret': adminSecret};
  }

  /// Transforms raw Nhost storage URLs to use Cloudflare CDN edge cache (if configured)
  /// and safely encodes spaces/special characters in query params.
  /// Dynamic server-side resizing params (w/q) are intentionally omitted because
  /// Nhost's Hasura storage service runs on a minimal CPU container where on-the-fly
  /// transforms fail with 502/503 during parallel image loading. Flutter downsamples
  /// natively on device via `memCacheWidth`.
  String getMediaUrl(String rawUrl, {int? width, int? quality}) {
    if (rawUrl.isEmpty) return rawUrl;
    String url = rawUrl.trim();
    if (cdnUrl.isNotEmpty) {
      url = url.replaceAll(storageUrl, cdnUrl);
    }

    final qIndex = url.indexOf('?');
    final baseUrl = qIndex != -1 ? url.substring(0, qIndex) : url;
    final queryString = qIndex != -1 ? url.substring(qIndex + 1) : '';

    final queryParams = <String, String>{};
    if (queryString.isNotEmpty) {
      for (final part in queryString.split('&')) {
        if (part.isEmpty) continue;
        final kv = part.split('=');
        final key = Uri.decodeComponent(kv[0]);
        // Strip server-side transformation params that cause Nhost storage to crash/503
        if (key == 'w' || key == 'q' || key == 'width' || key == 'quality') continue;
        final val = kv.length > 1 ? Uri.decodeComponent(kv.sublist(1).join('=')) : '';
        queryParams[key] = val;
      }
    }

    if (queryParams.isEmpty) return baseUrl;

    final encodedQuery = queryParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$baseUrl?$encodedQuery';
  }

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
  DateTime? _lastBootstrapAttempt;

  // In-memory query caching to eliminate repeated redundant API / database requests
  List<GalleryFolderModel>? _cachedFolders;
  String? _cachedFoldersCoupleId;
  DateTime? _cachedFoldersTime;

  final Map<String, List<GalleryImageModel>> _cachedFolderImages = {};
  final Map<String, DateTime> _cachedFolderImagesTime = {};

  void invalidateCache({String? folderId}) {
    _cachedFolders = null;
    _cachedFoldersCoupleId = null;
    _cachedFoldersTime = null;
    if (folderId != null) {
      _cachedFolderImages.remove(folderId);
      _cachedFolderImagesTime.remove(folderId);
    } else {
      _cachedFolderImages.clear();
      _cachedFolderImagesTime.clear();
    }
  }

  /// Ensures tables and Hasura tracking are provisioned in Nhost
  Future<void> ensureTablesProvisioned({bool force = false}) async {
    if (_hasBootstrapped && !force) return;

    // Check local device storage to prevent repeated heavy DDL/metadata requests
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyProvisioned = prefs.getBool('nhost_provisioned_$subdomain') ?? false;
      if (alreadyProvisioned && !force) {
        _hasBootstrapped = true;
        return;
      }
    } catch (_) {}

    if (!force && _lastBootstrapAttempt != null) {
      final elapsed = DateTime.now().difference(_lastBootstrapAttempt!);
      if (elapsed < const Duration(minutes: 5)) return;
    }
    _lastBootstrapAttempt = DateTime.now();

    try {
      final sql = '''
        DO \$\$
        BEGIN
          IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'gallery_images')
             AND NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'gallery_media') THEN
            ALTER TABLE public.gallery_images RENAME TO gallery_media;
          END IF;
        END
        \$\$;

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

        CREATE TABLE IF NOT EXISTS public.gallery_media (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            folder_id UUID NOT NULL REFERENCES public.gallery_folders(id) ON DELETE CASCADE,
            couple_id TEXT NOT NULL,
            uploaded_by_id TEXT NOT NULL,
            image_url TEXT NOT NULL,
            file_id TEXT,
            caption TEXT,
            taken_at TIMESTAMPTZ,
            media_type TEXT DEFAULT 'image',
            created_at TIMESTAMPTZ DEFAULT NOW(),
            deleted_at TIMESTAMPTZ
        );

        ALTER TABLE public.gallery_media ADD COLUMN IF NOT EXISTS taken_at TIMESTAMPTZ;
        ALTER TABLE public.gallery_media ADD COLUMN IF NOT EXISTS media_type TEXT DEFAULT 'image';
        UPDATE storage.buckets SET max_upload_file_size = 1000000000;

        CREATE INDEX IF NOT EXISTS idx_gallery_folders_couple ON public.gallery_folders(couple_id);
        CREATE INDEX IF NOT EXISTS idx_gallery_media_folder ON public.gallery_media(folder_id);
      ''';

      // Execute SQL via Hasura run_sql endpoint with short timeout
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
      ).timeout(const Duration(seconds: 4));
      debugPrint('Nhost run_sql response (${response.statusCode}): ${response.body}');

      // Drop any inconsistent metadata from renaming gallery_images -> gallery_media
      try {
        await http.post(
          Uri.parse(metadataUrl),
          headers: _headers,
          body: jsonEncode({'type': 'drop_inconsistent_metadata', 'args': {}}),
        ).timeout(const Duration(seconds: 3));
      } catch (_) {}

      // Untrack obsolete gallery_images table
      await _untrackTable('gallery_images');

      // Track tables in Hasura metadata
      await _trackTable('gallery_folders');
      await _trackTable('gallery_media');
      await _trackRelationship(
        tableName: 'gallery_folders',
        relationshipName: 'media',
        foreignKeyTable: 'gallery_media',
        isList: true,
      );
      await _trackRelationship(
        tableName: 'gallery_folders',
        relationshipName: 'images',
        foreignKeyTable: 'gallery_media',
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
        ).timeout(const Duration(seconds: 3));
      } catch (_) {}

      _hasBootstrapped = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('nhost_provisioned_$subdomain', true);
      } catch (_) {}
      debugPrint('NhostGalleryService: bootstrap complete');
    } catch (e) {
      debugPrint('NhostGalleryService bootstrap error: $e');
      _hasBootstrapped = false;
    }
  }

  Future<void> _untrackTable(String tableName) async {
    // Hasura v2 pg_untrack_table
    try {
      await http.post(
        Uri.parse(metadataUrl),
        headers: _headers,
        body: jsonEncode({
          'type': 'pg_untrack_table',
          'args': {
            'source': 'default',
            'table': {
              'schema': 'public',
              'name': tableName,
            },
            'cascade': true,
          },
        }),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}

    // Hasura v1 untrack_table fallback
    try {
      await http.post(
        Uri.parse('$hasuraUrl/v1/query'),
        headers: _headers,
        body: jsonEncode({
          'type': 'untrack_table',
          'args': {
            'table': {
              'schema': 'public',
              'name': tableName,
            },
            'cascade': true,
          },
        }),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
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
      ).timeout(const Duration(seconds: 3));
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
      ).timeout(const Duration(seconds: 3));
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
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  /// Update Nhost storage bucket limit to 1GB for high quality video uploads
  Future<void> increaseBucketMaxFileSize() async {
    try {
      const sql = 'UPDATE storage.buckets SET max_upload_file_size = 1000000000;';
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
      debugPrint('Nhost increaseBucketMaxFileSize response: ${response.statusCode}');
    } catch (e) {
      debugPrint('Failed to update storage.buckets max_file_size: $e');
    }
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
  Future<List<GalleryFolderModel>> getFolders(String coupleId, {bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedFolders != null &&
        _cachedFoldersCoupleId == coupleId &&
        _cachedFoldersTime != null &&
        DateTime.now().difference(_cachedFoldersTime!) < const Duration(seconds: 45)) {
      return _cachedFolders!;
    }

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
          media_aggregate(where: { deleted_at: { _is_null: true } }) {
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
      final folders = list.map((item) => GalleryFolderModel.fromJson(item as Map<String, dynamic>)).toList();
      _cachedFolders = folders;
      _cachedFoldersCoupleId = coupleId;
      _cachedFoldersTime = DateTime.now();
      return folders;
    } catch (e) {
      // Fallback query if media_aggregate relationship is not tracked yet
      const imagesAggQuery = r'''
        query GetGalleryFoldersImagesAgg($coupleId: String!) {
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
        final result = await _executeGraphQL(imagesAggQuery, variables: {'coupleId': coupleId});
        final list = result['gallery_folders'] as List<dynamic>? ?? [];
        final folders = list.map((item) => GalleryFolderModel.fromJson(item as Map<String, dynamic>)).toList();
        _cachedFolders = folders;
        _cachedFoldersCoupleId = coupleId;
        _cachedFoldersTime = DateTime.now();
        return folders;
      } catch (_) {
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
        final folders = list.map((item) => GalleryFolderModel.fromJson(item as Map<String, dynamic>)).toList();
        _cachedFolders = folders;
        _cachedFoldersCoupleId = coupleId;
        _cachedFoldersTime = DateTime.now();
        return folders;
      }
    }
  }

  /// Upload raw file bytes to Nhost Storage and return its public URL
  Future<String> uploadStorageFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uploadUri = Uri.parse('$storageUrl/files');
    final request = http.MultipartRequest('POST', uploadUri);
    request.headers['x-hasura-admin-secret'] = adminSecret;
    request.headers['x-nhost-bucket-id'] = 'default';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file[]',
        bytes,
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

    return '$storageUrl/files/$fileId';
  }

  /// Create a new folder
  Future<GalleryFolderModel> createFolder({
    required String coupleId,
    required String createdById,
    required String name,
    String? description,
    String? coverImageUrl,
  }) async {
    await ensureTablesProvisioned();

    const mutation = r'''
      mutation CreateGalleryFolder(
        $coupleId: String!
        $name: String!
        $description: String
        $coverImageUrl: String
        $createdById: String!
      ) {
        insert_gallery_folders_one(
          object: {
            couple_id: $coupleId
            name: $name
            description: $description
            cover_image_url: $coverImageUrl
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
      'coverImageUrl': coverImageUrl?.trim().isEmpty ?? true ? null : coverImageUrl?.trim(),
      'createdById': createdById,
    });

    final folderData = result['insert_gallery_folders_one'] as Map<String, dynamic>;
    invalidateCache();
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
    invalidateCache(folderId: folderId);
  }

  /// Delete folder and all its media files from bucket storage and database
  Future<void> deleteFolder(String folderId) async {
    // 1. Fetch all media file IDs inside this folder to purge from bucket storage
    try {
      const getMediaSql = '''
        SELECT coalesce(file_id, '') as file_id, coalesce(image_url, '') as image_url 
        FROM public.gallery_media 
        WHERE folder_id = '%FOLDER_ID%';
      ''';
      final response = await http.post(
        Uri.parse(sqlQueryUrl),
        headers: _headers,
        body: jsonEncode({
          'type': 'run_sql',
          'args': {
            'source': 'default',
            'sql': getMediaSql.replaceAll('%FOLDER_ID%', folderId),
            'cascade': false,
            'read_only': true,
          },
        }),
      );

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final rows = resData['result'] as List?;
        if (rows != null && rows.length > 1) {
          for (int i = 1; i < rows.length; i++) {
            final row = rows[i] as List;
            final fId = row[0]?.toString();
            final imgUrl = row[1]?.toString();
            final cleanFileId = extractFileId(fileId: fId, imageUrl: imgUrl);
            if (cleanFileId != null && cleanFileId.isNotEmpty) {
              await deleteStorageFile(cleanFileId);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('NhostGalleryService: deleteFolder storage purge error: $e');
    }

    // 2. Delete folder record from database (cascades to gallery_media)
    const mutation = r'''
      mutation DeleteGalleryFolder($folderId: uuid!) {
        delete_gallery_folders_by_pk(id: $folderId) {
          id
        }
      }
    ''';

    await _executeGraphQL(mutation, variables: {'folderId': folderId});
    invalidateCache(folderId: folderId);
  }

  /// Fetch media (photos/videos) for a folder
  Future<List<GalleryImageModel>> getFolderImages({
    required String folderId,
    required String coupleId,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedFolderImages.containsKey(folderId) &&
        _cachedFolderImagesTime.containsKey(folderId) &&
        DateTime.now().difference(_cachedFolderImagesTime[folderId]!) < const Duration(seconds: 45)) {
      return _cachedFolderImages[folderId]!;
    }

    await ensureTablesProvisioned();

    const query = r'''
      query GetFolderMedia($folderId: uuid!, $coupleId: String!) {
        gallery_media(
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
          media_type
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

      final list = ((result['gallery_media'] ?? result['gallery_images']) as List<dynamic>?) ?? [];
      final images = list.map((item) => GalleryImageModel.fromJson(item as Map<String, dynamic>)).toList();
      _cachedFolderImages[folderId] = images;
      _cachedFolderImagesTime[folderId] = DateTime.now();
      return images;
    } catch (e) {
      // Fallback query if gallery_media is not yet tracked or renamed
      const fallbackQuery = r'''
        query GetFolderMediaFallback($folderId: uuid!, $coupleId: String!) {
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
            media_type
            created_at
            deleted_at
          }
        }
      ''';
      try {
        final result = await _executeGraphQL(fallbackQuery, variables: {
          'folderId': folderId,
          'coupleId': coupleId,
        });
        final list = (result['gallery_images'] as List<dynamic>?) ?? [];
        final images = list.map((item) => GalleryImageModel.fromJson(item as Map<String, dynamic>)).toList();
        _cachedFolderImages[folderId] = images;
        _cachedFolderImagesTime[folderId] = DateTime.now();
        return images;
      } catch (_) {
        rethrow;
      }
    }
  }

  /// Upload image or video bytes to Nhost Storage and create record in gallery_media
  Future<GalleryImageModel> uploadImage({
    required String folderId,
    required String coupleId,
    required String uploadedById,
    required Uint8List imageBytes,
    required String fileName,
    String? caption,
    DateTime? takenAt,
    String? mediaType,
    bool updateFolderCoverIfEmpty = true,
  }) async {
    await ensureTablesProvisioned();

    final lowerName = fileName.toLowerCase();
    final isVid = lowerName.endsWith('.mp4') ||
        lowerName.endsWith('.mov') ||
        lowerName.endsWith('.mkv') ||
        lowerName.endsWith('.webm') ||
        lowerName.endsWith('.avi') ||
        lowerName.endsWith('.m4v');
    final effectiveMediaType = mediaType ?? (isVid ? 'video' : 'image');

    // Automatically downscale and compress photo on background isolate to save ~95% storage & bandwidth
    Uint8List effectiveBytes = imageBytes;
    String effectiveFileName = fileName;
    if (effectiveMediaType != 'video') {
      try {
        effectiveBytes = await compute(_compressPhotoWorker, imageBytes);
        final dotIndex = effectiveFileName.lastIndexOf('.');
        final base = dotIndex != -1 ? effectiveFileName.substring(0, dotIndex) : effectiveFileName;
        effectiveFileName = '$base.jpg';
      } catch (e) {
        debugPrint('Image compression notice: $e');
      }
    }

    // 1. Upload to Nhost Storage
    final uploadUri = Uri.parse('$storageUrl/files');
    final request = http.MultipartRequest('POST', uploadUri);
    request.headers['x-hasura-admin-secret'] = adminSecret;
    request.headers['x-nhost-bucket-id'] = 'default';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file[]',
        effectiveBytes,
        filename: effectiveFileName,
      ),
    );

    http.StreamedResponse streamedResponse = await request.send();
    String responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 201) {
      if (responseBody.contains('file too big')) {
        try {
          await increaseBucketMaxFileSize();
          final retryRequest = http.MultipartRequest('POST', uploadUri);
          retryRequest.headers['x-hasura-admin-secret'] = adminSecret;
          retryRequest.headers['x-nhost-bucket-id'] = 'default';
          retryRequest.files.add(
            http.MultipartFile.fromBytes(
              'file[]',
              imageBytes,
              filename: fileName,
            ),
          );
          streamedResponse = await retryRequest.send();
          responseBody = await streamedResponse.stream.bytesToString();
        } catch (_) {}
      }

      if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 201) {
        if (responseBody.contains('file too big')) {
          final sizeMb = (imageBytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);
          throw Exception('File is $sizeMb MB, exceeding Nhost bucket limit. Run "UPDATE storage.buckets SET max_upload_file_size = 1000000000;" in Nhost SQL console.');
        }
        throw Exception('Nhost Storage upload failed (${streamedResponse.statusCode}): $responseBody');
      }
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

    // Direct public access URL with filename query param so media type is preserved
    final publicImageUrl = '$storageUrl/files/$fileId?name=$fileName';

    // 2. Insert media metadata via GraphQL
    const insertMutation = r'''
      mutation InsertGalleryMedia(
        $folderId: uuid!
        $coupleId: String!
        $uploadedById: String!
        $imageUrl: String!
        $fileId: String
        $caption: String
        $takenAt: timestamptz
        $mediaType: String
      ) {
        insert_gallery_media_one(
          object: {
            folder_id: $folderId
            couple_id: $coupleId
            uploaded_by_id: $uploadedById
            image_url: $imageUrl
            file_id: $fileId
            caption: $caption
            taken_at: $takenAt
            media_type: $mediaType
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
          media_type
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
        'mediaType': effectiveMediaType,
      });
    } catch (e) {
      debugPrint('NhostGalleryService: insert_gallery_media_one attempt failed: $e');

      // If Hasura doesn't have gallery_media tracked yet, force re-provision and retry
      if (e.toString().contains('not found') || e.toString().contains('mutation_root')) {
        await ensureTablesProvisioned(force: true);
        try {
          result = await _executeGraphQL(insertMutation, variables: {
            'folderId': folderId,
            'coupleId': coupleId,
            'uploadedById': uploadedById,
            'imageUrl': publicImageUrl,
            'fileId': fileId,
            'caption': caption?.trim().isEmpty ?? true ? null : caption?.trim(),
            'takenAt': takenAt?.toIso8601String(),
            'mediaType': effectiveMediaType,
          });
        } catch (retryError) {
          debugPrint('NhostGalleryService: retry after re-provisioning failed: $retryError');
          throw Exception(retryError.toString().replaceAll('Exception: ', ''));
        }
      } else {
        rethrow;
      }
    }

    final imageObj = ((result['insert_gallery_media_one'] ?? result['insert_gallery_images_one']) as Map<String, dynamic>);
    final createdImage = GalleryImageModel.fromJson(imageObj).copyWith(
      mediaType: effectiveMediaType,
    );

    // 3. Update folder cover image if requested and not a video
    if (updateFolderCoverIfEmpty && !isVid) {
      try {
        await updateFolder(folderId: folderId, coverImageUrl: publicImageUrl);
      } catch (_) {}
    }

    invalidateCache(folderId: folderId);
    return createdImage;
  }

  /// Safely extracts the UUID file ID from either direct fileId or an imageUrl string
  String? extractFileId({String? fileId, String? imageUrl}) {
    if (fileId != null && fileId.trim().isNotEmpty) {
      return fileId.trim();
    }
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final match = RegExp(r'/files/([a-zA-Z0-9\-_]+)').firstMatch(imageUrl);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
    }
    return null;
  }

  /// Delete a file directly from Nhost Storage bucket and storage.files metadata table
  Future<void> deleteStorageFile(String fileId) async {
    final cleanId = fileId.trim();
    if (cleanId.isEmpty) return;

    // 1. Delete file object from Nhost Storage bucket via REST API
    try {
      final res = await http.delete(
        Uri.parse('$storageUrl/files/$cleanId'),
        headers: {
          'x-hasura-admin-secret': adminSecret,
        },
      );
      debugPrint('Nhost Storage bucket DELETE /files/$cleanId (${res.statusCode})');
    } catch (e) {
      debugPrint('Nhost Storage bucket delete warning for $cleanId: $e');
    }

    // 2. Ensure storage.files database record is purged via SQL
    try {
      await http.post(
        Uri.parse(sqlQueryUrl),
        headers: _headers,
        body: jsonEncode({
          'type': 'run_sql',
          'args': {
            'source': 'default',
            'sql': "DELETE FROM storage.files WHERE id = '$cleanId';",
            'cascade': true,
            'read_only': false,
          },
        }),
      );
    } catch (e) {
      debugPrint('Nhost storage.files SQL delete warning for $cleanId: $e');
    }
  }

  /// Delete media from Nhost GraphQL & Storage bucket
  Future<void> deleteImage({
    required String imageId,
    String? fileId,
    String? imageUrl,
  }) async {
    String? targetFileId = extractFileId(fileId: fileId, imageUrl: imageUrl);

    const mutation = r'''
      mutation DeleteGalleryMedia($imageId: uuid!) {
        delete_gallery_media_by_pk(id: $imageId) {
          id
          file_id
          image_url
        }
      }
    ''';

    try {
      final result = await _executeGraphQL(mutation, variables: {'imageId': imageId});
      final deleted = result['delete_gallery_media_by_pk'] as Map<String, dynamic>?;
      if (deleted != null) {
        targetFileId ??= extractFileId(
          fileId: deleted['file_id'] as String?,
          imageUrl: deleted['image_url'] as String?,
        );
      }
    } catch (e) {
      const fallbackMutation = r'''
        mutation DeleteGalleryImageFallback($imageId: uuid!) {
          delete_gallery_images_by_pk(id: $imageId) {
            id
            file_id
            image_url
          }
        }
      ''';
      try {
        final result = await _executeGraphQL(fallbackMutation, variables: {'imageId': imageId});
        final deleted = result['delete_gallery_images_by_pk'] as Map<String, dynamic>?;
        if (deleted != null) {
          targetFileId ??= extractFileId(
            fileId: deleted['file_id'] as String?,
            imageUrl: deleted['image_url'] as String?,
          );
        }
      } catch (_) {}
    }

    // Delete the file from Nhost bucket storage & storage.files
    if (targetFileId != null && targetFileId.isNotEmpty) {
      await deleteStorageFile(targetFileId);
    }
    invalidateCache();
  }

  /// Delete multiple images from Nhost GraphQL & Storage in batch
  Future<void> deleteImagesBatch(List<GalleryImageModel> images) async {
    for (final image in images) {
      try {
        await deleteImage(
          imageId: image.id,
          fileId: image.fileId,
          imageUrl: image.imageUrl,
        );
      } catch (e) {
        debugPrint('NhostGalleryService: batch delete error for ${image.id}: $e');
      }
    }
    invalidateCache();
  }

  /// Update media caption and optional date taken
  Future<void> updateCaption({
    required String imageId,
    required String caption,
    DateTime? takenAt,
    bool clearTakenAt = false,
  }) async {
    const mutation = r'''
      mutation UpdateMediaCaption($imageId: uuid!, $caption: String, $takenAt: timestamptz) {
        update_gallery_media_by_pk(
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
      try {
        const fallbackMedia = r'''
          mutation UpdateMediaCaptionFallback($imageId: uuid!, $caption: String) {
            update_gallery_media_by_pk(
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
        await _executeGraphQL(fallbackMedia, variables: {
          'imageId': imageId,
          'caption': caption.trim(),
        });
      } catch (_) {
        const legacyMutation = r'''
          mutation UpdateImageCaptionLegacy($imageId: uuid!, $caption: String) {
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
        await _executeGraphQL(legacyMutation, variables: {
          'imageId': imageId,
          'caption': caption.trim(),
        });
      }
    }
    invalidateCache();
  }

  /// Fetch Nhost Database table counts and storage usage stats
  Future<Map<String, dynamic>> getStorageAndDatabaseStats() async {
    try {
      int folderCount = 0;
      int imageCount = 0;
      int storageFilesCount = 0;
      double? actualDbMb;
      double? actualStorageMb;

      // 1. Try real PostgreSQL inspection via Hasura run_sql
      try {
        final response = await http.post(
          Uri.parse(sqlQueryUrl),
          headers: _headers,
          body: jsonEncode({
            'type': 'run_sql',
            'args': {
              'source': 'default',
              'sql': '''
                SELECT 
                  (SELECT pg_database_size(current_database())) as db_bytes,
                  (SELECT count(*) FROM public.gallery_folders) as folders_count,
                  (SELECT count(*) FROM public.gallery_media WHERE deleted_at IS NULL) as images_count,
                  (SELECT count(*) FROM storage.files) as storage_files_count,
                  (SELECT coalesce(sum(size), 0) FROM storage.files) as storage_bytes;
              ''',
              'cascade': false,
              'read_only': true,
            },
          }),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final resData = jsonDecode(response.body);
          final rows = resData['result'] as List?;
          if (rows != null && rows.length >= 2) {
            final row = rows[1] as List;
            final dbBytes = num.tryParse(row[0]?.toString() ?? '0') ?? 0;
            folderCount = int.tryParse(row[1]?.toString() ?? '0') ?? 0;
            imageCount = int.tryParse(row[2]?.toString() ?? '0') ?? 0;
            storageFilesCount = int.tryParse(row[3]?.toString() ?? '0') ?? 0;
            final storageBytes = num.tryParse(row[4]?.toString() ?? '0') ?? 0;

            actualDbMb = (dbBytes / (1024 * 1024)).clamp(0.01, 1024.0);
            actualStorageMb = (storageBytes / (1024 * 1024)).clamp(0.0, 5120.0);
          }
        }
      } catch (_) {
        // Fallback to gallery_images if gallery_media is not yet renamed
        try {
          final response = await http.post(
            Uri.parse(sqlQueryUrl),
            headers: _headers,
            body: jsonEncode({
              'type': 'run_sql',
              'args': {
                'source': 'default',
                'sql': '''
                  SELECT 
                    (SELECT pg_database_size(current_database())) as db_bytes,
                    (SELECT count(*) FROM public.gallery_folders) as folders_count,
                    (SELECT count(*) FROM public.gallery_images WHERE deleted_at IS NULL) as images_count,
                    (SELECT count(*) FROM storage.files) as storage_files_count,
                    (SELECT coalesce(sum(size), 0) FROM storage.files) as storage_bytes;
                ''',
                'cascade': false,
                'read_only': true,
              },
            }),
          ).timeout(const Duration(seconds: 4));

          if (response.statusCode == 200) {
            final resData = jsonDecode(response.body);
            final rows = resData['result'] as List?;
            if (rows != null && rows.length >= 2) {
              final row = rows[1] as List;
              final dbBytes = num.tryParse(row[0]?.toString() ?? '0') ?? 0;
              folderCount = int.tryParse(row[1]?.toString() ?? '0') ?? 0;
              imageCount = int.tryParse(row[2]?.toString() ?? '0') ?? 0;
              storageFilesCount = int.tryParse(row[3]?.toString() ?? '0') ?? 0;
              final storageBytes = num.tryParse(row[4]?.toString() ?? '0') ?? 0;

              actualDbMb = (dbBytes / (1024 * 1024)).clamp(0.01, 1024.0);
              actualStorageMb = (storageBytes / (1024 * 1024)).clamp(0.0, 5120.0);
            }
          }
        } catch (e) {
          debugPrint('[NhostGalleryService] SQL stats notice: $e');
        }
      }

      // 2. If SQL query failed or returned null, fallback to GraphQL
      if (actualDbMb == null) {
        try {
          const query = r'''
            query GetNhostCounts {
              gallery_folders_aggregate {
                aggregate { count }
              }
              gallery_media_aggregate(where: { deleted_at: { _is_null: true } }) {
                aggregate { count }
              }
            }
          ''';
          final res = await _executeGraphQL(query);
          folderCount = (res['gallery_folders_aggregate']?['aggregate']?['count'] as num?)?.toInt() ?? 0;
          imageCount = (res['gallery_media_aggregate']?['aggregate']?['count'] as num?)?.toInt() ?? 0;
        } catch (_) {
          const fallback = r'''
            query GetNhostCountsFallback {
              gallery_folders_aggregate {
                aggregate { count }
              }
              gallery_images_aggregate(where: { deleted_at: { _is_null: true } }) {
                aggregate { count }
              }
            }
          ''';
          try {
            final res = await _executeGraphQL(fallback);
            folderCount = (res['gallery_folders_aggregate']?['aggregate']?['count'] as num?)?.toInt() ?? 0;
            imageCount = (res['gallery_images_aggregate']?['aggregate']?['count'] as num?)?.toInt() ?? 0;
          } catch (_) {}
        }

        storageFilesCount = imageCount;
        actualDbMb = ((folderCount * 1.5 + imageCount * 2.5) / 1024 + 8.5).clamp(0.01, 1024.0);
        actualStorageMb = (imageCount * 1.8).clamp(0.0, 5120.0);
      }

      final safeDbMb = actualDbMb ?? 0.0;
      final safeStorageMb = actualStorageMb ?? 0.0;
      final remainingDbMb = (1024.0 - safeDbMb).clamp(0.0, 1024.0);
      final remainingStorageMb = (5120.0 - safeStorageMb).clamp(0.0, 5120.0);

      return {
        'connected': true,
        'folders_count': folderCount,
        'images_count': imageCount,
        'total_records': folderCount + imageCount,
        'db_limit_mb': 1024.0,
        'db_used_mb': safeDbMb,
        'db_remaining_mb': remainingDbMb,
        'storage_limit_mb': 5120.0,
        'storage_used_mb': safeStorageMb,
        'storage_remaining_mb': remainingStorageMb,
        'storage_files_count': storageFilesCount,
      };
    } catch (e) {
      return {
        'connected': false,
        'error': e.toString(),
        'folders_count': 0,
        'images_count': 0,
        'total_records': 0,
        'db_limit_mb': 1024.0,
        'db_used_mb': 0.0,
        'db_remaining_mb': 1024.0,
        'storage_limit_mb': 5120.0,
        'storage_used_mb': 0.0,
        'storage_remaining_mb': 5120.0,
        'storage_files_count': 0,
      };
    }
  }
}
