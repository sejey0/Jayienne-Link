import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/secret_media_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/secret_media_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/common/app_text_field.dart';

/// Full-Screen Swipable Detail & Gallery Viewer for Hidden Vault and Secret Media
class SecretMediaDetailScreen extends StatefulWidget {
  final SecretMediaModel media;
  final List<SecretMediaModel>? mediaList;
  final int initialIndex;
  final Set<String>? initialRevealedIds;

  const SecretMediaDetailScreen({
    super.key,
    required this.media,
    this.mediaList,
    this.initialIndex = 0,
    this.initialRevealedIds,
  });

  @override
  State<SecretMediaDetailScreen> createState() =>
      _SecretMediaDetailScreenState();
}

class _SecretMediaDetailScreenState extends State<SecretMediaDetailScreen> {
  late List<SecretMediaModel> _items;
  late int _currentIndex;
  late PageController _pageController;

  final Set<String> _revealedMediaIds = <String>{};
  bool _showOverlays = true;
  bool _showInfoDrawer = false;

  late TextEditingController _captionController;
  final FocusNode _captionFocusNode = FocusNode();
  bool _isEditingCaption = false;
  bool _isSavingCaption = false;

  SecretMediaModel get _currentMedia => _items[_currentIndex];

  bool get _isUploader {
    final currentUserId = context.read<AuthProvider>().currentUserId;
    return currentUserId != null &&
        currentUserId.isNotEmpty &&
        _currentMedia.uploadedById.isNotEmpty &&
        currentUserId == _currentMedia.uploadedById;
  }

  @override
  void initState() {
    super.initState();
    _items = (widget.mediaList != null && widget.mediaList!.isNotEmpty)
        ? List<SecretMediaModel>.from(widget.mediaList!)
        : [widget.media];

    _currentIndex = widget.initialIndex.clamp(0, _items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _captionController =
        TextEditingController(text: _currentMedia.caption ?? '');

    if (widget.initialRevealedIds != null) {
      _revealedMediaIds.addAll(widget.initialRevealedIds!);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _captionController.dispose();
    _captionFocusNode.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _isEditingCaption = false;
      _captionController.text = _currentMedia.caption ?? '';
    });
  }

  void _toggleCurrentReveal() {
    HapticFeedback.lightImpact();
    final id = _currentMedia.id;
    if (id == null) return;
    setState(() {
      if (_revealedMediaIds.contains(id)) {
        _revealedMediaIds.remove(id);
      } else {
        _revealedMediaIds.add(id);
      }
    });
  }


  void _toggleOverlays() {
    setState(() {
      _showOverlays = !_showOverlays;
    });
  }

  void _startEditingCaption() {
    setState(() {
      _isEditingCaption = true;
      _showInfoDrawer = true;
      _captionController.text = _currentMedia.caption ?? '';
      _captionController.selection = TextSelection.fromPosition(
        TextPosition(offset: _captionController.text.length),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _captionFocusNode.requestFocus();
      }
    });
  }

  Future<void> _saveCaption() async {
    final newCaption = _captionController.text.trim();
    final currentCaption = _currentMedia.caption?.trim() ?? '';

    if (newCaption == currentCaption) {
      setState(() {
        _isEditingCaption = false;
      });
      return;
    }

    setState(() {
      _isSavingCaption = true;
    });

    final provider = context.read<SecretMediaProvider>();
    final success =
        await provider.updateCaption(_currentMedia.id!, newCaption);

    if (mounted) {
      setState(() {
        _isSavingCaption = false;
        if (success) {
          _items[_currentIndex] = _currentMedia.copyWith(
            caption: newCaption.isEmpty ? null : newCaption,
          );
          _isEditingCaption = false;
          SnackbarHelper.showSuccess(context, 'Caption updated');
        }
      });
    }
  }

