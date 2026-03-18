import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/phone_auth_screen.dart';
import '../../features/auth/screens/otp_verification_screen.dart';
import '../../features/auth/screens/email_verification_screen.dart';
import '../../features/profile/screens/profile_setup_screen.dart';
import '../../features/profile/screens/profile_view_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/couple/screens/couple_linking_screen.dart';
import '../../features/couple/screens/couple_success_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/settings_screen.dart';
import '../../features/location/screens/location_screen.dart';
import '../../features/location/screens/location_history_screen.dart';
import 'route_names.dart';

class AppRouter {
  AppRouter._();

  static GoRouter router(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();

    return GoRouter(
      initialLocation: RouteNames.splash,
      refreshListenable: Listenable.merge([authProvider, userProvider]),
      redirect: (context, state) {
        final auth = context.read<AuthProvider>();
        final user = context.read<UserProvider>();
        final location = state.matchedLocation;

        final isAuthenticated = auth.isAuthenticated;
        final isEmailVerified = auth.isEmailVerified;
        final isProfileComplete = user.isProfileComplete;
        final hasCoupleId = user.coupleId != null;

        // Allow splash to show briefly
        if (location == RouteNames.splash) return null;

        // Auth routes that don't need redirect
        final isOnAuthRoute = location.startsWith('/auth');
        final isOnProfileSetup = location == RouteNames.profileSetup;
        final isOnCoupleLink = location == RouteNames.coupleLink;
        final isOnCoupleSuccess = location == RouteNames.coupleSuccess;

        // Not authenticated -> go to auth
        if (!isAuthenticated) {
          return isOnAuthRoute ? null : RouteNames.auth;
        }

        // Authenticated but email not verified (email users only)
        if (auth.firebaseUser?.email != null && !isEmailVerified) {
          return location == RouteNames.emailVerification
              ? null
              : RouteNames.emailVerification;
        }

        // Authenticated + verified but no profile
        if (!isProfileComplete) {
          return isOnProfileSetup ? null : RouteNames.profileSetup;
        }

        // Profile complete but no couple
        if (!hasCoupleId) {
          if (isOnCoupleLink || isOnCoupleSuccess) return null;
          return RouteNames.coupleLink;
        }

        // Fully linked - redirect away from auth/setup routes
        if (isOnAuthRoute || isOnProfileSetup || isOnCoupleLink) {
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
          path: RouteNames.emailVerification,
          builder: (context, state) => const EmailVerificationScreen(),
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
          path: RouteNames.location,
          builder: (context, state) => const LocationScreen(),
        ),
        GoRoute(
          path: RouteNames.locationHistory,
          builder: (context, state) => const LocationHistoryScreen(),
        ),
      ],
    );
  }
}
