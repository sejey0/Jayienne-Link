import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/mood_letter_model.dart';
import '../../../providers/mood_letters_provider.dart';

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

    return RefreshIndicator(
      color: const Color(0xFFFF758C),
      onRefresh: () async {
        await lettersProvider.refreshSentLetters();
      },
      child: sentLetters.isEmpty
          ? ListView(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.22),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA18CD1).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.outbox_rounded,
                          size: 48,
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No letters sent yet',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : AppColors.deepCharcoal,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap the button below to write your first Mood Letter.',
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
              itemCount: sentLetters.length,
              itemBuilder: (ctx, index) {
                final letter = sentLetters[index];
                return _buildSentLetterTile(letter, isDark);
              },
            ),
    );
  }

  Widget _buildSentLetterTile(MoodLetterModel letter, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2B47) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Category and Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFA18CD1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  letter.category,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFA18CD1),
                  ),
                ),
              ),
              _buildStatusBadge(letter.isRead),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            letter.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.deepCharcoal,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Analytics Row: Read Count and Timestamps
          Row(
            children: [
              // Read Counter Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: letter.readCount > 0
                      ? const LinearGradient(
                          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: letter.readCount == 0
                      ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200)
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: letter.readCount > 0
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF758C).withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 13,
                      color: letter.readCount > 0 ? Colors.white : Colors.grey,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      letter.readCount == 0 ? 'Unopened' : 'Opened ${letter.readCount}x',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: letter.readCount > 0 ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Timestamp details
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (letter.firstReadAt != null)
                    Text(
                      'First read: ${letter.formattedFirstReadAt}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                  if (letter.lastReadAt != null && letter.readCount > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Last read: ${letter.formattedLastReadAt}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  if (letter.firstReadAt == null)
                    Text(
                      'Sent ${letter.formattedCreatedAt}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isRead) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isRead
            ? const Color(0xFF27AE60).withValues(alpha: 0.12)
            : const Color(0xFFFF9AA2).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRead ? Icons.mark_email_read_rounded : Icons.lock_outline_rounded,
            size: 13,
            color: isRead ? const Color(0xFF27AE60) : const Color(0xFFFF758C),
          ),
          const SizedBox(width: 4),
          Text(
            isRead ? 'Read' : 'Unread',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isRead ? const Color(0xFF27AE60) : const Color(0xFFFF758C),
            ),
          ),
        ],
      ),
    );
  }
}
