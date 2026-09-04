import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/zodiac_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/user_model.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/debug_provider.dart';
import '../../../providers/secret_media_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/supabase_data_service.dart';
import '../../../services/vault_cache_manager.dart';
import '../../../widgets/smart_profile_image.dart';
import '../../../widgets/common/app_text_field.dart';

/// Senior Admin Dashboard Screen redesigned to match Jayienne Link's signature romantic theme
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
    final debugProvider = context.watch<DebugProvider?>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF120E19) : const Color(0xFFFFF7F9),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Admin Console',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Data',
            onPressed: () {
              HapticFeedback.lightImpact();
              adminProvider.loadUsers();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => adminProvider.loadUsers(),
        color: const Color(0xFFFF758C),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. Stats Overview Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildStatsHeader(context, adminProvider, isDark),
              ),
            ),

            // 2. Developer, Debug Mode & Sync/Health Controls (Works in Release Mode)
            if (debugProvider != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _buildDebugControlsCard(context, debugProvider, isDark),
                ),
              ),

            // 3. Search & Filter Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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

            // 4. User List
            if (adminProvider.isLoading && adminProvider.allUsers.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF758C)),
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
                        color: isDark ? Colors.white30 : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Try adjusting your search query or filter criteria.',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              child: SizedBox(height: 36),
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
                gradientColors: const [Color(0xFFFF758C), Color(0xFFA18CD1)],
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
                gradientColors: const [Color(0xFF4CAF50), Color(0xFF2E7D32)],
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
                gradientColors: const [Color(0xFFFF5252), Color(0xFFD81B60)],
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
                gradientColors: const [Color(0xFF8E24AA), Color(0xFF5E35B1)],
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
    required List<Color> gradientColors,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF1C1427) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: gradientColors.first.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.first.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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

  // --- DEVELOPER & DEBUG MODE CONTROLS CARD (Available in Release Mode) ---
  Widget _buildDebugControlsCard(
    BuildContext context,
    DebugProvider debugProvider,
    bool isDark,
  ) {
    final cardBg = isDark ? const Color(0xFF1C1427) : Colors.white;
    final isDebugActive = debugProvider.isDebugMode;
    final isOverridden = debugProvider.isDebugModeOverride;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDebugActive
              ? const Color(0xFFFF758C).withValues(alpha: 0.45)
              : (isDark ? Colors.white12 : Colors.grey.shade300),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF758C).withValues(alpha: isDebugActive ? 0.12 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title and Status Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bug_report_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Developer & Debug Mode',
                      style: GoogleFonts.poppins(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.deepCharcoal,
                      ),
                    ),
                    Text(
                      isOverridden
                          ? 'Debug tools active via Release Override'
                          : kDebugMode
                              ? 'Native Flutter debug build'
                              : 'Release mode active',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDebugActive
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                      : (isDark ? Colors.white10 : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDebugActive
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 7,
                      color: isDebugActive ? const Color(0xFF4CAF50) : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isDebugActive ? 'DEBUG ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isDebugActive
                            ? const Color(0xFF4CAF50)
                            : (isDark ? Colors.white60 : Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
          const SizedBox(height: 14),

          // 1. Primary Debug Mode Switch (Release Override)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enable Debug Mode in Release',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Unlocks developer simulation tools and test menus across the entire app.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: debugProvider.isDebugModeOverride,
                activeThumbColor: const Color(0xFFFF758C),
                activeTrackColor: const Color(0xFFFF758C).withValues(alpha: 0.35),
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  debugProvider.setDebugModeOverride(val);
                  SnackbarHelper.showSuccess(
                    context,
                    val
                        ? 'Debug mode enabled! Developer tools and simulations are now active.'
                        : 'Debug mode disabled.',
                    title: 'Debug Mode',
                  );
                },
              ),
            ],
          ),

          // 2. Offline Simulation Toggle
          if (isDebugActive) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Simulate Offline Mode',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        debugProvider.forceOfflineMode
                            ? 'Simulating disconnected state'
                            : 'Normal live network',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: debugProvider.forceOfflineMode,
                  activeThumbColor: const Color(0xFFA18CD1),
                  activeTrackColor: const Color(0xFFA18CD1).withValues(alpha: 0.35),
                  onChanged: (_) {
                    HapticFeedback.lightImpact();
                    debugProvider.toggleOfflineMode();
                  },
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
          const SizedBox(height: 14),

          // ── SYNC & RESTORE HEALTH CENTER ───────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'Sync & System Health',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.deepCharcoal,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'HEALTHY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 3. Database & Cloud Health Diagnostic Button
          Container(
            width: double.infinity,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => _showSystemHealthModal(context, isDark),
              icon: const Icon(Icons.monitor_heart_rounded, size: 18, color: Colors.white),
              label: const Text(
                'Database & Cloud Health Inspector',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 4. Row with Sync & Restore Vault and Purge Cache
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF758C).withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _handleRestoreAllMedia(context),
                    icon: const Icon(Icons.sync_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Sync & Restore Vault',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5252), Color(0xFFD81B60)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5252).withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _handlePurgeCache(context),
                    icon: const Icon(Icons.cleaning_services_rounded, size: 15, color: Colors.white),
                    label: const Text(
                      'Purge Cache',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- SYSTEM HEALTH DIAGNOSTICS MODAL ---
  void _showSystemHealthModal(BuildContext context, bool isDark) {
    HapticFeedback.mediumImpact();
    final cardBg = isDark ? const Color(0xFF1C1427) : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>>(
          future: SupabaseDataService.getDatabaseHealth(),
          builder: (context, snapshot) {
            final isLoading = snapshot.connectionState == ConnectionState.waiting;
            final data = snapshot.data ?? {};
            final isConnected = data['connected'] == true;
            final latency = data['latency_ms'] ?? 0;

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.monitor_heart_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'System & Database Health',
                                style: GoogleFonts.poppins(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.deepCharcoal,
                                ),
                              ),
                              Text(
                                isConnected
                                    ? 'Supabase PostgreSQL • Online'
                                    : 'Supabase PostgreSQL • Checking...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isConnected ? const Color(0xFF4CAF50) : Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFF758C).withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.speed_rounded, size: 13, color: Color(0xFFFF758C)),
                              const SizedBox(width: 4),
                              Text(
                                '${latency}ms',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF758C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                    Divider(color: isDark ? Colors.white10 : Colors.grey.shade200),
                    const SizedBox(height: 12),

                    if (isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28.0),
                          child: CircularProgressIndicator(color: Color(0xFFFF758C)),
                        ),
                      )
                    else ...[
                      // Metrics Grid
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildHealthMetricRow('Database Engine', data['database_type'] ?? 'PostgreSQL', isDark, Icons.storage_rounded),
                            _buildHealthMetricRow('Registered Users', '${data['users_count'] ?? 0}', isDark, Icons.people_rounded),
                            _buildHealthMetricRow('Couples Linked', '${data['couples_count'] ?? 0}', isDark, Icons.favorite_rounded),
                            _buildHealthMetricRow('Secret Vault Media', '${data['secret_media_count'] ?? 0}', isDark, Icons.lock_rounded),
                            _buildHealthMetricRow('Movie Dates Logged', '${data['movies_count'] ?? 0}', isDark, Icons.movie_rounded),
                            _buildHealthMetricRow('Storage Buckets', '4 Active (avatars, photos, vault, audio)', isDark, Icons.cloud_done_rounded),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Actions Row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF758C).withValues(alpha: 0.30),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(ctx);
                                _handleRestoreAllMedia(context);
                              },
                              icon: const Icon(Icons.sync_rounded, size: 16, color: Colors.white),
                              label: const Text(
                                'Sync Vault',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF758C).withValues(alpha: 0.30),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                              label: const Text(
                                'Done',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHealthMetricRow(String label, String value, bool isDark, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFFFF758C)),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.deepCharcoal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePurgeCache(BuildContext context) async {
    HapticFeedback.mediumImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF1C1427) : Colors.white,
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF5252).withValues(alpha: 0.15),
                      const Color(0xFFD81B60).withValues(alpha: 0.20),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cleaning_services_rounded,
                  color: Color(0xFFFF5252),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Purge Temporary Cache?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.deepCharcoal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'This will clear local decrypted memory caches and temporary vault files to free up device space. No cloud photos or videos will be deleted.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5252), Color(0xFFD81B60)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5252).withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.cleaning_services_rounded, size: 20, color: Colors.white),
                  label: const Text(
                    'Purge Cache',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await VaultCacheManager.instance.purgeVaultCache();
      if (context.mounted) {
        SnackbarHelper.showSuccess(
          context,
          'Temporary vault memory & disk cache purged cleanly.',
          title: 'Cache Purged',
        );
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Failed to purge cache: $e');
      }
    }
  }

  Future<void> _handleRestoreAllMedia(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final user = context.read<UserProvider>().user;
    final coupleId = user?.coupleId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF1C1427) : Colors.white,
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF758C).withValues(alpha: 0.15),
                      const Color(0xFFA18CD1).withValues(alpha: 0.20),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.restore_from_trash_rounded,
                  color: Color(0xFFFF758C),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Restore Hidden Vault Media?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.deepCharcoal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'This will restore all deleted private photos and videos uploaded by you and your partner back to the Hidden Vault.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF758C).withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.sync_rounded, size: 20, color: Colors.white),
                  label: const Text(
                    'Sync & Restore Vault',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final secretMediaProvider = context.read<SecretMediaProvider>();

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF758C)),
        ),
      );

      final restoredCount = await secretMediaProvider.restoreHiddenVaultMedia(
        targetCoupleId: coupleId,
      );

      if (context.mounted) {
        Navigator.pop(context);
        setState(() {});
        if (restoredCount > 0) {
          SnackbarHelper.showSuccess(
            context,
            'Successfully restored $restoredCount hidden vault items!',
            title: 'Vault Restored',
          );
        } else {
          SnackbarHelper.showInfo(
            context,
            'All hidden vault photos & videos are active and synced!',
            title: 'Vault Status',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        SnackbarHelper.showError(
          context,
          'Failed to restore hidden vault media: $e',
        );
      }
    }
  }

  // --- SEARCH BAR ---
  Widget _buildSearchBar(
    BuildContext context,
    AdminProvider provider,
    bool isDark,
  ) {
    return AppTextField(
      controller: _searchController,
      hintText: 'Search display name or email...',
      prefixIcon: Icons.search_rounded,
      onChanged: (val) => provider.setSearchQuery(val),
      isDark: isDark,
      suffixIcon: _searchController.text.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear_rounded, size: 16),
              onPressed: () {
                _searchController.clear();
                provider.setSearchQuery('');
              },
            )
          : null,
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
          _buildFilterChip('All (${provider.totalUsersCount})', UserFilter.all, provider, isDark, Icons.people_rounded),
          const SizedBox(width: 8),
          _buildFilterChip('Active (${provider.activeUsersCount})', UserFilter.active, provider, isDark, Icons.check_circle_rounded),
          const SizedBox(width: 8),
          _buildFilterChip('Deactivated (${provider.deactivatedUsersCount})', UserFilter.deactivated, provider, isDark, Icons.block_rounded),
          const SizedBox(width: 8),
          _buildFilterChip('Admins (${provider.adminUsersCount})', UserFilter.admins, provider, isDark, Icons.shield_rounded),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    UserFilter filter,
    AdminProvider provider,
    bool isDark,
    IconData icon,
  ) {
    final isSelected = provider.selectedFilter == filter;
    final cardBg = isDark ? const Color(0xFF1C1427) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          provider.setFilter(filter);
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF758C).withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey.shade700),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.grey.shade700),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
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
    final cardBg = isDark ? const Color(0xFF1C1427) : Colors.white;
    final zodiacInfo = ZodiacHelper.getZodiac(user.zodiacSign);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: user.isDeactivated
              ? const Color(0xFFFF5252).withValues(alpha: 0.35)
              : (user.isAdmin
                  ? const Color(0xFFFF758C).withValues(alpha: 0.40)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.shade200)),
          width: user.isAdmin || user.isDeactivated ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          if (user.isAdmin)
            BoxShadow(
              color: const Color(0xFFFF758C).withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 2),
            ),
          if (user.isDeactivated)
            BoxShadow(
              color: const Color(0xFFFF5252).withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Romantic Gradient Accent Line
            Container(
              height: 3.5,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: user.isDeactivated
                      ? const [Color(0xFFFF5252), Color(0xFFD81B60)]
                      : (user.isAdmin
                          ? const [Color(0xFFFF758C), Color(0xFFA18CD1)]
                          : [
                              const Color(0xFFFF758C).withValues(alpha: 0.4),
                              const Color(0xFFA18CD1).withValues(alpha: 0.4),
                            ]),
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),

            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showUserDetailsModal(context, user, isDark),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Avatar, User Details, and Actions
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Double-ring Glowing Avatar with Status Indicator Dot
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: user.isDeactivated
                                        ? const [Color(0xFFFF5252), Color(0xFFD81B60)]
                                        : (user.isAdmin
                                            ? const [Color(0xFFFF758C), Color(0xFFA18CD1)]
                                            : [
                                                const Color(0xFFFF758C).withValues(alpha: 0.8),
                                                const Color(0xFFA18CD1).withValues(alpha: 0.8),
                                              ]),
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (user.isDeactivated
                                              ? const Color(0xFFFF5252)
                                              : const Color(0xFFFF758C))
                                          .withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(2.2),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: cardBg,
                                  ),
                                  child: ClipOval(
                                    child: SmartProfileImage(
                                      imageUrl: user.photoUrl,
                                      width: 46,
                                      height: 46,
                                      placeholder: Container(
                                        color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                                        child: Center(
                                          child: Text(
                                            user.displayName.isNotEmpty
                                                ? user.displayName[0].toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                              color: Color(0xFFFF758C),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                      errorWidget: Container(
                                        color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                                        child: const Icon(Icons.person, color: Color(0xFFFF758C), size: 24),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Bottom-right Status Indicator Dot
                              Positioned(
                                bottom: -1,
                                right: -1,
                                child: Container(
                                  width: 15,
                                  height: 15,
                                  decoration: BoxDecoration(
                                    color: user.isActive
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFFFF5252),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: cardBg,
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      user.isActive ? Icons.check_rounded : Icons.close_rounded,
                                      size: 8,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),

                          // Name, Identity Badges & Email
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
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15.5,
                                          color: isDark ? Colors.white : AppColors.deepCharcoal,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isCurrentAdmin) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                                              blurRadius: 6,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: const Text(
                                          'YOU',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (user.isAdmin && !isCurrentAdmin) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFA18CD1).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: const Color(0xFFA18CD1).withValues(alpha: 0.5),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.shield_rounded, size: 10, color: Color(0xFFA18CD1)),
                                            SizedBox(width: 3),
                                            Text(
                                              'ADMIN',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFA18CD1),
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.alternate_email_rounded,
                                      size: 12,
                                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        user.email,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Trailing Action: Quick View Details & Popup Menu
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                color: isDark ? Colors.white54 : Colors.grey.shade600,
                                tooltip: 'View Details',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: () => _showUserDetailsModal(context, user, isDark),
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert_rounded,
                                  color: isDark ? Colors.white60 : Colors.grey.shade700,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                color: cardBg,
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
                                  const PopupMenuItem(
                                    value: 'details',
                                    child: Row(
                                      children: [
                                        Icon(Icons.badge_rounded, size: 18, color: Color(0xFFFF758C)),
                                        SizedBox(width: 10),
                                        Text('View Details', style: TextStyle(fontWeight: FontWeight.w600)),
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
                                                : Icons.check_circle_outline_rounded,
                                            size: 18,
                                            color: user.isActive ? const Color(0xFFFF5252) : const Color(0xFF4CAF50),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            user.isActive ? 'Deactivate Account' : 'Activate Account',
                                            style: TextStyle(
                                              color: user.isActive ? const Color(0xFFFF5252) : const Color(0xFF4CAF50),
                                              fontWeight: FontWeight.w600,
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
                                                ? Icons.person_outline_rounded
                                                : Icons.admin_panel_settings_outlined,
                                            size: 18,
                                            color: const Color(0xFFA18CD1),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            user.isAdmin ? 'Demote to User' : 'Promote to Admin',
                                            style: const TextStyle(
                                              color: Color(0xFFA18CD1),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
                      const SizedBox(height: 10),

                      // Bottom Badges & Quick Action Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 5,
                              runSpacing: 5,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Status Badge
                                _buildBadge(
                                  label: user.isActive ? 'Active' : 'Deactivated',
                                  color: user.isActive ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                                  icon: user.isActive
                                      ? Icons.check_circle_rounded
                                      : Icons.block_rounded,
                                ),

                                // Zodiac Badge
                                if (user.zodiacSign != null && user.zodiacSign!.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: (zodiacInfo?.color ?? const Color(0xFFA18CD1)).withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: (zodiacInfo?.color ?? const Color(0xFFA18CD1)).withValues(alpha: 0.35),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        ZodiacIcon(
                                          zodiac: user.zodiacSign!,
                                          size: 11,
                                          color: zodiacInfo?.color ?? const Color(0xFFA18CD1),
                                          strokeWidth: 2.0,
                                        ),
                                        const SizedBox(width: 3.5),
                                        Text(
                                          user.zodiacSign!,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: zodiacInfo?.color ?? const Color(0xFFA18CD1),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Couple Status Badge
                                _buildBadge(
                                  label: user.hasRealPartner ? 'Coupled' : 'Single',
                                  color: user.hasRealPartner ? const Color(0xFFFF758C) : Colors.grey,
                                  icon: user.hasRealPartner
                                      ? Icons.favorite_rounded
                                      : Icons.person_outline_rounded,
                                ),
                              ],
                            ),
                          ),

                          // Quick Action Button: Activate / Deactivate
                          if (!isCurrentAdmin) ...[
                            const SizedBox(width: 8),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _confirmToggleActive(context, user, provider),
                                borderRadius: BorderRadius.circular(10),
                                child: Ink(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    gradient: user.isActive
                                        ? const LinearGradient(
                                            colors: [Color(0xFFFF5252), Color(0xFFD81B60)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : const LinearGradient(
                                            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (user.isActive
                                                ? const Color(0xFFFF5252)
                                                : const Color(0xFFFF758C))
                                            .withValues(alpha: 0.28),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        user.isActive
                                            ? Icons.block_rounded
                                            : Icons.check_circle_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        user.isActive ? 'Deactivate' : 'Activate',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (willDeactivate
                        ? const Color(0xFFFF5252)
                        : const Color(0xFFFF758C))
                    .withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                willDeactivate
                    ? Icons.block_rounded
                    : Icons.check_circle_rounded,
                size: 20,
                color: willDeactivate
                    ? const Color(0xFFFF5252)
                    : const Color(0xFFFF758C),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                willDeactivate ? 'Deactivate Account?' : 'Activate Account?',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          willDeactivate
              ? 'Are you sure you want to deactivate ${targetUser.displayName} (${targetUser.email})? They will be blocked from accessing the app.'
              : 'Are you sure you want to activate ${targetUser.displayName} (${targetUser.email})? Full access will be restored.',
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: willDeactivate
                  ? const LinearGradient(
                      colors: [Color(0xFFFF5252), Color(0xFFD81B60)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: (willDeactivate
                          ? const Color(0xFFFF5252)
                          : const Color(0xFFFF758C))
                      .withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await provider.toggleUserActiveStatus(targetUser);
                if (context.mounted) {
                  if (success) {
                    SnackbarHelper.showSuccess(
                      context,
                      willDeactivate
                          ? 'Account deactivated successfully.'
                          : 'Account activated successfully.',
                    );
                  } else if (provider.error != null) {
                    SnackbarHelper.showError(context, provider.error!);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                willDeactivate ? 'Deactivate' : 'Activate',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          willBeAdmin ? 'Promote to Admin?' : 'Demote to User?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          willBeAdmin
              ? 'Grant admin rights to ${targetUser.displayName}? They will gain full control over user accounts and admin settings.'
              : 'Revoke admin rights from ${targetUser.displayName}?',
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: willBeAdmin
                  ? const LinearGradient(
                      colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFFF5252), Color(0xFFD81B60)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: (willBeAdmin
                          ? const Color(0xFFFF758C)
                          : const Color(0xFFFF5252))
                      .withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await provider.toggleUserRole(targetUser);
                if (context.mounted) {
                  if (success) {
                    SnackbarHelper.showSuccess(
                      context,
                      willBeAdmin
                          ? '${targetUser.displayName} is now an Admin.'
                          : '${targetUser.displayName} is now a standard User.',
                    );
                  } else if (provider.error != null) {
                    SnackbarHelper.showError(context, provider.error!);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                willBeAdmin ? 'Promote' : 'Demote',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- USER DETAILS MODAL ---
  void _showUserDetailsModal(BuildContext context, UserModel user, bool isDark) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final cardBg = isDark ? const Color(0xFF1C1427) : Colors.white;
    final zodiacInfo = ZodiacHelper.getZodiac(user.zodiacSign);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header: Avatar, Name, Email, and Close Icon
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF758C).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cardBg,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipOval(
                        child: SmartProfileImage(
                          imageUrl: user.photoUrl,
                          width: 46,
                          height: 46,
                          placeholder: Container(
                            color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                            child: Center(
                              child: Text(
                                user.displayName.isNotEmpty
                                    ? user.displayName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Color(0xFFFF758C),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: Container(
                            color: const Color(0xFFFF758C).withValues(alpha: 0.15),
                            child: const Icon(Icons.person, color: Color(0xFFFF758C), size: 24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName.isNotEmpty ? user.displayName : 'Unnamed User',
                          style: GoogleFonts.poppins(
                            fontSize: 17.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.deepCharcoal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
              const SizedBox(height: 14),

              // Organized Details Grid (Clean 2-Column Info Cards)
              Row(
                children: [
                  Expanded(
                    child: _buildModalInfoTile(
                      label: 'Account Status',
                      value: user.isActive ? 'Active' : 'Deactivated',
                      icon: user.isActive ? Icons.check_circle_rounded : Icons.block_rounded,
                      iconColor: user.isActive ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildModalInfoTile(
                      label: 'System Role',
                      value: user.isAdmin ? 'Admin' : 'User',
                      icon: user.isAdmin ? Icons.shield_rounded : Icons.person_rounded,
                      iconColor: user.isAdmin ? const Color(0xFFA18CD1) : const Color(0xFFFF758C),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildModalInfoTile(
                      label: 'Relationship',
                      value: user.hasRealPartner ? 'Coupled' : 'Single',
                      icon: user.hasRealPartner ? Icons.favorite_rounded : Icons.person_outline_rounded,
                      iconColor: user.hasRealPartner ? const Color(0xFFFF758C) : Colors.grey,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildModalInfoTile(
                      label: 'Zodiac Sign',
                      value: (user.zodiacSign != null && user.zodiacSign!.isNotEmpty)
                          ? user.zodiacSign!
                          : 'Not set',
                      icon: Icons.auto_awesome_rounded,
                      iconColor: zodiacInfo?.color ?? const Color(0xFFA18CD1),
                      customIcon: (user.zodiacSign != null && user.zodiacSign!.isNotEmpty)
                          ? ZodiacIcon(
                              zodiac: user.zodiacSign!,
                              size: 16,
                              color: zodiacInfo?.color ?? const Color(0xFFA18CD1),
                              strokeWidth: 2.0,
                            )
                          : null,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildModalInfoTile(
                label: 'Member Since',
                value: dateFormat.format(user.createdAt),
                icon: Icons.calendar_today_rounded,
                iconColor: const Color(0xFF5C6BC0),
                isDark: isDark,
              ),

              const SizedBox(height: 20),

              // Redesigned Close Button (Romantic Gradient Hero Button per AGENTS.md)
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 19),
                  label: const Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalInfoTile({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    Widget? customIcon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: customIcon ?? Icon(icon, color: iconColor, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