  void _showDeleteDialog() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFF1C1427),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5252), Color(0xFFD81B60)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Delete Media?',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone. This private media will be permanently erased.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFFFF758C), width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFFFF758C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF5252), Color(0xFFD81B60)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        final mediaId = _currentMedia.id;
                        Navigator.pop(ctx);
                        if (mediaId != null) {
                          await context
                              .read<SecretMediaProvider>()
                              .deleteSecretMedia(mediaId);
                          if (mounted) {
                            SnackbarHelper.showSuccess(
                                context, 'Media deleted');
                            if (_items.length <= 1) {
                              Navigator.pop(context);
                            } else {
                              setState(() {
                                _items.removeAt(_currentIndex);
                                if (_currentIndex >= _items.length) {
                                  _currentIndex = _items.length - 1;
                                }
                              });
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildUploaderAvatar(
    UserModel? currentUser,
    UserModel? partner, {
    double size = 26,
  }) {
    final isMe = _currentMedia.uploadedById == currentUser?.id;
    final uploader = isMe ? currentUser : partner;
    final photoUrl = uploader?.photoUrl;
    final displayName = uploader?.displayName ?? (isMe ? 'You' : 'Partner');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFFF758C).withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF758C).withValues(alpha: 0.35),
            blurRadius: 4,
          ),
        ],
      ),
      child: ClipOval(
        child: photoUrl != null && photoUrl.trim().isNotEmpty
            ? Image.network(
                photoUrl.trim(),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _buildAvatarFallback(displayName, size: size),
              )
            : _buildAvatarFallback(displayName, size: size),
      ),
    );
  }

  Widget _buildAvatarFallback(String name, {double size = 26}) {
    final initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '♥';
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'No media available',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final isCurrentRevealed = _currentMedia.id != null &&
        _revealedMediaIds.contains(_currentMedia.id);

    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final currentUser = userProvider.user;
    final partner = coupleProvider.partner;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _revealedMediaIds);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Swipable Horizontal PageView (Scroll next to next)
            PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: _onPageChanged,
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final isRevealed =
                    item.id != null && _revealedMediaIds.contains(item.id);
                final isActivePage = index == _currentIndex;

                if (item.mediaType == 'video') {
                  return _VaultVideoPageItem(
                    media: item,
                    isActivePage: isActivePage,
                    isRevealed: isRevealed,
                    onToggleReveal: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (item.id != null) {
                          if (_revealedMediaIds.contains(item.id)) {
                            _revealedMediaIds.remove(item.id);
                          } else {
                            _revealedMediaIds.add(item.id!);
                          }
                        }
                      });
                    },
                    onToggleOverlays: _toggleOverlays,
                  );
                }

                return _VaultImagePageItem(
                  media: item,
                  isRevealed: isRevealed,
                  onToggleReveal: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (item.id != null) {
                        if (_revealedMediaIds.contains(item.id)) {
                          _revealedMediaIds.remove(item.id);
                        } else {
                          _revealedMediaIds.add(item.id!);
                        }
                      }
                    });
                  },
                  onToggleOverlays: _toggleOverlays,
                );
              },
            ),

            // 2. Animated Top AppBar Overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _showOverlays ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: IgnorePointer(
                  ignoring: !_showOverlays,
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 4,
                      left: 8,
                      right: 8,
                      bottom: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.8),
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Back Button (Syncs revealed state back to caller)
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () =>
                              Navigator.pop(context, _revealedMediaIds),
                        ),

                        // Position Counter & Media Type Indicator
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _currentMedia.mediaType == 'video'
                                          ? Icons.videocam_rounded
                                          : Icons.photo_rounded,
                                      color: const Color(0xFFFF758C),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_currentIndex + 1} / ${_items.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Full View Toggle Button
                        IconButton(
                          tooltip:
                              _showOverlays ? 'Full View' : 'Exit Full View',
                          icon: const Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 23,
                          ),
                          onPressed: _toggleOverlays,
                        ),

                        // Reveal / Hide Current Item Button
                        IconButton(
                          tooltip:
                              isCurrentRevealed ? 'Hide Media' : 'View Media',
                          icon: Icon(
                            isCurrentRevealed
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            color: isCurrentRevealed
                                ? const Color(0xFFFF758C)
                                : Colors.white,
                            size: 22,
                          ),
                          onPressed: _toggleCurrentReveal,
                        ),

                        // Delete Button (if uploader)
                        if (_isUploader)
                          IconButton(
                            tooltip: 'Delete Media',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error,
                              size: 22,
                            ),
                            onPressed: _showDeleteDialog,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Animated Bottom Floating Drawer / Caption Panel
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 14,
              child: AnimatedOpacity(
                opacity: _showOverlays ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: IgnorePointer(
                  ignoring: !_showOverlays,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF1C1427).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top bar with Uploader Avatar, Caption / Title, and Expand / Edit buttons
                            Row(
                              children: [
                                _buildUploaderAvatar(currentUser, partner, size: 24),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _currentMedia.caption?.isNotEmpty == true
                                        ? _currentMedia.caption!
                                        : (_currentMedia.mediaType == 'video'
                                            ? 'Private Video'
                                            : 'Private Photo'),
                                    maxLines: _showInfoDrawer ? 4 : 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (_isUploader && !_isEditingCaption)
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(
                                      Icons.edit_note_rounded,
                                      color: Color(0xFFFF758C),
                                      size: 22,
                                    ),
                                    tooltip: 'Edit Caption',
                                    onPressed: _startEditingCaption,
                                  ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _showInfoDrawer = !_showInfoDrawer;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Icon(
                                      _showInfoDrawer
                                          ? Icons.keyboard_arrow_down_rounded
                                          : Icons.info_outline_rounded,
                                      color: Colors.white70,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Editing Caption TextField
                            if (_isEditingCaption && _isUploader) ...[
                              const SizedBox(height: 10),
                              AppTextField(
                                controller: _captionController,
                                focusNode: _captionFocusNode,
                                hintText: 'Add a romantic caption...',
                                isDark: true,
                                maxLines: 3,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isEditingCaption = false;
                                        _captionController.text =
                                            _currentMedia.caption ?? '';
                                      });
                                    },
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(color: Colors.white60),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed:
                                        _isSavingCaption ? null : _saveCaption,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFF758C),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: _isSavingCaption
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Save'),
                                  ),
                                ],
                              ),
                            ],

                            // Expanded Metadata Section
                            if (_showInfoDrawer && !_isEditingCaption) ...[
                              const SizedBox(height: 10),
                              const Divider(color: Colors.white12, height: 1),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      _buildUploaderAvatar(
                                        currentUser,
                                        partner,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _currentMedia.uploadedById ==
                                                currentUser?.id
                                            ? 'You'
                                            : (partner?.displayName.isNotEmpty ==
                                                    true
                                                ? partner!.displayName
                                                : 'Partner'),
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 12,
                                        color: Colors.white54,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        DateFormat('MMM dd, yyyy • hh:mm a')
                                            .format(_currentMedia.uploadedAt),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white60,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00B09B)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF00B09B)
                                        .withValues(alpha: 0.35),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_rounded,
                                      size: 11,
                                      color: Color(0xFF00B09B),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '6-Key Vault Encrypted',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF00B09B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 4. Side-by-Side Horizontal Navigation Arrows
          if (_items.length > 1) ...[
            // Left Arrow (Previous)
            if (_currentIndex > 0)
              Positioned(
                left: 14,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _showOverlays ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: IgnorePointer(
                      ignoring: !_showOverlays,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeInOutCubic,
                            );
                          },
                          borderRadius: BorderRadius.circular(25),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.chevron_left_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Right Arrow (Next)
            if (_currentIndex < _items.length - 1)
              Positioned(
                right: 14,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _showOverlays ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: IgnorePointer(
                      ignoring: !_showOverlays,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeInOutCubic,
                            );
                          },
                          borderRadius: BorderRadius.circular(25),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}
}

