import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_lock_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/couple_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';

class JayienneLinkApp extends StatefulWidget {
  const JayienneLinkApp({super.key});

  @override
  State<JayienneLinkApp> createState() => _JayienneLinkAppState();
}

class _JayienneLinkAppState extends State<JayienneLinkApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Create router once in initState
    final authProvider = context.read<AuthProvider>();
    final appLockProvider = context.read<AppLockProvider>();
    final userProvider = context.read<UserProvider>();
    final coupleProvider = context.read<CoupleProvider>();
    _router = AppRouter.createRouter(
      authProvider,
      userProvider,
      coupleProvider,
      appLockProvider,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp.router(
      title: 'Jayienne Link',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      routerConfig: _router,
      builder: (context, child) {
        if (!kIsWeb) return child ?? const SizedBox.shrink();

        final mediaQuery = MediaQuery.of(context);
        final screenWidth = mediaQuery.size.width;

        // On mobile web (phones / narrow screens), render full width
        if (screenWidth <= 520) {
          return child ?? const SizedBox.shrink();
        }

        // On widescreen desktop web, constrain to a centered mobile canvas
        const maxContentWidth = 460.0;
        final isDark = themeProvider.isDarkMode;

        return ColoredBox(
          color: isDark ? const Color(0xFF0D0D12) : const Color(0xFFF1F3F8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: MediaQuery(
                data: mediaQuery.copyWith(
                  size: Size(maxContentWidth, mediaQuery.size.height),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
                        blurRadius: 28,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRect(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
