import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/couple_model.dart';
import '../models/partner_request_model.dart';
import '../models/user_model.dart';
import '../services/supabase_couple_service.dart';
import '../services/supabase_user_service.dart';

class CoupleProvider extends ChangeNotifier {
  final SupabaseCoupleService _coupleService;
  final SupabaseUserService _userService;

  CoupleModel? _couple;
  UserModel? _partner;
  UserModel? _searchResult;
  String? _inviteCode;
  DateTime? _codeExpiresAt;
  bool _isLoading = false;
  bool _isSearching = false;
  String? _error;
  StreamSubscription? _coupleSubscription;
  StreamSubscription<List<PartnerRequestModel>>? _incomingRequestsSubscription;
  StreamSubscription<List<PartnerRequestModel>>? _outgoingRequestsSubscription;
  List<PartnerRequestModel> _incomingRequests = [];
  List<PartnerRequestModel> _outgoingRequests = [];
  String? _requestsUserId;

  CoupleProvider(this._coupleService, this._userService);

  CoupleModel? get couple => _couple;
  UserModel? get partner => _partner;
  UserModel? get searchResult => _searchResult;
  String? get inviteCode => _inviteCode;
  DateTime? get codeExpiresAt => _codeExpiresAt;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get error => _error;
  bool get isLinked => _couple != null;
  List<PartnerRequestModel> get incomingRequests => _incomingRequests;
  List<PartnerRequestModel> get outgoingRequests => _outgoingRequests;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void initializeRequests(String userId) {
    if (_requestsUserId == userId &&
        _incomingRequestsSubscription != null &&
        _outgoingRequestsSubscription != null) {
      return;
    }

    _requestsUserId = userId;
    _incomingRequestsSubscription?.cancel();
    _outgoingRequestsSubscription?.cancel();

    _incomingRequestsSubscription =
        _coupleService.streamIncomingRequests(userId).listen((requests) {
      _incomingRequests = requests;
      notifyListeners();
    });

    _outgoingRequestsSubscription =
        _coupleService.streamOutgoingRequests(userId).listen((requests) {
      _outgoingRequests = requests;
      notifyListeners();
    });
  }

  Future<void> searchUserByEmail(String email, String currentUserId) async {
    _isSearching = true;
    _error = null;
    _searchResult = null;
    notifyListeners();

    try {
      final result = await _userService.getUserByEmail(email.trim());

      if (result == null) {
        _error = 'No user found with that email.';
      } else if (result.id == currentUserId) {
        _error = 'That is your own account.';
      } else {
        _searchResult = result;
      }
    } catch (e) {
      _error = 'Failed to search for user.';
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<bool> sendPartnerRequest({
    required UserModel sender,
    required UserModel receiver,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _coupleService.sendPartnerRequest(
        sender: sender,
        receiver: receiver,
      );
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

  Future<CoupleModel?> acceptPartnerRequest(PartnerRequestModel request) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final couple = await _coupleService.acceptPartnerRequest(request);
      _couple = couple;
      _isLoading = false;
      notifyListeners();
      return couple;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> declinePartnerRequest(String requestId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _coupleService.declinePartnerRequest(requestId);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cancelPartnerRequest(String requestId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _coupleService.cancelPartnerRequest(requestId);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  void loadCouple(String coupleId, String currentUserId) {
    _coupleSubscription?.cancel();
    _coupleSubscription =
        _coupleService.coupleStream(coupleId).listen((couple) async {
      _couple = couple;

      // Also load partner data
      if (couple != null) {
        final partnerId = couple.getPartnerId(currentUserId);
        if (partnerId.isNotEmpty) {
          _partner = await _userService.getUser(partnerId);
          debugPrint('✅ Partner loaded: ${_partner?.displayName}');
          debugPrint('   Partner photoUrl: ${_partner?.photoUrl ?? "null"}');
        }
      }

      notifyListeners();
    });
  }

  /// Refresh partner data (call when partner updates their profile)
  Future<void> refreshPartner(String currentUserId) async {
    if (_couple == null) return;

    final partnerId = _couple!.getPartnerId(currentUserId);
    if (partnerId.isNotEmpty) {
      _partner = await _userService.getUser(partnerId);
      notifyListeners();
    }
  }

  /// Clears all couple data (call when signing out or switching accounts)
  void clear() {
    _coupleSubscription?.cancel();
    _coupleSubscription = null;
    _incomingRequestsSubscription?.cancel();
    _incomingRequestsSubscription = null;
    _outgoingRequestsSubscription?.cancel();
    _outgoingRequestsSubscription = null;
    _couple = null;
    _partner = null;
    _searchResult = null;
    _inviteCode = null;
    _codeExpiresAt = null;
    _incomingRequests = [];
    _outgoingRequests = [];
    _requestsUserId = null;
    _error = null;
    _isLoading = false;
    _isSearching = false;
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
    _incomingRequestsSubscription?.cancel();
    _outgoingRequestsSubscription?.cancel();
    super.dispose();
  }
}
