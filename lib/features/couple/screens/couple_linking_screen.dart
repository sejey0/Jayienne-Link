import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../models/partner_request_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/loading_overlay.dart';

class CoupleLinkingScreen extends StatefulWidget {
  const CoupleLinkingScreen({super.key});

  @override
  State<CoupleLinkingScreen> createState() => _CoupleLinkingScreenState();
}

class _CoupleLinkingScreenState extends State<CoupleLinkingScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _searchUser() async {
    final email = _emailController.text.trim();
    final validationError = Validators.validateEmail(email);
    if (validationError != null) {
      SnackbarHelper.showError(context, validationError);
      return;
    }

    final currentUser = context.read<UserProvider>().user;
    if (currentUser == null) {
      SnackbarHelper.showError(
        context,
        'User profile not loaded. Please refresh and try again.',
      );
      return;
    }

    final coupleProvider = context.read<CoupleProvider>();
    await coupleProvider.searchUserByEmail(email, currentUser.id);

    if (!mounted) return;

    if (coupleProvider.error != null) {
      SnackbarHelper.showError(context, coupleProvider.error!);
    }
  }

  Future<void> _sendRequest(UserModel receiver) async {
    final sender = context.read<UserProvider>().user;
    if (sender == null) {
      SnackbarHelper.showError(
        context,
        'User profile not loaded. Please refresh and try again.',
      );
      return;
    }

    final coupleProvider = context.read<CoupleProvider>();
    final success = await coupleProvider.sendPartnerRequest(
      sender: sender,
      receiver: receiver,
    );

    if (!mounted) return;

    if (success) {
      SnackbarHelper.showSuccess(context, 'Request sent');
    } else if (coupleProvider.error != null) {
      SnackbarHelper.showError(context, coupleProvider.error!);
    }
  }

  Future<void> _acceptRequest(PartnerRequestModel request) async {
    final coupleProvider = context.read<CoupleProvider>();
    final success = await coupleProvider.acceptPartnerRequest(request);

    if (!mounted) return;

    if (success) {
      SnackbarHelper.showSuccess(context, 'Partner request accepted');
      context.go(RouteNames.coupleSuccess);
    } else if (coupleProvider.error != null) {
      SnackbarHelper.showError(context, coupleProvider.error!);
    }
  }

  Future<void> _declineRequest(PartnerRequestModel request) async {
    final coupleProvider = context.read<CoupleProvider>();
    await coupleProvider.declinePartnerRequest(request.id);

    if (!mounted) return;

    if (coupleProvider.error != null) {
      SnackbarHelper.showError(context, coupleProvider.error!);
    } else {
      SnackbarHelper.showInfo(context, 'Request declined');
    }
  }

  Future<void> _cancelRequest(PartnerRequestModel request) async {
    final coupleProvider = context.read<CoupleProvider>();
    await coupleProvider.cancelPartnerRequest(request.id);

    if (!mounted) return;

    if (coupleProvider.error != null) {
      SnackbarHelper.showError(context, coupleProvider.error!);
    } else {
      SnackbarHelper.showInfo(context, 'Request canceled');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final currentUser = userProvider.user;
    final searchResult = coupleProvider.searchResult;
    final incoming = coupleProvider.incomingRequests;
    final outgoing = coupleProvider.outgoingRequests;

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
                Text(
                  'Find your partner by email',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                AppTextField(
                  controller: _emailController,
                  hintText: AppStrings.email,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                AppButton(
                  label: 'Search',
                  icon: Icons.search,
                  onPressed: _searchUser,
                  isLoading: coupleProvider.isSearching,
                ),
                if (searchResult != null) ...[
                  const SizedBox(height: AppDimensions.spacingLg),
                  _buildSearchResultCard(context, searchResult),
                ],
                const SizedBox(height: AppDimensions.spacingXl),
                _buildRequestsSection(
                  context,
                  title: 'Requests from others',
                  emptyText: 'No incoming requests yet.',
                  requests: incoming,
                  onPrimaryAction: _acceptRequest,
                  onSecondaryAction: _declineRequest,
                  primaryLabel: 'Accept',
                  secondaryLabel: 'Decline',
                  isIncoming: true,
                ),
                const SizedBox(height: AppDimensions.spacingXl),
                _buildRequestsSection(
                  context,
                  title: 'Requests you sent',
                  emptyText: 'No sent requests yet.',
                  requests: outgoing,
                  onPrimaryAction: _cancelRequest,
                  onSecondaryAction: null,
                  primaryLabel: 'Cancel',
                  secondaryLabel: null,
                  isIncoming: false,
                ),
                const SizedBox(height: AppDimensions.spacingXl),
                if (currentUser != null)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final auth = context.read<AuthProvider>();
                      final userId = currentUser.id.isNotEmpty
                          ? currentUser.id
                          : auth.currentUserId;
                      if (userId == null) {
                        if (mounted) {
                          SnackbarHelper.showError(
                            context,
                            'User ID not found. Please sign in again.',
                          );
                        }
                        return;
                      }

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

                      if (!context.mounted) return;

                      if (confirmed == true) {
                        final success =
                            await userProvider.skipCoupleLink(userId);

                        if (!context.mounted) return;

                        if (success) {
                          await Future.delayed(
                            const Duration(milliseconds: 300),
                          );
                          if (!context.mounted) return;
                          context.go(RouteNames.home);
                        } else {
                          SnackbarHelper.showError(
                            context,
                            userProvider.error ??
                                'Failed to skip. Please try again.',
                          );
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

  Widget _buildSearchResultCard(BuildContext context, UserModel user) {
    final isLinked = user.coupleId != null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: AppDimensions.avatarSizeMedium / 2,
                backgroundColor: AppColors.peach.withOpacity(0.3),
                child: const Icon(Icons.person, color: AppColors.softRose),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName.isNotEmpty
                          ? user.displayName
                          : user.email,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isLinked) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              'This user is already linked. You can still send a request.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: AppDimensions.spacingMd),
          AppButton(
            label: 'Send Request',
            icon: Icons.send,
            onPressed: () => _sendRequest(user),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsSection(
    BuildContext context, {
    required String title,
    required String emptyText,
    required List<PartnerRequestModel> requests,
    required Future<void> Function(PartnerRequestModel request) onPrimaryAction,
    required Future<void> Function(PartnerRequestModel request)?
        onSecondaryAction,
    required String primaryLabel,
    required String? secondaryLabel,
    required bool isIncoming,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        if (requests.isEmpty)
          Text(
            emptyText,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          )
        else
          Column(
            children: requests.map((request) {
              final name =
                  isIncoming ? request.senderName : request.receiverName;
              final email =
                  isIncoming ? request.senderEmail : request.receiverEmail;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? name : email,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: AppDimensions.spacingMd),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: primaryLabel,
                              variant: AppButtonVariant.secondary,
                              onPressed: () => onPrimaryAction(request),
                            ),
                          ),
                          if (secondaryLabel != null &&
                              onSecondaryAction != null) ...[
                            const SizedBox(width: AppDimensions.spacingSm),
                            Expanded(
                              child: AppButton(
                                label: secondaryLabel,
                                variant: AppButtonVariant.text,
                                onPressed: () => onSecondaryAction(request),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
