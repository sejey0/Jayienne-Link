import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_lock_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/user_provider.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/phone_auth_screen.dart';
import '../../features/auth/screens/otp_verification_screen.dart';
import '../../features/profile/screens/profile_setup_screen.dart';
import '../../features/profile/screens/profile_view_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/couple/screens/couple_linking_screen.dart';
import '../../features/couple/screens/couple_success_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/settings_screen.dart';
import '../../features/home/screens/app_lock_screen.dart';
import '../../features/location/screens/location_screen.dart';
import '../../features/location/screens/location_history_screen.dart';
import '../../features/heartbeat/screens/heartbeat_screen.dart';
import '../../features/mood/screens/mood_screen.dart';
import '../../features/photos/screens/photos_screen.dart';
import '../../models/secret_media_model.dart';
import 'route_names.dart';
import '../../features/secret_media/screens/add_secret_media_screen.dart';
import '../../features/secret_media/screens/secret_media_detail_screen.dart';
import '../../features/secret_media/screens/hidden_vault_screen.dart';
import '../../features/anniversary/screens/relationship_timeline_screen.dart';
import '../../features/links/screens/couple_links_screen.dart';
import '../../features/auth/screens/deactivated_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';

class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'rootNavigatorKey');

  static GoRouter createRouter(
    AuthProvider authProvider,
    UserProvider userProvider,
    CoupleProvider coupleProvider,
    AppLockProvider appLockProvider,
  ) {
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: RouteNames.splash,
      refreshListenable:
          Listenable.merge([authProvider, userProvider, coupleProvider]),
      redirect: (context, state) {
        final auth = authProvider;
        final user = userProvider;
        final couple = coupleProvider;
        final location = state.matchedLocation;

        final isAuthenticated = auth.isAuthenticated;
        final isProfileComplete = user.isProfileComplete;
        final hasCoupleId = user.coupleId != null;
        final hasSkippedCoupleLink = user.user?.inviteCode == 'SKIPPED';
        final hasPendingRequest = couple.outgoingRequests.isNotEmpty ||
            couple.incomingRequests.isNotEmpty;

        // Allow splash to show briefly
        if (location == RouteNames.splash) return null;

        // Avoid redirecting during auth transitions (sign-in/sign-out) or while user profile is loading
        if (auth.isLoading || user.isLoading) return null;

        // If authenticated but user profile is currently loading from DB/cache, wait for userProvider
        if (isAuthenticated && user.user == null) return null;

        // Password Recovery Redirect Guard
        if (auth.isPasswordRecovery) {
          return location == RouteNames.resetPassword ? null : RouteNames.resetPassword;
        }

        // Check if user account is deactivated by Admin
        final isDeactivated = user.user?.isDeactivated ?? false;
        final isOnDeactivated = location == RouteNames.deactivated;

        if (isAuthenticated && isDeactivated) {
          return isOnDeactivated ? null : RouteNames.deactivated;
        }

        if (isOnDeactivated && !isDeactivated) {
          return RouteNames.home;
        }

        // Admin Route Guard
        final isOnAdmin = location == RouteNames.adminDashboard;
        final isAdmin = user.user?.isAdmin ?? false;

        if (isOnAdmin && !isAdmin) {
          return RouteNames.home;
        }

        // Auth routes that don't need redirect
        final isOnAuthRoute = location.startsWith('/auth');
        final isOnProfileSetup = location == RouteNames.profileSetup;
        final isOnCoupleLink = location == RouteNames.coupleLink;
        final isOnCoupleSuccess = location == RouteNames.coupleSuccess;
        final isOnAppLock = location == RouteNames.appLock;

        // Not authenticated -> go to auth
        if (!isAuthenticated) {
          return isOnAuthRoute ? null : RouteNames.auth;
        }

        // Authenticated + verified but no profile
        if (!isProfileComplete) {
          return isOnProfileSetup ? null : RouteNames.profileSetup;
        }

        // Profile complete but no couple (and hasn't skipped)
        if (!hasCoupleId && !hasSkippedCoupleLink && !hasPendingRequest) {
          if (isOnCoupleLink || isOnCoupleSuccess) return null;
          return RouteNames.coupleLink;
        }

        // Fully linked - redirect away from auth/setup routes
        if (hasCoupleId &&
            (isOnAuthRoute || isOnProfileSetup || isOnCoupleLink)) {
          return appLockProvider.requiresUnlock
              ? RouteNames.appLock
              : RouteNames.home;
        }

        // User skipped couple linking - redirect away from auth/setup but allow couple link access
        if (hasSkippedCoupleLink && (isOnAuthRoute || isOnProfileSetup)) {
          return appLockProvider.requiresUnlock
              ? RouteNames.appLock
              : RouteNames.home;
        }

        if (appLockProvider.requiresUnlock) {
          return isOnAppLock ? null : RouteNames.appLock;
        }

        if (isOnAppLock) {
          return RouteNames.home;
        }

        return null;
      },
      routes: [
        GoRoute(
          path: RouteNames.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: RouteNames.auth,
          builder: (context, state) => const AuthScreen(),
        ),
        GoRoute(
          path: RouteNames.register,
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: RouteNames.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: RouteNames.phoneAuth,
          builder: (context, state) => const PhoneAuthScreen(),
        ),
        GoRoute(
          path: RouteNames.otpVerification,
          builder: (context, state) => const OtpVerificationScreen(),
        ),
        GoRoute(
          path: RouteNames.resetPassword,
          builder: (context, state) => const ResetPasswordScreen(),
        ),
        GoRoute(
          path: RouteNames.profileSetup,
          builder: (context, state) => const ProfileSetupScreen(),
        ),
        GoRoute(
          path: RouteNames.coupleLink,
          builder: (context, state) => const CoupleLinkingScreen(),
        ),
        GoRoute(
          path: RouteNames.coupleSuccess,
          builder: (context, state) => const CoupleSuccessScreen(),
        ),
        GoRoute(
          path: RouteNames.home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: RouteNames.profile,
          builder: (context, state) => const ProfileViewScreen(),
        ),
        GoRoute(
          path: RouteNames.editProfile,
          builder: (context, state) => const EditProfileScreen(),
        ),
        GoRoute(
          path: RouteNames.settings,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: RouteNames.appLock,
          builder: (context, state) => const AppLockScreen(),
        ),
        GoRoute(
          path: RouteNames.location,
          builder: (context, state) => const LocationScreen(),
        ),
        GoRoute(
          path: RouteNames.locationHistory,
          builder: (context, state) {
            // Get tab parameter from query string (?tab=0 or ?tab=1)
            final tabStr = state.uri.queryParameters['tab'];
            final initialTab = int.tryParse(tabStr ?? '0') ?? 0;
            return LocationHistoryScreen(initialTab: initialTab);
          },
        ),
        GoRoute(
          path: RouteNames.heartbeat,
          builder: (context, state) => const HeartbeatScreen(),
        ),
        GoRoute(
          path: RouteNames.mood,
          builder: (context, state) => const MoodScreen(),
        ),
        GoRoute(
          path: RouteNames.photos,
          builder: (context, state) => const PhotosScreen(),
        ),
        GoRoute(
          path: RouteNames.secretMediaGallery,
          builder: (context, state) => const HiddenVaultScreen(),
        ),
        GoRoute(
          path: RouteNames.secretMediaAdd,
          builder: (context, state) => const AddSecretMediaScreen(),
        ),
        GoRoute(
          path: RouteNames.secretMediaDetail,
          builder: (context, state) {
            final media = state.extra;
            if (media is SecretMediaModel) {
              return SecretMediaDetailScreen(media: media);
            }
            return const Scaffold(
              body: Center(
                child: Text('Secret media item not found.'),
              ),
            );
          },
        ),
        GoRoute(
          path: RouteNames.secretMediaHiddenVault,
          builder: (context, state) => const HiddenVaultScreen(),
        ),
        GoRoute(
          path: RouteNames.relationshipTimeline,
          builder: (context, state) => const RelationshipTimelineScreen(),
        ),
        GoRoute(
          path: RouteNames.coupleLinks,
          builder: (context, state) => const CoupleLinksScreen(),
        ),
        GoRoute(
          path: RouteNames.adminDashboard,
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: RouteNames.deactivated,
          builder: (context, state) => const DeactivatedScreen(),
        ),
      ],
    );
  }
}
