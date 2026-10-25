import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common/loading_overlay.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  Timer? _resendTimer;
  int _resendCountdown = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _canResend = false;
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _verifyOtp(String otp) async {
    if (otp.length != 6) return;

    final auth = context.read<AuthProvider>();
    final phoneNumber = auth.pendingPhoneNumber;
    if (phoneNumber == null || phoneNumber.isEmpty) {
      if (!mounted) return;
      SnackbarHelper.showError(
        context,
        'Phone number missing. Please restart phone verification.',
      );
      return;
    }

    final success = await auth.verifyOtp(otp, phoneNumber);

    if (!mounted) return;

    if (!success && auth.error != null) {
      SnackbarHelper.showError(context, auth.error!);
      _otpController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return LoadingOverlay(
      isLoading: auth.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text(AppStrings.verifyOtp)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimensions.spacingXl),
                Text(
                  AppStrings.enterOtp,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacingXl),
                _OtpInputFields(
                  controller: _otpController,
                  onCompleted: _verifyOtp,
                ),
                const SizedBox(height: AppDimensions.spacingLg),
                Center(
                  child: _canResend
                      ? TextButton(
                          onPressed: () {
                            // Re-trigger phone verification
                            _startResendTimer();
                          },
                          child: const Text(AppStrings.resendCode),
                        )
                      : Text(
                          '${AppStrings.resendCode} in ${_resendCountdown}s',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpInputFields extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onCompleted;

  const _OtpInputFields({
    required this.controller,
    required this.onCompleted,
  });

  @override
  State<_OtpInputFields> createState() => _OtpInputFieldsState();
}

class _OtpInputFieldsState extends State<_OtpInputFields> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
    if (widget.controller.text.length == 6) {
      widget.onCompleted(widget.controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final isFocused = _focusNode.hasFocus;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _focusNode.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              autofocus: true,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              final digit = index < text.length ? text[index] : '';
              final isCurrent = isFocused && index == text.length;
              final isFilled = index < text.length;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.borderRadiusMedium,
                  ),
                  border: Border.all(
                    color: isCurrent
                        ? AppColors.lavender
                        : (isFilled ? AppColors.softRose : Colors.grey.shade300),
                    width: isCurrent || isFilled ? 2 : 1,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: AppColors.lavender.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  digit,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
