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
import 'providers/debug_provider.dart';
import 'providers/connectivity_provider.dart';
import 'widgets/common/offline_status_modal.dart';

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
        final wrappedChild = _AppConnectivityBannerOverlay(
          child: child ?? const SizedBox.shrink(),
        );

        if (!kIsWeb) return wrappedChild;

        final mediaQuery = MediaQuery.of(context);
        final screenWidth = mediaQuery.size.width;

        // On mobile web (phones / narrow screens), render full width
        if (screenWidth <= 520) {
          return wrappedChild;
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
                    child: wrappedChild,
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

class _AppConnectivityBannerOverlay extends StatelessWidget {
  final Widget child;

  const _AppConnectivityBannerOverlay({required this.child});

  @override
  Widget build(BuildContext context) {
    ConnectivityProvider? connectivity;
    try {
      connectivity = Provider.of<ConnectivityProvider>(context, listen: true);
    } catch (_) {}

    DebugProvider? debugProvider;
    try {
      debugProvider = Provider.of<DebugProvider>(context, listen: true);
    } catch (_) {}

    final isSimulated = (debugProvider?.forceOfflineMode ?? false) || DebugProvider.isOfflineForced;
    final isOffline = isSimulated || (connectivity != null && connectivity.isOffline);

    return Stack(
      children: [
        child,
        if (isOffline)
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            left: 16,
            right: 16,
            child: Material(
              type: MaterialType.transparency,
              child: Center(
                child: GestureDetector(
                  onTap: () => showOfflineModal(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1427).withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSimulated
                            ? const Color(0xFFA18CD1).withValues(alpha: 0.6)
                            : const Color(0xFFFF5252).withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isSimulated
                                  ? const Color(0xFFA18CD1)
                                  : const Color(0xFFFF5252))
                              .withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSimulated
                              ? Icons.developer_mode_rounded
                              : Icons.wifi_off_rounded,
                          size: 15,
                          color: isSimulated
                              ? const Color(0xFFA18CD1)
                              : const Color(0xFFFF5252),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isSimulated
                              ? 'Offline Simulation Active • Tap for details'
                              : 'No Internet • Offline Mode • Tap for details',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
