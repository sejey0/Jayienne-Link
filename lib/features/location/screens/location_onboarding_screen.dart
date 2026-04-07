import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/router/route_names.dart';
import '../../../providers/location_provider.dart';
import '../../../widgets/common/app_button.dart';

/// Onboarding screen explaining location sharing and requesting permissions.
class LocationOnboardingScreen extends StatefulWidget {
  const LocationOnboardingScreen({super.key});

  @override
  State<LocationOnboardingScreen> createState() =>
      _LocationOnboardingScreenState();
}

class _LocationOnboardingScreenState extends State<LocationOnboardingScreen> {
  int _currentPage = 0;
  final _pageController = PageController();

  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.location_on,
      title: 'Share Your Location',
      description:
          'Let your person know where you are, even when you\'re offline. '
          'Perfect for when you\'re hiking, traveling, or just out and about.',
      color: AppColors.softRose,
    ),
    _OnboardingPage(
      icon: Icons.cloud_off,
      title: 'Works Offline',
      description:
          'No internet? No problem. Your location is saved locally and '
          'automatically syncs when you\'re back online.',
      color: AppColors.lavender,
    ),
    _OnboardingPage(
      icon: Icons.lock,
      title: 'Private & Secure',
      description: 'Only your linked partner can see your location. '
          'You\'re always in control - pause sharing anytime.',
      color: AppColors.peach,
    ),
    _OnboardingPage(
      icon: Icons.battery_charging_full,
      title: 'Battery Friendly',
      description: 'Smart location updates that won\'t drain your battery. '
          'We only update when you move, not constantly.',
      color: AppColors.success,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => context.go(RouteNames.location),
                child: Text(
                  'Skip',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            ),
            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) => _buildPage(_pages[index]),
              ),
            ),
            // Page indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => _buildDot(index),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            // Action button
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLg),
              child: _currentPage == _pages.length - 1
                  ? _buildPermissionButton(context)
                  : _buildNextButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: page.color.withOpacity(0.2),
            ),
            child: Icon(
              page.icon,
              size: 60,
              color: page.color,
            ),
          )
              .animate()
              .scale(duration: const Duration(milliseconds: 500))
              .fadeIn(),
          const SizedBox(height: AppDimensions.spacingXl),
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            page.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: const Duration(milliseconds: 400)),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    final isActive = index == _currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppColors.softRose : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildNextButton() {
    return AppButton(
      label: 'Next',
      onPressed: () {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  Widget _buildPermissionButton(BuildContext context) {
    return Column(
      children: [
        AppButton(
          label: 'Enable Location Sharing',
          icon: Icons.location_on,
          onPressed: () async {
            final provider = context.read<LocationProvider>();
            final granted = await provider.requestPermission();

            if (!context.mounted) return;

            if (granted) {
              context.go(RouteNames.location);
            } else {
              _showPermissionDeniedDialog(context);
            }
          },
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        TextButton(
          onPressed: () => context.go(RouteNames.location),
          child: const Text('Maybe later'),
        ),
      ],
    );
  }

  void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission'),
        content: const Text(
          'Location access is needed to share your location with your person. '
          'You can enable it later in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(RouteNames.location);
            },
            child: const Text('Continue without location'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final provider = context.read<LocationProvider>();
              await provider.openSettings();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.softRose),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
