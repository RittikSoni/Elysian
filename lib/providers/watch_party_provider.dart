import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:elysian/services/watch_party_service.dart';
import 'package:elysian/models/watch_party_models.dart';
import 'package:elysian/models/models.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/services/link_parser.dart';
import 'package:elysian/video_player/yt_full.dart';
import 'package:elysian/video_player/video_player_full.dart';
import 'package:elysian/utils/kroute.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

/// Watch Party Provider - Manages watch party state globally
class WatchPartyProvider with ChangeNotifier {
  final WatchPartyService _watchPartyService = WatchPartyService();
  
  // Expose service for widgets that need direct access
  WatchPartyService get watchPartyService => _watchPartyService;
  
  // State
  WatchPartyRoom? _currentRoom;
  bool _isConnected = false;
  String? _connectionError;
  List<ChatMessage> _recentMessages = [];
  List<Reaction> _recentReactions = [];
  ChatMessage? _latestChatNotification;
  Reaction? _latestReactionNotification;
  
  // Global overlay for notifications
  OverlayEntry? _notificationOverlay;
  Timer? _notificationTimer;
  
  // Getters
  WatchPartyRoom? get currentRoom => _currentRoom;
  bool get isInRoom => _currentRoom != null;
  bool get isHost => _watchPartyService.isHost;
  bool get isConnected => _isConnected;
  String? get connectionError => _connectionError;
  List<ChatMessage> get recentMessages => List.unmodifiable(_recentMessages);
  List<Reaction> get recentReactions => List.unmodifiable(_recentReactions);
  ChatMessage? get latestChatNotification => _latestChatNotification;
  Reaction? get latestReactionNotification => _latestReactionNotification;
  
  static const int _maxMessages = 100;
  static const int _maxReactions = 50;
  
  WatchPartyProvider() {
    _initializeCallbacks();
  }
  
  /// Initialize all callbacks
  void _initializeCallbacks() {
    // Room updates
    _watchPartyService.onRoomUpdate = (room) {
      _handleRoomUpdate(room);
    };
    
    // Video changes
    _watchPartyService.onVideoChange = (videoUrl, videoTitle) {
      _handleVideoChange(videoUrl, videoTitle);
    };
    
    // Chat messages
    _watchPartyService.onChatMessage = (message) {
      _handleChatMessage(message);
    };
    
    // Reactions
    _watchPartyService.onReaction = (reaction) {
      _handleReaction(reaction);
    };
    
    // Sync messages
    _watchPartyService.onSyncMessage = (message) {
      // Sync messages are handled by video players
      notifyListeners();
    };
  }
  
