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
import 'package:jayienne_link/providers/couple_provider.dart';
import 'package:jayienne_link/providers/debug_provider.dart';
import 'package:jayienne_link/models/secret_media_model.dart';
import 'add_secret_media_screen.dart';
import 'secret_media_detail_screen.dart';
import 'package:video_player/video_player.dart';
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

  static const Set<String> _knownCorruptedIds = {
    '68123b89-c301-4d47-980f-e7e69c1f825c',
    '517c69a3-79c3-4b46-9786-e046431fe008',
  };

  String _selectedUploader = 'all'; // 'all', 'me', 'partner'
  String _selectedType = 'all'; // 'all', 'image', 'video'
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

  List<SecretMediaModel> _filteredHiddenMedia(
    SecretMediaProvider provider, {
    String? currentUserId,
  }) {
    final effectiveUserId = currentUserId ??
        context.read<AuthProvider>().currentUserId ??
        context.read<UserProvider>().user?.id;

    final seenIds = <String>{};
    final validMedia = <SecretMediaModel>[];

    for (final m in provider.hiddenMedia) {
      final id = m.id;
      if (id != null && _knownCorruptedIds.contains(id)) {
        continue;
      }
      final url = m.mediaUrl.trim();
      if (url.isEmpty || url == 'null' || !(url.startsWith('http://') || url.startsWith('https://'))) {
        continue;
      }
      if (id != null && seenIds.contains(id)) continue;
      if (id != null) seenIds.add(id);
      validMedia.add(m);
    }

    validMedia.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

    return validMedia.where((m) {
      // 1. Parent filter: Uploader (All / Me / Partner)
      if (_selectedUploader == 'me') {
        if (effectiveUserId == null || m.uploadedById != effectiveUserId) return false;
      } else if (_selectedUploader == 'partner') {
        if (effectiveUserId == null || m.uploadedById == effectiveUserId) return false;
      }

      // 2. Child filter: Media Type (All / Photos / Videos)
      if (_selectedType == 'image') {
        return m.mediaType == 'image';
      } else if (_selectedType == 'video') {
        return m.mediaType == 'video';
      }

      return true;
    }).toList();
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
                // Header with Title and "Show All / Hide All" Keys Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Security Keys (${_vaultLocks.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.grey.shade800,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        final anyObscured = _obscureLocks.any((o) => o);
                        setState(() {
                          for (int i = 0; i < _obscureLocks.length; i++) {
                            _obscureLocks[i] = !anyObscured;
                          }
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: const Color(0xFFFF758C),
                      ),
                      icon: Icon(
                        _obscureLocks.any((o) => o)
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 16,
                      ),
                      label: Text(
                        _obscureLocks.any((o) => o) ? 'Show All' : 'Hide All',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

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
          if (DebugProvider.isDebug) ...[
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
          const SizedBox(height: 32),
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
                      final allIds =
                          filtered.map((m) => m.id).whereType<String>().toSet();
                      final isAllRevealed = allIds.isNotEmpty &&
                          allIds.every((id) => _revealedMediaIds.contains(id));

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
                    icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white),
                    tooltip: 'Add Media',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddSecretMediaScreen(
                            initialMediaType:
                                _selectedType == 'video' ? 'video' : 'image',
                          ),
                        ),
                      );
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
                  // Purge any revealed IDs for items that no longer exist (e.g. deleted from database)
                  _revealedMediaIds.removeWhere(
                      (id) => !provider.hiddenMedia.any((m) => m.id == id));

                  final allValidHidden = provider.hiddenMedia.where((m) {
                    final id = m.id;
                    if (id != null && _knownCorruptedIds.contains(id)) {
                      return false;
                    }
                    final url = m.mediaUrl.trim();
                    return url.isNotEmpty &&
                        url != 'null' &&
                        (url.startsWith('http://') || url.startsWith('https://'));
                  }).toList();
                  final seenIds = <String>{};
                  final uniqueHidden = <SecretMediaModel>[];
                  for (final m in allValidHidden) {
                    final id = m.id;
                    if (id != null && seenIds.contains(id)) continue;
                    if (id != null) seenIds.add(id);
                    uniqueHidden.add(m);
                  }

                  final authProvider = context.watch<AuthProvider>();
                  final coupleProvider = context.watch<CoupleProvider>();
                  final userProvider = context.watch<UserProvider>();
                  final currentUserId =
                      authProvider.currentUserId ?? userProvider.user?.id;
                  final partner = coupleProvider.partner;
                  final partnerName =
                      partner != null && partner.displayName.trim().isNotEmpty
                          ? partner.displayName.trim()
                          : 'Partner';
                  final partnerPhoto = partner?.photoUrl;
                  final myPhoto = userProvider.user?.photoUrl;

                  // 1. Parent (Uploader) Filter Counts
                  final allUploaderCount = uniqueHidden.length;
                  final myTotalCount = uniqueHidden
                      .where((m) =>
                          currentUserId != null &&
                          m.uploadedById == currentUserId)
                      .length;
                  final partnerTotalCount = uniqueHidden
                      .where((m) =>
                          currentUserId != null &&
                          m.uploadedById != currentUserId)
                      .length;

                  // 2. Child (Media Type) Filter Scope based on selected uploader
                  final uploaderScopeMedia = uniqueHidden.where((m) {
                    if (_selectedUploader == 'me') {
                      return currentUserId != null &&
                          m.uploadedById == currentUserId;
                    } else if (_selectedUploader == 'partner') {
                      return currentUserId != null &&
                          m.uploadedById != currentUserId;
                    }
                    return true;
                  }).toList();

                  final childAllCount = uploaderScopeMedia.length;
                  final childImageCount = uploaderScopeMedia
                      .where((m) => m.mediaType == 'image')
                      .length;
                  final childVideoCount = uploaderScopeMedia
                      .where((m) => m.mediaType == 'video')
                      .length;

                  final filteredMedia = _filteredHiddenMedia(
                    provider,
                    currentUserId: currentUserId,
                  );

                  if (provider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFF758C)),
                    );
                  }

                  if (uniqueHidden.isEmpty) {
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
                                      builder: (context) => AddSecretMediaScreen(
                                        initialMediaType: _selectedType == 'video'
                                            ? 'video'
                                            : 'image',
                                      ),
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
                      // Two-Tier Filter: Parent (Uploader) -> Child (Media Type)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tier 1: Parent Filter (Who Uploaded)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  _buildUploaderChip(
                                    'all',
                                    'Everyone',
                                    allUploaderCount,
                                    Icons.people_alt_rounded,
                                    isDark,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildUploaderChip(
                                    'me',
                                    'Me',
                                    myTotalCount,
                                    Icons.person_rounded,
                                    isDark,
                                    photoUrl: myPhoto,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildUploaderChip(
                                    'partner',
                                    partnerName,
                                    partnerTotalCount,
                                    Icons.favorite_rounded,
                                    isDark,
                                    photoUrl: partnerPhoto,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Tier 2: Child Filter (Media Type)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  _buildCategoryChip(
                                    'all',
                                    'All Media',
                                    childAllCount,
                                    Icons.grid_view_rounded,
                                    isDark,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildCategoryChip(
                                    'image',
                                    'Photos',
                                    childImageCount,
                                    Icons.photo_library_rounded,
                                    isDark,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildCategoryChip(
                                    'video',
                                    'Videos',
                                    childVideoCount,
                                    Icons.videocam_rounded,
                                    isDark,
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                                          : (_selectedType == 'video'
                                              ? Icons.videocam_outlined
                                              : Icons.folder_open_rounded),
                                      size: 52,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24),
                                      child: Text(
                                        _getEmptyFilterMessage(partnerName),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.grey.shade600,
                                        ),
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
                                  padding: EdgeInsets.fromLTRB(
                                    14,
                                    6,
                                    14,
                                    MediaQuery.of(context).padding.bottom + 24,
                                  ),
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
      ),
    );
  }

  Widget _buildUploaderChip(
    String uploaderKey,
    String label,
    int count,
    IconData icon,
    bool isDark, {
    String? photoUrl,
  }) {
    final isSelected = _selectedUploader == uploaderKey;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedUploader = uploaderKey;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected
              ? null
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
            if (photoUrl != null && photoUrl.isNotEmpty)
              Container(
                width: 17,
                height: 17,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : const Color(0xFFFF758C),
                    width: 1.0,
                  ),
                ),
                child: ClipOval(
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      icon,
                      size: 13,
                      color: isSelected ? Colors.white : const Color(0xFFFF758C),
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  icon,
                  size: 14,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? const Color(0xFFA18CD1) : const Color(0xFFFF758C)),
                ),
              ),
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
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2E1C44) : const Color(0xFFFFEFF2))
              : (isDark ? const Color(0xFF160D20) : const Color(0xFFF9F7FA)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF758C)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.withValues(alpha: 0.18)),
            width: isSelected ? 1.2 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF758C).withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? const Color(0xFFFF758C)
                  : (isDark ? Colors.white60 : Colors.grey.shade600),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFFFF758C))
                    : (isDark ? Colors.white70 : Colors.grey.shade700),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF758C).withValues(alpha: 0.2)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? const Color(0xFFFF758C)
                      : (isDark ? Colors.white60 : Colors.grey.shade600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getEmptyFilterMessage(String partnerName) {
    if (_selectedUploader == 'me') {
      if (_selectedType == 'image') return 'You haven\'t uploaded any hidden photos yet';
      if (_selectedType == 'video') return 'You haven\'t uploaded any hidden videos yet';
      return 'You haven\'t uploaded any hidden media yet';
    } else if (_selectedUploader == 'partner') {
      if (_selectedType == 'image') return '$partnerName hasn\'t uploaded any hidden photos yet';
      if (_selectedType == 'video') return '$partnerName hasn\'t uploaded any hidden videos yet';
      return '$partnerName hasn\'t uploaded any hidden media yet';
    } else {
      if (_selectedType == 'image') return 'No hidden photos found';
      if (_selectedType == 'video') return 'No hidden videos found';
      return 'No hidden media found';
    }
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
            : '')
        : media.displayUrl;

    final isVideo = media.mediaType == 'video';
    final isRevealedInPlace = media.id != null && _revealedMediaIds.contains(media.id);

    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();

        // Snapshot the "Hide All" state BEFORE navigating.
        // If every item was hidden (none revealed), hide-all was active.
        final provider = context.read<SecretMediaProvider>();
        final allMediaIds = _filteredHiddenMedia(provider)
            .map((m) => m.id)
            .whereType<String>()
            .toSet();
        final wasHideAllActive = allMediaIds.isNotEmpty &&
            !allMediaIds.any((id) => _revealedMediaIds.contains(id));

        final dynamic updatedReveals = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SecretMediaDetailScreen(
              media: media,
              mediaList: filteredMedia,
              initialIndex: index,
              initialRevealedIds: _revealedMediaIds,
            ),
          ),
        );
        if (updatedReveals is Set<String> && mounted) {
          setState(() {
            _revealedMediaIds.clear();
            // If "Hide All" was active before entering, re-enforce it
            // by NOT restoring any reveals that happened inside.
            if (!wasHideAllActive) {
              _revealedMediaIds.addAll(updatedReveals);
            }
          });
        }
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
              // 1. Background Media Content (Deeply Blurred if hidden, live preview or image if revealed)
              if (!isRevealedInPlace)
                if (displayImageUrl.isNotEmpty)
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                    child: Image.network(
                      displayImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFF1E142B),
                          child: Center(
                            child: Icon(
                              isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                              color: Colors.white24,
                              size: 32,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    color: const Color(0xFF1E142B),
                    child: Center(
                      child: Icon(
                        isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                        color: Colors.white24,
                        size: 32,
                      ),
                    ),
                  )
              else
                // Revealed in-place (Hide All is off)
                isVideo
                    ? _VaultGridVideoPreview(
                        key: ValueKey(media.id ?? media.displayUrl),
                        videoUrl: media.displayUrl,
                        thumbnail: media.thumbnail,
                      )
                    : Image.network(
                        displayImageUrl.isNotEmpty
                            ? displayImageUrl
                            : media.displayUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFF1E142B),
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_rounded,
                                color: Colors.white54,
                                size: 28,
                              ),
                            ),
                          );
                        },
                      ),

              // 2. Heavy dark frosted privacy mask overlay when hidden
              if (!isRevealedInPlace)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF140D1D).withValues(alpha: 0.85),
                            const Color(0xFF0C0712).withValues(alpha: 0.95),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
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

              // 5. Delete Action Button (Bottom Right)
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFFF5252),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF5252), Color(0xFFD81B60)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightweight paused thumbnail preview for vault grid items (zero streaming overhead)
class _VaultGridVideoPreview extends StatefulWidget {
  final String videoUrl;
  final String? thumbnail;

