import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../models/mood_message_model.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/mood_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/smart_profile_image.dart';

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  final TextEditingController _callSignController = TextEditingController();
  final FocusNode _callSignFocusNode = FocusNode();
  late final List<_MoodOption> _moodOptions;
  late final Map<String, _MoodOption> _moodLookup;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _moodOptions = _buildMoodOptions();
    _moodLookup = {
      for (final option in _moodOptions) option.key: option,
    };
  }

  @override
  void dispose() {
    _callSignController.dispose();
    _callSignFocusNode.dispose();
    super.dispose();
  }

  List<_MoodOption> _buildMoodOptions() {
    return const [
      _MoodOption(
        key: 'like',
        label: 'Like',
        icon: Icons.thumb_up_alt,
        color: AppColors.softRose,
      ),
      _MoodOption(
        key: 'sad',
        label: 'Sad',
        icon: Icons.sentiment_dissatisfied,
        color: Colors.blueGrey,
      ),
      _MoodOption(
        key: 'happy',
        label: 'Happy',
        icon: Icons.sentiment_satisfied,
        color: Colors.amber,
      ),
      _MoodOption(
        key: 'angry',
        label: 'Angry',
        icon: Icons.sentiment_very_dissatisfied,
        color: Colors.redAccent,
      ),
      _MoodOption(
        key: 'excited',
        label: 'Excited',
        icon: Icons.celebration,
        color: AppColors.lavender,
      ),
      _MoodOption(
        key: 'hungry',
        label: 'Hungry',
        icon: Icons.restaurant,
        color: Colors.orange,
      ),
      _MoodOption(
        key: 'sleepy',
        label: 'Sleepy',
        icon: Icons.bedtime,
        color: Colors.indigo,
      ),
      _MoodOption(
        key: 'bored',
        label: 'Bored',
        icon: Icons.sentiment_neutral,
        color: Colors.grey,
      ),
      _MoodOption(
        key: 'nervous',
        label: 'Nervous',
        icon: Icons.warning_amber,
        color: Colors.teal,
      ),
    ];
  }

  Future<void> _sendMood(
    MoodProvider provider,
    String mood,
    String callSign,
  ) async {
    if (!provider.canSend || provider.isSending) return;
    final trimmedCallSign = callSign.trim();
    if (trimmedCallSign.isEmpty) return;
    await provider.sendMood(mood: mood, callSign: trimmedCallSign);
  }

  @override
  Widget build(BuildContext context) {
    final moodProvider = context.watch<MoodProvider>();
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final user = userProvider.user;
    final partner = coupleProvider.partner;
    final moods = moodProvider.moods;

    final errorMessage = moodProvider.error;
    if (errorMessage != null && errorMessage != _lastError) {
      _lastError = errorMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(errorMessage)));
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood'),
      ),
      body: user == null || partner == null
          ? Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLg),
              child: _buildNotLinkedState(context),
            )
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.spacingLg,
                      AppDimensions.spacingLg,
                      AppDimensions.spacingLg,
                      0,
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: moods.isEmpty
                              ? _buildEmptyState(context)
                              : ListView.separated(
                                  reverse: true,
                                  padding: const EdgeInsets.only(
                                    bottom: AppDimensions.spacingSm,
                                  ),
                                  itemCount: moods.length,
                                  separatorBuilder: (_, __) => const SizedBox(
                                    height: AppDimensions.spacingSm,
                                  ),
                                  itemBuilder: (context, index) {
                                    return _buildMoodTile(
                                      context,
                                      mood: moods[index],
                                      userId: user.id,
                                      userPhotoUrl: user.photoUrl,
                                      partnerPhotoUrl: partner.photoUrl,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedPadding(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.fromLTRB(
                    AppDimensions.spacingLg,
                    AppDimensions.spacingSm,
                    AppDimensions.spacingLg,
                    isKeyboardOpen
                        ? AppDimensions.spacingXs
                        : AppDimensions.spacingLg,
                  ),
                  child: _buildMoodComposer(
                    context,
                    provider: moodProvider,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMoodComposer(
    BuildContext context, {
    required MoodProvider provider,
  }) {
    final canSend = provider.canSend && !provider.isSending;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final fieldFillColor =
        isDark ? AppColors.darkSurface : Colors.grey.shade100;
    final hintColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final textColor = isDark ? AppColors.darkText : AppColors.deepCharcoal;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxComposerHeight =
        isKeyboardOpen ? screenHeight * 0.32 : double.infinity;
    final verticalSpacing =
        isKeyboardOpen ? AppDimensions.spacingXs : AppDimensions.spacingMd;
    final cardPadding = EdgeInsets.fromLTRB(
      AppDimensions.cardPadding,
      isKeyboardOpen ? AppDimensions.spacingSm : AppDimensions.cardPadding,
      AppDimensions.cardPadding,
      isKeyboardOpen ? AppDimensions.spacingSm : AppDimensions.cardPadding,
    );

    final composerBody = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Send a mood',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: verticalSpacing),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _callSignController,
          builder: (context, value, _) {
            final callSign = value.text.trim();
            final canSendMood = canSend && callSign.isNotEmpty;
            return Column(
              children: [
                TextField(
                  controller: _callSignController,
                  focusNode: _callSignFocusNode,
                  enabled: canSend,
                  textInputAction: TextInputAction.done,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textColor,
                      ),
                  cursorColor: isDark ? AppColors.lavender : AppColors.softRose,
                  decoration: InputDecoration(
                    hintText: 'Callsign (e.g., wife)',
                    hintStyle: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: hintColor),
                    filled: true,
                    fillColor: fieldFillColor,
                    isDense: isKeyboardOpen,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingMd,
                      vertical: isKeyboardOpen
                          ? AppDimensions.spacingXs
                          : AppDimensions.spacingSm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.borderRadiusMedium,
                      ),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.borderRadiusMedium,
                      ),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.borderRadiusMedium,
                      ),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.lavender : AppColors.softRose,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Wrap(
                  spacing: AppDimensions.spacingSm,
                  runSpacing: AppDimensions.spacingSm,
                  alignment: WrapAlignment.center,
                  children: _moodOptions.map((option) {
                    return _MoodButton(
                      option: option,
                      enabled: canSendMood,
                      onTap: () => _sendMood(
                        provider,
                        option.key,
                        callSign,
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ],
    );

    final composerContent = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxComposerHeight),
      child: SingleChildScrollView(
        physics: isKeyboardOpen
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        child: composerBody,
      ),
    );

    return AppCard(
      padding: cardPadding,
      child: composerContent,
    );
  }

  Widget _buildMoodTile(
    BuildContext context, {
    required MoodMessageModel mood,
    required String? userId,
    required String? userPhotoUrl,
    required String? partnerPhotoUrl,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMine = mood.senderId == userId;
    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(AppDimensions.borderRadiusMedium),
      topRight: const Radius.circular(AppDimensions.borderRadiusMedium),
      bottomLeft: Radius.circular(
        isMine ? AppDimensions.borderRadiusMedium : 6,
      ),
      bottomRight: Radius.circular(
        isMine ? 6 : AppDimensions.borderRadiusMedium,
      ),
    );

    final option = _moodLookup[mood.mood];
    final icon = option?.icon ?? Icons.emoji_emotions_outlined;
    final iconBaseColor = option?.color ?? AppColors.softRose;
    final iconColor = isDark ? iconBaseColor.withOpacity(0.9) : iconBaseColor;
    final moodLabel = option?.label ?? mood.mood;
    final callSign = mood.callSign.trim();
    final moodText = callSign.isEmpty
        ? moodLabel
        : 'Your $callSign is ${moodLabel.toLowerCase()}';
    final bubbleColor = isDark
        ? (isMine
            ? AppColors.lavender.withOpacity(0.25)
            : AppColors.softRose.withOpacity(0.25))
        : (isMine ? AppColors.lavenderLight : AppColors.softRoseLight);
    final bubbleTextColor =
        isDark ? AppColors.darkText : AppColors.deepCharcoal;
    final metaColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine) ...[
              _buildAvatar(
                photoUrl: partnerPhotoUrl,
                accentColor: AppColors.softRose,
                fallbackIcon: Icons.favorite,
              ),
              const SizedBox(width: AppDimensions.spacingSm),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingMd,
                      vertical: AppDimensions.spacingSm,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: bubbleRadius,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 22, color: iconColor),
                        const SizedBox(width: AppDimensions.spacingXs),
                        Text(
                          moodText,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: bubbleTextColor,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mood.formattedDateTime,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: metaColor,
                        ),
                  ),
                ],
              ),
            ),
            if (isMine) ...[
              const SizedBox(width: AppDimensions.spacingSm),
              _buildAvatar(
                photoUrl: userPhotoUrl,
                accentColor: AppColors.lavender,
                fallbackIcon: Icons.person,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotLinkedState(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Icon(
            Icons.emoji_emotions_outlined,
            color: AppColors.softRose,
            size: 48,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            'Link with your partner to share moods',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            'Once linked, you can send quick mood updates.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_emotions_outlined,
            size: 48,
            color: AppColors.lavender,
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'No moods yet',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({
    required String? photoUrl,
    required Color accentColor,
    required IconData fallbackIcon,
  }) {
    const double size = 32;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accentColor, width: 2),
      ),
      child: ClipOval(
        child: SmartProfileImage(
          imageUrl: photoUrl,
          width: size,
          height: size,
          placeholder: _buildAvatarPlaceholder(size, accentColor, fallbackIcon),
          errorWidget: _buildAvatarPlaceholder(size, accentColor, fallbackIcon),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(
    double size,
    Color accentColor,
    IconData icon,
  ) {
    return Container(
      width: size,
      height: size,
      color: accentColor.withOpacity(0.15),
      child: Icon(
        icon,
        size: 18,
        color: accentColor,
      ),
    );
  }
}

class _MoodOption {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const _MoodOption({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _MoodButton extends StatelessWidget {
  const _MoodButton({
    required this.option,
    required this.enabled,
    required this.onTap,
  });

  final _MoodOption option;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = option.color;
    final backgroundColor = enabled
        ? (isDark ? baseColor.withOpacity(0.25) : baseColor.withOpacity(0.15))
        : (isDark ? Colors.grey.shade800 : Colors.grey.shade200);
    final borderColor = enabled
        ? (isDark ? baseColor.withOpacity(0.6) : baseColor.withOpacity(0.4))
        : (isDark ? Colors.grey.shade700 : Colors.grey.shade300);
    final labelColor = enabled
        ? (isDark ? AppColors.darkText : AppColors.deepCharcoal)
        : (isDark ? Colors.grey.shade500 : Colors.grey);
    final iconColor =
        enabled ? baseColor : (isDark ? Colors.grey.shade500 : Colors.grey);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingSm,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusFull),
          border: Border.all(
            color: borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(option.icon, size: 18, color: iconColor),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              option.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
