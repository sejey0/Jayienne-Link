import 'dart:io';
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

    final success = await userProvider.updateProfile(
      uid: auth.firebaseUser!.uid,
      displayName: _nameController.text.trim(),
      photoFile: _selectedPhoto,
      birthday: _birthday,
    );

    if (!mounted) return;

    if (success) {
      SnackbarHelper.showSuccess(context, 'Profile updated!');
      context.pop();
    } else if (userProvider.error != null) {
      SnackbarHelper.showError(context, userProvider.error!);
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
                          : (user?.photoUrl != null
                              ? CachedNetworkImageProvider(user!.photoUrl!)
                              : null),
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
