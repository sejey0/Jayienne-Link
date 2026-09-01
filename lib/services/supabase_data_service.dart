import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../providers/debug_provider.dart';

/// Base Supabase database service providing common database operations
/// and authentication integration for the Jayienne Link app.
class SupabaseDataService {
  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => client.auth.currentUser;
  static String? get currentUserId => currentUser?.id;

  /// Check if user is authenticated with Supabase
  static bool get isAuthenticated => currentUser != null;

  /// Get real-time stream of authentication state changes
  static Stream<AuthState> get authStateStream => client.auth.onAuthStateChange;

  /// Common error handling for database operations
  static String _handleDatabaseError(dynamic error) {
    debugPrint('Supabase Database Error: $error');

    if (error is SocketException) {
      return 'No Internet connection. You are in offline mode.';
    }

    if (error is PostgrestException) {
      switch (error.code) {
        case '23505': // Unique violation
          return 'This record already exists. Please check your data.';
        case '23503': // Foreign key violation
          return 'Related data not found. Please check your relationships.';
        case '42501': // Insufficient privilege
          return 'You don\'t have permission to perform this action.';
        case 'PGRST116': // Row not found
          return 'The requested data was not found.';
        case 'PGRST301': // Row level security violation
          return 'Access denied. Please check your permissions.';
        default:
          return 'Database error: ${error.message}';
      }
    }

    if (error is AuthException) {
      switch (error.message.toLowerCase()) {
        case 'invalid_jwt':
        case 'jwt_expired':
          return 'Your session has expired. Please log in again.';
        case 'user_not_found':
          return 'User account not found.';
        case 'invalid_credentials':
          return 'Invalid email or password.';
        default:
          return 'Authentication error: ${error.message}';
      }
    }

    return 'An unexpected error occurred: ${error.toString()}';
  }

  /// Execute a safe database operation with error handling
  static Future<T?> safeExecute<T>(
    Future<T> Function() operation, {
    String? context,
  }) async {
    if (DebugProvider.isOfflineForced) {
      debugPrint('🔌 [Simulated Offline Mode] Blocked operation: ${context ?? 'Database operation'}');
      throw const SocketException('No Internet connection (Simulated Offline Mode active)');
    }
    try {
      return await operation();
    } catch (e) {
      final errorMessage = _handleDatabaseError(e);
      debugPrint('${context ?? 'Database operation'} failed: $errorMessage');
      throw Exception(errorMessage);
    }
  }

  /// Execute a database query with automatic retries
  static Future<List<Map<String, dynamic>>> executeQuery(
    String query, {
    Map<String, dynamic>? params,
    int maxRetries = 3,
  }) async {
    return await safeExecute(() async {
          final response = await client.rpc(query, params: params ?? {});
          return List<Map<String, dynamic>>.from(response ?? []);
        }, context: 'Query: $query') ??
        [];
  }

  /// Insert a single record into a table
  static Future<Map<String, dynamic>> insertRecord(
    String table,
    Map<String, dynamic> data, {
    String? returning = '*',
  }) async {
    final result = await safeExecute(() async {
      final response =
          await client.from(table).insert(data).select(returning!).single();
      return response;
    }, context: 'Insert into $table');
    if (result == null) {
      throw Exception('Insert into $table returned null');
    }
    return result;
  }

  /// Update records in a table
  static Future<List<Map<String, dynamic>>> updateRecords(
    String table,
    Map<String, dynamic> data, {
    required String whereColumn,
    required dynamic whereValue,
    String? returning = '*',
  }) async {
    final result = await safeExecute(() async {
      final response = await client
          .from(table)
          .update(data)
          .eq(whereColumn, whereValue)
          .select(returning!);
      return List<Map<String, dynamic>>.from(response);
    }, context: 'Update in $table');
    return result ?? <Map<String, dynamic>>[];
  }

  /// Alias for updateRecords
  static Future<List<Map<String, dynamic>>> updateRecord(
    String table,
    Map<String, dynamic> data, {
    required String whereColumn,
    required dynamic whereValue,
    String? returning = '*',
  }) => updateRecords(table, data, whereColumn: whereColumn, whereValue: whereValue, returning: returning);

