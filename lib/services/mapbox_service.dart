import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/mapbox_place_model.dart';

/// Premium Mapbox Service for Search Autocomplete, Geocoding, and High-Resolution Raster Tiles
class MapboxService {
  static final MapboxService _instance = MapboxService._internal();
  factory MapboxService() => _instance;
  MapboxService._internal();

  /// Retrieve token from .env
  String get accessToken => dotenv.env['MAPBOX_ACCESS_TOKEN']?.trim() ?? '';

  bool get hasToken => accessToken.isNotEmpty;

  // -------------------------------------------------------------
  // Map Tile URL Providers
  // -------------------------------------------------------------

  /// Mapbox Satellite Streets Hybrid (High-Res 512px @2x)
  String getSatelliteTileUrl() {
    if (hasToken) {
      return 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$accessToken';
    }
    // High-res ArcGIS Satellite Imagery fallback
    return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  }

  /// Mapbox Standard Streets
  String getStreetsTileUrl() {
    if (hasToken) {
      return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$accessToken';
    }
    // Standard OpenStreetMap fallback
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  /// Mapbox Dark Navigation (Romantic Midnight)
  String getDarkTileUrl() {
    if (hasToken) {
      return 'https://api.mapbox.com/styles/v1/mapbox/navigation-night-v1/tiles/256/{z}/{x}/{y}@2x?access_token=$accessToken';
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  // -------------------------------------------------------------
  // Mapbox Places Search & Autocomplete API (100,000 free/month)
  // -------------------------------------------------------------

  /// Searches locations, brand names, stores, and addresses with auto-complete
  Future<List<MapboxPlace>> searchPlaces(
    String query, {
    LatLng? proximity,
    int limit = 6,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    if (!hasToken) {
      debugPrint('[MapboxService] Warning: MAPBOX_ACCESS_TOKEN is not configured in .env');
      return [];
    }

    try {
      final encodedQuery = Uri.encodeComponent(cleanQuery);
      var url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
          '?access_token=$accessToken'
          '&autocomplete=true'
          '&limit=$limit'
          '&types=poi,address,neighborhood,place,locality';

      if (proximity != null) {
        url += '&proximity=${proximity.longitude},${proximity.latitude}';
      }

      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 8),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];
        return features.map((f) => MapboxPlace.fromJson(f as Map<String, dynamic>)).toList();
      } else {
        debugPrint('[MapboxService] Search error: HTTP ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('[MapboxService] Search exception: $e');
      return [];
    }
  }

  /// Reverse geocodes a (lat, lng) to get place address
  Future<String?> reverseGeocode(double lat, double lng) async {
    if (!hasToken) return null;

    try {
      final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json'
          '?access_token=$accessToken'
          '&types=address,poi,place,neighborhood'
          '&limit=1';

      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 6),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];
        if (features.isNotEmpty) {
          return features.first['place_name'] as String?;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[MapboxService] Reverse geocode exception: $e');
      return null;
    }
  }
}
