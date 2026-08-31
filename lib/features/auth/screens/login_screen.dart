import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/loading_overlay.dart';
import 'deactivated_screen.dart';

/// Redesigned Romantic Login Screen matching the App Design Theme
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
    HapticFeedback.lightImpact();

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
    HapticFeedback.lightImpact();
    context.push(RouteNames.resetPassword);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LoadingOverlay(
      isLoading: auth.isLoading,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF140E1B) : const Color(0xFFFFF7F9),
        appBar: AppBar(
          title: const Text(
            'Sign In',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
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
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),

                  // App Logo Header with Romantic Heart Backdrop
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Soft Heart Glow
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 96,
                            color: Colors.white.withValues(alpha: isDark ? 0.3 : 0.35),
                          ),
                        ),
                        // Inner Heart Card
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: isDark
                                ? [const Color(0xFF261A34), const Color(0xFF191124)]
                                : [Colors.white, const Color(0xFFFFF0F5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Icon(
                            Icons.favorite_rounded,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                        // Heart Border
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: Icon(
                            Icons.favorite_outline_rounded,
                            size: 80,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        // Logo inside Heart
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Image.asset(
                            'assets/icon/road_to_forever, no bg.png',
                            width: 44,
                            height: 44,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Welcome Back, Love',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.deepCharcoal,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Email Field
                  AppTextField(
                    labelText: 'Email Address',
                    controller: _emailController,
                    hintText: 'Enter your email',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.validateEmail,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 18),

                  // Password Field
                  AppTextField(
                    labelText: 'Password',
                    controller: _passwordController,
                    hintText: 'Enter your password',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    isDark: isDark,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFFFF758C),
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),

                  // Forgot Password Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: const Text(
                        AppStrings.forgotPassword,
                        style: TextStyle(
                          color: Color(0xFFFF758C),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sign In Primary Button
                  InkWell(
                    onTap: auth.isLoading ? null : _login,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.login_rounded, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    AppStrings.signIn,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Bottom Switch to Register
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                          fontSize: 13.5,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.pushReplacement(RouteNames.register);
                        },
                        child: const Text(
                          'Create Account',
                          style: TextStyle(
                            color: Color(0xFFFF758C),
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
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
