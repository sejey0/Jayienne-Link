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
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lettersProvider = context.watch<MoodLettersProvider>();

    if (lettersProvider.isLoading && lettersProvider.receivedLetters.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF758C)),
      );
    }

    // Only include categories that actually have received letters
    final categoriesWithLetters = lettersProvider.receivedLetters
        .map((l) => l.category.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();

    final availableCategories = ['All', ...categoriesWithLetters];

    // Ensure current selected category is still valid
    final currentSelectedCategory = lettersProvider.selectedCategory;
    final activeCategory = (currentSelectedCategory != 'All' &&
            !categoriesWithLetters.contains(currentSelectedCategory))
        ? 'All'
        : currentSelectedCategory;

    final filteredLetters = activeCategory == 'All'
        ? lettersProvider.receivedLetters
        : lettersProvider.receivedLetters
            .where((l) => l.category.trim() == activeCategory)
            .toList();

    return Column(
      children: [
        // Category Filter Chips
        if (categoriesWithLetters.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: availableCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, index) {
                final category = availableCategories[index];
                final isSelected = activeCategory == category;
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    lettersProvider.selectCategory(category);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
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
                              ? Colors.white.withValues(alpha: 0.07)
                              : Colors.white),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.grey.shade300),
                        width: 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : AppColors.deepCharcoal),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ] else
          const SizedBox(height: 8),

        // Letters List
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFFFF758C),
            onRefresh: () async {
              await lettersProvider.refreshReceivedLetters();
            },
            child: filteredLetters.isEmpty
                ? _buildEmptyState(context, isDark, lettersProvider)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: filteredLetters.length,
                    itemBuilder: (ctx, index) {
                      final letter = filteredLetters[index];
                      return _buildReceivedLetterCard(letter, isDark);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  /// Empty state when no received letters exist
  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    MoodLettersProvider lettersProvider,
  ) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.16),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mail_outline_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Your letterbox is waiting',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Letters written by your partner will be sealed here for you to open when the mood strikes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
                if (lettersProvider.sentLetters.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F2B47) : const Color(0xFFFFF0F3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.outbox_rounded, size: 16, color: Color(0xFFFF758C)),
                        const SizedBox(width: 8),
                        Text(
                          'You have ${lettersProvider.sentLetters.length} letter${lettersProvider.sentLetters.length == 1 ? '' : 's'} in the Sent tab',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFFD81B60),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Modern romantic received letter card
  Widget _buildReceivedLetterCard(MoodLetterModel letter, bool isDark) {
    final isSealed = !letter.isRead;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? (isSealed ? const Color(0xFF221A30) : const Color(0xFF1B1527))
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSealed
              ? const Color(0xFFFF758C).withValues(alpha: 0.5)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFFF758C).withValues(alpha: 0.18)),
          width: isSealed ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSealed
                ? const Color(0xFFFF758C).withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: isSealed ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            HapticFeedback.lightImpact();
            await LetterDetailModal.show(context, letter);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Sealed Envelope Badge vs Read Badge
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: isSealed
                        ? const LinearGradient(
                            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSealed
                        ? null
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : const Color(0xFFF6F3F9)),
                    shape: BoxShape.circle,
                    boxShadow: isSealed
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFF758C).withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    isSealed ? Icons.mark_email_unread_rounded : Icons.drafts_rounded,
                    color: isSealed
                        ? Colors.white
                        : (isDark ? const Color(0xFFA18CD1) : Colors.grey.shade600),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),

                // Letter Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mood Category + Date Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF758C).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.favorite_rounded,
                                    size: 10, color: Color(0xFFFF758C)),
                                const SizedBox(width: 4),
                                Text(
                                  letter.category,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF758C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            letter.formattedCreatedAt,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white38 : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Title
                      Text(
                        letter.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.deepCharcoal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // Status & Action Indicator Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isSealed
                                  ? const Color(0xFFFF5252).withValues(alpha: 0.12)
                                  : const Color(0xFF27AE60).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSealed
                                      ? Icons.lock_outline_rounded
                                      : Icons.check_circle_outline_rounded,
                                  size: 11,
                                  color: isSealed
                                      ? const Color(0xFFFF5252)
                                      : const Color(0xFF27AE60),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isSealed
                                      ? 'Sealed'
                                      : (letter.readCount <= 1
                                          ? 'Opened'
                                          : 'Opened ${letter.readCount}x'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSealed
                                        ? const Color(0xFFFF5252)
                                        : const Color(0xFF27AE60),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Open Affordance
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isSealed ? 'Tap to open' : 'Read again',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isSealed
                                      ? const Color(0xFFFF758C)
                                      : (isDark ? Colors.white38 : Colors.grey.shade500),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10,
                                color: isSealed
                                    ? const Color(0xFFFF758C)
                                    : (isDark ? Colors.white38 : Colors.grey.shade400),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
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
