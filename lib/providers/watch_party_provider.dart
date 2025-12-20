import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:elysian/services/watch_party_service.dart';
import 'package:elysian/services/watch_party_firebase_service.dart';
import 'package:elysian/models/watch_party_models.dart';
import 'package:elysian/models/models.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/services/auth_service.dart';
import 'package:elysian/services/link_parser.dart';
import 'package:elysian/video_player/yt_full.dart';
import 'package:elysian/video_player/video_player_full.dart';
import 'package:elysian/utils/kroute.dart';
import 'package:elysian/widgets/watch_party_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

/// Watch Party Provider - Manages watch party state globally
class WatchPartyProvider with ChangeNotifier {
  final WatchPartyService _watchPartyService = WatchPartyService();
  final WatchPartyFirebaseService _firebaseService = WatchPartyFirebaseService();
  final AuthService _authService = AuthService();
  
  // Use Firebase if available, otherwise fall back to local
  bool _useFirebase = false;
  bool get useFirebase => _useFirebase;
  
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
  String? _roomEndedMessage; // Message when host ends party
  String? _lastNavigatedVideoUrl; // Track last navigated video to prevent duplicate navigations
  DateTime? _lastNavigationTime; // Track when last navigation occurred
  
  // Global overlay for notifications
  OverlayEntry? _notificationOverlay;
  Timer? _notificationTimer;
  
  // Getters
  WatchPartyRoom? get currentRoom => _currentRoom;
  bool get isInRoom => _currentRoom != null;
  bool get isHost => _useFirebase 
      ? _firebaseService.isHost 
      : _watchPartyService.isHost;
  bool get isConnected => _isConnected;
  String? get connectionError => _connectionError;
  String? get currentParticipantId => _useFirebase
      ? _firebaseService.currentParticipantId
      : _watchPartyService.currentParticipantId;
  List<ChatMessage> get recentMessages => List.unmodifiable(_recentMessages);
  List<Reaction> get recentReactions => List.unmodifiable(_recentReactions);
  ChatMessage? get latestChatNotification => _latestChatNotification;
  Reaction? get latestReactionNotification => _latestReactionNotification;
  String? get roomEndedMessage => _roomEndedMessage;
  
  static const int _maxMessages = 100;
  static const int _maxReactions = 50;
  
  WatchPartyProvider() {
    _initializeCallbacks();
    _checkFirebaseAvailability();
  }
  
  /// Check if Firebase is available and prefer it over local
  Future<void> _checkFirebaseAvailability() async {
    try {
      final isAvailable = await WatchPartyFirebaseService.isAvailable();
      _useFirebase = isAvailable;
      if (_useFirebase) {
        debugPrint('WatchParty: Using Firebase for online sync');
      } else {
        debugPrint('WatchParty: Firebase not available, using local network');
      }
    } catch (e) {
      _useFirebase = false;
      debugPrint('WatchParty: Firebase check failed, using local network: $e');
    }
  }
  
  /// Initialize all callbacks
  void _initializeCallbacks() {
    // Local service callbacks
    _watchPartyService.onRoomUpdate = (room) {
      if (!_useFirebase) {
        _handleRoomUpdate(room);
      }
    };
    
    _watchPartyService.onVideoChange = (videoUrl, videoTitle) {
      if (!_useFirebase) {
        _handleVideoChange(videoUrl, videoTitle);
      }
    };
    
    _watchPartyService.onChatMessage = (message) {
      if (!_useFirebase) {
        _handleChatMessage(message);
      }
    };
    
    _watchPartyService.onReaction = (reaction) {
      if (!_useFirebase) {
        _handleReaction(reaction);
      }
    };
    
    _watchPartyService.onSyncMessage = (message) {
      if (!_useFirebase) {
        notifyListeners();
      }
    };
    
    // Firebase service callbacks
    _firebaseService.onRoomUpdate = (room) {
      if (_useFirebase) {
        _handleRoomUpdate(room);
      }
    };
    
    _firebaseService.onVideoChange = (videoUrl, videoTitle) {
      if (_useFirebase) {
        _handleVideoChange(videoUrl, videoTitle);
      }
    };
    
    _firebaseService.onChatMessage = (message) {
      if (_useFirebase) {
        _handleChatMessage(message);
      }
    };
    
    _firebaseService.onReaction = (reaction) {
      if (_useFirebase) {
        _handleReaction(reaction);
      }
    };
    
    _firebaseService.onRoomEnded = (reason) {
      if (_useFirebase) {
        _handleRoomEnded(reason);
      }
    };
  }
  
