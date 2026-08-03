import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/loading_overlay.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (!success && auth.error != null) {
      final errorText = auth.error!.toLowerCase();
      final isInvalidCredentials =
          errorText.contains('invalid email or password') ||
              errorText.contains('invalid login credentials');
      final isUserNotFound = errorText.contains('no account found');

      if (isInvalidCredentials || isUserNotFound) {
        _showAccountNotFoundDialog();
      } else {
        SnackbarHelper.showError(context, auth.error!);
      }
    }
  }

  void _showAccountNotFoundDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account not found'),
        content: const Text(
          'We could not find an account with these credentials. '
          'Please sign up first or check your password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _forgotPassword() {
    context.push(RouteNames.resetPassword);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return LoadingOverlay(
      isLoading: auth.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text(AppStrings.signIn)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppDimensions.spacingXl),
                  AppTextField(
                    controller: _emailController,
                    hintText: AppStrings.email,
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.validateEmail,
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  AppTextField(
                    controller: _passwordController,
                    hintText: AppStrings.password,
                    prefixIcon: Icons.lock_outlined,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: const Text(AppStrings.forgotPassword),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingLg),
                  AppButton(
                    label: AppStrings.signIn,
                    onPressed: _login,
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
