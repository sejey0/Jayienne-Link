import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/loading_overlay.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    await auth.verifyPhone(_phoneController.text.trim());

    if (!mounted) return;

    if (auth.verificationId != null) {
      context.push(RouteNames.otpVerification);
    } else if (auth.error != null) {
      SnackbarHelper.showError(context, auth.error!);
    } else {
      SnackbarHelper.showError(
        context,
        'Failed to send verification code. Please check the number and try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return LoadingOverlay(
      isLoading: auth.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text(AppStrings.continueWithPhone)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppDimensions.spacingXl),
                  Text(
                    AppStrings.enterPhoneNumber,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  Text(
                    'Include your country code (e.g. +63)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: AppDimensions.spacingLg),
                  AppTextField(
                    controller: _phoneController,
                    hintText: '+63 9XX XXX XXXX',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    validator: Validators.validatePhone,
                  ),
                  const SizedBox(height: AppDimensions.spacingXl),
                  AppButton(
                    label: AppStrings.sendCode,
                    onPressed: _sendCode,
                    isLoading: auth.isLoading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