/// Image Page Item with Zoom Support, Double-Tap Zoom, and Privacy Mask
class _VaultImagePageItem extends StatefulWidget {
  final SecretMediaModel media;
  final bool isRevealed;
  final VoidCallback onToggleReveal;
  final VoidCallback onToggleOverlays;

  const _VaultImagePageItem({
    required this.media,
    required this.isRevealed,
    required this.onToggleReveal,
    required this.onToggleOverlays,
  });

  @override
  State<_VaultImagePageItem> createState() => _VaultImagePageItemState();
}

class _VaultImagePageItemState extends State<_VaultImagePageItem> {
  late TransformationController _transformationController;
  TapDownDetails? _doubleTapDetails;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.05;
    if (isZoomed != _isZoomed) {
      setState(() {
        _isZoomed = isZoomed;
      });
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    HapticFeedback.selectionClick();
    if (_isZoomed) {
      setState(() {
        _transformationController.value = Matrix4.identity();
      });
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      final x = -position.dx * (2.5 - 1);
      final y = -position.dy * (2.5 - 1);
      setState(() {
        _transformationController.value = Matrix4.identity()
          ..setEntry(0, 0, 2.5)
          ..setEntry(1, 1, 2.5)
          ..setEntry(0, 3, x)
          ..setEntry(1, 3, y);
      });
    }
  }

