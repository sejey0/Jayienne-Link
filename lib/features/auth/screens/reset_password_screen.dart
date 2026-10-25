import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/loading_overlay.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _step = 0; // 0 = Enter email, 1 = Enter code & new password
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      SnackbarHelper.showError(context, 'Please enter a valid email address');
      return;
    }

    HapticFeedback.lightImpact();
    final auth = context.read<AuthProvider>();
    final success = await auth.sendPasswordReset(email);

    if (!mounted) return;

    if (success) {
      HapticFeedback.mediumImpact();
      setState(() => _step = 1);
      SnackbarHelper.showSuccess(
        context,
        'Reset code sent to $email. Please check your inbox.',
      );
    } else if (auth.error != null) {
      SnackbarHelper.showError(context, auth.error!);
    }
  }

  Future<void> _handleConfirmNewPassword(bool isDirectSession) async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final code = _otpController.text.trim();
    final newPassword = _newPasswordController.text;

    bool success = false;
    if (isDirectSession) {
      // User arrived from recovery link or active session
      success = await auth.updatePassword(newPassword);
    } else {
      // User entered OTP code from email
      if (code.isEmpty) {
        SnackbarHelper.showError(context, 'Please enter the 6-digit code from your email');
        return;
      }
      success = await auth.resetPasswordWithOtp(
        email: email,
        token: code,
        newPassword: newPassword,
      );
    }

    if (!mounted) return;

    if (success) {
      HapticFeedback.heavyImpact();
      final isDark = Theme.of(context).brightness == Brightness.dark;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF1C1427) : Colors.white,
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF66BB6A).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Password Successfully Changed!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.deepCharcoal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your account password has been updated in the database. You can now log in securely with your new password.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    auth.clearPasswordRecovery();
                    Navigator.pop(dialogCtx);
                    context.go(RouteNames.login);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Proceed to Login',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (auth.error != null) {
      SnackbarHelper.showError(context, auth.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();

    // If authenticated via recovery link or currently signed in, directly show new password fields
    final isDirectRecoverySession = auth.isPasswordRecovery || auth.isAuthenticated;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isDirectRecoverySession || _step == 1 ? 'Set New Password' : 'Reset Password',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
            if (_step == 1 && !isDirectRecoverySession) {
              setState(() => _step = 0);
            } else {
              auth.clearPasswordRecovery();
              Navigator.pop(context);
            }
          },
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
                  const SizedBox(height: AppDimensions.spacingLg),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(AppDimensions.spacingLg),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        isDirectRecoverySession || _step == 1
                            ? Icons.lock_open_rounded
                            : Icons.lock_reset_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingLg),
                  Text(
                    isDirectRecoverySession || _step == 1
                        ? 'Create New Password'
                        : 'Forgot Your Password?',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isDirectRecoverySession
                        ? 'Your identity has been verified. Enter your new password below.'
                        : _step == 1
                            ? 'Enter the 6-digit verification code sent to your email and your new password.'
                            : 'Enter your registered email address to receive a secure recovery code and reset link.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.spacingXl),

                  // STEP 0: Request Reset Code (Email field)
                  if (!isDirectRecoverySession && _step == 0) ...[
                    AppTextField(
                      controller: _emailController,
                      hintText: 'Email Address',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.validateEmail,
                    ),
                    const SizedBox(height: AppDimensions.spacingXl),
                    AppButton(
                      label: 'Send Reset Code',
                      onPressed: _handleSendResetCode,
                      isLoading: auth.isLoading,
                    ),
                  ],

                  // STEP 1 / DIRECT RECOVERY: Set New Password
                  if (isDirectRecoverySession || _step == 1) ...[
                    // OTP Token Field (only if not already authenticated via direct recovery link)
                    if (!isDirectRecoverySession) ...[
                      AppTextField(
                        controller: _otpController,
                        hintText: '6-Digit Code (from email)',
                        prefixIcon: Icons.pin_outlined,
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter the 6-digit code';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDimensions.spacingMd),
                    ],

                    // New Password Field
                    AppTextField(
                      controller: _newPasswordController,
                      hintText: 'New Password',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscureNewPassword,
                      validator: Validators.validatePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                        onPressed: () => setState(
                          () => _obscureNewPassword = !_obscureNewPassword,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),

                    // Confirm Password Field
                    AppTextField(
                      controller: _confirmPasswordController,
                      hintText: 'Confirm New Password',
                      prefixIcon: Icons.lock_reset_rounded,
                      obscureText: _obscureConfirmPassword,
                      validator: (val) => Validators.validateConfirmPassword(
                        _newPasswordController.text,
                      )(val),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXl),

                    // Update Password Button
                    AppButton(
                      label: 'Save & Update Password',
                      onPressed: () => _handleConfirmNewPassword(isDirectRecoverySession),
                      isLoading: auth.isLoading,
                    ),

                    if (!isDirectRecoverySession) ...[
                      const SizedBox(height: AppDimensions.spacingMd),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: auth.isLoading ? null : _handleSendResetCode,
                            child: const Text(
                              'Resend Code',
                              style: TextStyle(
                                color: Color(0xFFFF758C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Text(' · '),
                          TextButton(
                            onPressed: () => setState(() => _step = 0),
                            child: Text(
                              'Change Email',
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      );
  }
}
