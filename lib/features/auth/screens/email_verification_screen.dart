import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common/app_button.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    _startVerificationCheck();
  }

  void _startVerificationCheck() {
    _checkTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final auth = context.read<AuthProvider>();
      await auth.checkEmailVerified();
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _resendEmail() async {
    final auth = context.read<AuthProvider>();
    try {
      await auth.sendEmailVerification();
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Verification email resent!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final email = auth.verificationEmail ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.verifyEmail)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 80,
                color: AppColors.softRose,
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              Text(
                AppStrings.verifyEmailSubtitle,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                email,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.softRose,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingXl),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.lavender,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                AppStrings.checkingVerification,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
              const SizedBox(height: AppDimensions.spacingXl),
              AppButton(
                label: AppStrings.resendEmail,
                variant: AppButtonVariant.secondary,
                icon: Icons.refresh,
                onPressed: _resendEmail,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              TextButton.icon(
                onPressed: () async {
                  final auth = context.read<AuthProvider>();
                  await auth.signOut();
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Login'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
