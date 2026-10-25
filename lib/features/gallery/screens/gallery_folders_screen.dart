import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/gallery_folder_model.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/nhost_gallery_service.dart';
import '../../../widgets/common/timed_confirm_dialog.dart';
import 'folder_detail_screen.dart';

class GalleryFoldersScreen extends StatefulWidget {
  const GalleryFoldersScreen({super.key});

  @override
  State<GalleryFoldersScreen> createState() => _GalleryFoldersScreenState();
}

class _GalleryFoldersScreenState extends State<GalleryFoldersScreen> {
  final NhostGalleryService _galleryService = NhostGalleryService.instance;
  List<GalleryFolderModel> _folders = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedSection = 'us'; // 'us', 'my_pictures', 'partner'
  bool _showSectionPicker = true;
  bool _hasPicked = false;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders({bool force = false}) async {
    final coupleProvider = context.read<CoupleProvider>();
    final userProvider = context.read<UserProvider>();
    final coupleId = coupleProvider.couple?.id ?? userProvider.coupleId;

    if (coupleId == null || coupleId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Link with your partner to access the shared gallery.';
        });
      }
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      final folders = await _galleryService.getFolders(coupleId, forceRefresh: force);
      if (mounted) {
        setState(() {
          _folders = folders;
          _isLoading = false;
          _errorMessage = _galleryService.isQuotaPaused
              ? 'Cloud sync is paused until quota resets (Nov 1). Showing available albums.'
              : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Cloud sync is paused until quota resets (Nov 1). Showing available albums.';
        });
      }
    }
  }

  Future<void> _showCreateFolderDialog({String? initialSection}) async {
    HapticFeedback.lightImpact();
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coupleProvider = context.read<CoupleProvider>();
    final partnerName = coupleProvider.partner?.displayName ?? 'Partner';
    String selectedSection = initialSection ?? _selectedSection;
    Uint8List? thumbnailBytes;
    String? thumbnailFileName;
    bool isSubmitting = false;

    await showDialog<bool>(
      context: context,
      barrierDismissible: !isSubmitting,
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
                        child: const Icon(Icons.create_new_folder_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'New Album Folder',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.deepCharcoal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Create an album in ${_sectionTitle(selectedSection, partnerName)}.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Thumbnail Picker Tile
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: isSubmitting
                        ? null
                        : () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 85,
                              maxWidth: 1200,
                            );
                            if (picked != null) {
                              final bytes = await picked.readAsBytes();
                              setDialogState(() {
                                thumbnailBytes = bytes;
                                thumbnailFileName = picked.name;
                              });
                            }
                          },
                    child: Container(
                      height: 110,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: thumbnailBytes != null
                              ? const Color(0xFFFF758C).withValues(alpha: 0.6)
                              : (isDark ? Colors.white12 : Colors.grey.shade300),
                          width: 1.5,
                        ),
                      ),
                      child: thumbnailBytes != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Image.memory(
                                    thumbnailBytes!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        thumbnailBytes = null;
                                        thumbnailFileName = null;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.photo_camera_rounded, color: Colors.white, size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'Change Thumbnail',
                                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFFFF758C).withValues(alpha: 0.15),
                                        const Color(0xFFA18CD1).withValues(alpha: 0.20),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFFFF758C), size: 22),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Upload Album Thumbnail (Optional)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap to choose a cover picture',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: nameController,
                    autofocus: false,
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
                      hintText: 'Add a sweet note about this album...',
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
                          onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
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
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final name = nameController.text.trim();
                                    if (name.isEmpty) return;

                                    final userProvider = context.read<UserProvider>();
                                    final coupleProvider = context.read<CoupleProvider>();
                                    final coupleId = coupleProvider.couple?.id ?? userProvider.coupleId;
                                    final userId = userProvider.user?.id;

                                    if (coupleId == null || userId == null) return;

                                    setDialogState(() => isSubmitting = true);

                                    try {
                                      String? coverUrl;
                                      if (thumbnailBytes != null) {
                                        coverUrl = await _galleryService.uploadStorageFile(
                                          bytes: thumbnailBytes!,
                                          fileName: thumbnailFileName ?? 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg',
                                        );
                                      }

                                      final rawDesc = descController.text.trim();
                                      final encodedDesc = rawDesc.isNotEmpty
                                          ? '$rawDesc\n[section:$selectedSection]'
                                          : '[section:$selectedSection]';

                                      await _galleryService.createFolder(
                                        coupleId: coupleId,
                                        createdById: userId,
                                        name: name,
                                        description: encodedDesc,
                                        coverImageUrl: coverUrl,
                                      );

                                      if (ctx.mounted) {
                                        Navigator.pop(ctx, true);
                                      }
                                      _loadFolders();
                                    } catch (e) {
                                      setDialogState(() => isSubmitting = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed to create folder: $e')),
                                        );
                                      }
                                    }
                                  },
                            icon: isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                            label: Text(
                              isSubmitting ? 'Creating...' : 'Create',
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
      ),
    );
  }

  Future<void> _showEditFolderDialog(GalleryFolderModel folder) async {
    HapticFeedback.lightImpact();
    final nameController = TextEditingController(text: folder.name);
    final descController = TextEditingController(text: folder.cleanDescription);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProvider = context.read<UserProvider>();
    final currentUserId = userProvider.user?.id ?? '';
    final coupleProvider = context.read<CoupleProvider>();
    final partnerName = coupleProvider.partner?.displayName ?? 'Partner';
    String selectedSection = folder.effectiveSection(currentUserId);
    Uint8List? newThumbnailBytes;
    String? newThumbnailFileName;
    String? currentCoverUrl = folder.coverImageUrl;
    bool isSubmitting = false;

    await showDialog<bool>(
      context: context,
      barrierDismissible: !isSubmitting,
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
                          'Edit Album',
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

                  // Thumbnail Tile (shows existing cover or newly chosen thumbnail)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: isSubmitting
                        ? null
                        : () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 85,
                              maxWidth: 1200,
                            );
                            if (picked != null) {
                              final bytes = await picked.readAsBytes();
                              setDialogState(() {
                                newThumbnailBytes = bytes;
                                newThumbnailFileName = picked.name;
                              });
                            }
                          },
                    child: Container(
                      height: 110,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (newThumbnailBytes != null || (currentCoverUrl != null && currentCoverUrl!.isNotEmpty))
                              ? const Color(0xFFFF758C).withValues(alpha: 0.6)
                              : (isDark ? Colors.white12 : Colors.grey.shade300),
                          width: 1.5,
                        ),
                      ),
                      child: newThumbnailBytes != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Image.memory(
                                    newThumbnailBytes!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        newThumbnailBytes = null;
                                        newThumbnailFileName = null;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.photo_camera_rounded, color: Colors.white, size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'Change Thumbnail',
                                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : (currentCoverUrl != null && currentCoverUrl!.isNotEmpty)
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: Builder(
                                        builder: (context) {
                                          final coverUrl = _galleryService.getMediaUrl(
                                            currentCoverUrl!,
                                            width: 500,
                                            quality: 75,
                                          );
                                          return CachedNetworkImage(
                                            imageUrl: coverUrl,
                                            httpHeaders: _galleryService.getStorageHeaders(url: coverUrl),
                                            memCacheWidth: 500,
                                            fit: BoxFit.cover,
                                          );
                                        },
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.photo_camera_rounded, color: Colors.white, size: 12),
                                            SizedBox(width: 4),
                                            Text(
                                              'Change Thumbnail',
                                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFFFF758C).withValues(alpha: 0.15),
                                            const Color(0xFFA18CD1).withValues(alpha: 0.20),
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFFFF758C), size: 22),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Upload Album Thumbnail (Optional)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : AppColors.deepCharcoal,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tap to select a cover picture',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: nameController,
                    autofocus: false,
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
                      hintText: 'Add a sweet note about this album...',
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
                          onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
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
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final newName = nameController.text.trim();
                                    if (newName.isEmpty) return;

                                    setDialogState(() => isSubmitting = true);

                                    try {
                                      String? updatedCoverUrl = currentCoverUrl;
                                      if (newThumbnailBytes != null) {
                                        updatedCoverUrl = await _galleryService.uploadStorageFile(
                                          bytes: newThumbnailBytes!,
                                          fileName: newThumbnailFileName ?? 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg',
                                        );
                                      }

                                      String sectionToStore = selectedSection;
                                      if (folder.createdById.isNotEmpty && folder.createdById != currentUserId) {
                                        if (selectedSection == 'my_pictures') {
                                          sectionToStore = 'partner';
                                        } else if (selectedSection == 'partner') {
                                          sectionToStore = 'my_pictures';
                                        }
                                      }

                                      await _galleryService.updateFolder(
                                        folderId: folder.id,
                                        name: newName,
                                        description: descController.text.trim().isNotEmpty
                                            ? '${descController.text.trim()}\n[section:$sectionToStore]'
                                            : '[section:$sectionToStore]',
                                        coverImageUrl: updatedCoverUrl,
                                      );

                                      if (ctx.mounted) {
                                        Navigator.pop(ctx, true);
                                      }
                                      _loadFolders();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Album updated successfully.')),
                                        );
                                      }
                                    } catch (e) {
                                      setDialogState(() => isSubmitting = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed to update album: $e')),
                                        );
                                      }
                                    }
                                  },
                            icon: isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                            label: Text(
                              isSubmitting ? 'Saving...' : 'Save',
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
      ),
    );
  }

  Future<void> _confirmDeleteFolder(GalleryFolderModel folder) async {
    final confirmed = await showTimedConfirmDialog(
      context: context,
      title: 'Delete Album Folder',
      message: 'Are you sure you want to delete "${folder.name}" and all photos inside it? This action cannot be undone.',
      confirmLabel: 'Delete Album',
      icon: Icons.delete_forever_rounded,
      countdownSeconds: 5,
    );

    if (confirmed == true) {
      try {
        await _galleryService.deleteFolder(folder.id);
        _loadFolders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Album "${folder.name}" deleted.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete album: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final currentUserId = userProvider.user?.id ?? '';
    final partnerName = coupleProvider.partner?.displayName ?? 'Partner';

    return PopScope(
      canPop: _showSectionPicker,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_showSectionPicker) {
          setState(() => _showSectionPicker = true);
        }
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF120E19) : const Color(0xFFFFF7F9),
        appBar: AppBar(
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
              if (!_showSectionPicker) {
                setState(() => _showSectionPicker = true);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: const Text(
            'Shared Gallery',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Refresh',
              onPressed: () {
                HapticFeedback.lightImpact();
                _loadFolders();
              },
            ),
          ],
        ),
        body: _buildBody(isDark, currentUserId, partnerName),
        floatingActionButton: _showSectionPicker
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
                  onPressed: () => _showCreateFolderDialog(initialSection: _selectedSection),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  highlightElevation: 0,
                  icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white),
                  label: Text(
                    'New ${_sectionTitle(_selectedSection)} Album',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBody(bool isDark, String currentUserId, String partnerName) {
    if (_isLoading && _folders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_showSectionPicker) {
      return _buildSectionPickerView(isDark, partnerName, currentUserId);
    }

    return _buildFoldersContent(isDark, currentUserId, partnerName);
  }

  Widget _buildQuotaNoticeBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF281A32) : const Color(0xFFF9F0F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFA18CD1).withValues(alpha: isDark ? 0.35 : 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA18CD1).withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF758C).withValues(alpha: 0.2),
                  const Color(0xFFA18CD1).withValues(alpha: 0.2),
                ],
              ),
            ),
            child: const Icon(
              Icons.cloud_sync_outlined,
              size: 20,
              color: Color(0xFFFF758C),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cloud Sync Paused (Quota Reset Nov 1)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF3D234A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Browsing cached albums and photos while sync rests.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _loadFolders(force: true);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
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
    );
  }

  Widget _buildSectionPickerView(bool isDark, String partnerName, String currentUserId) {
    final usCount = _folders.where((f) => f.effectiveSection(currentUserId) == 'us').length;
    final myPicturesCount = _folders.where((f) => f.effectiveSection(currentUserId) == 'my_pictures').length;
    final partnerCount = _folders.where((f) => f.effectiveSection(currentUserId) == 'partner').length;

    final sectionItems = [
      (
        id: 'us',
        title: 'Us',
        subtitle: 'Shared memories & albums of both of you',
        icon: Icons.favorite_rounded,
        count: usCount,
        color: const Color(0xFFFF758C),
      ),
      (
        id: 'my_pictures',
        title: 'My Pictures',
        subtitle: 'Personal pictures, solo shots & private albums',
        icon: Icons.person_rounded,
        count: myPicturesCount,
        color: const Color(0xFFA18CD1),
      ),
      (
        id: 'partner',
        title: partnerName.isNotEmpty ? 'My Partner ($partnerName)' : 'My Partner',
        subtitle: 'Albums dedicated to pictures of $partnerName',
        icon: Icons.favorite_border_rounded,
        count: partnerCount,
        color: const Color(0xFFFF9A5C),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null) _buildQuotaNoticeBanner(isDark),
          Text(
            'What are we viewing?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF2D2D2D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick a section to browse and manage albums',
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ...sectionItems.map((item) {
            final isActive = _hasPicked && _selectedSection == item.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _selectedSection = item.id;
                    _showSectionPicker = false;
                    _hasPicked = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? LinearGradient(
                            colors: [
                              item.color.withValues(alpha: isDark ? 0.22 : 0.12),
                              const Color(0xFFA18CD1).withValues(alpha: isDark ? 0.12 : 0.06),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isActive
                        ? null
                        : (isDark ? const Color(0xFF1E162B) : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive
                          ? item.color.withValues(alpha: 0.5)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.grey.shade200),
                      width: isActive ? 1.5 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isActive
                            ? item.color.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                        blurRadius: isActive ? 14 : 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [item.color, const Color(0xFFA18CD1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: item.color.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(item.icon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF2D2D2D),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: item.color.withValues(alpha: isDark ? 0.22 : 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${item.count} album${item.count == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: item.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.subtitle,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? Colors.white54 : Colors.grey.shade600,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: isActive
                            ? item.color
                            : (isDark ? Colors.white30 : Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionBanner(bool isDark, String partnerName) {
    final IconData icon = _selectedSection == 'my_pictures'
        ? Icons.person_rounded
        : (_selectedSection == 'partner'
            ? Icons.favorite_border_rounded
            : Icons.favorite_rounded);

    final Color secColor = _selectedSection == 'my_pictures'
        ? const Color(0xFFA18CD1)
        : (_selectedSection == 'partner'
            ? const Color(0xFFFF9A5C)
            : const Color(0xFFFF758C));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [secColor, const Color(0xFFA18CD1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _sectionTitle(_selectedSection, partnerName),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2D2D2D),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showSectionPicker = true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swap_horiz_rounded,
                    size: 15,
                    color: isDark ? Colors.white70 : const Color(0xFFFF758C),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFFFF758C),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoldersContent(bool isDark, String currentUserId, String partnerName) {
    final filteredFolders = _folders.where((f) => f.effectiveSection(currentUserId) == _selectedSection).toList();

    return Column(
      children: [
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _buildQuotaNoticeBanner(isDark),
          ),
        _buildSectionBanner(isDark, partnerName),
        Expanded(
          child: filteredFolders.isEmpty
              ? _buildEmptySectionView(isDark, partnerName)
              : RefreshIndicator(
                  onRefresh: _loadFolders,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: filteredFolders.length,
                    itemBuilder: (context, index) {
                      final folder = filteredFolders[index];
                      final isOwner = folder.createdById == currentUserId;
                      final creatorLabel = isOwner ? 'You' : partnerName;

                      return _FolderCard(
                        folder: folder,
                        creatorLabel: creatorLabel,
                        isOwner: isOwner,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FolderDetailScreen(folder: folder),
                            ),
                          );
                          _loadFolders();
                        },
                        onEdit: () => _showEditFolderDialog(folder),
                        onDelete: () => _confirmDeleteFolder(folder),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptySectionView(bool isDark, String partnerName) {
    final String title;
    final String subtitle;
    final IconData icon;

    switch (_selectedSection) {
      case 'my_pictures':
        title = 'No "My Pictures" Albums Yet';
        subtitle = 'Create an album for your personal pictures and memories.';
        icon = Icons.person_rounded;
        break;
      case 'partner':
        title = 'No "My Partner" Albums Yet';
        subtitle = 'Create an album dedicated to pictures of $partnerName.';
        icon = Icons.favorite_border_rounded;
        break;
      case 'us':
      default:
        title = 'No "Us" Albums Yet';
        subtitle = 'Create an album to collect shared memories together.';
        icon = Icons.favorite_rounded;
        break;
    }

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
                borderRadius: BorderRadius.circular(16),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () => _showCreateFolderDialog(initialSection: _selectedSection),
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: Text(
                  'Create Album in ${_sectionTitle(_selectedSection)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sectionTitle(String sec, [String? partnerName]) {
    if (sec == 'my_pictures') return 'My Pictures';
    if (sec == 'partner') {
      return (partnerName != null && partnerName.isNotEmpty)
          ? 'My Partner ($partnerName)'
          : 'My Partner';
    }
    return 'Us';
  }


}

class _FolderCard extends StatelessWidget {
  final GalleryFolderModel folder;
  final String creatorLabel;
  final bool isOwner;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FolderCard({
    required this.folder,
    required this.creatorLabel,
    required this.isOwner,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasCover = folder.coverImageUrl != null && folder.coverImageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E162B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image or Gradient Placeholder
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasCover)
                    Builder(
                      builder: (context) {
                        final coverUrl = NhostGalleryService.instance.getMediaUrl(
                          folder.coverImageUrl!,
                          width: 450,
                          quality: 75,
                        );
                        return CachedNetworkImage(
                          imageUrl: coverUrl,
                          httpHeaders: NhostGalleryService.instance.getStorageHeaders(url: coverUrl),
                          memCacheWidth: 450,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: isDark ? Colors.white10 : Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, __, ___) => _buildFallbackCover(),
                        );
                      },
                    )
                  else
                    _buildFallbackCover(),

                  // Gradient Overlay for readability
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // 3-dot Menu for Edit & Delete
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: const CircleBorder(),
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: isDark ? const Color(0xFF261D36) : Colors.white,
                        onSelected: (val) {
                          if (val == 'edit') onEdit();
                          if (val == 'delete') onDelete();
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18, color: Color(0xFFFF758C)),
                                SizedBox(width: 10),
                                Text('Edit Album', style: TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFFF5252)),
                                SizedBox(width: 10),
                                Text('Delete Album', style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Photo Count Badge bottom right
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '${folder.imageCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Folder Info
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      folder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: isDark ? Colors.white : AppColors.deepCharcoal,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (folder.cleanDescription.isNotEmpty)
                      Text(
                        folder.cleanDescription,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                      )
                    else
                      Text(
                        'By $creatorLabel',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.photo_album_outlined,
          color: Colors.white70,
          size: 38,
        ),
      ),
    );
  }
}
