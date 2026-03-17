import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/router/route_names.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/heart_animation.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingLg,
          ),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const HeartAnimation(size: 72),
              const SizedBox(height: AppDimensions.spacingLg),
              Text(
                AppStrings.welcome,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 500.ms),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                AppStrings.appTagline,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.lavender,
                    ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
              const Spacer(flex: 3),
              AppButton(
                label: AppStrings.continueWithEmail,
                icon: Icons.email_outlined,
                onPressed: () => context.push(RouteNames.register),
              ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
              const SizedBox(height: AppDimensions.spacingMd),
              AppButton(
                label: AppStrings.continueWithPhone,
                variant: AppButtonVariant.secondary,
                icon: Icons.phone_outlined,
                onPressed: () => context.push(RouteNames.phoneAuth),
              ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
              const SizedBox(height: AppDimensions.spacingMd),
              AppButton(
                label: AppStrings.iHaveAnAccount,
                variant: AppButtonVariant.text,
                onPressed: () => context.push(RouteNames.login),
              ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
