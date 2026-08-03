import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/supabase_user_service.dart';

enum UserFilter { all, active, deactivated, admins }

class AdminProvider extends ChangeNotifier {
  final SupabaseUserService _userService;

  List<UserModel> _allUsers = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  UserFilter _selectedFilter = UserFilter.all;

  StreamSubscription<List<UserModel>>? _usersSubscription;
  bool _disposed = false;

  AdminProvider(this._userService);

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  List<UserModel> get allUsers => _allUsers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  UserFilter get selectedFilter => _selectedFilter;

  // Filtered Users List
  List<UserModel> get filteredUsers {
    return _allUsers.where((user) {
      // 1. Search Query Filter (Display Name or Email)
      final matchesSearch = _searchQuery.isEmpty ||
          user.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.email.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      // 2. Tab Category Filter
      switch (_selectedFilter) {
        case UserFilter.active:
          return user.isActive;
        case UserFilter.deactivated:
          return user.isDeactivated;
        case UserFilter.admins:
          return user.isAdmin;
        case UserFilter.all:
          return true;
      }
    }).toList();
  }

  // Dashboard Stats
  int get totalUsersCount => _allUsers.length;
  int get activeUsersCount => _allUsers.where((u) => u.isActive).length;
  int get deactivatedUsersCount => _allUsers.where((u) => u.isDeactivated).length;
  int get adminUsersCount => _allUsers.where((u) => u.isAdmin).length;
  int get coupledUsersCount => _allUsers.where((u) => u.hasRealPartner).length;

  /// Initialize and start streaming user list
  void initAdminDashboard() {
    loadUsers();
    _usersSubscription?.cancel();
    _usersSubscription = _userService.allUsersStream().listen(
      (users) {
        _allUsers = users;
        _isLoading = false;
        notifyListeners();
      },
      onError: (err) {
        debugPrint('Admin stream error: $err');
        _error = 'Error listening to user updates.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Manually load users
  Future<void> loadUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allUsers = await _userService.getAllUsers();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load users: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update Search Query
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Update Category Filter
  void setFilter(UserFilter filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  /// Toggle User Active/Deactivated Status
  Future<bool> toggleUserActiveStatus(UserModel targetUser) async {
    _error = null;
    final newActiveState = !targetUser.isActive;

    try {
      await _userService.setUserActiveStatus(targetUser.id, newActiveState);

      // Optimistically update local list
      final index = _allUsers.indexWhere((u) => u.id == targetUser.id);
      if (index != -1) {
        _allUsers[index] = targetUser.copyWith(isActive: newActiveState);
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = 'Failed to update user status: $e';
      notifyListeners();
      return false;
    }
  }

  /// Toggle User Role (User <-> Admin)
  Future<bool> toggleUserRole(UserModel targetUser) async {
    _error = null;
    final newRole = targetUser.isAdmin ? 'user' : 'admin';

    try {
      await _userService.setUserRole(targetUser.id, newRole);

      // Optimistically update local list
      final index = _allUsers.indexWhere((u) => u.id == targetUser.id);
      if (index != -1) {
        _allUsers[index] = targetUser.copyWith(role: newRole);
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = 'Failed to update user role: $e';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _usersSubscription?.cancel();
    super.dispose();
  }
}
