import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import 'package:jayienne_link/providers/secret_media_provider.dart';
import 'package:jayienne_link/providers/auth_provider.dart';
import 'package:jayienne_link/providers/user_provider.dart';
import 'package:jayienne_link/models/secret_media_model.dart';
import 'add_secret_media_screen.dart';
import 'hidden_vault_screen.dart';
import 'secret_media_detail_screen.dart';

class SecretMediaGalleryScreen extends StatefulWidget {
  const SecretMediaGalleryScreen({super.key});

  @override
  State<SecretMediaGalleryScreen> createState() =>
      _SecretMediaGalleryScreenState();
}

class _SecretMediaGalleryScreenState extends State<SecretMediaGalleryScreen> {
  String _selectedFilter = 'all'; // 'all', 'image', 'video'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final user = context.read<UserProvider>();
      final coupleId = user.user?.coupleId ?? user.coupleId;
      final userId = auth.currentUserId ?? user.user?.id;
      if (coupleId != null &&
          coupleId.isNotEmpty &&
          userId != null &&
          userId.isNotEmpty) {
        context.read<SecretMediaProvider>().initialize(
              userId: userId,
              coupleId: coupleId,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Secret Gallery',
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
        actions: [
          // Hidden vault button
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Consumer<SecretMediaProvider>(
              builder: (context, provider, _) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HiddenVaultScreen(),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock, color: Colors.white),
                      if (provider.hiddenMediaCount > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${provider.hiddenMediaCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Consumer3<SecretMediaProvider, AuthProvider, UserProvider>(
        builder: (context, secretMediaProvider, authProvider, userProvider, _) {
          if (secretMediaProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            );
          }

          if (secretMediaProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    secretMediaProvider.error ?? 'An error occurred',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      secretMediaProvider.clearError();
                      secretMediaProvider.refresh();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final mediaItems = secretMediaProvider.sharedMedia;
          debugPrint('📱 UI GALLERY RECEIVED ITEMS: ${mediaItems.length}');

          final filteredItems = mediaItems.where((item) {
            if (_selectedFilter == 'image') return item.mediaType == 'image';
            if (_selectedFilter == 'video') return item.mediaType == 'video';
            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: () => secretMediaProvider.refresh(),
            color: Colors.deepPurple,
            child: Column(
              children: [
                // Stats Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.deepPurple.shade400,
                        Colors.deepPurple.shade700,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '${secretMediaProvider.sharedMediaCount}',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Shared',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const VerticalDivider(
                        color: Colors.white24,
                        thickness: 1.5,
                      ),
                      Column(
                        children: [
                          Text(
                            '${secretMediaProvider.hiddenMediaCount}',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Hidden',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const VerticalDivider(
                        color: Colors.white24,
                        thickness: 1.5,
                      ),
                      Column(
                        children: [
                          Text(
                            '${secretMediaProvider.totalMediaCount}',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Total',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Filter chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all', mediaItems.length),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Photos',
                        'image',
                        mediaItems.where((m) => m.mediaType == 'image').length,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Videos',
                        'video',
                        mediaItems.where((m) => m.mediaType == 'video').length,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Gallery
                Expanded(
                  child: filteredItems.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.35,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No secret media yet',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add your first secret photo or video',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final media = filteredItems[index];
                            return _buildMediaCard(
                              context,
                              media,
                              secretMediaProvider,
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddSecretMediaScreen(),
            ),
          );
        },
        backgroundColor: Colors.deepPurple.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMediaCard(
    BuildContext context,
    SecretMediaModel media,
    SecretMediaProvider provider,
  ) {
    final currentUserId = context.read<AuthProvider>().currentUserId;
    final canDelete =
        currentUserId != null && currentUserId == media.uploadedById;

    final displayImageUrl = media.mediaType == 'video'
        ? (media.thumbnail?.isNotEmpty == true
            ? media.thumbnail!
            : media.displayUrl)
        : media.displayUrl;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SecretMediaDetailScreen(media: media),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Container(
          color: Colors.grey.shade900,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Bottom Layer: Media Image / Thumbnail
              if (displayImageUrl.isNotEmpty)
                Image.network(
                  displayImageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.deepPurple,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey.shade900,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: Colors.pinkAccent,
                        size: 28,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  color: Colors.grey.shade900,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: 28,
                      color: Colors.white38,
                    ),
                  ),
                ),

              // 2. Middle Layer: Permanent Blur & Dark Privacy Overlay
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: const Center(
                      child: Icon(
                        Icons.lock_rounded,
                        color: Colors.white70,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Top Layer: Video Indicator (if applicable)
              if (media.mediaType == 'video')
                const Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.black54,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),

              // 4. Menu button (More options / Vault / Delete)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: PopupMenuButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                    ),
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem(
                        child: const Text('Move to Vault'),
                        onTap: () {
                          _showConfirmDialog(
                            context,
                            'Move to Hidden Vault?',
                            'This media will only be visible to you.',
                            () {
                              provider.moveToHiddenVault(media.id!);
                              SnackbarHelper.showSuccess(
                                context,
                                'Moved to hidden vault',
                              );
                            },
                          );
                        },
                      ),
                      if (canDelete)
                        PopupMenuItem(
                          child: const Text('Delete'),
                          onTap: () {
                            _showConfirmDialog(
                              context,
                              'Delete Media?',
                              'This action cannot be undone.',
                              () {
                                provider.deleteSecretMedia(media.id!);
                                SnackbarHelper.showSuccess(
                                  context,
                                  'Media deleted',
                                );
                              },
                            );
                          },
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

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple.shade700 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade800,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text(
              'Confirm',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
