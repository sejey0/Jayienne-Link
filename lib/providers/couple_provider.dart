import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/couple_model.dart';
import '../models/anniversary_request_model.dart';
import '../models/partner_request_model.dart';
import '../models/user_model.dart';
import '../services/supabase_couple_service.dart';
import '../services/supabase_user_service.dart';
import '../services/supabase_data_service.dart';
import '../services/local_cache_service.dart';
import 'debug_provider.dart';

class CoupleProvider extends ChangeNotifier {
  final SupabaseCoupleService _coupleService;
  final SupabaseUserService _userService;
  final DebugProvider? _debugProvider;

  // Static in-memory cache to preserve data across provider lifecycle
  static CoupleModel? _staticCoupleCache;
  static UserModel? _staticPartnerCache;

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
  StreamSubscription<List<AnniversaryRequestModel>>?
      _incomingAnniversarySubscription;
  StreamSubscription<List<AnniversaryRequestModel>>?
      _outgoingAnniversarySubscription;
  List<PartnerRequestModel> _incomingRequests = [];
  List<PartnerRequestModel> _outgoingRequests = [];
  List<AnniversaryRequestModel> _incomingAnniversaryRequests = [];
  List<AnniversaryRequestModel> _outgoingAnniversaryRequests = [];
  String? _requestsUserId;

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  StreamSubscription<bool>? _offlineStreamSub;

  CoupleProvider(this._coupleService, this._userService,
      [this._debugProvider]) {
    // Initialize with static cache if available
    if (_staticCoupleCache != null && _staticPartnerCache != null) {
      _couple = _staticCoupleCache;
      _partner = _staticPartnerCache;
    }

    _offlineStreamSub = DebugProvider.offlineModeStream.listen((isForced) {
      if (isForced) {
        _coupleSubscription?.cancel();
        LocalCacheService.loadCouple().then((cachedCouple) {
          if (cachedCouple != null) {
            _couple = cachedCouple;
            _staticCoupleCache = cachedCouple;
            notifyListeners();
          }
        });
        LocalCacheService.loadPartner().then((cachedPartner) {
          if (cachedPartner != null) {
            _partner = cachedPartner;
            _staticPartnerCache = cachedPartner;
            notifyListeners();
          }
        });
      } else if (_couple != null && _couple!.id != null) {
        final currentUid = SupabaseDataService.currentUserId ??
            (_couple!.partnerIds.isNotEmpty ? _couple!.partnerIds.first : '');
        if (currentUid.isNotEmpty) {
          loadCouple(_couple!.id!, currentUid);
        }
      }
    });
  }

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
  List<AnniversaryRequestModel> get incomingAnniversaryRequests =>
      _incomingAnniversaryRequests;
  List<AnniversaryRequestModel> get outgoingAnniversaryRequests =>
      _outgoingAnniversaryRequests;

