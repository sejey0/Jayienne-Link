import 'dart:io';
import 'package:flutter/material.dart';
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

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  File? _selectedPhoto;
  DateTime? _birthday;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(source: source, maxWidth: 512);
    if (picked != null) {
      setState(() => _selectedPhoto = File(picked.path));
    }
  }

  Future<void> _pickBirthday() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _birthday = date);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    final firebaseUser = auth.firebaseUser!;

    final success = await userProvider.createProfile(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      phoneNumber: firebaseUser.phoneNumber,
      displayName: _nameController.text.trim(),
      photoFile: _selectedPhoto,
      birthday: _birthday,
    );

    if (!mounted) return;

    if (!success && userProvider.error != null) {
      SnackbarHelper.showError(context, userProvider.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return LoadingOverlay(
      isLoading: userProvider.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text(AppStrings.setupProfile)),
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
                          : null,
                      child: _selectedPhoto == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.person_add_alt_1,
                                  size: 36,
                                  color: AppColors.softRose,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppStrings.tapToChangePhoto,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.softRose),
                                ),
                              ],
                            )
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
                    label: AppStrings.saveProfile,
                    onPressed: _saveProfile,
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
