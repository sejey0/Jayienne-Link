import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service that connects live to the web (Wikipedia API & Open Web) to fetch
/// dynamic, super-random authentic Filipino culture suggestions for food & date activities.
class OnlineFilipinoSuggestionService {
  static final Random _random = Random();

  static const List<String> _foodSearchQueries = [
    'Philippine cuisine dishes',
    'Philippine street food',
    'Filipino delicacies',
    'Kapampangan cuisine dishes',
    'Ilocano food dishes',
    'Bicol cuisine dishes',
    'Cebuano food specialties',
    'Philippine desserts kakanin',
    'Filipino noodle dishes pancit',
    'Philippine soup dishes sinigang nilaga',
    'Philippine grilled food inasal barbecue',
  ];

  static const List<String> _activitySearchQueries = [
    'Tourist attractions in the Philippines',
    'Parks in Metro Manila Philippines',
    'Museums in the Philippines',
    'Islands of the Philippines tourism',
    'Landmarks in the Philippines',
    'Historical shrines in the Philippines',
    'Theme parks and recreation in the Philippines',
    'Beaches and resorts in the Philippines',
    'Heritage sites in the Philippines',
    'Nature reserves in the Philippines',
  ];

  // Ignored non-actionable or generic titles
  static const Set<String> _ignoredTitles = {
    'Philippine cuisine',
    'Cuisine of the Philippines',
    'Philippines',
    'Filipino people',
    'Culture of the Philippines',
    'History of the Philippines',
    'Tourism in the Philippines',
    'List of Philippine dishes',
    'List of tourist attractions in the Philippines',
    'Metro Manila',
    'Luzon',
    'Visayas',
    'Mindanao',
    'Geography of the Philippines',
  };

  /// Fetches a super random Filipino culture suggestion live from the web.
  static Future<String> fetchRandomOnlineSuggestion({
    required bool isFood,
  }) async {
    final queries = isFood ? _foodSearchQueries : _activitySearchQueries;
    final query = queries[_random.nextInt(queries.length)];
    final offset = _random.nextInt(4) * 10; // 0, 10, 20, 30 offset for diversity

    final url = Uri.parse(
      'https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch='
      '${Uri.encodeComponent(query)}&sroffset=$offset&srlimit=20&format=json',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'JayienneLinkCoupleApp/1.0 (filipino_decision_spinner)',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final queryObj = data['query'] as Map<String, dynamic>?;
        final searchResults = queryObj?['search'] as List<dynamic>?;

        if (searchResults != null && searchResults.isNotEmpty) {
          final candidates = <String>[];
          for (final item in searchResults) {
            final title = item['title']?.toString().trim() ?? '';
            if (title.isNotEmpty &&
                !_ignoredTitles.contains(title) &&
                !title.startsWith('List of') &&
                !title.startsWith('Category:')) {
              // Clean up title (remove brackets, parenthetical disambiguations)
              final cleanTitle = title
                  .replaceAll(RegExp(r'\s*\(.*?\)\s*'), '')
                  .trim();
              if (cleanTitle.isNotEmpty && !candidates.contains(cleanTitle)) {
                candidates.add(cleanTitle);
              }
            }
          }

          if (candidates.isNotEmpty) {
            final picked = candidates[_random.nextInt(candidates.length)];
            return picked;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching live online Filipino suggestion: $e');
    }

    // Dynamic offline fallback if device is disconnected
    return _getRandomOfflineFallback(isFood: isFood);
  }

  static String _getRandomOfflineFallback({required bool isFood}) {
    if (isFood) {
      const fallbacks = [
        'Crispy Sisig with Egg',
        'Sinigang na Baboy',
        'Beef Pares Retiro & Mami',
        'Chicken Inasal with Garlic Rice',
        'Kare-Kareng Baka with Bagoong',
        'Lechon Kawali with Mang Tomas',
        'Halo-Halo with Ube Ice Cream',
        'Binondo Street Food Crawl',
        'Tusok-Tusok Isaw & Kwek-Kwek',
        'Pampanga Sizzling Bulalo',
        'Cebu Lechon Belly',
        'Bacolod Cansi Soup',
      ];
      return fallbacks[_random.nextInt(fallbacks.length)];
    } else {
      const fallbacks = [
        'Intramuros Historic Bambike Tour',
        'Sunset Walk in Seaside Baywalk',
        'Pinto Art Museum Antipolo Stroll',
        'Tagaytay Ridge Coffee & Overlook',
        'BGC High Street Picnic & Photobooth',
        'Cubao Expo Vintage & Vinyl Hunt',
        'National Museum of Fine Arts Date',
        'Night Drive to Antipolo Cloud 9',
        'Videoke & Karaoke Showdown Night',
        'Escolta Heritage & Coffee Walk',
        'Binondo Chinatown Hop & Lucky Charms',
        'Ukay-Ukay Thrift Challenge Together',
      ];
      return fallbacks[_random.nextInt(fallbacks.length)];
    }
  }
}
