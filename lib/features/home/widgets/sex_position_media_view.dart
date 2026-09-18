import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../models/sex_position_model.dart';

/// Interactive media viewer for a sex position.
/// Displays an animated demonstration video (looping, muted) if available,
/// with an instant toggle to switch between the animated motion and the high-res illustration.
class SexPositionMediaView extends StatefulWidget {
  final SexPositionModel position;
  final double height;
  final bool isDark;
  final bool autoPlay;
  final double borderRadius;

  const SexPositionMediaView({
    super.key,
    required this.position,
    this.height = 340,
    required this.isDark,
    this.autoPlay = true,
    this.borderRadius = 20,
  });

  @override
  State<SexPositionMediaView> createState() => _SexPositionMediaViewState();
}

class _SexPositionMediaViewState extends State<SexPositionMediaView> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showAnimation = true;

  @override
  void initState() {
    super.initState();
    _initVideoIfAvailable();
  }

  @override
  void didUpdateWidget(covariant SexPositionMediaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position.animationUrl != widget.position.animationUrl) {
      _disposeVideo();
      _initVideoIfAvailable();
    }
  }

  void _disposeVideo() {
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    _isInitialized = false;
    _hasError = false;
  }

  void _initVideoIfAvailable() {
    if (!widget.position.hasAnimation) {
      return;
    }

    try {
      final uri = Uri.parse(widget.position.animationUrl);
      final controller = VideoPlayerController.networkUrl(uri);
      _videoController = controller;

      controller.initialize().then((_) {
        if (!mounted) return;
        controller.setLooping(true);
        controller.setVolume(0.0);
        if (widget.autoPlay && _showAnimation) {
          controller.play();
        }
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      });
    } catch (_) {
      setState(() {
        _hasError = true;
        _isInitialized = false;
      });
    }
  }

  void _toggleAnimation() {
    HapticFeedback.selectionClick();
    setState(() {
      _showAnimation = !_showAnimation;
      if (_videoController != null && _isInitialized) {
        if (_showAnimation) {
          _videoController!.play();
        } else {
          _videoController!.pause();
        }
      }
    });
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasAnim = widget.position.hasAnimation && !_hasError;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Container(
        width: double.infinity,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF261D33) : const Color(0xFFF9F6FA),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFFF758C).withValues(alpha: 0.2),
            width: 1.2,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Layer 1: Static Image or Fallback
            if (!_showAnimation || !hasAnim || !_isInitialized)
              _buildStaticImage(),

            // Layer 2: Animated Looping Video (when active & initialized)
            if (hasAnim && _showAnimation && _isInitialized && _videoController != null)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _videoController!.value.size.width > 0
                        ? _videoController!.value.size.width
                        : 300,
                    height: _videoController!.value.size.height > 0
                        ? _videoController!.value.size.height
                        : 300,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              ),

            // Layer 3: Loading Indicator while video initializes
            if (hasAnim && _showAnimation && !_isInitialized && !_hasError)
              Positioned(
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: Color(0xFFFF758C),
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Loading animation...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Layer 4: Animation Badge & Toggle Button (Top Right)
            if (hasAnim)
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: _toggleAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: _showAnimation
                          ? const LinearGradient(
                              colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: _showAnimation
                          ? null
                          : (widget.isDark
                              ? Colors.black.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.85)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _showAnimation
                            ? Colors.white.withValues(alpha: 0.3)
                            : const Color(0xFFFF758C).withValues(alpha: 0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showAnimation
                              ? Icons.pause_circle_outline_rounded
                              : Icons.play_circle_fill_rounded,
                          size: 14,
                          color: _showAnimation
                              ? Colors.white
                              : const Color(0xFFFF758C),
                        ),
                        const SizedBox(width: 4.5),
                        Text(
                          _showAnimation ? 'Motion' : 'Static',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _showAnimation
                                ? Colors.white
                                : (widget.isDark ? Colors.white : const Color(0xFF333333)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticImage() {
    if (widget.position.imageUrl.isEmpty) {
      return Center(
        child: Icon(
          Icons.favorite_outline_rounded,
          size: 48,
          color: widget.isDark ? Colors.white30 : Colors.grey.shade400,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: widget.position.imageUrl,
      fit: BoxFit.contain,
      placeholder: (_, __) => const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFFFF758C),
        ),
      ),
      errorWidget: (_, __, ___) => Center(
        child: Icon(
          Icons.favorite_outline_rounded,
          size: 48,
          color: widget.isDark ? Colors.white30 : Colors.grey.shade400,
        ),
      ),
    );
  }
}
