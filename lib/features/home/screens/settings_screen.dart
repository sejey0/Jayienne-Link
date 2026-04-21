import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/couple_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/supabase_storage_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final user = userProvider.user;
    final couple = coupleProvider.couple;
    final pendingAnniversary =
        coupleProvider.outgoingAnniversaryRequests.isNotEmpty
            ? coupleProvider.outgoingAnniversaryRequests.first
            : null;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings)),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Edit Profile'),
            subtitle: const Text('View or edit your profile'),
            onTap: null,
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(RouteNames.profile),
            ),
          ),
          if (user != null) ...[
            ListTile(
              title: const Text('Update Anniversary'),
              subtitle: Text(
                couple == null
                    ? 'Link with your partner to set one'
                    : pendingAnniversary != null
                        ? 'Request pending for ${_formatAnniversary(pendingAnniversary.proposedDate)}'
                        : couple.anniversary != null
                            ? 'Current: ${_formatAnniversary(couple.anniversary!)}'
                            : 'Not set',
              ),
              onTap: null,
              trailing: IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  color: couple == null ? Colors.grey.shade400 : null,
                ),
                onPressed: couple == null
                    ? null
                    : () => _requestAnniversary(context, user, couple),
              ),
            ),
          ],
          SwitchListTile(
            title: const Text(AppStrings.darkMode),
            secondary: Icon(
              themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            ),
            value: themeProvider.isDarkMode,
            onChanged: (_) => themeProvider.toggleTheme(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text(AppStrings.signOut),
            onTap: () => _confirmSignOut(context),
          ),
          // Debug section (only visible in debug mode)
          if (kDebugMode) ...[
            const Divider(),
            const ListTile(
              leading: Icon(Icons.bug_report),
              title: Text('Debug Tools'),
              subtitle: Text('Development only'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingLg),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () => _testSupabaseStorage(context),
                    child: const Text('Test Supabase Storage'),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  ElevatedButton(
                    onPressed: () => _showStorageInfo(context),
                    child: const Text('Storage Information'),
                  ),
                ],
              ),
            ),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: Text(
              '${AppStrings.appVersion} 1.0.0',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.signOut),
        content: const Text(AppStrings.signOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().signOut();
            },
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile Image Storage'),
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
              SizedBox(height: 16),
              Text(
                'To setup Supabase (recommended):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Create a Supabase project at supabase.com'),
              Text('2. Create a "profile-photos" storage bucket'),
              Text('3. Configure your .env file with project credentials'),
              Text('4. Run storage tests to verify setup'),
              SizedBox(height: 16),
              Text(
                'Note: The app works perfectly without any setup!',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
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
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Testing Supabase Storage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
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
            title: const Text('Supabase Storage Test Results'),
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
                  if (!isConnected || !isInitialized) ...[
                    const SizedBox(height: 16),
                    const Text('Setup Instructions:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('1. Create Supabase project'),
                    const Text('2. Create "profile-photos" bucket'),
                    const Text('3. Update .env file with credentials'),
                    const Text('4. Restart the app'),
                  ],
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
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Show error
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Supabase test failed: $e');
      }
    }
  }
}
