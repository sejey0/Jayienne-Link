import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/photo_message_model.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/photo_message_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/smart_profile_image.dart';

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key});

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _captionFocusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isComposerHidden = false;
  bool _isSaving = false;
  static const String _editConfirmationPhrase = 'i love you';

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _selectedImage = File(picked.path);
    });
  }

  Future<void> _sendPhoto(PhotoMessageProvider provider) async {
    final imageFile = _selectedImage;
    if (imageFile == null) return;

    final caption = _captionController.text.trim();
    final didSend = await provider.sendPhotoMessage(
      imageFile: imageFile,
      caption: caption.isNotEmpty ? caption : null,
    );

    if (!mounted) return;

    if (didSend) {
      setState(() {
        _selectedImage = null;
      });
      _captionController.clear();
      _captionFocusNode.unfocus();
    }
  }

  Future<void> _handleRefresh(PhotoMessageProvider provider) async {
    if (provider.isRefreshing) return;
    await provider.refreshNow();
  }

  Future<void> _downloadToGallery(
    PhotoMessageModel message,
  ) async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final hasPermission = await _ensureGalleryPermission();
      if (!mounted) return;
      if (!hasPermission) {
        SnackbarHelper.showError(context, 'Gallery permission is required.');
        return;
      }

      final bytes = await _loadImageBytes(message.imageUrl);
      if (!mounted) return;
      final name =
          message.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      final result = await ImageGallerySaver.saveImage(
        bytes,
        name: 'jayienne_$name',
        quality: 95,
      );

      if (!mounted) return;

      final success = result is Map &&
          ((result['isSuccess'] == true) || (result['success'] == true));

      if (success) {
        SnackbarHelper.showSuccess(context, 'Saved to gallery.');
      } else {
        SnackbarHelper.showError(context, 'Save failed. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Save failed: $e');
      }
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<bool> _ensureGalleryPermission() async {
    if (kIsWeb) return true;

    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 29) {
        return true;
      }

      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }

    return true;
  }

  Future<Uint8List> _loadImageBytes(String imageUrl) async {
    if (imageUrl.startsWith('data:image/')) {
      final base64String = imageUrl.split(',').last;
      return base64Decode(base64String);
    }

    final uri = Uri.parse(imageUrl);
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('Download failed (${response.statusCode})');
      }
      return await consolidateHttpClientResponseBytes(response);
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoProvider = context.watch<PhotoMessageProvider>();
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final user = userProvider.user;
    final couple = coupleProvider.couple;
    final partner = coupleProvider.partner;
    final messages = photoProvider.messages;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Shared Photo Feed',
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
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: photoProvider.isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh, color: Colors.white),
            onPressed: photoProvider.isRefreshing
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    _handleRefresh(photoProvider);
                  },
          ),
        ],
        elevation: 0,
      ),
      body: user == null || couple == null
          ? Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLg),
              child: _buildNotLinkedState(context),
            )
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.spacingLg,
                      AppDimensions.spacingLg,
                      AppDimensions.spacingLg,
                      0,
                    ),
                    child: Column(
                      children: [
                        if (photoProvider.error != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppDimensions.spacingSm,
                            ),
                            child: Text(
                              photoProvider.error!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.error,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        Expanded(
                          child: messages.isEmpty
                              ? _buildEmptyState(context)
                              : ListView.separated(
                                  reverse: true,
                                  padding: const EdgeInsets.only(
                                    bottom: AppDimensions.spacingSm,
                                  ),
                                  itemCount: messages.length,
                                  separatorBuilder: (_, __) => const SizedBox(
                                    height: AppDimensions.spacingSm,
                                  ),
                                  itemBuilder: (context, index) {
                                    return _buildPhotoTile(
                                      context,
                                      message: messages[index],
                                      photoProvider: photoProvider,
                                      userId: user.id,
                                      userPhotoUrl: user.photoUrl,
                                      partnerPhotoUrl: partner?.photoUrl,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedPadding(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.fromLTRB(
                    AppDimensions.spacingLg,
                    AppDimensions.spacingSm,
                    AppDimensions.spacingLg,
                    isKeyboardOpen
                        ? AppDimensions.spacingXs
                        : AppDimensions.spacingLg,
                  ),
                  child: _buildComposer(
                    context,
                    photoProvider: photoProvider,
                    onPickGallery: () => _pickImage(ImageSource.gallery),
                    onPickCamera: () => _pickImage(ImageSource.camera),
                    onSend: () => _sendPhoto(photoProvider),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildComposer(
    BuildContext context, {
    required PhotoMessageProvider photoProvider,
    required VoidCallback onPickGallery,
    required VoidCallback onPickCamera,
    required VoidCallback onSend,
  }) {
    final canSend = photoProvider.canSend && !photoProvider.isSending;
    final hasImage = _selectedImage != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final previewHeight = isKeyboardOpen ? 90.0 : 160.0;
    final placeholderHeight = isKeyboardOpen ? 52.0 : 100.0;
    final captionMaxLines = isKeyboardOpen ? 1 : 2;
    final verticalSpacing = isKeyboardOpen ? 4.0 : AppDimensions.spacingSm;
    final fieldVerticalPadding = isKeyboardOpen ? 4.0 : AppDimensions.spacingSm;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxComposerHeight =
        isKeyboardOpen ? screenHeight * 0.32 : double.infinity;
    final cardPadding = EdgeInsets.fromLTRB(
      AppDimensions.cardPadding,
      isKeyboardOpen ? AppDimensions.spacingSm : AppDimensions.cardPadding,
      AppDimensions.cardPadding,
      isKeyboardOpen ? AppDimensions.spacingSm : AppDimensions.cardPadding,
    );

    if (_isComposerHidden) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _isComposerHidden = false);
        },
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFF06292), Color(0xFF9C27B0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.photo_library_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Share a photo',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 20,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ],
          ),
        ),
      );
    }

    final composerBody = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const SizedBox(width: 32),
            Expanded(
              child: Text(
                'Share a photo',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              tooltip: 'Hide',
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                _captionFocusNode.unfocus();
                FocusScope.of(context).unfocus();
                setState(() => _isComposerHidden = true);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        SizedBox(height: verticalSpacing),
        if (hasImage)
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF06292).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF06292).withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.file(
                    _selectedImage!,
                    height: previewHeight,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedImage = null);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showPickImageSheet(context);
            },
            child: Container(
              height: placeholderHeight,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : AppColors.softRose.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? AppColors.softRose.withValues(alpha: 0.2)
                      : AppColors.softRose.withValues(alpha: 0.25),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF06292), Color(0xFF9C27B0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF06292).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Select or snap a photo',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white70 : AppColors.deepCharcoal,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        SizedBox(height: verticalSpacing),
        TextField(
          controller: _captionController,
          focusNode: _captionFocusNode,
          enabled: canSend,
          minLines: 1,
          maxLines: captionMaxLines,
          textInputAction: TextInputAction.send,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.darkText : AppColors.deepCharcoal,
              ),
          cursorColor: isDark ? AppColors.lavender : AppColors.softRose,
          onSubmitted: (_) => onSend(),
          decoration: InputDecoration(
            hintText: 'Add a sweet caption (optional)...',
            hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
            filled: true,
            fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade100,
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingMd,
              vertical: fieldVerticalPadding,
            ),
            prefixIcon: const Icon(
              Icons.edit_note_rounded,
              color: AppColors.softRose,
              size: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? AppColors.lavender : AppColors.softRose,
              ),
            ),
          ),
        ),
        SizedBox(height: verticalSpacing),
        Row(
          children: [
            _buildSquircleActionButton(
              icon: Icons.photo_library_rounded,
              label: 'Gallery',
              gradientColors: const [Color(0xFFF06292), Color(0xFF9C27B0)],
              onPressed: canSend ? onPickGallery : null,
              isDark: isDark,
            ),
            SizedBox(width: isKeyboardOpen ? 4 : AppDimensions.spacingSm),
            _buildSquircleActionButton(
              icon: Icons.photo_camera_rounded,
              label: 'Camera',
              gradientColors: const [Color(0xFFFF5252), Color(0xFFD81B60)],
              onPressed: canSend ? onPickCamera : null,
              isDark: isDark,
            ),
            SizedBox(width: isKeyboardOpen ? 4 : AppDimensions.spacingSm),
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  gradient: (canSend && hasImage)
                      ? const LinearGradient(
                          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: (canSend && hasImage)
                      ? null
                      : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: (canSend && hasImage)
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: ElevatedButton.icon(
                  onPressed: (canSend && hasImage) ? onSend : null,
                  icon: photoProvider.isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 16),
                  label: const Text(
                    'Send photo',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledForegroundColor:
                        isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    final composerContent = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxComposerHeight),
      child: SingleChildScrollView(
        physics: isKeyboardOpen
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        child: composerBody,
      ),
    );

    return AppCard(
      padding: cardPadding,
      child: composerContent,
    );
  }

  void _showPickImageSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1427) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: AppColors.softRose.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose Photo Source',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: isDark ? Colors.white : AppColors.deepCharcoal,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSourceModalTile(
                    ctx,
                    title: 'Gallery',
                    icon: Icons.photo_library_rounded,
                    gradientColors: const [Color(0xFFF06292), Color(0xFF9C27B0)],
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery);
                    },
                    isDark: isDark,
                  ),
                  _buildSourceModalTile(
                    ctx,
                    title: 'Camera',
                    icon: Icons.photo_camera_rounded,
                    gradientColors: const [Color(0xFFFF5252), Color(0xFFD81B60)],
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.camera);
                    },
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSourceModalTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 130,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.softRose.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? AppColors.softRose.withValues(alpha: 0.2)
                : AppColors.softRose.withValues(alpha: 0.25),
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white : AppColors.deepCharcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquircleActionButton({
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
    required VoidCallback? onPressed,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.softRose.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? AppColors.softRose.withValues(alpha: 0.2)
                : AppColors.softRose.withValues(alpha: 0.25),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, size: 15, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.deepCharcoal,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotLinkedState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF06292), Color(0xFF9C27B0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF06292).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.photo_library_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            'Link with your love to share Photo Feed',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            'Once linked, you can share photos and memories instantly.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white60 : Colors.grey,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF06292), Color(0xFF9C27B0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF06292).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.photo_library_rounded,
              size: 36,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'No photos shared yet',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Snap or upload a photo to start your memory feed!',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoTile(
    BuildContext context, {
    required PhotoMessageModel message,
    required PhotoMessageProvider photoProvider,
    required String? userId,
    required String? userPhotoUrl,
    required String? partnerPhotoUrl,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMine = message.senderId == userId;
    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(AppDimensions.borderRadiusMedium),
      topRight: const Radius.circular(AppDimensions.borderRadiusMedium),
      bottomLeft: Radius.circular(
        isMine ? AppDimensions.borderRadiusMedium : 6,
      ),
      bottomRight: Radius.circular(
        isMine ? 6 : AppDimensions.borderRadiusMedium,
      ),
    );
    final caption = message.caption?.trim();
    final hasCaption = caption != null && caption.isNotEmpty;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine) ...[
              _buildAvatar(
                photoUrl: partnerPhotoUrl,
                accentColor: AppColors.softRose,
                fallbackIcon: Icons.favorite,
              ),
              const SizedBox(width: AppDimensions.spacingSm),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.60,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF231A33) : Colors.white,
                      borderRadius: bubbleRadius,
                      border: Border.all(
                        color: isDark
                            ? (isMine
                                ? AppColors.lavender.withValues(alpha: 0.3)
                                : AppColors.softRose.withValues(alpha: 0.3))
                            : (isMine
                                ? AppColors.lavender.withValues(alpha: 0.2)
                                : AppColors.softRose.withValues(alpha: 0.2)),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isMine ? AppColors.lavender : AppColors.softRose)
                              .withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: bubbleRadius,
                        onTap: () => _showPhotoViewer(context, message),
                        child: ClipRRect(
                          borderRadius: bubbleRadius,
                          child: _buildPhotoImage(message.imageUrl),
                        ),
                      ),
                    ),
                  ),
                  if (hasCaption) ...[
                    const SizedBox(height: 4),
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.60,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingMd,
                        vertical: AppDimensions.spacingSm,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? (isMine
                                ? AppColors.lavender.withValues(alpha: 0.25)
                                : AppColors.softRose.withValues(alpha: 0.25))
                            : (isMine
                                ? AppColors.lavenderLight
                                : AppColors.softRoseLight),
                        borderRadius: bubbleRadius,
                      ),
                      child: Text(
                        caption,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkText
                                  : AppColors.deepCharcoal,
                            ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  _buildMetaRow(
                    context,
                    message,
                    isMine,
                    photoProvider: photoProvider,
                  ),
                ],
              ),
            ),
            if (isMine) ...[
              const SizedBox(width: AppDimensions.spacingSm),
              _buildAvatar(
                photoUrl: userPhotoUrl,
                accentColor: AppColors.lavender,
                fallbackIcon: Icons.person,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(
    BuildContext context,
    PhotoMessageModel message,
    bool isMine, {
    required PhotoMessageProvider photoProvider,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messageId = message.id;
    final hasSeen =
        messageId != null && isMine && photoProvider.isSeenByPartner(messageId);
    final seenTextStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isDark ? AppColors.lavender : Colors.grey.shade600,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        );
    final timeTextStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
          fontSize: 11,
        );

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            message.formattedDateTime,
            style: timeTextStyle,
          ),
          if (hasSeen) ...[
            const SizedBox(width: 6),
            Text(
              'Seen',
              style: seenTextStyle,
            ),
          ],
          const SizedBox(width: 4),
          SizedBox(
            width: 22,
            height: 22,
            child: PopupMenuButton<_PhotoMessageAction>(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.more_horiz,
                size: 18,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              onSelected: (action) {
                if (action == _PhotoMessageAction.download) {
                  _downloadToGallery(message);
                } else if (action == _PhotoMessageAction.edit) {
                  _showEditCaptionDialog(context, message);
                } else if (action == _PhotoMessageAction.delete) {
                  _confirmDelete(context, message);
                }
              },
              itemBuilder: (context) {
                return [
                  const PopupMenuItem(
                    value: _PhotoMessageAction.download,
                    child: Row(
                      children: [
                        Icon(Icons.download, size: 18),
                        SizedBox(width: 8),
                        Text('Download'),
                      ],
                    ),
                  ),
                  if (isMine)
                    const PopupMenuItem(
                      value: _PhotoMessageAction.edit,
                      child: Text('Edit caption'),
                    ),
                  if (isMine)
                    const PopupMenuItem(
                      value: _PhotoMessageAction.delete,
                      child: Text('Delete'),
                    ),
                ];
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditCaptionDialog(
    BuildContext context,
    PhotoMessageModel message,
  ) async {
    if (message.id == null) return;
    final provider = context.read<PhotoMessageProvider>();
    final updatedCaption = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return _EditCaptionDialog(
          initialCaption: message.caption ?? '',
          confirmationPhrase: _editConfirmationPhrase,
        );
      },
    );

    if (updatedCaption == null) return;
    final updated = await provider.updateCaption(
      messageId: message.id!,
      caption: updatedCaption,
    );
    if (!updated && context.mounted) {
      SnackbarHelper.showError(
        context,
        provider.error ?? 'Unable to update caption.',
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PhotoMessageModel message,
  ) async {
    if (message.id == null) return;
    final provider = context.read<PhotoMessageProvider>();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return const _DeletePhotoDialog(
               confirmationPhrase: _editConfirmationPhrase,
            );
          },
        ) ??
        false;

    if (!confirmed) return;
    final deleted = await provider.deleteMessage(message.id!);
    if (!deleted && context.mounted) {
      SnackbarHelper.showError(
        context,
        provider.error ?? 'Unable to delete photo.',
      );
    }
  }

  Widget _buildPhotoImage(String imageUrl) {
    if (imageUrl.startsWith('data:image/')) {
      try {
        final base64String = imageUrl.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          height: 200,
          fit: BoxFit.cover,
        );
      } catch (_) {
        return _buildImageFallback();
      }
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      height: 200,
      fit: BoxFit.cover,
      placeholder: (_, __) => _buildImageFallback(isLoading: true),
      errorWidget: (_, __, ___) => _buildImageFallback(),
    );
  }

  void _showPhotoViewer(BuildContext context, PhotoMessageModel message) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: _buildFullPhotoImage(message.imageUrl),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Save to gallery',
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download, color: Colors.white),
                        onPressed: _isSaving
                            ? null
                            : () => _downloadToGallery(message),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFullPhotoImage(String imageUrl) {
    if (imageUrl.startsWith('data:image/')) {
      try {
        final base64String = imageUrl.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
        );
      } catch (_) {
        return const Icon(Icons.broken_image_outlined, color: Colors.white54);
      }
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      placeholder: (_, __) => const CircularProgressIndicator(
        color: Colors.white,
      ),
      errorWidget: (_, __, ___) =>
          const Icon(Icons.broken_image_outlined, color: Colors.white54),
    );
  }

  Widget _buildImageFallback({bool isLoading = false}) {
    return Container(
      height: 200,
      color: Colors.grey.shade200,
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : const Icon(Icons.broken_image_outlined, color: Colors.grey),
      ),
    );
  }

  Widget _buildAvatar({
    required String? photoUrl,
    required Color accentColor,
    required IconData fallbackIcon,
  }) {
    const double size = 32;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accentColor, width: 2),
      ),
      child: ClipOval(
        child: SmartProfileImage(
          imageUrl: photoUrl,
          width: size,
          height: size,
          placeholder: _buildAvatarPlaceholder(size, accentColor, fallbackIcon),
          errorWidget: _buildAvatarPlaceholder(size, accentColor, fallbackIcon),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(
    double size,
    Color accentColor,
    IconData icon,
  ) {
    return Container(
      width: size,
      height: size,
      color: accentColor.withValues(alpha: 0.15),
      child: Icon(
        icon,
        size: 18,
        color: accentColor,
      ),
    );
  }
}

class _EditCaptionDialog extends StatefulWidget {
  const _EditCaptionDialog({
    required this.initialCaption,
    required this.confirmationPhrase,
  });

  final String initialCaption;
  final String confirmationPhrase;

  @override
  State<_EditCaptionDialog> createState() => _EditCaptionDialogState();
}

class _EditCaptionDialogState extends State<_EditCaptionDialog> {
  late final TextEditingController _captionController;
  late final TextEditingController _confirmController;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.initialCaption);
    _confirmController = TextEditingController();
    _confirmController.addListener(_onConfirmChanged);
  }

  void _onConfirmChanged() {
    if (!mounted) return;
    setState(() {});
  }

  bool get _isConfirmed =>
      _confirmController.text.trim().toLowerCase() == widget.confirmationPhrase;

  @override
  void dispose() {
    _confirmController.removeListener(_onConfirmChanged);
    _captionController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1C1427) : Colors.white,
      scrollable: true,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Edit Caption',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: isDark ? Colors.white : AppColors.deepCharcoal,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _captionController,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Caption',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          TextField(
            controller: _confirmController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Type "${widget.confirmationPhrase}" to save',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFF758C), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: _isConfirmed
                        ? const LinearGradient(
                            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: _isConfirmed ? null : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: _isConfirmed
                        ? () => Navigator.of(context).pop(_captionController.text)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white70,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeletePhotoDialog extends StatefulWidget {
  const _DeletePhotoDialog({
    required this.confirmationPhrase,
  });

  final String confirmationPhrase;

  @override
  State<_DeletePhotoDialog> createState() => _DeletePhotoDialogState();
}

class _DeletePhotoDialogState extends State<_DeletePhotoDialog> {
  final TextEditingController _confirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _confirmController.addListener(_onConfirmChanged);
  }

  void _onConfirmChanged() {
    if (!mounted) return;
    setState(() {});
  }

  bool get _isConfirmed =>
      _confirmController.text.trim().toLowerCase() == widget.confirmationPhrase;

  @override
  void dispose() {
    _confirmController.removeListener(_onConfirmChanged);
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1C1427) : Colors.white,
      scrollable: true,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF5252), Color(0xFFD81B60)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Delete Photo?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: isDark ? Colors.white : AppColors.deepCharcoal,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'This will permanently remove the photo from your shared feed.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          TextField(
            controller: _confirmController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Type "${widget.confirmationPhrase}" to delete',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFF758C), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: _isConfirmed
                        ? const LinearGradient(
                            colors: [Color(0xFFFF5252), Color(0xFFD81B60)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: _isConfirmed ? null : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed:
                        _isConfirmed ? () => Navigator.of(context).pop(true) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white70,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _PhotoMessageAction { download, edit, delete }
