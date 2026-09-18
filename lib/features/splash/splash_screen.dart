import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_strings.dart';
import '../../core/router/route_names.dart';
import '../../services/local_cache_service.dart';
import '../../widgets/common/romantic_loading_indicator.dart';

class SplashScreen extends StatefulWidget {
  final bool isPreview;
  const SplashScreen({super.key, this.isPreview = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Key _indicatorKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    if (!widget.isPreview) {
      _navigateAfterDelay();
    }
  }

  Future<void> _navigateAfterDelay() async {
    // Show smooth startup splash so user experiences the romantic launch transition
    await Future.delayed(const Duration(milliseconds: 1400));

    final isFirstLaunch = await LocalCacheService.isFirstLaunch();
    if (isFirstLaunch) {
      await LocalCacheService.markFirstLaunchComplete();
    }

    if (mounted) {
      context.go(RouteNames.auth);
    }
  }

  void _restartAnimation() {
    setState(() {
      _indicatorKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF140E1B) : const Color(0xFFFFF7F9),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RomanticLoadingIndicator(
                    key: _indicatorKey,
                    size: 88,
                    message: 'Connecting to your love space',
                  ),
                  const SizedBox(height: 28),
                  Text(
                    AppStrings.appName,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF2C1930),
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.appTagline,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF8E7C93),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.isPreview)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close Button
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white : Colors.black87,
                        size: 22,
                      ),
                      tooltip: 'Close Preview',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  // Restart Animation Button
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.replay_rounded,
                        color: isDark ? Colors.white : Colors.black87,
                        size: 22,
                      ),
                      tooltip: 'Restart Animation',
                      onPressed: _restartAnimation,
                    ),
                  ),
                ],
              ),
            ),
          if (widget.isPreview)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.16)
                          : Colors.black.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.visibility_rounded,
                        size: 14,
                        color: Color(0xFFFF758C),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Developer Preview Mode',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
