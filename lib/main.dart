import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:jayienne_link/app.dart';
import 'package:jayienne_link/providers/auth_provider.dart';
import 'package:jayienne_link/providers/couple_provider.dart';
import 'package:jayienne_link/providers/debug_provider.dart';
import 'package:jayienne_link/providers/heartbeat_provider.dart';
import 'package:jayienne_link/providers/location_provider.dart';
import 'package:jayienne_link/providers/mood_provider.dart';
import 'package:jayienne_link/providers/photo_message_provider.dart';
import 'package:jayienne_link/providers/secret_media_provider.dart';
import 'package:jayienne_link/providers/theme_provider.dart';
import 'package:jayienne_link/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:jayienne_link/services/background_location_service.dart';
import 'package:jayienne_link/services/supabase_auth_service.dart';
import 'package:jayienne_link/services/supabase_couple_service.dart';
import 'package:jayienne_link/services/supabase_data_service.dart';
import 'package:jayienne_link/services/supabase_heartbeat_service.dart';
import 'package:jayienne_link/services/supabase_mood_service.dart';
import 'package:jayienne_link/services/supabase_photo_message_service.dart';
import 'package:jayienne_link/services/supabase_secret_media_service.dart';
import 'package:jayienne_link/services/supabase_storage_service.dart';
import 'package:jayienne_link/services/supabase_user_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // Debug Supabase in development
  if (kDebugMode) {
    await _debugSupabase();
  }

  // Initialize background location service (includes Workmanager setup)
  await BackgroundLocationService.instance.initialize();

  final authService = SupabaseAuthService();
  final userService = SupabaseUserService();
  final coupleService = SupabaseCoupleService();
  final storageService = SupabaseStorageService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DebugProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (_) =>
              UserProvider(userService, storageService, coupleService),
          update: (_, auth, userProv) {
            if (auth.isAuthenticated) {
              // Try to load user by email first (more reliable than ID)
              final email = auth.currentUser?.email;
              if (email != null && email.isNotEmpty) {
                // Load by email since auth ID may differ from database ID
                userProv!.loadUserByEmail(email);
              } else {
                // Fallback to ID for phone auth users
                userProv!.loadUser(auth.currentUserId!);
              }
            } else {
              userProv!.clearUser();
            }
            return userProv;
          },
        ),
        ChangeNotifierProxyProvider<UserProvider, CoupleProvider>(
          create: (_) => CoupleProvider(coupleService, userService),
          update: (_, user, coupleProv) {
            final safeCoupleProv =
                coupleProv ?? CoupleProvider(coupleService, userService);
            final currentUser = user.user;
            if (currentUser == null) {
              // User signed out - clear couple data
              safeCoupleProv.clear();
            } else {
              safeCoupleProv.initializeRequests(currentUser.id);
              final coupleId = user.coupleId;
              if (coupleId != null) {
                safeCoupleProv.loadCouple(coupleId, currentUser.id);
              }
            }
            return safeCoupleProv;
          },
        ),
        ChangeNotifierProxyProvider3<UserProvider, CoupleProvider,
            DebugProvider, LocationProvider>(
          create: (_) => LocationProvider(userService, DebugProvider()),
          update: (_, userProv, coupleProv, debugProv, locationProv) {
            final user = userProv.user;
            final couple = coupleProv.couple;
            if (user != null) {
              // Get partner ID from couple
              String? partnerId;
              if (couple != null) {
                partnerId = couple.partnerIds
                    .firstWhere((id) => id != user.id, orElse: () => '');
                if (partnerId.isEmpty) partnerId = null;
              }
              // Initialize location provider with user context
              locationProv!.initialize(
                userId: user.uid,
                coupleId: user.coupleId,
                partnerId: partnerId,
              );
            }
            return locationProv!;
          },
        ),
        ChangeNotifierProxyProvider2<UserProvider, CoupleProvider,
            HeartbeatProvider>(
          create: (_) => HeartbeatProvider(SupabaseHeartbeatService()),
          update: (_, userProv, coupleProv, heartbeatProv) {
            final user = userProv.user;
            final coupleId = user?.coupleId;
            final couple = coupleProv.couple;
            final cachedPartner = coupleProv.partner;

            if (user == null || coupleId == null) {
              heartbeatProv!.clear();
              return heartbeatProv;
            }

            String? partnerId;
            if (couple != null) {
              partnerId = couple.getPartnerId(
                user.id.isNotEmpty ? user.id : user.uid,
              );
            }

            if ((partnerId == null || partnerId.isEmpty) &&
                cachedPartner != null) {
              partnerId = cachedPartner.id;
            }

            if (partnerId == null || partnerId.isEmpty) {
              heartbeatProv!.clear();
              return heartbeatProv;
            }

            heartbeatProv!.initialize(
              userId: user.id,
              coupleId: coupleId,
              partnerId: partnerId,
            );
            return heartbeatProv;
          },
        ),
        ChangeNotifierProxyProvider2<UserProvider, CoupleProvider,
            MoodProvider>(
          create: (_) => MoodProvider(SupabaseMoodService()),
          update: (_, userProv, coupleProv, moodProv) {
            final user = userProv.user;
            final coupleId = user?.coupleId;
            final couple = coupleProv.couple;
            final cachedPartner = coupleProv.partner;

            if (user == null || coupleId == null) {
              moodProv!.clear();
              return moodProv;
            }

            String? partnerId;
            if (couple != null) {
              partnerId = couple.getPartnerId(
                user.id.isNotEmpty ? user.id : user.uid,
              );
            }

            if ((partnerId == null || partnerId.isEmpty) &&
                cachedPartner != null) {
              partnerId = cachedPartner.id;
            }

            if (partnerId == null || partnerId.isEmpty) {
              moodProv!.clear();
              return moodProv;
            }

            moodProv!.initialize(
              userId: user.id,
              coupleId: coupleId,
              partnerId: partnerId,
            );
            return moodProv;
          },
        ),
        ChangeNotifierProxyProvider2<UserProvider, CoupleProvider,
            PhotoMessageProvider>(
          create: (_) => PhotoMessageProvider(
            SupabasePhotoMessageService(),
            SupabaseStorageService(),
          ),
          update: (_, userProv, coupleProv, photoProv) {
            final user = userProv.user;
            final coupleId = user?.coupleId;
            final couple = coupleProv.couple;
            final cachedPartner = coupleProv.partner;

            if (user == null || coupleId == null) {
              photoProv!.clear();
              return photoProv;
            }

            String? partnerId;
            if (couple != null) {
              partnerId = couple.getPartnerId(
                user.id.isNotEmpty ? user.id : user.uid,
              );
            }

            if ((partnerId == null || partnerId.isEmpty) &&
                cachedPartner != null) {
              partnerId = cachedPartner.id;
            }

            if (partnerId == null || partnerId.isEmpty) {
              photoProv!.clear();
              return photoProv;
            }

            photoProv!.initialize(
              userId: user.id,
              coupleId: coupleId,
              partnerId: partnerId,
            );
            return photoProv;
          },
        ),
        ChangeNotifierProxyProvider2<UserProvider, CoupleProvider,
            SecretMediaProvider>(
          create: (_) => SecretMediaProvider(
            SupabaseSecretMediaService(Supabase.instance.client),
          ),
          update: (_, userProv, coupleProv, secretMediaProv) {
            final user = userProv.user;
            final coupleId = user?.coupleId;

            if (user == null || coupleId == null) {
              secretMediaProv!.clear();
              return secretMediaProv;
            }

            secretMediaProv!.initialize(
              userId: user.id,
              coupleId: coupleId,
            );
            return secretMediaProv;
          },
        ),
      ],
      child: const JayienneLinkApp(),
    ),
  );
}

