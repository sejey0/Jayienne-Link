class RouteNames {
  RouteNames._();

  static const String splash = '/splash';
  static const String auth = '/auth';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String phoneAuth = '/auth/phone';
  static const String otpVerification = '/auth/otp';
  static const String emailVerification = '/auth/verify-email';
  static const String resetPassword = '/auth/reset-password';
  static const String profileSetup = '/profile-setup';
  static const String coupleLink = '/couple-link';
  static const String coupleSuccess = '/couple-success';
  static const String appLock = '/app-lock';
  static const String home = '/';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String settings = '/settings';

  // Location routes
  static const String location = '/location';
  static const String locationHistory = '/location/history';

  // Heartbeat routes
  static const String heartbeat = '/heartbeat';

  // Mood routes
  static const String mood = '/mood';

  // Photos routes
  static const String photos = '/photos';

  // Secret Media routes
  static const String secretMediaGallery = '/secret-media/gallery';
  static const String secretMediaAdd = '/secret-media/add';
  static const String secretMediaDetail = '/secret-media/detail';
  static const String secretMediaHiddenVault = '/secret-media/vault';

  // Anniversary & Timeline routes
  static const String relationshipTimeline = '/timeline';

  // Couple Links & Social Profiles
  static const String coupleLinks = '/couple-links';

  // Admin & Security routes
  static const String adminDashboard = '/admin';
  static const String deactivated = '/deactivated';
}