  /// Handle room ended (host ended party)
  void _handleRoomEnded(String reason) {
    // Prevent duplicate handling
    if (_currentRoom == null && _roomEndedMessage != null) {
      debugPrint('WatchPartyProvider: Room already ended, ignoring duplicate call');
      return;
    }
    
    _roomEndedMessage = reason;
    _currentRoom = null;
    _isConnected = false;
    _connectionError = reason;
    _recentMessages.clear();
    _recentReactions.clear();
    _latestChatNotification = null;
    _latestReactionNotification = null;
    _lastNavigatedVideoUrl = null;
    _lastNavigationTime = null;
    _removeGlobalNotification();
    _hideIndicatorOverlay();
    
    // Reset mode flag
    _useFirebase = false;
    
    notifyListeners();
    
    // Show notification dialog after a short delay to ensure UI is ready
    Future.delayed(const Duration(milliseconds: 300), () {
      _showRoomEndedDialog(reason);
    });
  }
  
  /// Show dialog when room ends
  void _showRoomEndedDialog(String reason) {
    // Use a delayed check to ensure context is available
    Future.delayed(const Duration(milliseconds: 100), () {
      final context = navigatorKey.currentContext;
      if (context == null) {
        debugPrint('WatchPartyProvider: Context not available for room ended dialog');
        return;
      }
      
      // Check if dialog is already showing
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.amber.withOpacity(0.5), width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Watch Party Ended',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              reason,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Have a great time soon again! 🎬',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _roomEndedMessage = null;
              notifyListeners();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        ),
      );
    });
  }
  
  /// Handle room update
  void _handleRoomUpdate(WatchPartyRoom room) {
    // Don't process room updates if we've already left the room
    // This prevents the indicator from showing again after leaving
    // Check if this is a different room (we left) or if currentRoom is null
    if (_currentRoom == null) {
      // We've left the room, ignore any delayed updates
      _hideIndicatorOverlay();
      return;
    }
    
    // If room IDs don't match, we might have left and this is a stale update
    if (_currentRoom!.roomId != room.roomId) {
      _hideIndicatorOverlay();
      return;
    }
    
    final videoChanged = _currentRoom?.videoUrl != room.videoUrl || 
                        _currentRoom?.videoTitle != room.videoTitle;
    
    _currentRoom = room;
    
    // Update connection state based on current mode
    if (_useFirebase) {
      _isConnected = _firebaseService.isConnected;
      _connectionError = _firebaseService.connectionError;
    } else {
      _isConnected = _watchPartyService.isConnected;
      _connectionError = _watchPartyService.connectionError;
      
      // IMPORTANT: For local mode, if connection is lost and room is null, host likely ended the room
      if (!_isConnected && _watchPartyService.currentRoom == null && _currentRoom != null) {
        // Host ended the room - handle it similar to Firebase
        debugPrint('WatchPartyProvider: Local mode - host ended room (connection lost)');
        _handleRoomEnded(_connectionError ?? 'Host ended the watch party');
        return; // Don't process further updates
      }
    }
    
    // IMPORTANT: Forward Firebase updates to local service callback
    // This ensures video players receive updates (they listen to local service)
    if (_useFirebase && _watchPartyService.onRoomUpdate != null) {
      _watchPartyService.onRoomUpdate!(room);
    }
    
    // Update indicator overlay only if room is still valid
    if (_currentRoom != null) {
      _updateIndicatorOverlay();
    } else {
      _hideIndicatorOverlay();
    }
    
    notifyListeners();
    
    // IMPORTANT: Don't navigate when video changes if we're already in a video player
    // The video player will handle the video change via onRoomUpdate callback
    // Only navigate if we're NOT in a video player (e.g., user is on home screen)
    if (videoChanged && room.videoUrl.isNotEmpty && !isHost) {
      Future.delayed(const Duration(milliseconds: 200), () {
        // If we're already in a video player, don't navigate - let the player handle it
        if (_isInVideoPlayer()) {
          debugPrint('WatchPartyProvider: Already in video player, player will handle video change. Skipping navigation.');
          return;
        }
        
        // Only navigate if we're NOT in a video player
        if (!_isInVideoPlayer() && _currentRoom?.videoUrl == room.videoUrl) {
          debugPrint('WatchPartyProvider: Not in video player, navigating guest to video ${room.videoUrl}');
          _navigateToVideo(room.videoUrl, room.videoTitle);
        }
      });
    }
  }
  
  /// Handle video change
  void _handleVideoChange(String videoUrl, String videoTitle) {
    // Update room if we have one
    if (_currentRoom != null) {
      // Only update if video actually changed
      if (_currentRoom!.videoUrl != videoUrl) {
        _currentRoom = _currentRoom!.copyWith(
          videoUrl: videoUrl,
          videoTitle: videoTitle,
        );
        notifyListeners();
      }
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
    
    // IMPORTANT: Prevent infinite navigation loop
    // Hosts should never navigate - they're already in the video player
    if (isHost) {
      debugPrint('WatchPartyProvider: Host updating video, skipping navigation');
      return;
    }
    
    // If we're already in a video player, don't navigate again
    // The video player itself will handle video changes via onVideoChange callback
    if (_isInVideoPlayer()) {
      debugPrint('WatchPartyProvider: Already in video player, skipping navigation. Video player will handle change.');
      return;
    }
    
    // Navigate if not already in video player (guests only)
    // Use a delay to ensure context is available and avoid race conditions
    Future.delayed(const Duration(milliseconds: 200), () {
      // Double-check we're not already in the video player
      if (!_isInVideoPlayer() && _currentRoom?.videoUrl == videoUrl) {
        debugPrint('WatchPartyProvider: Navigating guest to video $videoUrl');
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
    
    // Hosts should never navigate - they're already in the video player
    if (isHost) {
      debugPrint('WatchPartyProvider: Host attempted navigation, skipping');
      return;
    }
    
    // Prevent duplicate navigations to the same video within a short time window
    final now = DateTime.now();
    if (_lastNavigatedVideoUrl == videoUrl && _lastNavigationTime != null) {
      final timeSinceLastNav = now.difference(_lastNavigationTime!);
      if (timeSinceLastNav.inSeconds < 3) {
        debugPrint('WatchPartyProvider: Duplicate navigation prevented (same video within ${timeSinceLastNav.inSeconds}s)');
        return;
      }
    }
    
    // Double-check that the video URL matches the current room's video URL
    // This prevents navigation with stale/wrong video URLs
    if (_currentRoom != null && _currentRoom!.videoUrl != videoUrl) {
      debugPrint('WatchPartyProvider: Video URL mismatch, skipping navigation. Room: ${_currentRoom!.videoUrl}, Requested: $videoUrl');
      return;
    }
    
    // Final check: if we're already in a video player, don't navigate
    if (_isInVideoPlayer()) {
      debugPrint('WatchPartyProvider: Already in video player, skipping navigation to $videoUrl');
      return;
    }
    
    // Mark that we're navigating to prevent duplicate calls
    _lastNavigatedVideoUrl = videoUrl;
    _lastNavigationTime = now;
    
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

      // IMPORTANT: Use pushReplacement instead of push to replace current video player
      // This prevents stacking multiple video players when host changes video
      if (link.type == LinkType.youtube) {
        Navigator.pushReplacement(
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
        Navigator.pushReplacement(
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
  
  /// Update indicator overlay
  void _updateIndicatorOverlay() {
    // Always check current room state before updating
    if (_currentRoom == null) {
      _hideIndicatorOverlay();
      return;
    }
    
    final context = navigatorKey.currentContext;
    if (context == null) return;
    
    // Show or update indicator
    Future.delayed(const Duration(milliseconds: 100), () {
      // Double-check room is still valid after delay
      if (_currentRoom == null) {
        _hideIndicatorOverlay();
        return;
      }
      final ctx = navigatorKey.currentContext;
      if (ctx != null && _currentRoom != null) {
        WatchPartyIndicatorOverlay.show(ctx, _currentRoom!, isHost);
      }
    });
  }
  
  /// Hide indicator overlay
  void _hideIndicatorOverlay() {
    WatchPartyIndicatorOverlay.hide();
  }
  
  /// Open chat (navigate to video player if needed)
  void _openChat() {
    if (_currentRoom?.videoUrl.isNotEmpty == true) {
      _navigateToVideo(_currentRoom!.videoUrl, _currentRoom!.videoTitle);
    }
  }
  
  /// Create room
  Future<WatchPartyRoom?> createRoom(
    String participantName, {
    bool useOnline = false,
    String? videoUrl,
    String? videoTitle,
    Duration? initialPosition,
    bool? initialPlaying,
  }) async {
    // Check if user is authenticated
    final isSignedIn = await _authService.checkSignInStatus();
    if (!isSignedIn) {
      throw Exception('Please sign in to create a watch party. Authentication is required for watch party features.');
    }
    
    // IMPORTANT: Ensure we're not already in a room before creating a new one
    if (_currentRoom != null) {
      debugPrint('WatchPartyProvider: Already in a room, leaving first...');
      await leaveRoom();
      // Wait a bit for cleanup to complete
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    // Use Firebase only if explicitly requested (useOnline=true)
    // If useOnline=false, always use local network regardless of Firebase availability
    // If useOnline is not specified (default false), use Firebase if available, otherwise local
    final shouldUseFirebase = useOnline;
    
    try {
      if (shouldUseFirebase) {
        final room = await _firebaseService.createRoom(
          hostName: participantName,
          videoUrl: videoUrl ?? '',
          videoTitle: videoTitle ?? 'Watch Party',
          initialPosition: initialPosition ?? Duration.zero,
          initialPlaying: initialPlaying ?? false,
        );
        _currentRoom = room;
        // Force update to use Firebase service
        _useFirebase = true;
        
        // Re-initialize callbacks to ensure they're set up correctly for Firebase mode
        _initializeCallbacks();
        
        _isConnected = _firebaseService.isConnected;
        _connectionError = _firebaseService.connectionError;
        _updateIndicatorOverlay();
        notifyListeners();
        
        // Trigger a room update to ensure connection state is synced
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_currentRoom != null && _firebaseService.isConnected) {
            _handleRoomUpdate(_currentRoom!);
          }
        });
        
        return room;
      } else {
        // Fall back to local network
        debugPrint('WatchPartyProvider: Creating local network room');
        // IMPORTANT: Force use of local service, not Firebase
        _useFirebase = false;
        
        // Re-initialize callbacks to ensure they're set up correctly for local mode
        _initializeCallbacks();
        
        final room = await _watchPartyService.createRoom(
          hostName: participantName,
          videoUrl: videoUrl ?? '',
          videoTitle: videoTitle ?? 'Watch Party',
          initialPosition: initialPosition ?? Duration.zero,
          initialPlaying: initialPlaying ?? false,
        );
        _currentRoom = room;
        _isConnected = _watchPartyService.isConnected;
        _connectionError = _watchPartyService.connectionError;
        
        // Verify server port after room creation
        final port = _watchPartyService.getServerPort();
        debugPrint('WatchPartyProvider: Room created, server port: $port');
        debugPrint('WatchPartyProvider: _useFirebase set to false for local mode');
        
        _updateIndicatorOverlay();
        notifyListeners();
        return room;
      }
    } catch (e) {
      debugPrint('Error creating room: $e');
      // If Firebase fails and it was explicitly requested, try local as fallback
      if (shouldUseFirebase && useOnline) {
        debugPrint('WatchParty: Firebase failed, falling back to local network');
        return createRoom(
          participantName,
          useOnline: false,
          videoUrl: videoUrl,
          videoTitle: videoTitle,
          initialPosition: initialPosition,
          initialPlaying: initialPlaying,
        );
      }
      return null;
    }
  }
  
  /// Join room (local network)
  Future<WatchPartyRoom?> joinRoom(
    String participantName,
    String hostIp,
    int hostPort,
    String roomCode,
  ) async {
    // Check if user is authenticated
    final isSignedIn = await _authService.checkSignInStatus();
    if (!isSignedIn) {
      throw Exception('Please sign in to join a watch party. Authentication is required for watch party features.');
    }
    
    // IMPORTANT: Ensure we're not already in a room before joining a new one
    if (_currentRoom != null) {
      debugPrint('WatchPartyProvider: Already in a room, leaving first...');
      await leaveRoom();
      // Wait a bit for cleanup to complete
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    try {
      // IMPORTANT: Force use of local service, not Firebase
      _useFirebase = false;
      debugPrint('WatchPartyProvider: Joining local network room, _useFirebase set to false');
      
      // Re-initialize callbacks to ensure they're set up correctly for local mode
      _initializeCallbacks();
      
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
        _updateIndicatorOverlay();
        notifyListeners();
      }
      return room;
    } catch (e) {
      debugPrint('Error joining room: $e');
      return null;
    }
  }
  
  /// Join room (online/Firebase)
  Future<WatchPartyRoom?> joinRoomOnline(
    String participantName,
    String roomCode,
  ) async {
    // Check if user is authenticated
    final isSignedIn = await _authService.checkSignInStatus();
    if (!isSignedIn) {
      throw Exception('Please sign in to join a watch party. Authentication is required for watch party features.');
    }
    
    // IMPORTANT: Ensure we're not already in a room before joining a new one
    if (_currentRoom != null) {
      debugPrint('WatchPartyProvider: Already in a room, leaving first...');
      await leaveRoom();
      // Wait a bit for cleanup to complete
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    try {
      if (roomCode.isEmpty) {
        _connectionError = 'Room code is required';
        return null;
      }
      
      // IMPORTANT: Force use of Firebase service for online mode
      _useFirebase = true;
      debugPrint('WatchPartyProvider: Joining online room, _useFirebase set to true');
      
      // Re-initialize callbacks to ensure they're set up correctly for Firebase mode
      _initializeCallbacks();
      
      final room = await _firebaseService.joinRoom(
        participantName: participantName,
        roomCode: roomCode,
      );
      
      if (room != null) {
        _currentRoom = room;
        _isConnected = _firebaseService.isConnected;
        _connectionError = _firebaseService.connectionError;
        _updateIndicatorOverlay();
        notifyListeners();
      } else {
        _connectionError = _firebaseService.connectionError ?? 'Failed to join room';
      }
      
      return room;
    } catch (e) {
      debugPrint('Error joining online room: $e');
      _connectionError = 'Failed to join room: $e';
      return null;
    }
  }
  
  /// Leave room
  Future<void> leaveRoom() async {
    debugPrint('WatchPartyProvider: leaveRoom() called, useFirebase: $_useFirebase');
    final wasHost = isHost;
    final wasUsingFirebase = _useFirebase;
    
    // Hide indicator immediately before leaving to prevent it from showing again
    _hideIndicatorOverlay();
    
    try {
      if (_useFirebase) {
        debugPrint('WatchPartyProvider: Leaving Firebase room');
        await _firebaseService.leaveRoom();
      } else {
        debugPrint('WatchPartyProvider: Leaving local room');
        await _watchPartyService.leaveRoom();
        debugPrint('WatchPartyProvider: Local service leaveRoom() completed');
      }
    } catch (e, stackTrace) {
      debugPrint('WatchPartyProvider: Error in leaveRoom(): $e');
      debugPrint('WatchPartyProvider: Stack trace: $stackTrace');
      // Continue with cleanup even if service call fails
    }
    
    // Clear all state
    debugPrint('WatchPartyProvider: Clearing state');
    _currentRoom = null;
    _isConnected = false;
    _connectionError = null;
    _recentMessages.clear();
    _recentReactions.clear();
    _latestChatNotification = null;
    _latestReactionNotification = null;
    _roomEndedMessage = null;
    _lastNavigatedVideoUrl = null; // Reset navigation tracking
    _lastNavigationTime = null;
    _removeGlobalNotification();
    
    // IMPORTANT: Reset mode flag after leaving to ensure clean state for next room
    // This prevents issues when switching between local and online modes
    _useFirebase = false;
    
    // Ensure indicator is hidden (call again to be safe)
    _hideIndicatorOverlay();
    
    // Notify listeners after state is cleared
    debugPrint('WatchPartyProvider: Notifying listeners');
    notifyListeners();
    
    // Final check to hide indicator after a delay (in case any delayed updates try to show it)
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_currentRoom == null) {
        _hideIndicatorOverlay();
      }
    });
    
    // If host left, show confirmation
    if (wasHost && wasUsingFirebase) {
      debugPrint('Host left watch party - all participants will be notified');
    }
    
    debugPrint('WatchPartyProvider: leaveRoom() completed');
  }
  
  /// Send chat message
  Future<void> sendChatMessage(String message) async {
    // Validate we're in a room and have participant ID
    if (!isInRoom || _currentRoom == null) {
      debugPrint('WatchPartyProvider: Cannot send chat - not in a room');
      return;
    }
    
    final participantId = currentParticipantId;
    if (participantId == null || participantId.isEmpty) {
      debugPrint('WatchPartyProvider: Cannot send chat - no participant ID');
      return;
    }
    
    debugPrint('WatchPartyProvider: sendChatMessage called, useFirebase: $_useFirebase');
    debugPrint('WatchPartyProvider: isInRoom: $isInRoom, currentRoom: ${_currentRoom != null}');
    
    try {
      if (_useFirebase) {
        await _firebaseService.sendChatMessage(message);
      } else {
        debugPrint('WatchPartyProvider: Calling local service sendChatMessage');
        await _watchPartyService.sendChatMessage(message);
      }
    } catch (e) {
      debugPrint('WatchPartyProvider: Error sending chat message: $e');
      // Don't throw, just log the error
    }
  }
  
  /// Send reaction
  Future<void> sendReaction(ReactionType type) async {
    // Validate we're in a room and have participant ID
    if (!isInRoom || _currentRoom == null) {
      debugPrint('WatchPartyProvider: Cannot send reaction - not in a room');
      return;
    }
    
    final participantId = currentParticipantId;
    if (participantId == null || participantId.isEmpty) {
      debugPrint('WatchPartyProvider: Cannot send reaction - no participant ID');
      return;
    }
    
    debugPrint('WatchPartyProvider: sendReaction called with $type, useFirebase: $_useFirebase');
    debugPrint('WatchPartyProvider: isInRoom: $isInRoom, currentRoom: ${_currentRoom != null}');
    
    try {
      if (_useFirebase) {
        await _firebaseService.sendReaction(type);
      } else {
        debugPrint('WatchPartyProvider: Calling local service sendReaction');
        await _watchPartyService.sendReaction(type);
      }
    } catch (e) {
      debugPrint('WatchPartyProvider: Error sending reaction: $e');
      // Don't throw, just log the error
    }
  }
  
  /// Update room state (host only)
  void updateRoomState({
    Duration? position,
    bool? isPlaying,
    String? videoUrl,
    String? videoTitle,
  }) {
    // Validate we're in a room and are the host
    if (!isInRoom || !isHost || _currentRoom == null) {
      debugPrint('WatchPartyProvider: Cannot update room state - not host or not in room');
      return;
    }
    
    try {
      if (_useFirebase) {
        _firebaseService.updateRoomState(
          position: position,
          isPlaying: isPlaying,
          videoUrl: videoUrl,
          videoTitle: videoTitle,
        );
      } else {
        _watchPartyService.updateRoomState(
          position: position,
          isPlaying: isPlaying,
          videoUrl: videoUrl,
          videoTitle: videoTitle,
        );
      }
    } catch (e) {
      debugPrint('WatchPartyProvider: Error updating room state: $e');
      // Don't throw, just log the error
    }
  }
  
  @override
  void dispose() {
    _removeGlobalNotification();
    _hideIndicatorOverlay();
    if (_useFirebase) {
      _firebaseService.leaveRoom();
    } else {
      _watchPartyService.leaveRoom();
    }
    super.dispose();
  }
}

