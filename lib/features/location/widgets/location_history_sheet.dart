import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/location_provider.dart';

/// Bottom panel for controlling Location History & Route Playback
class LocationHistorySheet extends StatelessWidget {
  final VoidCallback onClose;

  const LocationHistorySheet({
    super.key,
    required this.onClose,
  });

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
    if (heading == null) return '';
    final directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', 'N'];
    final index = ((heading % 360) / 45).round() % 8;
    return '${heading.toStringAsFixed(0)}° ${directions[index]}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocationProvider>();
    final locations = provider.historyLocations;
    final currentIndex = provider.playbackIndex;
    final isPlaying = provider.isPlayingRoute;
    final selectedDate = provider.selectedHistoryDate;
    final isLoading = provider.isLoadingHistory;
    final currentPoint = provider.currentPlaybackLocation;

    final myId = provider.currentUser?.id ?? provider.userId;
    final partnerId = provider.partnerUser?.id ?? provider.partnerId;
    final partnerName = provider.partnerUser?.displayName.isNotEmpty == true
        ? provider.partnerUser!.displayName
        : 'Partner';
    final isViewingPartner = provider.historyOwnerId == partnerId;

    final maxIndex = math.max(0, locations.length - 1).toDouble();
    final sliderVal = currentIndex.clamp(0, locations.isEmpty ? 0 : locations.length - 1).toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1A29).withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.softRose.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar: Mode Title & Exit Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.softRose.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: AppColors.softRose,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Route History Playback',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Person Selector (My Route vs Partner's Route)
            if (partnerId != null)
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (partnerId.isNotEmpty) {
                            provider.setHistoryOwner(partnerId);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isViewingPartner ? AppColors.softRose : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "$partnerName's Route",
                            style: TextStyle(
                              color: isViewingPartner ? Colors.white : Colors.white60,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (myId != null)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            provider.setHistoryOwner(myId);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: !isViewingPartner ? AppColors.lavender : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'My Route',
                              style: TextStyle(
                                color: !isViewingPartner ? Colors.white : Colors.white60,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 10),

            // Date Navigation Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                  onPressed: () {
                    provider.setSelectedHistoryDate(
                      selectedDate.subtract(const Duration(days: 1)),
                    );
                  },
                ),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppColors.softRose,
                              surface: Color(0xFF1E1A29),
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
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.softRose),
                        const SizedBox(width: 6),
                        Text(
                          _formatDateLabel(selectedDate),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                  onPressed: selectedDate.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
                      ? () {
                          provider.setSelectedHistoryDate(
                            selectedDate.add(const Duration(days: 1)),
                          );
                        }
                      : null,
                ),
              ],
            ),

            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.softRose, strokeWidth: 2.5),
                ),
              )
            else if (locations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  children: [
                    Icon(Icons.route_rounded, size: 36, color: Colors.white.withValues(alpha: 0.3)),
                    const SizedBox(height: 6),
                    Text(
                      'No recorded points for ${_formatDateLabel(selectedDate)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Timeline Slider & Point Count
              Row(
                children: [
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.softRose,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                        thumbColor: AppColors.softRose,
                        overlayColor: AppColors.softRose.withValues(alpha: 0.2),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
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
                  ),
                  Text(
                    '${currentIndex + 1}/${locations.length}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // Point Info Badge
              if (currentPoint != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Time
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 14, color: AppColors.softRose),
                          const SizedBox(width: 4),
                          Text(
                            currentPoint.formattedTime,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      // Speed
                      Row(
                        children: [
                          const Icon(Icons.speed_rounded, size: 14, color: AppColors.lavender),
                          const SizedBox(width: 4),
                          Text(
                            currentPoint.speed != null && currentPoint.speed! > 0
                                ? '${(currentPoint.speed! * 3.6).toStringAsFixed(1)} km/h'
                                : '0.0 km/h',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                      // Heading
                      if (currentPoint.heading != null && currentPoint.heading! >= 0)
                        Row(
                          children: [
                            const Icon(Icons.explore_rounded, size: 14, color: Colors.greenAccent),
                            const SizedBox(width: 4),
                            Text(
                              _getHeadingDirection(currentPoint.heading),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      // Battery
                      if (currentPoint.batteryLevel != null)
                        Row(
                          children: [
                            const Icon(Icons.battery_charging_full_rounded, size: 14, color: Colors.amberAccent),
                            const SizedBox(width: 4),
                            Text(
                              '${currentPoint.batteryLevel}%',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

              // Playback Controls (Rewind, Play/Pause, Forward)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 28),
                    onPressed: currentIndex > 0
                        ? () => provider.seekPlayback(math.max(0, currentIndex - 5))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton.small(
                    backgroundColor: AppColors.softRose,
                    foregroundColor: Colors.white,
                    onPressed: () {
                      provider.toggleRoutePlayback();
                    },
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
                    onPressed: currentIndex < locations.length - 1
                        ? () => provider.seekPlayback(math.min(locations.length - 1, currentIndex + 5))
                        : null,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
