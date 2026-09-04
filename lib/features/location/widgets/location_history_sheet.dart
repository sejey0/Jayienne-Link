import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/location_model.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/couple_provider.dart';

/// Premium Bottom Sheet for Interactive Route History Playback
/// Dynamically adapts to Light & Dark themes, supports collapsing into a compact mini player,
/// and includes a dedicated Full-Screen Map toggle.
class LocationHistorySheet extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onFitRoute;
  final bool isFullscreen;

  const LocationHistorySheet({
    super.key,
    required this.onClose,
    this.onToggleFullscreen,
    this.onFitRoute,
    this.isFullscreen = false,
  });

  @override
  State<LocationHistorySheet> createState() => _LocationHistorySheetState();
}

class _LocationHistorySheetState extends State<LocationHistorySheet> {
  bool _isCollapsed = false;

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);

    if (selected == today) {
      return 'Today, ${DateFormat('MMM d').format(date)}';
    } else if (selected == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${DateFormat('MMM d').format(date)}';
    }
    return DateFormat('EEE, MMM d, yyyy').format(date);
  }

  String _getHeadingDirection(double? heading) {
    if (heading == null || heading < 0) return 'Moving';
    final directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', 'N'];
    final index = ((heading % 360) / 45).round() % 8;
    return '${heading.toStringAsFixed(0)}° ${directions[index]}';
  }

  double _calculateDistanceUpTo(List<LocationModel> locations, int upToIndex) {
    if (locations.length < 2 || upToIndex <= 0) return 0.0;
    double total = 0.0;
    final maxIdx = math.min(upToIndex, locations.length - 1);
    for (int i = 0; i < maxIdx; i++) {
      total += Geolocator.distanceBetween(
        locations[i].latitude,
        locations[i].longitude,
        locations[i + 1].latitude,
        locations[i + 1].longitude,
      );
    }
    return total / 1000.0;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<LocationProvider>();
    final locations = provider.historyLocations;
    final currentIndex = provider.playbackIndex;
    final isPlaying = provider.isPlayingRoute;
    final selectedDate = provider.selectedHistoryDate;
    final isLoading = provider.isLoadingHistory;
    final currentPoint = provider.currentPlaybackLocation;
    final currentSpeed = provider.playbackSpeed;

    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();

    final myId = userProvider.user?.id ?? provider.currentUser?.id ?? provider.userId;
    final partnerUser = provider.partnerUser ?? coupleProvider.partner;
    final partnerId = partnerUser?.id ?? provider.partnerId ?? coupleProvider.partner?.id;
    final partnerName = partnerUser?.displayName.isNotEmpty == true
        ? partnerUser!.displayName
        : 'Partner';
    final isViewingPartner = provider.historyOwnerId == partnerId;

    final maxIndex = math.max(0, locations.length - 1).toDouble();
    final sliderVal = currentIndex
        .clamp(0, locations.isEmpty ? 0 : locations.length - 1)
        .toDouble();

    final currentDistanceKm = _calculateDistanceUpTo(locations, currentIndex);
    final totalDistanceKm = _calculateDistanceUpTo(locations, locations.length - 1);

    // Compute dynamic heading direction if point heading is 0 or null
    double? activeHeading = currentPoint?.heading;
    if ((activeHeading == null || activeHeading == 0.0) &&
        currentIndex < locations.length - 1 &&
        locations.isNotEmpty) {
      final nextLoc = locations[currentIndex + 1];
      if (currentPoint != null) {
        activeHeading = Geolocator.bearingBetween(
          currentPoint.latitude,
          currentPoint.longitude,
          nextLoc.latitude,
          nextLoc.longitude,
        );
        if (activeHeading < 0) activeHeading += 360;
      }
    }

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 200 && !_isCollapsed) {
            // Swipe down -> collapse card
            HapticFeedback.lightImpact();
            setState(() => _isCollapsed = true);
          } else if (details.primaryVelocity! < -200 && _isCollapsed) {
            // Swipe up -> expand card
            HapticFeedback.lightImpact();
            setState(() => _isCollapsed = false);
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: _isCollapsed
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
            : const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    const Color(0xF21F172E),
                    const Color(0xF7281B3D),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.96),
                    const Color(0xFFFAF7FC).withValues(alpha: 0.98),
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(_isCollapsed ? 22 : 28),
          border: Border.all(
            color: isDark
                ? AppColors.softRose.withValues(alpha: 0.38)
                : AppColors.softRose.withValues(alpha: 0.32),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.softRose.withValues(alpha: isDark ? 0.20 : 0.14),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, -2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.65 : 0.08),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag / Tap Pill Handle
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _isCollapsed = !_isCollapsed);
                },
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.28)
                        : Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              if (_isCollapsed)
                _buildCollapsedBar(
                  context,
                  isDark: isDark,
                  provider: provider,
                  isPlaying: isPlaying,
                  currentPoint: currentPoint,
                  currentIndex: currentIndex,
                  locationsCount: locations.length,
                  currentDistanceKm: currentDistanceKm,
                )
              else
                _buildExpandedContent(
                  context,
                  isDark: isDark,
                  provider: provider,
                  locations: locations,
                  currentIndex: currentIndex,
                  isPlaying: isPlaying,
                  selectedDate: selectedDate,
                  isLoading: isLoading,
                  currentPoint: currentPoint,
                  currentSpeed: currentSpeed,
                  partnerId: partnerId,
                  partnerName: partnerName,
                  isViewingPartner: isViewingPartner,
                  myId: myId,
                  sliderVal: sliderVal,
                  maxIndex: maxIndex,
                  currentDistanceKm: currentDistanceKm,
                  totalDistanceKm: totalDistanceKm,
                  activeHeading: activeHeading,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact Mini Bar when collapsed
  Widget _buildCollapsedBar(
    BuildContext context, {
    required bool isDark,
    required LocationProvider provider,
    required bool isPlaying,
    required LocationModel? currentPoint,
    required int currentIndex,
    required int locationsCount,
    required double currentDistanceKm,
  }) {
    return Row(
      children: [
        // Mini Play/Pause Glowing Button
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            provider.toggleRoutePlayback();
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.softRose, Color(0xFFE57388)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.softRose.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Telemetry Summary Strip
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    currentPoint != null ? currentPoint.formattedTime : '00:00',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.deepCharcoal,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.softRose.withValues(alpha: isDark ? 0.22 : 0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      locationsCount > 0 ? '${currentIndex + 1}/$locationsCount' : '0/0',
                      style: const TextStyle(
                        color: AppColors.softRose,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${currentDistanceKm.toStringAsFixed(1)} km traveled',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.65)
                      : Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Expand Playback Card Button
        IconButton(
          icon: Icon(
            Icons.keyboard_arrow_up_rounded,
            color: isDark ? Colors.white70 : const Color(0xFF3B2F4C),
            size: 24,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Expand Playback Card',
          onPressed: () {
            HapticFeedback.lightImpact();
            setState(() => _isCollapsed = false);
          },
        ),
        const SizedBox(width: 8),

        // Fullscreen Toggle Button
        if (widget.onToggleFullscreen != null) ...[
          IconButton(
            icon: Icon(
              widget.isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
              color: widget.isFullscreen ? AppColors.softRose : (isDark ? Colors.white70 : const Color(0xFF3B2F4C)),
              size: 21,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: widget.isFullscreen ? 'Exit Fullscreen' : 'Fullscreen Map',
            onPressed: () {
              HapticFeedback.lightImpact();
              widget.onToggleFullscreen!();
            },
          ),
          const SizedBox(width: 8),
        ],

        // Close Playback Button
        IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: isDark ? Colors.white70 : const Color(0xFF3B2F4C),
            size: 20,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Close Playback',
          onPressed: () {
            HapticFeedback.lightImpact();
            widget.onClose();
          },
        ),
      ],
    );
  }

  /// Full playback controls and telemetry when expanded
  Widget _buildExpandedContent(
    BuildContext context, {
    required bool isDark,
    required LocationProvider provider,
    required List<LocationModel> locations,
    required int currentIndex,
    required bool isPlaying,
    required DateTime selectedDate,
    required bool isLoading,
    required LocationModel? currentPoint,
    required double currentSpeed,
    required String? partnerId,
    required String partnerName,
    required bool isViewingPartner,
    required String? myId,
    required double sliderVal,
    required double maxIndex,
    required double currentDistanceKm,
    required double totalDistanceKm,
    required double? activeHeading,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Top Header (Title + Status Check Badge + Fullscreen + Close)
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.softRose, AppColors.lavender],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.route_rounded,
                color: Colors.white,
                size: 15,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Route History Playback',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.deepCharcoal,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),

            // Collapse Playback Card Button
            IconButton(
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isDark ? Colors.white70 : const Color(0xFF3B2F4C),
                size: 24,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Collapse Playback Card',
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() => _isCollapsed = true);
              },
            ),
            const SizedBox(width: 8),

            // Fullscreen Map Button (Restored!)
            if (widget.onToggleFullscreen != null) ...[
              IconButton(
                icon: Icon(
                  widget.isFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  color: widget.isFullscreen ? AppColors.softRose : (isDark ? Colors.white70 : const Color(0xFF3B2F4C)),
                  size: 21,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: widget.isFullscreen ? 'Exit Fullscreen' : 'Fullscreen Map',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.onToggleFullscreen!();
                },
              ),
              const SizedBox(width: 10),
            ],

            // Close / Exit Button
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: isDark ? Colors.white70 : const Color(0xFF3B2F4C),
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Close Playback',
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.onClose();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 2. Person Selector (Your Route vs Partner's Route)
        if (partnerId != null)
          Container(
            height: 38,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1B1426)
                  : const Color(0xFFEFE8F5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFDED4E7),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                if (myId != null)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (provider.historyOwnerId != myId) {
                          provider.setHistoryOwner(myId);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: !isViewingPartner
                              ? AppColors.softRose
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            if (!isViewingPartner)
                              BoxShadow(
                                color: AppColors.softRose.withValues(alpha: 0.40),
                                blurRadius: 6,
                                offset: const Offset(0, 1.5),
                              ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 13.5,
                              color: !isViewingPartner
                                  ? Colors.white
                                  : (isDark ? Colors.white60 : const Color(0xFF6B5F79)),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Your Route',
                              style: TextStyle(
                                color: !isViewingPartner
                                    ? Colors.white
                                    : (isDark ? Colors.white60 : const Color(0xFF6B5F79)),
                                fontSize: 12,
                                fontWeight: !isViewingPartner ? FontWeight.bold : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (partnerId.isNotEmpty && provider.historyOwnerId != partnerId) {
                        provider.setHistoryOwner(partnerId);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: isViewingPartner
                            ? AppColors.lavender
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          if (isViewingPartner)
                            BoxShadow(
                              color: AppColors.lavender.withValues(alpha: 0.40),
                              blurRadius: 6,
                              offset: const Offset(0, 1.5),
                            ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            size: 13.5,
                            color: isViewingPartner
                                ? Colors.white
                                : (isDark ? Colors.white60 : const Color(0xFF6B5F79)),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              "$partnerName's Route",
                              style: TextStyle(
                                color: isViewingPartner
                                    ? Colors.white
                                    : (isDark ? Colors.white60 : const Color(0xFF6B5F79)),
                                fontSize: 12,
                                fontWeight: isViewingPartner ? FontWeight.bold : FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // 3. Date Quick Selector Pills
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDatePill(
              context,
              label: 'Today',
              isDark: isDark,
              isSelected: _isSameDay(selectedDate, DateTime.now()),
              onTap: () => provider.setSelectedHistoryDate(DateTime.now()),
            ),
            const SizedBox(width: 8),
            _buildDatePill(
              context,
              label: 'Yesterday',
              isDark: isDark,
              isSelected: _isSameDay(
                selectedDate,
                DateTime.now().subtract(const Duration(days: 1)),
              ),
              onTap: () => provider.setSelectedHistoryDate(
                DateTime.now().subtract(const Duration(days: 1)),
              ),
            ),
            const SizedBox(width: 8),
            _buildDatePill(
              context,
              label: _isSameDay(selectedDate, DateTime.now()) ||
                      _isSameDay(selectedDate,
                          DateTime.now().subtract(const Duration(days: 1)))
                  ? 'Pick Date'
                  : DateFormat('MMM d').format(selectedDate),
              isDark: isDark,
              icon: Icons.calendar_month_rounded,
              isSelected: !_isSameDay(selectedDate, DateTime.now()) &&
                  !_isSameDay(selectedDate,
                      DateTime.now().subtract(const Duration(days: 1))),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: isDark
                            ? const ColorScheme.dark(
                                primary: AppColors.softRose,
                                surface: Color(0xFF1E1A29),
                              )
                            : const ColorScheme.light(
                                primary: AppColors.softRose,
                              ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  provider.setSelectedHistoryDate(picked);
                }
              },
            ),
          ],
        ),

        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.softRose,
                strokeWidth: 2.5,
              ),
            ),
          )
        else if (locations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: [
                Icon(
                  Icons.explore_off_rounded,
                  size: 36,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.35)
                      : Colors.grey.shade400,
                ),
                const SizedBox(height: 6),
                Text(
                  'No route points found for ${_formatDateLabel(selectedDate)}',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.65)
                        : Colors.grey.shade600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          )
        else ...[
          const SizedBox(height: 6),

          // 4. Time & Distance Progress Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currentPoint != null
                      ? '${currentPoint.formattedTime}  •  ${currentDistanceKm.toStringAsFixed(1)} km'
                      : '0.0 km',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${totalDistanceKm.toStringAsFixed(1)} km total',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.grey.shade600,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),

          // 5. Interactive Timeline Scrubber Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.softRose,
              inactiveTrackColor: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : const Color(0xFFE0D4EC),
              thumbColor: AppColors.softRose,
              overlayColor: AppColors.softRose.withValues(alpha: 0.25),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.5),
              trackHeight: 3.5,
            ),
            child: Slider(
              value: sliderVal,
              min: 0,
              max: maxIndex,
              divisions: locations.length > 1 ? locations.length - 1 : 1,
              onChanged: (val) {
                provider.seekPlayback(val.toInt());
              },
            ),
          ),

          // 6. Live Telemetry Data Strip (Speed, Heading, Battery, Stop Count)
          if (currentPoint != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFF5EFFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : const Color(0xFFE6DCF0),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Speed
                  _buildTelemetryItem(
                    isDark: isDark,
                    icon: Icons.speed_rounded,
                    label: currentPoint.speed != null && currentPoint.speed! > 0
                        ? '${(currentPoint.speed! * 3.6).toStringAsFixed(0)} km/h'
                        : '0 km/h',
                    color: isDark ? AppColors.lavender : const Color(0xFF6B63B5),
                  ),
                  // Heading
                  _buildTelemetryItem(
                    isDark: isDark,
                    icon: Icons.explore_rounded,
                    label: _getHeadingDirection(activeHeading),
                    color: isDark ? Colors.greenAccent : const Color(0xFF2E7D32),
                  ),
                  // Battery
                  if (currentPoint.batteryLevel != null)
                    _buildTelemetryItem(
                      isDark: isDark,
                      icon: Icons.battery_5_bar_rounded,
                      label: '${currentPoint.batteryLevel}%',
                      color: isDark ? Colors.amberAccent : Colors.orange.shade700,
                    ),
                  // Stop Index
                  _buildTelemetryItem(
                    isDark: isDark,
                    icon: Icons.location_on_rounded,
                    label: '${currentIndex + 1}/${locations.length}',
                    color: AppColors.softRose,
                  ),
                ],
              ),
            ),

          // 7. Playback Controls & Speed Multiplier
          Row(
            children: [
              // Speed Selector Pills (1x, 2x, 5x, 10x)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFF1EBF7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [1.0, 2.0, 5.0, 10.0].map((spd) {
                    final isSelected = currentSpeed == spd;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        provider.setPlaybackSpeed(spd);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.softRose
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${spd.toInt()}x',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white60 : const Color(0xFF6B5F79)),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const Spacer(),

              // Fit / Recenter Route on Map Button
              if (widget.onFitRoute != null && locations.isNotEmpty) ...[
                IconButton(
                  icon: Icon(
                    Icons.center_focus_strong_rounded,
                    color: isDark ? Colors.white70 : const Color(0xFF3B2F4C),
                    size: 21,
                  ),
                  tooltip: 'Fit Route to Screen',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.onFitRoute!();
                  },
                ),
                const SizedBox(width: 6),
              ],

              // Main Play / Pause Glowing Action Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  provider.toggleRoutePlayback();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.softRose, Color(0xFFE57388)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.softRose.withValues(alpha: 0.50),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isPlaying ? 'Pause' : 'Play',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDatePill(
    BuildContext context, {
    required String label,
    required bool isDark,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5.5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.softRose
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFF3EDF8)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.softRose
                : (isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : const Color(0xFFE2D7ED)),
            width: 1.2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.softRose.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF4C3E5E)),
              ),
              const SizedBox(width: 4.5),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF4C3E5E)),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryItem({
    required bool isDark,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13.5, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.deepCharcoal,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
