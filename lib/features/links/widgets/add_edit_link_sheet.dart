import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/social_link_model.dart';
import '../../../providers/couple_links_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/common/app_text_field.dart';
import 'link_added_success_modal.dart';
import 'platform_brand_icon.dart';

/// Formatter that automatically capitalizes the first letter of each word
class CapitalizeWordsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final buffer = StringBuffer();
    bool capitalizeNext = true;

    for (int i = 0; i < newValue.text.length; i++) {
      final char = newValue.text[i];
      if (char == ' ' || char == '-' || char == '_' || char == '/') {
        buffer.write(char);
        capitalizeNext = true;
      } else if (capitalizeNext) {
        buffer.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(char);
      }
    }

    final capitalizedString = buffer.toString();
    return newValue.copyWith(
      text: capitalizedString,
      selection: newValue.selection,
    );
  }
}

class AddEditLinkSheet extends StatefulWidget {
  final SocialLinkModel? initialLink;

  const AddEditLinkSheet({
    super.key,
    this.initialLink,
  });

  static Future<void> show(
    BuildContext context, {
    SocialLinkModel? initialLink,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditLinkSheet(initialLink: initialLink),
    );
  }

  @override
  State<AddEditLinkSheet> createState() => _AddEditLinkSheetState();
}

class _AddEditLinkSheetState extends State<AddEditLinkSheet> {
  final _formKey = GlobalKey<FormState>();
  late SocialPlatform _selectedPlatform;
  late final TextEditingController _inputController;
  late final TextEditingController _titleController;

  bool get _isEditing => widget.initialLink != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialLink != null) {
      _selectedPlatform = widget.initialLink!.socialPlatform;
      _inputController = TextEditingController(
        text: widget.initialLink!.username.isNotEmpty
            ? widget.initialLink!.username
            : widget.initialLink!.url,
      );
      _titleController = TextEditingController(text: widget.initialLink!.title);
    } else {
      _selectedPlatform = SocialPlatform.website;
      _inputController = TextEditingController();
      _titleController = TextEditingController();
    }

    _inputController.addListener(() {
      final text = _inputController.text.trim();
      if (text.isNotEmpty) {
        final detected = SocialPlatform.detectFromUrl(text);
        if (detected != null && detected != _selectedPlatform) {
          setState(() {
            _selectedPlatform = detected;
          });
          return;
        }
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  String get _livePreviewUrl {
    final text = _inputController.text.trim();
    if (text.isEmpty) return '';
    return _selectedPlatform.formatUrl(text);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<CoupleLinksProvider>();
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.user;

    final rawInput = _inputController.text.trim();
    final customTitle = _titleController.text.trim();

    HapticFeedback.mediumImpact();

    if (_isEditing) {
      final success = await provider.updateLink(
        linkId: widget.initialLink!.id,
        platform: _selectedPlatform,
        usernameOrUrl: rawInput,
        title: customTitle.isNotEmpty ? customTitle : _selectedPlatform.displayName,
      );

      if (!mounted) return;

      if (success) {
        final updatedLink = provider.links.firstWhere(
          (l) => l.id == widget.initialLink!.id,
          orElse: () => widget.initialLink!.copyWith(
            platform: _selectedPlatform.name,
            title: customTitle.isNotEmpty ? customTitle : _selectedPlatform.displayName,
            url: _selectedPlatform.formatUrl(rawInput),
            username: rawInput,
          ),
        );
        Navigator.of(context).pop();
        LinkAddedSuccessModal.show(context, updatedLink, isEditing: true);
      } else {
        SnackbarHelper.showError(
          context,
          provider.error ?? 'Failed to update link. Please try again.',
        );
      }
    } else {
      final createdLink = await provider.addLink(
        platform: _selectedPlatform,
        usernameOrUrl: rawInput,
        title: customTitle.isNotEmpty ? customTitle : _selectedPlatform.displayName,
        userDisplayName: currentUser?.displayName,
        userPhotoUrl: currentUser?.photoUrl,
      );

      if (!mounted) return;

      if (createdLink != null) {
        Navigator.of(context).pop();
        LinkAddedSuccessModal.show(context, createdLink);
      } else {
        SnackbarHelper.showError(
          context,
          provider.error ?? 'Failed to share link. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final linksProvider = context.watch<CoupleLinksProvider>();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1427) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: AppColors.softRose.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.softRose.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.softRose, AppColors.lavender],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.softRose.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isEditing ? Icons.edit_rounded : Icons.add_link_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing ? 'Edit Profile Link' : 'Add Profile or Website Link',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Share your social profiles or favorite web links',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Platform Selector Section
                  Text(
                    'SELECT PLATFORM',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: isDark ? AppColors.softRoseLight : AppColors.softRose,
                    ),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    height: 84,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: SocialPlatform.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final platform = SocialPlatform.values[index];
                        final isSelected = _selectedPlatform == platform;

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedPlatform = platform;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark
                                      ? platform.primaryColor.withValues(alpha: 0.25)
                                      : platform.primaryColor.withValues(alpha: 0.12))
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? platform.primaryColor
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.grey.shade300),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: platform.primaryColor.withValues(alpha: 0.25),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                PlatformBrandIcon(
                                  platform: platform,
                                  size: 32,
                                  borderRadius: 10,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  platform.displayName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected
                                        ? (isDark ? Colors.white : platform.primaryColor)
                                        : (isDark ? Colors.white70 : Colors.grey.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Username / Account Link Input Field
                  Text(
                    'ACCOUNT / URL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: isDark ? AppColors.softRoseLight : AppColors.softRose,
                    ),
                  ),
                  const SizedBox(height: 8),

                  AppTextField(
                    controller: _inputController,
                    hintText: _selectedPlatform.placeholder,
                    prefixWidget: SizedBox(
                      width: 44,
                      child: Center(
                        child: PlatformBrandIcon(
                          platform: _selectedPlatform,
                          customUrl: _livePreviewUrl,
                          size: 20,
                          showBackground: false,
                        ),
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter username or website URL';
                      }
                      return null;
                    },
                    borderRadius: BorderRadius.circular(16),
                    isDark: isDark,
                  ),

                  // Live Preview URL Box
                  if (_livePreviewUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : AppColors.softRose.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.softRose.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          PlatformBrandIcon(
                            platform: _selectedPlatform,
                            customUrl: _livePreviewUrl,
                            size: 22,
                            borderRadius: 6,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tap action will open:',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.softRose,
                                  ),
                                ),
                                Text(
                                  _livePreviewUrl,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Custom Title / Label Input Field
                  Text(
                    'TITLE / LABEL (OPTIONAL)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: isDark ? AppColors.softRoseLight : AppColors.softRose,
                    ),
                  ),
                  const SizedBox(height: 8),

                  AppTextField(
                    controller: _titleController,
                    hintText: 'e.g. My Main Account, Favorite Playlist',
                    prefixIcon: Icons.label_outline_rounded,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [
                      CapitalizeWordsInputFormatter(),
                    ],
                    borderRadius: BorderRadius.circular(16),
                    isDark: isDark,
                  ),

                  const SizedBox(height: 26),

                  // Submit Button
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.softRose, AppColors.lavender],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.softRose.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: linksProvider.isSaving ? null : _submit,
                      icon: linksProvider.isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _isEditing ? Icons.check_rounded : Icons.favorite_rounded,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isEditing ? 'Save Changes' : 'Share Link with Partner',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
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
