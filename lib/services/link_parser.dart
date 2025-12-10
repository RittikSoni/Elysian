import 'dart:convert';
import 'package:elysian/models/models.dart';
import 'package:http/http.dart' as http;

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
    return type != null;
  }

  /// Generates a default title from URL (synchronous, for fallback)
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

  /// Fetches the actual title from the URL (async)
  static Future<String> fetchTitleFromUrl(String url, LinkType type) async {
    try {
      switch (type) {
        case LinkType.youtube:
          return await _fetchYouTubeTitle(url);
        case LinkType.instagram:
          return await _fetchInstagramTitle(url);
        case LinkType.unknown:
          return 'Shared Link';
      }
    } catch (e) {
      // Fallback to default title on error
      return generateTitleFromUrl(url, type);
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
}
