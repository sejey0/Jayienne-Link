import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/secret_media_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/supabase_storage_service.dart';
import '../../../widgets/common/app_text_field.dart';

/// Redesigned Screen for Uploading and Encrypting Private Photos & Videos
class AddSecretMediaScreen extends StatefulWidget {
  final String initialMediaType;

  const AddSecretMediaScreen({
    super.key,
    this.initialMediaType = 'image',
  });

  @override
  State<AddSecretMediaScreen> createState() => _AddSecretMediaScreenState();
}

class _AddSecretMediaScreenState extends State<AddSecretMediaScreen> {
  late ImagePicker _imagePicker;
  File? _selectedFile;
  late String _mediaType; // 'image' or 'video'
  final TextEditingController _captionController = TextEditingController();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _imagePicker = ImagePicker();
    _mediaType = widget.initialMediaType == 'video' ? 'video' : 'image';
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(String type, {ImageSource source = ImageSource.gallery}) async {
    HapticFeedback.lightImpact();
    try {
      XFile? pickedFile;

      if (type == 'image') {
        pickedFile = await _imagePicker.pickImage(
          source: source,
          imageQuality: 88,
        );
      } else {
        pickedFile = await _imagePicker.pickVideo(
          source: source,
        );
      }

      if (pickedFile != null) {
        setState(() {
          _selectedFile = File(pickedFile!.path);
          _mediaType = type;
        });
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to pick media: $e');
      }
    }
  }

