import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/mood_message_model.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/mood_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_text_field.dart';
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
  final List<_MoodOption> _customMoods = [];
  String? _selectedMoodKey;
  String? _lastError;
  bool _isSelectionMode = false;
  final Set<String> _selectedMoodIds = {};
  bool _isComposerHidden = false;

  @override
  void initState() {
    super.initState();
    _moodOptions = _buildMoodOptions();
    _moodLookup = {
      for (final option in _moodOptions) option.key: option,
    };
    _selectedMoodKey = null;
    _loadCustomMoods();
  }

  @override
  void dispose() {
    _callSignController.dispose();
    _callSignFocusNode.dispose();
    super.dispose();
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedMoodIds.clear();
      }
    });
  }

  void _toggleMoodSelection(String id) {
    setState(() {
      if (_selectedMoodIds.contains(id)) {
        _selectedMoodIds.remove(id);
        if (_selectedMoodIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMoodIds.add(id);
      }
    });
  }

  void _selectAll(List<MoodMessageModel> moods) {
    setState(() {
      final allIds = moods.map((m) => m.id).whereType<String>().toSet();
      if (_selectedMoodIds.length == allIds.length) {
        _selectedMoodIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedMoodIds.addAll(allIds);
      }
    });
  }

  Future<void> _confirmDeleteSingleMood(
    MoodProvider provider,
    String moodId,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1C1427) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Mood?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text('Are you sure you want to delete this mood message?'),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF758C), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFFFF758C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await provider.deleteMood(moodId);
      if (mounted) {
        if (success) {
          SnackbarHelper.showSuccess(context, 'Mood deleted');
        } else {
          SnackbarHelper.showError(context, 'Failed to delete mood');
        }
      }
    }
  }

  Future<void> _confirmBulkDelete(MoodProvider provider) async {
    if (_selectedMoodIds.isEmpty) return;
    final count = _selectedMoodIds.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1C1427) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_sweep_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Selected?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete $count selected mood message${count > 1 ? 's' : ''}?',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF758C), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFFFF758C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final idsToDelete = _selectedMoodIds.toList();
      final success = await provider.deleteMoods(idsToDelete);
      if (mounted) {
        setState(() {
          _isSelectionMode = false;
          _selectedMoodIds.clear();
        });
        if (success) {
          SnackbarHelper.showSuccess(
            context,
            '$count mood${count > 1 ? 's' : ''} deleted',
          );
        } else {
          SnackbarHelper.showError(context, 'Failed to delete selected moods');
        }
      }
    }
  }

  Future<void> _loadCustomMoods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList('saved_custom_moods') ?? [];
      final loaded = <_MoodOption>[];
      for (final raw in rawList) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final key = map['key'] as String;
        final label = map['label'] as String;
        final iconCode = map['iconCode'] as int?;
        final icon = _findIcon(iconCode);
        final option = _MoodOption(
          key: key,
          label: label,
          icon: icon,
          color: AppColors.softRose,
          gradientColors: const [Color(0xFFFF758C), Color(0xFFA18CD1)],
        );
        loaded.add(option);
        _moodLookup[key] = option;
      }
      if (mounted && loaded.isNotEmpty) {
        setState(() {
          _customMoods.clear();
          _customMoods.addAll(loaded);
        });
      }
    } catch (_) {}
  }

  static IconData _findIcon(int? codePoint) {
    if (codePoint == null) return Icons.star_rounded;
    for (final choice in _iconChoices) {
      if (choice.icon.codePoint == codePoint) return choice.icon;
    }
    return Icons.star_rounded;
  }

  static const List<_IconChoice> _iconChoices = [
    // Emotions & Faces
    _IconChoice(Icons.emoji_emotions_outlined, 'Happy'),
    _IconChoice(Icons.sentiment_very_satisfied_rounded, 'Overjoyed'),
    _IconChoice(Icons.sentiment_dissatisfied_rounded, 'Sad'),
    _IconChoice(Icons.sentiment_very_dissatisfied_rounded, 'Angry'),
    _IconChoice(Icons.sentiment_neutral_rounded, 'Neutral'),
    _IconChoice(Icons.face_rounded, 'Calm'),
    _IconChoice(Icons.mood_bad_rounded, 'Upset'),
    _IconChoice(Icons.tag_faces_rounded, 'Playful'),
    // Love & Connection
    _IconChoice(Icons.favorite_rounded, 'Love'),
    _IconChoice(Icons.favorite_border_rounded, 'Caring'),
    _IconChoice(Icons.volunteer_activism_rounded, 'Giving'),
    _IconChoice(Icons.handshake_rounded, 'Connected'),
    // Energy & Action
    _IconChoice(Icons.local_fire_department_rounded, 'Fire'),
    _IconChoice(Icons.bolt_rounded, 'Energized'),
    _IconChoice(Icons.rocket_launch_rounded, 'Motivated'),
    _IconChoice(Icons.celebration_rounded, 'Excited'),
    _IconChoice(Icons.sports_score_rounded, 'Focused'),
    _IconChoice(Icons.fitness_center_rounded, 'Strong'),
    // Relaxation & Wellness
    _IconChoice(Icons.spa_rounded, 'Relaxed'),
    _IconChoice(Icons.self_improvement_rounded, 'Mindful'),
    _IconChoice(Icons.bedtime_rounded, 'Sleepy'),
    _IconChoice(Icons.beach_access_rounded, 'Chill'),
    _IconChoice(Icons.hot_tub_rounded, 'Cozy'),
    _IconChoice(Icons.coffee_rounded, 'Coffee'),
    // Nature & Weather
    _IconChoice(Icons.wb_sunny_rounded, 'Sunny'),
    _IconChoice(Icons.cloud_rounded, 'Cloudy'),
    _IconChoice(Icons.thunderstorm_rounded, 'Stormy'),
    _IconChoice(Icons.ac_unit_rounded, 'Cold'),
    _IconChoice(Icons.local_florist_rounded, 'Blooming'),
    _IconChoice(Icons.park_rounded, 'Peaceful'),
    // Activities
    _IconChoice(Icons.music_note_rounded, 'Musical'),
    _IconChoice(Icons.sports_esports_rounded, 'Gaming'),
    _IconChoice(Icons.movie_rounded, 'Cinematic'),
    _IconChoice(Icons.restaurant_rounded, 'Hungry'),
    _IconChoice(Icons.flight_rounded, 'Adventurous'),
    _IconChoice(Icons.menu_book_rounded, 'Studious'),
    // Status & Misc
    _IconChoice(Icons.star_rounded, 'Star'),
    _IconChoice(Icons.auto_awesome_rounded, 'Magical'),
    _IconChoice(Icons.diamond_rounded, 'Precious'),
    _IconChoice(Icons.warning_amber_rounded, 'Anxious'),
    _IconChoice(Icons.hourglass_empty_rounded, 'Waiting'),
    _IconChoice(Icons.nightlight_round_outlined, 'Nighttime'),
  ];

  Future<void> _saveCustomMoods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = _customMoods.map((opt) {
        return jsonEncode({
          'key': opt.key,
          'label': opt.label,
          'iconCode': opt.icon.codePoint,
        });
      }).toList();
      await prefs.setStringList('saved_custom_moods', rawList);
    } catch (_) {}
  }

  List<_MoodOption> _buildMoodOptions() {
    return const [
      _MoodOption(
        key: 'like',
        label: 'Like',
        icon: Icons.favorite_rounded,
        color: AppColors.softRose,
        gradientColors: [Color(0xFFFF5252), Color(0xFFD81B60)],
      ),
      _MoodOption(
        key: 'happy',
        label: 'Happy',
        icon: Icons.sentiment_very_satisfied_rounded,
        color: Color(0xFFFF4081),
        gradientColors: [Color(0xFFFF4081), Color(0xFFAB47BC)],
      ),
      _MoodOption(
        key: 'excited',
        label: 'Excited',
        icon: Icons.celebration_rounded,
        color: Color(0xFFA18CD1),
        gradientColors: [Color(0xFFEC407A), Color(0xFF8E24AA)],
      ),
      _MoodOption(
        key: 'sad',
        label: 'Sad',
        icon: Icons.sentiment_dissatisfied_rounded,
        color: Color(0xFF8E24AA),
        gradientColors: [Color(0xFF9C27B0), Color(0xFF512DA8)],
      ),
      _MoodOption(
        key: 'angry',
        label: 'Angry',
        icon: Icons.sentiment_very_dissatisfied_rounded,
        color: Color(0xFFFF5252),
        gradientColors: [Color(0xFFFF5252), Color(0xFFC2185B)],
      ),
      _MoodOption(
        key: 'hungry',
        label: 'Hungry',
        icon: Icons.restaurant_rounded,
        color: Color(0xFFEC407A),
        gradientColors: [Color(0xFFFF6E40), Color(0xFFE91E63)],
      ),
      _MoodOption(
        key: 'sleepy',
        label: 'Sleepy',
        icon: Icons.bedtime_rounded,
        color: Color(0xFF7B1FA2),
        gradientColors: [Color(0xFF7B1FA2), Color(0xFF4A148C)],
      ),
      _MoodOption(
        key: 'bored',
        label: 'Bored',
        icon: Icons.sentiment_neutral_rounded,
        color: Color(0xFFBA68C8),
        gradientColors: [Color(0xFFBA68C8), Color(0xFF7B1FA2)],
      ),
      _MoodOption(
        key: 'nervous',
        label: 'Nervous',
        icon: Icons.warning_amber_rounded,
        color: Color(0xFFD81B60),
        gradientColors: [Color(0xFFF06292), Color(0xFF8E24AA)],
      ),
    ];
  }

  String _extractCallSign(String text) {
    var raw = text.trim();
    if (raw.isEmpty) return '';

    // Check if format is "Your <callsign> is <mood/anything>"
    final regex = RegExp(r'^Your\s+(.+?)\s+is\b.*$', caseSensitive: false);
    final match = regex.firstMatch(raw);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }

    // Check if format is "Your <callsign>"
    final prefixRegex = RegExp(r'^Your\s+(.+)$', caseSensitive: false);
    final prefixMatch = prefixRegex.firstMatch(raw);
    if (prefixMatch != null && prefixMatch.group(1) != null) {
      return prefixMatch.group(1)!.trim();
    }

    return raw;
  }

  void _onMoodTapped(_MoodOption option) {
    HapticFeedback.lightImpact();
    final cleanCallSign = _extractCallSign(_callSignController.text);
    if (cleanCallSign.isEmpty) {
      _callSignFocusNode.requestFocus();
      SnackbarHelper.showError(
        context,
        'Please enter your callsign first (e.g., daddy, wife)',
      );
      return;
    }

    setState(() {
      _selectedMoodKey = option.key;
    });

    final formattedText = 'Your $cleanCallSign is ${option.label.toLowerCase()}';
    _callSignController.value = TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }

  Future<void> _sendMood(
    MoodProvider provider,
    String mood,
    String rawText,
  ) async {
    if (!provider.canSend || provider.isSending) return;
    final trimmedCallSign = _extractCallSign(rawText);
    if (trimmedCallSign.isEmpty) {
      _callSignFocusNode.requestFocus();
      SnackbarHelper.showError(context, 'Please enter a callsign to send.');
      return;
    }
    final success = await provider.sendMood(mood: mood, callSign: trimmedCallSign);
    if (success) {
      _callSignController.clear();
      _callSignFocusNode.unfocus();
      setState(() {
        _selectedMoodKey = null;
      });
    }
  }

  Future<String?> _showCustomMoodDialog() async {
    final customController = TextEditingController();
    IconData selectedIcon = Icons.emoji_emotions_outlined;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF1C1427) : Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF758C).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_reaction_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Custom Mood',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : AppColors.deepCharcoal,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mood name input
                AppTextField(
                  labelText: 'Mood name *',
                  controller: customController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  hintText: 'e.g., Grateful, Nostalgic, Cozy...',
                  prefixIcon: Icons.edit_rounded,
                  borderRadius: BorderRadius.circular(14),
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                Text(
                  'Pick an icon',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? Colors.white70 : AppColors.deepCharcoal,
                  ),
                ),
                const SizedBox(height: 8),
                // Icon grid in fixed-height scroll container — styled same to Features & Tools
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: _iconChoices.map((choice) {
                            final isSelected = selectedIcon == choice.icon;
                            return GestureDetector(
                              onTap: () => setDialogState(() => selectedIcon = choice.icon),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: isSelected
                                      ? const LinearGradient(
                                          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  color: isSelected
                                      ? null
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.06)
                                          : AppColors.softRose.withValues(alpha: 0.08)),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.transparent
                                        : (isDark
                                            ? AppColors.softRose.withValues(alpha: 0.2)
                                            : AppColors.softRose.withValues(alpha: 0.25)),
                                    width: 1.2,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFFFF758C).withValues(alpha: 0.45),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Icon(
                                    choice.icon,
                                    size: 22,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.softRose,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Centered action buttons — Cancel & Save to Template
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFF758C), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFFFF758C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.bookmark_add_rounded, size: 16, color: Colors.white),
                          label: const Text(
                            'Save',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: () {
                            final label = customController.text.trim();
                            if (label.isEmpty) {
                              SnackbarHelper.showError(context, 'Please enter a mood name');
                              return;
                            }
                            final key = 'custom:$label';
                            Navigator.pop(ctx, key);
                            final newOption = _MoodOption(
                              key: key,
                              label: label,
                              icon: selectedIcon,
                              color: AppColors.softRose,
                              gradientColors: const [Color(0xFFFF758C), Color(0xFFA18CD1)],
                            );
                            setState(() {
                              _customMoods.removeWhere((o) => o.key == key);
                              _customMoods.add(newOption);
                              _moodLookup[key] = newOption;
                              _selectedMoodKey = key;
                            });
                            final cleanCallSign = _extractCallSign(_callSignController.text);
                            if (cleanCallSign.isNotEmpty) {
                              final formattedText = 'Your $cleanCallSign is ${label.toLowerCase()}';
                              _callSignController.value = TextEditingValue(
                                text: formattedText,
                                selection: TextSelection.collapsed(offset: formattedText.length),
                              );
                            }
                            _saveCustomMoods();
                            SnackbarHelper.showSuccess(
                              context,
                              'Mood "$label" saved to templates!',
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: const [],
        ),
      ),
    );
  }

  void _showDeleteCustomMoodDialog(_MoodOption option) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1C1427) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Delete Mood?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text('Remove "${option.label}" from your saved custom moods?'),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF758C), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFFFF758C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _customMoods.removeWhere((o) => o.key == option.key);
                        if (_selectedMoodKey == option.key) {
                          _selectedMoodKey = null;
                        }
                      });
                      _saveCustomMoods();
                      SnackbarHelper.showSuccess(context, 'Removed "${option.label}"');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRefresh(MoodProvider provider) async {
    if (provider.isRefreshing) return;
    await provider.refreshNow();
  }

  Future<void> _showEditMoodDialog(
    MoodProvider provider,
    MoodMessageModel mood,
  ) async {
    final moodId = mood.id;
    if (moodId == null) return;

    String callSign = mood.callSign;
    String selectedMood = mood.mood;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: isDark ? const Color(0xFF1C1427) : Colors.white,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Edit Mood',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : AppColors.deepCharcoal,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      initialValue: callSign,
                      onChanged: (value) {
                        callSign = value;
                      },
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Callsign',
                        hintText: 'e.g., wife',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    Text(
                      'Select Mood',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? Colors.white70 : AppColors.deepCharcoal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._moodOptions.map((option) {
                          final selected = selectedMood == option.key;
                          return _MoodButton(
                            option: option,
                            enabled: true,
                            isSelected: selected,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setDialogState(() {
                                selectedMood = option.key;
                              });
                            },
                          );
                        }),
                        ..._customMoods.map((option) {
                          final selected = selectedMood == option.key;
                          return _MoodButton(
                            option: option,
                            enabled: true,
                            isSelected: selected,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setDialogState(() {
                                selectedMood = option.key;
                              });
                            },
                          );
                        }),
                        // + Custom Button inside Edit Dialog
                        InkWell(
                          onTap: () async {
                            final newKey = await _showCustomMoodDialog();
                            if (newKey != null) {
                              setDialogState(() {
                                selectedMood = newKey;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : AppColors.softRose.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.softRose.withValues(alpha: 0.2)
                                    : AppColors.softRose.withValues(alpha: 0.25),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.add_reaction_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '+ Custom',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: isDark ? Colors.white : AppColors.deepCharcoal,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFFF758C), width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Color(0xFFFF758C), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(dialogContext, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: const [],
            );
          },
        );
      },
    );

    if (shouldSave != true) return;

    callSign = callSign.trim();

    if (callSign.isEmpty) {
      if (!mounted) return;
      SnackbarHelper.showError(context, 'Callsign cannot be empty.');
      return;
    }

    final success = await provider.updateMoodMessage(
      moodMessageId: moodId,
      mood: selectedMood,
      callSign: callSign,
    );

    if (!mounted) return;
    if (success) {
      SnackbarHelper.showSuccess(context, 'Mood updated');
    } else {
      SnackbarHelper.showError(context, 'Failed to update mood');
    }
  }

  @override
  Widget build(BuildContext context) {
    final moodProvider = context.watch<MoodProvider>();
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final user = userProvider.user;
    final couple = coupleProvider.couple;
    final partner = coupleProvider.partner;
    final moods = moodProvider.moods;

    final errorMessage = moodProvider.error;
    if (errorMessage != null && errorMessage != _lastError) {
      _lastError = errorMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        SnackbarHelper.showError(context, errorMessage);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? '${_selectedMoodIds.length} Selected' : 'Mood Board',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.softRose, AppColors.lavender],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: _toggleSelectionMode,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
              ),
        actions: _isSelectionMode
            ? [
                IconButton(
                  tooltip: 'Select All',
                  icon: const Icon(Icons.select_all_rounded, color: Colors.white),
                  onPressed: () => _selectAll(moods),
                ),
                IconButton(
                  tooltip: 'Delete Selected',
                  icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
                  onPressed: _selectedMoodIds.isNotEmpty
                      ? () => _confirmBulkDelete(moodProvider)
                      : null,
                ),
              ]
            : [
                if (moods.isNotEmpty)
                  IconButton(
                    tooltip: 'Select & Delete',
                    icon: const Icon(Icons.checklist_rounded, color: Colors.white),
                    onPressed: _toggleSelectionMode,
                  ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: moodProvider.isRefreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh, color: Colors.white),
                  onPressed: moodProvider.isRefreshing
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          _handleRefresh(moodProvider);
                        },
                ),
              ],
        elevation: 0,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: user == null || couple == null
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
                                        moodProvider: moodProvider,
                                        userId: user.id,
                                        userPhotoUrl: user.photoUrl,
                                        partnerPhotoUrl: partner?.photoUrl,
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

    if (_isComposerHidden) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _isComposerHidden = false);
        },
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Send a mood',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 20,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ],
          ),
        ),
      );
    }

    final composerBody = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const SizedBox(width: 32),
            Expanded(
              child: Text(
                'Send a mood',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              tooltip: 'Hide',
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                _callSignFocusNode.unfocus();
                FocusScope.of(context).unfocus();
                setState(() => _isComposerHidden = true);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        SizedBox(height: verticalSpacing),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _callSignController,
          builder: (context, value, _) {
            final callSign = value.text.trim();
            final hasCallSign = callSign.isNotEmpty;
            final isFocused = _callSignFocusNode.hasFocus;

            return Column(
              children: [
                AppTextField(
                  controller: _callSignController,
                  focusNode: _callSignFocusNode,
                  enabled: canSend,
                  textInputAction: TextInputAction.send,
                  onFieldSubmitted: (text) {
                    final trimmed = text.trim();
                    if (trimmed.isNotEmpty) {
                      final moodToSend = _selectedMoodKey ?? _moodOptions.first.key;
                      _sendMood(provider, moodToSend, trimmed);
                    }
                  },
                  hintText: 'Callsign (e.g., wife)',
                  prefixIcon: Icons.favorite_rounded,
                  borderRadius: BorderRadius.circular(16),
                  isDark: isDark,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasCallSign || isFocused || isKeyboardOpen)
                        IconButton(
                          tooltip: 'Cancel / Dismiss',
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          onPressed: () {
                            _callSignController.clear();
                            _callSignFocusNode.unfocus();
                            FocusScope.of(context).unfocus();
                          },
                        ),
                      if (hasCallSign)
                        IconButton(
                          tooltip: 'Send Mood',
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          onPressed: () {
                            final moodToSend = _selectedMoodKey ?? _moodOptions.first.key;
                            _sendMood(provider, moodToSend, callSign);
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Wrap(
                  spacing: AppDimensions.spacingSm,
                  runSpacing: AppDimensions.spacingSm,
                  alignment: WrapAlignment.center,
                  children: [
                    // Predefined Moods
                    ..._moodOptions.map((option) {
                      final isSelected = _selectedMoodKey == option.key;
                      return _MoodButton(
                        option: option,
                        enabled: canSend && hasCallSign,
                        isSelected: isSelected,
                        onTap: () => _onMoodTapped(option),
                      );
                    }),
                    // Custom Saved Moods
                    ..._customMoods.map((option) {
                      final isSelected = _selectedMoodKey == option.key;
                      return _MoodButton(
                        option: option,
                        enabled: canSend && hasCallSign,
                        isSelected: isSelected,
                        onTap: () => _onMoodTapped(option),
                        onLongPress: () => _showDeleteCustomMoodDialog(option),
                      );
                    }),
                    // + Custom mood button (always enabled to add new moods)
                    InkWell(
                      onTap: () => _showCustomMoodDialog(),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : AppColors.softRose.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? AppColors.softRose.withValues(alpha: 0.2)
                                : AppColors.softRose.withValues(alpha: 0.25),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add_reaction_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '+ Custom',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
    required MoodProvider moodProvider,
    required String? userId,
    required String? userPhotoUrl,
    required String? partnerPhotoUrl,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMine = mood.senderId == userId;
    final moodId = mood.id;
    final isSelectedInBulk = moodId != null && _selectedMoodIds.contains(moodId);
    final hasSeen =
        moodId != null && isMine && moodProvider.isSeenByPartner(moodId);
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

    // Support custom moods: key format is 'custom:<label>'
    final isCustomMood = mood.mood.startsWith('custom:');
    final customLabel = isCustomMood ? mood.mood.replaceFirst('custom:', '') : null;
    final option = _moodLookup[mood.mood];
    final icon = option?.icon ?? Icons.star_rounded;
    final moodLabel = customLabel ?? option?.label ?? mood.mood;
    final callSign = mood.callSign.trim();
    final moodText = callSign.isEmpty
        ? moodLabel
        : 'Your $callSign is ${moodLabel.toLowerCase()}';
    final List<Color> gradientColors;
    if (option != null) {
      gradientColors = option.gradientColors;
    } else {
      gradientColors = const [Color(0xFFFF758C), Color(0xFFA18CD1)];
    }

    final bubbleColor = isDark
        ? (isMine
            ? AppColors.lavender.withValues(alpha: 0.25)
            : AppColors.softRose.withValues(alpha: 0.25))
        : (isMine ? AppColors.lavenderLight : AppColors.softRoseLight);
    final bubbleTextColor =
        isDark ? AppColors.darkText : AppColors.deepCharcoal;
    final metaColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    final seenTextStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w600,
        );

    return GestureDetector(
      onTap: _isSelectionMode && moodId != null
          ? () => _toggleMoodSelection(moodId)
          : null,
      onLongPress: () {
        if (moodId == null) return;
        HapticFeedback.mediumImpact();
        setState(() {
          _isSelectionMode = true;
          _selectedMoodIds.add(moodId);
        });
      },
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_isSelectionMode && moodId != null) ...[
                GestureDetector(
                  onTap: () => _toggleMoodSelection(moodId),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8, bottom: 6),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isSelectedInBulk
                          ? const LinearGradient(
                              colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelectedInBulk
                          ? null
                          : (isDark ? Colors.white12 : Colors.grey.shade200),
                      border: Border.all(
                        color: isSelectedInBulk
                            ? Colors.transparent
                            : (isDark ? Colors.white38 : Colors.grey.shade400),
                        width: 1.5,
                      ),
                    ),
                    child: isSelectedInBulk
                        ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                        : null,
                  ),
                ),
              ],
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
                        border: isSelectedInBulk
                            ? Border.all(
                                color: const Color(0xFFFF758C),
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: gradientColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: gradientColors.first.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Icon(icon, size: 15, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              moodText,
                              style:
                                  Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: bubbleTextColor,
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          mood.formattedDateTime,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: metaColor,
                              ),
                        ),
                        if (isMine && mood.id != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: moodProvider.isSending
                                ? null
                                : () => _showEditMoodDialog(
                                      moodProvider,
                                      mood,
                                    ),
                            child: Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color: metaColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: moodProvider.isSending
                                ? null
                                : () => _confirmDeleteSingleMood(
                                      moodProvider,
                                      mood.id!,
                                    ),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: 15,
                              color: AppColors.error.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                        if (hasSeen) ...[
                          const SizedBox(width: 6),
                          Text('Seen', style: seenTextStyle),
                        ],
                      ],
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
            'Link with your love to share moods',
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
      color: accentColor.withValues(alpha: 0.15),
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
  final List<Color> gradientColors;

  const _MoodOption({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    this.gradientColors = const [Color(0xFFFF758C), Color(0xFFA18CD1)],
  });
}

class _IconChoice {
  final IconData icon;
  final String label;
  const _IconChoice(this.icon, this.label);
}

class _MoodButton extends StatelessWidget {
  const _MoodButton({
    required this.option,
    required this.enabled,
    required this.onTap,
    this.isSelected = false,
    this.onLongPress,
  });

  final _MoodOption option;
  final bool enabled;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = option.gradientColors;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? (isDark
                  ? const Color(0xFFFF758C).withValues(alpha: 0.22)
                  : const Color(0xFFFF758C).withValues(alpha: 0.12))
              : enabled
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : AppColors.softRose.withValues(alpha: 0.06))
                  : (isDark ? Colors.grey.shade900 : Colors.grey.shade200),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF758C)
                : enabled
                    ? (isDark
                        ? AppColors.softRose.withValues(alpha: 0.2)
                        : AppColors.softRose.withValues(alpha: 0.25))
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                option.icon,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              option.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? (isDark ? Colors.white : AppColors.deepCharcoal)
                        : enabled
                            ? (isDark ? AppColors.darkText : AppColors.deepCharcoal)
                            : (isDark ? Colors.grey.shade600 : Colors.grey),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
