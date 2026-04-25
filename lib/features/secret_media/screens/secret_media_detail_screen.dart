import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:jayienne_link/providers/secret_media_provider.dart';
import 'package:jayienne_link/models/secret_media_model.dart';

class SecretMediaDetailScreen extends StatefulWidget {
  final SecretMediaModel media;

  const SecretMediaDetailScreen({
    super.key,
    required this.media,
  });

  @override
  State<SecretMediaDetailScreen> createState() =>
      _SecretMediaDetailScreenState();
}

class _SecretMediaDetailScreenState extends State<SecretMediaDetailScreen> {
  late TextEditingController _captionController;
  bool _isEditingCaption = false;
  bool _isSavingCaption = false;

  @override
  void initState() {
    super.initState();
    _captionController =
        TextEditingController(text: widget.media.caption ?? '');
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _saveCaption() async {
    if (_captionController.text == widget.media.caption) {
      setState(() {
        _isEditingCaption = false;
      });
      return;
    }

    setState(() {
      _isSavingCaption = true;
    });

    final provider = context.read<SecretMediaProvider>();
    final success =
        await provider.updateCaption(widget.media.id!, _captionController.text);

    if (mounted) {
      setState(() {
        _isSavingCaption = false;
        if (success) {
          _isEditingCaption = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Caption updated')),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                child: widget.media.isHidden
                    ? const Text('Move to Gallery')
                    : const Text('Move to Vault'),
                onTap: () {
                  _showConfirmDialog(
                    widget.media.isHidden
                        ? 'Move to Gallery?'
                        : 'Move to Vault?',
                    widget.media.isHidden
                        ? 'Your partner will be able to see this media.'
                        : 'This media will only be visible to you.',
                    () {
                      if (widget.media.isHidden) {
                        context
                            .read<SecretMediaProvider>()
                            .moveToShared(widget.media.id!);
                      } else {
                        context
                            .read<SecretMediaProvider>()
                            .moveToHiddenVault(widget.media.id!);
                      }
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(widget.media.isHidden
                              ? 'Moved to gallery'
                              : 'Moved to vault'),
                        ),
                      );
                    },
                  );
                },
              ),
              PopupMenuItem(
                child: const Text('Delete'),
                onTap: () {
                  _showConfirmDialog(
                    'Delete Media?',
                    'This action cannot be undone.',
                    () {
                      context
                          .read<SecretMediaProvider>()
                          .deleteSecretMedia(widget.media.id!);
                      Navigator.pop(context);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Media deleted')),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Media Display
            Container(
              color: Colors.black,
              child: widget.media.mediaType == 'image'
                  ? Image.network(
                      widget.media.mediaUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 400,
                          color: Colors.grey.shade800,
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 400,
                          color: Colors.grey.shade900,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      height: 400,
                      color: Colors.grey.shade900,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.videocam,
                            size: 64,
                            color: Colors.white70,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Video Media',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to open in gallery',
                            style: GoogleFonts.poppins(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            // Details Panel
            Container(
              color: Colors.grey.shade900,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Media Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    widget.media.mediaType.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (widget.media.isHidden)
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'HIDDEN',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'SHARED',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                if (widget.media.isEncrypted)
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.lock,
                                      color: Colors.amber,
                                      size: 12,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Uploaded ${DateFormat('MMM dd, yyyy').format(widget.media.uploadedAt)}',
                              style: GoogleFonts.poppins(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Caption Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Caption',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!_isEditingCaption)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isEditingCaption = true;
                            });
                          },
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isEditingCaption)
                    Column(
                      children: [
                        TextField(
                          controller: _captionController,
                          maxLines: 4,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Add a caption...',
                            hintStyle: const TextStyle(color: Colors.white54),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Colors.white30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: Colors.blue, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                _captionController.text =
                                    widget.media.caption ?? '';
                                setState(() {
                                  _isEditingCaption = false;
                                });
                              },
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isSavingCaption ? null : _saveCaption,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                              child: _isSavingCaption
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Save'),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.media.caption?.isNotEmpty ?? false
                            ? widget.media.caption!
                            : 'No caption',
                        style: GoogleFonts.poppins(
                          color: widget.media.caption?.isNotEmpty ?? false
                              ? Colors.white
                              : Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(
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
