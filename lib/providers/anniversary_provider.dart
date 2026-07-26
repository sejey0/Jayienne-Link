import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/milestone_model.dart';
import '../services/supabase_milestone_service.dart';

/// Senior Anniversary & Milestone State Provider
/// Manages live ticking time streams, anniversary calculations, milestone timeline, and analytics.
class AnniversaryProvider extends ChangeNotifier {
  final SupabaseMilestoneService _service;
  bool _disposed = false;

  AnniversaryProvider(this._service);

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  // Core State
  DateTime? _anniversaryDate;
  List<MilestoneModel> _milestones = [];
  CoupleStatsModel _coupleStats = const CoupleStatsModel();

  String? _coupleId;
  String? _userId;
  String? _partnerId;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  // Live Timer
  Timer? _tickerTimer;
  DateTime _now = DateTime.now();

  // Getters
  DateTime? get anniversaryDate => _anniversaryDate;
  bool get hasAnniversaryDate => _anniversaryDate != null;
  List<MilestoneModel> get milestones => List.unmodifiable(_milestones);
  CoupleStatsModel get coupleStats => _coupleStats;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  DateTime get now => _now;

  // ==========================
  // LIVE TIME DURATION CALCULATIONS
  // ==========================

  /// Total days together since anniversary date
  int get totalDaysTogether {
    if (_anniversaryDate == null) return 0;
    return _now.difference(_anniversaryDate!).inDays;
  }

  /// Formatted live breakdown: Years, Months, Days
  int get yearsTogether {
    if (_anniversaryDate == null) return 0;
    int years = _now.year - _anniversaryDate!.year;
    if (_now.month < _anniversaryDate!.month ||
        (_now.month == _anniversaryDate!.month && _now.day < _anniversaryDate!.day)) {
      years--;
    }
    return years < 0 ? 0 : years;
  }

  int get monthsTogether {
    if (_anniversaryDate == null) return 0;
    int months = (_now.year - _anniversaryDate!.year) * 12 + (_now.month - _anniversaryDate!.month);
    if (_now.day < _anniversaryDate!.day) {
      months--;
    }
    return months % 12;
  }

  int get daysTogetherRemainder {
    if (_anniversaryDate == null) return 0;
    final lastMonthAnniversary = DateTime(_now.year, _now.month, _anniversaryDate!.day);
    if (_now.isAfter(lastMonthAnniversary)) {
      return _now.difference(lastMonthAnniversary).inDays;
    } else {
      final prevMonthDate = DateTime(_now.year, _now.month - 1, _anniversaryDate!.day);
      return _now.difference(prevMonthDate).inDays;
    }
  }

  int get hoursTogetherRemainder => _now.difference(_anniversaryDate ?? _now).inHours % 24;
  int get minutesTogetherRemainder => _now.difference(_anniversaryDate ?? _now).inMinutes % 60;
  int get secondsTogetherRemainder => _now.difference(_anniversaryDate ?? _now).inSeconds % 60;

  // ==========================
  // NEXT ANNIVERSARY COUNTDOWN METRICS
  // ==========================

  /// Target date of next upcoming anniversary
  DateTime? get nextAnniversaryDate {
    if (_anniversaryDate == null) return null;

    final thisYearAnniversary = DateTime(
      _now.year,
      _anniversaryDate!.month,
      _anniversaryDate!.day,
    );

    if (_now.isBefore(thisYearAnniversary)) {
      return thisYearAnniversary;
    } else {
      return DateTime(_now.year + 1, _anniversaryDate!.month, _anniversaryDate!.day);
    }
  }

  /// Days remaining until next anniversary milestone
  int get daysUntilNextAnniversary {
    final next = nextAnniversaryDate;
    if (next == null) return 0;
    return next.difference(_now).inDays;
  }

  /// The milestone year number coming up (e.g. 2nd Anniversary)
  int get nextAnniversaryYearNumber {
    if (_anniversaryDate == null) return 1;
    final next = nextAnniversaryDate;
    if (next == null) return 1;
    return next.year - _anniversaryDate!.year;
  }

  /// Progress fraction (0.0 to 1.0) toward next annual anniversary milestone
  double get progressToNextAnniversary {
    if (_anniversaryDate == null) return 0.0;
    final next = nextAnniversaryDate!;
    final prev = DateTime(next.year - 1, _anniversaryDate!.month, _anniversaryDate!.day);

    final totalDaysInYear = next.difference(prev).inDays;
    final elapsedDays = _now.difference(prev).inDays;

    if (totalDaysInYear <= 0) return 0.0;
    return (elapsedDays / totalDaysInYear).clamp(0.0, 1.0);
  }

  // ==========================
  // INITIALIZATION & LIFECYCLE
  // ==========================

  Future<void> initialize({
    required String coupleId,
    required String userId,
    String? partnerId,
    DateTime? initialAnniversaryDate,
  }) async {
    _coupleId = coupleId;
    _userId = userId;
    _partnerId = partnerId;
    if (initialAnniversaryDate != null) {
      _anniversaryDate = initialAnniversaryDate;
    }

    _startLiveTicker();
    await refreshAll();
  }

  void _startLiveTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      _now = DateTime.now();
      notifyListeners();
    });
  }

  Future<void> refreshAll() async {
    if (_coupleId == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Fetch anniversary date from database
      final dateFromDb = await _service.fetchAnniversaryDate(_coupleId!);
      if (dateFromDb != null) {
        _anniversaryDate = dateFromDb;
      }

      // 2. Fetch memory timeline milestones
      _milestones = await _service.getMilestones(_coupleId!);

      // 3. Fetch couple statistics
      _coupleStats = await _service.fetchCoupleStats(
        _coupleId!,
        userId: _userId,
        partnerId: _partnerId,
      );
    } catch (e) {
      _error = 'Failed to load relationship milestones: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update official couple anniversary date
  Future<bool> setAnniversaryDate(DateTime date) async {
    if (_coupleId == null) return false;
    _isSaving = true;
    notifyListeners();

    final success = await _service.updateAnniversaryDate(_coupleId!, date);
    if (success) {
      _anniversaryDate = date;
    } else {
      _error = 'Failed to save anniversary date.';
    }

    _isSaving = false;
    notifyListeners();
    return success;
  }

  /// Add new relationship milestone entry
  Future<bool> addMilestone({
    required String title,
    String? description,
    required MilestoneCategory category,
    required DateTime eventDate,
    File? imageFile,
  }) async {
    if (_coupleId == null || _userId == null) {
      throw Exception('Couple ID or User ID is missing.');
    }
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final newMilestone = MilestoneModel(
        coupleId: _coupleId!,
        createdById: _userId!,
        title: title,
        description: description,
        category: category,
        eventDate: eventDate,
      );

      final created = await _service.addMilestone(
        milestone: newMilestone,
        imageFile: imageFile,
      );

      if (created != null) {
        _milestones.insert(0, created);
        _milestones.sort((a, b) => b.eventDate.compareTo(a.eventDate));
        _isSaving = false;
        notifyListeners();
        return true;
      } else {
        throw Exception('Failed to insert milestone record into database.');
      }
    } catch (e) {
      _error = e.toString();
      _isSaving = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Delete milestone entry
  Future<bool> deleteMilestone(String milestoneId) async {
    final success = await _service.deleteMilestone(milestoneId);
    if (success) {
      _milestones.removeWhere((m) => m.id == milestoneId);
      notifyListeners();
    }
    return success;
  }

  @override
  void dispose() {
    _disposed = true;
    _tickerTimer?.cancel();
    super.dispose();
  }
}
