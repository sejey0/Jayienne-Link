import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/daily_sync_service.dart';

/// Senior Daily Love Quote & Sweet Note Glassmorphism Card Widget with Online Real-time Couple Sync
class DailyQuoteCard extends StatefulWidget {
  const DailyQuoteCard({super.key});

  @override
  State<DailyQuoteCard> createState() => _DailyQuoteCardState();
}

class _DailyQuoteCardState extends State<DailyQuoteCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _spinController;
  bool _isRerolling = false;

  AnimationController get _effectiveSpinController {
    return _spinController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _spinController?.dispose();
    super.dispose();
  }

  Future<void> _rerollQuote(
    BuildContext context, {
    required String? coupleId,
    required String? userId,
    required String? userName,
  }) async {
    if (_isRerolling) return;
    _isRerolling = true;
    HapticFeedback.lightImpact();
    _effectiveSpinController.forward(from: 0.0);

    try {
      await DailySyncService.instance.rerollSweetQuote(
        coupleId: coupleId,
        userId: userId,
        userName: userName,
      );
    } catch (e) {
      debugPrint('⚠️ Reroll quote error: $e');
    } finally {
      if (mounted) {
        setState(() => _isRerolling = false);
      }
    }
  }

  void _copyQuote(DailyQuoteItem item) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(
      text: '"${item.text}"',
    ));
    SnackbarHelper.showSuccess(context, 'Love note copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coupleProvider = context.watch<CoupleProvider>();
    final userProvider = context.watch<UserProvider>();

    final coupleId = coupleProvider.couple?.id;
    final userId = userProvider.user?.uid;
    final userName = userProvider.user?.displayName ?? 'You';
    final partner = coupleProvider.partner;
    final partnerName = (partner?.displayName.isNotEmpty == true)
        ? partner!.displayName
        : 'your love';

    return StreamBuilder<DailyQuoteItem>(
      stream: DailySyncService.instance.streamSweetQuote(coupleId),
      builder: (context, snapshot) {
        final item = snapshot.data;
        if (item == null) {
          return const SizedBox.shrink();
        }

        final isUpdatedByPartner = item.updatedBy != null &&
            item.updatedBy != userId &&
            item.updatedBy!.isNotEmpty;

        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingSm,
          ),
          child: Container(
            padding: const EdgeInsets.all(18.0),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1E2C).withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.95),
              gradient: LinearGradient(
                colors: [
                  AppColors.softRose.withValues(alpha: isDark ? 0.16 : 0.10),
                  AppColors.lavender.withValues(alpha: isDark ? 0.26 : 0.16),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.softRose.withValues(alpha: 0.28),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.softRose.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header: Icon + Title + Sync indicator & Reroll Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF758C)
                                    .withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.format_quote_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sweet Daily Note',
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.softRose,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Heartfelt Love & Affirmation',
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Actions: Reroll Button
                    IconButton(
                          onPressed: () => _rerollQuote(
                            context,
                            coupleId: coupleId,
                            userId: userId,
                            userName: userName,
                          ),
                          icon: RotationTransition(
                            turns: _effectiveSpinController,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF758C)
                                        .withValues(alpha: 0.25),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.refresh_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'New quote (Syncs with partner)',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                // 2. Animated Quote Body Text
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.1),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Padding(
                    key: ValueKey<String>(item.text),
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: Text(
                      '"${item.text}"',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 14.5,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white.withValues(alpha: 0.95) : Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Footer: Subtitle / Synced With & Copy Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Romantic Signature Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.softRose.withValues(alpha: isDark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.softRose.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite_rounded,
                            size: 11,
                            color: AppColors.softRose,
                          ),
                          const SizedBox(width: 4.5),
                          Text(
                            isUpdatedByPartner
                                ? 'From ${item.updatedByName ?? partnerName}'
                                : 'For Us',
                            style: const TextStyle(
                              color: AppColors.softRose,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Copy & Info Row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isUpdatedByPartner)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              'Rerolled by ${item.updatedByName ?? partnerName}',
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black45,
                                fontSize: 10.5,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        IconButton(
                          onPressed: () => _copyQuote(item),
                          icon: Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: isDark ? Colors.white60 : Colors.black45,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Copy love note',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
