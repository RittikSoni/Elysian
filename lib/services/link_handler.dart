import 'package:elysian/models/models.dart';
import 'package:elysian/services/link_parser.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/video_player/yt_full.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkHandler {
  /// Handles opening a link based on user's player preference
  static Future<void> openLink(
    BuildContext context,
    String url, {
    LinkType? linkType,
    String? title,
    String? description,
  }) async {
    // Determine link type if not provided
    final type = linkType ?? LinkParser.parseLinkType(url);
    
    if (type == null) {
      // Unknown link type, open externally
      await _openExternally(url);
      return;
    }

    // Check user preference
    final useInbuilt = await StorageService.isInbuiltPlayer();

    if (useInbuilt) {
      await _openInbuilt(context, url, type, title: title, description: description);
    } else {
      await _openExternally(url);
    }
  }

  /// Opens link in inbuilt player
  static Future<void> _openInbuilt(
    BuildContext context,
    String url,
    LinkType type, {
    String? title,
    String? description,
  }) async {
    switch (type) {
      case LinkType.youtube:
        final videoId = LinkParser.extractYouTubeVideoId(url);
        if (videoId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => YTFull(
                videoId: videoId,
                title: title,
                description: description,
              ),
            ),
          );
        } else {
          // Fallback to external if video ID can't be extracted
          await _openExternally(url);
        }
        break;
      case LinkType.instagram:
        // Instagram doesn't provide direct video URLs easily
        // Redirect to external app for better experience
        await _openExternally(url);
        break;
      case LinkType.unknown:
        await _openExternally(url);
        break;
    }
  }

  /// Opens link in external application
  static Future<void> _openExternally(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

