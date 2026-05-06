import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/router/route_names.dart';
import '../../widgets/common/heart_animation.dart';
import '../../services/local_cache_service.dart';

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
    // Check if this is the first launch
    final isFirstLaunch = await LocalCacheService.isFirstLaunch();

    // Only add delay on first launch
    if (isFirstLaunch) {
      await Future.delayed(const Duration(seconds: 2));
      // Mark first launch as complete
      await LocalCacheService.markFirstLaunchComplete();
    }

    if (mounted) {
      context.go(RouteNames.auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HeartAnimation(size: 80),
            const SizedBox(height: 24),
            Text(
              AppStrings.appName,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: AppColors.softRose,
                  ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
            const SizedBox(height: 8),
            Text(
              AppStrings.appTagline,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.lavender,
                  ),
            ).animate().fadeIn(duration: 600.ms),
          ],
        ),
      ),
    );
  }
}
