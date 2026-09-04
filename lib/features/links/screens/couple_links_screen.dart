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
import '../../../widgets/common/romantic_loading_indicator.dart';
import '../../../widgets/common/timed_confirm_dialog.dart';

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

              // 2. Horizontal Platform Chips Filter (only platforms with content)
              _buildPlatformFilterRow(isDark, tabFilteredLinks),

              const SizedBox(height: 8),

              // 3. Links List or Empty State
              if (linksProvider.isLoading && displayedLinks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(48.0),
                  child: Center(
                    child: RomanticLoadingIndicator(
                      size: 56,
                      message: 'Loading links...',
                    ),
                  ),
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

  Widget _buildPlatformFilterRow(bool isDark, List<SocialLinkModel> currentLinks) {
    final availablePlatforms = <SocialPlatform>{};
    for (final link in currentLinks) {
      availablePlatforms.add(link.socialPlatform);
    }

    if (availablePlatforms.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_selectedPlatformFilter != null && !availablePlatforms.contains(_selectedPlatformFilter)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedPlatformFilter != null && !availablePlatforms.contains(_selectedPlatformFilter)) {
          setState(() => _selectedPlatformFilter = null);
        }
      });
    }

    final sortedPlatforms = SocialPlatform.values.where((p) => availablePlatforms.contains(p)).toList();

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _buildPlatformChip(
            label: 'All (${currentLinks.length})',
            icon: Icons.apps_rounded,
            isSelected: _selectedPlatformFilter == null,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedPlatformFilter = null);
            },
            isDark: isDark,
          ),
          ...sortedPlatforms.map((platform) {
            final count = currentLinks.where((l) => l.socialPlatform == platform).length;
            final isSelected = _selectedPlatformFilter == platform;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildPlatformChip(
                label: '${platform.displayName} ($count)',
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
    final accentColor = isMine ? AppColors.softRose : AppColors.lavender;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E162A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showLinkDetails(
            context: context,
            link: link,
            isMine: isMine,
            creatorName: creatorName,
            creatorPhotoUrl: creatorPhotoUrl,
            isDark: isDark,
            linksProvider: linksProvider,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Row: Platform Icon + Title/Handle + 3-Dots ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PlatformBrandIcon(
                      platform: platform,
                      customUrl: link.url,
                      size: 42,
                      borderRadius: 12,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            link.displayTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                              color: isDark ? Colors.white : AppColors.deepCharcoal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              // Platform Name Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: platform.primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: platform.primaryColor.withValues(alpha: 0.35),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  platform.displayName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: platform.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  link.displayHandle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Bottom Row: Creator Badge + Action Buttons ───────
                Row(
                  children: [
                    // Creator Mini Badge
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: accentColor, width: 1.2),
                      ),
                      child: ClipOval(
                        child: SmartProfileImage(
                          imageUrl: creatorPhotoUrl,
                          width: 18,
                          height: 18,
                          placeholder: Container(
                            color: accentColor.withValues(alpha: 0.2),
                            child: Icon(Icons.person, color: accentColor, size: 10),
                          ),
                          errorWidget: Container(
                            color: accentColor.withValues(alpha: 0.2),
                            child: Icon(Icons.person, color: accentColor, size: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      creatorName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),

                    const Spacer(),

                    // Details Button
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showLinkDetails(
                        context: context,
                        link: link,
                        isMine: isMine,
                        creatorName: creatorName,
                        creatorPhotoUrl: creatorPhotoUrl,
                        isDark: isDark,
                        linksProvider: linksProvider,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : accentColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 13,
                              color: accentColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Details',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Open Site Button
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: platform.gradientColors.length >= 2
                              ? platform.gradientColors
                              : [accentColor, AppColors.lavender],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: platform.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _confirmOpenSite(
                            context,
                            url: link.url,
                            title: link.displayTitle,
                            platform: platform,
                          );
                        },
                        icon: const Icon(
                          Icons.open_in_new_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Open Site',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 11.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: Size.zero,
                        ),
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

  void _showLinkDetails({
    required BuildContext context,
    required SocialLinkModel link,
    required bool isMine,
    required String creatorName,
    required String? creatorPhotoUrl,
    required bool isDark,
    required CoupleLinksProvider linksProvider,
  }) {
    final platform = link.socialPlatform;
    final accentColor = isMine ? AppColors.softRose : AppColors.lavender;
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: sheetDark ? const Color(0xFF1A1225) : AppColors.warmWhite,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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

                  // Platform header
                  Row(
                    children: [
                      PlatformBrandIcon(
                        platform: platform,
                        customUrl: link.url,
                        size: 54,
                        borderRadius: 16,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              link.displayTitle,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: sheetDark ? Colors.white : AppColors.deepCharcoal,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: platform.primaryColor.withValues(alpha: sheetDark ? 0.2 : 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: platform.primaryColor.withValues(alpha: 0.35),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    platform.displayName,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: platform.primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    link.displayHandle,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: platform.primaryColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: sheetDark ? Colors.white54 : Colors.grey.shade600,
                          size: 22,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Full URL row with Copy Button
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    decoration: BoxDecoration(
                      color: sheetDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : accentColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link_rounded, size: 18, color: accentColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SelectableText(
                            link.url,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: sheetDark ? Colors.white70 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Copy Link',
                          icon: Icon(
                            Icons.copy_rounded,
                            size: 17,
                            color: accentColor,
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            UrlLauncherHelper.copyToClipboard(
                              context,
                              link.url,
                              label: link.displayTitle,
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Added by + date row
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: accentColor, width: 1.5),
                        ),
                        child: ClipOval(
                          child: SmartProfileImage(
                            imageUrl: creatorPhotoUrl,
                            width: 28,
                            height: 28,
                            placeholder: Container(
                              color: accentColor.withValues(alpha: 0.2),
                              child: Icon(Icons.person, color: accentColor, size: 14),
                            ),
                            errorWidget: Container(
                              color: accentColor.withValues(alpha: 0.2),
                              child: Icon(Icons.person, color: accentColor, size: 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 12,
                              color: sheetDark ? Colors.white54 : Colors.grey.shade500,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Added by ',
                              ),
                              TextSpan(
                                text: creatorName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                              TextSpan(
                                text:
                                    '  ·  ${link.createdAt.toLocal().toString().substring(0, 10)}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Open Site Button inside details
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: platform.gradientColors.length >= 2
                            ? platform.gradientColors
                            : [accentColor, AppColors.lavender],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: platform.primaryColor.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _confirmOpenSite(
                          context,
                          url: link.url,
                          title: link.displayTitle,
                          platform: platform,
                        );
                      },
                      icon: const Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Open Site',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // ── Edit Button ──
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(ctx).pop();
                              AddEditLinkSheet.show(context, initialLink: link);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 46,
                              decoration: BoxDecoration(
                                color: sheetDark
                                    ? const Color(0xFF281E38)
                                    : AppColors.softRose.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.softRose.withValues(alpha: 0.35),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.softRose.withValues(alpha: 0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: AppColors.softRose.withValues(alpha: 0.18),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.edit_rounded,
                                      size: 14,
                                      color: AppColors.softRose,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Edit Link',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: sheetDark ? Colors.white : AppColors.deepCharcoal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // ── Delete Button ──
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(ctx).pop();
                              _confirmDelete(context, link, linksProvider);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 46,
                              decoration: BoxDecoration(
                                color: sheetDark
                                    ? const Color(0xFF2E1724)
                                    : const Color(0xFFFFF0F3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFFF4D6D).withValues(alpha: 0.35),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF4D6D).withValues(alpha: 0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF4D6D).withValues(alpha: 0.16),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 14,
                                      color: Color(0xFFFF4D6D),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Delete',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: Color(0xFFFF4D6D),
                                    ),
                                  ),
                                ],
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
        );
      },
    );
  }

  void _confirmOpenSite(
    BuildContext context, {
    required String url,
    required String title,
    required SocialPlatform platform,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.lightImpact();

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
              color: platform.primaryColor.withValues(alpha: 0.20),
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
                // Drag handle
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

                // Platform Brand Icon with glow
                PlatformBrandIcon(
                  platform: platform,
                  customUrl: url,
                  size: 58,
                  borderRadius: 18,
                ),
                const SizedBox(height: 16),

                Text(
                  'Open External Site?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'You are about to visit "$title" in your external browser or app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),

                // URL Pill Preview
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
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
                        Icons.link_rounded,
                        size: 14,
                        color: platform.primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          url,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Actions: Cancel & Open Site
                Row(
                  children: [
                    // Cancel
                    Expanded(
                      child: SecondaryCancelButton(
                        label: 'Cancel',
                        height: 48,
                        borderRadius: 16,
                        onPressed: () => Navigator.of(modalContext).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Open Site
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: platform.gradientColors.length >= 2
                                ? platform.gradientColors
                                : [AppColors.softRose, AppColors.lavender],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: platform.primaryColor.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(modalContext).pop();
                            UrlLauncherHelper.launchLink(context, url);
                          },
                          icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 16),
                          label: const Text(
                            'Open Site',
                            style: TextStyle(
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
                // Handle
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

                // Glowing trash emblem
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF4D6D), Color(0xFFD90429)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
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
                  'Delete Link?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Are you sure you want to remove "${link.displayTitle}" from your shared couple links?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: SecondaryCancelButton(
                        label: 'Cancel',
                        height: 48,
                        borderRadius: 16,
                        onPressed: () => Navigator.of(modalContext).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Confirm Delete Button
                    Expanded(
                      child: TimedDestructiveButton(
                        label: 'Delete',
                        icon: Icons.delete_outline_rounded,
                        countdownSeconds: 5,
                        height: 48,
                        borderRadius: 16,
                        fontSize: 14,
                        onPressed: () async {
                          Navigator.of(modalContext).pop();
                          HapticFeedback.mediumImpact();
                          final deleted = await provider.deleteLink(link.id);
                          if (context.mounted) {
                            if (deleted) {
                              SnackbarHelper.showSuccess(context, 'Link removed successfully');
                            } else {
                              SnackbarHelper.showError(
                                context,
                                provider.error ?? 'Failed to delete link.',
                              );
                            }
                          }
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