/// Debug Supabase connectivity and setup
Future<void> _debugSupabase() async {
  try {
    debugPrint('=== Supabase Debug Info ===');
    debugPrint('URL: ${dotenv.env['SUPABASE_URL']}');
    debugPrint(
        'Key configured: ${dotenv.env['SUPABASE_ANON_KEY']?.isNotEmpty == true}');

    // Test Storage Service
    final supabaseStorageService = SupabaseStorageService();
    final storageConnected = await supabaseStorageService.testConnectivity();
    final storageInitialized = await supabaseStorageService.initializeStorage();

    if (storageConnected && storageInitialized) {
      debugPrint('✅ Supabase Storage: Ready to use');
      final stats = await supabaseStorageService.getStorageStats();
      debugPrint('Storage stats: $stats');
    } else {
      debugPrint('⚠️ Supabase Storage: Setup needed');
    }

    // Test Database Service
    final dbConnected = await SupabaseDataService.testConnectivity();
    if (dbConnected) {
      debugPrint('✅ Supabase Database: Connected');
      final dbHealth = await SupabaseDataService.getDatabaseHealth();
      debugPrint('Database health: $dbHealth');
    } else {
      debugPrint('⚠️ Supabase Database: Connection failed');
    }

    debugPrint('========================');
  } catch (e) {
    debugPrint('❌ Supabase debug failed: $e');
  }
}
