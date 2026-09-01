import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/zodiac_helper.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/url_launcher_helper.dart';
import '../../../models/couple_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/anniversary_provider.dart';
import '../../../providers/couple_links_provider.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/user_provider.dart';
import '../../links/widgets/add_edit_link_sheet.dart';
import '../../links/widgets/platform_brand_icon.dart';
import '../../../widgets/common/romantic_loading_indicator.dart';

class ProfileViewScreen extends StatefulWidget {
  const ProfileViewScreen({super.key});

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  Future<void> _requestAnniversary(
    BuildContext context,
    UserModel user,
    CoupleModel couple,
  ) async {
    HapticFeedback.lightImpact();
    if (couple.id == null) {
      SnackbarHelper.showError(context, 'Couple not ready. Try again.');
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: couple.anniversary ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: isDark
              ? const ColorScheme.dark(
                  primary: Color(0xFFFF758C),
                  onPrimary: Colors.white,
                  surface: Color(0xFF1C1427),
                  onSurface: Colors.white,
                )
              : const ColorScheme.light(
                  primary: Color(0xFFFF758C),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Color(0xFF2D4059),
                ),
        ),
        child: child!,
      ),
    );

    if (picked == null) return;
    if (!context.mounted) return;

    final coupleProvider = context.read<CoupleProvider>();
    final partnerId = couple.getPartnerId(user.id);
    if (partnerId.isEmpty) {
      SnackbarHelper.showError(context, 'Partner not found.');
      return;
    }
    final success = await coupleProvider.sendAnniversaryRequest(
      coupleId: couple.id!,
      proposerId: user.id,
      partnerId: partnerId,
      proposedDate: picked,
    );

    if (!context.mounted) return;
    if (success) {
      SnackbarHelper.showSuccess(context, 'Anniversary request sent to your partner');
    } else if (coupleProvider.error != null) {
      SnackbarHelper.showError(context, coupleProvider.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final anniversaryProvider = context.watch<AnniversaryProvider>();
    final user = userProvider.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return const RomanticLoadingScreen(
        message: 'Loading your profile...',
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF120E19) : const Color(0xFFFFF7F9),
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
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
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            tooltip: 'Edit Profile',
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push(RouteNames.editProfile);
            },
          ),
        ],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Hero Header Banner ─────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF758C).withValues(alpha: 0.12),
                    const Color(0xFFA18CD1).withValues(alpha: 0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  // Avatar with gradient ring
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF120E19) : Colors.white,
                      ),
                      child: CircleAvatar(
                        radius: AppDimensions.avatarSizeLarge / 2,
                        backgroundColor: const Color(0xFFFF758C).withValues(alpha: 0.15),
                        backgroundImage: _getProfileImageProvider(user.photoUrl),
                        child: user.photoUrl == null
                            ? Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.displayName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.deepCharcoal,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // Birthday Badge
                      if (user.birthday != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF758C).withValues(alpha: isDark ? 0.12 : 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cake_outlined, size: 13, color: Color(0xFFFF758C)),
                              const SizedBox(width: 5),
                              Text(
                                _formatDate(user.birthday!),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFF758C),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Zodiac Badge or Set Button
                      if (user.zodiacSign != null && user.zodiacSign!.isNotEmpty) ...[
                        Builder(
                          builder: (context) {
                            final zodiacInfo = ZodiacHelper.getZodiac(user.zodiacSign);
                            final color = zodiacInfo?.color ?? const Color(0xFFA18CD1);
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: isDark ? 0.18 : 0.10),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ZodiacIcon(
                                    zodiac: user.zodiacSign!,
                                    size: 14,
                                    color: color,
                                    strokeWidth: 2.0,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    user.zodiacSign!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push(RouteNames.editProfile);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFA18CD1).withValues(alpha: isDark ? 0.16 : 0.09),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFA18CD1).withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome_rounded, size: 13, color: Color(0xFFA18CD1)),
                                SizedBox(width: 5),
                                Text(
                                  'Set Zodiac Sign',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFA18CD1),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFFA18CD1)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  // ── Couple Card (Gradient hero style) ─────────────
                  if (coupleProvider.couple != null) ...[
                    _buildCoupleCard(
                      context: context,
                      isDark: isDark,
                      user: user,
                      coupleProvider: coupleProvider,
                      anniversaryProvider: anniversaryProvider,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── My Social Links Section ────────────────────────
                  _buildSocialLinksSection(context, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoupleCard({
    required BuildContext context,
    required bool isDark,
    required UserModel user,
    required CoupleProvider coupleProvider,
    required AnniversaryProvider anniversaryProvider,
  }) {
    final couple = coupleProvider.couple!;
    final partnerName = couple.getPartnerName(
      user.uid,
      livePartnerName: coupleProvider.partner?.displayName,
    );
    final partnerPhotoUrl = coupleProvider.partner?.photoUrl;
    final pendingAnniversary = coupleProvider.outgoingAnniversaryRequests.isNotEmpty
        ? coupleProvider.outgoingAnniversaryRequests.first
        : null;

    final partnerZodiac = coupleProvider.partner?.zodiacSign;
    final userZodiac = user.zodiacSign;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.30),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF758C).withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Section label
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'COUPLE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.4,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Dual avatars with heart & zodiac badges
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // My avatar + zodiac
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeroAvatar(photoUrl: user.photoUrl),
                    if (userZodiac != null && userZodiac.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildZodiacPill(userZodiac),
                    ],
                  ],
                ),
                const SizedBox(width: 16),
                // Heart
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.25),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                // Partner avatar + zodiac
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeroAvatar(photoUrl: partnerPhotoUrl),
                    if (partnerZodiac != null && partnerZodiac.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildZodiacPill(partnerZodiac),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Names row
            Row(
              children: [
                Expanded(
                  child: _buildWhiteNamePill(user.displayName),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildWhiteNamePill(partnerName),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Days together counter
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${couple.daysTogether}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'days together',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Anniversary date row
            GestureDetector(
              onTap: () => _requestAnniversary(context, user, couple),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pendingAnniversary != null
                            ? 'Request pending: ${DateFormat('MMM d, yyyy').format(pendingAnniversary.proposedDate)}'
                            : couple.anniversary != null
                                ? 'Anniversary: ${DateFormat('MMM d, yyyy').format(couple.anniversary!)}'
                                : 'Set your anniversary date',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: pendingAnniversary != null
                              ? Colors.white70
                              : couple.anniversary != null
                                  ? Colors.white
                                  : Colors.white70,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.edit_calendar_rounded,
                      color: Colors.white.withValues(alpha: 0.70),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroAvatar({required String? photoUrl}) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 32,
        backgroundColor: Colors.white.withValues(alpha: 0.25),
        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
            ? _getProfileImageProvider(photoUrl)
            : null,
        child: (photoUrl == null || photoUrl.isEmpty)
            ? const Icon(Icons.person_rounded, size: 32, color: Colors.white)
            : null,
      ),
    );
  }

  Widget _buildWhiteNamePill(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        name,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildZodiacPill(String zodiacName) {
    final info = ZodiacHelper.getZodiac(zodiacName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ZodiacIcon(
            zodiac: zodiacName,
            size: 11,
            color: Colors.white,
            strokeWidth: 2.0,
          ),
          const SizedBox(width: 4),
          Text(
            info?.name ?? zodiacName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required List<Color> gradientColors,
    required String label,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1427) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: gradientColors.first.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 15),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: gradientColors.first,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildSocialLinksSection(BuildContext context, bool isDark) {
    final linksProvider = context.watch<CoupleLinksProvider>();
    // Only show MY links
    final myLinks = linksProvider.myLinks;

    return _buildSectionCard(
      context: context,
      isDark: isDark,
      icon: Icons.link_rounded,
      gradientColors: const [Color(0xFFA18CD1), Color(0xFF7C82E8)],
      label: 'MY SOCIALS & WEBSITES',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                myLinks.isEmpty
                    ? 'No links added yet'
                    : '${myLinks.length} link${myLinks.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push(RouteNames.coupleLinks);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA18CD1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFA18CD1).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text(
                    'Manage',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFA18CD1),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (myLinks.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.link_off_rounded,
                    size: 28,
                    color: isDark ? Colors.white30 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No social profiles or websites added yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      AddEditLinkSheet.show(context);
                    },
                    icon: const Icon(Icons.add_rounded, size: 14),
                    label: const Text(
                      'Add Link',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFA18CD1),
                      side: const BorderSide(color: Color(0xFFA18CD1)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Centered wrap of link chips
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: myLinks.map((link) {
                final platform = link.socialPlatform;
                return InkWell(
                  onTap: () => UrlLauncherHelper.launchLink(context, link.url),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? platform.primaryColor.withValues(alpha: 0.15)
                          : platform.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: platform.primaryColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlatformBrandIcon(
                          platform: platform,
                          size: 22,
                          borderRadius: 6,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          link.displayTitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.deepCharcoal,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_outward_rounded,
                          size: 12,
                          color: platform.primaryColor,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  ImageProvider? _getProfileImageProvider(String? photoUrl) {
    if (photoUrl == null) return null;
    if (photoUrl.startsWith('data:image/')) {
      try {
        final base64String = photoUrl.split(',')[1];
        final bytes = base64Decode(base64String);
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    } else {
      return CachedNetworkImageProvider(photoUrl);
    }
  }
}
