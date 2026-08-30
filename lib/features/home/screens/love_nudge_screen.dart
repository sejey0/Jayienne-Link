import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/supabase_love_nudge_service.dart';
import '../../../widgets/common/love_nudge_overlay_listener.dart';

/// Senior Love Nudge Screen supporting custom photo uploads for Kiss & Hug and live real-time visual screen effects
class LoveNudgeScreen extends StatefulWidget {
  const LoveNudgeScreen({super.key});

  @override
  State<LoveNudgeScreen> createState() => _LoveNudgeScreenState();
}

class _LoveNudgeScreenState extends State<LoveNudgeScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _messageController = TextEditingController();

  String? _kissPhotoUrl;
  String? _hugPhotoUrl;
  bool _isUploadingKissPhoto = false;
  bool _isUploadingHugPhoto = false;
  bool _isKissPressed = false;
  bool _isHugPressed = false;
  List<String> _savedMessageTemplates = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPhotos();
    _loadSavedMessageTemplates();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _kissPhotoUrl = prefs.getString('love_nudge_custom_kiss_photo');
      _hugPhotoUrl = prefs.getString('love_nudge_custom_hug_photo');
    });
  }

  Future<void> _loadSavedMessageTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('love_nudge_saved_message_templates') ?? [];
    if (!mounted) return;
    setState(() {
      _savedMessageTemplates = list;
    });
  }

  Future<void> _saveMessageTemplate(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    final list = List<String>.from(_savedMessageTemplates);
    list.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
    list.insert(0, trimmed);

    if (list.length > 8) {
      list.removeRange(8, list.length);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('love_nudge_saved_message_templates', list);

    if (!mounted) return;
    setState(() {
      _savedMessageTemplates = list;
    });
  }

  Future<void> _deleteMessageTemplate(String template) async {
    HapticFeedback.lightImpact();
    final list = List<String>.from(_savedMessageTemplates)..remove(template);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('love_nudge_saved_message_templates', list);
    if (!mounted) return;
    setState(() {
      _savedMessageTemplates = list;
    });
  }

  Future<void> _savePhoto(bool isKiss, String? photoUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final key = isKiss ? 'love_nudge_custom_kiss_photo' : 'love_nudge_custom_hug_photo';
    if (photoUrl == null || photoUrl.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, photoUrl);
    }
  }

  Future<void> _pickAndUploadPhoto(bool isKiss, ImageSource source) async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (picked == null) return;

      setState(() {
        if (isKiss) {
          _isUploadingKissPhoto = true;
        } else {
          _isUploadingHugPhoto = true;
        }
      });

      HapticFeedback.mediumImpact();
      final uploadedUrl = await SupabaseLoveNudgeService().uploadLoveNudgePhoto(
        user.uid,
        File(picked.path),
      );

      await _savePhoto(isKiss, uploadedUrl);

      if (!mounted) return;
      setState(() {
        if (isKiss) {
          _kissPhotoUrl = uploadedUrl;
          _isUploadingKissPhoto = false;
        } else {
          _hugPhotoUrl = uploadedUrl;
          _isUploadingHugPhoto = false;
        }
      });

      SnackbarHelper.showSuccess(
        context,
        isKiss
            ? 'Custom Kiss photo has been saved!'
            : 'Custom Hug photo has been saved!',
        title: 'Photo Saved',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingKissPhoto = false;
        _isUploadingHugPhoto = false;
      });
      SnackbarHelper.showError(
        context,
        'Failed to upload photo: $e',
      );
    }
  }

  void _showPhotoOptionsModal(bool isKiss) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentPhoto = isKiss ? _kissPhotoUrl : _hugPhotoUrl;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E142B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isKiss ? 'Custom Virtual Kiss Photo' : 'Custom Warm Hug Photo',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Upload your photo to send with this nudge',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isKiss ? const Color(0xFFFF4081) : const Color(0xFFAB47BC)).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.photo_library_rounded,
                    color: isKiss ? const Color(0xFFFF4081) : const Color(0xFFAB47BC),
                  ),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhoto(isKiss, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isKiss ? const Color(0xFFFF4081) : const Color(0xFFAB47BC)).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: isKiss ? const Color(0xFFFF4081) : const Color(0xFFAB47BC),
                  ),
                ),
                title: const Text('Take a Snapshot', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhoto(isKiss, ImageSource.camera);
                },
              ),
              if (currentPhoto != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  ),
                  title: const Text('Delete Custom Photo', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmAndDeletePhoto(isKiss);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndDeletePhoto(bool isKiss) async {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final photoType = isKiss ? 'Virtual Kiss' : 'Warm Hug';

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E142B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Photo?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove the custom photo for $photoType?',
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
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
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _savePhoto(isKiss, null);
      if (!mounted) return;
      setState(() {
        if (isKiss) {
          _kissPhotoUrl = null;
        } else {
          _hugPhotoUrl = null;
        }
      });

      SnackbarHelper.showCustom(
        context: context,
        title: 'Photo Deleted',
        message: 'Your $photoType custom photo has been removed.',
        icon: Icons.delete_outline_rounded,
        gradientColors: const [Color(0xFFFF5252), Color(0xFFD81B60)],
      );
    }
  }

  void _triggerNudge({required bool isKiss, required String partnerName}) {
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();

    final coupleProvider = context.read<CoupleProvider>();
    final userProvider = context.read<UserProvider>();
    final couple = coupleProvider.couple;
    final user = userProvider.user;

    final photoUrl = isKiss ? _kissPhotoUrl : _hugPhotoUrl;
    final message = _messageController.text.trim();

    if (message.isNotEmpty) {
      _saveMessageTemplate(message);
    }

    final payload = LoveNudgePayload(
      senderId: user?.uid ?? '',
      senderName: user?.displayName.isNotEmpty == true ? user!.displayName : 'You',
      nudgeType: isKiss ? 'kiss' : 'hug',
      photoUrl: photoUrl,
      message: message.isNotEmpty ? message : null,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    // Send Realtime Broadcast to Partner
    if (couple != null && couple.id != null && user != null) {
      SupabaseLoveNudgeService().sendLoveNudge(
        coupleId: couple.id!,
        senderId: user.uid,
        senderName: user.displayName.isNotEmpty ? user.displayName : 'Your Love',
        nudgeType: isKiss ? 'kiss' : 'hug',
        photoUrl: photoUrl,
        message: message.isNotEmpty ? message : null,
      );
    }

    // Spawn Full Realtime Live Overlay locally on sender's device as well
    LoveNudgeOverlayListener.showLocalNudgeEffect(context, payload);

    final actionText = isKiss ? 'Virtual Kiss' : 'Virtual Hug';

    SnackbarHelper.showCustom(
      context: context,
      title: '$actionText Sent!',
      message: 'Successfully sent a $actionText to $partnerName',
      icon: isKiss ? Icons.favorite_rounded : Icons.volunteer_activism_rounded,
      gradientColors: isKiss
          ? const [Color(0xFFFF4081), Color(0xFFD81B60)]
          : const [Color(0xFFBA68C8), Color(0xFF7B1FA2)],
    );
  }

  Widget _buildPhotoThumbnail(String photoUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CachedNetworkImage(
        imageUrl: photoUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(
          color: Colors.white12,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF758C)),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.black26,
          child: const Icon(Icons.broken_image_rounded, size: 24, color: Colors.white60),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coupleProvider = context.watch<CoupleProvider>();
    final partner = coupleProvider.partner;
    final couple = coupleProvider.couple;
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;

    final partnerName = (partner != null && partner.displayName.isNotEmpty)
        ? partner.displayName
        : (couple != null && user != null
            ? couple.getPartnerName(user.uid, livePartnerName: partner?.displayName)
            : 'wifeyyy');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF120E19) : const Color(0xFFFFF7F9),
      appBar: AppBar(
        title: const Text(
          'Love Nudge',
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
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),

                // CARD 1: VIRTUAL KISS
                _buildNudgeCard(
                  isDark: isDark,
                  isKiss: true,
                  title: 'Virtual Kiss',
                  subtitle: 'Send your kiss with custom photo',
                  primaryColor: const Color(0xFFFF4081),
                  secondaryColor: const Color(0xFFFF5252),
                  photoUrl: _kissPhotoUrl,
                  isUploading: _isUploadingKissPhoto,
                  isPressed: _isKissPressed,
                  partnerName: partnerName,
                  onTapDown: () => setState(() => _isKissPressed = true),
                  onTapUp: () {
                    setState(() => _isKissPressed = false);
                    _triggerNudge(isKiss: true, partnerName: partnerName);
                  },
                  onTapCancel: () => setState(() => _isKissPressed = false),
                  onUploadTap: () => _showPhotoOptionsModal(true),
                  onDeletePhotoTap: () => _confirmAndDeletePhoto(true),
                ),
                const SizedBox(height: 20),

                // CARD 2: WARM HUG
                _buildNudgeCard(
                  isDark: isDark,
                  isKiss: false,
                  title: 'Warm Hug',
                  subtitle: 'Send your warm hug with custom photo',
                  primaryColor: const Color(0xFFAB47BC),
                  secondaryColor: const Color(0xFF7B1FA2),
                  photoUrl: _hugPhotoUrl,
                  isUploading: _isUploadingHugPhoto,
                  isPressed: _isHugPressed,
                  partnerName: partnerName,
                  onTapDown: () => setState(() => _isHugPressed = true),
                  onTapUp: () {
                    setState(() => _isHugPressed = false);
                    _triggerNudge(isKiss: false, partnerName: partnerName);
                  },
                  onTapCancel: () => setState(() => _isHugPressed = false),
                  onUploadTap: () => _showPhotoOptionsModal(false),
                  onDeletePhotoTap: () => _confirmAndDeletePhoto(false),
                ),
                const SizedBox(height: 24),

                // OPTIONAL SWEET NOTE SECTION (Clean text field without predefined templates)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E142B) : Colors.white,
                    borderRadius: BorderRadius.circular(22),
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
                      ListenableBuilder(
                        listenable: _messageController,
                        builder: (context, _) {
                          final currentTrimmed = _messageController.text.trim();
                          final isAlreadySaved = _savedMessageTemplates.any(
                            (t) => t.trim().toLowerCase() == currentTrimmed.toLowerCase(),
                          );

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.favorite_rounded,
                                    size: 16,
                                    color: Color(0xFFFF758C),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Attach Sweet Message (Optional)',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF2D4059),
                                    ),
                                  ),
                                ],
                              ),
                              if (currentTrimmed.isNotEmpty)
                                isAlreadySaved
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle_outline_rounded, size: 12, color: Colors.green),
                                            SizedBox(width: 3),
                                            Text(
                                              'Saved',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : InkWell(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          FocusScope.of(context).unfocus();
                                          final textToSave = _messageController.text;
                                          _saveMessageTemplate(textToSave);
                                          SnackbarHelper.showSuccess(
                                            context,
                                            'Message template saved for future love nudges!',
                                            title: 'Template Saved',
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF758C).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.bookmark_add_outlined, size: 12, color: Color(0xFFFF758C)),
                                              SizedBox(width: 3),
                                              Text(
                                                'Save',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFFF758C),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      ListenableBuilder(
                        listenable: _messageController,
                        builder: (context, _) {
                          return TextField(
                            controller: _messageController,
                            maxLength: 80,
                            decoration: InputDecoration(
                              hintText: 'Write a sweet note to pop up with your nudge...',
                              hintStyle: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? Colors.white38 : Colors.grey.shade400,
                              ),
                              counterText: '',
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              suffixIcon: _messageController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        _messageController.clear();
                                      },
                                    )
                                  : null,
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
                          );
                        },
                      ),
                      if (_savedMessageTemplates.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 13,
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Saved Templates (Tap to use)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white54 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ListenableBuilder(
                          listenable: _messageController,
                          builder: (context, _) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _savedMessageTemplates.map((template) {
                                  final isSelected = _messageController.text.trim() == template;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: InkWell(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        _messageController.text = template;
                                        _messageController.selection = TextSelection.fromPosition(
                                          TextPosition(offset: template.length),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFFFF758C).withValues(alpha: 0.18)
                                              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFFFF758C).withValues(alpha: 0.6)
                                                : (isDark ? Colors.white10 : Colors.grey.shade300),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 160),
                                              child: Text(
                                                template,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                  color: isSelected
                                                      ? const Color(0xFFFF758C)
                                                      : (isDark ? Colors.white : Colors.black87),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            GestureDetector(
                                              onTap: () => _deleteMessageTemplate(template),
                                              child: Icon(
                                                Icons.close_rounded,
                                                size: 13,
                                                color: isDark ? Colors.white38 : Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNudgeCard({
    required bool isDark,
    required bool isKiss,
    required String title,
    required String subtitle,
    required Color primaryColor,
    required Color secondaryColor,
    required String? photoUrl,
    required bool isUploading,
    required bool isPressed,
    required String partnerName,
    required VoidCallback onTapDown,
    required VoidCallback onTapUp,
    required VoidCallback onTapCancel,
    required VoidCallback onUploadTap,
    required VoidCallback onDeletePhotoTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E142B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title & Upload Photo Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, secondaryColor],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: isKiss
                          ? const Icon(Icons.favorite_rounded, size: 22, color: Colors.white)
                          : const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? Colors.white : const Color(0xFF2D4059),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Upload / Change Photo Pill Button
              InkWell(
                onTap: isUploading ? null : onUploadTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isUploading)
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                        )
                      else
                        Icon(
                          photoUrl != null ? Icons.edit_rounded : Icons.add_a_photo_rounded,
                          size: 13,
                          color: primaryColor,
                        ),
                      const SizedBox(width: 5),
                      Text(
                        photoUrl != null ? 'Change' : '+ Photo',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Photo Preview / Placeholder Banner
          if (photoUrl != null) ...[
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 130,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: _buildPhotoThumbnail(photoUrl),
                ),
                // Delete button with confirmation on top-right
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: onDeletePhotoTap,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(7),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                // Attached badge on bottom-left
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 12, color: Colors.greenAccent),
                        const SizedBox(width: 4),
                        Text(
                          'Custom ${isKiss ? "Kiss" : "Hug"} Photo Attached',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Big Interactive Tap to Send Button
          GestureDetector(
            onTapDown: (_) => onTapDown(),
            onTapUp: (_) => onTapUp(),
            onTapCancel: () => onTapCancel(),
            child: AnimatedScale(
              scale: isPressed ? 0.96 : 1.0,
              duration: const Duration(milliseconds: 100),
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      isKiss
                          ? const Icon(Icons.favorite_rounded, size: 20, color: Colors.white)
                          : const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Tap to Send to $partnerName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
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
  }
}

