import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../models/location_model.dart';
import '../../../providers/location_provider.dart';
import '../../../widgets/common/app_card.dart';
import '../widgets/offline_status_indicator.dart';

/// Timeline view of location history showing synced/offline periods.
class LocationHistoryScreen extends StatefulWidget {
  const LocationHistoryScreen({super.key});

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final provider = context.read<LocationProvider>();
    await provider.loadLocationHistory();
    await provider.loadPartnerLocationHistory();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location History'),
        actions: [
          const OfflineStatusIndicator(),
          const SizedBox(width: AppDimensions.spacingSm),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
            tooltip: 'Select date',
          ),
          PopupMenuButton<String>(
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
          tabs: const [
            Tab(text: 'My Locations'),
            Tab(text: 'Your Person'),
          ],
        ),
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
    if (locations.isEmpty) {
      return _buildEmptyState(context, isMyLocations);
    }

    // Group locations by date
    final grouped = _groupByDate(locations);

    return RefreshIndicator(
      onRefresh: _loadHistory,
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
              ...dayLocations.map((loc) => _buildTimelineItem(context, loc)),
              const SizedBox(height: AppDimensions.spacingMd),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isMyLocations) {
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
              isMyLocations
                  ? 'No location history yet'
                  : 'No locations from your person yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              isMyLocations
                  ? 'Enable location sharing to start tracking'
                  : 'Waiting for your person to share their location',
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

  Widget _buildTimelineItem(BuildContext context, LocationModel location) {
    final isSynced = location.isSynced;
    final isOfflineCapture = location.source == LocationSource.background;

    return Padding(
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
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
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
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.lavender,
                                  ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        fontFamily: 'monospace',
                      ),
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
          // Heart icon for significant locations
          Icon(
            Icons.favorite_border,
            color: Colors.grey.shade300,
            size: 18,
          ),
        ],
      ),
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
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
      // TODO: Filter history by selected date
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location history deleted')),
        );
      }
    }
  }
}
