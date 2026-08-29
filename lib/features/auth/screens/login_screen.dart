import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/loading_overlay.dart';
import 'deactivated_screen.dart';

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
    if (!_formKey.currentState!.validate()) {
      SnackbarHelper.showError(
        context,
        'Please enter a valid email and password.',
        title: 'Missing Information',
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      final user = context.read<UserProvider>().user;
      if (user != null && user.isDeactivated) {
        DeactivatedScreen.showDeactivatedDialog(context);
      }
    } else if (auth.error != null) {
      final errorText = auth.error!.toLowerCase();
      final isDeactivated = errorText.contains('deactivated');
      final isInvalidCredentials =
          errorText.contains('invalid email or password') ||
              errorText.contains('invalid login credentials') ||
              errorText.contains('invalid credentials');
      final isUserNotFound = errorText.contains('no account found') ||
          errorText.contains('user not found');

      if (isDeactivated) {
        DeactivatedScreen.showDeactivatedDialog(context);
      } else if (isInvalidCredentials || isUserNotFound) {
        _showAccountNotFoundDialog();
      } else {
        SnackbarHelper.showError(context, auth.error!);
      }
    } else {
      SnackbarHelper.showError(
        context,
        'Login failed. Please check your credentials.',
      );
    }
  }

  void _showAccountNotFoundDialog() {
    SnackbarHelper.showCustom(
      context: context,
      title: 'Account Not Found',
      message:
          'We could not find an account with these credentials. Please sign up first or check your password.',
      icon: Icons.person_off_rounded,
      gradientColors: const [Color(0xFFFF5252), Color(0xFFD81B60)],
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
        appBar: AppBar(
          title: const Text(
            AppStrings.signIn,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          elevation: 0,
        ),
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
