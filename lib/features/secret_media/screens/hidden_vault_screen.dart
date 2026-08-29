import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import 'package:jayienne_link/providers/secret_media_provider.dart';
import 'package:jayienne_link/providers/auth_provider.dart';
import 'package:jayienne_link/providers/user_provider.dart';
import 'package:jayienne_link/models/secret_media_model.dart';
import 'add_secret_media_screen.dart';
import 'secret_media_detail_screen.dart';

class HiddenVaultScreen extends StatefulWidget {
  const HiddenVaultScreen({super.key});

  @override
  State<HiddenVaultScreen> createState() => _HiddenVaultScreenState();
}

class _HiddenVaultScreenState extends State<HiddenVaultScreen> {
  static const List<String> _vaultLocks = [
    'purpink',
    '0122',
    'cr',
    '1230',
    'sagad',
    '071525',
  ];

  String _selectedType = 'image';
  bool _isUnlocked = false;
  String? _lockError;
  late final List<TextEditingController> _lockControllers;

  @override
  void initState() {
    super.initState();
    _lockControllers =
        List.generate(_vaultLocks.length, (_) => TextEditingController());
    _isUnlocked = false; // Always show lock screen so it can be designed and tested

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final user = context.read<UserProvider>();
      final coupleId = user.user?.coupleId ?? user.coupleId;
      final userId = auth.currentUserId ?? user.user?.id;
      if (coupleId != null &&
          coupleId.isNotEmpty &&
          userId != null &&
          userId.isNotEmpty) {
        context.read<SecretMediaProvider>().initialize(
              userId: userId,
              coupleId: coupleId,
            );
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _lockControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _normalizeLock(String value) {
    return value.trim().toLowerCase();
  }

  void _tryUnlockVault() {
    HapticFeedback.mediumImpact();
    final isValid = _lockControllers.asMap().entries.every((entry) {
      final index = entry.key;
      final value = entry.value.text;
      return _normalizeLock(value) == _normalizeLock(_vaultLocks[index]);
    });

    if (isValid) {
      setState(() {
        _isUnlocked = true;
        _lockError = null;
      });
      context.read<SecretMediaProvider>().refresh();
      return;
    }

    setState(() {
      _lockError = 'Incorrect lock combination. Please try again.';
    });
  }

  void _bypassLockDebug() {
    HapticFeedback.lightImpact();
    setState(() {
      _isUnlocked = true;
      _lockError = null;
    });
    context.read<SecretMediaProvider>().refresh();
    SnackbarHelper.showInfo(context, 'Vault bypassed (Debug Mode)');
  }

  Widget _buildLockGate() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),

          // Glowing Shield/Lock Emblem
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC2185B), Color(0xFF512DA8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC2185B).withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 38,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title & Description
          Text(
            'Private Vault Locked',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF2D4059),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter all 6 security keys to decrypt and reveal your private couple media.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Lock Input Fields Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E142B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: List.generate(_vaultLocks.length, (index) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _vaultLocks.length - 1 ? 0 : 12,
                  ),
                  child: TextField(
                    controller: _lockControllers[index],
                    obscureText: true,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Security Key ${index + 1}',
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                      prefixIcon: Icon(
                        Icons.key_rounded,
                        size: 18,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white12 : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white12 : Colors.grey.shade200,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF758C),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          if (_lockError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lockError!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Primary Unlock Button
          Container(
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _tryUnlockVault,
              icon: const Icon(Icons.lock_open_rounded, size: 20),
              label: const Text(
                'Unlock Vault',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          // Debug Mode Bypass Button
          if (kDebugMode) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _bypassLockDebug,
              icon: const Icon(Icons.developer_mode_rounded, size: 18, color: AppColors.lavender),
              label: const Text(
                'Bypass Lock (Debug Mode)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.lavender,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.lavender, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<SecretMediaModel> _filteredHiddenMedia(SecretMediaProvider provider) {
    return provider.hiddenMedia
        .where((media) => media.mediaType == _selectedType)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hidden Vault',
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
        actions: _isUnlocked
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    final provider = context.read<SecretMediaProvider>();
                    await provider.refresh();
                    if (!context.mounted) return;
                    SnackbarHelper.showSuccess(context, 'Vault refreshed');
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddSecretMediaScreen(),
                      ),
                    );
                  },
                ),
              ]
            : (kDebugMode
                ? [
                    IconButton(
                      icon: const Icon(Icons.lock_open_rounded, color: Colors.white),
                      tooltip: 'Bypass (Debug)',
                      onPressed: _bypassLockDebug,
                    ),
                  ]
                : null),
      ),
      body: !_isUnlocked
          ? _buildLockGate()
          : Consumer<SecretMediaProvider>(
              builder: (context, provider, _) {
                final imageCount = provider.hiddenMedia
                    .where((m) => m.mediaType == 'image')
                    .length;
                final videoCount = provider.hiddenMedia
                    .where((m) => m.mediaType == 'video')
                    .length;
                final filteredMedia = _filteredHiddenMedia(provider);

                if (_selectedType == 'image' &&
                    imageCount == 0 &&
                    videoCount > 0) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _selectedType = 'video';
                      });
                    }
                  });
                }

                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.red),
                  );
                }

                if (provider.hiddenMedia.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your vault is empty',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Move media here to keep it private',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: Text('Images ($imageCount)'),
                              selected: _selectedType == 'image',
                              onSelected: (_) {
                                setState(() {
                                  _selectedType = 'image';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: Text('Videos ($videoCount)'),
                              selected: _selectedType == 'video',
                              onSelected: (_) {
                                setState(() {
                                  _selectedType = 'video';
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filteredMedia.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _selectedType == 'image'
                                        ? Icons.image_outlined
                                        : Icons.videocam_outlined,
                                    size: 56,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _selectedType == 'image'
                                        ? 'No hidden images yet'
                                        : 'No hidden videos yet',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.8,
                              ),
                              itemCount: filteredMedia.length,
                              itemBuilder: (context, index) {
                                final media = filteredMedia[index];
                                return _buildMediaCard(
                                    context, media, provider);
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildMediaCard(
    BuildContext context,
    SecretMediaModel media,
    SecretMediaProvider provider,
  ) {
    final currentUserId = context.read<AuthProvider>().currentUserId;
    final canDelete =
        currentUserId != null && currentUserId == media.uploadedById;

    final displayImageUrl = media.mediaType == 'video'
        ? (media.thumbnail?.isNotEmpty == true
            ? media.thumbnail!
            : media.displayUrl)
        : media.displayUrl;

    final isVideo = media.mediaType == 'video';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SecretMediaDetailScreen(media: media),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Blurred background thumbnail / silhouette
              if (displayImageUrl.isNotEmpty)
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Image.network(
                    displayImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFF1E142B),
                    ),
                  ),
                )
              else
                Container(
                  color: const Color(0xFF1E142B),
                ),

              // 2. Dark frosted gradient privacy mask
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              // 3. Center Privacy Lock & Mask Emblem
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        isVideo ? Icons.videocam_rounded : Icons.lock_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isVideo ? 'Private Video' : 'Private Photo',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to Reveal',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Video Badge (Top Right)
              if (isVideo)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 2),
                        Text(
                          'VIDEO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 5. Delete Action Menu (Top Left)
              if (canDelete)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: PopupMenuButton(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: 18,
                      ),
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem(
                          child: const Row(
                            children: [
                              Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                          onTap: () {
                            _showConfirmDialog(
                              context,
                              'Delete Media?',
                              'This action cannot be undone.',
                              () {
                                provider.deleteSecretMedia(media.id!);
                                SnackbarHelper.showSuccess(context, 'Media deleted');
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConfirmDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text(
              'Confirm',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
