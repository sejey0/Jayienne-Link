import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../models/location_model.dart';
import '../../../providers/anniversary_provider.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/user_provider.dart';

/// Unified Couple Hero Masterpiece Card:
/// Merges Love Counter, Dual Avatars with Beating Heart, Intertwined Couple Names,
/// Live Ticking Breakdown, and Real-time Partner Vitals into a single romantic card.
class CoupleHeroCard extends StatefulWidget {
  final bool initialExpanded;

  const CoupleHeroCard({
    super.key,
    this.initialExpanded = false,
  });

  @override
  State<CoupleHeroCard> createState() => _CoupleHeroCardState();
}

class _CoupleHeroCardState extends State<CoupleHeroCard>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _heartController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;

    // Smooth heartbeat double-pulse loop animation controller
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(
        parent: _heartController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    HapticFeedback.lightImpact();
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  Future<void> _showDatePickerDialog(
    BuildContext context,
    AnniversaryProvider provider,
  ) async {
    HapticFeedback.lightImpact();
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.anniversaryDate ?? DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      await provider.setAnniversaryDate(picked);
    }
  }

  String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) return 'th';
    switch (number % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final anniversaryProvider = context.watch<AnniversaryProvider>();
    final locationProvider = context.watch<LocationProvider>();

    final user = userProvider.user;
    final couple = coupleProvider.couple;
    final partner = coupleProvider.partner;
    final outgoingAnniversary = coupleProvider.outgoingAnniversaryRequests;
    final pendingAnniversary =
        outgoingAnniversary.isNotEmpty ? outgoingAnniversary.first : null;

    final hasDate = anniversaryProvider.hasAnniversaryDate;

    // Location & Online status
    final partnerLoc = locationProvider.partnerLocation;
    final isAppOnline = locationProvider.isOnline;
    final isPartnerOnline = partner != null &&
        isAppOnline &&
        partnerLoc != null &&
        partnerLoc.isRecent(threshold: const Duration(minutes: 5));

    final myName = (user != null && user.displayName.isNotEmpty)
        ? user.displayName
        : 'You';
    final partnerName = couple != null && user != null
        ? couple.getPartnerName(user.uid, livePartnerName: partner?.displayName)
        : (partner?.displayName ?? 'Partner');

    // Distance calculation
    final distanceMeters = locationProvider.distanceInMeters;
    String distanceString = '';
    if (locationProvider.myLatLng != null && locationProvider.partnerLatLng != null) {
      final km = distanceMeters / 1000.0;
      if (km < 0.05) {
        distanceString = 'Together ❤️';
      } else if (km < 1.0) {
        distanceString = '${distanceMeters.toStringAsFixed(0)}m apart';
      } else {
        distanceString = '${km.toStringAsFixed(1)} km apart';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF758C).withValues(alpha: 0.94),
            const Color(0xFFA18CD1).withValues(alpha: 0.96),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF758C).withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: hasDate
              ? _toggleExpanded
              : () => _showDatePickerDialog(context, anniversaryProvider),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Top Romantic Header Bar (Active Status on left, Seconds ticker & arrow on right)
                  _buildHeaderRow(
                    context,
                    anniversaryProvider,
                    hasDate,
                    isPartnerOnline: isPartnerOnline,
                    isLinked: partner != null,
                  ),
                  const SizedBox(height: 18),

                  // 2. Dual Avatars with Pulsing Beating Heart in Center
                  _buildDualAvatarsSection(
                    context,
                    userPhotoUrl: user?.photoUrl,
                    partnerPhotoUrl: partner?.photoUrl,
                    isPartnerOnline: isPartnerOnline,
                  ),
                  const SizedBox(height: 14),

                  // 3. Intertwined Couple Names Modern Pill (e.g. CJay 💖 Ayen)
                  _buildCoupleNamesPill(context, myName, partnerName),
                  const SizedBox(height: 16),

                  // 4. Prominent Live Love Counter
                  if (hasDate)
                    _buildLoveCounterBody(context, anniversaryProvider)
                  else
                    _buildSetDatePrompt(context, anniversaryProvider),

                  // 5. Expandable Detailed Duration & Milestone Progress
                  if (hasDate && _isExpanded) ...[
                    const SizedBox(height: 16),
                    _buildExpandedContent(context, anniversaryProvider),
                  ],

                  // 6. Bottom Partner Vitals Bar (Distance, Battery, Status)
                  if (partner != null) ...[
                    const SizedBox(height: 16),
                    _buildPartnerVitalsBar(
                      context,
                      isPartnerOnline: isPartnerOnline,
                      distanceString: distanceString,
                      partnerLoc: partnerLoc,
                    ),
                  ],

                  // 7. Pending Anniversary Notice if present
                  if (pendingAnniversary != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.hourglass_top_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Anniversary request pending: ${DateFormat('MMMM d, yyyy').format(pendingAnniversary.proposedDate)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Top Row: Active Status Badge on left, Date & Live Ticking Seconds Pill + Expand Arrow on right
  Widget _buildHeaderRow(
    BuildContext context,
    AnniversaryProvider provider,
    bool hasDate, {
    required bool isPartnerOnline,
    required bool isLinked,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Re-aligned Active Now / Partner Status Badge on Left
        if (isLinked)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.circle,
                  size: 7,
                  color: isPartnerOnline
                      ? const Color(0xFF69F0AE)
                      : Colors.white.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 5.5),
                Text(
                  isPartnerOnline ? 'Active Now' : 'Last seen recently',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          )
        else
          const SizedBox.shrink(),

        // Date & Ticking Pill & Arrow
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasDate) ...[
              // Live Ticking Seconds Pill
              Selector<AnniversaryProvider, int>(
                selector: (_, p) => p.secondsTogetherRemainder,
                builder: (context, seconds, _) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${seconds.toString().padLeft(2, '0')}s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),

              // Expand / Collapse Arrow
              Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: Colors.white,
                size: 24,
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Dual Glowing Avatars with Beating Heart Pulse
  Widget _buildDualAvatarsSection(
    BuildContext context, {
    required String? userPhotoUrl,
    required String? partnerPhotoUrl,
    required bool isPartnerOnline,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // User Avatar (Left)
          _buildAvatarWithRing(
            context,
            photoUrl: userPhotoUrl,
            label: 'You',
          ),

          const SizedBox(width: 16),

          // Beating Heart Animation with Haptic Feedback on Tap
          GestureDetector(
            onTap: () => HapticFeedback.lightImpact(),
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Partner Avatar (Right) with Online Status Ring
          _buildAvatarWithRing(
            context,
            photoUrl: partnerPhotoUrl,
            isOnline: isPartnerOnline,
            showStatus: true,
            label: 'Partner',
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWithRing(
    BuildContext context, {
    required String? photoUrl,
    bool isOnline = false,
    bool showStatus = false,
    required String label,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 3.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                ? NetworkImage(photoUrl)
                : null,
            child: (photoUrl == null || photoUrl.isEmpty)
                ? const Icon(
                    Icons.person_rounded,
                    size: 38,
                    color: Colors.white,
                  )
                : null,
          ),
        ),

        // Live Online / Offline Indicator Badge
        if (showStatus)
          Positioned(
            right: 3,
            bottom: 3,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isOnline
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF8E8E93),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isOnline
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.2),
                    blurRadius: 6,
                    spreadRadius: isOnline ? 1 : 0,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: !isOnline
                  ? Center(
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
      ],
    );
  }

  /// Intertwined Couple Names Pill (e.g. CJay 💖 Ayen)
  Widget _buildCoupleNamesPill(
    BuildContext context,
    String myName,
    String partnerName,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            myName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 15,
            ),
          ),
          Text(
            partnerName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Big Prominent Love Counter Display (e.g. 428 Days Together + 1yr 2mos 3days)
  Widget _buildLoveCounterBody(
    BuildContext context,
    AnniversaryProvider provider,
  ) {
    return Column(
      children: [
        // Main Total Days Together in Bold Glamour Typography
        Selector<AnniversaryProvider, int>(
          selector: (_, p) => p.totalDaysTogether,
          builder: (context, totalDays, _) {
            return Column(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Color(0xFFFFF0F5)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds),
                  child: Text(
                    '$totalDays Days Together',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Sub-Breakdown Pill (e.g. 1 Year • 2 Months • 3 Days)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${provider.yearsTogether} ${provider.yearsTogether == 1 ? "Year" : "Years"} • ${provider.monthsTogether} ${provider.monthsTogether == 1 ? "Month" : "Months"} • ${provider.daysTogetherRemainder} ${provider.daysTogetherRemainder == 1 ? "Day" : "Days"}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Detailed View shown when Expanded
  Widget _buildExpandedContent(
    BuildContext context,
    AnniversaryProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white24, height: 1),
        const SizedBox(height: 14),

        // Official Anniversary Date Row with Edit Button
        if (provider.anniversaryDate != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Anniversary: ${DateFormat('MMMM d, yyyy').format(provider.anniversaryDate!)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _showDatePickerDialog(context, provider),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_calendar_rounded,
                          color: Colors.white70, size: 14),
                      SizedBox(width: 3),
                      Text(
                        'Change',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Detailed Duration Precision Breakdown (y m d h m s)
        Selector<AnniversaryProvider, String>(
          selector: (_, p) =>
              '${p.yearsTogether}y ${p.monthsTogether}m ${p.daysTogetherRemainder}d ${p.hoursTogetherRemainder}h ${p.minutesTogetherRemainder}m ${p.secondsTogetherRemainder}s',
          builder: (context, durationString, _) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  durationString,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),

        // Progress Bar toward Next Anniversary
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${provider.daysUntilNextAnniversary} days until ${provider.nextAnniversaryYearNumber}${_getOrdinalSuffix(provider.nextAnniversaryYearNumber)} Anniversary',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(provider.progressToNextAnniversary * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: provider.progressToNextAnniversary,
                minHeight: 7,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Tap to collapse',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  /// Prompt to set anniversary if missing
  Widget _buildSetDatePrompt(
    BuildContext context,
    AnniversaryProvider provider,
  ) {
    return Column(
      children: [
        const Text(
          'When did your love story begin?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Set your anniversary date to start the live counter.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () => _showDatePickerDialog(context, provider),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFFFF758C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          ),
          icon: const Icon(Icons.calendar_month_rounded, size: 16),
          label: const Text(
            'Set Anniversary Date',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }

  /// Bottom Partner Vitals Dock (Distance • Battery / Connection)
  Widget _buildPartnerVitalsBar(
    BuildContext context, {
    required bool isPartnerOnline,
    required String distanceString,
    required LocationModel? partnerLoc,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Distance
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: Colors.white,
                size: 13,
              ),
              const SizedBox(width: 5),
              Text(
                distanceString.isNotEmpty ? distanceString : 'Location active',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          Container(
            width: 1,
            height: 14,
            color: Colors.white24,
          ),

          // Battery
          if (partnerLoc != null && partnerLoc.batteryLevel != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  (partnerLoc.batteryLevel! > 80)
                      ? Icons.battery_full_rounded
                      : (partnerLoc.batteryLevel! > 40)
                          ? Icons.battery_5_bar_rounded
                          : (partnerLoc.batteryLevel! > 15)
                              ? Icons.battery_2_bar_rounded
                              : Icons.battery_alert_rounded,
                  color: Colors.white,
                  size: 13,
                ),
                const SizedBox(width: 5),
                Text(
                  '${partnerLoc.batteryLevel}% Battery',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPartnerOnline
                      ? Icons.wifi_rounded
                      : Icons.wifi_off_rounded,
                  color: Colors.white,
                  size: 13,
                ),
                const SizedBox(width: 5),
                Text(
                  isPartnerOnline ? 'Live Connected' : 'Offline',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
