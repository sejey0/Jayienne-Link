import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jayienne_link/providers/secret_media_provider.dart';
import 'package:jayienne_link/models/secret_media_model.dart';
import 'add_secret_media_screen.dart';
import 'secret_media_detail_screen.dart';

class HiddenVaultScreen extends StatefulWidget {
  const HiddenVaultScreen({super.key});

  @override
  State<HiddenVaultScreen> createState() => _HiddenVaultScreenState();
}

class _HiddenVaultScreenState extends State<HiddenVaultScreen> {
  static const List<String> _vaultLocks = [
    'purpink',
    '0122',
    'cr',
    '1230',
    'sagad',
    '071525',
  ];

  String _selectedType = 'image';
  bool _isUnlocked = false;
  String? _lockError;
  late final List<TextEditingController> _lockControllers;

  @override
  void initState() {
    super.initState();
    _lockControllers =
        List.generate(_vaultLocks.length, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (final controller in _lockControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _normalizeLock(String value) {
    return value.trim().toLowerCase();
  }

  void _tryUnlockVault() {
    final isValid = _lockControllers.asMap().entries.every((entry) {
      final index = entry.key;
      final value = entry.value.text;
      return _normalizeLock(value) == _normalizeLock(_vaultLocks[index]);
    });

    if (isValid) {
      setState(() {
        _isUnlocked = true;
        _lockError = null;
      });
      return;
    }

    setState(() {
      _lockError = 'Incorrect lock combination. Please try again.';
    });
  }

  Widget _buildLockGate() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Icon(
            Icons.lock,
            size: 56,
            color: Colors.red.shade700,
          ),
          const SizedBox(height: 12),
          Text(
            'Enter 6 Locks to Open Vault',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(_vaultLocks.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _lockControllers[index],
                decoration: InputDecoration(
                  labelText: 'Lock ${index + 1}',
                  border: const OutlineInputBorder(),
                ),
              ),
            );
          }),
          if (_lockError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _lockError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ElevatedButton.icon(
            onPressed: _tryUnlockVault,
            icon: const Icon(Icons.lock_open),
            label: const Text('Unlock Vault'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  List<SecretMediaModel> _filteredHiddenMedia(SecretMediaProvider provider) {
    return provider.hiddenMedia
        .where((media) => media.mediaType == _selectedType)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hidden Vault 🔐',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        actions: _isUnlocked
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () async {
                    final provider = context.read<SecretMediaProvider>();
                    await provider.refresh();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vault refreshed')),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddSecretMediaScreen(),
                      ),
                    );
                  },
                ),
              ]
            : null,
      ),
      body: !_isUnlocked
          ? _buildLockGate()
          : Consumer<SecretMediaProvider>(
              builder: (context, provider, _) {
                final imageCount = provider.hiddenMedia
                    .where((m) => m.mediaType == 'image')
                    .length;
                final videoCount = provider.hiddenMedia
                    .where((m) => m.mediaType == 'video')
                    .length;
                final filteredMedia = _filteredHiddenMedia(provider);

                if (_selectedType == 'image' &&
                    imageCount == 0 &&
                    videoCount > 0) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _selectedType = 'video';
                      });
                    }
                  });
                }

                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.red),
                  );
                }

                if (provider.hiddenMedia.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your vault is empty',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Move media here to keep it private',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: Text('Images ($imageCount)'),
                              selected: _selectedType == 'image',
                              onSelected: (_) {
                                setState(() {
                                  _selectedType = 'image';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: Text('Videos ($videoCount)'),
                              selected: _selectedType == 'video',
                              onSelected: (_) {
                                setState(() {
                                  _selectedType = 'video';
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filteredMedia.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _selectedType == 'image'
                                        ? Icons.image_outlined
                                        : Icons.videocam_outlined,
                                    size: 56,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _selectedType == 'image'
                                        ? 'No hidden images yet'
                                        : 'No hidden videos yet',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.8,
                              ),
                              itemCount: filteredMedia.length,
                              itemBuilder: (context, index) {
                                final media = filteredMedia[index];
                                return _buildMediaCard(
                                    context, media, provider);
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildMediaCard(
    BuildContext context,
    SecretMediaModel media,
    SecretMediaProvider provider,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SecretMediaDetailScreen(media: media),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media image or thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: media.mediaType == 'video' &&
                      (media.thumbnail == null || media.thumbnail!.isEmpty)
                  ? Container(
                      color: Colors.black87,
                      child: const Center(
                        child: Icon(
                          Icons.videocam,
                          size: 40,
                          color: Colors.white70,
                        ),
                      ),
                    )
                  : Image.network(
                      media.mediaType == 'video'
                          ? (media.thumbnail ?? media.mediaUrl)
                          : media.mediaUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade300,
                          child: const Icon(
                            Icons.broken_image,
                            size: 32,
                            color: Colors.grey,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.red,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Video badge
            if (media.mediaType == 'video')
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.videocam,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            // Hidden badge
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
            // Menu button
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: PopupMenuButton(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 20,
                  ),
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem(
                      child: const Text('Delete'),
                      onTap: () {
                        _showConfirmDialog(
                          context,
                          'Delete Media?',
                          'This action cannot be undone.',
                          () {
                            provider.deleteSecretMedia(media.id!);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Media deleted')),
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
