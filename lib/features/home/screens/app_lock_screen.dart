import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/app_lock_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common/app_text_field.dart';

/// Operating modes for AppLockScreen
enum AppLockMode { unlock, setup }

/// 2-Step Passcode Creation Workflow
enum SetupStep { createPasscode, confirmPasscode }

/// Secure App Lock Screen fully integrated with Jayienne Link's romantic theme system
/// (Soft Rose / Lavender Gradients, Glassmorphic Card, and Playfair & Nunito Typography).
class AppLockScreen extends StatefulWidget {
  final AppLockMode? mode;

  const AppLockScreen({
    super.key,
    this.mode,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _passcodeController = TextEditingController();
  final FocusNode _passcodeFocusNode = FocusNode();

  AppLockMode _currentMode = AppLockMode.unlock;
  SetupStep _setupStep = SetupStep.createPasscode;
  String? _candidatePasscode;

  bool _obscurePasscode = true;
  bool _isProcessing = false;
  String? _setupError;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    if (widget.mode != null) {
      _currentMode = widget.mode!;
    }

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 24)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkAndTriggerBiometrics();
      if (mounted) {
        _passcodeFocusNode.requestFocus();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.mode != null) {
      _currentMode = widget.mode!;
    } else {
      final lockProvider = context.read<AppLockProvider>();
      _currentMode = lockProvider.hasPasscode ? AppLockMode.unlock : AppLockMode.setup;
    }
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    _passcodeFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _checkAndTriggerBiometrics() async {
    if (_currentMode != AppLockMode.unlock) return;
    final lockProvider = context.read<AppLockProvider>();
    if (lockProvider.isBiometricAvailable && !lockProvider.isLockedOut) {
      await _triggerBiometrics();
    }
  }

  Future<void> _triggerBiometrics() async {
    final lockProvider = context.read<AppLockProvider>();
    final success = await lockProvider.unlockWithBiometrics();
    if (success && mounted) {
      context.go(RouteNames.home);
    }
  }

  Future<void> _handlePasscodeSubmission() async {
    final lockProvider = context.read<AppLockProvider>();
    if ((_currentMode == AppLockMode.unlock && lockProvider.isLockedOut) ||
        _isProcessing) {
      return;
    }

    final input = _passcodeController.text.trim();

    // Enforce minimum 8 characters requirement
    if (input.length < AppLockProvider.minPasscodeLength) {
      _triggerError('Passcode must be at least ${AppLockProvider.minPasscodeLength} characters long.');
      SnackbarHelper.showError(
        context,
        'Passcode must be at least ${AppLockProvider.minPasscodeLength} characters long.',
        title: 'Passcode Too Short',
      );
      return;
    }

    if (_currentMode == AppLockMode.unlock) {
      await _submitUnlock(input);
    } else {
      await _submitSetupStep(input);
    }
  }

  /// Handles 2-Step Alphanumeric Passcode Creation Flow
  Future<void> _submitSetupStep(String inputPasscode) async {
    final lockProvider = context.read<AppLockProvider>();

    if (_setupStep == SetupStep.createPasscode) {
      // Step 1: Candidate Passcode captured. Transition to Step 2 (Confirm)
      setState(() {
        _candidatePasscode = inputPasscode;
        _setupStep = SetupStep.confirmPasscode;
        _passcodeController.clear();
        _setupError = null;
      });
      HapticFeedback.mediumImpact();
    } else {
      // Step 2: Compare confirmation passcode with candidate passcode
      if (inputPasscode == _candidatePasscode) {
        setState(() {
          _isProcessing = true;
        });

        final success = await lockProvider.setPasscode(inputPasscode);

        if (!mounted) return;

        setState(() {
          _isProcessing = false;
        });

        if (success) {
          SnackbarHelper.showSuccess(
            context,
            'Alphanumeric passcode set successfully!',
          );
          if (Navigator.canPop(context)) {
            Navigator.pop(context, true);
          } else {
            context.go(RouteNames.home);
          }
        } else {
          _triggerError(lockProvider.error ?? 'Failed to save passcode.');
          SnackbarHelper.showError(
            context,
            lockProvider.error ?? 'Failed to save passcode.',
          );
          _resetSetupFlow();
        }
      } else {
        // Confirmation failed: reset to Step 1 with error feedback
        _triggerError('Passcodes do not match. Please try again.');
        SnackbarHelper.showError(
          context,
          'Passcodes do not match. Please try again.',
          title: 'Mismatch Error',
        );
        _resetSetupFlow();
      }
    }
  }

  /// Reset 2-step setup workflow back to Step 1
  void _resetSetupFlow() {
    setState(() {
      _setupStep = SetupStep.createPasscode;
      _candidatePasscode = null;
      _passcodeController.clear();
    });
  }

  /// Handles Unlocking Existing Passcode
  Future<void> _submitUnlock(String inputPasscode) async {
    final lockProvider = context.read<AppLockProvider>();
    setState(() {
      _isProcessing = true;
    });

    final success = await lockProvider.unlockWithPasscode(inputPasscode);

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    if (success) {
      context.go(RouteNames.home);
    } else {
      _triggerError(null);
      _passcodeController.clear();
      if (lockProvider.isLockedOut) {
        SnackbarHelper.showError(
          context,
          'Too many failed attempts. Please try again in ${lockProvider.remainingLockoutSeconds} seconds.',
          title: 'Account Locked Out',
        );
      } else {
        final remaining = lockProvider.remainingAttempts;
        SnackbarHelper.showError(
          context,
          'Incorrect passcode. $remaining attempt${remaining == 1 ? '' : 's'} remaining.',
          title: 'Incorrect Passcode',
        );
      }
    }
  }

  void _triggerError(String? errorMessage) {
    _shakeController.forward(from: 0.0);
    HapticFeedback.vibrate();
    if (errorMessage != null) {
      setState(() {
        _setupError = errorMessage;
      });
    }
  }

  String get _titleText {
    if (_currentMode == AppLockMode.setup) {
      return _setupStep == SetupStep.createPasscode
          ? 'Create Passcode'
          : 'Confirm Passcode';
    }
    return AppStrings.appName;
  }

  String _getSubtitleText(AppLockProvider lockProvider) {
    if (_currentMode == AppLockMode.setup) {
      return _setupStep == SetupStep.createPasscode
          ? 'Enter a passcode (min 8 characters, letters & numbers)'
          : 'Re-enter your passcode to confirm';
    }
    if (lockProvider.isLockedOut) {
      return 'Locked out for ${lockProvider.remainingLockoutSeconds}s';
    }
    return 'Enter your passcode or use biometrics to unlock';
  }

  String get _buttonText {
    if (_currentMode == AppLockMode.setup) {
      return _setupStep == SetupStep.createPasscode ? 'Next Step' : 'Confirm & Save Passcode';
    }
    return 'Unlock';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final lockProvider = context.watch<AppLockProvider>();
    final isLockedOut = _currentMode == AppLockMode.unlock && lockProvider.isLockedOut;

    final bgGradient = LinearGradient(
      colors: isDark
          ? const [Color(0xFF120C18), Color(0xFF1A1224), Color(0xFF140D1B)]
          : const [Color(0xFFFFF7F9), Color(0xFFFDF0F4), Color(0xFFF7ECF7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return PopScope(
      canPop: _currentMode == AppLockMode.setup && Navigator.canPop(context),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _currentMode == AppLockMode.setup && Navigator.canPop(context)
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              )
            : null,
        body: Container(
          decoration: BoxDecoration(gradient: bgGradient),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                final double offset =
                    (0.5 - ((_shakeAnimation.value / 24) % 1).abs()) * 12;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Frosted / Theme-driven Vault Card
                        Container(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E142B).withValues(alpha: 0.9)
                                : Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.09)
                                  : const Color(0xFFFFE0E8),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? Colors.black : const Color(0xFFFF758C))
                                    .withValues(alpha: isDark ? 0.45 : 0.12),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Romantic Glowing Lock Emblem
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFFFF758C).withValues(alpha: isDark ? 0.4 : 0.35),
                                      const Color(0xFFA18CD1).withValues(alpha: isDark ? 0.4 : 0.35),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF758C).withValues(alpha: isDark ? 0.35 : 0.25),
                                      blurRadius: 20,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Icon(
                                    _currentMode == AppLockMode.setup
                                        ? (_setupStep == SetupStep.createPasscode
                                            ? Icons.lock_open_rounded
                                            : Icons.lock_rounded)
                                        : Icons.lock_rounded,
                                    size: 38,
                                    color: Colors.white,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Colored Title (App Name / Screen Mode)
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds),
                                child: Text(
                                  _titleText,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.playfairDisplay(
                                    color: Colors.white,
                                    fontSize: 25,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Subtitle
                              Text(
                                _getSubtitleText(lockProvider),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(
                                  color: isLockedOut
                                      ? AppColors.error
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : Colors.grey.shade600),
                                  fontSize: 13.5,
                                  fontWeight: isLockedOut ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),

                              const SizedBox(height: 26),

                              // Alphanumeric Passcode Input Field
                                AppTextField(
                                  controller: _passcodeController,
                                  focusNode: _passcodeFocusNode,
                                  enabled: !isLockedOut && !_isProcessing,
                                  autofocus: true,
                                  keyboardType: TextInputType.visiblePassword,
                                  obscureText: _obscurePasscode,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _handlePasscodeSubmission(),
                                  onChanged: (val) {
                                    if (_setupError != null || lockProvider.error != null) {
                                      setState(() {
                                        _setupError = null;
                                      });
                                    }
                                  },
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                                    fontSize: 16,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  hintText: 'Enter passcode (min 8 chars)',
                                  prefixIcon: Icons.key_rounded,
                                  borderRadius: BorderRadius.circular(18),
                                  isDark: isDark,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePasscode
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePasscode = !_obscurePasscode;
                                      });
                                    },
                                  ),
                                ),