  static void clearStaticCache() {
    _staticCoupleCache = null;
    _staticPartnerCache = null;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void initializeRequests(String userId) {
    if (_requestsUserId == userId &&
        _incomingRequestsSubscription != null &&
        _outgoingRequestsSubscription != null &&
        _incomingAnniversarySubscription != null &&
        _outgoingAnniversarySubscription != null) {
      return;
    }

    _requestsUserId = userId;
    _incomingRequestsSubscription?.cancel();
    _outgoingRequestsSubscription?.cancel();
    _incomingAnniversarySubscription?.cancel();
    _outgoingAnniversarySubscription?.cancel();

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

    _incomingAnniversarySubscription = _coupleService
        .streamIncomingAnniversaryRequests(userId)
        .listen((requests) {
      _incomingAnniversaryRequests = requests;
      notifyListeners();
    });

    _outgoingAnniversarySubscription = _coupleService
        .streamOutgoingAnniversaryRequests(userId)
        .listen((requests) {
      _outgoingAnniversaryRequests = requests;
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
      final request = await _coupleService.sendPartnerRequest(
        sender: sender,
        receiver: receiver,
      );
      if (_outgoingRequests.every((item) => item.id != request.id)) {
        _outgoingRequests = [request, ..._outgoingRequests];
      }
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

  Future<bool> sendAnniversaryRequest({
    required String coupleId,
    required String proposerId,
    required String partnerId,
    required DateTime proposedDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final request = await _coupleService.sendAnniversaryRequest(
        coupleId: coupleId,
        proposerId: proposerId,
        partnerId: partnerId,
        proposedDate: proposedDate,
      );
      _outgoingAnniversaryRequests = [request, ..._outgoingAnniversaryRequests];
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

  Future<bool> acceptAnniversaryRequest(AnniversaryRequestModel request) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final date = await _coupleService.acceptAnniversaryRequest(request);
      _incomingAnniversaryRequests = _incomingAnniversaryRequests
          .where((item) => item.id != request.id)
          .toList();
      if (_couple != null) {
        _couple = _couple!.copyWith(anniversary: date);
      }
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

  Future<void> declineAnniversaryRequest(String requestId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _coupleService.declineAnniversaryRequest(requestId);
      _incomingAnniversaryRequests = _incomingAnniversaryRequests
          .where((item) => item.id != requestId)
          .toList();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cancelAnniversaryRequest(String requestId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _coupleService.cancelAnniversaryRequest(requestId);
      _outgoingAnniversaryRequests = _outgoingAnniversaryRequests
          .where((item) => item.id != requestId)
          .toList();
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

    // If in debug offline mode, load from cache immediately and skip stream
    if ((_debugProvider?.forceOfflineMode ?? false) || DebugProvider.isOfflineForced) {
      LocalCacheService.loadCouple().then((cachedCouple) {
        if (cachedCouple != null && cachedCouple.id == coupleId) {
          _couple = cachedCouple;
          _staticCoupleCache = cachedCouple;
          notifyListeners();
          LocalCacheService.loadPartner().then((cachedPartner) {
            if (cachedPartner != null) {
              _partner = cachedPartner;
              _staticPartnerCache = cachedPartner;
              notifyListeners();
            }
          });
        }
      });
      return;
    }

    // Load from cache first if we don't have data yet
    if (_couple == null) {
      LocalCacheService.loadCouple().then((cachedCouple) {
        if (cachedCouple != null && cachedCouple.id == coupleId) {
          _couple = cachedCouple;
          _staticCoupleCache = cachedCouple;
          notifyListeners();
          LocalCacheService.loadPartner().then((cachedPartner) {
            if (cachedPartner != null) {
              _partner = cachedPartner;
              _staticPartnerCache = cachedPartner;
              notifyListeners();
            }
          });
        }
      });
    }

    _coupleSubscription =
        _coupleService.coupleStream(coupleId).listen((couple) async {
      if (couple == null) {
        if (_couple == null) {
          _couple = null;
          _staticCoupleCache = null;
          notifyListeners();
        }
        return;
      }

      _couple = couple;
      _staticCoupleCache = couple;
      await LocalCacheService.saveCouple(couple);

      // Also load partner data
      final partnerId = couple.getPartnerId(currentUserId);
      if (partnerId.isNotEmpty) {
        try {
          _partner = await _userService.getUser(partnerId);
          if (_partner != null) {
            _staticPartnerCache = _partner;
            await LocalCacheService.savePartner(_partner!);
          }
          debugPrint('✅ Partner loaded: ${_partner?.displayName}');
          debugPrint('   Partner photoUrl: ${_partner?.photoUrl ?? "null"}');
        } catch (e) {
          final cachedPartner = await LocalCacheService.loadPartner();
          if (cachedPartner != null) {
            _partner = cachedPartner;
            _staticPartnerCache = cachedPartner;
          }
          debugPrint('⚠️ Partner load failed, using cached data: $e');
        }
      }

      notifyListeners();
    }, onError: (error) {
      // When stream errors (e.g., offline), try to load from cache
      debugPrint('⚠️ Couple stream error: $error');
      LocalCacheService.loadCouple().then((cachedCouple) {
        if (cachedCouple != null && _couple == null) {
          _couple = cachedCouple;
          _staticCoupleCache = cachedCouple;
          LocalCacheService.loadPartner().then((cachedPartner) {
            if (cachedPartner != null && _partner == null) {
              _partner = cachedPartner;
              _staticPartnerCache = cachedPartner;
              notifyListeners();
            }
          });
        }
      });
    });
  }

  /// Refresh partner data (call when partner updates their profile)
  Future<void> refreshPartner(String currentUserId) async {
    if (_couple == null) return;

    final partnerId = _couple!.getPartnerId(currentUserId);
    if (partnerId.isNotEmpty) {
      try {
        _partner = await _userService.getUser(partnerId);
        if (_partner != null) {
          await LocalCacheService.savePartner(_partner!);
        }
        notifyListeners();
      } catch (e) {
        final cachedPartner = await LocalCacheService.loadPartner();
        if (cachedPartner != null) {
          _partner = cachedPartner;
          notifyListeners();
        }
      }
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
    _incomingAnniversarySubscription?.cancel();
    _incomingAnniversarySubscription = null;
    _outgoingAnniversarySubscription?.cancel();
    _outgoingAnniversarySubscription = null;
    _couple = null;
    _partner = null;
    _staticCoupleCache = null;
    _staticPartnerCache = null;
    _searchResult = null;
    _inviteCode = null;
    _codeExpiresAt = null;
    _incomingRequests = [];
    _outgoingRequests = [];
    _incomingAnniversaryRequests = [];
    _outgoingAnniversaryRequests = [];
    _requestsUserId = null;
    _error = null;
    _isLoading = false;
    _isSearching = false;
    LocalCacheService.clearCouple();
    LocalCacheService.clearPartner();
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
    _disposed = true;
    _offlineStreamSub?.cancel();
    _coupleSubscription?.cancel();
    _incomingRequestsSubscription?.cancel();
    _outgoingRequestsSubscription?.cancel();
    _incomingAnniversarySubscription?.cancel();
    _outgoingAnniversarySubscription?.cancel();
    super.dispose();
  }
}
