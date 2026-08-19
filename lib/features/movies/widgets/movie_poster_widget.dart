import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';

/// Reusable Movie Poster Widget with support for Network URLs, Base64 Data URIs,
/// Local Files, and romantic gradient fallback placeholders.
class MoviePosterWidget extends StatelessWidget {
  final String? posterUrl;
  final File? localFile;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final bool showShadow;

  const MoviePosterWidget({
    super.key,
    this.posterUrl,
    this.localFile,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.showShadow = true,
  });

  bool get _isDataUri =>
      posterUrl != null && posterUrl!.startsWith('data:image/');

  bool get _isNetworkUrl =>
      posterUrl != null &&
      (posterUrl!.startsWith('http://') || posterUrl!.startsWith('https://'));

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

    return Container(
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
