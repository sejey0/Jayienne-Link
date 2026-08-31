import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/snackbar_helper.dart';

/// Data model for version.json hosted on GitHub Raw
class AppVersionInfo {
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String releaseNotes;
  final String? minRequiredVersion;
  final bool forceUpdate;

  const AppVersionInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    this.minRequiredVersion,
    this.forceUpdate = true,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      version: json['version'] as String? ?? '1.0.0',
      buildNumber: json['build_number'] as int? ?? 1,
      downloadUrl: json['download_url'] as String? ?? '',
      releaseNotes: json['release_notes'] as String? ?? 'Exciting new improvements and bug fixes.',
      minRequiredVersion: json['min_required_version'] as String?,
      forceUpdate: json['force_update'] as bool? ?? true,
    );
  }
}

/// Service to handle in-app OTA version checks and forced updates
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  /// Default GitHub raw JSON URL
  /// Users can replace YOUR_GITHUB_USERNAME and YOUR_REPO_NAME or use this default.
  static const String defaultVersionUrl =
      'https://raw.githubusercontent.com/sejey0/Jayienne-Link/main/version.json';

  bool _isChecking = false;
  bool _isDialogOpen = false;

  /// Check GitHub for latest version and display non-dismissible dialog if outdated
  Future<void> checkForUpdates(
    BuildContext context, {
    bool isManualCheck = false,
    String versionUrl = defaultVersionUrl,
  }) async {
    if (_isChecking || _isDialogOpen) return;
    _isChecking = true;

    try {
      final remoteInfo = await _fetchRemoteVersion(versionUrl);
      if (remoteInfo == null) {
        if (isManualCheck && context.mounted) {
          SnackbarHelper.showError(context, 'Unable to check for updates. Please check your internet connection.');
        }
        return;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      final updateNeeded = _isUpdateRequired(
        currentVersion: currentVersion,
        currentBuild: currentBuildNumber,
        remoteVersion: remoteInfo.version,
        remoteBuild: remoteInfo.buildNumber,
      );

      if (updateNeeded) {
        if (context.mounted && !_isDialogOpen) {
          _isDialogOpen = true;
          await showDialog(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.black.withValues(alpha: 0.85),
            builder: (dialogContext) => PopScope(
              canPop: false,
              child: _ForcedUpdateDialog(
                updateInfo: remoteInfo,
                currentVersion: currentVersion,
              ),
            ),
          );
          _isDialogOpen = false;
        }
      } else {
        if (isManualCheck && context.mounted) {
          SnackbarHelper.showSuccess(
            context,
            'You are using the latest version of Jayienne Link (v$currentVersion).',
          );
        }
      }
    } catch (e) {
      debugPrint('[UpdateService] Error checking for updates: $e');
      if (isManualCheck && context.mounted) {
        SnackbarHelper.showError(context, 'Failed to check for updates: $e');
      }
    } finally {
      _isChecking = false;
    }
  }

  /// Fetch remote version JSON
  Future<AppVersionInfo?> _fetchRemoteVersion(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return AppVersionInfo.fromJson(data);
      } else {
        debugPrint('[UpdateService] Failed to load version.json: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[UpdateService] Network error fetching version info: $e');
    }
    return null;
  }

  /// Compare semantic versions (e.g. 1.0.1 vs 1.0.0) or build numbers
  bool _isUpdateRequired({
    required String currentVersion,
    required int currentBuild,
    required String remoteVersion,
    required int remoteBuild,
  }) {
    // 1. Compare build number first if available
    if (remoteBuild > currentBuild && currentBuild > 0) {
      return true;
    }

    // 2. Semantic version comparison
    final currentParts = currentVersion.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final remoteParts = remoteVersion.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    while (currentParts.length < 3) {
      currentParts.add(0);
    }
    while (remoteParts.length < 3) {
      remoteParts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (remoteParts[i] > currentParts[i]) {
        return true;
      } else if (remoteParts[i] < currentParts[i]) {
        return false;
      }
    }

    return false;
  }
}

/// Non-dismissible Forced Update Dialog with live download progress
class _ForcedUpdateDialog extends StatefulWidget {
  final AppVersionInfo updateInfo;
  final String currentVersion;

  const _ForcedUpdateDialog({
    required this.updateInfo,
    required this.currentVersion,
  });

  @override
  State<_ForcedUpdateDialog> createState() => _ForcedUpdateDialogState();
}

enum _UpdateProgressState { idle, downloading, installing, error }

