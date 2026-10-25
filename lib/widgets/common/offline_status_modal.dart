import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/debug_provider.dart';
import 'timed_confirm_dialog.dart';

/// Shows the official application offline modal.
/// Accurately displays the state of the network (real Wi-Fi/Mobile data vs. simulated offline).
Future<void> showOfflineModal(
  BuildContext context, {
  bool isPreview = false,
}) async {
  HapticFeedback.mediumImpact();
  final isDark = Theme.of(context).brightness == Brightness.dark;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _OfflineStatusDialog(
      isDark: isDark,
      isPreview: isPreview,
    ),
  );
}

class _OfflineStatusDialog extends StatefulWidget {
  final bool isDark;
  final bool isPreview;

  const _OfflineStatusDialog({
    required this.isDark,
    this.isPreview = false,
  });

  @override
  State<_OfflineStatusDialog> createState() => _OfflineStatusDialogState();
}

class _OfflineStatusDialogState extends State<_OfflineStatusDialog> {
  bool _isChecking = false;

  Future<void> _handleRetryConnection(BuildContext context) async {
    setState(() => _isChecking = true);
    HapticFeedback.lightImpact();

    ConnectivityProvider? connectivityProv;
    try {
      connectivityProv = context.read<ConnectivityProvider>();
    } catch (_) {}
    final debugProv = context.read<DebugProvider>();

    await Future.delayed(const Duration(milliseconds: 650));
    final isOnline = connectivityProv != null
        ? await connectivityProv.checkConnectivity()
        : false;

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (debugProv.forceOfflineMode) {
      SnackbarHelper.showInfo(
        context,
        'Simulated Offline Mode is currently active in Admin Console.',
      );
      return;
    }

    if (isOnline) {
      Navigator.of(context, rootNavigator: true).pop();
      SnackbarHelper.showSuccess(
        context,
        'Connection restored! Live sync is active.',
      );
    } else {
      SnackbarHelper.showError(
        context,
        'Still disconnected. Please check your Wi-Fi or Cellular Data.',
      );
    }
  }

  void _handleTurnOffSimulation(BuildContext context) {
    HapticFeedback.mediumImpact();
    final debugProv = context.read<DebugProvider>();
    debugProv.setOfflineMode(false);
    Navigator.of(context, rootNavigator: true).pop();
    SnackbarHelper.showSuccess(
      context,
      'Simulated offline mode disabled. Live network restored.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    ConnectivityProvider? connectivity;
    try {
      connectivity = Provider.of<ConnectivityProvider>(context, listen: true);
    } catch (_) {}
    final debugProvider = context.watch<DebugProvider>();

    final isSimulated = debugProvider.forceOfflineMode;
    final isWifi = connectivity?.isWifi ?? false;
    final isMobileData = connectivity?.isMobileData ?? false;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1C1427) : Colors.white,
      surfaceTintColor: Colors.transparent,
      contentPadding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circular Icon Badge (Adhering to No Emojis Rule)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: Color(0xFFFF5252),
                size: 34,
              ),
            ),
            const SizedBox(height: 16),

            // Modal Title
            Text(
              isSimulated
                  ? 'Simulated Offline Mode'
                  : 'No Internet Connection',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : AppColors.deepCharcoal,
              ),
            ),
            const SizedBox(height: 8),

            // Source indicator chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                color: isSimulated
                    ? const Color(0xFFA18CD1).withValues(alpha: 0.16)
                    : const Color(0xFFFF5252).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSimulated
                      ? const Color(0xFFA18CD1).withValues(alpha: 0.4)
                      : const Color(0xFFFF5252).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSimulated
                        ? Icons.developer_mode_rounded
                        : Icons.signal_cellular_connected_no_internet_4_bar_rounded,
                    size: 13,
                    color: isSimulated
                        ? const Color(0xFFA18CD1)
                        : const Color(0xFFFF5252),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isSimulated
                        ? 'Simulated Disconnect (Admin Console)'
                        : 'Device Disconnected (No Data or Wi-Fi)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSimulated
                          ? (isDark ? const Color(0xFFD4C7F5) : const Color(0xFF6B4FA0))
                          : const Color(0xFFFF5252),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Explanatory Message
            Text(
              'The application cannot reach cloud services. Live partner tracking, telemetry, and background synchronization are temporarily paused.\n\nYou can continue accessing local memories and cached features. Any newly drafted notes or letters are saved offline and will auto-sync once connected.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),

            // Network Hardware & Sync Breakdown Container
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF7F8FC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  _StatusRow(
                    icon: Icons.wifi_rounded,
                    label: 'Wi-Fi Status',
                    value: isSimulated
                        ? 'Simulated Blocked'
                        : (isWifi ? 'Connected' : 'Disconnected'),
                    isPositive: !isSimulated && isWifi,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 7),
                  _StatusRow(
                    icon: Icons.signal_cellular_alt_rounded,
                    label: 'Cellular Data',
                    value: isSimulated
                        ? 'Simulated Blocked'
                        : (isMobileData ? 'Connected' : 'Disconnected'),
                    isPositive: !isSimulated && isMobileData,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 7),
                  _StatusRow(
                    icon: Icons.sync_disabled_rounded,
                    label: 'Firebase & Supabase',
                    value: 'Paused (Offline)',
                    isPositive: false,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 7),
                  _StatusRow(
                    icon: Icons.storage_rounded,
                    label: 'Local SQLite Storage',
                    value: 'Active & Ready',
                    isPositive: true,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action 1: Standard Signature Gradient Primary Button (Try Reconnecting)
            Container(
              width: double.infinity,
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
                    color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _isChecking ? null : () => _handleRetryConnection(context),
                icon: _isChecking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                label: Text(
                  _isChecking ? 'Checking Network...' : 'Try Reconnecting',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            // Action 2: If in Simulated Mode, provide direct button to disable simulation
            if (isSimulated) ...[
              const SizedBox(height: 9),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: () => _handleTurnOffSimulation(context),
                  icon: const Icon(
                    Icons.power_settings_new_rounded,
                    size: 16,
                    color: Color(0xFFA18CD1),
                  ),
                  label: const Text(
                    'Turn Off Offline Simulation',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: Color(0xFFA18CD1),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFA18CD1), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 9),

            // Action 3: Secondary Cancel / Dismiss Button
            SecondaryCancelButton(
              label: 'Continue in Offline Mode',
              icon: Icons.arrow_forward_rounded,
              height: 44,
              borderRadius: 14,
              fontSize: 13,
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isPositive;
  final bool isDark;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isPositive,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isPositive
        ? const Color(0xFF27AE60)
        : (value.contains('Simulated')
            ? const Color(0xFFA18CD1)
            : const Color(0xFFFF5252));

    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark ? Colors.white54 : Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: statusColor,
          ),
        ),
      ],
    );
  }
}
