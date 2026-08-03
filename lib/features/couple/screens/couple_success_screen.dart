import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/router/route_names.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/couple_provider.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/heart_animation.dart';

class CoupleSuccessScreen extends StatelessWidget {
  const CoupleSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final couple = coupleProvider.couple;
    final partnerName =
        couple?.getPartnerName(auth.currentUserId!, livePartnerName: coupleProvider.partner?.displayName) ?? 'your partner';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const HeartAnimation(size: 96),
              const SizedBox(height: AppDimensions.spacingXl),
              Text(
                AppStrings.youreConnected,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppColors.softRose,
                    ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                '${AppStrings.connectedWith} $partnerName',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.lavender,
                    ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
              const SizedBox(height: AppDimensions.spacingXxl),
              AppButton(
                label: AppStrings.continueText,
                onPressed: () => context.go(RouteNames.home),
              ).animate().fadeIn(duration: 400.ms, delay: 900.ms),
            ],
          ),
        ),
      ),
    );
  }
}
