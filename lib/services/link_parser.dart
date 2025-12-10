import 'package:elysian/models/models.dart';

class LinkParser {
  static LinkType? parseLinkType(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final host = uri.host.toLowerCase();
    
    if (host.contains('youtube.com') || host.contains('youtu.be')) {
      return LinkType.youtube;
    } else if (host.contains('instagram.com')) {
      return LinkType.instagram;
    }
    
    return null;
  }

  static String? extractYouTubeVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // Handle youtu.be short links
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }

    // Handle youtube.com links
    if (uri.host.contains('youtube.com')) {
      return uri.queryParameters['v'];
    }

    return null;
  }

  static String? extractInstagramMediaId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    if (uri.host.contains('instagram.com')) {
      // Extract from path like /p/MEDIA_ID/ or /reel/MEDIA_ID/
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        // Skip 'p' or 'reel' and get the actual ID
        if (pathSegments.length > 1) {
          return pathSegments[1];
        } else if (pathSegments.length == 1 && pathSegments[0] != 'p' && pathSegments[0] != 'reel') {
          return pathSegments[0];
        }
      }
    }

    return null;
  }

  static bool isValidLink(String url) {
    final type = parseLinkType(url);
    return type != null;
  }

  static String generateTitleFromUrl(String url, LinkType type) {
    switch (type) {
      case LinkType.youtube:
        final videoId = extractYouTubeVideoId(url);
        return videoId != null ? 'YouTube Video' : 'YouTube Link';
      case LinkType.instagram:
        return 'Instagram Post';
      case LinkType.unknown:
        return 'Shared Link';
    }
  }
}

