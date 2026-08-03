import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../models/user_model.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/user_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().initAdminDashboard();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final adminProvider = context.watch<AdminProvider>();
    final currentUser = context.watch<UserProvider>().user;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Admin Dashboard'),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Users',
            onPressed: () => adminProvider.loadUsers(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => adminProvider.loadUsers(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. Stats Overview Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingMd),
                child: _buildStatsHeader(context, adminProvider, isDark),
              ),
            ),

            // 2. Search & Filter Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
                child: Column(
                  children: [
                    _buildSearchBar(context, adminProvider, isDark),
                    const SizedBox(height: 12),
                    _buildFilterChips(context, adminProvider, isDark),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // 3. User List
            if (adminProvider.isLoading && adminProvider.allUsers.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (adminProvider.filteredUsers.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try adjusting your search query or filter criteria.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingMd,
                  vertical: 8,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final user = adminProvider.filteredUsers[index];
                      final isCurrentAdmin = user.id == currentUser?.id;
                      return _buildUserCard(
                        context,
                        user,
                        isCurrentAdmin,
                        adminProvider,
                        isDark,
                      );
                    },
                    childCount: adminProvider.filteredUsers.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
          ],
        ),
      ),
    );
  }

  // --- STATS OVERVIEW CARDS ---
  Widget _buildStatsHeader(
    BuildContext context,
    AdminProvider provider,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Total Users',
                value: provider.totalUsersCount.toString(),
                icon: Icons.groups_rounded,
                color: Colors.blue,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Active Users',
                value: provider.activeUsersCount.toString(),
                icon: Icons.check_circle_rounded,
                color: Colors.green,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Deactivated',
                value: provider.deactivatedUsersCount.toString(),
                icon: Icons.block_rounded,
                color: Colors.redAccent,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Admins',
                value: provider.adminUsersCount.toString(),
                icon: Icons.security_rounded,
                color: Colors.purple,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SEARCH BAR ---
  Widget _buildSearchBar(
    BuildContext context,
    AdminProvider provider,
    bool isDark,
  ) {
    return TextField(
      controller: _searchController,
      onChanged: (val) => provider.setSearchQuery(val),
      decoration: InputDecoration(
        hintText: 'Search by display name or email...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _searchController.clear();
                  provider.setSearchQuery('');
                },
              )
            : null,
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  // --- FILTER CHIPS ---
  Widget _buildFilterChips(
    BuildContext context,
    AdminProvider provider,
    bool isDark,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('All (${provider.totalUsersCount})', UserFilter.all, provider, isDark),
          const SizedBox(width: 8),
          _buildFilterChip('Active (${provider.activeUsersCount})', UserFilter.active, provider, isDark),
          const SizedBox(width: 8),
          _buildFilterChip('Deactivated (${provider.deactivatedUsersCount})', UserFilter.deactivated, provider, isDark),
          const SizedBox(width: 8),
          _buildFilterChip('Admins (${provider.adminUsersCount})', UserFilter.admins, provider, isDark),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    UserFilter filter,
    AdminProvider provider,
    bool isDark,
  ) {
    final isSelected = provider.selectedFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => provider.setFilter(filter),
      selectedColor: AppColors.primary.withOpacity(0.2),
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      labelStyle: TextStyle(
        color: isSelected
            ? AppColors.primary
            : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected
            ? AppColors.primary
            : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  // --- USER CARD ---
  Widget _buildUserCard(
    BuildContext context,
    UserModel user,
    bool isCurrentAdmin,
    AdminProvider provider,
    bool isDark,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: user.isDeactivated
              ? Colors.red.withOpacity(0.3)
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
          width: user.isDeactivated ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showUserDetailsModal(context, user, isDark),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // User Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    backgroundImage: (user.photoUrl != null &&
                            user.photoUrl!.isNotEmpty &&
                            !user.photoUrl!.startsWith('data:image'))
                        ? NetworkImage(user.photoUrl!)
                        : null,
                    child: (user.photoUrl == null ||
                            user.photoUrl!.isEmpty ||
                            user.photoUrl!.startsWith('data:image'))
                        ? Text(
                            user.displayName.isNotEmpty
                                ? user.displayName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Name and Email
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.displayName.isNotEmpty
                                    ? user.displayName
                                    : 'Unnamed User',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrentAdmin) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'YOU',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Actions menu / toggle button
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: isDark ? Colors.white60 : Colors.grey.shade700,
                    ),
                    onSelected: (value) async {
                      if (value == 'toggle_active') {
                        _confirmToggleActive(context, user, provider);
                      } else if (value == 'toggle_role') {
                        _confirmToggleRole(context, user, provider);
                      } else if (value == 'details') {
                        _showUserDetailsModal(context, user, isDark);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: const [
                            Icon(Icons.info_outline, size: 18),
                            SizedBox(width: 8),
                            Text('View Details'),
                          ],
                        ),
                      ),
                      if (!isCurrentAdmin) ...[
                        PopupMenuItem(
                          value: 'toggle_active',
                          child: Row(
                            children: [
                              Icon(
                                user.isActive
                                    ? Icons.block_rounded
                                    : Icons.check_circle_outline,
                                size: 18,
                                color: user.isActive ? Colors.red : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                user.isActive ? 'Deactivate Account' : 'Activate Account',
                                style: TextStyle(
                                  color: user.isActive ? Colors.red : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'toggle_role',
                          child: Row(
                            children: [
                              Icon(
                                user.isAdmin
                                    ? Icons.person_outline
                                    : Icons.admin_panel_settings_outlined,
                                size: 18,
                                color: Colors.purple,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                user.isAdmin ? 'Demote to User' : 'Promote to Admin',
                                style: const TextStyle(color: Colors.purple),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Badges Row
              Row(
                children: [
                  // Status Badge
                  _buildBadge(
                    label: user.isActive ? 'Active' : 'Deactivated',
                    color: user.isActive ? Colors.green : Colors.red,
                    icon: user.isActive
                        ? Icons.check_circle_rounded
                        : Icons.block_rounded,
                  ),
                  const SizedBox(width: 8),

                  // Role Badge
                  _buildBadge(
                    label: user.isAdmin ? 'Admin' : 'User',
                    color: user.isAdmin ? Colors.purple : Colors.blue,
                    icon: user.isAdmin
                        ? Icons.security_rounded
                        : Icons.person_rounded,
                  ),
                  const SizedBox(width: 8),

                  // Couple Status Badge
                  _buildBadge(
                    label: user.hasRealPartner ? 'Coupled' : 'Single',
                    color: user.hasRealPartner ? Colors.pink : Colors.grey,
                    icon: user.hasRealPartner
                        ? Icons.favorite_rounded
                        : Icons.person_outline_rounded,
                  ),

                  const Spacer(),

                  // Quick Action Activation Switch
                  if (!isCurrentAdmin)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.isActive ? 'Active' : 'Off',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: user.isActive ? Colors.green : Colors.red,
                          ),
                        ),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: user.isActive,
                            activeColor: Colors.green,
                            inactiveTrackColor: Colors.red.withOpacity(0.2),
                            inactiveThumbColor: Colors.red,
                            onChanged: (_) =>
                                _confirmToggleActive(context, user, provider),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // --- CONFIRMATION DIALOGS ---
  void _confirmToggleActive(
    BuildContext context,
    UserModel targetUser,
    AdminProvider provider,
  ) {
    final willDeactivate = targetUser.isActive;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(willDeactivate ? 'Deactivate Account?' : 'Activate Account?'),
        content: Text(
          willDeactivate
              ? 'Are you sure you want to deactivate ${targetUser.displayName} (${targetUser.email})? They will be blocked from accessing the app.'
              : 'Are you sure you want to activate ${targetUser.displayName} (${targetUser.email})? Full access will be restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.toggleUserActiveStatus(targetUser);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        willDeactivate
                            ? 'Account deactivated successfully.'
                            : 'Account activated successfully.',
                      ),
                      backgroundColor: willDeactivate ? Colors.red : Colors.green,
                    ),
                  );
                } else if (provider.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(provider.error!)),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: willDeactivate ? Colors.red : Colors.green,
            ),
            child: Text(willDeactivate ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
  }

  void _confirmToggleRole(
    BuildContext context,
    UserModel targetUser,
    AdminProvider provider,
  ) {
    final willBeAdmin = !targetUser.isAdmin;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(willBeAdmin ? 'Promote to Admin?' : 'Demote to User?'),
        content: Text(
          willBeAdmin
              ? 'Grant admin rights to ${targetUser.displayName}? They will gain full control over user accounts and admin settings.'
              : 'Revoke admin rights from ${targetUser.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.toggleUserRole(targetUser);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        willBeAdmin
                            ? '${targetUser.displayName} is now an Admin.'
                            : '${targetUser.displayName} is now a standard User.',
                      ),
                    ),
                  );
                } else if (provider.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(provider.error!)),
                  );
                }
              }
            },
            child: Text(willBeAdmin ? 'Promote' : 'Demote'),
          ),
        ],
      ),
    );
  }

  // --- USER DETAILS MODAL ---
  void _showUserDetailsModal(BuildContext context, UserModel user, bool isDark) {
    final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  child: Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user.email,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            _buildDetailRow('User ID', user.id, isDark),
            _buildDetailRow('Role', user.role.toUpperCase(), isDark),
            _buildDetailRow('Account Status', user.isActive ? 'Active' : 'Deactivated', isDark),
            _buildDetailRow('Phone', user.phoneNumber ?? 'Not provided', isDark),
            _buildDetailRow('Couple ID', user.coupleId ?? 'Not linked', isDark),
            _buildDetailRow('Profile Complete', user.profileComplete ? 'Yes' : 'No', isDark),
            _buildDetailRow('Created At', dateFormat.format(user.createdAt), isDark),
            _buildDetailRow('Updated At', dateFormat.format(user.updatedAt), isDark),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
