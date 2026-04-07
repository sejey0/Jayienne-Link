import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SmartProfileImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const SmartProfileImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  bool _isDataUri(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('data:image/');
  }

  bool _isNetworkUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  Uint8List? _decodeBase64Image(String dataUri) {
    try {
      // Extract base64 data from data URI
      final base64String = dataUri.split(',').last;
      return base64Decode(base64String);
    } catch (e) {
      print('Error decoding base64 image: $e');
      return null;
    }
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius,
      ),
      child: const Icon(
        Icons.person,
        color: Colors.grey,
        size: 40,
      ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius,
      ),
      child: const Icon(
        Icons.error_outline,
        color: Colors.red,
        size: 40,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectivePlaceholder = placeholder ?? _buildDefaultPlaceholder();
    final effectiveErrorWidget = errorWidget ?? _buildDefaultErrorWidget();

    // Handle empty or null URLs
    if (imageUrl == null || imageUrl!.isEmpty) {
      return effectivePlaceholder;
    }

    Widget imageWidget;

    if (_isDataUri(imageUrl!)) {
      // Handle Base64 data URI
      final imageBytes = _decodeBase64Image(imageUrl!);
      if (imageBytes != null) {
        imageWidget = Image.memory(
          imageBytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => effectiveErrorWidget,
        );
      } else {
        return effectiveErrorWidget;
      }
    } else if (_isNetworkUrl(imageUrl!)) {
      // Handle network URL
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => effectivePlaceholder,
        errorWidget: (context, url, error) => effectiveErrorWidget,
      );
    } else {
      // Fallback for other cases
      return effectiveErrorWidget;
    }

    // Apply border radius if specified
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}