import 'package:flutter/material.dart';
import 'package:elysian/services/watch_party_service.dart';
import 'package:elysian/models/watch_party_models.dart';
import 'package:elysian/models/models.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/services/link_parser.dart';
import 'package:elysian/video_player/yt_full.dart';
import 'package:elysian/video_player/video_player_full.dart';
import 'package:elysian/widgets/watch_party_chat_notification.dart';
import 'package:elysian/utils/kroute.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

/// Global manager for watch party that works across all screens
class WatchPartyGlobalManager {
  static final WatchPartyGlobalManager _instance = WatchPartyGlobalManager._internal();
  factory WatchPartyGlobalManager() => _instance;
  WatchPartyGlobalManager._internal();

  final _watchPartyService = WatchPartyService();
  OverlayEntry? _chatNotificationOverlay;
  ChatMessage? _currentNotificationMessage;
  Timer? _notificationTimer;

  bool _isInitialized = false;

  /// Initialize global watch party manager
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Listen for video changes - navigate to video when host starts playing
    _watchPartyService.onVideoChange = (videoUrl, videoTitle) {
      _handleVideoChange(videoUrl, videoTitle);
    };

    // Listen for room updates - check if video started
    _watchPartyService.onRoomUpdate = (room) {
      _handleRoomUpdate(room);
    };

    // Listen for chat messages - show global notification
    _watchPartyService.onChatMessage = (message) {
      _showGlobalChatNotification(message);
    };

    // Listen for reactions - could show notification too if needed
    _watchPartyService.onReaction = (reaction) {
      // Reactions are handled in video players
    };
  }

  /// Handle video change from host
  Future<void> _handleVideoChange(String videoUrl, String videoTitle) async {
    if (videoUrl.isEmpty) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    // Check if we're already in a video player by checking route
    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null) {
      final routeName = modalRoute.settings.name ?? '';
      if (routeName.contains('video') || 
          routeName.contains('YTFull') ||
          routeName.contains('RSNewVideoPlayerScreen')) {
        // Already in video player, let it handle the change
        return;
      }
    }

    // Navigate to video
    try {
      final allLinks = await StorageService.getSavedLinks();
      final link = allLinks.firstWhere(
        (l) => l.url == videoUrl,
        orElse: () => SavedLink(
          id: '',
          url: videoUrl,
          title: videoTitle,
          type: LinkParser.parseLinkType(videoUrl) ?? LinkType.unknown,
          listIds: [],
          savedAt: DateTime.now(),
        ),
      );

      if (link.type == LinkType.youtube) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => YTFull(
              url: link.url,
              title: link.title.isNotEmpty ? link.title : videoTitle,
              listIds: link.listIds,
            ),
          ),
        );
      } else if (link.type.canPlayInbuilt) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RSNewVideoPlayerScreen(
              url: link.url,
              title: link.title.isNotEmpty ? link.title : videoTitle,
              listIds: link.listIds,
            ),
          ),
        );
      } else {
        // External link
        if (await canLaunchUrl(Uri.parse(videoUrl))) {
          await launchUrl(Uri.parse(videoUrl), mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('Error navigating to video: $e');
    }
  }

  /// Handle room updates
  void _handleRoomUpdate(WatchPartyRoom room) {
    // If guest and video URL exists, navigate to it
    if (!_watchPartyService.isHost && room.videoUrl.isNotEmpty) {
      final context = navigatorKey.currentContext;
      if (context != null) {
      // Check if we're not already in a video player
      final modalRoute = ModalRoute.of(context);
      if (modalRoute != null) {
        final routeName = modalRoute.settings.name ?? '';
        if (!routeName.contains('video') && 
            !routeName.contains('YTFull') &&
            !routeName.contains('RSNewVideoPlayerScreen')) {
          _handleVideoChange(room.videoUrl, room.videoTitle);
        }
      } else {
        // No route info, try to navigate
        _handleVideoChange(room.videoUrl, room.videoTitle);
      }
      }
    }
  }

  /// Show global chat notification on any screen
  void _showGlobalChatNotification(ChatMessage message) {
    // Don't show if same message
    if (_currentNotificationMessage?.id == message.id) return;

    // Remove existing notification
    _removeGlobalChatNotification();

    _currentNotificationMessage = message;

    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null) return;

    final overlay = navigatorState.overlay;
    if (overlay == null) return;

    _chatNotificationOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: WatchPartyChatNotification(
            message: message,
            onTap: () {
              _removeGlobalChatNotification();
              _openChatOverlay();
            },
            onComplete: () {
              _removeGlobalChatNotification();
            },
          ),
        ),
      ),
    );

    overlay.insert(_chatNotificationOverlay!);

    // Auto-remove after 4 seconds
    _notificationTimer?.cancel();
    _notificationTimer = Timer(const Duration(seconds: 4), () {
      _removeGlobalChatNotification();
    });
  }

  /// Remove global chat notification
  void _removeGlobalChatNotification() {
    _notificationTimer?.cancel();
    _notificationTimer = null;
    _chatNotificationOverlay?.remove();
    _chatNotificationOverlay = null;
    _currentNotificationMessage = null;
  }

  /// Open chat overlay (navigate to video player if not already there)
  void _openChatOverlay() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    // If in video player, just show chat
    // Otherwise, navigate to video player first
    if (_watchPartyService.isInRoom && _watchPartyService.currentRoom != null) {
      final room = _watchPartyService.currentRoom!;
      if (room.videoUrl.isNotEmpty) {
        _handleVideoChange(room.videoUrl, room.videoTitle);
      }
    }
  }

  /// Cleanup
  void dispose() {
    _removeGlobalChatNotification();
    _isInitialized = false;
  }
}

