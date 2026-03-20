import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/loading_overlay.dart';

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
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final user = context.read<UserProvider>().user;
      _nameController = TextEditingController(text: user?.displayName ?? '');
      _birthday = user?.birthday;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
    );
    if (picked != null) {
      setState(() => _selectedPhoto = File(picked.path));
    }
  }

  Future<void> _pickBirthday() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _birthday = date);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();

    // Show a loading dialog for image uploads
    bool showingUploadDialog = false;
    if (_selectedPhoto != null) {
      showingUploadDialog = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Uploading Photo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Please wait while we upload your profile photo...'),
            ],
          ),
        ),
      );
    }

    final success = await userProvider.updateProfile(
      uid: auth.firebaseUser!.uid,
      displayName: _nameController.text.trim(),
      photoFile: _selectedPhoto,
      birthday: _birthday,
    );

    // Close upload dialog if shown
    if (showingUploadDialog && mounted) {
      Navigator.of(context).pop();
    }

    if (!mounted) return;

    if (success) {
      SnackbarHelper.showSuccess(context, 'Profile updated!');
      context.pop();
    } else if (userProvider.error != null) {
      // Show detailed error dialog for storage issues
      if (userProvider.error!.contains('upload') ||
          userProvider.error!.contains('Storage')) {
        _showStorageErrorDialog(context, userProvider.error!);
      } else {
        SnackbarHelper.showError(context, userProvider.error!);
      }
    }
  }

  void _showStorageErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error),
            const SizedBox(height: 16),
            const Text('Troubleshooting steps:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('• Check your internet connection'),
            const Text('• Try selecting a different photo'),
            const Text('• Make sure the photo file is not corrupted'),
            const Text('• Try again in a few moments'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Retry upload
              _save();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  /// Get appropriate ImageProvider for profile photos (supports both network URLs and Base64)
  ImageProvider? _getProfileImageProvider(String? photoUrl) {
    if (photoUrl == null) return null;

    // Check if it's a Base64 data URL
    if (photoUrl.startsWith('data:image/')) {
      try {
        // Extract Base64 data from data URL
        final base64String = photoUrl.split(',')[1];
        final bytes = base64Decode(base64String);
        return MemoryImage(bytes);
      } catch (e) {
        // If Base64 decoding fails, return null to show fallback
        return null;
      }
    } else {
      // Regular network URL, use CachedNetworkImageProvider
      return CachedNetworkImageProvider(photoUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;

    return LoadingOverlay(
      isLoading: userProvider.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text(AppStrings.editProfile)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: AppDimensions.spacingLg),
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: CircleAvatar(
                      radius: AppDimensions.avatarSizeLarge / 2,
                      backgroundColor: AppColors.peach.withOpacity(0.3),
                      backgroundImage: _selectedPhoto != null
                          ? FileImage(_selectedPhoto!)
                          : _getProfileImageProvider(user?.photoUrl),
                      child: (_selectedPhoto == null && user?.photoUrl == null)
                          ? const Icon(Icons.camera_alt,
                              size: 36, color: AppColors.softRose)
                          : null,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingXl),
                  AppTextField(
                    controller: _nameController,
                    hintText: AppStrings.displayName,
                    prefixIcon: Icons.person_outlined,
                    textCapitalization: TextCapitalization.words,
                    validator: Validators.validateDisplayName,
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  InkWell(
                    onTap: _pickBirthday,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.borderRadiusLarge,
                    ),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        hintText: AppStrings.birthday,
                        prefixIcon: Icon(Icons.cake_outlined),
                      ),
                      child: Text(
                        _birthday != null
                            ? '${_birthday!.month}/${_birthday!.day}/${_birthday!.year}'
                            : AppStrings.birthday,
                        style: _birthday != null
                            ? null
                            : TextStyle(color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingXl),
                  AppButton(
                    label: 'Save Changes',
                    onPressed: _save,
                    isLoading: userProvider.isLoading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
