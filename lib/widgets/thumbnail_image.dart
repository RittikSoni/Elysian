import 'dart:io';
import 'package:elysian/models/models.dart';
import 'package:flutter/material.dart';

/// A widget that displays a thumbnail from either a local file or network URL
class ThumbnailImage extends StatelessWidget {
  final SavedLink link;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const ThumbnailImage({
    super.key,
    required this.link,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Priority: customThumbnailPath > thumbnailUrl > generated URL
    final thumbnailPath = link.customThumbnailPath;
    final thumbnailUrl = link.thumbnailUrl;

    // Show placeholder while loading or if no thumbnail
    if (thumbnailPath == null && thumbnailUrl == null) {
      return placeholder ?? _defaultPlaceholder();
    }

    // Display local file thumbnail
    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      return Image.file(
        File(thumbnailPath),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? _defaultErrorWidget();
        },
      );
    }

    // Display network thumbnail with caching
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      // Only cache if width/height are finite numbers (not infinity or NaN)
      int? cacheW;
      int? cacheH;
      final w = width;
      final h = height;
      if (w != null && w.isFinite && !w.isNaN) {
        cacheW = w.toInt();
      }
      if (h != null && h.isFinite && !h.isNaN) {
        cacheH = h.toInt();
      }

      return Image.network(
        thumbnailUrl,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheW,
        cacheHeight: cacheH,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder ?? _defaultPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? _defaultErrorWidget();
        },
      );
    }

    return placeholder ?? _defaultPlaceholder();
  }

  Widget _defaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[800],
      child: Icon(
        _getIconForType(link.type),
        color: Colors.grey[600],
        size: 40,
      ),
    );
  }

  Widget _defaultErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[800],
      child: Icon(
        _getIconForType(link.type),
        color: Colors.grey[600],
        size: 40,
      ),
    );
  }

  IconData _getIconForType(LinkType type) {
    switch (type) {
      case LinkType.youtube:
        return Icons.play_circle_outline;
      case LinkType.instagram:
        return Icons.photo_outlined;
      case LinkType.vimeo:
        return Icons.play_circle_filled;
      case LinkType.googledrive:
        return Icons.cloud;
      case LinkType.directVideo:
        return Icons.video_library;
      case LinkType.web:
        return Icons.language;
      case LinkType.unknown:
        return Icons.link;
    }
  }
}
