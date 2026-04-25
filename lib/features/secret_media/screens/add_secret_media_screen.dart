import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jayienne_link/providers/secret_media_provider.dart';
import 'package:jayienne_link/providers/auth_provider.dart';
import 'package:jayienne_link/providers/user_provider.dart';
import 'package:jayienne_link/services/supabase_storage_service.dart';

class AddSecretMediaScreen extends StatefulWidget {
  const AddSecretMediaScreen({super.key});

  @override
  State<AddSecretMediaScreen> createState() => _AddSecretMediaScreenState();
}

class _AddSecretMediaScreenState extends State<AddSecretMediaScreen> {
  late ImagePicker _imagePicker;
  File? _selectedFile;
  String _mediaType = 'image'; // 'image' or 'video'
  final TextEditingController _captionController = TextEditingController();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _imagePicker = ImagePicker();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(String type) async {
    try {
      XFile? pickedFile;

      if (type == 'image') {
        pickedFile = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
      } else {
        pickedFile = await _imagePicker.pickVideo(
          source: ImageSource.gallery,
        );
      }

      if (pickedFile != null) {
        setState(() {
          _selectedFile = File(pickedFile!.path);
          _mediaType = type;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick media: $e');
    }
  }

  Future<void> _uploadMedia() async {
    if (_selectedFile == null) {
      _showErrorSnackBar('Please select a file first');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    final secretMediaProvider = context.read<SecretMediaProvider>();
    final storageService = SupabaseStorageService();

    if (authProvider.currentUserId == null) {
      _showErrorSnackBar('User not authenticated');
      return;
    }

    final user = userProvider.user;
    final coupleId = user?.coupleId;
    if (user == null || coupleId == null || coupleId.isEmpty) {
      _showErrorSnackBar('Link with your partner first to use Secret Media');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Ensure provider has current user/couple context before uploading.
      await secretMediaProvider.initialize(
        userId: user.id,
        coupleId: coupleId,
      );

      // Upload to Supabase Storage
      final mediaUrl = await storageService.uploadSecretMedia(
        authProvider.currentUserId!,
        _selectedFile!,
        _mediaType,
      );

      // Add to database
      final createdMedia = await secretMediaProvider.addSecretMedia(
        mediaType: _mediaType,
        mediaUrl: mediaUrl,
        caption:
            _captionController.text.isNotEmpty ? _captionController.text : null,
        isHidden: true,
      );

      if (createdMedia == null) {
        throw Exception(secretMediaProvider.error ?? 'Failed to save media');
      }

      if (mounted) {
        _showSuccessSnackBar('Media added to hidden vault!');
        Navigator.pop(context);
      }
    } catch (e) {
      final message = e.toString();
      if (message.contains('Bucket not found') ||
          message.contains('secret-media')) {
        _showErrorSnackBar(
            'Secret Media storage is not configured. Please create the "secret-media" bucket in Supabase.');
      } else if (message.contains('row-level security') ||
          message.contains('Unauthorized')) {
        _showErrorSnackBar(
            'Storage permissions blocked upload. Check Supabase RLS policies.');
      } else {
        _showErrorSnackBar('Upload failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Secret Media',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurple.shade700,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Media Selection
              Text(
                'Select Media Type',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMediaTypeButton(
                      'Photo',
                      Icons.image,
                      _mediaType == 'image',
                      () => _pickMedia('image'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMediaTypeButton(
                      'Video',
                      Icons.videocam,
                      _mediaType == 'video',
                      () => _pickMedia('video'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Media Preview
              if (_selectedFile != null)
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade200,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _mediaType == 'image'
                            ? Image.file(
                                _selectedFile!,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.black,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.videocam,
                                      size: 64,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Video Selected',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedFile = null;
                            });
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.deepPurple.shade300,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                    color: Colors.deepPurple.shade50,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 48,
                        color: Colors.deepPurple.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No media selected',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap above to select a photo or video',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Caption
              Text(
                'Add a Caption (Optional)',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _captionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add a caption or note...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.deepPurple,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.lock, color: Colors.deepPurple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'All uploads go directly to Hidden Vault (private)',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Upload Button
              ElevatedButton(
                onPressed: _isUploading ? null : _uploadMedia,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade700,
                  disabledBackgroundColor: Colors.grey.shade400,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Upload to Secret Gallery',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaTypeButton(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? Colors.deepPurple.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? Colors.deepPurple : Colors.grey.shade600,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.deepPurple : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
