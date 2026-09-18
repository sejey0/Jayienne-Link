import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/mood_letters_provider.dart';
import '../../../providers/user_provider.dart';

class ComposeLetterSheet extends StatefulWidget {
  const ComposeLetterSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ComposeLetterSheet(),
    );
  }

  @override
  State<ComposeLetterSheet> createState() => _ComposeLetterSheetState();
}

class _ComposeLetterSheetState extends State<ComposeLetterSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _customCategoryController = TextEditingController();

  final List<String> _moodOptions = [
    "Open when you're sad",
    "Open when you miss me",
    "Open when you need a smile",
    "Open when you're stressed",
    "Open when you can't sleep",
    "Open when we had an argument",
    "Custom...",
  ];

  late String _selectedMood;
  bool _isCustomCategory = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedMood = _moodOptions.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (!_formKey.currentState!.validate()) return;

    final coupleProvider = context.read<CoupleProvider>();
    final userProvider = context.read<UserProvider>();
    final lettersProvider = context.read<MoodLettersProvider>();

    final coupleId = userProvider.coupleId ?? coupleProvider.couple?.id;
    final currentUserId = userProvider.user?.id.isNotEmpty == true
        ? userProvider.user!.id
        : (userProvider.user?.uid ?? '');

    final partner = coupleProvider.partner;
    String? partnerId = partner?.id.isNotEmpty == true ? partner!.id : partner?.uid;
    if ((partnerId == null || partnerId.isEmpty) && coupleProvider.couple != null) {
      final ids = coupleProvider.couple!.partnerIds;
      if (ids.isNotEmpty) {
        partnerId = ids.firstWhere((id) => id != currentUserId, orElse: () => '');
      }
    }

    if (coupleId == null || partnerId == null || partnerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active partner linked. Link your partner first.'),
          backgroundColor: Color(0xFFFF5252),
        ),
      );
      return;
    }

    final category = _isCustomCategory
        ? _customCategoryController.text.trim()
        : _selectedMood;

    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    final targetReceiverId = lettersProvider.effectivePartnerId ?? partnerId;

    final success = await lettersProvider.sendLetter(
      coupleId: coupleId,
      receiverId: targetReceiverId,
      category: category,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your Mood Letter has been sealed and sent'),
            backgroundColor: Color(0xFF27AE60),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lettersProvider.error ?? 'Failed to send letter. Please retry.'),
            backgroundColor: const Color(0xFFFF5252),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1427) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF758C).withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sheet Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.create_rounded,
                      color: Color(0xFFFF758C),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Write a Mood Letter',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.deepCharcoal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category Selector
              DropdownButtonFormField<String>(
                value: _selectedMood,
                decoration: InputDecoration(
                  labelText: 'Select Mood / Open When...',
                  prefixIcon: const Icon(Icons.label_outline_rounded, color: Color(0xFFFF758C)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFFF758C), width: 1.8),
                  ),
                ),
                dropdownColor: isDark ? const Color(0xFF1F2B47) : Colors.white,
                items: _moodOptions.map((mood) {
                  return DropdownMenuItem(
                    value: mood,
                    child: Text(mood, style: const TextStyle(fontSize: 13.5)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedMood = val;
                      _isCustomCategory = val == 'Custom...';
                    });
                  }
                },
              ),

              if (_isCustomCategory) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customCategoryController,
                  validator: (val) {
                    if (_isCustomCategory && (val == null || val.trim().isEmpty)) {
                      return 'Please enter a custom category';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Custom Category (e.g. Open when you feel lonely)',
                    prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFFFF758C)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFFF758C), width: 1.8),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Title Field
              TextFormField(
                controller: _titleController,
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a title' : null,
                decoration: InputDecoration(
                  labelText: 'Letter Title',
                  prefixIcon: const Icon(Icons.title_rounded, color: Color(0xFFFF758C)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFFF758C), width: 1.8),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Content Area
              Expanded(
                child: TextFormField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please write your message' : null,
                  decoration: InputDecoration(
                    labelText: 'Write your thoughts...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFFF758C), width: 1.8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5252), Color(0xFFD81B60)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
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
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        label: Text(
                          _isSubmitting ? 'Sending...' : 'Seal & Send',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isSubmitting ? null : _handleSend,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
