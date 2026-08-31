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
import '../../../widgets/common/app_text_field.dart';

class HiddenVaultScreen extends StatefulWidget {
  const HiddenVaultScreen({super.key});

  @override
  State<HiddenVaultScreen> createState() => _HiddenVaultScreenState();
}

class _HiddenVaultScreenState extends State<HiddenVaultScreen>
    with WidgetsBindingObserver {
  static const List<String> _vaultLocks = [
    'purpink',
    '0122',
    'cr',
    '1230',
    'sagad',
    '071525',
  ];

  String _selectedType = 'all';
  bool _isUnlocked = false;
  final Set<String> _revealedMediaIds = <String>{};
  late final List<TextEditingController> _lockControllers;
  late final List<bool> _obscureLocks;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockControllers =
        List.generate(_vaultLocks.length, (_) => TextEditingController());
    _obscureLocks = List.generate(_vaultLocks.length, (_) => true);
    // Always start at the lock gate screen for privacy
    _isUnlocked = false;

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // Re-lock only when app is fully closed/detached
      if (mounted) {
        context.read<SecretMediaProvider>().lockVaultSession();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      context.read<SecretMediaProvider>().unlockVaultSession();
      setState(() {
        _isUnlocked = true;
      });
      context.read<SecretMediaProvider>().refresh();
      SnackbarHelper.showSuccess(
        context,
        'Vault decrypted successfully!',
        title: 'Vault Unlocked',
      );
      return;
    }

    SnackbarHelper.showError(
      context,
      'Incorrect lock combination. Please check your 6 security keys and try again.',
      title: 'Access Denied',
    );
  }

  void _bypassLockDebug() {
    HapticFeedback.lightImpact();
    context.read<SecretMediaProvider>().unlockVaultSession();
    setState(() {
      _isUnlocked = true;
    });
    context.read<SecretMediaProvider>().refresh();
    SnackbarHelper.showInfo(context, 'Vault bypassed (Debug Mode)');
  }

  List<SecretMediaModel> _filteredHiddenMedia(SecretMediaProvider provider) {
    if (_selectedType == 'image') {
      return provider.hiddenMedia.where((m) => m.mediaType == 'image').toList();
    } else if (_selectedType == 'video') {
      return provider.hiddenMedia.where((m) => m.mediaType == 'video').toList();
    }
    return provider.hiddenMedia;
  }

  Widget _buildLockGate(bool isSessionUnlocked) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isSessionUnlocked) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // Glowing Shield/Lock Emblem (Emerald/Purple gradient)
            Center(
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00B09B), Color(0xFF96C93D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00B09B).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_open_rounded,
                  size: 42,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title & Description
            Text(
              'Vault Decrypted',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2D4059),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You already unlocked your private vault during this login session.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Status Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E142B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF00B09B).withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B09B).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF00B09B),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session Access Active',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.deepCharcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap below to view your media or lock the vault.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Primary Enter Button
            Container(
              height: 52,
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
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _isUnlocked = true;
                  });
                  context.read<SecretMediaProvider>().refresh();
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                label: const Text(
                  'Enter Vault',
                  style: TextStyle(
                    fontSize: 15.5,
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
            const SizedBox(height: 12),

            // Option to Re-Lock
            OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.read<SecretMediaProvider>().lockVaultSession();
                SnackbarHelper.showInfo(context, 'Vault locked');
              },
              icon: const Icon(Icons.lock_rounded, size: 18, color: Colors.grey),
              label: const Text(
                'Lock Vault Now',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: Colors.grey,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 6 Lock Fields using unified AppTextField
                ...List.generate(_vaultLocks.length, (index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _vaultLocks.length - 1 ? 0 : 12,
                    ),
                    child: AppTextField(
                      controller: _lockControllers[index],
                      hintText: 'Security Key #${index + 1}',
                      obscureText: _obscureLocks[index],
                      prefixIcon: Icons.key_rounded,
                      isDark: isDark,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureLocks[index]
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: const Color(0xFFFF758C),
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _obscureLocks[index] = !_obscureLocks[index];
                          });
                        },
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Primary Unlock Button
          Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC2185B), Color(0xFF512DA8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC2185B).withValues(alpha: 0.35),
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
                  fontSize: 15.5,
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

          // Debug Bypass in Debug Mode
          if (kDebugMode) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: _bypassLockDebug,
                icon: const Icon(Icons.bug_report_rounded, size: 16),
                label: const Text(
                  'Quick Bypass (Debug Only)',
                  style: TextStyle(fontSize: 12.5),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !_isUnlocked,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isUnlocked) {
          setState(() {
            _isUnlocked = false;
          });
        }
      },
      child: Scaffold(
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
                colors: [Color(0xFFC2185B), Color(0xFF512DA8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () {
              HapticFeedback.lightImpact();
              if (_isUnlocked) {
                setState(() {
                  _isUnlocked = false;
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          elevation: 0,
          actions: _isUnlocked
              ? [
                  Consumer<SecretMediaProvider>(
                    builder: (context, provider, _) {
                      final filtered = _filteredHiddenMedia(provider);
                      final allIds = filtered.map((m) => m.id).whereType<String>().toSet();
                      final isAllRevealed = allIds.isNotEmpty && allIds.every(_revealedMediaIds.contains);

                      return IconButton(
                        icon: Icon(
                          isAllRevealed
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          color: Colors.white,
                        ),
                        tooltip: isAllRevealed ? 'Hide All' : 'View All',
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            if (isAllRevealed) {
                              _revealedMediaIds.removeAll(allIds);
                            } else {
                              _revealedMediaIds.addAll(allIds);
                            }
                          });
                        },
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    tooltip: 'Refresh',
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      final provider = context.read<SecretMediaProvider>();
                      await provider.refresh();
                      if (!context.mounted) return;
                      SnackbarHelper.showSuccess(context, 'Vault refreshed');
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.lock_rounded, color: Colors.white),
                    tooltip: 'Lock Vault',
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      context.read<SecretMediaProvider>().lockVaultSession();
                      setState(() {
                        _isUnlocked = false;
                      });
                      SnackbarHelper.showInfo(context, 'Vault locked');
                    },
                  ),
                ]
              : null,
        ),
        body: !_isUnlocked
            ? _buildLockGate(
                context.watch<SecretMediaProvider>().isVaultUnlockedSession,
              )
            : Consumer<SecretMediaProvider>(
                builder: (context, provider, _) {
                  final imageCount = provider.hiddenMedia
                      .where((m) => m.mediaType == 'image')
                      .length;
                  final videoCount = provider.hiddenMedia
                      .where((m) => m.mediaType == 'video')
                      .length;
                  final totalCount = provider.hiddenMedia.length;
                  final filteredMedia = _filteredHiddenMedia(provider);

                  if (provider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFF758C)),
                    );
                  }

                  if (provider.hiddenMedia.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFC2185B).withValues(alpha: 0.2),
                                    const Color(0xFF512DA8).withValues(alpha: 0.2),
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.lock_outline_rounded,
                                size: 52,
                                color: Color(0xFFFF758C),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Your Vault is Empty',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF2D4059),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Keep private photos and videos safe here. Only you and your partner can decrypt them.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AddSecretMediaScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                label: const Text(
                                  'Add Private Media',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Category Filter Chips Row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildCategoryChip('all', 'All Media', totalCount, Icons.apps_rounded, isDark),
                              const SizedBox(width: 8),
                              _buildCategoryChip('image', 'Photos', imageCount, Icons.photo_library_rounded, isDark),
                              const SizedBox(width: 8),
                              _buildCategoryChip('video', 'Videos', videoCount, Icons.videocam_rounded, isDark),
                            ],
                          ),
                        ),
                      ),

                      // Scrollable Grid of All Images and Videos
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
                                      size: 52,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _selectedType == 'image'
                                          ? 'No hidden photos yet'
                                          : 'No hidden videos yet',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                color: const Color(0xFFFF758C),
                                onRefresh: () => provider.refresh(),
                                child: GridView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 96),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 0.82,
                                  ),
                                  itemCount: filteredMedia.length,
                                  itemBuilder: (context, index) {
                                    final media = filteredMedia[index];
                                    return _buildMediaCard(
                                      context,
                                      media,
                                      provider,
                                      isDark,
                                      index,
                                      filteredMedia,
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
        floatingActionButton: _isUnlocked
            ? Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF758C).withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FloatingActionButton.extended(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddSecretMediaScreen(),
                      ),
                    );
                  },
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  splashColor: Colors.white.withValues(alpha: 0.2),
                  icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 22),
                  label: const Text(
                    'Add Media',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildCategoryChip(
    String type,
    String label,
    int count,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _selectedType == type;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedType = type;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF758C)
              : (isDark ? const Color(0xFF1E142B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF758C)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFFF758C).withValues(alpha: 0.22)),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFFFF758C).withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFFA18CD1) : const Color(0xFFFF758C)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : AppColors.deepCharcoal),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.28)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFFF758C).withValues(alpha: 0.12)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFFFF758C)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaCard(
    BuildContext context,
    SecretMediaModel media,
    SecretMediaProvider provider,
    bool isDark,
    int index,
    List<SecretMediaModel> filteredMedia,
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
    final isRevealedInPlace = media.id != null && _revealedMediaIds.contains(media.id);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SecretMediaDetailScreen(
              media: media,
              mediaList: filteredMedia,
              initialIndex: index,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFFF758C).withValues(alpha: 0.18),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Background Image (Blurred if hidden, clear if revealed in-place)
              if (displayImageUrl.isNotEmpty)
                isRevealedInPlace
                    ? Image.network(
                        displayImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFF1E142B),
                          child: const Center(
                            child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 28),
                          ),
                        ),
                      )
                    : ImageFiltered(
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

              // 2. Dark frosted gradient overlay when hidden
              if (!isRevealedInPlace)
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

              // 3. Center Privacy Lock & Mask Emblem when hidden
              if (!isRevealedInPlace)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF758C).withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            isVideo ? Icons.videocam_rounded : Icons.lock_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          isVideo ? 'Private Video' : 'Private Photo',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Tap to view',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 4. Video Badge (Top Left)
              if (isVideo)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.8,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white, size: 13),
                        SizedBox(width: 2),
                        Text(
                          'VIDEO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 5. Eye Quick Reveal Toggle Button (Top Right)
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (media.id == null) return;
                      setState(() {
                        if (_revealedMediaIds.contains(media.id)) {
                          _revealedMediaIds.remove(media.id);
                        } else {
                          _revealedMediaIds.add(media.id!);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Icon(
                        isRevealedInPlace
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ),
              ),

              // 6. Delete Action Button (Bottom Right)
              if (canDelete)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showConfirmDialog(
                          context,
                          'Delete Media?',
                          'This will permanently remove this private media from your vault.',
                          () {
                            provider.deleteSecretMedia(media.id!);
                            SnackbarHelper.showSuccess(context, 'Media deleted');
                          },
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                          size: 15,
                        ),
                      ),
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
