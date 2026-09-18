import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/sex_position_model.dart';

class SexPositionsService {
  static final SexPositionsService _instance = SexPositionsService._internal();
  factory SexPositionsService() => _instance;
  SexPositionsService._internal();

  List<SexPositionModel> _positions = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<SexPositionModel> get positions => List.unmodifiable(_positions);

  /// Load positions from the bundled assets/data/sex_positions.json
  Future<List<SexPositionModel>> loadPositions() async {
    if (_isLoaded && _positions.isNotEmpty) {
      return _positions;
    }

    try {
      final jsonString = await rootBundle.loadString('assets/data/sex_positions.json');
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;

      _positions = jsonList
          .map((item) => SexPositionModel.fromJson(item as Map<String, dynamic>))
          .toList();

      _isLoaded = true;
      debugPrint('[SexPositionsService] Successfully loaded ${_positions.length} positions');
    } catch (e) {
      debugPrint('[SexPositionsService] Error loading sex positions: $e');
      _positions = [];
    }

    return _positions;
  }

  /// Get distinct categories (e.g. Missionary, Cowgirl, Doggystyle, Spoons, Lotus, etc.)
  List<String> getCategories() {
    final cats = _positions.map((p) => p.category.trim()).where((c) => c.isNotEmpty).toSet().toList();
    cats.sort();
    return ['All', ...cats];
  }

  /// Filter positions by category
  List<SexPositionModel> getPositionsByCategory(String category) {
    if (category == 'All' || category.trim().isEmpty) {
      return List.unmodifiable(_positions);
    }
    return _positions.where((p) => p.category.trim().toLowerCase() == category.trim().toLowerCase()).toList();
  }

  /// Get a random subset of positions (default 8) for the spinner wheel slices
  List<SexPositionModel> getRandomSliceSelection({String? category, int count = 8}) {
    final pool = (category == null || category == 'All')
        ? List<SexPositionModel>.from(_positions)
        : getPositionsByCategory(category);

    if (pool.isEmpty) return [];

    pool.shuffle();
    if (pool.length <= count) return pool;
    return pool.take(count).toList();
  }

  /// Search positions by name or description
  List<SexPositionModel> searchPositions(String query, {String? category}) {
    final pool = getPositionsByCategory(category ?? 'All');
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return pool;

    return pool.where((p) {
      final nameMatches = p.name.toLowerCase().contains(q);
      final descMatches = p.description.toLowerCase().contains(q);
      final catMatches = p.category.toLowerCase().contains(q);
      return nameMatches || descMatches || catMatches;
    }).toList();
  }

  /// Find position by exact or partial name
  SexPositionModel? findByName(String name) {
    if (_positions.isEmpty) return null;
    final lower = name.trim().toLowerCase();
    try {
      return _positions.firstWhere((p) => p.name.trim().toLowerCase() == lower);
    } catch (_) {
      try {
        return _positions.firstWhere((p) => p.name.trim().toLowerCase().contains(lower));
      } catch (_) {
        return null;
      }
    }
  }
}
