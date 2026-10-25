import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/gallery_folder_model.dart';
import '../../../models/gallery_image_model.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/nhost_gallery_service.dart';
import '../../../widgets/common/photo_viewer_nav_preference.dart';
import '../../../widgets/common/timed_confirm_dialog.dart';

class _CaptionDialogResult {
  final String? caption;
  final DateTime? takenAt;
  final String section;

  const _CaptionDialogResult({this.caption, this.takenAt, this.section = 'us'});
}

class FolderDetailScreen extends StatefulWidget {
  final GalleryFolderModel folder;

  const FolderDetailScreen({
    super.key,
    required this.folder,
  });

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  final NhostGalleryService _galleryService = NhostGalleryService.instance;
  final ImagePicker _picker = ImagePicker();

  GalleryFolderModel? _customFolder;
  GalleryFolderModel get _currentFolder => _customFolder ?? widget.folder;
  List<GalleryImageModel> _images = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _uploadStatusText;
  double _uploadProgress = 0.0;
  String _selectedMediaType = 'photos'; // 'photos' or 'videos'

  // Selection mode for batch delete
  bool _isSelectionMode = false;
  final Set<String> _selectedImageIds = {};

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  List<GalleryImageModel> get _filteredImages {
    if (_selectedMediaType == 'videos') {
      return _images.where((img) => img.isVideo).toList();
    }
    return _images.where((img) => !img.isVideo).toList();
  }

  Future<void> _loadImages() async {
    final coupleProvider = context.read<CoupleProvider>();
    final userProvider = context.read<UserProvider>();
    final coupleId = coupleProvider.couple?.id ?? userProvider.coupleId;

    if (coupleId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      final images = await _galleryService.getFolderImages(
        folderId: _currentFolder.id,
        coupleId: coupleId,
      );
      if (mounted) {
        setState(() {
          _images = images;
          _isLoading = false;
          final photosCount = _images.where((img) => !img.isVideo).length;
          final videosCount = _images.where((img) => img.isVideo).length;
          if (photosCount == 0 && videosCount > 0) {
            _selectedMediaType = 'videos';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load photos: $e')),
        );
      }
    }
  }

  void _toggleSelectionMode({String? initialId}) {
    HapticFeedback.lightImpact();
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedImageIds.clear();
      if (_isSelectionMode && initialId != null) {
        _selectedImageIds.add(initialId);
      }
    });
  }

