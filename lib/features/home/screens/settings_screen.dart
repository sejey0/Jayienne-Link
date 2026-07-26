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
import '../../../providers/app_lock_provider.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/debug_provider.dart';
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
          Consumer<AppLockProvider>(
            builder: (context, appLockProvider, _) {
              final enabled = appLockProvider.isEnabled;
              return Column(
                children: [
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('App Lock'),
                    subtitle: Text(
                      enabled
                          ? 'Password required after login until you unlock the app.'
                          : 'Add a password to lock the app after login.',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingLg,
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton(
                          onPressed: () =>
                              _showPinDialog(context, appLockProvider),
                          child: Text(
                              enabled ? 'Change Password' : 'Set Password'),
                        ),
                        if (enabled)
                          OutlinedButton(
                            onPressed: () =>
                                _showDisablePinDialog(context, appLockProvider),
                            child: const Text('Disable Password'),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
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
                  // Offline Mode Test Toggle
                  Consumer<DebugProvider>(
                    builder: (context, debugProvider, _) => SwitchListTile(
                      title: const Text('Simulate Offline Mode'),
                      subtitle: Text(
                        debugProvider.forceOfflineMode
                            ? 'Offline mode ON - Test offline features'
                            : 'Online mode - Normal operation',
                      ),
                      value: debugProvider.forceOfflineMode,
                      onChanged: (_) {
                        debugProvider.toggleOfflineMode();
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                debugProvider.forceOfflineMode
                                    ? 'Offline mode enabled - WiFi will not be used'
                                    : 'Offline mode disabled - Normal operation',
                              ),
                            ),
                          );
                      },
                    ),
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

  Widget _buildPinField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    VoidCallback? onToggleObscure,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: TextInputType.visiblePassword,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: onToggleObscure,
              )
            : null,
      ),
    );
  }

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
          return AlertDialog(
            title:
                Text(isChanging ? 'Change Passcode' : 'Set Passcode'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isChanging) ...[
                    _buildPinField(
                      label: 'Current Passcode',
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
                    label: 'New Passcode (min 8 chars)',
                    controller: newPinController,
                    obscureText: obscureNew,
                    onToggleObscure: () {
                      setDialogState(() {
                        obscureNew = !obscureNew;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildPinField(
                    label: 'Confirm Passcode',
                    controller: confirmPinController,
                    obscureText: obscureConfirm,
                    onToggleObscure: () {
                      setDialogState(() {
                        obscureConfirm = !obscureConfirm;
                      });
                    },
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    isSaving ? null : () => Navigator.pop(dialogContext, false),
                child: const Text(AppStrings.cancel),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final currentPin = currentPinController.text.trim();
                        final newPin = newPinController.text.trim();
                        final confirmPin = confirmPinController.text.trim();

                        if (isChanging && currentPin.isEmpty) {
                          setDialogState(() {
                            errorText = 'Enter your current passcode.';
                          });
                          return;
                        }

                        if (newPin.length < AppLockProvider.minPasscodeLength) {
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
                child: isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
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
            const SnackBar(content: Text('App password saved')),
          );
      });
    }
  }

  Future<void> _showDisablePinDialog(
    BuildContext context,
    AppLockProvider appLockProvider,
  ) async {
    final currentPinController = TextEditingController();
    String? errorText;
    bool isSaving = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Disable App Password'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPinField(
                    label: 'Current Password',
                    controller: currentPinController,
                    obscureText: true,
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    isSaving ? null : () => Navigator.pop(dialogContext, false),
                child: const Text(AppStrings.cancel),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final currentPin = currentPinController.text.trim();
                        if (currentPin.isEmpty) {
                          setDialogState(() {
                            errorText = 'Enter your current password.';
                          });
                          return;
                        }

                        setDialogState(() {
                          isSaving = true;
                          errorText = null;
                        });

                        final success = await appLockProvider.disablePin(
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
                                'Unable to disable password.';
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Disable'),
              ),
            ],
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
            const SnackBar(content: Text('App password disabled')),
          );
      });
    }
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
