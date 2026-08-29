import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
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
          horizontal: AppDimensions.spacingLg,
          vertical: AppDimensions.spacingMd,
        ),
        decoration: BoxDecoration(
          color: isSharing
              ? AppColors.softRose.withOpacity(0.15)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLarge),
          border: Border.all(
            color: isSharing
                ? AppColors.softRose.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeartIcon(context, isSharing, canShare),
            const SizedBox(width: AppDimensions.spacingSm),
            _buildStatusText(context, isSharing, canShare, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildHeartIcon(BuildContext context, bool isSharing, bool canShare) {
    final icon = Icon(
      isSharing ? Icons.favorite : Icons.favorite_border,
      color: isSharing ? AppColors.softRose : Colors.grey,
      size: 28,
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
    Color textColor;

    if (!provider.isOnline) {
      text = 'Offline only';
      textColor = AppColors.warning;
    } else if (!provider.hasPartner) {
      text = 'Link with your person first';
      textColor = Colors.grey;
    } else if (!provider.permissionStatus.canTrack) {
      text = 'Enable location access';
      textColor = AppColors.warning;
    } else if (isSharing) {
      text = 'Sharing location';
      textColor = AppColors.softRose;
    } else {
      text = 'Location paused';
      textColor = Colors.grey;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
        ),
        if (isSharing && provider.isOnline)
          Text(
            'Your person can see where you are',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor.withOpacity(0.7),
                ),
          ),
        if (isSharing && !provider.isOnline)
          Text(
            'Saving offline - will sync later',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.warning,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Needed'),
        content: const Text(
          'To share your location with your person, please enable '
          'location access in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.openSettings();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.softRose),
            child: const Text('Open Settings'),
          ),
        ],
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
