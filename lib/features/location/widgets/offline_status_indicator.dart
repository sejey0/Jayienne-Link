import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../models/location_model.dart';
import '../../../providers/location_provider.dart';

/// Shows sync status - synced, pending, syncing, or offline.
/// Displays as a small chip or banner depending on style.
class OfflineStatusIndicator extends StatelessWidget {
  final OfflineIndicatorStyle style;
  final VoidCallback? onTap;

  const OfflineStatusIndicator({
    super.key,
    this.style = OfflineIndicatorStyle.chip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocationProvider>();
    final syncStatus = provider.syncStatus;
    final pendingCount = provider.pendingSyncCount;
    final isOnline = provider.isOnline;

    if (style == OfflineIndicatorStyle.banner) {
      return _buildBanner(context, syncStatus, pendingCount, isOnline);
    }

    return _buildChip(context, syncStatus, pendingCount, isOnline);
  }

  Widget _buildChip(
    BuildContext context,
    SyncStatus status,
    int pendingCount,
    bool isOnline,
  ) {
    final (icon, label, color, showAnimation) = _getStatusInfo(
      status,
      pendingCount,
      isOnline,
    );

    Widget chip = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingSm,
          vertical: AppDimensions.spacingXs,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSmall),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );

    if (showAnimation && status == SyncStatus.syncing) {
      return chip.animate(onPlay: (c) => c.repeat()).shimmer(
            duration: const Duration(milliseconds: 1500),
            color: color.withOpacity(0.3),
          );
    }

    return chip;
  }

  Widget _buildBanner(
    BuildContext context,
    SyncStatus status,
    int pendingCount,
    bool isOnline,
  ) {
    // Only show banner for offline or pending states
    if (status == SyncStatus.synced && isOnline) {
      return const SizedBox.shrink();
    }

    final (icon, label, color, _) = _getStatusInfo(
      status,
      pendingCount,
      isOnline,
    );

    String message;
    if (!isOnline) {
      message = 'You\'re offline. Locations are being saved locally.';
    } else if (status == SyncStatus.syncing) {
      message = 'Syncing your locations with your person...';
    } else if (status == SyncStatus.pending) {
      message =
          '$pendingCount location${pendingCount > 1 ? 's' : ''} waiting to sync';
    } else if (status == SyncStatus.error) {
      message = 'Sync failed. Tap to retry.';
    } else {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingSm,
        ),
        color: color.withOpacity(0.1),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                    ),
              ),
            ),
            if (status == SyncStatus.syncing)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
          ],
        ),
      ),
    );
  }

  (IconData, String, Color, bool) _getStatusInfo(
    SyncStatus status,
    int pendingCount,
    bool isOnline,
  ) {
    if (!isOnline) {
      return (
        Icons.cloud_off_outlined,
        'Offline mode',
        AppColors.warning,
        false,
      );
    }

    switch (status) {
      case SyncStatus.synced:
        return (
          Icons.cloud_done_outlined,
          'Synced',
          AppColors.success,
          false,
        );
      case SyncStatus.pending:
        return (
          Icons.cloud_upload_outlined,
          'Pending ($pendingCount)',
          AppColors.warning,
          false,
        );
      case SyncStatus.syncing:
        return (
          Icons.cloud_sync_outlined,
          'Syncing...',
          AppColors.lavender,
          true,
        );
      case SyncStatus.offline:
        return (
          Icons.cloud_off_outlined,
          'Offline',
          AppColors.warning,
          false,
        );
      case SyncStatus.error:
        return (
          Icons.cloud_off_outlined,
          'Sync failed',
          AppColors.error,
          false,
        );
    }
  }
}

/// Style options for the offline indicator
enum OfflineIndicatorStyle {
  chip, // Small chip for headers/toolbars
  banner, // Full-width banner for screen tops
}

/// Persistent offline banner for screens
class OfflineBanner extends StatelessWidget {
  final VoidCallback? onRetry;

  const OfflineBanner({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocationProvider>();

    if (provider.isOnline && provider.syncStatus == SyncStatus.synced) {
      return const SizedBox.shrink();
    }

    return OfflineStatusIndicator(
      style: OfflineIndicatorStyle.banner,
      onTap: () {
        if (provider.isOnline && provider.syncStatus == SyncStatus.pending) {
          provider.syncLocations();
        }
        onRetry?.call();
      },
    );
  }
}

/// Animated connection status dot
class ConnectionStatusDot extends StatelessWidget {
  const ConnectionStatusDot({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocationProvider>();
    final isOnline = provider.isOnline;

    Widget dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? AppColors.success : AppColors.warning,
      ),
    );

    if (!isOnline) {
      return dot
          .animate(onPlay: (controller) => controller.repeat())
          .fadeIn(duration: const Duration(milliseconds: 500))
          .then()
          .fadeOut(duration: const Duration(milliseconds: 500));
    }

    return dot;
  }
}
