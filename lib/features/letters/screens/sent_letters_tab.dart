import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/mood_letter_model.dart';
import '../../../providers/mood_letters_provider.dart';
import '../widgets/letter_detail_modal.dart';

class SentLettersTab extends StatelessWidget {
  const SentLettersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lettersProvider = context.watch<MoodLettersProvider>();

    if (lettersProvider.isLoading && lettersProvider.sentLetters.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF758C)),
      );
    }

    final sentLetters = lettersProvider.sentLetters;
    final readCountTotal = sentLetters.where((l) => l.isRead).length;

    return RefreshIndicator(
      color: const Color(0xFFFF758C),
      onRefresh: () async {
        await lettersProvider.refreshSentLetters();
      },
      child: sentLetters.isEmpty
          ? _buildEmptyState(context, isDark)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                // Top Summary Header Pill
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : const Color(0xFFF3EDF7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.outbox_rounded,
                                size: 13, color: Color(0xFFA18CD1)),
                            const SizedBox(width: 5),
                            Text(
                              '${sentLetters.length} letter${sentLetters.length == 1 ? '' : 's'} sent',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? const Color(0xFFC5B3F0)
                                    : const Color(0xFF7B1FA2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF758C).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite_rounded,
                                size: 12, color: Color(0xFFFF758C)),
                            const SizedBox(width: 5),
                            Text(
                              '$readCountTotal read by partner',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF758C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // List of Sent Cards
                ...sentLetters.map((letter) => _buildSentLetterTile(context, letter, isDark)),
              ],
            ),
    );
  }

  /// Empty state when no sent letters exist
  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
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
                      colors: [Color(0xFFA18CD1), Color(0xFF8E24AA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFA18CD1).withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.outbox_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'No letters sent yet',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Surprise your partner with an "Open When..." mood letter. Tap the button below to write one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Modern sent letter card with live partner read analytics and message snippet
  Widget _buildSentLetterTile(BuildContext context, MoodLetterModel letter, bool isDark) {
    final isReadByPartner = letter.isRead;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1729) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isReadByPartner
              ? const Color(0xFFA18CD1).withValues(alpha: 0.35)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.shade200),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isReadByPartner
                ? const Color(0xFFA18CD1).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            LetterDetailModal.show(
              context,
              letter,
              isSenderView: true,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row: Category Badge + Partner Read Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Mood Category Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA18CD1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.label_outline_rounded,
                              size: 11, color: Color(0xFFA18CD1)),
                          const SizedBox(width: 4),
                          Text(
                            letter.category,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFA18CD1),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Partner Read Status Pill
                    _buildPartnerStatusBadge(letter, isDark),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  letter.title,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                  ),
                ),
                const SizedBox(height: 5),

                // Content Snippet (Preview)
                Text(
                  letter.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Footer Row: Timestamps & View Affordance
                Row(
                  children: [
                    // Timestamp details
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            isReadByPartner
                                ? Icons.done_all_rounded
                                : Icons.schedule_rounded,
                            size: 13,
                            color: isReadByPartner
                                ? const Color(0xFFFF758C)
                                : (isDark ? Colors.white38 : Colors.grey.shade500),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              isReadByPartner
                                  ? (letter.formattedFirstReadAt != null
                                      ? 'Read: ${letter.formattedFirstReadAt}'
                                      : 'Read by partner')
                                  : 'Sent ${letter.formattedCreatedAt}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white54 : Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tap affordance pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA18CD1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFA18CD1),
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 12,
                            color: Color(0xFFA18CD1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Modern partner read badge with romantic gradient or clean waiting badge
  Widget _buildPartnerStatusBadge(MoodLetterModel letter, bool isDark) {
    if (letter.readCount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF758C).withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.favorite_rounded,
              size: 11,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              'Partner opened ${letter.readCount}x',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_clock_rounded,
            size: 12,
            color: isDark ? Colors.white60 : Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            'Unopened',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
