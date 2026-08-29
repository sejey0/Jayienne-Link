import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/app_lock_provider.dart';
import '../../../providers/auth_provider.dart';

/// Operating modes for AppLockScreen
enum AppLockMode { unlock, setup }

/// 2-Step Passcode Creation Workflow
enum SetupStep { createPasscode, confirmPasscode }

/// Secure App Lock Screen fully integrated with the application's active ThemeData
/// (Light / Dark mode, Primary colors, Surface fills, and Typography).
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

  late AppLockMode _currentMode;
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

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 24)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initMode();
      _checkAndTriggerBiometrics();
      if (mounted) {
        _passcodeFocusNode.requestFocus();
      }
    });
  }

  void _initMode() {
    if (!mounted) return;
    final lockProvider = context.read<AppLockProvider>();
    if (widget.mode != null) {
      _currentMode = widget.mode!;
    } else {
      _currentMode = lockProvider.hasPasscode ? AppLockMode.unlock : AppLockMode.setup;
    }
    if (mounted) setState(() {});
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
          _resetSetupFlow();
        }
      } else {
        // Confirmation failed: reset to Step 1 with error feedback
        _triggerError('Passcodes do not match. Please try again.');
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
    return 'Jayienne Vault Locked';
  }

  String get _subtitleText {
    final lockProvider = context.read<AppLockProvider>();
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
      return _setupStep == SetupStep.createPasscode ? 'Next' : 'Confirm & Save';
    }
    return 'Unlock';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final lockProvider = context.watch<AppLockProvider>();
    final isLockedOut = _currentMode == AppLockMode.unlock && lockProvider.isLockedOut;
    final displayError = _setupError ?? lockProvider.error;

    return PopScope(
      canPop: _currentMode == AppLockMode.setup && Navigator.canPop(context),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: _currentMode == AppLockMode.setup && Navigator.canPop(context)
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
                  onPressed: () => Navigator.pop(context),
                ),
              )
            : null,
        body: SafeArea(
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
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Header Icon with Theme-driven soft container
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _currentMode == AppLockMode.setup
                              ? Icons.security_rounded
                              : Icons.lock_outline_rounded,
                          size: 48,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _titleText,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _subtitleText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isLockedOut
                              ? colorScheme.error
                              : colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight:
                              isLockedOut ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Theme-driven Alphanumeric Passcode TextField
                      TextField(
                        controller: _passcodeController,
                        focusNode: _passcodeFocusNode,
                        enabled: !isLockedOut && !_isProcessing,
                        autofocus: true,
                        keyboardType: TextInputType.visiblePassword,
                        obscureText: _obscurePasscode,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _handlePasscodeSubmission(),
                        onChanged: (val) {
                          if (_setupError != null || lockProvider.error != null) {
                            setState(() {
                              _setupError = null;
                            });
                          }
                        },
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 18,
                          letterSpacing: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter passcode (min 8 chars)',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                            fontSize: 15,
                          ),
                          filled: true,
                          fillColor: colorScheme.surface,
                          prefixIcon: Icon(
                            Icons.key_rounded,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePasscode
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePasscode = !_obscurePasscode;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),

                      if (displayError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          displayError,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Submission Button ("Unlock" or "Next" / "Confirm")
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (isLockedOut || _isProcessing)
                              ? null
                              : _handlePasscodeSubmission,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                          child: _isProcessing
                              ? SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: colorScheme.onPrimary,
                                  ),
                                )
                              : Text(
                                  _buttonText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      // Biometric Alternative Button (Unlock Mode Only)
                      if (_currentMode == AppLockMode.unlock &&
                          lockProvider.isBiometricAvailable) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: isLockedOut ? null : _triggerBiometrics,
                          icon: Icon(Icons.fingerprint, color: colorScheme.primary),
                          label: Text(
                            'Unlock with Biometrics',
                            style: TextStyle(color: colorScheme.primary),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colorScheme.primary),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      if (_currentMode == AppLockMode.unlock)
                        TextButton(
                          onPressed: () => context.read<AuthProvider>().signOut(),
                          child: Text(
                            'Sign Out',
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
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