  void _resetZoom() {
    HapticFeedback.selectionClick();
    setState(() {
      _transformationController.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Image View (Blurred if hidden, Crisp InteractiveViewer if revealed)
        if (!widget.isRevealed)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Image.network(
              widget.media.mediaUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFF150D20),
              ),
            ),
          )
        else
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTapDown: (details) => _doubleTapDetails = details,
            onDoubleTap: _handleDoubleTap,
            onTap: widget.onToggleOverlays,
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 1.0,
              maxScale: 5.0,
              clipBehavior: Clip.none,
              child: Center(
                child: Image.network(
                  widget.media.mediaUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFFF758C)),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Floating Reset Zoom Button when zoomed in
        if (widget.isRevealed && _isZoomed)
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            right: 18,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _resetZoom,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.zoom_out_map_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Reset Zoom',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // 2. Frosted Privacy Overlay & "Tap to View" Button when hidden (ONLY button reveals)
        if (!widget.isRevealed)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.black.withValues(alpha: 0.85),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF758C)
                                .withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Private Photo',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap the button below to decrypt and view this private photo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF758C)
                                .withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: widget.onToggleReveal,
                        icon: const Icon(
                          Icons.visibility_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'View Photo',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Video Page Item with Inline Player Controls, Tap to View, and Privacy Mask
class _VaultVideoPageItem extends StatefulWidget {
  final SecretMediaModel media;
  final bool isActivePage;
  final bool isRevealed;
  final VoidCallback onToggleReveal;
  final VoidCallback onToggleOverlays;

  const _VaultVideoPageItem({
    required this.media,
    required this.isActivePage,
    required this.isRevealed,
    required this.onToggleReveal,
    required this.onToggleOverlays,
  });

  @override
  State<_VaultVideoPageItem> createState() => _VaultVideoPageItemState();
}

class _VaultVideoPageItemState extends State<_VaultVideoPageItem> {
  VideoPlayerController? _controller;
  Future<void>? _initFuture;
  bool _isPlaying = false;
  bool _isMuted = false;
  String? _videoError;

  int _quarterTurns = 0;
  late TransformationController _videoTransformationController;
  TapDownDetails? _videoDoubleTapDetails;
  bool _isVideoZoomed = false;

  @override
  void initState() {
    super.initState();
    _videoTransformationController = TransformationController();
    _videoTransformationController.addListener(_onVideoTransformationChanged);

    if (widget.isActivePage && widget.isRevealed) {
      _initVideo();
    }
  }

  void _onVideoTransformationChanged() {
    final scale = _videoTransformationController.value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.05;
    if (isZoomed != _isVideoZoomed) {
      setState(() {
        _isVideoZoomed = isZoomed;
      });
    }
  }

  @override
  void didUpdateWidget(covariant _VaultVideoPageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.isActivePage && widget.isRevealed) &&
        (!oldWidget.isActivePage ||
            !oldWidget.isRevealed ||
            _controller == null)) {
      _initVideo();
    } else if (!widget.isActivePage || !widget.isRevealed) {
      if (_controller != null && _isPlaying) {
        _controller?.pause();
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoTransformationController
        .removeListener(_onVideoTransformationChanged);
    _videoTransformationController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    try {
      _controller?.dispose();
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.media.mediaUrl));
      _controller = controller;
      _initFuture = controller.initialize().then((_) {
        if (mounted) {
          setState(() {
            _videoError = null;
            _isPlaying = controller.value.isPlaying;
          });
          controller.setLooping(true);
        }
      });
      controller.addListener(() {
        if (mounted) {
          setState(() {
            _isPlaying = controller.value.isPlaying;
          });
        }
      });
      setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _videoError = 'Failed to load video: $e';
        });
      }
    }
  }

  void _rotateVideo() {
    HapticFeedback.selectionClick();
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
    });
  }

  void _handleVideoDoubleTap() {
    HapticFeedback.selectionClick();
    if (_isVideoZoomed) {
      setState(() {
        _videoTransformationController.value = Matrix4.identity();
      });
    } else {
      final position = _videoDoubleTapDetails?.localPosition ?? Offset.zero;
      final x = -position.dx * (2.2 - 1);
      final y = -position.dy * (2.2 - 1);
      setState(() {
        _videoTransformationController.value = Matrix4.identity()
          ..setEntry(0, 0, 2.2)
          ..setEntry(1, 1, 2.2)
          ..setEntry(0, 3, x)
          ..setEntry(1, 3, y);
      });
    }
  }

  void _resetVideoZoom() {
    HapticFeedback.selectionClick();
    setState(() {
      _videoTransformationController.value = Matrix4.identity();
    });
  }

  void _togglePlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  void _toggleMute() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isRevealed) {
      final displayThumbnail = widget.media.thumbnail?.isNotEmpty == true
          ? widget.media.thumbnail!
          : widget.media.displayUrl;

      return Stack(
        fit: StackFit.expand,
        children: [
          // Blurred Thumbnail
          if (displayThumbnail.isNotEmpty)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Image.network(
                displayThumbnail,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFF150D20),
                ),
              ),
            )
          else
            Container(color: const Color(0xFF150D20)),

          // Dark frosted privacy mask (ONLY button reveals)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.black.withValues(alpha: 0.85),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF758C)
                                .withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.videocam_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Private Video',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap the button below to decrypt and play this private video.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF758C)
                                .withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: widget.onToggleReveal,
                        icon: const Icon(
                          Icons.visibility_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'View Video',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_videoError != null) {
      return Center(
        child: Text(
          _videoError!,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    final controller = _controller;
    final initFuture = _initFuture;

    if (controller == null || initFuture == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF758C)),
      );
    }

    return FutureBuilder<void>(
      future: initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF758C)),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: (d) => _videoDoubleTapDetails = d,
          onDoubleTap: _handleVideoDoubleTap,
          onTap: widget.onToggleOverlays,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Interactive Video Player with Pinch Zoom & Animated Rotation
              Center(
                child: InteractiveViewer(
                  transformationController: _videoTransformationController,
                  minScale: 1.0,
                  maxScale: 5.0,
                  clipBehavior: Clip.none,
                  child: AnimatedRotation(
                    turns: _quarterTurns * 0.25,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOutCubic,
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
              ),

              // Center Play/Pause Overlay Button
              if (!_isPlaying)
                Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _togglePlayPause,
                      borderRadius: BorderRadius.circular(40),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),

              // Floating Reset Zoom Button when zoomed in
              if (_isVideoZoomed)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 70,
                  right: 18,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _resetVideoZoom,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.zoom_out_map_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Reset Zoom',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Bottom Video Controls Bar
              Positioned(
                left: 20,
                right: 20,
                bottom: 100,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12,
                              ),
                              activeTrackColor: const Color(0xFFFF758C),
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: controller.value.position.inMilliseconds
                                  .clamp(
                                    0,
                                    controller.value.duration.inMilliseconds,
                                  )
                                  .toDouble() /
                                  (controller.value.duration.inMilliseconds
                                      .clamp(1, double.maxFinite.toInt())
                                      .toDouble()),
                              onChanged:
                                  controller.value.duration.inMilliseconds == 0
                                      ? null
                                      : (val) {
                                          final target = Duration(
                                            milliseconds: (controller
                                                        .value
                                                        .duration
                                                        .inMilliseconds *
                                                    val)
                                                .round(),
                                          );
                                          controller.seekTo(target);
                                        },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(
                                      _isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    onPressed: _togglePlayPause,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${_formatDuration(controller.value.position)} / ${_formatDuration(controller.value.duration)}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  // Rotate Video Button
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Rotate 90°',
                                    icon: const Icon(
                                      Icons.rotate_right_rounded,
                                      color: Colors.white70,
                                      size: 22,
                                    ),
                                    onPressed: _rotateVideo,
                                  ),
                                  const SizedBox(width: 12),
                                  // Mute/Unmute Button
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(
                                      _isMuted
                                          ? Icons.volume_off_rounded
                                          : Icons.volume_up_rounded,
                                      color: Colors.white70,
                                      size: 20,
                                    ),
                                    onPressed: _toggleMute,
                                  ),
                                  const SizedBox(width: 12),
                                  // Full View Toggle
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Full View',
                                    icon: const Icon(
                                      Icons.fullscreen_rounded,
                                      color: Colors.white70,
                                      size: 22,
                                    ),
                                    onPressed: widget.onToggleOverlays,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
