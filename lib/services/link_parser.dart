import 'dart:convert';
import 'package:elysian/models/models.dart';
import 'package:http/http.dart' as http;

class LinkParser {
  static LinkType? parseLinkType(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final scheme = uri.scheme.toLowerCase();
    
    // YouTube
    if (host.contains('youtube.com') || host.contains('youtu.be')) {
      return LinkType.youtube;
    }

    // Instagram
    if (host.contains('instagram.com')) {
      return LinkType.instagram;
    }

    // Vimeo
    if (host.contains('vimeo.com')) {
      return LinkType.vimeo;
    }

    // Google Drive
    if (host.contains('drive.google.com') || host.contains('docs.google.com')) {
      return LinkType.googledrive;
    }

    // Direct video URLs - check file extension or content type
    if (_isDirectVideoUrl(url, path)) {
      return LinkType.directVideo;
    }

    // Generic web links (http/https)
    if (scheme == 'http' || scheme == 'https') {
      return LinkType.web;
    }
    
    return null;
  }

  /// Checks if URL is a direct video file
  static bool _isDirectVideoUrl(String url, String path) {
    final videoExtensions = [
      '.mp4',
      '.webm',
      '.ogg',
      '.ogv',
      '.m3u8',
      '.m3u',
      '.mov',
      '.avi',
      '.wmv',
      '.flv',
      '.mkv',
      '.3gp',
    ];

    final lowerUrl = url.toLowerCase();
    final lowerPath = path.toLowerCase();

    // Check file extension
    for (final ext in videoExtensions) {
      if (lowerPath.endsWith(ext) || lowerUrl.contains(ext)) {
        return true;
      }
    }

    // Check for common video URL patterns
    if (lowerUrl.contains('/video/') ||
        lowerUrl.contains('/stream/') ||
        lowerUrl.contains('.m3u8') ||
        lowerUrl.contains('.m3u')) {
      return true;
    }

    return false;
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
        } else if (pathSegments.length == 1 &&
            pathSegments[0] != 'p' &&
            pathSegments[0] != 'reel') {
          return pathSegments[0];
        }
      }
    }

    return null;
  }

  static bool isValidLink(String url) {
    final type = parseLinkType(url);
    return type != null && type != LinkType.unknown;
  }

  /// Extracts Vimeo video ID from URL
  static String? extractVimeoVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    if (uri.host.contains('vimeo.com')) {
      // Vimeo URLs are typically: https://vimeo.com/VIDEO_ID
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        return pathSegments.first;
      }
    }

    return null;
  }

  /// Extracts Google Drive file ID from URL
  static String? extractGoogleDriveFileId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    if (uri.host.contains('drive.google.com')) {
      // Google Drive URLs: https://drive.google.com/file/d/FILE_ID/view
      final pathSegments = uri.pathSegments;
      final fileIndex = pathSegments.indexOf('d');
      if (fileIndex != -1 && fileIndex + 1 < pathSegments.length) {
        return pathSegments[fileIndex + 1];
      }

      // Alternative format: ?id=FILE_ID
      return uri.queryParameters['id'];
    }

    if (uri.host.contains('docs.google.com')) {
      // Google Docs viewer format
      return uri.queryParameters['id'];
    }

    return null;
  }

  /// Checks if URL is a direct playable video URL
  static bool isDirectPlayableVideo(String url) {
    final type = parseLinkType(url);
    return type == LinkType.directVideo;
  }

  /// Generates a default title from URL (synchronous, for fallback)
  static String generateTitleFromUrl(String url, LinkType type) {
    switch (type) {
      case LinkType.youtube:
        final videoId = extractYouTubeVideoId(url);
        return videoId != null ? 'YouTube Video' : 'YouTube Link';
      case LinkType.instagram:
        return 'Instagram Post';
      case LinkType.vimeo:
        return 'Vimeo Video';
      case LinkType.googledrive:
        return 'Google Drive Video';
      case LinkType.directVideo:
        return 'Video';
      case LinkType.web:
        return 'Web Link';
      case LinkType.unknown:
        return 'Shared Link';
    }
  }

  /// Fetches the actual title from the URL (async)
  static Future<String> fetchTitleFromUrl(String url, LinkType type) async {
    try {
      switch (type) {
        case LinkType.youtube:
          return await _fetchYouTubeTitle(url);
        case LinkType.instagram:
          return await _fetchInstagramTitle(url);
        case LinkType.vimeo:
          return await _fetchVimeoTitle(url);
        case LinkType.googledrive:
          return await _fetchGoogleDriveTitle(url);
        case LinkType.directVideo:
        case LinkType.web:
          return await _fetchWebTitle(url);
        case LinkType.unknown:
          return 'Shared Link';
      }
    } catch (e) {
      // Fallback to default title on error
      return generateTitleFromUrl(url, type);
    }
  }

  /// Fetches Vimeo video title
  static Future<String> _fetchVimeoTitle(String url) async {
    try {
      final videoId = extractVimeoVideoId(url);
      if (videoId == null) {
        return 'Vimeo Video';
      }

      final oEmbedUrl = Uri.parse('https://vimeo.com/api/oembed.json?url=$url');

      final response = await http
          .get(oEmbedUrl)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final title = data['title'] as String?;
        if (title != null && title.isNotEmpty) {
          return title;
        }
      }

      return 'Vimeo Video';
    } catch (e) {
      return 'Vimeo Video';
    }
  }

  /// Fetches Google Drive file title
  static Future<String> _fetchGoogleDriveTitle(String url) async {
    try {
      // Google Drive doesn't have a public API for fetching titles without auth
      // We'll try to extract from the page HTML as fallback
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final html = response.body;

        // Try to extract title from og:title or <title>
        final ogTitleMatch = RegExp(
          r'<meta\s+property="og:title"\s+content="([^"]+)"',
          caseSensitive: false,
        ).firstMatch(html);

        if (ogTitleMatch != null) {
          final title = ogTitleMatch.group(1)!;
          if (title.isNotEmpty) {
            return title.trim();
          }
        }

        final titleMatch = RegExp(
          r'<title[^>]*>([^<]+)</title>',
          caseSensitive: false,
        ).firstMatch(html);

        if (titleMatch != null) {
          String title = titleMatch.group(1)!;
          title = title.replaceAll(
            RegExp(r'\s*-\s*Google\s+Drive\s*$', caseSensitive: false),
            '',
          );
          if (title.isNotEmpty) {
            return title.trim();
          }
        }
      }

      return 'Google Drive Video';
    } catch (e) {
      return 'Google Drive Video';
    }
  }

  /// Fetches web page title
  static Future<String> _fetchWebTitle(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final html = response.body;

        // Try og:title first
        final ogTitleMatch = RegExp(
          r'<meta\s+property="og:title"\s+content="([^"]+)"',
          caseSensitive: false,
        ).firstMatch(html);

        if (ogTitleMatch != null) {
          final title = ogTitleMatch.group(1)!;
          if (title.isNotEmpty) {
            return title.trim();
          }
        }

        // Fallback to <title>
        final titleMatch = RegExp(
          r'<title[^>]*>([^<]+)</title>',
          caseSensitive: false,
        ).firstMatch(html);

        if (titleMatch != null) {
          String title = titleMatch.group(1)!;
          if (title.isNotEmpty) {
            return title.trim();
          }
        }
      }

      return 'Web Link';
    } catch (e) {
      return 'Web Link';
    }
  }

  /// Extracts direct video URL from Vimeo link
  static Future<String?> extractVimeoVideoUrl(String url) async {
    try {
      final videoId = extractVimeoVideoId(url);
      if (videoId == null) return null;

      // Try Vimeo oEmbed API to get video info
      final oEmbedUrl = Uri.parse('https://vimeo.com/api/oembed.json?url=$url');

      final response = await http
          .get(oEmbedUrl)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        // Vimeo oEmbed doesn't provide direct video URL, but we can construct it
        // For now, return the original URL with video_player
        // The video_player package can handle vimeo.com URLs in some cases
        return url;
      }
    } catch (e) {
      // Fallback to original URL
    }
    return url;
  }

  /// Extracts direct video URL from Google Drive link
  static String? extractGoogleDriveVideoUrl(String url) {
    try {
      final fileId = extractGoogleDriveFileId(url);
      if (fileId == null) return null;

      // Construct direct video URL for Google Drive
      // Format: https://drive.google.com/uc?export=download&id=FILE_ID
      // For video playback: https://drive.google.com/file/d/FILE_ID/preview
      return 'https://drive.google.com/file/d/$fileId/preview';
    } catch (e) {
      return null;
    }
  }

  /// Fetches YouTube video duration
  static Future<String?> fetchYouTubeDuration(String url) async {
    try {
      final videoId = extractYouTubeVideoId(url);
      if (videoId == null) return null;

      // Fetch the page and extract duration from HTML
      final pageResponse = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (pageResponse.statusCode == 200) {
        final html = pageResponse.body;
        
        // Try to extract duration from meta tag
        final durationMatch = RegExp(
          r'"lengthSeconds":"(\d+)"',
          caseSensitive: false,
        ).firstMatch(html);
        
        if (durationMatch != null) {
          final seconds = int.tryParse(durationMatch.group(1)!);
          if (seconds != null) {
            return _formatDuration(seconds);
          }
        }
        
        // Alternative: try to find in videoDetails
        final videoDetailsMatch = RegExp(
          r'"videoDetails":\{[^}]*"lengthSeconds":"(\d+)"',
          caseSensitive: false,
        ).firstMatch(html);
        
        if (videoDetailsMatch != null) {
          final seconds = int.tryParse(videoDetailsMatch.group(1)!);
          if (seconds != null) {
            return _formatDuration(seconds);
          }
        }
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }

  /// Formats seconds into readable duration (e.g., "10:30", "1h 5m")
  static String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final secs = seconds % 60;
      return secs > 0 ? '$minutes:${secs.toString().padLeft(2, '0')}' : '${minutes}m';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      }
      return '${hours}h';
    }
  }

  /// Fetches YouTube video title
  static Future<String> _fetchYouTubeTitle(String url) async {
    try {
      // Try oEmbed API first (simpler and more reliable)
      final videoId = extractYouTubeVideoId(url);
      if (videoId == null) {
        return 'YouTube Link';
      }

      final oEmbedUrl = Uri.parse(
        'https://www.youtube.com/oembed?url=$url&format=json',
      );

      final response = await http
          .get(oEmbedUrl)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final title = data['title'] as String?;
        if (title != null && title.isNotEmpty) {
          return title;
        }
      }

      // Fallback: fetch the page and extract title from HTML
      final pageResponse = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (pageResponse.statusCode == 200) {
        final html = pageResponse.body;
        // Extract title from <title> tag
        final titleMatch = RegExp(
          r'<title[^>]*>([^<]+)</title>',
          caseSensitive: false,
        ).firstMatch(html);
        if (titleMatch != null) {
          String title = titleMatch.group(1)!;
          // Clean up YouTube title (remove " - YouTube" suffix)
          title = title.replaceAll(
            RegExp(r'\s*-\s*YouTube\s*$', caseSensitive: false),
            '',
          );
          if (title.isNotEmpty) {
            return title.trim();
          }
        }
      }

      return 'YouTube Video';
    } catch (e) {
      return 'YouTube Video';
    }
  }

  /// Fetches Instagram post title
  static Future<String> _fetchInstagramTitle(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final html = response.body;

        // Try to extract title from og:title meta tag (try both single and double quotes)
        RegExpMatch? ogTitleMatch = RegExp(
          r'<meta\s+property="og:title"\s+content="([^"]+)"',
          caseSensitive: false,
        ).firstMatch(html);

        if (ogTitleMatch == null) {
          ogTitleMatch = RegExp(
            r"<meta\s+property='og:title'\s+content='([^']+)'",
            caseSensitive: false,
          ).firstMatch(html);
        }

        if (ogTitleMatch != null) {
          final title = ogTitleMatch.group(1)!;
          if (title.isNotEmpty) {
            return title.trim();
          }
        }

        // Fallback: extract from <title> tag
        final titleMatch = RegExp(
          r'<title[^>]*>([^<]+)</title>',
          caseSensitive: false,
        ).firstMatch(html);
        if (titleMatch != null) {
          String title = titleMatch.group(1)!;
          // Clean up Instagram title (remove " on Instagram" suffix)
          title = title.replaceAll(
            RegExp(r'\s*on\s+Instagram\s*$', caseSensitive: false),
            '',
          );
          if (title.isNotEmpty) {
            return title.trim();
          }
        }
      }

      return 'Instagram Post';
    } catch (e) {
      return 'Instagram Post';
    }
  }

  /// Fetches enhanced metadata from URL (thumbnail, description, etc.)
  static Future<Map<String, String?>> fetchMetadataFromUrl(String url, LinkType type) async {
    final metadata = <String, String?>{
      'thumbnailUrl': null,
      'description': null,
    };

    try {
      switch (type) {
        case LinkType.youtube:
          final videoId = extractYouTubeVideoId(url);
          if (videoId != null) {
            metadata['thumbnailUrl'] = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
            // Try to fetch description from YouTube
            try {
              final response = await http
                  .get(Uri.parse(url))
                  .timeout(const Duration(seconds: 5));
              if (response.statusCode == 200) {
                final html = response.body;
                // Extract og:description
                final ogDescMatch = RegExp(
                  r'<meta\s+property="og:description"\s+content="([^"]+)"',
                  caseSensitive: false,
                ).firstMatch(html);
                if (ogDescMatch != null) {
                  metadata['description'] = ogDescMatch.group(1)?.trim();
                }
              }
            } catch (e) {
              // Silently fail
            }
          }
          break;
        case LinkType.instagram:
          // Try to extract og:image and og:description
          try {
            final response = await http
                .get(Uri.parse(url))
                .timeout(const Duration(seconds: 5));
            if (response.statusCode == 200) {
              final html = response.body;
              
              // Extract og:image
              RegExpMatch? ogImageMatch = RegExp(
                r'<meta\s+property="og:image"\s+content="([^"]+)"',
                caseSensitive: false,
              ).firstMatch(html);
              if (ogImageMatch == null) {
                ogImageMatch = RegExp(
                  r"<meta\s+property='og:image'\s+content='([^']+)'",
                  caseSensitive: false,
                ).firstMatch(html);
              }
              if (ogImageMatch != null) {
                metadata['thumbnailUrl'] = ogImageMatch.group(1)?.trim();
              }

              // Extract og:description
              RegExpMatch? ogDescMatch = RegExp(
                r'<meta\s+property="og:description"\s+content="([^"]+)"',
                caseSensitive: false,
              ).firstMatch(html);
              if (ogDescMatch == null) {
                ogDescMatch = RegExp(
                  r"<meta\s+property='og:description'\s+content='([^']+)'",
                  caseSensitive: false,
                ).firstMatch(html);
              }
              if (ogDescMatch != null) {
                metadata['description'] = ogDescMatch.group(1)?.trim();
              }
            }
          } catch (e) {
            // Silently fail
          }
          break;
        case LinkType.vimeo:
          try {
            final videoId = extractVimeoVideoId(url);
            if (videoId != null) {
              final oEmbedUrl = Uri.parse('https://vimeo.com/api/oembed.json?url=$url');
              final response = await http
                  .get(oEmbedUrl)
                  .timeout(const Duration(seconds: 5));
              if (response.statusCode == 200) {
                final data = jsonDecode(response.body) as Map<String, dynamic>;
                metadata['thumbnailUrl'] = data['thumbnail_url'] as String?;
                metadata['description'] = data['description'] as String?;
              }
            }
          } catch (e) {
            // Silently fail
          }
          break;
        case LinkType.web:
        case LinkType.googledrive:
        case LinkType.directVideo:
          // Extract og:image and og:description from web pages
          try {
            final response = await http
                .get(Uri.parse(url))
                .timeout(const Duration(seconds: 5));
            if (response.statusCode == 200) {
              final html = response.body;
              
              // Extract og:image
              RegExpMatch? ogImageMatch = RegExp(
                r'<meta\s+property="og:image"\s+content="([^"]+)"',
                caseSensitive: false,
              ).firstMatch(html);
              if (ogImageMatch == null) {
                ogImageMatch = RegExp(
                  r"<meta\s+property='og:image'\s+content='([^']+)'",
                  caseSensitive: false,
                ).firstMatch(html);
              }
              if (ogImageMatch != null) {
                metadata['thumbnailUrl'] = ogImageMatch.group(1)?.trim();
              }

              // Extract og:description
              RegExpMatch? ogDescMatch = RegExp(
                r'<meta\s+property="og:description"\s+content="([^"]+)"',
                caseSensitive: false,
              ).firstMatch(html);
              if (ogDescMatch == null) {
                ogDescMatch = RegExp(
                  r"<meta\s+property='og:description'\s+content='([^']+)'",
                  caseSensitive: false,
                ).firstMatch(html);
              }
              if (ogDescMatch != null) {
                metadata['description'] = ogDescMatch.group(1)?.trim();
              } else {
                // Fallback to meta description
                final metaDescMatch = RegExp(
                  r'<meta\s+name="description"\s+content="([^"]+)"',
                  caseSensitive: false,
                ).firstMatch(html);
                if (metaDescMatch != null) {
                  metadata['description'] = metaDescMatch.group(1)?.trim();
                }
              }
            }
          } catch (e) {
            // Silently fail
          }
          break;
        case LinkType.unknown:
          break;
      }
    } catch (e) {
      // Return empty metadata on error
    }

    return metadata;
  }
}