  const _VaultGridVideoPreview({
    super.key,
    required this.videoUrl,
    this.thumbnail,
  });

  @override
  State<_VaultGridVideoPreview> createState() => _VaultGridVideoPreviewState();
}

class _VaultGridVideoPreviewState extends State<_VaultGridVideoPreview> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // If static thumbnail image exists, use it directly without initializing player
    if (widget.thumbnail == null || widget.thumbnail!.isEmpty) {
      _initController();
    }
  }

  Future<void> _initController() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      await controller.setVolume(0.0);
      await controller.pause(); // Kept paused on first frame to avoid stressing database/network
      setState(() {
        _isInitialized = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Static thumbnail if available (0 video network load)
    if (widget.thumbnail?.isNotEmpty == true) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            widget.thumbnail!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF1E142B)),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      );
    }

    // 2. Paused first frame if video controller initialized
    if (_isInitialized && _controller != null) {
      final size = _controller!.value.size;
      return Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: size.width > 0 ? size.width : 16,
              height: size.height > 0 ? size.height : 9,
              child: VideoPlayer(_controller!),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      );
    }

    if (_hasError) {
      return Container(
        color: const Color(0xFF1E142B),
        child: const Center(
          child: Icon(Icons.videocam_rounded, color: Colors.white38, size: 28),
        ),
      );
    }

    return Container(
      color: const Color(0xFF1E142B),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFFF758C),
          ),
        ),
      ),
    );
  }
}
