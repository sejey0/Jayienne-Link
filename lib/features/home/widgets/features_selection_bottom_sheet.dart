import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_names.dart';
import '../../../providers/secret_media_provider.dart';
import '../../movies/screens/movie_tracker_screen.dart';
import '../../secret_media/screens/hidden_vault_screen.dart';
import '../screens/decision_spinner_screen.dart';
import '../screens/love_nudge_screen.dart';

enum _ActionType {
  route,
  customScreen,
  loveNudgeScreen,
  decisionSpinnerScreen,
  movieDiaryScreen,
}

/// Senior Feature Selection Modal Bottom Sheet with Single Instance Back-Stack Persistence & Haptic Feedback
class FeaturesSelectionBottomSheet extends StatelessWidget {
  const FeaturesSelectionBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FeaturesSelectionBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secretMediaProvider = context.watch<SecretMediaProvider>();
    final isVaultHidden = secretMediaProvider.isVaultHiddenFromFeatures;

    // Strict Pink & Purple Palette Tile Items (Hidden Vault is ALWAYS dynamically placed at the very end)
    const baseFeatures = [
      _FeatureModalItem(
        title: 'Live Location',
        subtitle: 'Map & distance',
        icon: Icons.location_on_rounded,
        gradientColors: [Color(0xFFFF4081), Color(0xFFAB47BC)],
        route: RouteNames.location,
      ),
      _FeatureModalItem(
        title: 'Touch Canvas',
        subtitle: 'Heartbeat touches',
        icon: Icons.favorite_rounded,
        gradientColors: [Color(0xFFFF5252), Color(0xFFD81B60)],
        route: RouteNames.heartbeat,
      ),
      _FeatureModalItem(
        title: 'Relationship Timeline',
        subtitle: 'Memory timeline',
        icon: Icons.auto_stories_rounded,
        gradientColors: [Color(0xFFEC407A), Color(0xFF8E24AA)],
        route: RouteNames.relationshipTimeline,
      ),
      _FeatureModalItem(
        title: 'Mood Board',
        subtitle: 'Partner check-in',
        icon: Icons.mood_rounded,
        gradientColors: [Color(0xFFE91E63), Color(0xFF7B1FA2)],
        route: RouteNames.mood,
      ),
      _FeatureModalItem(
        title: 'Shared Photo Feed',
        subtitle: 'Shared memories',
        icon: Icons.photo_library_rounded,
        gradientColors: [Color(0xFFF06292), Color(0xFF9C27B0)],
        route: RouteNames.photos,
      ),
      _FeatureModalItem(
        title: 'Love Nudge',
        subtitle: 'Send virtual kiss & hug',
        icon: Icons.volunteer_activism_rounded,
        gradientColors: [Color(0xFFFF4081), Color(0xFFD81B60)],
        actionType: _ActionType.loveNudgeScreen,
      ),
      _FeatureModalItem(
        title: 'Decision Spinner',
        subtitle: 'Date & food picker',
        icon: Icons.casino_rounded,
        gradientColors: [Color(0xFFBA68C8), Color(0xFF7B1FA2)],
        actionType: _ActionType.decisionSpinnerScreen,
      ),
      _FeatureModalItem(
        title: 'Movie Diary',
        subtitle: 'Watchlist & reviews',
        icon: Icons.local_movies_rounded,
        gradientColors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
        actionType: _ActionType.movieDiaryScreen,
      ),
      _FeatureModalItem(
        title: 'Couple Links',
        subtitle: 'Socials & websites',
        icon: Icons.link_rounded,
        gradientColors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
        route: RouteNames.coupleLinks,
      ),
    ];

    final featureItems = [
      ...baseFeatures,
      if (!isVaultHidden)
        const _FeatureModalItem(
          title: 'Hidden Vault',
          subtitle: 'Private photos & video',
          icon: Icons.lock_rounded,
          gradientColors: [Color(0xFFC2185B), Color(0xFF512DA8)],
          route: RouteNames.secretMediaHiddenVault,
          actionType: _ActionType.customScreen,
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1427) : const Color(0xFFFFF7F9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: AppColors.softRose.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pink & Purple Drag Handle Indicator
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
              const SizedBox(height: 16),

              // Modal Header Row with Close Button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.softRose.withValues(alpha: 0.2),
                          AppColors.lavender.withValues(alpha: 0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.widgets_rounded,
                      color: AppColors.softRose,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Features & Tools',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: isDark
                                    ? Colors.white
                                    : AppColors.softRose,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select a tool to connect with your love',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: isDark ? Colors.white70 : Colors.grey.shade600,
                                fontSize: 12,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.softRose.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.softRose,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Selection Grid Tiles (Single-instance back-stack return)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: featureItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.15,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final item = featureItems[index];
                  return _FeatureModalTile(
                    item: item,
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      if (item.actionType == _ActionType.customScreen) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HiddenVaultScreen(),
                          ),
                        );
                      } else if (item.actionType == _ActionType.loveNudgeScreen) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoveNudgeScreen(),
                          ),
                        );
                      } else if (item.actionType == _ActionType.decisionSpinnerScreen) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DecisionSpinnerScreen(),
                          ),
                        );
                      } else if (item.actionType == _ActionType.movieDiaryScreen) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MovieTrackerScreen(),
                          ),
                        );
                      } else {
                        await context.push(item.route);
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureModalItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final String route;
  final _ActionType actionType;

  const _FeatureModalItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    this.route = '',
    this.actionType = _ActionType.route,
  });
}

class _FeatureModalTile extends StatefulWidget {
  final _FeatureModalItem item;
  final VoidCallback onTap;

  const _FeatureModalTile({
    required this.item,
    required this.onTap,
  });

  @override
  State<_FeatureModalTile> createState() => _FeatureModalTileState();
}

class _FeatureModalTileState extends State<_FeatureModalTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.softRose.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? AppColors.softRose.withValues(alpha: 0.2)
                  : AppColors.softRose.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.item.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: widget.item.gradientColors.first
                          .withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  widget.item.icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white70
                            : Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
