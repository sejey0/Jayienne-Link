import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/zodiac_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/loading_overlay.dart';

// ── Screen ─────────────────────────────────────────────────────────────────────
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  File? _selectedPhoto;
  DateTime? _birthday;
  String? _selectedZodiac;
  bool _initialized = false;
  bool _nameEditable = false; // pencil-icon toggle

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final user = context.read<UserProvider>().user;
      _nameController = TextEditingController(text: user?.displayName ?? '');
      _birthday = user?.birthday;
      _selectedZodiac = user?.zodiacSign;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Pickers ────────────────────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (picked != null) setState(() => _selectedPhoto = File(picked.path));
  }

  Future<void> _pickBirthday() async {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: isDark
              ? const ColorScheme.dark(
                  primary: Color(0xFFFF758C),
                  onPrimary: Colors.white,
                  surface: Color(0xFF1C1427),
                  onSurface: Colors.white,
                )
              : const ColorScheme.light(
                  primary: Color(0xFFFF758C),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Color(0xFF2D4059),
                ),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _birthday = date);
  }

  void _showZodiacPicker() {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String? tempSelected = _selectedZodiac;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1427) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Handle
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                          ).createShader(bounds),
                          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Select Zodiac Sign',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.deepCharcoal,
                          ),
                        ),
                        const Spacer(),
                        if (tempSelected != null)
                          GestureDetector(
                            onTap: () => setModalState(() => tempSelected = null),
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                color: Color(0xFFFF758C),
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Zodiac grid
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: kZodiacSigns.length,
                      itemBuilder: (context, i) {
                        final z = kZodiacSigns[i];
                        final isSelected = tempSelected == z.name;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setModalState(() => tempSelected = isSelected ? null : z.name);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? z.color.withValues(alpha: isDark ? 0.25 : 0.12)
                                  : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? z.color : (isDark ? Colors.white12 : Colors.grey.shade200),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: z.color.withValues(alpha: 0.25),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ZodiacIcon(
                                  zodiac: z.name,
                                  size: 28,
                                  color: isSelected ? z.color : (isDark ? Colors.white70 : Colors.grey.shade600),
                                  strokeWidth: 2.2,
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  z.name,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? z.color : (isDark ? Colors.white : AppColors.deepCharcoal),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  z.dateRange,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Confirm button
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
                    child: Container(
                      width: double.infinity,
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
                            color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedZodiac = tempSelected);
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                          tempSelected != null ? 'Set ${tempSelected!}' : 'Confirm',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Save ───────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final userProvider = context.read<UserProvider>();
    final auth = context.read<AuthProvider>();
    final currentUser = userProvider.user;
    final userId = (currentUser != null && currentUser.id.isNotEmpty)
        ? currentUser.id
        : auth.currentUserId;

    if (userId == null) {
      SnackbarHelper.showError(context, 'User ID not found. Please sign in again.');
      return;
    }

    bool showingUploadDialog = false;
    if (_selectedPhoto != null) {
      showingUploadDialog = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: isDark ? const Color(0xFF1C1427) : Colors.white,
            contentPadding: const EdgeInsets.all(28),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 16),
                Text(
                  'Uploading Photo',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait while we upload your profile photo...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                const LinearProgressIndicator(
                  backgroundColor: Color(0xFFA18CD1),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF758C)),
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ],
            ),
          );
        },
      );
    }

    final success = await userProvider.updateProfile(
      uid: userId,
      displayName: _nameEditable ? _nameController.text.trim() : null,
      photoFile: _selectedPhoto,
      birthday: _birthday,
      zodiacSign: _selectedZodiac,
      clearZodiacSign: _selectedZodiac == null && (currentUser?.zodiacSign != null),
    );

    if (showingUploadDialog && mounted) Navigator.of(context).pop();
    if (!mounted) return;

    if (success) {
      SnackbarHelper.showSuccess(context, 'Profile updated successfully!');
      context.pop();
    } else if (userProvider.error != null) {
      if (userProvider.error!.contains('upload') || userProvider.error!.contains('Storage')) {
        _showStorageErrorDialog(context, userProvider.error!);
      } else {
        SnackbarHelper.showError(context, userProvider.error!);
      }
    }
  }

  void _showStorageErrorDialog(BuildContext context, String error) {
    HapticFeedback.heavyImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1C1427) : Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
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
              child: const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              'Upload Failed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.deepCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? Colors.white70 : Colors.grey.shade700),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Troubleshooting steps:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : AppColors.deepCharcoal),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• Check your internet connection\n• Try selecting a different photo\n• Make sure the photo is under 10MB',
                    style: TextStyle(fontSize: 11.5, height: 1.5, color: isDark ? Colors.white60 : Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF758C), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFFFF758C), fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF758C), Color(0xFFA18CD1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: () { Navigator.of(ctx).pop(); _save(); },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                      child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
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

  // ── Helpers ────────────────────────────────────────────────────────────────
  ImageProvider? _getProfileImageProvider(String? photoUrl) {
    if (photoUrl == null) return null;
    if (photoUrl.startsWith('data:image/')) {
      try {
        final base64String = photoUrl.split(',')[1];
        final bytes = base64Decode(base64String);
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    } else {
      return CachedNetworkImageProvider(photoUrl);
    }
  }

  String _formatBirthday(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  ZodiacInfo? get _currentZodiacInfo =>
      _selectedZodiac == null ? null : kZodiacSigns.firstWhere((z) => z.name == _selectedZodiac, orElse: () => kZodiacSigns[0]);

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zodiac = _currentZodiacInfo;

    return LoadingOverlay(
      isLoading: userProvider.isLoading,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF120E19) : const Color(0xFFFFF7F9),
        appBar: AppBar(
          title: const Text(
            AppStrings.editProfile,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
          ),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
          ),
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // ── Avatar Banner ──────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFF758C).withValues(alpha: 0.10),
                        const Color(0xFFA18CD1).withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickPhoto,
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? const Color(0xFF120E19) : Colors.white,
                                ),
                                child: CircleAvatar(
                                  radius: AppDimensions.avatarSizeLarge / 2,
                                  backgroundColor: const Color(0xFFFF758C).withValues(alpha: 0.15),
                                  backgroundImage: _selectedPhoto != null
                                      ? FileImage(_selectedPhoto!)
                                      : _getProfileImageProvider(user?.photoUrl),
                                  child: (_selectedPhoto == null && user?.photoUrl == null)
                                      ? Container(
                                          width: double.infinity,
                                          height: double.infinity,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: const Icon(Icons.person_rounded, size: 48, color: Colors.white),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF120E19) : Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF758C).withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap to change photo',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Form Fields ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('Personal Info', isDark),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1C1427) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFFF758C).withValues(alpha: 0.25),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF758C).withValues(alpha: 0.07),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Column(
                            children: [
                              // ── Name field with pencil toggle ──────────────
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: AppTextField(
                                      controller: _nameController,
                                      hintText: AppStrings.displayName,
                                      prefixIcon: Icons.person_outlined,
                                      textCapitalization: TextCapitalization.words,
                                      validator: _nameEditable ? Validators.validateDisplayName : null,
                                      enabled: _nameEditable,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Pencil toggle button
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() => _nameEditable = !_nameEditable);
                                        if (_nameEditable) {
                                          Future.delayed(const Duration(milliseconds: 80), () {
                                            _nameController.selection = TextSelection.fromPosition(
                                              TextPosition(offset: _nameController.text.length),
                                            );
                                          });
                                        }
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          gradient: _nameEditable
                                              ? const LinearGradient(
                                                  colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                              : null,
                                          color: _nameEditable ? null : (isDark ? Colors.white.withValues(alpha: 0.07) : Colors.grey.shade100),
                                          borderRadius: BorderRadius.circular(12),
                                          border: _nameEditable
                                              ? null
                                              : Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                                        ),
                                        child: Icon(
                                          _nameEditable ? Icons.edit_off_rounded : Icons.edit_rounded,
                                          size: 18,
                                          color: _nameEditable ? Colors.white : (isDark ? Colors.white54 : Colors.grey.shade500),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // ── Birthday picker ────────────────────────────
                              InkWell(
                                onTap: _pickBirthday,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded, size: 18, color: isDark ? Colors.white54 : Colors.grey.shade600),
                                      const SizedBox(width: 12),
                                      Text(
                                        _birthday != null ? _formatBirthday(_birthday!) : AppStrings.birthday,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: _birthday != null ? FontWeight.w500 : FontWeight.normal,
                                          color: _birthday != null
                                              ? (isDark ? Colors.white : AppColors.deepCharcoal)
                                              : (isDark ? Colors.white38 : Colors.grey.shade400),
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? Colors.white30 : Colors.grey.shade400),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Zodiac Sign Section ────────────────────────────
                        _buildSectionLabel('Zodiac Sign', isDark),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _showZodiacPicker,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1C1427) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: zodiac != null
                                    ? zodiac.color.withValues(alpha: 0.45)
                                    : const Color(0xFFA18CD1).withValues(alpha: 0.25),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (zodiac?.color ?? const Color(0xFFA18CD1)).withValues(alpha: 0.07),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                // Symbol circle
                                if (zodiac != null) ...[
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: zodiac.color.withValues(alpha: isDark ? 0.2 : 0.1),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: zodiac.color.withValues(alpha: 0.4)),
                                    ),
                                    child: Center(
                                      child: ZodiacIcon(
                                        zodiac: zodiac.name,
                                        size: 20,
                                        color: zodiac.color,
                                        strokeWidth: 2.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          zodiac.name,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : AppColors.deepCharcoal,
                                          ),
                                        ),
                                        Text(
                                          zodiac.dateRange,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade50,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                                    ),
                                    child: Center(
                                      child: Icon(Icons.auto_awesome_rounded, size: 18, color: isDark ? Colors.white38 : Colors.grey.shade400),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Select your zodiac sign',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                ],
                                Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? Colors.white30 : Colors.grey.shade400),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Save Button ────────────────────────────────────
                        Container(
                          width: double.infinity,
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
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: userProvider.isLoading ? null : _save,
                            icon: const Icon(Icons.check_rounded, size: 20, color: Colors.white),
                            label: const Text(
                              'Save Changes',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.4,
        color: isDark ? Colors.white70 : Colors.grey.shade700,
      ),
    );
  }
}
