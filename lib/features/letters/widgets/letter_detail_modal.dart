import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/mood_letter_model.dart';
import '../../../providers/mood_letters_provider.dart';

class LetterDetailModal extends StatefulWidget {
  final MoodLetterModel letter;
  final bool isSenderView;

  const LetterDetailModal({
    super.key,
    required this.letter,
    this.isSenderView = false,
  });

  static Future<void> show(
    BuildContext context,
    MoodLetterModel letter, {
    bool isSenderView = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LetterDetailModal(
        letter: letter,
        isSenderView: isSenderView,
      ),
    );
  }

  @override
  State<LetterDetailModal> createState() => _LetterDetailModalState();
}

class _LetterDetailModalState extends State<LetterDetailModal> {
  bool _isProcessing = false;
  late bool _isUnsealed;

  @override
  void initState() {
    super.initState();
    // Sender immediately sees what they wrote with the full letter design
    _isUnsealed = widget.isSenderView;
  }

  Future<void> _handleReadAction() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isProcessing = true;
      _isUnsealed = true;
    });

    final provider = context.read<MoodLettersProvider>();
    await provider.openLetter(widget.letter.id);

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.84,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF191424) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF758C).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Category & Date Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF758C).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite_rounded, size: 13, color: Color(0xFFFF758C)),
                      const SizedBox(width: 5),
                      Text(
                        widget.letter.category,
                        style: const TextStyle(
                          color: Color(0xFFFF758C),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  widget.letter.formattedCreatedAt,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Letter Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Text(
              widget.letter.title,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                height: 1.25,
                color: isDark ? Colors.white : AppColors.deepCharcoal,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          // Body Content: Simple Sealed First Page vs Full Stationery Letter Design
          Expanded(
            child: _isProcessing
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF758C),
                    ),
                  )
                : (_isUnsealed
                    ? _buildUnsealedLetterContent(isDark)
                    : _buildSealedFirstPage(isDark)),
          ),

          // Bottom Action Bar: [Cancel] + [Read] if sealed, or [Close Letter] if unsealed
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: _isUnsealed
                ? _buildCloseButton()
                : _buildCancelAndReadButtons(),
          ),
        ],
      ),
    );
  }

  /// Simple first page when clicking a sealed letter (clean & straightforward)
  Widget _buildSealedFirstPage(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFF758C).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mail_outline_rounded,
                size: 40,
                color: Color(0xFFFF758C),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Letter is sealed',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.deepCharcoal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap Read to open and count this letter',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The Full Romantic Stationery Letter Design
  Widget _buildUnsealedLetterContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      physics: const BouncingScrollPhysics(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E182A) : const Color(0xFFFFFDFC),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? const Color(0xFFA18CD1).withValues(alpha: 0.25)
                : const Color(0xFFFF758C).withValues(alpha: 0.25),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top decorative quotation icon
            Icon(
              Icons.format_quote_rounded,
              size: 28,
              color: const Color(0xFFFF758C).withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),

            // Letter Content Text
            SelectableText(
              widget.letter.content,
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w400,
                color: isDark ? const Color(0xFFF3F0F7) : AppColors.deepCharcoal,
              ),
            ),
            const SizedBox(height: 24),

            // Romantic Bottom Stamp
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.favorite_rounded,
                  size: 13,
                  color: const Color(0xFFFF758C).withValues(alpha: 0.6),
                ),
                const SizedBox(width: 5),
                Text(
                  widget.isSenderView
                      ? 'Sealed with love'
                      : 'Written for your heart',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFFFF8FA3).withValues(alpha: 0.8)
                        : const Color(0xFFD81B60).withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Two-Button Row: [Cancel] + [Read]
  Widget _buildCancelAndReadButtons() {
    return Row(
      children: [
        // Cancel Button
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF5252), Color(0xFFD81B60)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
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
                size: 18,
                color: Colors.white,
              ),
              label: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Read Button
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 19),
              label: const Text(
                'Read',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _handleReadAction,
            ),
          ),
        ),
      ],
    );
  }

  /// Single Full-Width Button: [Close Letter]
  Widget _buildCloseButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF758C).withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.check_rounded, color: Colors.white, size: 19),
        label: const Text(
          'Close Letter',
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
