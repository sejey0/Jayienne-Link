import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/location_provider.dart';
import '../../../services/offline_location_service.dart';

/// Heart-shaped toggle for location sharing.
/// Shows pulsing heart when active, grey heart when paused.
class LocationShareToggle extends StatelessWidget {
  final VoidCallback? onPermissionRequired;

  const LocationShareToggle({
    super.key,
    this.onPermissionRequired,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocationProvider>();
    final isSharing = provider.isSharingEnabled;
    final canShare = provider.canShare;
    final permissionStatus = provider.permissionStatus;

    return GestureDetector(
      onTap: () => _handleTap(context, provider, permissionStatus),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isSharing
              ? AppColors.softRose.withValues(alpha: 0.16)
              : const Color(0xFFF4F2F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSharing
                ? AppColors.softRose.withValues(alpha: 0.5)
                : const Color(0xFFE2DEEA),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeartIcon(context, isSharing, canShare),
            const SizedBox(width: 12),
            Expanded(child: _buildStatusText(context, isSharing, canShare, provider)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeartIcon(BuildContext context, bool isSharing, bool canShare) {
    final icon = Icon(
      isSharing ? Icons.favorite : Icons.favorite_border,
      color: isSharing ? AppColors.softRose : Colors.grey.shade400,
      size: 26,
    );

    if (isSharing) {
      // Pulsing animation when sharing
      return icon
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.15, 1.15),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
    }

    return icon;
  }

  Widget _buildStatusText(
    BuildContext context,
    bool isSharing,
    bool canShare,
    LocationProvider provider,
  ) {
    String text;

    if (!provider.isOnline) {
      text = 'Offline only';
    } else if (!provider.hasPartner) {
      text = 'Link with your person first';
    } else if (!provider.permissionStatus.canTrack) {
      text = 'Enable location access';
    } else if (isSharing) {
      text = 'Sharing location';
    } else {
      text = 'Location paused';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF1E142B),
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
        if (isSharing && provider.isOnline)
          Text(
            'Your person can see where you are',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11.5,
            ),
          ),
        if (isSharing && !provider.isOnline)
          const Text(
            'Saving offline - will sync later',
            style: TextStyle(
              color: AppColors.warning,
              fontSize: 11.5,
            ),
          ),
      ],
    );
  }

  void _handleTap(
    BuildContext context,
    LocationProvider provider,
    LocationPermissionStatus status,
  ) async {
    // Offline notice
    if (!provider.isOnline) {
      SnackbarHelper.showInfo(
        context,
        'Offline only. Connect to the internet to share location.',
        title: 'Offline Notice',
      );
      return;
    }

    // Check if partner is linked
    if (!provider.hasPartner) {
      SnackbarHelper.showInfo(
        context,
        'Link with your person first to share location.',
        title: 'Partner Link Required',
      );
      return;
    }

    // Check permissions
    if (!status.canTrack) {
      if (status == LocationPermissionStatus.deniedForever) {
        // Show dialog to open settings
        _showPermissionDialog(context, provider);
        return;
      }

      // Request permission
      final granted = await provider.requestPermission();
      if (!granted) {
        onPermissionRequired?.call();
        return;
      }
    }

    // Toggle sharing
    await provider.toggleSharing();
  }

  void _showPermissionDialog(BuildContext context, LocationProvider provider) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1C1427) : Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
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
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.location_off_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Location Permission Needed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.deepCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'To share real-time location with your partner, please enable location access in device settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
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
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        provider.openSettings();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Settings',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
  }
}

/// Compact version for toolbar/header
class LocationShareToggleCompact extends StatelessWidget {
  const LocationShareToggleCompact({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocationProvider>();
    final isSharing = provider.isSharingEnabled;

    return IconButton(
      onPressed: provider.canShare ? () => provider.toggleSharing() : null,
      icon: Icon(
        isSharing ? Icons.location_on : Icons.location_off,
        color: isSharing ? AppColors.softRose : Colors.grey,
      ),
      tooltip: isSharing ? 'Sharing location' : 'Location paused',
    );
  }
}
