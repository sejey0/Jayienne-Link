import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/location_model.dart';
import '../../../providers/location_provider.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/smart_profile_image.dart';
import '../widgets/offline_status_indicator.dart';

/// Timeline view of location history showing synced/offline periods.
class LocationHistoryScreen extends StatefulWidget {
  final int initialTab;

  const LocationHistoryScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory({bool forceRefresh = false}) async {
    final provider = context.read<LocationProvider>();
    await provider.loadLocationHistory(forceRefresh: forceRefresh);
    await provider.loadPartnerLocationHistory();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Location History',
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
          const OfflineStatusIndicator(),
          const SizedBox(width: AppDimensions.spacingSm),
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () {
              HapticFeedback.lightImpact();
              _selectDate(context);
            },
            tooltip: 'Select date',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDeleteHistory(context, provider);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Delete all history'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'My Locations'),
            Tab(text: 'Your Person'),
          ],
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHistoryList(context, provider.locationHistory, true),
                _buildHistoryList(
                  context,
                  provider.partnerLocationHistory,
                  false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(
    BuildContext context,
    List<LocationModel> locations,
    bool isMyLocations,
  ) {
    final filteredLocations = _filterLocationsByDate(locations);

    if (filteredLocations.isEmpty) {
      return _buildEmptyState(
        context,
        isMyLocations,
        isFiltered: _selectedDate != null,
      );
    }

    // Group locations by date
    final grouped = _groupByDate(filteredLocations);

    return RefreshIndicator(
      onRefresh: () => _loadHistory(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final date = grouped.keys.elementAt(index);
          final dayLocations = grouped[date]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.spacingMd,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingSm,
                        vertical: AppDimensions.spacingXs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lavender.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.borderRadiusSmall,
                        ),
                      ),
                      child: Text(
                        _formatDate(date),
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.lavender,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Text(
                      '${dayLocations.length} locations',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
              // Map preview for the day
              _buildDayMapPreview(context, dayLocations, isMyLocations),
              const SizedBox(height: AppDimensions.spacingSm),
              // Timeline
              ...dayLocations.map(
                (loc) => _buildTimelineItem(context, loc, isMyLocations),
              ),
              const SizedBox(height: AppDimensions.spacingMd),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isMyLocations, {
    bool isFiltered = false,
  }) {
    final title = isFiltered
        ? 'No locations on this date'
        : isMyLocations
            ? 'No location history yet'
            : 'No locations from your person yet';
    final subtitle = isFiltered
        ? 'Try another date to see saved locations'
        : isMyLocations
            ? 'Enable location sharing to start tracking'
            : 'Waiting for your person to share their location';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayMapPreview(
    BuildContext context,
    List<LocationModel> locations,
    bool isMyLocations,
  ) {
    if (locations.isEmpty) return const SizedBox.shrink();

    // Create route points
    final points = locations
        .map((loc) => LatLng(loc.latitude, loc.longitude))
        .toList()
        .reversed
        .toList();

    // Calculate bounds
    final bounds = LatLngBounds.fromPoints(points);

    return AppCard(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
        child: SizedBox(
          height: 150,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: bounds.center,
              initialZoom: 13,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.jayiennelink.app',
              ),
              // Route line
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: 3,
                    color:
                        isMyLocations ? AppColors.lavender : AppColors.softRose,
                  ),
                ],
              ),
              // Markers at start and end
              MarkerLayer(
                markers: [
                  // Start marker
                  if (points.isNotEmpty)
                    Marker(
                      point: points.first,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.success,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  // End marker
                  if (points.length > 1)
                    Marker(
                      point: points.last,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isMyLocations
                              ? AppColors.lavender
                              : AppColors.softRose,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.flag,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    LocationModel location,
    bool isMyLocations,
  ) {
    final isSynced = location.isSynced;
    final isOfflineCapture = location.source == LocationSource.background;

    return InkWell(
      onTap: () => _showLocationOnMap(context, location, isMyLocations),
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSmall),
      child: Padding(
        padding: const EdgeInsets.only(left: AppDimensions.spacingMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline line and dot
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSynced ? AppColors.success : AppColors.warning,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                ),
                Container(
                  width: 2,
                  height: 40,
                  color: Colors.grey.shade300,
                ),
              ],
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        location.formattedTime,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(width: AppDimensions.spacingSm),
                      if (!isSynced)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Pending sync',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppColors.warning,
                                ),
                          ),
                        ),
                      if (isOfflineCapture)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lavender.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Background',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppColors.lavender,
                                ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.lavender,
                                    fontFamily: 'monospace',
                                    decoration: TextDecoration.underline,
                                  ),
                        ),
                      ),
                      const Icon(
                        Icons.map_outlined,
                        color: AppColors.lavender,
                        size: 16,
                      ),
                    ],
                  ),
                  Text(
                    'Accuracy: ${location.accuracy.toStringAsFixed(1)}m',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade400,
                        ),
                  ),
                ],
              ),
            ),
            // Tap to view on map indicator
            const Icon(
              Icons.chevron_right,
              color: AppColors.lavender,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Show a specific location on a map in a bottom sheet
  void _showLocationOnMap(
    BuildContext context,
    LocationModel location,
    bool isMyLocations,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final provider = context.watch<LocationProvider>();
        final currentUser = provider.currentUser;
        final partnerUser = provider.partnerUser;

        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.borderRadiusLarge),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingMd),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.softRose),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location.formattedTime,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                      fontFamily: 'monospace',
                                    ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: AppDimensions.spacingMd,
                  right: AppDimensions.spacingMd,
                  bottom: AppDimensions.spacingSm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildProfileAvatar(
                      context,
                      label: 'You',
                      photoUrl: currentUser?.photoUrl,
                      accentColor: AppColors.lavender,
                      fallbackIcon: Icons.person,
                      isHighlighted: isMyLocations,
                    ),
                    const SizedBox(width: AppDimensions.spacingLg),
                    _buildProfileAvatar(
                      context,
                      label: 'Your Person',
                      photoUrl: partnerUser?.photoUrl,
                      accentColor: AppColors.softRose,
                      fallbackIcon: Icons.favorite,
                      isHighlighted: !isMyLocations,
                    ),
                  ],
                ),
              ),
              // Map
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(AppDimensions.borderRadiusLarge),
                  ),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter:
                          LatLng(location.latitude, location.longitude),
                      initialZoom: 16,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.jayiennelink.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point:
                                LatLng(location.latitude, location.longitude),
                            width: 38,
                            height: 38,
                            child: _buildSingleMapMarker(
                              photoUrl: isMyLocations
                                  ? currentUser?.photoUrl
                                  : partnerUser?.photoUrl,
                              accentColor: isMyLocations
                                  ? AppColors.lavender
                                  : AppColors.softRose,
                              fallbackIcon:
                                  isMyLocations ? Icons.person : Icons.favorite,
                              size: 38,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Info bar
              Container(
                padding: const EdgeInsets.all(AppDimensions.spacingMd),
                decoration: BoxDecoration(
                  color: AppColors.lavender.withOpacity(0.1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoItem(
                      context,
                      Icons.gps_fixed,
                      'Accuracy',
                      '${location.accuracy.toStringAsFixed(1)}m',
                    ),
                    _buildInfoItem(
                      context,
                      location.isSynced ? Icons.cloud_done : Icons.cloud_off,
                      'Status',
                      location.isSynced ? 'Synced' : 'Pending',
                    ),
                    _buildInfoItem(
                      context,
                      Icons.schedule,
                      'Time',
                      location.timeAgo,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileAvatar(
    BuildContext context, {
    required String label,
    required String? photoUrl,
    required Color accentColor,
    required IconData fallbackIcon,
    required bool isHighlighted,
  }) {
    const size = AppDimensions.avatarSizeSmall;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: accentColor.withOpacity(isHighlighted ? 1 : 0.5),
              width: isHighlighted ? 2 : 1,
            ),
          ),
          child: ClipOval(
            child: SmartProfileImage(
              imageUrl: photoUrl,
              width: size,
              height: size,
              placeholder: _buildAvatarPlaceholder(
                size,
                fallbackIcon,
                accentColor,
              ),
              errorWidget: _buildAvatarPlaceholder(
                size,
                fallbackIcon,
                accentColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: accentColor,
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
              ),
        ),
      ],
    );
  }

  Widget _buildSingleMapMarker({
    required String? photoUrl,
    required Color accentColor,
    required IconData fallbackIcon,
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: accentColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.35),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: SmartProfileImage(
          imageUrl: photoUrl,
          width: size,
          height: size,
          placeholder: _buildAvatarPlaceholder(
            size,
            fallbackIcon,
            accentColor,
          ),
          errorWidget: _buildAvatarPlaceholder(
            size,
            fallbackIcon,
            accentColor,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(
    double size,
    IconData icon,
    Color accentColor,
  ) {
    return Container(
      width: size,
      height: size,
      color: accentColor.withOpacity(0.15),
      child: Icon(
        icon,
        color: accentColor,
        size: 20,
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.lavender),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Map<DateTime, List<LocationModel>> _groupByDate(
      List<LocationModel> locations) {
    final Map<DateTime, List<LocationModel>> grouped = {};

    for (final location in locations) {
      final date = DateTime(
        location.timestamp.year,
        location.timestamp.month,
        location.timestamp.day,
      );

      grouped.putIfAbsent(date, () => []).add(location);
    }

    return grouped;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  List<LocationModel> _filterLocationsByDate(List<LocationModel> locations) {
    if (_selectedDate == null) return locations;

    return locations
        .where((location) => _isSameDay(location.timestamp, _selectedDate!))
        .toList();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _confirmDeleteHistory(
    BuildContext context,
    LocationProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Location History?'),
        content: const Text(
          'This will permanently delete all your location history. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.deleteAllHistory();
      if (context.mounted) {
        SnackbarHelper.showSuccess(
          context,
          'Location history deleted',
        );
      }
    }
  }
}