  /// Delete records from a table
  static Future<bool> deleteRecords(
    String table, {
    required String whereColumn,
    required dynamic whereValue,
  }) async {
    final result = await safeExecute(() async {
      await client.from(table).delete().eq(whereColumn, whereValue);
      return true;
    }, context: 'Delete from $table');
    return result ?? false;
  }

  /// Alias for deleteRecords
  static Future<bool> deleteRecord(
    String table, {
    required String whereColumn,
    required dynamic whereValue,
  }) => deleteRecords(table, whereColumn: whereColumn, whereValue: whereValue);

  /// Get records from a table with optional filtering and pagination
  static Future<List<Map<String, dynamic>>> getRecords(
    String table, {
    String? select = '*',
    String? whereColumn,
    dynamic whereValue,
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) async {
    final result = await safeExecute(() async {
      dynamic query = client.from(table).select(select!);

      if (whereColumn != null && whereValue != null) {
        query = query.eq(whereColumn, whereValue);
      }

      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    }, context: 'Get records from $table');
    return result ?? <Map<String, dynamic>>[];
  }

  /// Get a single record from a table
  static Future<Map<String, dynamic>?> getSingleRecord(
    String table, {
    String? select = '*',
    required String whereColumn,
    required dynamic whereValue,
  }) async {
    if (DebugProvider.isOfflineForced) {
      debugPrint('🔌 [Simulated Offline Mode] Blocked getSingleRecord: $table');
      throw const SocketException('No Internet connection (Simulated Offline Mode active)');
    }
    try {
      final response = await client
          .from(table)
          .select(select!)
          .eq(whereColumn, whereValue)
          .maybeSingle();
      return response;
    } catch (e) {
      final errorMessage = _handleDatabaseError(e);
      debugPrint('Get single record from $table failed: $errorMessage');
      throw Exception(errorMessage);
    }
  }

  /// Get real-time stream of records from a table
  static Stream<List<Map<String, dynamic>>> getRecordsStream(
    String table, {
    String? select = '*',
    String? whereColumn,
    dynamic whereValue,
    String? orderBy,
    bool ascending = true,
  }) {
    if (DebugProvider.isOfflineForced) {
      debugPrint('🔌 [Simulated Offline Mode] Blocked getRecordsStream for $table');
      return Stream<List<Map<String, dynamic>>>.error(
        const SocketException('No Internet connection (Simulated Offline Mode active)'),
      );
    }
    try {
      final query = client.from(table).stream(primaryKey: ['id']);

      if (whereColumn != null && whereValue != null) {
        query.eq(whereColumn, whereValue);
      }

      if (orderBy != null) {
        query.order(orderBy, ascending: ascending);
      }

      return query.transform(
        StreamTransformer.fromHandlers(
          handleData: (data, sink) {
            sink.add(List<Map<String, dynamic>>.from(data));
          },
          handleError: (error, stack, sink) {
            debugPrint('Stream error for $table: $error');
          },
        ),
      );
    } catch (e) {
      debugPrint('Stream error for $table: $e');
      return Stream<List<Map<String, dynamic>>>.error(
        _handleDatabaseError(e),
      );
    }
  }

  /// Get real-time stream of a single record
  static Stream<Map<String, dynamic>?> getSingleRecordStream(
    String table, {
    String? select = '*',
    required String whereColumn,
    required dynamic whereValue,
  }) {
    if (DebugProvider.isOfflineForced) {
      debugPrint('🔌 [Simulated Offline Mode] Blocked getSingleRecordStream for $table');
      return Stream.error(
        const SocketException('No Internet connection (Simulated Offline Mode active)'),
      );
    }
    try {
      final query = client
          .from(table)
          .stream(primaryKey: ['id']).eq(whereColumn, whereValue);

      return query.transform(
        StreamTransformer.fromHandlers(
          handleData: (records, sink) {
            final typed = List<Map<String, dynamic>>.from(records);
            sink.add(typed.isNotEmpty ? typed.first : null);
          },
          handleError: (error, stack, sink) {
            debugPrint('Single record stream error for $table: $error');
          },
        ),
      );
    } catch (e) {
      debugPrint('Single record stream error for $table: $e');
      return Stream.error(_handleDatabaseError(e));
    }
  }

  /// Execute a raw SQL function/procedure
  static Future<List<Map<String, dynamic>>> executeProcedure(
    String procedureName, {
    Map<String, dynamic>? params,
  }) async {
    return await safeExecute(() async {
          final response =
              await client.rpc(procedureName, params: params ?? {});
          // Handle scalar return values (e.g., UUID from create_couple)
          if (response is String || response is num || response is bool) {
            return <Map<String, dynamic>>[
              {procedureName: response}
            ];
          }
          // Handle null response
          if (response == null) {
            return <Map<String, dynamic>>[];
          }
          // Handle list of maps (normal case)
          final list = response as List;
          return list
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        }, context: 'Execute procedure: $procedureName') ??
        <Map<String, dynamic>>[];
  }

  /// Batch operations within a transaction
  static Future<T> executeTransaction<T>(
    Future<T> Function() operation,
  ) async {
    final result = await safeExecute(operation, context: 'Transaction');
    if (result == null) {
      throw Exception('Transaction returned null');
    }
    return result;
  }

  /// Test database connectivity
  static Future<bool> testConnectivity() async {
    if (DebugProvider.isOfflineForced) {
      debugPrint('🔌 [Simulated Offline Mode] testConnectivity: DISCONNECTED');
      return false;
    }
    try {
      // Simple query to test connection
      await client.from('users').select('count').limit(1);
      debugPrint('✅ Supabase Database: Connected');
      return true;
    } catch (e) {
      debugPrint('❌ Supabase Database: Connection failed - $e');
      return false;
    }
  }

  /// Get database statistics and health
  static Future<Map<String, dynamic>> getDatabaseHealth() async {
    if (DebugProvider.isOfflineForced) {
      return {
        'connected': false,
        'latency_ms': 0,
        'database_type': 'Simulated Offline Mode',
        'error': 'Network is simulated offline (Disconnected from Wi-Fi)',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
    final result = await safeExecute(() async {
      // Get basic statistics from each table
      final stats = <String, dynamic>{};
      final stopwatch = Stopwatch()..start();

      try {
        final userCount =
            await client.from('users').select('*').count(CountOption.exact);
        stats['users_count'] = userCount.count;
      } catch (e) {
        stats['users_count'] = 'Error: $e';
      }

      try {
        final coupleCount =
            await client.from('couples').select('*').count(CountOption.exact);
        stats['couples_count'] = coupleCount.count;
      } catch (e) {
        stats['couples_count'] = 'Error: $e';
      }

      try {
        final mediaCount =
            await client.from('secret_media').select('*').count(CountOption.exact);
        stats['secret_media_count'] = mediaCount.count;
      } catch (_) {
        stats['secret_media_count'] = 0;
      }

      try {
        final movieCount =
            await client.from('movies').select('*').count(CountOption.exact);
        stats['movies_count'] = movieCount.count;
      } catch (_) {
        stats['movies_count'] = 0;
      }

      stopwatch.stop();
      stats['latency_ms'] = stopwatch.elapsedMilliseconds;
      stats['database_type'] = 'Supabase PostgreSQL';
      stats['connected'] = true;
      stats['timestamp'] = DateTime.now().toIso8601String();

      return stats;
    }, context: 'Database health check');
    return result ?? {'connected': false, 'error': 'Check failed'};
  }

  /// Initialize database and run any setup if needed
  static Future<bool> initializeDatabase() async {
    try {
      debugPrint('🔄 Initializing Supabase database connection...');

      // Test basic connectivity
      final isConnected = await testConnectivity();
      if (!isConnected) return false;

      // Clean up expired invite codes
      try {
        await client.rpc('cleanup_expired_invite_codes');
        debugPrint('✅ Cleaned up expired invite codes');
      } catch (e) {
        debugPrint('⚠️ Could not clean up invite codes: $e');
      }

      debugPrint('✅ Supabase database initialized successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to initialize Supabase database: $e');
      return false;
    }
  }
}
