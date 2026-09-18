import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/mood_letter_model.dart';
import '../../../providers/mood_letters_provider.dart';
import '../../../widgets/common/timed_confirm_dialog.dart';

class LetterDetailModal extends StatefulWidget {
  final MoodLetterModel letter;

  const LetterDetailModal({super.key, required this.letter});

  static Future<void> show(BuildContext context, MoodLetterModel letter) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LetterDetailModal(letter: letter),
    );
  }

  @override
  State<LetterDetailModal> createState() => _LetterDetailModalState();
}

class _LetterDetailModalState extends State<LetterDetailModal> {
  bool _isProcessing = true;
  late int _readCount;

  @override
  void initState() {
    super.initState();
    _readCount = widget.letter.readCount;
    _triggerOpenAction();
  }

  Future<void> _triggerOpenAction() async {
    HapticFeedback.mediumImpact();
    final provider = context.read<MoodLettersProvider>();
    final result = await provider.openLetter(widget.letter.id);

    if (mounted) {
      setState(() {
        _isProcessing = false;
        if (result['read_count'] is int) {
          _readCount = result['read_count'] as int;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.84,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1427) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF758C).withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Mood Category Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF758C).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite_rounded, size: 14, color: Color(0xFFFF758C)),
                const SizedBox(width: 6),
                Text(
                  widget.letter.category,
                  style: const TextStyle(
                    color: Color(0xFFFF758C),
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.letter.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.deepCharcoal,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Timestamp & Open Counter Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 13,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                widget.letter.formattedCreatedAt,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
              if (_readCount > 0) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA18CD1).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.visibility_outlined,
                        size: 12,
                        color: Color(0xFFA18CD1),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Read $_readCount ${_readCount == 1 ? 'time' : 'times'}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFA18CD1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),

          // Content Box
          Expanded(
            child: _isProcessing
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF758C),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF151928) : const Color(0xFFFDF8F5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFF758C).withValues(alpha: 0.22),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.letter.content,
                        style: TextStyle(
                          fontSize: 15.5,
                          height: 1.65,
                          letterSpacing: 0.25,
                          color: isDark ? const Color(0xFFF5F5F5) : AppColors.deepCharcoal,
                        ),
                      ),
                    ),
                  ),
          ),

          // Close Button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: SizedBox(
              width: double.infinity,
              child: SecondaryCancelButton(
                label: 'Close Letter',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
