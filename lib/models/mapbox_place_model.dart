import 'package:latlong2/latlong.dart';

/// Structured Mapbox Place Model for Search Suggestions & Geocoding
class MapboxPlace {
  final String id;
  final String text; // e.g. "Starbucks", "Ayala Mall", "Greenbelt"
  final String placeName; // e.g. "Starbucks, Makati Avenue, Makati, Metro Manila, Philippines"
  final LatLng coordinates;
  final String? placeType; // e.g. "poi", "address", "neighborhood", "place"
  final String? address;

  const MapboxPlace({
    required this.id,
    required this.text,
    required this.placeName,
    required this.coordinates,
    this.placeType,
    this.address,
  });

  factory MapboxPlace.fromJson(Map<String, dynamic> json) {
    final center = (json['center'] as List<dynamic>?) ?? [0.0, 0.0];
    final lng = (center[0] as num).toDouble();
    final lat = (center[1] as num).toDouble();

    final placeTypes = (json['place_type'] as List<dynamic>?) ?? [];
    final firstType = placeTypes.isNotEmpty ? placeTypes.first.toString() : null;

    return MapboxPlace(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      placeName: json['place_name'] ?? '',
      coordinates: LatLng(lat, lng),
      placeType: firstType,
      address: json['address']?.toString(),
    );
  }

  /// Returns a clean subtitle (e.g. without duplicate title)
  String get subtitle {
    if (placeName.startsWith(text) && placeName.length > text.length) {
      final sub = placeName.substring(text.length).trim();
      return sub.startsWith(',') ? sub.substring(1).trim() : sub;
    }
    return placeName;
  }
}
