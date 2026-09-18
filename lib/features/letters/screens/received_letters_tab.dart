import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/mood_letter_model.dart';
import '../../../providers/mood_letters_provider.dart';
import '../widgets/letter_detail_modal.dart';

class ReceivedLettersTab extends StatefulWidget {
  const ReceivedLettersTab({super.key});

  @override
  State<ReceivedLettersTab> createState() => _ReceivedLettersTabState();
}

class _ReceivedLettersTabState extends State<ReceivedLettersTab> {
  final List<String> _categories = [
    'All',
    "Open when you're sad",
    "Open when you miss me",
    "Open when you need a smile",
    "Open when you're stressed",
    "Open when you can't sleep",
    "Open when we had an argument",
    "Open on our anniversary",
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lettersProvider = context.watch<MoodLettersProvider>();

    if (lettersProvider.isLoading && lettersProvider.receivedLetters.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF758C)),
      );
    }

    final filteredLetters = lettersProvider.filteredReceivedLetters;

    return Column(
      children: [
        const SizedBox(height: 12),
        // Filter Chips Horizontal Scroll
        SizedBox(
          height: 42,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, index) {
              final category = _categories[index];
              final isSelected = lettersProvider.selectedCategory == category;
              return ChoiceChip(
                label: Text(
                  category,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : AppColors.deepCharcoal),
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFFFF758C),
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade200,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                showCheckmark: false,
                onSelected: (val) {
                  if (val) {
                    HapticFeedback.selectionClick();
                    lettersProvider.selectCategory(category);
                  }
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Letters List
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFFFF758C),
            onRefresh: () async {
              await lettersProvider.refreshReceivedLetters();
            },
            child: filteredLetters.isEmpty
                ? ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF758C).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.mail_outline_rounded,
                                size: 48,
                                color: isDark ? Colors.white38 : Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No letters in this mood yet',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : AppColors.deepCharcoal,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Letters written by your partner will appear here.',
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.grey.shade500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                    itemCount: filteredLetters.length,
                    itemBuilder: (ctx, index) {
                      final letter = filteredLetters[index];
                      return _buildLetterCard(letter, isDark);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildLetterCard(MoodLetterModel letter, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2B47) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: letter.isRead
                ? Colors.black.withValues(alpha: 0.03)
                : const Color(0xFFFF758C).withValues(alpha: 0.16),
            blurRadius: letter.isRead ? 6 : 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: letter.isRead
              ? Colors.transparent
              : const Color(0xFFFF758C).withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await LetterDetailModal.show(context, letter);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Envelope Icon Badge
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: letter.isRead
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: letter.isRead
                        ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200)
                        : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    letter.isRead ? Icons.drafts_outlined : Icons.mark_email_unread_rounded,
                    color: letter.isRead ? Colors.grey : Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF758C).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          letter.category,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF758C),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        letter.title,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.deepCharcoal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        letter.formattedCreatedAt,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Action Indicator
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.white30 : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
