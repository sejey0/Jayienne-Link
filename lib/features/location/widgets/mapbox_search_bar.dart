import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/mapbox_place_model.dart';
import '../../../services/mapbox_service.dart';

/// Clean Floating Mapbox Autocomplete Search Bar & Suggestions Overlay
/// Designed to blend seamlessly with the app's theme without harsh colored rings or glows.
class MapboxSearchBar extends StatefulWidget {
  final LatLng? userPosition;
  final ValueChanged<MapboxPlace> onPlaceSelected;
  final VoidCallback? onClear;

  const MapboxSearchBar({
    super.key,
    this.userPosition,
    required this.onPlaceSelected,
    this.onClear,
  });

  @override
  State<MapboxSearchBar> createState() => _MapboxSearchBarState();
}

class _MapboxSearchBarState extends State<MapboxSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final MapboxService _mapboxService = MapboxService();

  Timer? _debounceTimer;
  List<MapboxPlace> _suggestions = [];
  bool _isLoading = false;
  bool _isDropdownVisible = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _suggestions.isNotEmpty) {
        setState(() => _isDropdownVisible = true);
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _suggestions = [];
        _isDropdownVisible = false;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    _debounceTimer = Timer(const Duration(milliseconds: 280), () async {
      final results = await _mapboxService.searchPlaces(
        trimmed,
        proximity: widget.userPosition,
        limit: 6,
      );

      if (mounted) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
          _isDropdownVisible = results.isNotEmpty;
        });
      }
    });
  }

  void _selectPlace(MapboxPlace place) {
    HapticFeedback.selectionClick();
    _focusNode.unfocus();
    _searchController.text = place.text;
    setState(() {
      _suggestions = [];
      _isDropdownVisible = false;
    });
    widget.onPlaceSelected(place);
  }

  void _clearSearch() {
    HapticFeedback.lightImpact();
    _searchController.clear();
    _focusNode.unfocus();
    setState(() {
      _suggestions = [];
      _isDropdownVisible = false;
      _isLoading = false;
    });
    widget.onClear?.call();
  }

  IconData _getPlaceIcon(String? type, String text) {
    final lower = text.toLowerCase();
    if (lower.contains('cafe') || lower.contains('coffee') || lower.contains('starbucks')) {
      return Icons.local_cafe_rounded;
    }
    if (lower.contains('mall') || lower.contains('store') || lower.contains('shop') || lower.contains('market')) {
      return Icons.storefront_rounded;
    }
    if (lower.contains('food') || lower.contains('restaurant') || lower.contains('dining') || lower.contains('grill')) {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('hotel') || lower.contains('inn') || lower.contains('resort')) {
      return Icons.hotel_rounded;
    }
    if (lower.contains('hospital') || lower.contains('clinic') || lower.contains('pharmacy')) {
      return Icons.local_hospital_rounded;
    }
    if (type == 'poi') return Icons.place_rounded;
    if (type == 'address') return Icons.navigation_rounded;
    return Icons.location_city_rounded;
  }

  String? _getDistanceText(LatLng target) {
    if (widget.userPosition == null) return null;
    final meters = Geolocator.distanceBetween(
      widget.userPosition!.latitude,
      widget.userPosition!.longitude,
      target.latitude,
      target.longitude,
    );
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000.0).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Clean Search Input Bar (No Glowing Colored Rings or Light Mode Rings)
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF231A33)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isDark
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                    width: 1.0,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                Icons.search_rounded,
                color: isDark ? Colors.white60 : const Color(0xFF6B5F79),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  cursorColor: AppColors.softRose,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    filled: false,
                    fillColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    hintText: 'Search places, cafes, addresses...',
                    hintStyle: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.45)
                          : Colors.grey.shade500,
                      fontSize: 13.5,
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: AppColors.softRose,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  onPressed: _clearSearch,
                ),
              const SizedBox(width: 4),
            ],
          ),
        ),

        // Autocomplete Dropdown List
        if (_isDropdownVisible && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF231A33)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: isDark
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                      width: 1.0,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFF0EBF5),
                ),
                itemBuilder: (context, index) {
                  final place = _suggestions[index];
                  final distance = _getDistanceText(place.coordinates);

                  return InkWell(
                    onTap: () => _selectPlace(place),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFF3ECF8),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getPlaceIcon(place.placeType, place.text),
                              color: isDark ? AppColors.lavender : const Color(0xFF6B63B5),
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  place.text,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  place.subtitle,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.55)
                                        : Colors.grey.shade600,
                                    fontSize: 11.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (distance != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFFF3EDF8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                distance,
                                style: TextStyle(
                                  color: isDark ? AppColors.lavender : const Color(0xFF6B63B5),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