class _ForcedUpdateDialogState extends State<_ForcedUpdateDialog> {
  _UpdateProgressState _state = _UpdateProgressState.idle;
  int _downloadPercentage = 0;
  String _statusMessage = '';
  StreamSubscription<OtaEvent>? _otaSubscription;

  @override
  void dispose() {
    _otaSubscription?.cancel();
    super.dispose();
  }

  void _startOtaUpdate() {
    if (widget.updateInfo.downloadUrl.isEmpty) {
      setState(() {
        _state = _UpdateProgressState.error;
        _statusMessage = 'Download link is missing or invalid. Please check GitHub Releases.';
      });
      return;
    }

    setState(() {
      _state = _UpdateProgressState.downloading;
      _downloadPercentage = 0;
      _statusMessage = 'Starting update download...';
    });

    HapticFeedback.mediumImpact();

    try {
      _otaSubscription?.cancel();
      _otaSubscription = OtaUpdate()
          .execute(
            widget.updateInfo.downloadUrl,
            destinationFilename: 'jayienne_link_update.apk',
          )
          .listen(
        (OtaEvent event) {
          if (!mounted) return;

          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final percent = int.tryParse(event.value ?? '0') ?? _downloadPercentage;
              setState(() {
                _state = _UpdateProgressState.downloading;
                _downloadPercentage = percent;
                _statusMessage = 'Downloading update ($percent%)...';
              });
              break;

            case OtaStatus.INSTALLING:
            case OtaStatus.INSTALLATION_DONE:
              setState(() {
                _state = _UpdateProgressState.installing;
                _downloadPercentage = 100;
                _statusMessage = 'Launching installer... Please tap "Install" on your screen.';
              });
              break;

            case OtaStatus.ALREADY_RUNNING_ERROR:
              setState(() {
                _statusMessage = 'Download already in progress...';
              });
              break;

            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              setState(() {
                _state = _UpdateProgressState.error;
                _statusMessage =
                    'Install permission not granted. Please allow "Install unknown apps" for Jayienne Link in Settings and retry.';
              });
              break;

            case OtaStatus.INTERNAL_ERROR:
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.CHECKSUM_ERROR:
            case OtaStatus.INSTALLATION_ERROR:
              setState(() {
                _state = _UpdateProgressState.error;
                _statusMessage = 'Failed to download or install update (${event.status.name}). Please check internet and retry.';
              });
              break;

            default:
              break;
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _state = _UpdateProgressState.error;
            _statusMessage = 'Update error: $error';
          });
        },
      );
    } catch (e) {
      setState(() {
        _state = _UpdateProgressState.error;
        _statusMessage = 'Could not execute update: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      backgroundColor: isDark ? const Color(0xFF1E1A22) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Icon Container
            Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.softRose, AppColors.lavender],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.softRose.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  _state == _UpdateProgressState.error
                      ? Icons.error_outline_rounded
                      : _state == _UpdateProgressState.installing
                          ? Icons.check_circle_outline_rounded
                          : Icons.system_update_rounded,
                  size: 34,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Title
            Text(
              'Update Required',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
                color: isDark ? Colors.white : AppColors.deepCharcoal,
              ),
            ),
            const SizedBox(height: 6),

            // Version tags
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Current: v${widget.currentVersion}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.softRose),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.softRose.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'New: v${widget.updateInfo.version}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.softRose,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Release Notes Box
            if (widget.updateInfo.releaseNotes.isNotEmpty) ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : const Color(0xFFF9F7F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.stars_rounded, size: 15, color: AppColors.softRose),
                          const SizedBox(width: 6),
                          Text(
                            "What's New:",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.updateInfo.releaseNotes,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark ? Colors.white60 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Progress or Action Section
            if (_state == _UpdateProgressState.idle) ...[
              Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.softRose, AppColors.lavender],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.softRose.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _startOtaUpdate,
                  icon: const Icon(Icons.cloud_download_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    'Update Now',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ] else if (_state == _UpdateProgressState.downloading ||
                _state == _UpdateProgressState.installing) ...[
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _state == _UpdateProgressState.installing
                          ? null
                          : (_downloadPercentage / 100.0).clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.softRose),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_state == _UpdateProgressState.downloading)
                        Text(
                          '$_downloadPercentage%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.softRose,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ] else if (_state == _UpdateProgressState.error) ...[
              Column(
                children: [
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFFF4D6D),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.softRose, AppColors.lavender],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _startOtaUpdate,
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                      label: const Text(
                        'Retry Update',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
