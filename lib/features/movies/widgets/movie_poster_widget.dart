import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';

/// Reusable Movie Poster Widget with support for Network URLs, Base64 Data URIs,
/// Local Files, romantic gradient fallback placeholders, and interactive Full Screen Zoom.
class MoviePosterWidget extends StatelessWidget {
  final String? posterUrl;
  final File? localFile;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final bool showShadow;
  final bool enableZoomOnTap;
  final String? title;
  final String? year;
  final String? date;
  final String? notes;

  const MoviePosterWidget({
    super.key,
    this.posterUrl,
    this.localFile,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.showShadow = true,
    this.enableZoomOnTap = true,
    this.title,
    this.year,
    this.date,
    this.notes,
  });

  bool get _isDataUri =>
      posterUrl != null && posterUrl!.startsWith('data:image/');

  bool get _isNetworkUrl =>
      posterUrl != null &&
      (posterUrl!.startsWith('http://') || posterUrl!.startsWith('https://'));

  bool get _hasValidImage =>
      _isNetworkUrl || _isDataUri || (localFile != null && localFile!.existsSync());

  /// Open high-resolution full-screen pinch-to-zoom viewer with description button in header
  static void showPosterZoom(
    BuildContext context, {
    String? posterUrl,
    File? localFile,
    String? title,
    String? year,
    String? date,
    String? notes,
  }) {
    if ((posterUrl == null || posterUrl.trim().isEmpty) &&
        (localFile == null || !localFile.existsSync())) {
      return;
    }

    HapticFeedback.lightImpact();
    final hasNotes = notes != null && notes.trim().isNotEmpty;
    bool showDescriptionOverlay = false;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            Widget bigImage;
            if (localFile != null && localFile.existsSync()) {
              bigImage = Image.file(
                localFile,
                fit: BoxFit.contain,
              );
            } else if (posterUrl != null && posterUrl.startsWith('data:image/')) {
              try {
                final base64Data = posterUrl.split(',').last;
                final bytes = base64Decode(base64Data);
                bigImage = Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                );
              } catch (_) {
                bigImage = const Center(
                  child: Icon(Icons.broken_image_rounded, color: Colors.white60, size: 48),
                );
              }
            } else if (posterUrl != null &&
                (posterUrl.startsWith('http://') || posterUrl.startsWith('https://'))) {
              bigImage = CachedNetworkImage(
                imageUrl: posterUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFFFF758C),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.broken_image_rounded, color: Colors.white60, size: 48),
                ),
              );
            } else {
              return const SizedBox.shrink();
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Zoomable Interactive Image
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.5,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(dialogCtx).size.width * 0.94,
                            maxHeight: MediaQuery.of(dialogCtx).size.height * 0.82,
                          ),
                          child: bigImage,
                        ),
                      ),
                    ),
                  ),

                  // Floating Description Card Overlay (if toggled on)
                  if (showDescriptionOverlay)
                    Positioned(
                      top: 68,
                      left: 6,
                      right: 6,
                      child: Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(dialogCtx).size.height * 0.55,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1428).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFF758C).withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.description_rounded,
                                        size: 16,
                                        color: Color(0xFFFF758C),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Movie Description',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setDialogState(() {
                                        showDescriptionOverlay = false;
                                      });
                                    },
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white70,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                hasNotes
                                    ? notes.trim()
                                    : 'No description or synopsis added for this movie.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.45,
                                  color: hasNotes ? Colors.white : Colors.white60,
                                  fontStyle: hasNotes ? FontStyle.normal : FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Floating Header Bar matched to Jayienne Link romantic theme
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E162B).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF758C).withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Gradient Icon Container
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.movie_filter_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Movie Title with Year only (no dates)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title != null && title.trim().isNotEmpty
                                      ? title.trim()
                                      : 'Movie Poster',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (year != null && year.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1.5),
                                    child: Text(
                                      year.trim(),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFFF758C),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Description Button in Header
                          InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setDialogState(() {
                                showDescriptionOverlay = !showDescriptionOverlay;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4.5,
                              ),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: showDescriptionOverlay
                                    ? const Color(0xFFFF758C)
                                    : const Color(0xFFFF758C).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFFF758C).withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 13,
                                    color: showDescriptionOverlay
                                        ? Colors.white
                                        : const Color(0xFFFF758C),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Description',
                                    style: TextStyle(
                                      color: showDescriptionOverlay
                                          ? Colors.white
                                          : const Color(0xFFFF758C),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Romantic Circular Close Button
                          InkWell(
                            onTap: () => Navigator.pop(dialogCtx),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 17,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom hint
                  Positioned(
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E162B).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFA18CD1).withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in_rounded, size: 13, color: Color(0xFFFF758C)),
                          SizedBox(width: 5),
                          Text(
                            'Pinch or drag to zoom & explore',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(16);

    Widget imageContent;

    if (localFile != null && localFile!.existsSync()) {
      imageContent = Image.file(
        localFile!,
        width: width,
        height: height,
        fit: fit,
      );
    } else if (_isDataUri) {
      try {
        final base64Data = posterUrl!.split(',').last;
        final bytes = base64Decode(base64Data);
        imageContent = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      } catch (_) {
        imageContent = _buildPlaceholder();
      }
    } else if (_isNetworkUrl) {
      imageContent = CachedNetworkImage(
        imageUrl: posterUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF758C).withValues(alpha: 0.3),
                const Color(0xFFA18CD1).withValues(alpha: 0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.softRose,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    } else {
      imageContent = _buildPlaceholder();
    }

    final posterContainer = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: imageContent,
      ),
    );

    if (enableZoomOnTap && _hasValidImage) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showPosterZoom(
            context,
            posterUrl: posterUrl,
            localFile: localFile,
            title: title,
            year: year,
            date: date,
            notes: notes,
          ),
          borderRadius: effectiveRadius,
          child: posterContainer,
        ),
      );
    }

    return posterContainer;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFF758C),
            Color(0xFFA18CD1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_creation_rounded,
            color: Colors.white.withValues(alpha: 0.9),
            size: (width != null && width! < 70) ? 22 : 36,
          ),
          if (width == null || width! >= 70) ...[
            const SizedBox(height: 6),
            Text(
              'Cinema',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
