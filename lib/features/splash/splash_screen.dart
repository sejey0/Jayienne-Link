import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_strings.dart';
import '../../core/router/route_names.dart';
import '../../services/local_cache_service.dart';
import '../../widgets/common/romantic_loading_indicator.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterDelay();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF140E1B) : const Color(0xFFFFF7F9),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const RomanticLoadingIndicator(
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
    );
  }
}
