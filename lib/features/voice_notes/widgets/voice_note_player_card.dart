import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/voice_note_model.dart';
import '../../../providers/voice_notes_provider.dart';
import '../../../widgets/common/timed_confirm_dialog.dart';

class VoiceNotePlayerCard extends StatelessWidget {
  final VoiceNoteModel note;
  final bool isMine;
  final String partnerName;
  final String? partnerPhotoUrl;

  const VoiceNotePlayerCard({
    super.key,
    required this.note,
    required this.isMine,
    required this.partnerName,
    this.partnerPhotoUrl,
  });

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final noteDate = DateTime(dt.year, dt.month, dt.day);

    final timeStr = DateFormat('h:mm a').format(dt);
    if (noteDate == today) {
      return 'Today at $timeStr';
    } else if (noteDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday at $timeStr';
    }
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  void _confirmDelete(BuildContext context, VoiceNotesProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1427) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4D6D).withValues(alpha: 0.20),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF4D6D), Color(0xFFD90429)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4D6D).withValues(alpha: 0.40),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Delete Voice Message?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Are you sure you want to delete this 10-second voice note? This cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(modalContext).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : AppColors.deepCharcoal,
                          side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TimedDestructiveButton(
                        label: 'Delete',
                        icon: Icons.delete_rounded,
                        countdownSeconds: 5,
                        height: 48,
                        borderRadius: 16,
                        fontSize: 14,
                        onPressed: () {
                          Navigator.of(modalContext).pop();
                          provider.deleteVoiceNote(note.id, audioUrl: note.audioUrl);
                        },
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<VoiceNotesProvider>();

    final isThisPlaying = provider.currentlyPlayingId == note.id && provider.isPlaying;
    final isThisActive = provider.currentlyPlayingId == note.id;

    final currentSeconds = isThisActive
        ? provider.currentPosition.inSeconds
        : 0;
    final totalSeconds = note.durationSeconds > 0 ? note.durationSeconds : 10;

    final progress = isThisActive && provider.totalDuration.inMilliseconds > 0
        ? (provider.currentPosition.inMilliseconds / provider.totalDuration.inMilliseconds)
            .clamp(0.0, 1.0)
        : (isThisPlaying ? (currentSeconds / totalSeconds).clamp(0.0, 1.0) : 0.0);

    final senderDisplayName = isMine ? 'You' : note.displaySenderName;
    final photoUrl = isMine ? note.senderPhotoUrl : (note.senderPhotoUrl ?? partnerPhotoUrl);

    final cardAccent = isMine ? AppColors.softRose : AppColors.lavender;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E172A) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (!note.isListened && !isMine)
              ? AppColors.softRose.withValues(alpha: 0.6)
              : cardAccent.withValues(alpha: isDark ? 0.22 : 0.15),
          width: (!note.isListened && !isMine) ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: (!note.isListened && !isMine)
                ? AppColors.softRose.withValues(alpha: 0.18)
                : cardAccent.withValues(alpha: isDark ? 0.08 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header: Avatar + Sender + Tag + Timestamp + Delete ──
            Row(
              children: [
                // Avatar
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isMine
                          ? [AppColors.softRose, AppColors.lavender]
                          : [AppColors.lavender, const Color(0xFF7E57C2)],
                    ),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: ClipOval(
                    child: (photoUrl != null && photoUrl.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Center(
                              child: Text(
                                senderDisplayName.isNotEmpty ? senderDisplayName[0].toUpperCase() : 'P',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              senderDisplayName.isNotEmpty ? senderDisplayName[0].toUpperCase() : 'P',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),

                // Name & Time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              senderDisplayName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.deepCharcoal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: cardAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isMine ? 'You' : 'Partner',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: cardAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTimestamp(note.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Unlistened "New" badge or Delete button
                if (!note.isListened && !isMine) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.softRose, Color(0xFFFF4D6D)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_new_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 2),
                        Text(
                          'New',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (isMine)
                  IconButton(
                    onPressed: () => _confirmDelete(context, provider),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Delete voice note',
                  ),
              ],
            ),

            if (note.title != null && note.title!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                note.title!,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.9)
                      : AppColors.deepCharcoal,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ── Audio Player Strip ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : cardAccent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cardAccent.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  // Play / Pause Circle
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      provider.playAudio(note.id, note.audioUrl);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isThisPlaying
                              ? [const Color(0xFFFF4D6D), const Color(0xFFD90429)]
                              : [cardAccent, AppColors.lavender],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: cardAccent.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        isThisPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Progress Bar & Duration
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                            activeTrackColor: cardAccent,
                            inactiveTrackColor: isDark ? Colors.white12 : Colors.grey.shade300,
                            thumbColor: cardAccent,
                            overlayColor: cardAccent.withValues(alpha: 0.2),
                          ),
                          child: Slider(
                            value: progress,
                            onChanged: (val) {
                              if (isThisActive && provider.totalDuration.inMilliseconds > 0) {
                                final seekPos = Duration(
                                  milliseconds: (val * provider.totalDuration.inMilliseconds).toInt(),
                                );
                                provider.seekAudio(seekPos);
                              }
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '0:${currentSeconds.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                '0:${totalSeconds.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: cardAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