                              const SizedBox(height: 22),

                              // Primary Action Button (Unlock / Next)
                              Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: (isLockedOut || _isProcessing)
                                      ? null
                                      : const LinearGradient(
                                          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                  color: (isLockedOut || _isProcessing)
                                      ? (isDark ? Colors.grey.shade800 : Colors.grey.shade300)
                                      : null,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: (isLockedOut || _isProcessing)
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: const Color(0xFFFF758C).withValues(alpha: 0.38),
                                            blurRadius: 14,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                ),
                                child: ElevatedButton(
                                  onPressed: (isLockedOut || _isProcessing)
                                      ? null
                                      : _handlePasscodeSubmission,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isProcessing
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _buttonText,
                                          style: GoogleFonts.nunito(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
                              ),

                              // Biometric Button (Unlock Mode Only)
                              if (_currentMode == AppLockMode.unlock &&
                                  lockProvider.isBiometricAvailable) ...[
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFFF758C).withValues(alpha: isDark ? 0.6 : 0.75),
                                      width: 1.4,
                                    ),
                                    color: (isDark
                                            ? const Color(0xFFFF758C)
                                            : const Color(0xFFFF9AA2))
                                        .withValues(alpha: isDark ? 0.08 : 0.06),
                                  ),
                                  child: TextButton.icon(
                                    onPressed: isLockedOut ? null : _triggerBiometrics,
                                    icon: const Icon(
                                      Icons.fingerprint_rounded,
                                      color: Color(0xFFFF758C),
                                      size: 22,
                                    ),
                                    label: Text(
                                      'Unlock with Biometrics',
                                      style: GoogleFonts.nunito(
                                        color: isDark
                                            ? const Color(0xFFFF9AA2)
                                            : const Color(0xFFE25B75),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Sign Out Button (Unlock Mode Only)
                        if (_currentMode == AppLockMode.unlock) ...[
                          const SizedBox(height: 20),
                          TextButton.icon(
                            onPressed: () => context.read<AuthProvider>().signOut(),
                            icon: Icon(
                              Icons.logout_rounded,
                              size: 16,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                            label: Text(
                              'Sign Out of Jayienne Link',
                              style: GoogleFonts.nunito(
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