  Future<void> _uploadMedia() async {
    if (_selectedFile == null) {
      SnackbarHelper.showError(context, 'Please select a photo or video first');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    final secretMediaProvider = context.read<SecretMediaProvider>();
    final storageService = SupabaseStorageService();

    if (authProvider.currentUserId == null) {
      SnackbarHelper.showError(context, 'User not authenticated');
      return;
    }

    final user = userProvider.user;
    final coupleId = user?.coupleId;
    if (user == null || coupleId == null || coupleId.isEmpty) {
      SnackbarHelper.showError(
        context,
        'Link with your partner first to upload to your private vault',
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isUploading = true;
    });

    try {
      await secretMediaProvider.initialize(
        userId: user.id,
        coupleId: coupleId,
      );

      final currentType = _mediaType;
      final mediaUrl = await storageService.uploadSecretMedia(
        authProvider.currentUserId!,
        _selectedFile!,
        currentType,
      );

      final createdMedia = await secretMediaProvider.addSecretMedia(
        mediaType: currentType,
        mediaUrl: mediaUrl,
        caption: _captionController.text.trim().isNotEmpty
            ? _captionController.text.trim()
            : null,
        isHidden: true,
      );

      if (createdMedia == null) {
        throw Exception(secretMediaProvider.error ?? 'Failed to save media');
      }

      if (mounted) {
        HapticFeedback.heavyImpact();
        // Reset form state so no traces or pending upload files remain
        setState(() {
          _selectedFile = null;
          _captionController.clear();
        });

        // Show elegant success confirmation modal
        _showUploadSuccessModal(context, isVideo: currentType == 'video');
      }
    } catch (e) {
      final message = e.toString();
      if (mounted) {
        if (message.contains('Bucket not found') ||
            message.contains('secret-media')) {
          SnackbarHelper.showError(
            context,
            'Vault storage bucket is being initialized. Please try again.',
          );
        } else {
          SnackbarHelper.showError(context, 'Upload failed: $e');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showUploadSuccessModal(BuildContext context, {required bool isVideo}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E142B) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFF00B09B).withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00B09B).withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing Animated Emerald / Lavender Success Badge
              Container(
                padding: const EdgeInsets.all(18),
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
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  isVideo ? Icons.videocam_rounded : Icons.photo_library_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                isVideo ? 'Private Video Saved!' : 'Private Photo Saved!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF2D4059),
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                isVideo
                    ? 'Your private video has been safely encrypted and saved to your Hidden Vault.'
                    : 'Your private photo has been safely encrypted and saved to your Hidden Vault.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Security & Hidden Vault Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B09B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF00B09B).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      color: Color(0xFF00B09B),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Encrypted & Hidden in Vault',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF00897B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons Row
              Row(
                children: [
                  // Upload Another (Stays on screen with reset inputs)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(dialogCtx);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : Colors.grey.shade800,
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Upload More',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Go to Vault (Returns to Hidden Vault)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(dialogCtx); // Close modal
                          Navigator.pop(context);   // Return to Hidden Vault
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Go to Vault',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E142B) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF130D1B) : const Color(0xFFFFF7F9),
      appBar: AppBar(
        title: const Text(
          'Add Private Media',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
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
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Media Type Selector (Photos / Videos)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTypeSegment(
                      label: 'Photo',
                      icon: Icons.photo_library_rounded,
                      isSelected: _mediaType == 'image',
                      onTap: () {
                        setState(() {
                          _mediaType = 'image';
                          _selectedFile = null;
                        });
                      },
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildTypeSegment(
                      label: 'Video',
                      icon: Icons.videocam_rounded,
                      isSelected: _mediaType == 'video',
                      onTap: () {
                        setState(() {
                          _mediaType = 'video';
                          _selectedFile = null;
                        });
                      },
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 2. Media Preview or Pick Container
            if (_selectedFile != null)
              Container(
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_mediaType == 'image')
                        Image.file(
                          _selectedFile!,
                          fit: BoxFit.cover,
                        )
                      else
                        Container(
                          color: const Color(0xFF1A1124),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
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
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.videocam_rounded,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Video Selected',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedFile!.path.split(Platform.pathSeparator).last,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Top Type Badge
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _mediaType == 'image'
                                    ? Icons.image_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _mediaType.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Top Right Action Buttons (Change & Remove)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: const CircleBorder(),
                              child: IconButton(
                                icon: const Icon(Icons.change_circle_rounded, color: Colors.white, size: 20),
                                tooltip: 'Change Media',
                                onPressed: () => _pickMedia(_mediaType),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Material(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: const CircleBorder(),
                              child: IconButton(
                                icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 20),
                                tooltip: 'Remove',
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _selectedFile = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade200,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFF758C).withValues(alpha: 0.15),
                            const Color(0xFFA18CD1).withValues(alpha: 0.15),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _mediaType == 'image'
                            ? Icons.add_photo_alternate_rounded
                            : Icons.video_call_rounded,
                        size: 40,
                        color: const Color(0xFFFF758C),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _mediaType == 'image'
                          ? 'Select Private Photo'
                          : 'Select Private Video',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF2D4059),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose a private memory to encrypt in your vault',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickMedia(_mediaType, source: ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded, size: 18),
                            label: const Text('Gallery'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFF758C),
                              side: const BorderSide(color: Color(0xFFFF758C), width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickMedia(_mediaType, source: ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_rounded, size: 18),
                            label: const Text('Camera'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFA18CD1),
                              side: const BorderSide(color: Color(0xFFA18CD1), width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 18),

            // 3. Caption / Note Input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Caption (Optional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: _captionController,
                    hintText: 'Add a romantic note or memory description...',
                    prefixIcon: Icons.edit_note_rounded,
                    isDark: isDark,
                    maxLines: 3,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 4. Privacy & End-to-End Encryption Notice Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E142B) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF00B09B).withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B09B).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF00B09B),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Encrypted & Hidden',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.deepCharcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Uploads are placed directly into Hidden Vault and protected by your 6 security keys.',
                          style: TextStyle(
                            fontSize: 11,
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

            // 5. Encrypt & Upload Primary Button
            Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: _selectedFile != null
                    ? const LinearGradient(
                        colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: _selectedFile == null ? Colors.grey.shade400 : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _selectedFile != null
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF758C).withValues(alpha: 0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: ElevatedButton.icon(
                onPressed: (_isUploading || _selectedFile == null) ? null : _uploadMedia,
                icon: _isUploading
                    ? const SizedBox.shrink()
                    : const Icon(Icons.lock_rounded, size: 20),
                label: _isUploading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      )
                    : const Text(
                        'Encrypt & Save to Vault',
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
                  disabledForegroundColor: Colors.white70,
                  disabledBackgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSegment({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF758C)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white60 : Colors.grey.shade700),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
