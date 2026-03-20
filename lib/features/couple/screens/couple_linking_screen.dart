import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/loading_overlay.dart';

class CoupleLinkingScreen extends StatefulWidget {
  const CoupleLinkingScreen({super.key});

  @override
  State<CoupleLinkingScreen> createState() => _CoupleLinkingScreenState();
}

class _CoupleLinkingScreenState extends State<CoupleLinkingScreen> {
  final _codeController = TextEditingController();
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrGenerateCode();
    });
    _startExpiryTimer();
  }

  void _loadOrGenerateCode() {
    final auth = context.read<AuthProvider>();
    final user = context.read<UserProvider>().user;
    final coupleProvider = context.read<CoupleProvider>();

    // User must complete profile setup first
    if (user == null) {
      SnackbarHelper.showError(
        context,
        'Please complete your profile setup first',
      );
      context.go(RouteNames.profileSetup);
      return;
    }

    if (user.inviteCode != null) {
      coupleProvider.loadExistingCode(user.inviteCode);
    } else {
      coupleProvider.generateCode(auth.currentUserId!);
    }
  }

  void _startExpiryTimer() {
    _expiryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _expiryTimer?.cancel();
    super.dispose();
  }

  String _formatTimeRemaining(DateTime? expiresAt) {
    if (expiresAt == null) return '';
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return AppStrings.codeExpired;
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    return '${AppStrings.expiresIn} ${hours}h ${minutes}m';
  }

  Future<void> _redeemCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) return;

    final auth = context.read<AuthProvider>();
    final coupleProvider = context.read<CoupleProvider>();
    final success =
        await coupleProvider.redeemCode(code, auth.currentUserId!);

    if (!mounted) return;

    if (success) {
      context.go(RouteNames.coupleSuccess);
    } else if (coupleProvider.error != null) {
      SnackbarHelper.showError(context, coupleProvider.error!);
      if (mounted) {
        _codeController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coupleProvider = context.watch<CoupleProvider>();
    final inviteCode = coupleProvider.inviteCode;
    final expiresAt = coupleProvider.codeExpiresAt;
    final isExpired = expiresAt != null && DateTime.now().isAfter(expiresAt);

    return LoadingOverlay(
      isLoading: coupleProvider.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text(AppStrings.linkWithPartner)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Your invite code section
                Text(
                  AppStrings.yourInviteCode,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                if (inviteCode != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.spacingLg,
                      horizontal: AppDimensions.spacingMd,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color ??
                          Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.borderRadiusMedium,
                      ),
                      border: Border.all(
                        color: AppColors.softRose.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: inviteCode.split('').map((char) {
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: 44,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.softRose.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.borderRadiusSmall,
                                  ),
                                  border: Border.all(
                                    color: AppColors.softRose.withOpacity(0.3),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    char,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.softRose,
                                        ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingMd),
                        Text(
                          _formatTimeRemaining(expiresAt),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color:
                                    isExpired ? AppColors.error : Colors.grey,
                              ),
                        ),
                        const SizedBox(height: AppDimensions.spacingMd),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!isExpired) ...[
                              TextButton.icon(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: inviteCode),
                                  );
                                  SnackbarHelper.showSuccess(
                                    context,
                                    AppStrings.codeCopied,
                                  );
                                },
                                icon: const Icon(Icons.copy, size: 18),
                                label: const Text(AppStrings.copyCode),
                              ),
                              const SizedBox(width: AppDimensions.spacingMd),
                              TextButton.icon(
                                onPressed: () {
                                  Share.share(
                                    'Join me on Jayienne Link! Use my invite code: $inviteCode',
                                  );
                                },
                                icon: const Icon(Icons.share, size: 18),
                                label: const Text(AppStrings.shareCode),
                              ),
                            ] else
                              TextButton.icon(
                                onPressed: () {
                                  final auth = context.read<AuthProvider>();
                                  coupleProvider.regenerateCode(
                                    auth.currentUserId!,
                                  );
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text(AppStrings.generateNewCode),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else
                  const Center(child: CircularProgressIndicator()),
                const SizedBox(height: AppDimensions.spacingXl),
                const Divider(),
                const SizedBox(height: AppDimensions.spacingXl),
                // Enter partner's code section
                Text(
                  AppStrings.enterPartnerCode,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                PinCodeTextField(
                  appContext: context,
                  length: 6,
                  controller: _codeController,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  animationType: AnimationType.fade,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.borderRadiusMedium,
                    ),
                    fieldHeight: 56,
                    fieldWidth: 48,
                    activeColor: AppColors.lavender,
                    inactiveColor: Colors.grey.shade300,
                    selectedColor: AppColors.softRose,
                    activeFillColor: Theme.of(context).colorScheme.surface,
                    inactiveFillColor: Theme.of(context).colorScheme.surface,
                    selectedFillColor: Theme.of(context).colorScheme.surface,
                  ),
                  enableActiveFill: true,
                  onChanged: (_) {},
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                AppButton(
                  label: AppStrings.linkNow,
                  icon: Icons.favorite,
                  onPressed: _redeemCode,
                  isLoading: coupleProvider.isLoading,
                ),
                const SizedBox(height: AppDimensions.spacingXl),
                // Skip button
                OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Skip for now?'),
                        content: const Text(
                          'You can link with your partner later from the home screen. '
                          'Some features will be limited until you link.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Skip'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && mounted) {
                      final auth = context.read<AuthProvider>();
                      final userProvider = context.read<UserProvider>();
                      final router = GoRouter.of(context);
                      final success = await userProvider.skipCoupleLink(
                        auth.currentUserId!,
                      );
                      if (success && mounted) {
                        router.go(RouteNames.home);
                      }
                    }
                  },
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Skip for now'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: BorderSide(color: Colors.grey.shade300),
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
