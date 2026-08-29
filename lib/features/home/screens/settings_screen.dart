import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/couple_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/app_lock_provider.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/debug_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/supabase_storage_service.dart';
import '../../../widgets/smart_profile_image.dart';
import '../../admin/screens/admin_dashboard_screen.dart';
import '../../auth/screens/auth_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/screens/register_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final user = userProvider.user;
    final couple = coupleProvider.couple;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pendingAnniversary =
        coupleProvider.outgoingAnniversaryRequests.isNotEmpty
            ? coupleProvider.outgoingAnniversaryRequests.first
            : null;

    final cardBg = isDark ? const Color(0xFF1E142B) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.softRose, AppColors.lavender],
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
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        children: [
          // 1. Profile Overview Header Card
          if (user != null) ...[
            _buildProfileSummaryCard(context, user, couple, isDark, cardBg),
            const SizedBox(height: 16),
          ],

          // 2. VIP Admin Dashboard Hero Card
          if (user != null && user.isAdmin) ...[
            _buildAdminHeroCard(context, isDark),
            const SizedBox(height: 20),
          ],

          // 3. Section: Relationship
          _buildSectionHeader('RELATIONSHIP', isDark),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSettingsTile(
                  icon: Icons.favorite_rounded,
                  iconColor: const Color(0xFFFF758C),
                  title: 'Anniversary Date',
                  subtitle: couple == null
                      ? 'Link with your partner to set one'
                      : pendingAnniversary != null
                          ? 'Request pending for ${_formatAnniversary(pendingAnniversary.proposedDate)}'
                          : couple.anniversary != null
                              ? 'Current: ${_formatAnniversary(couple.anniversary!)}'
                              : 'Not set yet',
                  trailing: Icon(
                    Icons.edit_calendar_rounded,
                    color: couple == null ? Colors.grey.shade400 : AppColors.softRose,
                    size: 22,
                  ),
                  onTap: couple == null
                      ? null
                      : () => _requestAnniversary(context, user!, couple),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. Section: Preferences & Appearance
          _buildSectionHeader('PREFERENCES', isDark),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSwitchTile(
                  icon: themeProvider.isDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  iconColor: themeProvider.isDarkMode
                      ? AppColors.lavender
                      : const Color(0xFFFFB74D),
                  title: 'Dark Mode',
                  subtitle: themeProvider.isDarkMode
                      ? 'Dark romantic theme active'
                      : 'Light romantic theme active',
                  value: themeProvider.isDarkMode,
                  onChanged: (_) {
                    HapticFeedback.selectionClick();
                    themeProvider.toggleTheme();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. Section: Security & Privacy (Passcode)
          _buildSectionHeader('SECURITY & PRIVACY', isDark),
          const SizedBox(height: 8),
          Consumer<AppLockProvider>(
            builder: (context, appLockProvider, _) {
              final enabled = appLockProvider.isEnabled;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade200,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (enabled ? const Color(0xFF4CAF50) : Colors.grey)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            enabled
                                ? Icons.lock_outline_rounded
                                : Icons.lock_open_rounded,
                            color: enabled ? const Color(0xFF4CAF50) : Colors.grey,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'App Passcode Lock',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.deepCharcoal,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                enabled
                                    ? 'Passcode is active on startup'
                                    : 'Protect app with custom passcode',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (enabled
                                    ? const Color(0xFF4CAF50)
                                    : Colors.grey.shade600)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            enabled ? 'ACTIVE' : 'OFF',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: enabled
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                _showPinDialog(context, appLockProvider);
                              },
                              icon: Icon(
                                enabled ? Icons.edit_rounded : Icons.add_rounded,
                                size: 16,
                              ),
                              label: Text(
                                enabled ? 'Change Passcode' : 'Set Passcode',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (enabled) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _showDisablePinDialog(context, appLockProvider);
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.error),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                            ),
                            child: const Text(
                              'Disable',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // 6. Section: Account Actions
          _buildSectionHeader('ACCOUNT', isDark),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSettingsTile(
                  icon: Icons.logout_rounded,
                  iconColor: AppColors.error,
                  title: 'Sign Out',
                  subtitle: 'Log out of your Jayienne Link account',
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey,
                    size: 22,
                  ),
                  onTap: () => _confirmSignOut(context),
                ),
              ],
            ),
          ),

          // 7. Developer Diagnostics (Debug Mode Only)
          if (kDebugMode) ...[
            const SizedBox(height: 20),
            _buildSectionHeader('DEVELOPER DIAGNOSTICS', isDark),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.lavender.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.lavender.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Consumer<DebugProvider>(
                    builder: (context, debugProvider, _) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Simulate Offline Mode',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.deepCharcoal,
                                ),
                              ),
                              Text(
                                debugProvider.forceOfflineMode
                                    ? 'Offline simulation active'
                                    : 'Normal online operation',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: debugProvider.forceOfflineMode,
                          activeThumbColor: AppColors.lavender,
                          activeTrackColor: AppColors.lavender.withValues(alpha: 0.35),
                          onChanged: (_) {
                            debugProvider.toggleOfflineMode();
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(
                                    debugProvider.forceOfflineMode
                                        ? 'Offline mode enabled'
                                        : 'Offline mode disabled',
                                  ),
                                ),
                              );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _testSupabaseStorage(context),
                          icon: const Icon(Icons.cloud_sync_rounded, size: 16),
                          label: const Text('Test Storage', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.lavender),
                            foregroundColor: AppColors.lavender,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showStorageInfo(context),
                          icon: const Icon(Icons.info_outline_rounded, size: 16),
                          label: const Text('Storage Info', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.lavender),
                            foregroundColor: AppColors.lavender,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Preview Welcome / First Install Screen
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AuthScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.favorite_rounded, color: Color(0xFFFF758C), size: 16),
                      label: const Text(
                        'Preview Welcome Screen (First Install)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFF758C), width: 1.5),
                        foregroundColor: const Color(0xFFFF758C),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Preview Login & Register screens row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.login_rounded, size: 15),
                          label: const Text(
                            'Login Page',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.lavender),
                            foregroundColor: AppColors.lavender,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person_add_rounded, size: 15),
                          label: const Text(
                            'Register Page',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.lavender),
                            foregroundColor: AppColors.lavender,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          // 8. Footer Info
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite, size: 14, color: Color(0xFFFF758C)),
                    const SizedBox(width: 6),
                    Text(
                      'Jayienne Link v1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Crafted with love for couples 💕',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- PROFILE HEADER CARD ---
  Widget _buildProfileSummaryCard(
    BuildContext context,
    UserModel user,
    CoupleModel? couple,
    bool isDark,
    Color cardBg,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFF758C), width: 2),
            ),
            child: ClipOval(
              child: SmartProfileImage(
                imageUrl: user.photoUrl,
                width: 58,
                height: 58,
                placeholder: Container(
                  color: AppColors.softRose.withValues(alpha: 0.15),
                  child: Center(
                    child: Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: AppColors.softRose,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ),
                errorWidget: Container(
                  color: AppColors.softRose.withValues(alpha: 0.15),
                  child: const Icon(Icons.person, color: AppColors.softRose, size: 28),
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
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (couple != null ? const Color(0xFFFF758C) : Colors.grey)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    couple != null ? '💕 Coupled' : 'Single',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: couple != null ? const Color(0xFFFF758C) : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push(RouteNames.profile);
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.softRose.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_rounded, color: AppColors.softRose, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // --- VIP ADMIN HERO CARD ---
  Widget _buildAdminHeroCard(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminDashboardScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    const Color(0xFF2A1B3D),
                    const Color(0xFF1E142B),
                  ]
                : [
                    const Color(0xFFFDF0F6),
                    const Color(0xFFF3EDFD),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFA18CD1).withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFA18CD1).withValues(alpha: 0.15),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Admin Shield Badge
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),

            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Admin Dashboard',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.deepCharcoal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.lavender.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.lavender.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'VIP',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.lavender,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'User management, active toggles & media sync',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow circle
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.lavender,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SECTION HEADER ---
  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          color: isDark ? Colors.white38 : Colors.grey.shade500,
        ),
      ),
    );
  }

  // --- REUSABLE SETTINGS TILE ---
  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap != null
            ? () {
                HapticFeedback.lightImpact();
                onTap();
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  // --- REUSABLE SWITCH TILE ---
  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFFFF758C),
            activeTrackColor: const Color(0xFFFF758C).withValues(alpha: 0.35),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // --- LUXURY PASSCODE FIELD HELPER ---
  Widget _buildPinField({
    required BuildContext context,
    required String label,
    required String hintText,
    required TextEditingController controller,
    required bool obscureText,
    VoidCallback? onToggleObscure,
    ValueChanged<String>? onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppColors.deepCharcoal,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: TextInputType.visiblePassword,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : AppColors.deepCharcoal,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.grey.shade400,
            ),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFF9F7FB),
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFFFF758C),
              size: 20,
            ),
            suffixIcon: onToggleObscure != null
                ? IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                      size: 20,
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onToggleObscure();
                    },
                  )
                : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFFF758C),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- PASSCODE SETUP / CHANGE DIALOG ---
  Future<void> _showPinDialog(
    BuildContext context,
    AppLockProvider appLockProvider,
  ) async {
    final isChanging = appLockProvider.isEnabled;
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    String? errorText;
    bool isSaving = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
          final cardBg = isDark ? const Color(0xFF1E142B) : Colors.white;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            backgroundColor: cardBg,
            contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            content: SizedBox(
              width: MediaQuery.of(dialogContext).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Badge
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF758C)
                                .withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Title
                    Text(
                      isChanging ? 'Change Passcode' : 'Set App Passcode',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.deepCharcoal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Protect your private couple space with a minimum 8-character passcode.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),

                    // Inputs
                    if (isChanging) ...[
                      _buildPinField(
                        context: dialogContext,
                        label: 'Current Passcode',
                        hintText: 'Enter your existing code',
                        controller: currentPinController,
                        obscureText: obscureCurrent,
                        onToggleObscure: () {
                          setDialogState(() {
                            obscureCurrent = !obscureCurrent;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildPinField(
                      context: dialogContext,
                      label: 'New Passcode',
                      hintText: 'Minimum 8 characters',
                      controller: newPinController,
                      obscureText: obscureNew,
                      onToggleObscure: () {
                        setDialogState(() {
                          obscureNew = !obscureNew;
                        });
                      },
                      onChanged: (_) {
                        if (errorText != null) {
                          setDialogState(() {
                            errorText = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildPinField(
                      context: dialogContext,
                      label: 'Confirm New Passcode',
                      hintText: 'Re-enter your passcode',
                      controller: confirmPinController,
                      obscureText: obscureConfirm,
                      onToggleObscure: () {
                        setDialogState(() {
                          obscureConfirm = !obscureConfirm;
                        });
                      },
                      onChanged: (_) {
                        if (errorText != null) {
                          setDialogState(() {
                            errorText = null;
                          });
                        }
                      },
                    ),

                    // Error Box
                    if (errorText != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.error,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorText!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Save Button
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
                            color: const Color(0xFFFF758C)
                                .withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                HapticFeedback.mediumImpact();
                                final currentPin =
                                    currentPinController.text.trim();
                                final newPin = newPinController.text.trim();
                                final confirmPin =
                                    confirmPinController.text.trim();

                                if (isChanging && currentPin.isEmpty) {
                                  setDialogState(() {
                                    errorText =
                                        'Please enter your current passcode.';
                                  });
                                  return;
                                }

                                if (newPin.length <
                                    AppLockProvider.minPasscodeLength) {
                                  setDialogState(() {
                                    errorText =
                                        'Passcode must be at least ${AppLockProvider.minPasscodeLength} characters long.';
                                  });
                                  return;
                                }

                                if (newPin != confirmPin) {
                                  setDialogState(() {
                                    errorText = 'Passcodes do not match.';
                                  });
                                  return;
                                }

                                setDialogState(() {
                                  isSaving = true;
                                  errorText = null;
                                });

                                final success = isChanging
                                    ? await appLockProvider.changePin(
                                        currentPin,
                                        newPin,
                                        notify: false,
                                      )
                                    : await appLockProvider.setPin(
                                        newPin,
                                        notify: false,
                                      );

                                if (!dialogContext.mounted) return;

                                if (success) {
                                  Navigator.pop(dialogContext, true);
                                } else {
                                  setDialogState(() {
                                    isSaving = false;
                                    errorText = appLockProvider.error ??
                                        'Unable to save passcode.';
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isChanging
                                    ? 'Update Passcode'
                                    : 'Save & Enable Passcode',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Cancel
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: isSaving
                            ? null
                            : () => Navigator.pop(dialogContext, false),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white60
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      currentPinController.dispose();
      newPinController.dispose();
      confirmPinController.dispose();
    });

    if (result == true && context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await appLockProvider.load();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('App Passcode updated successfully!'),
                ],
              ),
              backgroundColor: Color(0xFF4CAF50),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
          );
      });
    }
  }

  // --- DISABLE PASSCODE DIALOG ---
  Future<void> _showDisablePinDialog(
    BuildContext context,
    AppLockProvider appLockProvider,
  ) async {
    final currentPinController = TextEditingController();
    bool obscureCurrent = true;
    String? errorText;
    bool isSaving = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
          final cardBg = isDark ? const Color(0xFF1E142B) : Colors.white;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            backgroundColor: cardBg,
            contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            content: SizedBox(
              width: MediaQuery.of(dialogContext).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Badge
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_open_rounded,
                        color: AppColors.error,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Title
                    Text(
                      'Disable App Passcode',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.deepCharcoal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enter your current passcode to turn off app lock protection.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),

                    _buildPinField(
                      context: dialogContext,
                      label: 'Current Passcode',
                      hintText: 'Enter your current code',
                      controller: currentPinController,
                      obscureText: obscureCurrent,
                      onToggleObscure: () {
                        setDialogState(() {
                          obscureCurrent = !obscureCurrent;
                        });
                      },
                      onChanged: (_) {
                        if (errorText != null) {
                          setDialogState(() {
                            errorText = null;
                          });
                        }
                      },
                    ),

                    if (errorText != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.error,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorText!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Disable Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                HapticFeedback.mediumImpact();
                                final currentPin =
                                    currentPinController.text.trim();
                                if (currentPin.isEmpty) {
                                  setDialogState(() {
                                    errorText =
                                        'Please enter your current passcode.';
                                  });
                                  return;
                                }

                                setDialogState(() {
                                  isSaving = true;
                                  errorText = null;
                                });

                                final success =
                                    await appLockProvider.disablePin(
                                  currentPin,
                                  notify: false,
                                );

                                if (!dialogContext.mounted) return;

                                if (success) {
                                  Navigator.pop(dialogContext, true);
                                } else {
                                  setDialogState(() {
                                    isSaving = false;
                                    errorText = appLockProvider.error ??
                                        'Unable to disable passcode.';
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Disable Passcode Lock',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Cancel Button
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: isSaving
                            ? null
                            : () => Navigator.pop(dialogContext, false),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white60
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      currentPinController.dispose();
    });

    if (result == true && context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await appLockProvider.load();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('App Passcode disabled'),
                ],
              ),
              backgroundColor: Color(0xFF1E142B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
          );
      });
    }
  }

  void _confirmSignOut(BuildContext context) {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E142B) : Colors.white,
        title: const Text(AppStrings.signOut, style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(AppStrings.signOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(AppStrings.signOut),
          ),
        ],
      ),
    );
  }

  String _formatAnniversary(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  Future<void> _requestAnniversary(
    BuildContext context,
    UserModel user,
    CoupleModel couple,
  ) async {
    HapticFeedback.lightImpact();
    if (couple.id == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Couple not ready. Try again.')),
        );
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: couple.anniversary ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;
    if (!context.mounted) return;

    final coupleProvider = context.read<CoupleProvider>();
    final partnerId = couple.getPartnerId(user.id);
    if (partnerId.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Partner not found.')),
        );
      return;
    }
    final success = await coupleProvider.sendAnniversaryRequest(
      coupleId: couple.id!,
      proposerId: user.id,
      partnerId: partnerId,
      proposedDate: picked,
    );

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Anniversary request sent')),
        );
    } else if (coupleProvider.error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(coupleProvider.error!)));
    }
  }

  void _showStorageInfo(BuildContext context) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E142B) : Colors.white,
        title: const Text('Profile Image Storage', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Supabase Storage System:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                  '• Primary: Supabase Storage - Best performance, supports images & videos'),
              Text(
                  '• Fallback: Optimized Base64 - Always available, stored in user profile'),
              SizedBox(height: 16),
              Text(
                'Current Status:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('✅ Images work regardless of setup'),
              Text('✅ Automatic service selection and fallbacks'),
              Text('✅ Display on map markers for you and your partner'),
              Text('✅ Automatic optimization for best performance'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  void _testSupabaseStorage(BuildContext context) async {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E142B) : Colors.white,
        title: const Text('Testing Supabase Storage', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFFF758C)),
            SizedBox(height: 16),
            Text('Checking Supabase connectivity...'),
          ],
        ),
      ),
    );

    try {
      final supabaseService = SupabaseStorageService();
      final isConnected = await supabaseService.testConnectivity();
      final isInitialized = await supabaseService.initializeStorage();
      final stats = await supabaseService.getStorageStats();

      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Show results
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: isDark ? const Color(0xFF1E142B) : Colors.white,
            title: const Text('Storage Test Results', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConnected
                        ? '✅ Connection: SUCCESS'
                        : '❌ Connection: FAILED',
                    style: TextStyle(
                      color: isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isInitialized
                        ? '✅ Storage Bucket: READY'
                        : '❌ Storage Bucket: SETUP NEEDED',
                    style: TextStyle(
                      color: isInitialized ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Storage Statistics:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (stats['error'] == null) ...[
                    Text('Files: ${stats['total_files'] ?? 'N/A'}'),
                    Text('Size: ${stats['total_size_mb'] ?? 'N/A'} MB'),
                    Text('Bucket: ${stats['bucket_name'] ?? 'N/A'}'),
                  ] else
                    Text('Error: ${stats['error']}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Supabase test failed: $e');
      }
    }
  }
}