  /// Handle room update
  void _handleRoomUpdate(WatchPartyRoom room) {
    final videoChanged = _currentRoom?.videoUrl != room.videoUrl || 
                        _currentRoom?.videoTitle != room.videoTitle;
    
    _currentRoom = room;
    _isConnected = _watchPartyService.isConnected;
    _connectionError = _watchPartyService.connectionError;
    
    notifyListeners();
    
    // If video changed and we're not in a video player, navigate
    // Use a delay to ensure context is available and avoid race conditions
    if (videoChanged && room.videoUrl.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_isInVideoPlayer() && _currentRoom?.videoUrl == room.videoUrl) {
          _navigateToVideo(room.videoUrl, room.videoTitle);
        }
      });
    }
  }
  
  /// Handle video change
  void _handleVideoChange(String videoUrl, String videoTitle) {
    // Update room if we have one
    if (_currentRoom != null) {
      _currentRoom = _currentRoom!.copyWith(
        videoUrl: videoUrl,
        videoTitle: videoTitle,
      );
      notifyListeners();
    }
    
    // If video URL is empty, host closed the video - guests should also close
    if (videoUrl.isEmpty) {
      // Navigate back if in video player
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_isInVideoPlayer()) {
          final context = navigatorKey.currentContext;
          if (context != null) {
            Navigator.pop(context);
          }
        }
      });
      return;
    }
    
    // Navigate if not already in video player
    // Use a delay to ensure context is available and avoid race conditions
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!_isInVideoPlayer() && _currentRoom?.videoUrl == videoUrl) {
        _navigateToVideo(videoUrl, videoTitle);
      }
    });
  }
  
  /// Handle chat message
  void _handleChatMessage(ChatMessage message) {
    // Add to recent messages
    _recentMessages.add(message);
    if (_recentMessages.length > _maxMessages) {
      _recentMessages.removeAt(0);
    }
    
    // Set as latest notification
    _latestChatNotification = message;
    
    // Show global notification
    _showGlobalNotification(message: message);
    
    notifyListeners();
    
    // Clear notification after delay
    Future.delayed(const Duration(seconds: 4), () {
      if (_latestChatNotification?.id == message.id) {
        _latestChatNotification = null;
        notifyListeners();
      }
    });
  }
  
  /// Handle reaction
  void _handleReaction(Reaction reaction) {
    // Add to recent reactions
    _recentReactions.add(reaction);
    if (_recentReactions.length > _maxReactions) {
      _recentReactions.removeAt(0);
    }
    
    // Set as latest notification
    _latestReactionNotification = reaction;
    
    // Show global notification
    _showGlobalNotification(reaction: reaction);
    
    notifyListeners();
    
    // Clear notification after delay
    Future.delayed(const Duration(seconds: 3), () {
      if (_latestReactionNotification?.id == reaction.id) {
        _latestReactionNotification = null;
        notifyListeners();
      }
    });
  }
  
  /// Check if currently in video player
  bool _isInVideoPlayer() {
    final context = navigatorKey.currentContext;
    if (context == null) return false;
    
    try {
      // Get the current route
      final route = ModalRoute.of(context);
      if (route == null) return false;
      
      // Check route name or settings
      final routeName = route.settings.name ?? '';
      final isVideoRoute = routeName.contains('video') || 
                           routeName.contains('YTFull') ||
                           routeName.contains('RSNewVideoPlayerScreen');
      
      if (isVideoRoute) return true;
      
      // Also check if we're in a video player by checking the widget tree
      // This is a fallback if route name isn't set
      try {
        final videoPlayer = context.findAncestorWidgetOfExactType<YTFull>();
        if (videoPlayer != null) return true;
        final regularPlayer = context.findAncestorWidgetOfExactType<RSNewVideoPlayerScreen>();
        if (regularPlayer != null) return true;
      } catch (e) {
        // Ignore errors
      }
      
      return false;
    } catch (e) {
      // If any error occurs, assume we're not in a video player
      // This allows navigation to proceed
      debugPrint('Error checking if in video player: $e');
      return false;
    }
  }
  
  /// Navigate to video
  Future<void> _navigateToVideo(String videoUrl, String videoTitle) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    
    // Double-check that the video URL matches the current room's video URL
    // This prevents navigation with stale/wrong video URLs
    if (_currentRoom != null && _currentRoom!.videoUrl != videoUrl) {
      debugPrint('WatchPartyProvider: Video URL mismatch, skipping navigation. Room: ${_currentRoom!.videoUrl}, Requested: $videoUrl');
      return;
    }
    
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
              adsEnabled: false, // Disable ads by default
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
  
  /// Show global notification overlay
  void _showGlobalNotification({ChatMessage? message, Reaction? reaction}) {
    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null) return;
    
    final overlay = navigatorState.overlay;
    if (overlay == null) return;
    
    // Remove existing notification
    _removeGlobalNotification();
    
    _notificationOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: _buildNotificationWidget(message: message, reaction: reaction),
        ),
      ),
    );
    
    overlay.insert(_notificationOverlay!);
    
    // Auto-remove after delay
    _notificationTimer?.cancel();
    _notificationTimer = Timer(
      Duration(seconds: message != null ? 4 : 3),
      () => _removeGlobalNotification(),
    );
  }
  
  /// Build notification widget
  Widget _buildNotificationWidget({ChatMessage? message, Reaction? reaction}) {
    if (message != null) {
      return _buildChatNotification(message);
    } else if (reaction != null) {
      return _buildReactionNotification(reaction);
    }
    return const SizedBox.shrink();
  }
  
  /// Build chat notification
  Widget _buildChatNotification(ChatMessage message) {
    return GestureDetector(
      onTap: () {
        _removeGlobalNotification();
        _openChat();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[900]!.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.amber.withOpacity(0.2),
              child: Text(
                message.participantName.isNotEmpty
                    ? message.participantName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.participantName,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chat_bubble_outline,
              color: Colors.amber,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
  
  /// Build reaction notification
  Widget _buildReactionNotification(Reaction reaction) {
    final emojiMap = {
      ReactionType.like: '👍',
      ReactionType.love: '❤️',
      ReactionType.laugh: '😂',
      ReactionType.sad: '😢',
      ReactionType.angry: '😠',
    };
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900]!.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emojiMap[reaction.type] ?? '👍',
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 8),
          Text(
            '${reaction.participantName} reacted',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Remove global notification
  void _removeGlobalNotification() {
    _notificationTimer?.cancel();
    _notificationTimer = null;
    _notificationOverlay?.remove();
    _notificationOverlay = null;
  }
  
  /// Open chat (navigate to video player if needed)
  void _openChat() {
    if (_currentRoom?.videoUrl.isNotEmpty == true) {
      _navigateToVideo(_currentRoom!.videoUrl, _currentRoom!.videoTitle);
    }
  }
  
  /// Create room
  Future<WatchPartyRoom?> createRoom(String participantName) async {
    final room = await _watchPartyService.createRoom(
      hostName: participantName,
      videoUrl: '',
      videoTitle: 'Watch Party',
      initialPosition: Duration.zero,
      initialPlaying: false,
    );
    _currentRoom = room;
    _isConnected = _watchPartyService.isConnected;
    notifyListeners();
    return room;
  }
  
  /// Join room
  Future<WatchPartyRoom?> joinRoom(
    String participantName,
    String hostIp,
    int hostPort,
    String roomCode,
  ) async {
    final room = await _watchPartyService.joinRoom(
      hostIp: hostIp,
      hostPort: hostPort,
      participantName: participantName,
      roomCode: roomCode.isEmpty ? null : roomCode,
    );
    if (room != null) {
      _currentRoom = room;
      _isConnected = _watchPartyService.isConnected;
      _connectionError = _watchPartyService.connectionError;
      notifyListeners();
    }
    return room;
  }
  
  /// Leave room
  Future<void> leaveRoom() async {
    await _watchPartyService.leaveRoom();
    _currentRoom = null;
    _isConnected = false;
    _connectionError = null;
    _recentMessages.clear();
    _recentReactions.clear();
    _latestChatNotification = null;
    _latestReactionNotification = null;
    _removeGlobalNotification();
    notifyListeners();
  }
  
  /// Send chat message
  Future<void> sendChatMessage(String message) async {
    await _watchPartyService.sendChatMessage(message);
  }
  
  /// Send reaction
  Future<void> sendReaction(ReactionType type) async {
    await _watchPartyService.sendReaction(type);
  }
  
  /// Update room state (host only)
  void updateRoomState({
    Duration? position,
    bool? isPlaying,
    String? videoUrl,
    String? videoTitle,
  }) {
    _watchPartyService.updateRoomState(
      position: position,
      isPlaying: isPlaying,
      videoUrl: videoUrl,
      videoTitle: videoTitle,
    );
  }
  
  @override
  void dispose() {
    _removeGlobalNotification();
    _watchPartyService.leaveRoom();
    super.dispose();
  }
}

