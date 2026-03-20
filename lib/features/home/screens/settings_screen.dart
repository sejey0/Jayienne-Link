import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../utils/firebase_debug.dart';

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
                    onPressed: () => _showStorageRules(context),
                    child: const Text('Show Storage Rules'),
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
}
