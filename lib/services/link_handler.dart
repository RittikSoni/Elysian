import 'package:elysian/models/models.dart';
import 'package:elysian/services/link_parser.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/utils/kroute.dart';
import 'package:elysian/screens/video_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkHandler {
  /// Handles opening a link - always goes through detail page first
  static Future<void> openLink(
    BuildContext context,
    String url, {
    LinkType? linkType,
    String? title,
    String? description,
    String? linkId, // Optional link ID to track views
    SavedLink? savedLink, // Optional SavedLink object
  }) async {
    // Determine link type if not provided
    final type = linkType ?? LinkParser.parseLinkType(url);

    if (type == null) {
      // Unknown link type, open externally
      await _openExternally(url);
      return;
    }

    // Try to get SavedLink if not provided
    SavedLink? link = savedLink;
    if (link == null) {
      try {
        final allLinks = await StorageService.getSavedLinks();
        link = allLinks.firstWhere((l) => l.url == url);
      } catch (e) {
        // Link not found in saved links, create a temporary one
        link = SavedLink(
          id: linkId ?? DateTime.now().millisecondsSinceEpoch.toString(),
          url: url,
          title: title ?? 'Video',
          description: description,
          type: type,
          listIds: [StorageService.defaultListId],
          savedAt: DateTime.now(),
        );
      }
    }

    // Track view
    if (link.id.isNotEmpty) {
      await StorageService.recordLinkView(link.id);
    }

    // Always navigate to detail page first
    Navigator.push(
      navigatorKey.currentContext!,
      MaterialPageRoute(builder: (context) => VideoDetailScreen(link: link!)),
    );
  }

  /// Opens link in inbuilt player with fallback to external (kept for backward compatibility)
  // @Deprecated('Use openLink which navigates to detail page')
  // static Future<void> _openInbuilt(
  //   BuildContext context,
  //   String url,
  //   LinkType type, {
  //   String? title,
  //   String? description,
  // }) async {
  //   try {
  //     switch (type) {
  //       case LinkType.youtube:
  //         final videoId = LinkParser.extractYouTubeVideoId(url);
  //         if (videoId != null) {
  //           Navigator.push(
  //             context,
  //             MaterialPageRoute(
  //               builder: (context) => YTFull(
  //                 videoId: videoId,
  //                 title: title,
  //                 description: description,
  //               ),
  //             ),
  //           );
  //         } else {
  //           // Fallback to external if video ID can't be extracted
  //           await _openExternally(url);
  //         }
  //         break;

  //       case LinkType.directVideo:
  //         // Direct video URLs - use video player
  //         Navigator.push(
  //           context,
  //           MaterialPageRoute(
  //             builder: (context) => RSNewVideoPlayerScreen(
  //               mediaUrl: url,
  //               onError: () => _openExternally(url),
  //             ),
  //           ),
  //         );
  //         break;

  //       case LinkType.vimeo:
  //         // Try to play Vimeo in inbuilt player
  //         // Vimeo URLs can sometimes be played directly with video_player
  //         try {
  //           Navigator.push(
  //             context,
  //             MaterialPageRoute(
  //               builder: (context) => RSNewVideoPlayerScreen(
  //                 mediaUrl: url,
  //                 onError: () => _openExternally(url),
  //               ),
  //             ),
  //           );
  //         } catch (e) {
  //           // If inbuilt player fails, fallback to external
  //           await _openExternally(url);
  //         }
  //         break;

  //       case LinkType.googledrive:
  //         // Try to extract direct video URL for Google Drive
  //         final videoUrl = LinkParser.extractGoogleDriveVideoUrl(url);
  //         if (videoUrl != null) {
  //           try {
  //             Navigator.push(
  //               context,
  //               MaterialPageRoute(
  //                 builder: (context) => RSNewVideoPlayerScreen(
  //                   mediaUrl: videoUrl,
  //                   onError: () => _openExternally(url),
  //                 ),
  //               ),
  //             );
  //           } catch (e) {
  //             // If inbuilt player fails, fallback to external
  //             await _openExternally(url);
  //           }
  //         } else {
  //           // Can't extract video URL, use external
  //           await _openExternally(url);
  //         }
  //         break;

  //       case LinkType.instagram:
  //       case LinkType.web:
  //         // These platforms don't support inbuilt player well
  //         // Redirect to external app
  //         await _openExternally(url);
  //         break;

  //       case LinkType.unknown:
  //         // Try as direct video URL first
  //         if (LinkParser.isDirectPlayableVideo(url)) {
  //           try {
  //             Navigator.push(
  //               context,
  //               MaterialPageRoute(
  //                 builder: (context) => RSNewVideoPlayerScreen(
  //                   mediaUrl: url,
  //                   onError: () => _openExternally(url),
  //                 ),
  //               ),
  //             );
  //           } catch (e) {
  //             await _openExternally(url);
  //           }
  //         } else {
  //           await _openExternally(url);
  //         }
  //         break;
  //     }
  //   } catch (e) {
  //     // If anything fails, fallback to external
  //     await _openExternally(url);
  //   }
  // }

  /// Opens link in external application
  static Future<void> _openExternally(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