  void _toggleImageSelection(String imageId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedImageIds.contains(imageId)) {
        _selectedImageIds.remove(imageId);
        if (_selectedImageIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedImageIds.add(imageId);
      }
    });
  }

  void _selectAll() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedImageIds.length == _images.length) {
        _selectedImageIds.clear();
      } else {
        _selectedImageIds.addAll(_images.map((img) => img.id));
      }
    });
  }

  Future<void> _deleteSelectedImages() async {
    final selectedCount = _selectedImageIds.length;
    if (selectedCount == 0) return;

    final confirmed = await showTimedConfirmDialog(
      context: context,
      title: 'Delete $selectedCount Photo${selectedCount > 1 ? 's' : ''}',
      message: 'Are you sure you want to delete the $selectedCount selected photo${selectedCount > 1 ? 's' : ''} from "${_currentFolder.name}"? This action cannot be undone.',
      confirmLabel: 'Delete $selectedCount Photo${selectedCount > 1 ? 's' : ''}',
      icon: Icons.delete_forever_rounded,
      countdownSeconds: 5,
    );

    if (confirmed == true) {
      final imagesToDelete = _images.where((img) => _selectedImageIds.contains(img.id)).toList();
      setState(() => _isLoading = true);

      try {
        await _galleryService.deleteImagesBatch(imagesToDelete);
        if (mounted) {
          setState(() {
            _images.removeWhere((img) => _selectedImageIds.contains(img.id));
            _selectedImageIds.clear();
            _isSelectionMode = false;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$selectedCount photo${selectedCount > 1 ? 's' : ''} deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete photos: $e')),
          );
        }
      }
    }
  }

  Future<void> _showEditFolderDialog() async {
    HapticFeedback.lightImpact();
    final nameController = TextEditingController(text: _currentFolder.name);
    final descController = TextEditingController(text: _currentFolder.cleanDescription);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedSection = _currentFolder.section;

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: isDark ? const Color(0xFF1E162B) : Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
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
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Edit Album Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.deepCharcoal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Folder Name',
                      hintText: 'e.g. Baguio Trip, Date Nights',
                      prefixIcon: const Icon(Icons.folder_outlined),
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'Add or edit sweet note about this album...',
                      prefixIcon: const Icon(Icons.description_outlined),
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryCancelButton(
                          label: 'Cancel',
                          height: 46,
                          borderRadius: 14,
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () async {
                              final newName = nameController.text.trim();
                              if (newName.isEmpty) return;
                              final newDesc = descController.text.trim();
                              final encodedDesc = newDesc.isNotEmpty
                                  ? '$newDesc\n[section:$selectedSection]'
                                  : '[section:$selectedSection]';
                              Navigator.pop(ctx, true);
                              try {
                                await _galleryService.updateFolder(
                                  folderId: _currentFolder.id,
                                  name: newName,
                                  description: encodedDesc,
                                );
                                if (mounted) {
                                  setState(() {
                                    _customFolder = _currentFolder.copyWith(
                                      name: newName,
                                      description: encodedDesc,
                                      section: selectedSection,
                                    );
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Album details updated.')),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to update album: $e')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                            label: const Text(
                              'Save',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
        ),
      ),
    );
  }

  void _showImageSourcePicker() {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E162B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Upload Media to ${_currentFolder.name}',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.deepCharcoal,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickMultipleMedia();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.perm_media_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Photos & Videos',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.white : AppColors.deepCharcoal,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Multi-select gallery',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickSingleVideo();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFFFF4D6D), Color(0xFFFF758C)],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.video_library_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload Video',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.white : AppColors.deepCharcoal,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Choose from gallery',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickCameraImage();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFFA18CD1), Color(0xFF6C5CE7)],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Take Photo',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.white : AppColors.deepCharcoal,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Snap with camera',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.pop(ctx);
                        _recordVideo();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF6C5CE7), Color(0xFF4834D4)],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Record Video',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.white : AppColors.deepCharcoal,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Record with camera',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                              ),
                            ),
                          ],
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

  Future<void> _pickMultipleMedia() async {
    HapticFeedback.lightImpact();
    try {
      final List<XFile> pickedFiles = await _picker.pickMultipleMedia(
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (pickedFiles.isEmpty) return;
      if (!mounted) return;

      final result = await _showBatchCaptionDialog(pickedFiles.length);
      if (result == null) return;

      _uploadMultipleFiles(
        pickedFiles,
        caption: result.caption,
        takenAt: result.takenAt,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick media: $e')),
        );
      }
    }
  }

  Future<void> _pickSingleVideo() async {
    HapticFeedback.lightImpact();
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (pickedFile == null) return;

      final videoBytes = await pickedFile.readAsBytes();
      final fileName = pickedFile.name.isNotEmpty
          ? pickedFile.name
          : 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';

      if (!mounted) return;

      final result = await _showSingleCaptionDialog(videoBytes, isVideo: true, fileName: fileName);
      if (result == null) return;

      _startUploadingSingle(
        videoBytes,
        fileName,
        caption: result.caption,
        takenAt: result.takenAt,
        mediaType: 'video',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick video: $e')),
        );
      }
    }
  }

  Future<void> _recordVideo() async {
    HapticFeedback.lightImpact();
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.camera,
      );

      if (pickedFile == null) return;

      final videoBytes = await pickedFile.readAsBytes();
      final fileName = pickedFile.name.isNotEmpty
          ? pickedFile.name
          : 'recorded_${DateTime.now().millisecondsSinceEpoch}.mp4';

      if (!mounted) return;

      final result = await _showSingleCaptionDialog(videoBytes, isVideo: true, fileName: fileName);
      if (result == null) return;

      _startUploadingSingle(
        videoBytes,
        fileName,
        caption: result.caption,
        takenAt: result.takenAt,
        mediaType: 'video',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record video: $e')),
        );
      }
    }
  }

  Future<void> _pickCameraImage() async {
    HapticFeedback.lightImpact();
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (pickedFile == null) return;

      final imageBytes = await pickedFile.readAsBytes();
      final fileName = pickedFile.name.isNotEmpty
          ? pickedFile.name
          : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (!mounted) return;

      final result = await _showSingleCaptionDialog(imageBytes, isVideo: false, fileName: fileName);
      if (result == null) return;

      _startUploadingSingle(
        imageBytes,
        fileName,
        caption: result.caption,
        takenAt: result.takenAt,
        mediaType: 'image',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to take photo: $e')),
        );
      }
    }
  }

  Future<_CaptionDialogResult?> _showBatchCaptionDialog(int count) async {
    final captionController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coupleProvider = context.read<CoupleProvider>();
    final partnerName = coupleProvider.partner?.displayName ?? 'Partner';
    String selectedSection = _currentFolder.section;
    DateTime? selectedDateTaken;

    return showDialog<_CaptionDialogResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: isDark ? const Color(0xFF1E162B) : Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upload $count Photos',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.deepCharcoal,
                            ),
                          ),
                          Text(
                            'Add optional details for this batch',
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
                const SizedBox(height: 16),
                _buildSectionSelector(
                  selectedSection: selectedSection,
                  onSelected: (val) => setDialogState(() => selectedSection = val),
                  isDark: isDark,
                  partnerName: partnerName,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: captionController,
                  maxLines: 2,
                  autofocus: false,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Add caption (optional)...',
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDateTaken ?? DateTime.now(),
                      firstDate: DateTime(1990),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDateTaken = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedDateTaken != null
                            ? const Color(0xFFFF758C).withValues(alpha: 0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                          color: selectedDateTaken != null
                              ? const Color(0xFFFF758C)
                              : (isDark ? Colors.white60 : Colors.grey.shade600),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedDateTaken != null
                                ? 'Date Taken: ${DateFormat('MMM d, y').format(selectedDateTaken!)}'
                                : 'Date Picture Taken (Optional)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selectedDateTaken != null ? FontWeight.bold : FontWeight.normal,
                              color: selectedDateTaken != null
                                  ? (isDark ? Colors.white : AppColors.deepCharcoal)
                                  : (isDark ? Colors.white60 : Colors.grey.shade600),
                            ),
                          ),
                        ),
                        if (selectedDateTaken != null)
                          GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedDateTaken = null;
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryCancelButton(
                        label: 'Cancel',
                        height: 44,
                        borderRadius: 14,
                        onPressed: () => Navigator.pop(ctx, null),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            final text = captionController.text.trim();
                            final encodedCaption = text.isNotEmpty
                                ? '$text\n[section:$selectedSection]'
                                : '[section:$selectedSection]';
                            Navigator.pop(
                              ctx,
                              _CaptionDialogResult(
                                caption: encodedCaption,
                                takenAt: selectedDateTaken,
                                section: selectedSection,
                              ),
                            );
                          },
                          child: Text(
                            'Upload ($count)',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
      ),
    );
  }

  Future<_CaptionDialogResult?> _showSingleCaptionDialog(
    Uint8List mediaBytes, {
    bool isVideo = false,
    String? fileName,
  }) async {
    final captionController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coupleProvider = context.read<CoupleProvider>();
    final partnerName = coupleProvider.partner?.displayName ?? 'Partner';
    String selectedSection = _currentFolder.section;
    DateTime? selectedDateTaken;

    return showDialog<_CaptionDialogResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: isDark ? const Color(0xFF1E162B) : Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isVideo ? Icons.videocam_rounded : Icons.add_photo_alternate_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isVideo ? 'Add Video Details' : 'Add Photo Details',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isVideo)
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF2A1E3F), const Color(0xFF191224)]
                            : [const Color(0xFF3B284C), const Color(0xFF241434)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            fileName ?? 'Video File',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(mediaBytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      mediaBytes,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 14),
                _buildSectionSelector(
                  selectedSection: selectedSection,
                  onSelected: (val) => setDialogState(() => selectedSection = val),
                  isDark: isDark,
                  partnerName: partnerName,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: captionController,
                  maxLines: 2,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Write a caption for this memory (optional)...',
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDateTaken ?? DateTime.now(),
                      firstDate: DateTime(1990),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDateTaken = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedDateTaken != null
                            ? const Color(0xFFFF758C).withValues(alpha: 0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                          color: selectedDateTaken != null
                              ? const Color(0xFFFF758C)
                              : (isDark ? Colors.white60 : Colors.grey.shade600),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedDateTaken != null
                                ? 'Date Taken: ${DateFormat('MMM d, y').format(selectedDateTaken!)}'
                                : 'Date Taken (Optional)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selectedDateTaken != null ? FontWeight.bold : FontWeight.normal,
                              color: selectedDateTaken != null
                                  ? (isDark ? Colors.white : AppColors.deepCharcoal)
                                  : (isDark ? Colors.white60 : Colors.grey.shade600),
                            ),
                          ),
                        ),
                        if (selectedDateTaken != null)
                          GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedDateTaken = null;
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryCancelButton(
                        label: 'Cancel',
                        height: 44,
                        borderRadius: 14,
                        onPressed: () => Navigator.pop(ctx, null),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            final text = captionController.text.trim();
                            final encodedCaption = text.isNotEmpty
                                ? '$text\n[section:$selectedSection]'
                                : '[section:$selectedSection]';
                            Navigator.pop(
                              ctx,
                              _CaptionDialogResult(
                                caption: encodedCaption,
                                takenAt: selectedDateTaken,
                                section: selectedSection,
                              ),
                            );
                          },
                          child: const Text(
                            'Upload',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
      ),
    );
  }

  Future<void> _startUploadingSingle(
    Uint8List mediaBytes,
    String fileName, {
    String? caption,
    DateTime? takenAt,
    String? mediaType,
  }) async {
    final userProvider = context.read<UserProvider>();
    final coupleProvider = context.read<CoupleProvider>();
    final coupleId = coupleProvider.couple?.id ?? userProvider.coupleId;
    final userId = userProvider.user?.id;

    if (coupleId == null || userId == null) return;

    final isVid = mediaType == 'video';

    setState(() {
      _isUploading = true;
      _uploadStatusText = isVid ? 'Uploading video...' : 'Uploading photo...';
      _uploadProgress = 0.5;
    });

    try {
      final newImage = await _galleryService.uploadImage(
        folderId: _currentFolder.id,
        coupleId: coupleId,
        uploadedById: userId,
        imageBytes: mediaBytes,
        fileName: fileName,
        caption: caption,
        takenAt: takenAt,
        mediaType: mediaType,
        updateFolderCoverIfEmpty: _currentFolder.coverImageUrl == null && !isVid,
      );

      if (mounted) {
        setState(() {
          _images.insert(0, newImage);
          _isUploading = false;
          _uploadStatusText = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isVid ? 'Video' : 'Photo'} uploaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatusText = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _uploadMultipleFiles(
    List<XFile> files, {
    String? caption,
    DateTime? takenAt,
  }) async {
    final userProvider = context.read<UserProvider>();
    final coupleProvider = context.read<CoupleProvider>();
    final coupleId = coupleProvider.couple?.id ?? userProvider.coupleId;
    final userId = userProvider.user?.id;

    if (coupleId == null || userId == null) return;

    final total = files.length;
    final List<GalleryImageModel> uploadedBatch = [];
    String? lastError;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatusText = 'Preparing 1 of $total items...';
    });

    for (int i = 0; i < total; i++) {
      if (!mounted) break;
      final file = files[i];
      final currentNum = i + 1;

      setState(() {
        _uploadProgress = (i / total).clamp(0.0, 1.0);
        _uploadStatusText = 'Uploading $currentNum of $total items...';
      });

      try {
        final mediaBytes = await file.readAsBytes();
        final lower = file.name.toLowerCase();
        final isVid = lower.endsWith('.mp4') ||
            lower.endsWith('.mov') ||
            lower.endsWith('.mkv') ||
            lower.endsWith('.webm') ||
            lower.endsWith('.avi') ||
            lower.endsWith('.m4v');
        final fileName = file.name.isNotEmpty
            ? file.name
            : (isVid
                ? 'video_${DateTime.now().millisecondsSinceEpoch}_$i.mp4'
                : 'photo_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');

        final newImage = await _galleryService.uploadImage(
          folderId: _currentFolder.id,
          coupleId: coupleId,
          uploadedById: userId,
          imageBytes: mediaBytes,
          fileName: fileName,
          caption: caption,
          takenAt: takenAt,
          mediaType: isVid ? 'video' : 'image',
          updateFolderCoverIfEmpty: _currentFolder.coverImageUrl == null && !isVid && i == 0,
        );
        uploadedBatch.add(newImage);
      } catch (e) {
        lastError = e.toString().replaceFirst('Exception: ', '');
        debugPrint('Failed to upload file ${file.name}: $e');
      }
    }

    if (mounted) {
      setState(() {
        _images.insertAll(0, uploadedBatch);
        _isUploading = false;
        _uploadStatusText = null;
        _uploadProgress = 1.0;
      });
      if (uploadedBatch.isEmpty && lastError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $lastError')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${uploadedBatch.length} of $total media items uploaded successfully!')),
        );
      }
    }
  }

  Future<void> _deleteSingleImage(GalleryImageModel image) async {
    final confirmed = await showTimedConfirmDialog(
      context: context,
      title: 'Delete Photo',
      message: 'Are you sure you want to delete this photo from your shared album? This cannot be undone.',
      confirmLabel: 'Delete Photo',
      icon: Icons.delete_forever_rounded,
      countdownSeconds: 5,
    );

    if (confirmed == true) {
      try {
        await _galleryService.deleteImage(
          imageId: image.id,
          fileId: image.fileId,
          imageUrl: image.imageUrl,
        );
        if (mounted) {
          setState(() {
            _images.removeWhere((img) => img.id == image.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo deleted.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  void _openPhotoViewer(int initialIndex) {
    final imagesToView = _filteredImages.isNotEmpty ? _filteredImages : _images;
    if (imagesToView.isEmpty) return;
    final clampedIndex = initialIndex.clamp(0, imagesToView.length - 1);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenGalleryViewer(
          images: imagesToView,
          initialIndex: clampedIndex,
          onDelete: (image) {
            setState(() {
              _images.removeWhere((img) => img.id == image.id);
            });
          },
          onCaptionUpdated: (updatedImage) {
            setState(() {
              final idx = _images.indexWhere((img) => img.id == updatedImage.id);
              if (idx != -1) {
                _images[idx] = updatedImage;
              }
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coupleProvider = context.watch<CoupleProvider>();
    final partnerName = coupleProvider.partner?.displayName ?? 'Partner';

    return Scaffold(
      appBar: _isSelectionMode
          ? _buildSelectionAppBar()
          : _buildStandardAppBar(isDark),
      body: Stack(
        children: [
          Column(
            children: [
              _buildFolderHeader(isDark),
              _buildMediaTypeTabs(isDark),
              Expanded(child: _buildGridContent(isDark)),
            ],
          ),
          if (_isUploading) _buildUploadProgressOverlay(isDark),
        ],
      ),
      bottomNavigationBar: _isSelectionMode && _selectedImageIds.isNotEmpty
          ? _buildSelectionBottomBar()
          : null,
      floatingActionButton: _isSelectionMode
          ? null
          : Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: _showImageSourcePicker,
                backgroundColor: Colors.transparent,
                elevation: 0,
                highlightElevation: 0,
                icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white),
                label: const Text(
                  'Add Media',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
    );
  }

  AppBar _buildStandardAppBar(bool isDark) {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
      ),
      title: Column(
        children: [
          Text(
            _currentFolder.name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            _images.any((img) => img.isVideo)
                ? '${_images.length} item${_images.length == 1 ? '' : 's'}'
                : '${_images.length} photo${_images.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 11.5, color: Colors.white70),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        if (_images.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.checklist_rounded, color: Colors.white),
            tooltip: 'Select Photos',
            onPressed: () => _toggleSelectionMode(),
          ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: Colors.white),
          tooltip: 'Edit Album',
          onPressed: _showEditFolderDialog,
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Refresh',
          onPressed: () {
            HapticFeedback.lightImpact();
            _loadImages();
          },
        ),
      ],
    );
  }

  AppBar _buildSelectionAppBar() {
    final allSelected = _selectedImageIds.length == _images.length;
    return AppBar(
      backgroundColor: const Color(0xFF1E162B),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white),
        onPressed: () => _toggleSelectionMode(),
      ),
      title: Text(
        '${_selectedImageIds.length} Selected',
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      actions: [
        TextButton.icon(
          onPressed: _selectAll,
          icon: Icon(
            allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
            color: const Color(0xFFFF758C),
            size: 18,
          ),
          label: Text(
            allSelected ? 'Deselect All' : 'Select All',
            style: const TextStyle(
              color: Color(0xFFFF758C),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFolderHeader(bool isDark) {
    if (_currentFolder.cleanDescription.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E162B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.format_quote_rounded, color: Color(0xFFFF758C), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _currentFolder.cleanDescription,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(Icons.edit_outlined, size: 16, color: isDark ? Colors.white54 : Colors.grey.shade500),
            tooltip: 'Edit Description',
            onPressed: _showEditFolderDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildMediaTypeTabs(bool isDark) {
    final photosCount = _images.where((img) => !img.isVideo).length;
    final videosCount = _images.where((img) => img.isVideo).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E162B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Photos Option Tab
          Expanded(
            child: _buildMediaTabItem(
              title: 'Photos',
              icon: Icons.photo_library_rounded,
              count: photosCount,
              isSelected: _selectedMediaType == 'photos',
              isDark: isDark,
              onTap: () {
                if (_selectedMediaType == 'photos') return;
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedMediaType = 'photos';
                  _selectedImageIds.clear();
                  _isSelectionMode = false;
                });
              },
            ),
          ),
          const SizedBox(width: 6),
          // Videos Option Tab
          Expanded(
            child: _buildMediaTabItem(
              title: 'Videos',
              icon: Icons.videocam_rounded,
              count: videosCount,
              isSelected: _selectedMediaType == 'videos',
              isDark: isDark,
              onTap: () {
                if (_selectedMediaType == 'videos') return;
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedMediaType = 'videos';
                  _selectedImageIds.clear();
                  _isSelectionMode = false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaTabItem({
    required String title,
    required IconData icon,
    required int count,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
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
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
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
                  : (isDark ? Colors.white70 : Colors.grey.shade700),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey.shade700),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.grey.shade800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridContent(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredList = _filteredImages;

    if (filteredList.isEmpty) {
      return _buildEmptyMediaView(isDark);
    }

    return RefreshIndicator(
      onRefresh: _loadImages,
      child: GridView.builder(
        cacheExtent: 200,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        itemCount: filteredList.length,
        itemBuilder: (context, index) {
          final image = filteredList[index];
          final isSelected = _selectedImageIds.contains(image.id);

          return GestureDetector(
            onTap: () {
              if (_isSelectionMode) {
                _toggleImageSelection(image.id);
              } else {
                _openPhotoViewer(index);
              }
            },
            onLongPress: () {
              if (!_isSelectionMode) {
                _toggleSelectionMode(initialId: image.id);
              } else {
                _toggleImageSelection(image.id);
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image.isVideo)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF2E1C38), const Color(0xFF160F20)]
                              : [const Color(0xFF42275A), const Color(0xFF734B6E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.5),
                                border: Border.all(
                                  color: const Color(0xFFFF758C).withValues(alpha: 0.7),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF758C).withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.videocam_rounded, color: Colors.white, size: 10),
                                  SizedBox(width: 3),
                                  Text(
                                    'VIDEO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Builder(
                      builder: (context) {
                        final thumbUrl = NhostGalleryService.instance.getMediaUrl(
                          image.imageUrl,
                        );
                        return CachedNetworkImage(
                          imageUrl: thumbUrl,
                          httpHeaders: NhostGalleryService.instance.getStorageHeaders(url: thumbUrl),
                          memCacheWidth: 320,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: isDark ? Colors.white10 : Colors.grey.shade200,
                            child: const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF758C)),
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (ctx, url, _) => GestureDetector(
                            onTap: () {
                              CachedNetworkImage.evictFromCache(url);
                              (ctx as Element).markNeedsBuild();
                            },
                            child: Container(
                              color: isDark ? Colors.white10 : Colors.grey.shade300,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Retry',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // Caption badge
                  if (image.cleanCaption.isNotEmpty && !_isSelectionMode)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),

                  // Selection overlay and badge
                  if (_isSelectionMode)
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        color: isSelected
                            ? const Color(0xFFFF758C).withValues(alpha: 0.35)
                            : Colors.black.withValues(alpha: 0.15),
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: isSelected
                                ? Container(
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                  )
                                : Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withValues(alpha: 0.4),
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectionBottomBar() {
    final count = _selectedImageIds.length;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E162B),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF5252), Color(0xFFD81B60)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _deleteSelectedImages,
            icon: const Icon(Icons.delete_forever_rounded, color: Colors.white),
            label: Text(
              'Delete Selected ($count)',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadProgressOverlay(bool isDark) {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 36),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E162B) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                _uploadStatusText ?? 'Uploading photos...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.deepCharcoal,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _uploadProgress > 0 ? _uploadProgress : null,
                  minHeight: 6,
                  backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFFF758C)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyMediaView(bool isDark) {
    final isVideos = _selectedMediaType == 'videos';
    final title = isVideos ? 'No Videos in this Album' : 'No Photos in this Album';
    final subtitle = isVideos
        ? 'Capture or upload video memories to this album.'
        : 'Snap or upload photo memories to this album.';
    final icon = isVideos ? Icons.videocam_rounded : Icons.photo_library_rounded;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF758C).withValues(alpha: 0.15),
                    const Color(0xFFA18CD1).withValues(alpha: 0.20),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 50,
                color: const Color(0xFFFF758C),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.deepCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 22),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _showImageSourcePicker,
                icon: Icon(
                  isVideos ? Icons.video_call_rounded : Icons.add_photo_alternate_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                label: Text(
                  isVideos ? 'Add Videos to Album' : 'Add Photos to Album',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sectionTitle(String sec) {
    switch (sec) {
      case 'my_pictures':
        return 'My Pictures';
      case 'partner':
        return 'My Partner';
      case 'us':
      default:
        return 'Us';
    }
  }

  Widget _buildSectionSelector({
    required String selectedSection,
    required ValueChanged<String> onSelected,
    required bool isDark,
    String? partnerName,
  }) {
    final sections = [
      {'id': 'us', 'label': 'Us', 'icon': Icons.favorite_rounded},
      {'id': 'my_pictures', 'label': 'My Pictures', 'icon': Icons.person_rounded},
      {'id': 'partner', 'label': partnerName ?? 'My Partner', 'icon': Icons.favorite_border_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Section',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: sections.map((sec) {
            final isSelected = selectedSection == sec['id'];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(sec['id'] as String);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
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
                        : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : (isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        sec['icon'] as IconData,
                        size: 18,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.grey.shade700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sec['label'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _FullScreenGalleryViewer extends StatefulWidget {
  final List<GalleryImageModel> images;
  final int initialIndex;
  final Function(GalleryImageModel) onDelete;
  final Function(GalleryImageModel) onCaptionUpdated;

  const _FullScreenGalleryViewer({
    required this.images,
    required this.initialIndex,
    required this.onDelete,
    required this.onCaptionUpdated,
  });

  @override
  State<_FullScreenGalleryViewer> createState() => _FullScreenGalleryViewerState();
}

class _FullScreenGalleryViewerState extends State<_FullScreenGalleryViewer> {
  late PageController _pageController;
  late int _currentIndex;
  late List<GalleryImageModel> _imageList;
  bool _isSaving = false;
  bool get _showNavArrows => PhotoViewerNavPreference.showArrows;

  @override
  void initState() {
    super.initState();
    _imageList = List.from(widget.images);
    _currentIndex = widget.initialIndex.clamp(0, _imageList.isEmpty ? 0 : _imageList.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      HapticFeedback.lightImpact();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < _imageList.length - 1) {
      HapticFeedback.lightImpact();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
      );
    }
  }

  void _toggleArrows() {
    HapticFeedback.lightImpact();
    setState(() {
      PhotoViewerNavPreference.showArrows = !PhotoViewerNavPreference.showArrows;
    });
  }

  Future<void> _saveToDevice(GalleryImageModel image) async {
    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);
    try {
      final downloadUrl = NhostGalleryService.instance.getMediaUrl(image.imageUrl);
      final response = await http.get(
        Uri.parse(downloadUrl),
        headers: NhostGalleryService.instance.getStorageHeaders(url: downloadUrl),
      );
      if (response.statusCode == 200) {
        if (image.isVideo) {
          final tempDir = await getTemporaryDirectory();
          final ext = image.imageUrl.toLowerCase().contains('.mov') ? 'mov' : 'mp4';
          final tempFile = File('${tempDir.path}/JayienneLink_${DateTime.now().millisecondsSinceEpoch}.$ext');
          await tempFile.writeAsBytes(response.bodyBytes);
          await ImageGallerySaver.saveFile(tempFile.path);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          if (mounted) {
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video saved to device gallery.')),
            );
          }
        } else {
          final result = await ImageGallerySaver.saveImage(
            Uint8List.fromList(response.bodyBytes),
            quality: 100,
            name: 'JayienneLink_${DateTime.now().millisecondsSinceEpoch}',
          );
          if (mounted) {
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Saved to device photos.')),
            );
          }
        }
      } else {
        throw Exception('Download failed with status ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save media: $e')),
        );
      }
    }
  }

  Future<void> _showEditCaptionDialog(GalleryImageModel image) async {
    HapticFeedback.lightImpact();
    final captionController = TextEditingController(text: image.cleanCaption);
    DateTime? selectedDateTaken = image.takenAt;
    String selectedSection = image.section;
    final coupleProvider = context.read<CoupleProvider>();
    final partnerName = coupleProvider.partner?.displayName ?? 'Partner';

    final result = await showDialog<_CaptionDialogResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: const Color(0xFF1E162B),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Edit Photo Details',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildViewerSectionSelector(
                  selectedSection: selectedSection,
                  onSelected: (val) => setDialogState(() => selectedSection = val),
                  partnerName: partnerName,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: captionController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Add or edit description/caption (optional)...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDateTaken ?? DateTime.now(),
                      firstDate: DateTime(1990),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDateTaken = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedDateTaken != null
                            ? const Color(0xFFFF758C).withValues(alpha: 0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                          color: selectedDateTaken != null
                              ? const Color(0xFFFF758C)
                              : Colors.white60,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedDateTaken != null
                                ? 'Date Taken: ${DateFormat('MMM d, y').format(selectedDateTaken!)}'
                                : 'Date Picture Taken (Optional)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selectedDateTaken != null ? FontWeight.bold : FontWeight.normal,
                              color: selectedDateTaken != null
                                  ? Colors.white
                                  : Colors.white60,
                            ),
                          ),
                        ),
                        if (selectedDateTaken != null)
                          GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedDateTaken = null;
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryCancelButton(
                        label: 'Cancel',
                        height: 44,
                        borderRadius: 14,
                        onPressed: () => Navigator.pop(ctx, null),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            final text = captionController.text.trim();
                            final encodedCaption = text.isNotEmpty
                                ? '$text\n[section:$selectedSection]'
                                : '[section:$selectedSection]';
                            Navigator.pop(
                              ctx,
                              _CaptionDialogResult(
                                caption: encodedCaption,
                                takenAt: selectedDateTaken,
                                section: selectedSection,
                              ),
                            );
                          },
                          child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null) {
      try {
        await NhostGalleryService.instance.updateCaption(
          imageId: image.id,
          caption: result.caption ?? '',
          takenAt: result.takenAt,
          clearTakenAt: result.takenAt == null,
        );
        final updated = image.copyWith(
          caption: result.caption,
          section: result.section,
          takenAt: result.takenAt,
          clearTakenAt: result.takenAt == null,
        );
        setState(() {
          _imageList[_currentIndex] = updated;
        });
        widget.onCaptionUpdated(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo details updated.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update details: $e')),
          );
        }
      }
    }
  }

  Widget _buildViewerSectionSelector({
    required String selectedSection,
    required ValueChanged<String> onSelected,
    String? partnerName,
  }) {
    final sections = [
      {'id': 'us', 'label': 'Us', 'icon': Icons.favorite_rounded},
      {'id': 'my_pictures', 'label': 'My Pictures', 'icon': Icons.person_rounded},
      {'id': 'partner', 'label': partnerName ?? 'My Partner', 'icon': Icons.favorite_border_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Section',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: sections.map((sec) {
            final isSelected = selectedSection == sec['id'];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(sec['id'] as String);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSelected ? null : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : Colors.white12,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        sec['icon'] as IconData,
                        size: 16,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        sec['label'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _confirmAndDelete(GalleryImageModel image) async {
    HapticFeedback.lightImpact();
    final itemType = image.isVideo ? 'Video' : 'Photo';
    final confirmed = await showTimedConfirmDialog(
      context: context,
      title: 'Delete $itemType',
      message: 'Are you sure you want to delete this $itemType from your shared album? This cannot be undone.',
      confirmLabel: 'Delete $itemType',
      icon: Icons.delete_forever_rounded,
      countdownSeconds: 5,
    );

    if (confirmed == true && mounted) {
      try {
        await NhostGalleryService.instance.deleteImage(
          imageId: image.id,
          fileId: image.fileId,
          imageUrl: image.imageUrl,
        );

        widget.onDelete(image);

        if (mounted) {
          setState(() {
            _imageList.removeWhere((img) => img.id == image.id);
            if (_currentIndex >= _imageList.length && _currentIndex > 0) {
              _currentIndex = _imageList.length - 1;
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$itemType deleted.')),
          );

          if (_imageList.isEmpty) {
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete $itemType: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageList.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('No media items', style: TextStyle(color: Colors.white))),
      );
    }

    final currentImage = _imageList[_currentIndex];
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final isMe = currentImage.uploadedById == userProvider.user?.id;
    final partnerName = coupleProvider.partner?.displayName ?? 'Partner';
    final uploaderName = isMe ? 'You' : partnerName;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: _imageList.length,
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            itemBuilder: (context, index) {
              final img = _imageList[index];
              if (img.isVideo) {
                final videoUrl = NhostGalleryService.instance.getMediaUrl(img.imageUrl);
                return _GalleryVideoPlayerItem(
                  key: ValueKey(img.id),
                  videoUrl: videoUrl,
                  storageHeaders: NhostGalleryService.instance.getStorageHeaders(url: videoUrl),
                );
              }
              final viewerUrl = NhostGalleryService.instance.getMediaUrl(img.imageUrl);
              return Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: viewerUrl,
                    httpHeaders: NhostGalleryService.instance.getStorageHeaders(url: viewerUrl),
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
              );
            },
          ),

          // Left navigation arrow button (shown when _showNavArrows is true)
          if (_showNavArrows && _currentIndex > 0)
            Positioned(
              left: 14,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _goToPrevious,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1.2),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Right navigation arrow button (shown when _showNavArrows is true)
          if (_showNavArrows && _currentIndex < _imageList.length - 1)
            Positioned(
              right: 14,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _goToNext,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1.2),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Top Floating Overlay Controls: Counter, Toggle Arrows, Edit, Download, Delete, Close
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Photo counter badge (e.g. 1 / 15)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${_imageList.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Actions Row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Toggle/Hide Navigation Arrows Button (Text Label)
                        InkWell(
                          onTap: _toggleArrows,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: _showNavArrows
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : Colors.black54,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.28),
                                width: 0.9,
                              ),
                            ),
                            child: Text(
                              _showNavArrows ? 'Hide Arrows' : 'Show Arrows',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        IconButton(
                          icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
                          tooltip: 'Edit Caption',
                          onPressed: () => _showEditCaptionDialog(currentImage),
                        ),
                        IconButton(
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.download_rounded, color: Colors.white),
                          tooltip: 'Save to Device',
                          onPressed: _isSaving ? null : () => _saveToDevice(currentImage),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF5252)),
                          tooltip: 'Delete',
                          onPressed: () => _confirmAndDelete(currentImage),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Details Overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFF758C).withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              uploaderName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (currentImage.isVideo) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4D6D).withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFF4D6D).withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.videocam_rounded, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'Video',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (currentImage.takenAt != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 11),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('MMM d, y').format(currentImage.takenAt!),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              currentImage.section == 'my_pictures'
                                  ? Icons.person_rounded
                                  : (currentImage.section == 'partner'
                                      ? Icons.favorite_border_rounded
                                      : Icons.favorite_rounded),
                              color: const Color(0xFFFF758C),
                              size: 11,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              currentImage.section == 'my_pictures'
                                  ? 'My Pictures'
                                  : (currentImage.section == 'partner'
                                      ? 'My Partner'
                                      : 'Us'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => _showEditCaptionDialog(currentImage),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 13, color: Color(0xFFFF758C)),
                              SizedBox(width: 4),
                              Text(
                                'Edit',
                                style: TextStyle(
                                  color: Color(0xFFFF758C),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (currentImage.cleanCaption.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      currentImage.cleanCaption,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryVideoPlayerItem extends StatefulWidget {
  final String videoUrl;
  final Map<String, String>? storageHeaders;

  const _GalleryVideoPlayerItem({
    super.key,
    required this.videoUrl,
    this.storageHeaders,
  });

  @override
  State<_GalleryVideoPlayerItem> createState() => _GalleryVideoPlayerItemState();
}

class _GalleryVideoPlayerItemState extends State<_GalleryVideoPlayerItem> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        httpHeaders: widget.storageHeaders ?? const {},
      );
      await _controller.initialize();
      _controller.setLooping(true);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFFF5252), size: 48),
              const SizedBox(height: 12),
              const Text(
                'Could not play video',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF758C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _isInitialized = false;
                  });
                  _initializeVideo();
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                label: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF758C)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading video...',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio > 0 ? _controller.value.aspectRatio : 16 / 9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller),

              // Play/Pause center overlay button
              if (_showControls || !_controller.value.isPlaying)
                GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF758C).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),

              // Progress bar & timer at bottom of video
              if (_showControls)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        ValueListenableBuilder(
                          valueListenable: _controller,
                          builder: (context, VideoPlayerValue value, child) {
                            final pos = value.position;
                            final dur = value.duration;
                            final posStr = '${pos.inMinutes}:${(pos.inSeconds % 60).toString().padLeft(2, '0')}';
                            final durStr = '${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}';
                            return Text(
                              '$posStr / $durStr',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: VideoProgressIndicator(
                            _controller,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: Color(0xFFFF758C),
                              bufferedColor: Colors.white30,
                              backgroundColor: Colors.white12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _controller.setVolume(_controller.value.volume > 0 ? 0.0 : 1.0);
                            });
                          },
                          child: Icon(
                            _controller.value.volume > 0 ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
