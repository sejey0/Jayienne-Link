import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/couple_model.dart';
import '../services/supabase_couple_service.dart';

class CoupleProvider extends ChangeNotifier {
  final SupabaseCoupleService _coupleService;

  CoupleModel? _couple;
  String? _inviteCode;
  DateTime? _codeExpiresAt;
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _coupleSubscription;

  CoupleProvider(this._coupleService);

  CoupleModel? get couple => _couple;
  String? get inviteCode => _inviteCode;
  DateTime? get codeExpiresAt => _codeExpiresAt;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLinked => _couple != null;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> generateCode(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _inviteCode = await _coupleService.generateAndStoreInviteCode(userId);
      _codeExpiresAt = DateTime.now().add(const Duration(hours: 48));
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to generate invite code: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> regenerateCode(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _inviteCode = await _coupleService.regenerateInviteCode(
        userId,
        _inviteCode,
      );
      _codeExpiresAt = DateTime.now().add(const Duration(hours: 48));
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to regenerate invite code.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> redeemCode(String code, String currentUserId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _couple = await _coupleService.linkCouple(code, currentUserId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void loadCouple(String coupleId) {
    _coupleSubscription?.cancel();
    _coupleSubscription =
        _coupleService.coupleStream(coupleId).listen((couple) {
      _couple = couple;
      notifyListeners();
    });
  }

  /// Clears all couple data (call when signing out or switching accounts)
  void clear() {
    _coupleSubscription?.cancel();
    _coupleSubscription = null;
    _couple = null;
    _inviteCode = null;
    _codeExpiresAt = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Loads the existing invite code for a user from Supabase
  Future<void> loadExistingCode(String? code) async {
    if (code == null) return;
    if (code == 'SKIPPED') {
      _inviteCode = null;
      _codeExpiresAt = null;
      notifyListeners();
      return;
    }
    _inviteCode = code;

    try {
      final inviteCodeModel = await _coupleService.getInviteCode(code);
      if (inviteCodeModel != null && inviteCodeModel.isValid) {
        _codeExpiresAt = inviteCodeModel.expiresAt;
      } else {
        // Code expired or used, clear it
        _inviteCode = null;
        _codeExpiresAt = null;
      }
    } catch (_) {
      _inviteCode = null;
      _codeExpiresAt = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _coupleSubscription?.cancel();
    super.dispose();
  }
}
