import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/url_launcher_helper.dart';
import '../../../models/social_link_model.dart';
import '../../../providers/couple_links_provider.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/smart_profile_image.dart';
import '../widgets/add_edit_link_sheet.dart';
import '../widgets/platform_brand_icon.dart';

enum _LinkFilterTab { all, mine, partner }

class CoupleLinksScreen extends StatefulWidget {
  const CoupleLinksScreen({super.key});

  @override
  State<CoupleLinksScreen> createState() => _CoupleLinksScreenState();
}

class _CoupleLinksScreenState extends State<CoupleLinksScreen> {
  _LinkFilterTab _selectedTab = _LinkFilterTab.all;
  SocialPlatform? _selectedPlatformFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final linksProv = context.read<CoupleLinksProvider>();
      final userProv = context.read<UserProvider>();
      final coupleId = userProv.user?.coupleId;
      final userId = userProv.user?.id;
      if (coupleId != null && userId != null) {
        linksProv.initialize(coupleId: coupleId, userId: userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final linksProvider = context.watch<CoupleLinksProvider>();
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();

    final currentUser = userProvider.user;
    final partner = coupleProvider.partner;
    final partnerName = partner?.displayName.isNotEmpty == true
        ? partner!.displayName
        : 'Partner';

    final allLinks = linksProvider.links;
    final myLinks = linksProvider.myLinks;
    final partnerLinks = linksProvider.partnerLinks;

    // Apply Tab Filter
    List<SocialLinkModel> tabFilteredLinks;
    switch (_selectedTab) {
      case _LinkFilterTab.all:
        tabFilteredLinks = allLinks;
        break;
      case _LinkFilterTab.mine:
        tabFilteredLinks = myLinks;
        break;
      case _LinkFilterTab.partner:
        tabFilteredLinks = partnerLinks;
        break;
    }

    // Apply Platform Filter
    final displayedLinks = _selectedPlatformFilter == null
        ? tabFilteredLinks
        : tabFilteredLinks
            .where((l) => l.socialPlatform == _selectedPlatformFilter)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Couple Links & Accounts',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
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
            tooltip: 'Refresh links',
            icon: linksProvider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: linksProvider.isLoading
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    linksProvider.refreshLinks();
                  },
          ),
        ],
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          AddEditLinkSheet.show(context);
        },
        backgroundColor: AppColors.softRose,
        icon: const Icon(Icons.add_link_rounded, color: Colors.white),
        label: const Text(
          'Add Link',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.softRose,
        onRefresh: () => linksProvider.refreshLinks(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Segmented Filter Tabs
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildSegmentedFilter(
                  allCount: allLinks.length,
                  myCount: myLinks.length,
                  partnerCount: partnerLinks.length,
                  partnerName: partnerName,
                  isDark: isDark,
                ),
              ),

              // 2. Horizontal Platform Chips Filter
              _buildPlatformFilterRow(isDark),

              const SizedBox(height: 8),

              // 3. Links List or Empty State
              if (linksProvider.isLoading && displayedLinks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(48.0),
                  child: Center(child: CircularProgressIndicator(color: AppColors.softRose)),
                )
              else if (displayedLinks.isEmpty)
                _buildEmptyState(context, isDark, partnerName)
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: displayedLinks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = displayedLinks[index];
                    final isMine = item.userId == currentUser?.id;

                    return _buildLinkCard(
                      context: context,
                      link: item,
                      isMine: isMine,
                      partnerName: partnerName,
                      isDark: isDark,
                      linksProvider: linksProvider,
                    );
                  },
                ),

              // Bottom safe padding for FAB and gesture navigation bar
              SizedBox(height: MediaQuery.of(context).padding.bottom + 84),
            ],
          ),
        ),
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF231A33) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          _buildFilterTabItem(
            label: 'All ($allCount)',
            tab: _LinkFilterTab.all,
            isSelected: _selectedTab == _LinkFilterTab.all,
            isDark: isDark,
          ),
          _buildFilterTabItem(
            label: 'Mine ($myCount)',
            tab: _LinkFilterTab.mine,
            isSelected: _selectedTab == _LinkFilterTab.mine,
            isDark: isDark,
          ),
          _buildFilterTabItem(
            label: '$partnerName ($partnerCount)',
            tab: _LinkFilterTab.partner,
            isSelected: _selectedTab == _LinkFilterTab.partner,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabItem({
    required String label,
    required _LinkFilterTab tab,
    required bool isSelected,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedTab = tab;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [AppColors.softRose, AppColors.lavender],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.softRose.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 12.5,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : AppColors.deepCharcoal),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformFilterRow(bool isDark) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _buildPlatformChip(
            label: 'All Platforms',
            icon: Icons.apps_rounded,
            isSelected: _selectedPlatformFilter == null,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedPlatformFilter = null);
            },
            isDark: isDark,
          ),
          ...SocialPlatform.values.map((platform) {
            final isSelected = _selectedPlatformFilter == platform;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildPlatformChip(
                label: platform.displayName,
                icon: platform.icon,
                isSelected: isSelected,
                color: platform.primaryColor,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedPlatformFilter = isSelected ? null : platform;
                  });
                },
                isDark: isDark,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPlatformChip({
    required String label,
    required dynamic icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    Color? color,
  }) {
    final activeColor = color ?? AppColors.softRose;
    Widget iconWidget;
    if (icon is FaIconData) {
      iconWidget = FaIcon(
        icon,
        size: 13,
        color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.grey.shade700),
      );
    } else if (icon is IconData) {
      iconWidget = Icon(
        icon,
        size: 14,
        color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.grey.shade700),
      );
    } else {
      iconWidget = const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkCard({
    required BuildContext context,
    required SocialLinkModel link,
    required bool isMine,
    required String partnerName,
    required bool isDark,
    required CoupleLinksProvider linksProvider,
  }) {
    final userProvider = context.read<UserProvider>();
    final coupleProvider = context.read<CoupleProvider>();
    final currentUser = userProvider.user;
    final partner = coupleProvider.partner;

    final creatorPhotoUrl = isMine ? currentUser?.photoUrl : (link.userPhotoUrl ?? partner?.photoUrl);
    final creatorName = isMine ? 'You' : (link.userDisplayName ?? (partnerName.isNotEmpty ? partnerName : 'Partner'));
    final platform = link.socialPlatform;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E162A) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isMine
              ? AppColors.softRose.withValues(alpha: 0.25)
              : AppColors.lavender.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isMine ? AppColors.softRose : AppColors.lavender).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => UrlLauncherHelper.launchLink(context, link.url),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Platform Icon + Title/Handle + Actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Glowing Branded Platform Emblem
                    PlatformBrandIcon(
                      platform: platform,
                      size: 48,
                      borderRadius: 16,
                    ),

                    const SizedBox(width: 14),

                    // Title & Handle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            link.displayTitle,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          // Username / Handle Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              link.displayHandle,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : AppColors.deepCharcoal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3-Dots Menu (for Owner)
                    if (isMine)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 20,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                        onSelected: (action) {
                          if (action == 'edit') {
                            AddEditLinkSheet.show(context, initialLink: link);
                          } else if (action == 'delete') {
                            _confirmDelete(context, link, linksProvider);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 18, color: AppColors.softRose),
                                SizedBox(width: 10),
                                Text('Edit Link'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                SizedBox(width: 10),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // Bottom Action & Attribution Row
                Row(
                  children: [
                    // Shared By Owner Profile with Avatar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isMine
                            ? AppColors.softRose.withValues(alpha: 0.12)
                            : AppColors.lavender.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (isMine ? AppColors.softRose : AppColors.lavender).withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isMine ? AppColors.softRose : AppColors.lavender,
                                width: 1.5,
                              ),
                            ),
                            child: ClipOval(
                              child: SmartProfileImage(
                                imageUrl: creatorPhotoUrl,
                                width: 20,
                                height: 20,
                                placeholder: Container(
                                  color: (isMine ? AppColors.softRose : AppColors.lavender).withValues(alpha: 0.2),
                                  child: Icon(
                                    Icons.person,
                                    color: isMine ? AppColors.softRose : AppColors.lavender,
                                    size: 11,
                                  ),
                                ),
                                errorWidget: Container(
                                  color: (isMine ? AppColors.softRose : AppColors.lavender).withValues(alpha: 0.2),
                                  child: Icon(
                                    Icons.person,
                                    color: isMine ? AppColors.softRose : AppColors.lavender,
                                    size: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            creatorName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isMine ? AppColors.softRose : AppColors.lavender,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Copy Link Button
                    IconButton(
                      tooltip: 'Copy link',
                      icon: Icon(
                        Icons.copy_rounded,
                        size: 18,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => UrlLauncherHelper.copyToClipboard(
                        context,
                        link.url,
                        label: link.displayTitle,
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Tap to Open Profile Button
                    ElevatedButton.icon(
                      onPressed: () => UrlLauncherHelper.launchLink(context, link.url),
                      icon: const Icon(Icons.open_in_new_rounded, size: 14, color: Colors.white),
                      label: Text(
                        platform == SocialPlatform.website ? 'Visit Site' : 'Open Profile',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: platform.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
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

  void _confirmDelete(
    BuildContext context,
    SocialLinkModel link,
    CoupleLinksProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Link?'),
        content: Text('Are you sure you want to remove "${link.displayTitle}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final deleted = await provider.deleteLink(link.id);
              if (context.mounted) {
                if (deleted) {
                  SnackbarHelper.showSuccess(context, 'Link removed.');
                } else {
                  SnackbarHelper.showError(context, provider.error ?? 'Failed to delete link.');
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, String partnerName) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.softRose, AppColors.lavender],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.softRose.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.link_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No links added yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share your Instagram, TikTok, Spotify, or favorite websites with $partnerName so you can open each other\'s profiles anytime!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => AddEditLinkSheet.show(context),
            icon: const Icon(Icons.add_link_rounded, color: Colors.white),
            label: const Text(
              'Add Your First Link',
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
