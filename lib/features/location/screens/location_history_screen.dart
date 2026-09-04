import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/location_model.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/mapbox_service.dart';
import '../widgets/offline_status_indicator.dart';
import '../../../widgets/common/timed_confirm_dialog.dart';

/// Redesigned Location History Screen featuring romantic trip summary cards,
/// person switcher, quick date filter chips, interactive day map previews,
/// and 1-tap route playback on the main map.
class LocationHistoryScreen extends StatefulWidget {
  final int initialTab;

  const LocationHistoryScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen> {
  int _selectedPersonIndex = 0; // 0 = Me, 1 = Partner
  DateTime? _selectedDateFilter;
  final Set<String> _expandedDays = {};
  final Set<String> _collapsedCards = {};

  @override
  void initState() {
    super.initState();
    _selectedPersonIndex = widget.initialTab.clamp(0, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }

  Future<void> _loadHistory({bool forceRefresh = false}) async {
    final provider = context.read<LocationProvider>();
    await provider.loadLocationHistory(forceRefresh: forceRefresh);
    await provider.loadPartnerLocationHistory();
  }

  double _calculateTotalDistance(List<LocationModel> locations) {
    if (locations.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < locations.length - 1; i++) {
      total += Geolocator.distanceBetween(
        locations[i].latitude,
        locations[i].longitude,
        locations[i + 1].latitude,
        locations[i + 1].longitude,
      );
    }
    return total / 1000.0; // in km
  }

  Map<DateTime, List<LocationModel>> _groupByDate(List<LocationModel> locations) {
    final Map<DateTime, List<LocationModel>> grouped = {};

    for (final location in locations) {
      final local = location.timestamp.toLocal();
      final date = DateTime(
        local.year,
        local.month,
        local.day,
      );

      grouped.putIfAbsent(date, () => []).add(location);
    }

    // Sort locations inside each day chronologically
    for (final date in grouped.keys) {
      grouped[date]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    return grouped;
  }

  List<LocationModel> _filterLocationsByDate(List<LocationModel> locations) {
    if (_selectedDateFilter == null) return locations;

    return locations.where((loc) {
      final l = loc.timestamp.toLocal();
      final f = _selectedDateFilter!.toLocal();
      return l.year == f.year && l.month == f.month && l.day == f.day;
    }).toList();
  }

  String _formatDateTitle(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return 'Today • ${DateFormat('MMM d').format(date)}';
    } else if (date == yesterday) {
      return 'Yesterday • ${DateFormat('MMM d').format(date)}';
    } else {
      return DateFormat('EEEE, MMM d, yyyy').format(date);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final aLocal = a.toLocal();
    final bLocal = b.toLocal();
    return aLocal.year == bLocal.year &&
        aLocal.month == bLocal.month &&
        aLocal.day == bLocal.day;
  }

  void _launchMapPlayback(DateTime date, bool isMyRoute, LocationProvider provider) {
    HapticFeedback.mediumImpact();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final myId = userProvider.user?.id ?? provider.currentUser?.id ?? provider.userId;
    final partnerId = provider.partnerUser?.id ?? provider.partnerId;
    final targetOwner = isMyRoute ? myId : (partnerId ?? myId);

    if (targetOwner != null) {
      provider.setSelectedHistoryDate(date, ownerId: targetOwner);
      provider.toggleHistoryMode(true, ownerId: targetOwner);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final partnerName = provider.partnerUser?.displayName.isNotEmpty == true
        ? provider.partnerUser!.displayName
        : 'Partner';

    final isMyLocations = _selectedPersonIndex == 0;
    final activeLocationsList =
        isMyLocations ? provider.locationHistory : provider.partnerLocationHistory;
    final filteredLocations = _filterLocationsByDate(activeLocationsList);
    final groupedDays = _groupByDate(filteredLocations);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF140F1D) : const Color(0xFFF9F7FB),
      appBar: AppBar(
        title: const Text(
          'Location History',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.2,
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
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
            tooltip: 'Clear History',
            onPressed: () {
              _confirmDeleteHistory(context, provider);
            },
          ),
          const SizedBox(width: 4),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          const OfflineBanner(),

          // 1. Person Segmented Pill Switcher (You vs Partner)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF221A30)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFEBE6F2),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildPersonTab(
                    title: 'Your Route',
                    icon: Icons.person_rounded,
                    isSelected: _selectedPersonIndex == 0,
                    accentColor: AppColors.softRose,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedPersonIndex = 0);
                    },
                  ),
                ),
                Expanded(
                  child: _buildPersonTab(
                    title: "$partnerName's Route",
                    icon: Icons.favorite_rounded,
                    isSelected: _selectedPersonIndex == 1,
                    accentColor: AppColors.lavender,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedPersonIndex = 1);
                    },
                  ),
                ),
              ],
            ),
          ),

          // 2. Quick Date Filter Chips Row
          _buildDateFilters(context),

          const SizedBox(height: 6),

          // 3. Daily Trip Cards List
          Expanded(
            child: RefreshIndicator(
              color: AppColors.softRose,
              onRefresh: () => _loadHistory(forceRefresh: true),
              child: groupedDays.isEmpty
                  ? _buildEmptyState(context, isMyLocations, isFiltered: _selectedDateFilter != null)
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        MediaQuery.of(context).padding.bottom + 28,
                      ),
                      itemCount: groupedDays.length,
                      itemBuilder: (context, index) {
                        final date = groupedDays.keys.elementAt(index);
                        final dayLocations = groupedDays[date]!;
                        return _buildDayTripCard(
                          context,
                          date: date,
                          locations: dayLocations,
                          isMyRoute: isMyLocations,
                          provider: provider,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: accentColor.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : Colors.grey.shade500,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilters(BuildContext context) {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'All Days',
            icon: Icons.all_inclusive_rounded,
            isSelected: _selectedDateFilter == null,
            onTap: () => setState(() => _selectedDateFilter = null),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Today',
            icon: Icons.today_rounded,
            isSelected: _selectedDateFilter != null && _isSameDay(_selectedDateFilter!, now),
            onTap: () => setState(() => _selectedDateFilter = now),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Yesterday',
            icon: Icons.history_toggle_off_rounded,
            isSelected: _selectedDateFilter != null &&
                _isSameDay(_selectedDateFilter!, now.subtract(const Duration(days: 1))),
            onTap: () => setState(() => _selectedDateFilter = now.subtract(const Duration(days: 1))),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: _selectedDateFilter != null &&
                    !_isSameDay(_selectedDateFilter!, now) &&
                    !_isSameDay(_selectedDateFilter!, now.subtract(const Duration(days: 1)))
                ? DateFormat('MMM d').format(_selectedDateFilter!)
                : 'Pick Date',
            icon: Icons.calendar_month_rounded,
            isSelected: _selectedDateFilter != null &&
                !_isSameDay(_selectedDateFilter!, now) &&
                !_isSameDay(_selectedDateFilter!, now.subtract(const Duration(days: 1))),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDateFilter ?? now,
                firstDate: now.subtract(const Duration(days: 60)),
                lastDate: now,
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
                setState(() => _selectedDateFilter = picked);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.softRose
              : (isDark ? const Color(0xFF221A30) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.softRose
                : (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFEBE6F2)),
            width: 1.2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.softRose.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13.5,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayTripCard(
    BuildContext context, {
    required DateTime date,
    required List<LocationModel> locations,
    required bool isMyRoute,
    required LocationProvider provider,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalKm = _calculateTotalDistance(locations);
    final startTime = locations.first.formattedTime;
    final endTime = locations.last.formattedTime;
    final dateKey = '${date.year}-${date.month}-${date.day}';
    final isCardCollapsed = _collapsedCards.contains(dateKey);
    final isExpanded = _expandedDays.contains(dateKey);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E172B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? AppColors.softRose.withValues(alpha: 0.22)
              : const Color(0xFFEDE8F5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.softRose.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Card Top Bar (Date Title + Collapse toggle + "Play on Map" Action Button)
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                if (isCardCollapsed) {
                  _collapsedCards.remove(dateKey);
                } else {
                  _collapsedCards.add(dateKey);
                }
              });
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.softRose.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      color: AppColors.softRose,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _formatDateTitle(date),
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.deepCharcoal,
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isCardCollapsed
                                  ? Icons.keyboard_arrow_down_rounded
                                  : Icons.keyboard_arrow_up_rounded,
                              color: Colors.grey.shade400,
                              size: 18,
                            ),
                          ],
                        ),
                        Text(
                          totalKm > 0
                              ? '${totalKm.toStringAsFixed(1)} km • ${locations.length} points'
                              : '${locations.length} points recorded',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Glowing "Play Route" Action Button
                  GestureDetector(
                    onTap: () => _launchMapPlayback(date, isMyRoute, provider),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.softRose, Color(0xFFE57388)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.softRose.withValues(alpha: 0.45),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 3),
                          Text(
                            'Play Route',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Body (Metrics Strip + Mini Map Preview + Stop Timeline)
          if (!isCardCollapsed) ...[
            // 2. Trip Metrics Summary Strip
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : const Color(0xFFF7F5FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricItem(
                    icon: Icons.timeline_rounded,
                    label: 'Distance',
                    value: totalKm > 0 ? '${totalKm.toStringAsFixed(1)} km' : '< 1 km',
                    color: AppColors.softRose,
                  ),
                  Container(width: 1, height: 24, color: Colors.grey.withValues(alpha: 0.2)),
                  _buildMetricItem(
                    icon: Icons.access_time_rounded,
                    label: 'Active Times',
                    value: '$startTime - $endTime',
                    color: AppColors.lavender,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 3. Mini Map Route Preview
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFEBE6F2),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _buildMapPreview(locations, isMyRoute),
                ),
              ),
            ),

            // 4. Collapsible Timeline Accordion
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        if (isExpanded) {
                          _expandedDays.remove(dateKey);
                        } else {
                          _expandedDays.add(dateKey);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isExpanded ? 'Hide Stop Details' : 'View Stop Details (${locations.length})',
                            style: const TextStyle(
                              color: AppColors.softRose,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: AppColors.softRose,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (isExpanded) ...[
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    ...locations.map((loc) => _buildStopTimelineItem(loc, isDark)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.deepCharcoal,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMapPreview(List<LocationModel> locations, bool isMyRoute) {
    final points = locations.map((l) => LatLng(l.latitude, l.longitude)).toList();
    final bounds = LatLngBounds.fromPoints(points);

    return FlutterMap(
      options: MapOptions(
        initialCenter: bounds.center,
        initialZoom: 13,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: MapboxService().getStreetsTileUrl(),
          userAgentPackageName: 'com.jayiennelink.app',
          maxNativeZoom: 18,
          maxZoom: 22,
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              strokeWidth: 4.0,
              color: isMyRoute ? AppColors.softRose : AppColors.lavender,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            if (points.isNotEmpty)
              Marker(
                point: points.first,
                width: 22,
                height: 22,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00E676),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            if (points.length > 1)
              Marker(
                point: points.last,
                width: 24,
                height: 24,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isMyRoute ? AppColors.softRose : AppColors.lavender,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.flag_rounded, color: Colors.white, size: 12),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStopTimelineItem(LocationModel loc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.softRose,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            loc.formattedTime,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.deepCharcoal,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          if (loc.speed != null && loc.speed! > 0)
            Text(
              '${(loc.speed! * 3.6).toStringAsFixed(0)} km/h',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
            ),
          const Spacer(),
          if (loc.batteryLevel != null)
            Row(
              children: [
                Icon(
                  Icons.battery_5_bar_rounded,
                  size: 13,
                  color: Colors.greenAccent.shade700,
                ),
                const SizedBox(width: 2),
                Text(
                  '${loc.batteryLevel}%',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isMyLocations, {
    bool isFiltered = false,
  }) {
    final title = isFiltered
        ? 'No locations recorded on this date'
        : isMyLocations
            ? 'No location history recorded yet'
            : 'No location history from your person yet';

    final subtitle = isFiltered
        ? 'Try selecting another day from the filter pills above.'
        : isMyLocations
            ? 'As you move with the app open, your travel routes will appear here!'
            : 'When your person shares their location, their history will sync automatically.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.softRose.withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.explore_off_rounded,
                size: 48,
                color: AppColors.softRose,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteHistory(
    BuildContext context,
    LocationProvider provider,
  ) async {
    HapticFeedback.heavyImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1C1427) : Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5252), Color(0xFFD81B60)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Clear Location History?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.deepCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will permanently delete all your recorded local location trails.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SecondaryCancelButton(
                    label: 'Cancel',
                    height: 42,
                    borderRadius: 12,
                    fontSize: 13.5,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TimedDestructiveButton(
                    label: 'Delete',
                    icon: Icons.delete_outline_rounded,
                    countdownSeconds: 5,
                    height: 42,
                    borderRadius: 12,
                    fontSize: 13.5,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await provider.deleteAllHistory();
      if (context.mounted) {
        SnackbarHelper.showSuccess(
          context,
          'Location history cleared',
        );
      }
    }
  }
}
