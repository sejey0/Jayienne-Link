import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:jayienne_link/providers/auth_provider.dart';
import 'package:jayienne_link/providers/secret_media_provider.dart';
import 'package:jayienne_link/models/secret_media_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import 'package:video_player/video_player.dart';
import '../../../widgets/common/app_text_field.dart';

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
  final FocusNode _captionFocusNode = FocusNode();
  String? _currentCaption;
  bool _isEditingCaption = false;
  bool _isSavingCaption = false;
  bool _isImageMasked = false;
  bool _showVideoControls = false;
  VideoPlayerController? _videoController;
  Future<void>? _videoInitializeFuture;
  String? _videoError;

  bool get _isUploader {
    final currentUserId = context.read<AuthProvider>().currentUserId;
    final isUploader = currentUserId != null &&
        currentUserId.isNotEmpty &&
        widget.media.uploadedById.isNotEmpty &&
        currentUserId == widget.media.uploadedById;

    // Debug: Print to console to help troubleshoot
    debugPrint(
        'Delete Permission Check: currentUser=$currentUserId, uploadedBy=${widget.media.uploadedById}, canDelete=$isUploader');

    return isUploader;
  }

  @override
  void initState() {
    super.initState();
    _currentCaption = widget.media.caption;
    _captionController =
        TextEditingController(text: widget.media.caption ?? '');

    if (widget.media.mediaType == 'video') {
      _initializeVideoPlayer();
    }
  }

  void _initializeVideoPlayer() {
    try {
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.media.mediaUrl));
      _videoController = controller;
      _videoInitializeFuture = controller.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      }).catchError((error) {
        if (!mounted) return;
        setState(() {
          _videoError = _buildVideoErrorMessage(error);
        });
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _videoError = _buildVideoErrorMessage(error);
      });
    }
  }

  String _buildVideoErrorMessage(Object error) {
    final message = error.toString();
    if (error is PlatformException ||
        message.contains('Unable to establish connection on channel') ||
        message.contains('video_player_android')) {
      return 'Video player is not initialized. Fully restart the app (stop and run again).';
    }
    return 'Failed to load video';
  }

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocusNode.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _startEditingCaption() {
    setState(() {
      _isEditingCaption = true;
      _captionController.selection = TextSelection.fromPosition(
        TextPosition(offset: _captionController.text.length),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _captionFocusNode.requestFocus();
      }
    });
  }

  Future<void> _saveCaption() async {
    final newCaption = _captionController.text.trim();
    final currentCaption = _currentCaption?.trim() ?? '';

    if (newCaption == currentCaption) {
      setState(() {
        _isEditingCaption = false;
      });
      return;
    }

    setState(() {
      _isSavingCaption = true;
    });

    final provider = context.read<SecretMediaProvider>();
    final success = await provider.updateCaption(widget.media.id!, newCaption);

    if (mounted) {
      setState(() {
        _isSavingCaption = false;
        if (success) {
          _currentCaption = newCaption.isEmpty ? null : newCaption;
          _isEditingCaption = false;
          SnackbarHelper.showSuccess(context, 'Caption updated');
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
          if (_isUploader)
            PopupMenuButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              itemBuilder: (BuildContext context) => [
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
                        SnackbarHelper.showSuccess(context, 'Media deleted');
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
                  ? _buildImagePreview()
                  : _buildVideoPlayer(),
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
                                    color: Colors.blue.withValues(alpha: 0.3),
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
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.3),
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
                                ),
                                const SizedBox(width: 8),
                                if (widget.media.isEncrypted)
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.3),
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
                      if (_isUploader && !_isEditingCaption)
                        IconButton(
                          onPressed: _startEditingCaption,
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!_isUploader)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Only the uploader can edit this description.',
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (_isUploader && _isEditingCaption)
                    Column(
                      children: [
                        AppTextField(
                          controller: _captionController,
                          focusNode: _captionFocusNode,
                          autofocus: true,
                          maxLines: 4,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          hintText: 'Add a caption...',
                          borderRadius: BorderRadius.circular(14),
                          isDark: true,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                _captionController.text = _currentCaption ?? '';
                                _captionFocusNode.unfocus();
                                setState(() {
                                  _isEditingCaption = false;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white54),
                                foregroundColor: Colors.white70,
                              ),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: _isSavingCaption ? null : _saveCaption,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
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
                        _currentCaption?.isNotEmpty ?? false
                            ? _currentCaption!
                            : 'No caption',
                        style: GoogleFonts.poppins(
                          color: _currentCaption?.isNotEmpty ?? false
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

  Widget _buildImagePreview() {
    return SizedBox(
      height: 400,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              widget.media.mediaUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
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
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                );
              },
            ),
          ),
          if (_isImageMasked)
            Positioned.fill(
              child: Container(
                color: Colors.black,
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: Colors.redAccent,
                    elevation: 6,
                    shadowColor: Colors.black54,
                    shape: const CircleBorder(
                      side: BorderSide(color: Colors.white24, width: 1),
                    ),
                    child: IconButton(
                      tooltip: 'Full View',
                      icon: const Icon(Icons.fullscreen, color: Colors.white),
                      onPressed: _showFullImageViewer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: Colors.black87,
                    elevation: 6,
                    shadowColor: Colors.black54,
                    shape: const CircleBorder(
                      side: BorderSide(color: Colors.white24, width: 1),
                    ),
                    child: IconButton(
                      tooltip: _isImageMasked ? 'Show Image' : 'Hide Image',
                      icon: Icon(
                        _isImageMasked
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _isImageMasked = !_isImageMasked;
                        });
                      },
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

  void _showFullImageViewer() {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(
                    widget.media.mediaUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
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
                        color: Colors.black,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoPlayer() {
    if (_videoError != null) {
      return Container(
        height: 400,
        color: Colors.grey.shade900,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _videoError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    final initializeFuture = _videoInitializeFuture;
    final controller = _videoController;
    if (initializeFuture == null || controller == null) {
      return Container(
        height: 400,
        color: Colors.grey.shade900,
      );
    }

    return FutureBuilder<void>(
      future: initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            height: 400,
            color: Colors.grey.shade900,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        return Container(
          height: 400,
          color: Colors.black,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _showVideoControls = !_showVideoControls;
              });
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
                if (_showVideoControls)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              if (controller.value.isPlaying) {
                                controller.pause();
                              } else {
                                controller.play();
                              }
                            });
                          },
                          icon: Icon(
                            controller.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_showVideoControls)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      icon: const Icon(Icons.fullscreen, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SecretMediaFullscreenVideoScreen(
                              title: _currentCaption?.isNotEmpty == true
                                  ? _currentCaption!
                                  : 'Video',
                              videoUrl: widget.media.mediaUrl,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showConfirmDialog(
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    HapticFeedback.heavyImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1C1427) : Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5252), Color(0xFFD81B60)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
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
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF758C), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFFFF758C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF5252), Color(0xFFD81B60)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onConfirm();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SecretMediaFullscreenVideoScreen extends StatefulWidget {
  final String title;
  final String videoUrl;

  const SecretMediaFullscreenVideoScreen({
    super.key,
    required this.title,
    required this.videoUrl,
  });

  @override
  State<SecretMediaFullscreenVideoScreen> createState() =>
      _SecretMediaFullscreenVideoScreenState();
}

class _SecretMediaFullscreenVideoScreenState
    extends State<SecretMediaFullscreenVideoScreen> {
  VideoPlayerController? _controller;
  Future<void>? _initFuture;
  bool _showVideoControls = false;
  bool _isLandscapeMode = false;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _toggleLandscapeMode() async {
    final nextMode = !_isLandscapeMode;

    setState(() {
      _isLandscapeMode = nextMode;
    });

    await SystemChrome.setPreferredOrientations(
      nextMode
          ? [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : [
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ],
    );
  }

  @override
  void initState() {
    super.initState();
    final controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller = controller;
    _initFuture = controller.initialize().then((_) {
      if (!mounted) return;
      controller.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
      setState(() {});
      controller.play();
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    );
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initFuture = _initFuture;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: Text(widget.title),
      ),
      body: controller == null || initFuture == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : FutureBuilder<void>(
              future: initFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                return Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _showVideoControls = !_showVideoControls;
                      });
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: controller.value.aspectRatio,
                          child: VideoPlayer(controller),
                        ),
                        if (_showVideoControls)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 12,
                            child: SafeArea(
                              minimum: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 3,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 7,
                                      ),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                        overlayRadius: 14,
                                      ),
                                      activeTrackColor: Colors.white,
                                      inactiveTrackColor: Colors.white30,
                                      thumbColor: Colors.white,
                                    ),
                                    child: Slider(
                                      value: controller
                                              .value.position.inMilliseconds
                                              .clamp(
                                                0,
                                                controller.value.duration
                                                    .inMilliseconds,
                                              )
                                              .toDouble() /
                                          (controller
                                              .value.duration.inMilliseconds
                                              .clamp(
                                                  1, double.maxFinite.toInt())
                                              .toDouble()),
                                      onChanged: controller.value.duration
                                                  .inMilliseconds ==
                                              0
                                          ? null
                                          : (value) {
                                              final targetPosition = Duration(
                                                milliseconds: (controller
                                                            .value
                                                            .duration
                                                            .inMilliseconds *
                                                        value)
                                                    .round(),
                                              );
                                              controller.seekTo(targetPosition);
                                            },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDuration(
                                              controller.value.position),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          _formatDuration(
                                              controller.value.duration),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(32),
                                        ),
                                        child: IconButton(
                                          onPressed: _toggleLandscapeMode,
                                          icon: Icon(
                                            _isLandscapeMode
                                                ? Icons.screen_rotation
                                                : Icons.stay_current_landscape,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(32),
                                        ),
                                        child: IconButton(
                                          onPressed: () {
                                            setState(() {
                                              if (controller.value.isPlaying) {
                                                controller.pause();
                                              } else {
                                                controller.play();
                                              }
                                            });
                                          },
                                          icon: Icon(
                                            controller.value.isPlaying
                                                ? Icons.pause_circle_filled
                                                : Icons.play_circle_fill,
                                            size: 36,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
}
