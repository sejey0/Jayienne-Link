import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/couple_provider.dart';
import 'providers/theme_provider.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'services/couple_service.dart';
import 'services/storage_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

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
          create: (_) => UserProvider(userService, storageService),
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
      ],
      child: const JayienneLinkApp(),
    ),
  );
}
