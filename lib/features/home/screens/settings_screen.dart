import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../utils/firebase_debug.dart';
import '../../../services/storage_service.dart';
import '../../../services/supabase_storage_service.dart';
import '../../migration/migration_manager_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings)),
      body: ListView(
        children: [
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
                    onPressed: () => _testFirebaseStorage(context),
                    child: const Text('Test Firebase Storage'),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  ElevatedButton(
                    onPressed: () => _testSupabaseStorage(context),
                    child: const Text('Test Supabase Storage'),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  ElevatedButton(
                    onPressed: () => _showStorageInfo(context),
                    child: const Text('Storage Information'),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  ElevatedButton(
                    onPressed: () => _testAllStorage(context),
                    child: const Text('Test All Storage Services'),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MigrationManagerScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.sync_alt),
                    label: const Text('Firebase → Supabase Migration'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
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

  void _testFirebaseStorage(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Testing Firebase Storage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Running diagnostics...'),
          ],
        ),
      ),
    );

    try {
      final diagnosis = await FirebaseDebugUtils.diagnoseStorageIssue();

      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Show results
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Firebase Storage Test Results'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Firebase Initialized: ${diagnosis['firebase_initialized']}'),
                  Text('Project ID: ${diagnosis['project_id'] ?? 'N/A'}'),
                  Text(
                      'Storage Bucket: ${diagnosis['storage_bucket'] ?? 'N/A'}'),
                  const SizedBox(height: 8),
                  Text(
                    diagnosis['can_upload'] == true
                        ? '✅ Upload Test: PASSED'
                        : '❌ Upload Test: FAILED',
                    style: TextStyle(
                      color: diagnosis['can_upload'] == true
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (diagnosis['upload_error'] != null) ...[
                    const SizedBox(height: 8),
                    Text('Error: ${diagnosis['upload_error']}'),
                    Text('Error Code: ${diagnosis['upload_error_code']}'),
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
        SnackbarHelper.showError(context, 'Test failed: $e');
      }
    }
  }

  void _showStorageRules(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suggested Firebase Storage Rules'),
        content: SingleChildScrollView(
          child: Text(
            FirebaseDebugUtils.getSuggestedStorageRules(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
                'Multi-Tier Storage System:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Supabase Storage (Primary): Best performance, supports images & videos'),
              Text('2. Firebase Storage (Fallback): Good performance, images only'),
              Text('3. Optimized Base64 (Final): Always works, stored in user profile'),
              SizedBox(height: 16),
              Text(
                'Current Status:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('✅ Images work regardless of backend limitations'),
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

  void _testAllStorage(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Testing All Storage Services'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Testing storage services...'),
          ],
        ),
      ),
    );

    try {
      final storageService = StorageService();
      final results = await storageService.testAllStorageConnectivity();

      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Show results
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('All Storage Services Test'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    results['supabase'] == true
                        ? '✅ Supabase Storage: AVAILABLE'
                        : '❌ Supabase Storage: ${results['supabase_error'] ?? 'UNAVAILABLE'}',
                    style: TextStyle(
                      color: results['supabase'] == true ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    results['firebase'] == true
                        ? '✅ Firebase Storage: AVAILABLE'
                        : '❌ Firebase Storage: ${results['firebase_error'] ?? 'UNAVAILABLE'}',
                    style: TextStyle(
                      color: results['firebase'] == true ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '✅ Base64 Fallback: ALWAYS AVAILABLE',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Active Service: ${results['active_service'] ?? 'Base64 Fallback'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'The app will automatically use the best available service for uploads.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
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
        SnackbarHelper.showError(context, 'Storage test failed: $e');
      }
    }
  }
}
