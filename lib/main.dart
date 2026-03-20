import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/couple_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/location_provider.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'services/couple_service.dart';
import 'services/storage_service.dart';
import 'services/background_location_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Enable Firestore offline persistence with reduced cache for data saving
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 10485760, // 10MB cache limit (saves storage & data)
  );

  // Initialize Workmanager for background location tasks
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );

  final authService = AuthService();
  final userService = UserService();
  final coupleService = CoupleService();
  final storageService = StorageService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (_) =>
              UserProvider(userService, storageService, coupleService),
          update: (_, auth, userProv) {
            if (auth.isAuthenticated) {
              userProv!.loadUser(auth.firebaseUser!.uid);
            } else {
              userProv!.clearUser();
            }
            return userProv;
          },
        ),
        ChangeNotifierProxyProvider<UserProvider, CoupleProvider>(
          create: (_) => CoupleProvider(coupleService),
          update: (_, user, coupleProv) {
            if (user.coupleId != null) {
              coupleProv!.loadCouple(user.coupleId!);
            }
            return coupleProv!;
          },
        ),
        ChangeNotifierProxyProvider2<UserProvider, CoupleProvider,
            LocationProvider>(
          create: (_) => LocationProvider(userService),
          update: (_, userProv, coupleProv, locationProv) {
            final user = userProv.user;
            final couple = coupleProv.couple;
            if (user != null) {
              // Get partner ID from couple
              String? partnerId;
              if (couple != null) {
                partnerId = couple.partnerIds
                    .firstWhere((id) => id != user.uid, orElse: () => '');
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
      ],
      child: const JayienneLinkApp(),
    ),
  );
}
