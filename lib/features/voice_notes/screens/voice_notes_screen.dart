import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/voice_note_model.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/voice_notes_provider.dart';
import '../widgets/voice_note_player_card.dart';
import '../widgets/voice_record_sheet.dart';

class VoiceNotesScreen extends StatefulWidget {
  const VoiceNotesScreen({super.key});

  @override
  State<VoiceNotesScreen> createState() => _VoiceNotesScreenState();
}

class _VoiceNotesScreenState extends State<VoiceNotesScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: Sent by Me, 2: From Partner

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final voiceProv = context.watch<VoiceNotesProvider>();
    final userProv = context.watch<UserProvider>();
    final coupleProv = context.watch<CoupleProvider>();

    final user = userProv.user;
    final currentUserId = user?.id.isNotEmpty == true ? user!.id : (user?.uid ?? '');
    final partner = coupleProv.partner;
    final partnerName = (partner?.displayName != null && partner!.displayName.isNotEmpty)
        ? partner.displayName
        : 'Partner';

    final allNotes = voiceProv.voiceNotes;
    final myNotes = allNotes.where((n) => n.senderId == currentUserId).toList();
    final partnerNotes = allNotes.where((n) => n.senderId != currentUserId).toList();

    List<VoiceNoteModel> displayedNotes;
    switch (_selectedFilterIndex) {
      case 1:
        displayedNotes = myNotes;
        break;
      case 2:
        displayedNotes = partnerNotes;
        break;
      default:
        displayedNotes = allNotes;
        break;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF130E1C) : const Color(0xFFFBF8FC),
      appBar: AppBar(
        title: const Text(
          'Voice Messages',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh voice messages',
            icon: voiceProv.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: voiceProv.isLoading
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    voiceProv.fetchVoiceNotes();
                  },
          ),
        ],
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          VoiceRecordSheet.show(context);
        },
        backgroundColor: AppColors.softRose,
        icon: const Icon(Icons.mic_rounded, color: Colors.white),
        label: const Text(
          'Record Voice Note',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.softRose,
        onRefresh: () => voiceProv.fetchVoiceNotes(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Top Banner ──
              _buildTopBanner(isDark, partnerName),

              const SizedBox(height: 14),

              // ── 2. Segmented Filter Tabs ──
              _buildSegmentedFilter(
                allCount: allNotes.length,
                myCount: myNotes.length,
                partnerCount: partnerNotes.length,
                partnerName: partnerName,
                isDark: isDark,
              ),

              const SizedBox(height: 14),

              // ── 3. Voice Notes List or Empty State ──
              if (voiceProv.isLoading && displayedNotes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(48.0),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.softRose),
                  ),
                )
              else if (displayedNotes.isEmpty)
                _buildEmptyState(context, isDark, partnerName)
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayedNotes.length,
                  itemBuilder: (context, index) {
                    final note = displayedNotes[index];
                    final isMine = note.senderId == currentUserId;
                    return VoiceNotePlayerCard(
                      note: note,
                      isMine: isMine,
                      partnerName: partnerName,
                      partnerPhotoUrl: partner?.photoUrl,
                    );
                  },
                ),

              const SizedBox(height: 80), // Fab padding
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBanner(bool isDark, String partnerName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2B1D3D), const Color(0xFF1E172A)]
              : [
                  AppColors.softRose.withValues(alpha: 0.12),
                  AppColors.lavender.withValues(alpha: 0.12),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.softRose.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.softRose, AppColors.lavender],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.softRose.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.mic_external_on_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '10-Second Voice Notes',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Send quick, authentic audio moments to $partnerName. Real-time sync across both phones.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedFilter({
    required int allCount,
    required int myCount,
    required int partnerCount,
    required String partnerName,
    required bool isDark,
  }) {
    final tabs = [
      'All ($allCount)',
      'Mine ($myCount)',
      '$partnerName ($partnerCount)',
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E172A) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedFilterIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFilterIndex = index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF2C223D) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    tabs[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? AppColors.softRose
                          : (isDark ? Colors.white60 : Colors.grey.shade600),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, String partnerName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.softRose, AppColors.lavender],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.softRose.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.mic_none_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No Voice Messages Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.deepCharcoal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap below to record a sweet 10-second voice note for $partnerName.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              VoiceRecordSheet.show(context);
            },
            icon: const Icon(Icons.mic_rounded, color: Colors.white, size: 16),
            label: const Text(
              'Record First Note',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.softRose,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
