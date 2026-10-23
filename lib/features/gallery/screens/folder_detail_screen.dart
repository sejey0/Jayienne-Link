import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/gallery_folder_model.dart';
import '../../../models/gallery_image_model.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/nhost_gallery_service.dart';
import '../../../widgets/common/timed_confirm_dialog.dart';

class _CaptionDialogResult {
  final String? caption;
  final DateTime? takenAt;

  const _CaptionDialogResult({this.caption, this.takenAt});
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

  // Selection mode for batch delete
  bool _isSelectionMode = false;
  final Set<String> _selectedImageIds = {};

  @override
  void initState() {
    super.initState();
    _loadImages();
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
    final descController = TextEditingController(text: _currentFolder.description ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
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
              const SizedBox(height: 16),
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
                          Navigator.pop(ctx, true);
                          try {
                            await _galleryService.updateFolder(
                              folderId: _currentFolder.id,
                              name: newName,
                              description: newDesc,
                            );
                            if (mounted) {
                              setState(() {
                                _customFolder = _currentFolder.copyWith(
                                  name: newName,
                                  description: newDesc,
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
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
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
                'Upload Photos to ${_currentFolder.name}',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.deepCharcoal,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickMultipleImages();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
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
                              child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Multiple Photos',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: isDark ? Colors.white : AppColors.deepCharcoal,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Select from gallery',
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickCameraImage();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
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
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Take Photo',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickMultipleImages() async {
    HapticFeedback.lightImpact();
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (pickedFiles.isEmpty) return;

      if (!mounted) return;

      // Ask for optional common caption & date taken for the batch
      final result = await _showBatchCaptionDialog(pickedFiles.length);
      if (result == null) return; // User cancelled

      _uploadMultipleFiles(
        pickedFiles,
        caption: result.caption,
        takenAt: result.takenAt,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick images: $e')),
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

      final result = await _showSingleCaptionDialog(imageBytes);
      if (result == null) return;

      _startUploadingSingle(
        imageBytes,
        fileName,
        caption: result.caption,
        takenAt: result.takenAt,
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
                const SizedBox(height: 18),
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
                            Navigator.pop(
                              ctx,
                              _CaptionDialogResult(
                                caption: text.isEmpty ? null : text,
                                takenAt: selectedDateTaken,
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

  Future<_CaptionDialogResult?> _showSingleCaptionDialog(Uint8List imageBytes) async {
    final captionController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                      child: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Add Photo Details',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    imageBytes,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
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
                            Navigator.pop(
                              ctx,
                              _CaptionDialogResult(
                                caption: text.isEmpty ? null : text,
                                takenAt: selectedDateTaken,
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
    Uint8List imageBytes,
    String fileName, {
    String? caption,
    DateTime? takenAt,
  }) async {
    final userProvider = context.read<UserProvider>();
    final coupleProvider = context.read<CoupleProvider>();
    final coupleId = coupleProvider.couple?.id ?? userProvider.coupleId;
    final userId = userProvider.user?.id;

    if (coupleId == null || userId == null) return;

    setState(() {
      _isUploading = true;
      _uploadStatusText = 'Uploading photo...';
      _uploadProgress = 0.5;
    });

    try {
      final newImage = await _galleryService.uploadImage(
        folderId: _currentFolder.id,
        coupleId: coupleId,
        uploadedById: userId,
        imageBytes: imageBytes,
        fileName: fileName,
        caption: caption,
        takenAt: takenAt,
        updateFolderCoverIfEmpty: _currentFolder.coverImageUrl == null,
      );

      if (mounted) {
        setState(() {
          _images.insert(0, newImage);
          _isUploading = false;
          _uploadStatusText = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded successfully!')),
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

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatusText = 'Preparing 1 of $total photos...';
    });

    for (int i = 0; i < total; i++) {
      if (!mounted) break;
      final file = files[i];
      final currentNum = i + 1;

      setState(() {
        _uploadProgress = (i / total).clamp(0.0, 1.0);
        _uploadStatusText = 'Uploading $currentNum of $total photos...';
      });

      try {
        final imageBytes = await file.readAsBytes();
        final fileName = file.name.isNotEmpty
            ? file.name
            : 'photo_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

        final newImage = await _galleryService.uploadImage(
          folderId: _currentFolder.id,
          coupleId: coupleId,
          uploadedById: userId,
          imageBytes: imageBytes,
          fileName: fileName,
          caption: caption,
          takenAt: takenAt,
          updateFolderCoverIfEmpty: _currentFolder.coverImageUrl == null && i == 0,
        );
        uploadedBatch.add(newImage);
      } catch (e) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${uploadedBatch.length} of $total photos uploaded successfully!')),
      );
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenGalleryViewer(
          images: _images,
          initialIndex: initialIndex,
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

    return Scaffold(
      appBar: _isSelectionMode
          ? _buildSelectionAppBar()
          : _buildStandardAppBar(isDark),
      body: Stack(
        children: [
          Column(
            children: [
              _buildFolderHeader(isDark),
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
                  'Add Photos',
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
            '${_images.length} photos',
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
    if (_currentFolder.description == null || _currentFolder.description!.isEmpty) {
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
              _currentFolder.description!,
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

  Widget _buildGridContent(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_images.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF758C).withValues(alpha: 0.15),
                      const Color(0xFFA18CD1).withValues(alpha: 0.20),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  size: 48,
                  color: Color(0xFFFF758C),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'This Album is Empty',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.deepCharcoal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap "Add Photos" to upload multiple pictures together into "${_currentFolder.name}".',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadImages,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 96),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        itemCount: _images.length,
        itemBuilder: (context, index) {
          final image = _images[index];
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
                  CachedNetworkImage(
                    imageUrl: image.imageUrl,
                    httpHeaders: NhostGalleryService.instance.storageHeaders,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: isDark ? Colors.white10 : Colors.grey.shade300,
                      child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                    ),
                  ),

                  // Caption badge
                  if (image.caption != null && image.caption!.isNotEmpty && !_isSelectionMode)
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

  @override
  void initState() {
    super.initState();
    _imageList = List.from(widget.images);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _saveToDevice(String imageUrl) async {
    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);
    try {
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: NhostGalleryService.instance.storageHeaders,
      );
      if (response.statusCode == 200) {
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
      } else {
        throw Exception('Download failed with status ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save image: $e')),
        );
      }
    }
  }

  Future<void> _showEditCaptionDialog(GalleryImageModel image) async {
    HapticFeedback.lightImpact();
    final captionController = TextEditingController(text: image.caption ?? '');
    DateTime? selectedDateTaken = image.takenAt;

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
                            Navigator.pop(
                              ctx,
                              _CaptionDialogResult(
                                caption: text.isEmpty ? null : text,
                                takenAt: selectedDateTaken,
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

  Future<void> _confirmAndDelete(GalleryImageModel image) async {
    HapticFeedback.lightImpact();
    final confirmed = await showTimedConfirmDialog(
      context: context,
      title: 'Delete Photo',
      message: 'Are you sure you want to delete this photo from your shared album? This cannot be undone.',
      confirmLabel: 'Delete Photo',
      icon: Icons.delete_forever_rounded,
      countdownSeconds: 5,
    );

    if (confirmed == true && mounted) {
      try {
        await NhostGalleryService.instance.deleteImage(
          imageId: image.id,
          fileId: image.fileId,
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
            const SnackBar(content: Text('Photo deleted.')),
          );

          if (_imageList.isEmpty) {
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete photo: $e')),
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
        body: Center(child: Text('No photos', style: TextStyle(color: Colors.white))),
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
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.75),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} of ${_imageList.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
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
                : const Icon(Icons.download_rounded),
            tooltip: 'Save to Device',
            onPressed: _isSaving ? null : () => _saveToDevice(currentImage.imageUrl),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF5252)),
            tooltip: 'Delete',
            onPressed: () => _confirmAndDelete(currentImage),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _imageList.length,
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            itemBuilder: (context, index) {
              final img = _imageList[index];
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: img.imageUrl,
                    httpHeaders: NhostGalleryService.instance.storageHeaders,
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
                  if (currentImage.caption != null && currentImage.caption!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      currentImage.caption!,
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
