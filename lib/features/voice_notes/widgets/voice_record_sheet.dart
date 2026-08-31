import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/voice_notes_provider.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../links/widgets/add_edit_link_sheet.dart';

class VoiceRecordSheet extends StatefulWidget {
  const VoiceRecordSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const VoiceRecordSheet(),
    );
  }

  @override
  State<VoiceRecordSheet> createState() => _VoiceRecordSheetState();
}

class _VoiceRecordSheetState extends State<VoiceRecordSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final AudioPlayer _previewPlayer = AudioPlayer();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isRecorded = false;
  String? _localAudioPath;
  int _recordedDuration = 0;
  bool _isPreviewPlaying = false;
  Duration _previewPosition = Duration.zero;
  Duration _previewTotalDuration = const Duration(seconds: 10);
  StreamSubscription? _previewPosSub;
  StreamSubscription? _previewStateSub;
  StreamSubscription? _previewCompSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _previewPosSub = _previewPlayer.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() => _previewPosition = pos);
      }
    });

    _previewStateSub = _previewPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPreviewPlaying = state == PlayerState.playing);
      }
    });

    _previewCompSub = _previewPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPreviewPlaying = false;
          _previewPosition = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _previewPosSub?.cancel();
    _previewStateSub?.cancel();
    _previewCompSub?.cancel();
    _previewPlayer.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _handleRecordToggle(VoiceNotesProvider provider) async {
    HapticFeedback.mediumImpact();

    if (provider.isRecording) {
      final path = await provider.stopRecording();
      if (path != null) {
        setState(() {
          _isRecorded = true;
          _localAudioPath = path;
          _recordedDuration = provider.recordDurationSeconds > 0
              ? provider.recordDurationSeconds
              : 10;
          _previewTotalDuration = Duration(seconds: _recordedDuration);
        });
      }
    } else {
      final success = await provider.startRecording();
      if (!success && mounted && provider.error != null) {
        SnackbarHelper.showError(context, provider.error!);
      }
    }
  }

  Future<void> _handleDiscard(VoiceNotesProvider provider) async {
    HapticFeedback.lightImpact();
    await _previewPlayer.stop();
    await provider.cancelRecording();
    setState(() {
      _isRecorded = false;
      _localAudioPath = null;
      _recordedDuration = 0;
      _isPreviewPlaying = false;
      _previewPosition = Duration.zero;
    });
  }

  Future<void> _handleTogglePreview() async {
    if (_localAudioPath == null) return;
    HapticFeedback.lightImpact();

    if (_isPreviewPlaying) {
      await _previewPlayer.pause();
    } else {
      await _previewPlayer.play(DeviceFileSource(_localAudioPath!));
    }
  }

  Future<void> _handleSend(
    BuildContext context,
    VoiceNotesProvider voiceProv,
    UserProvider userProv,
    CoupleProvider coupleProv,
  ) async {
    final user = userProv.user;
    final coupleId = user?.coupleId;

    final nav = Navigator.of(context);
    final scaffoldContext = context;

    if (user == null || coupleId == null) {
      SnackbarHelper.showError(context, 'You must be linked in a couple to send voice notes.');
      return;
    }

    HapticFeedback.mediumImpact();
    await _previewPlayer.stop();

    final success = await voiceProv.sendRecordedVoiceNote(
      coupleId: coupleId,
      senderId: user.id.isNotEmpty ? user.id : user.uid,
      senderName: user.displayName.isNotEmpty ? user.displayName : 'Partner',
      senderPhotoUrl: user.photoUrl,
      title: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : null,
    );

    if (mounted) {
      if (success) {
        nav.pop();
        if (scaffoldContext.mounted) {
          SnackbarHelper.showSuccess(scaffoldContext, 'Voice message sent to partner!');
        }
      } else {
        if (scaffoldContext.mounted) {
          SnackbarHelper.showError(
            scaffoldContext,
            voiceProv.error ?? 'Failed to send voice note. Please try again.',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final voiceProv = context.watch<VoiceNotesProvider>();
    final userProv = context.watch<UserProvider>();
    final coupleProv = context.watch<CoupleProvider>();

    // If recording auto-stopped at 10s and not yet marked as recorded
    if (!voiceProv.isRecording &&
        voiceProv.recordedFilePath != null &&
        !_isRecorded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isRecorded = true;
            _localAudioPath = voiceProv.recordedFilePath;
            _recordedDuration = voiceProv.recordDurationSeconds > 0
                ? voiceProv.recordDurationSeconds
                : 10;
            _previewTotalDuration = Duration(seconds: _recordedDuration);
          });
        }
      });
    }

    final progress = voiceProv.isRecording
        ? (voiceProv.recordDurationSeconds / voiceProv.maxDurationSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1427) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: AppColors.softRose.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.softRose.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.softRose, AppColors.lavender],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.softRose.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.mic_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isRecorded
                                ? 'Preview Voice Note'
                                : voiceProv.isRecording
                                    ? 'Recording Audio Note...'
                                    : 'Record 10s Voice Note',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.deepCharcoal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isRecorded
                                ? 'Listen or send to your partner'
                                : 'Maximum 10 seconds voice message',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        voiceProv.cancelRecording();
                        Navigator.of(context).pop();
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Optional Title Input
                AppTextField(
                  controller: _titleController,
                  labelText: 'Title or Note (Optional)',
                  hintText: 'e.g. Good morning love, Missing you...',
                  prefixIcon: Icons.edit_note_rounded,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [CapitalizeWordsInputFormatter()],
                ),
                const SizedBox(height: 24),

                // Main Interactive Center: Record / Preview
                if (!_isRecorded) ...[
                  // Live Timer & Waveform
                  Text(
                    '0:${voiceProv.recordDurationSeconds.toString().padLeft(2, '0')} / 0:10',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: voiceProv.isRecording
                          ? const Color(0xFFFF4D6D)
                          : isDark
                              ? Colors.white
                              : AppColors.deepCharcoal,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Animated Circular Record Button with Progress Ring
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Progress Ring
                      SizedBox(
                        width: 108,
                        height: 108,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 4.5,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.softRose),
                        ),
                      ),

                      // Pulsing Glow when recording
                      if (voiceProv.isRecording)
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFF4D6D).withValues(alpha: 0.25),
                            ),
                          ),
                        ),

                      // Center Action Button
                      GestureDetector(
                        onTap: () => _handleRecordToggle(voiceProv),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: voiceProv.isRecording
                                  ? [const Color(0xFFFF4D6D), const Color(0xFFD90429)]
                                  : [AppColors.softRose, AppColors.lavender],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (voiceProv.isRecording
                                        ? const Color(0xFFFF4D6D)
                                        : AppColors.softRose)
                                    .withValues(alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            voiceProv.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                            size: 38,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(
                    voiceProv.isRecording
                        ? 'Tap red button to finish recording'
                        : 'Tap microphone to start 10s voice recording',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ] else ...[
                  // ── Preview Player Card ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF281E38)
                          : AppColors.softRose.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.softRose.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Play / Pause Button
                        GestureDetector(
                          onTap: _handleTogglePreview,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [AppColors.softRose, AppColors.lavender],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.softRose.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isPreviewPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Progress bar & Time
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LinearProgressIndicator(
                                value: _previewTotalDuration.inMilliseconds > 0
                                    ? (_previewPosition.inMilliseconds /
                                            _previewTotalDuration.inMilliseconds)
                                        .clamp(0.0, 1.0)
                                    : 0.0,
                                backgroundColor: isDark
                                    ? Colors.white12
                                    : Colors.grey.shade300,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.softRose,
                                ),
                                minHeight: 4,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '0:${_previewPosition.inSeconds.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                                    ),
                                  ),
                                  const Text(
                                    '0:10',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.softRose,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions: Discard & Send
                  Row(
                    children: [
                      // Discard Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _handleDiscard(voiceProv),
                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                          label: const Text(
                            'Discard',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
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
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Send Voice Note Button
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.softRose, AppColors.lavender],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.softRose.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: voiceProv.isUploading
                                ? null
                                : () => _handleSend(context, voiceProv, userProv, coupleProv),
                            icon: voiceProv.isUploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                            label: Text(
                              voiceProv.isUploading ? 'Sending...' : 'Send Voice Note',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
