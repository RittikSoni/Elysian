// ignore_for_file: invalid_use_of_protected_member, unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:elysian/video_player/shared_video_widgets.dart';
import 'package:elysian/utils/kroute.dart';
import 'package:elysian/models/models.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/services/watch_party_service.dart';
import 'package:elysian/services/link_parser.dart';
import 'package:elysian/providers/providers.dart';
import 'package:provider/provider.dart';
import 'package:elysian/widgets/thumbnail_image.dart';
import 'package:elysian/widgets/watch_party_room_dialog.dart';
import 'package:elysian/widgets/watch_party_participants_overlay.dart';
import 'package:elysian/widgets/watch_party_reaction_overlay.dart';
import 'package:elysian/widgets/watch_party_chat_notification.dart';
import 'package:elysian/screens/video_detail_screen.dart';

class YTFull extends StatefulWidget {
  final String? mediaUrl;
  final String? videoId;
  final String? title;
  final String? description;
  final Duration? initialPosition;
  final String? url; // Full URL to find the link in storage
  final List<String>? listIds; // List IDs this video belongs to
  final bool autoEnterPiP; // Auto-enter PiP mode after initialization

  const YTFull({
    super.key,
    this.mediaUrl,
    this.videoId,
    this.title,
    this.description,
    this.initialPosition,
    this.url,
    this.listIds,
    this.autoEnterPiP = false,
  });

  @override
  State<YTFull> createState() => _YTFullState();
}

class _YTFullState extends State<YTFull> {
  late YoutubePlayerController _controller;

  final bool _isPlayerReady = false;
  bool _wasPlayerReady = false; // Track if player was ready before

  final List<String> _ids = [
    'QdBZY2fkU-0',
    'U_BEXuSlpeE',
    'EeSELdjVLKA',
    'nPt8bK2gbaU',
    // 'gQDByCdjUXw',
    // 'iLnmTe5Q2Qw',
    // '_WoCV4c6XOE',
    // 'KmzdUe0RSJo',
    // '6jZDSSZZxjQ',
    // 'p2lYr3vM_1w',
    // '7QUtEmBT_-w',
    // '34_PXCzGw1M',
  ];

  VideoPlayerController? _adController;

  // UI state
  bool _showControls = true;
  bool _showEpisodeList = false;
  bool _showWatchParty = false;
  double _brightness = 0.5, _volume = 0.5;
  bool _showVolumeSlider = false;
  bool _showBrightnessSlider = false;
  Timer? _sliderHideTimer;
  Timer? _hideTimer;

  // WatchParty state
  final _watchPartyService = WatchPartyService();
  WatchPartyRoom? _watchPartyRoom;
  Timer? _watchPartySyncTimer;
  final List<Reaction> _activeReactions = [];
  ChatMessage? _latestChatMessage;
  bool _isVideoInitializing = false; // Track if video is being loaded/initialized
  DateTime? _lastSeekTime; // Track last seek to prevent rapid seeks
  bool _isSyncing = false; // Flag to prevent concurrent sync operations
  Duration? _lastSyncedPosition; // Track last synced position to avoid unnecessary seeks

  // Ad state
  final List<Duration> _adPositions = [];

  final List<String> _adUrls = [
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
  ];

  int _nextAdIndex = 0;
  bool _inAdBreak = false;
  int _adSecondsRemaining = 0;
  Timer? _adCountdownTimer;

  bool _isLocked = false;

  // PiP state
  bool _isInPiP = false;
  OverlayEntry? _pipOverlayEntry;
  Offset _pipPosition = const Offset(20, 100);
  final GlobalKey _pipKey = GlobalKey();
  bool _isDisposed = false;

  // call this to show one slider and auto‐hide it
  void _showSliderOverlay({required bool isVolume}) {
    _sliderHideTimer?.cancel();
    setState(() {
      _showVolumeSlider = isVolume;
      _showBrightnessSlider = !isVolume;
    });
    _sliderHideTimer = Timer(Duration(seconds: 1, milliseconds: 500), () {
      setState(() {
        _showVolumeSlider = false;
        _showBrightnessSlider = false;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _initVolumeAndBrightness();
    // Use provided videoId or fallback to first ID in list
    final initialVideoId = widget.videoId ?? _ids.first;
    _controller = YoutubePlayerController(
      initialVideoId: initialVideoId,
      flags: const YoutubePlayerFlags(
        mute: false,
        autoPlay: true,
        disableDragSeek: true,
        loop: true,
        isLive: false,
        forceHD: false,
        enableCaption: true,
        hideControls: true,
      ),
    )..addListener(listener);
    initializeVid();
    _initWatchParty();
  }

  void _initWatchParty() {
    _watchPartyService.onSyncMessage = (message) {
      if (!_isDisposed && mounted && !_watchPartyService.isHost) {
        _handleSyncMessage(message);
      }
    };
    
    // Handle sync from room updates (polling) - for guests
    _watchPartyService.onRoomUpdate = (room) {
      if (!_isDisposed && mounted) {
        if (!_watchPartyService.isHost && _controller.value.isReady) {
          // Don't sync if video is still initializing or already syncing
          if (_isVideoInitializing || _isSyncing) return;
          
          // Ensure video has valid duration before syncing
          final duration = _controller.value.metaData.duration;
          if (duration.inMilliseconds <= 0) return;
          
          // Check if current video URL matches room video URL
          // If not, trigger video change to load correct video
          final currentVideoUrl = widget.url ?? widget.mediaUrl ?? '';
          if (room.videoUrl.isNotEmpty && currentVideoUrl != room.videoUrl) {
            // Video mismatch - load the correct video
            _loadVideoFromUrl(room.videoUrl, room.videoTitle);
            return;
          }
          
          // Sync play/pause state (only if state actually changed)
          final currentIsPlaying = _controller.value.isPlaying;
          if (room.isPlaying != currentIsPlaying) {
            if (room.isPlaying) {
              _controller.play();
            } else {
              _controller.pause();
            }
          }
          
          // Sync position - only if there's a significant difference and enough time has passed
          final now = DateTime.now();
          final currentPosition = _controller.value.position;
          
          // Only sync if:
          // 1. Enough time has passed since last seek (3 seconds debounce)
          // 2. Position difference is significant (3+ seconds)
          // 3. Video is playing (don't sync during pauses)
          // 4. Position actually changed from last sync
          if ((_lastSeekTime == null ||
              now.difference(_lastSeekTime!).inMilliseconds > 3000) &&
              room.isPlaying) {
            final positionDiff = (room.currentPosition.inMilliseconds - 
                currentPosition.inMilliseconds).abs();
            
            // Check if position changed significantly from last synced position
            final lastSyncedDiff = _lastSyncedPosition != null
                ? (room.currentPosition.inMilliseconds -
                        _lastSyncedPosition!.inMilliseconds)
                    .abs()
                : 999999;
            
            // Only seek if:
            // - Difference is more than 3 seconds (larger threshold)
            // - Host position actually changed (not just polling noise)
            // - Video is playing
            if (positionDiff > 3000 && lastSyncedDiff > 500) {
              _isSyncing = true;
              // Ensure seek position is within valid range
              final seekPosition = room.currentPosition.inMilliseconds.clamp(
                0, 
                duration.inMilliseconds
              );
              _controller.seekTo(Duration(milliseconds: seekPosition));
              _lastSeekTime = now;
              _lastSyncedPosition = room.currentPosition;
              
              // Reset sync flag after a short delay
              Future.delayed(const Duration(milliseconds: 500), () {
                if (!_isDisposed && mounted) {
                  _isSyncing = false;
                }
              });
            } else {
              // Update last synced position even if we don't seek
              _lastSyncedPosition = room.currentPosition;
            }
          } else if (!room.isPlaying) {
            // When paused, just update last synced position
            _lastSyncedPosition = room.currentPosition;
          }
        }
        // Room is managed by provider
      }
    };
    
    // Chain chat callback to ensure global manager also receives it
    final existingChatCallback = _watchPartyService.onChatMessage;
    _watchPartyService.onChatMessage = (message) {
      // Call existing callback first (from global manager)
      existingChatCallback?.call(message);
      // Then show chat notification overlay in video player
      if (!_isDisposed && mounted) {
        setState(() {
          _latestChatMessage = message;
        });
        // Auto-hide after animation completes
        Future.delayed(const Duration(milliseconds: 3300), () {
          if (!_isDisposed && mounted && _latestChatMessage?.id == message.id) {
            setState(() {
              _latestChatMessage = null;
            });
          }
        });
      }
    };
    
    _watchPartyService.onReaction = (reaction) {
      if (!_isDisposed && mounted) {
        setState(() {
          _activeReactions.add(reaction);
        });
        // Remove reaction after animation
        Future.delayed(const Duration(seconds: 3), () {
          if (!_isDisposed && mounted) {
            setState(() {
              _activeReactions.remove(reaction);
            });
          }
        });
      }
    };
    
    // Handle video changes from host
    _watchPartyService.onVideoChange = (videoUrl, videoTitle) {
      if (!_isDisposed && mounted && !_watchPartyService.isHost) {
        // Guest should switch to the new video
        _loadVideoFromUrl(videoUrl, videoTitle);
      }
    };
  }
  
  Future<void> _loadVideoFromUrl(String videoUrl, String videoTitle) async {
    try {
      // Mark video as initializing
      _isVideoInitializing = true;
      _lastSeekTime = null;
      _lastSyncedPosition = null;
      _isSyncing = false;
      
      // Extract YouTube video ID
      final videoId = LinkParser.extractYouTubeVideoId(videoUrl);
      if (videoId != null) {
        // Load the new video
        _controller.load(videoId);
        if (mounted) {
          setState(() {
            // Video will be ready when listener fires
          });
        }
        
        // Wait for video to be ready, then allow sync
        // Use a delay to ensure video is fully loaded
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (!_isDisposed && mounted && _controller.value.isReady) {
            _isVideoInitializing = false;
            // Now sync to host's position if available
            final provider = Provider.of<WatchPartyProvider>(context, listen: false);
            final room = provider.currentRoom;
            if (room != null && room.videoUrl == videoUrl) {
              final duration = _controller.value.metaData.duration;
              if (duration.inMilliseconds > 0) {
                final seekPosition = room.currentPosition.inMilliseconds.clamp(
                  0,
                  duration.inMilliseconds
                );
                _controller.seekTo(Duration(milliseconds: seekPosition));
                if (room.isPlaying) {
                  _controller.play();
                } else {
                  _controller.pause();
                }
                _lastSeekTime = DateTime.now();
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading video from watch party: $e');
      _isVideoInitializing = false;
    }
  }

  void _handleSyncMessage(SyncMessage message) {
    if (!_controller.value.isReady) return;
    
    // Don't handle sync messages if video is still initializing or already syncing
    if (_isVideoInitializing || _isSyncing) return;
    
    // Ensure video has valid duration
    final duration = _controller.value.metaData.duration;
    if (duration.inMilliseconds <= 0) return;
    
    // Check if message has room info and verify video URL matches
    if (message.room != null && message.room!.videoUrl.isNotEmpty) {
      final currentVideoUrl = widget.url ?? widget.mediaUrl ?? '';
      if (currentVideoUrl != message.room!.videoUrl) {
        // Video mismatch - load the correct video
        _loadVideoFromUrl(message.room!.videoUrl, message.room!.videoTitle);
        return;
      }
    }
    
    switch (message.type) {
      case SyncMessageType.play:
        _isSyncing = true;
        if (message.position != null) {
          // Ensure position is within valid range
          final seekPosition = message.position!.inMilliseconds.clamp(
            0, 
            duration.inMilliseconds
          );
          // Add debounce to prevent rapid seeks
          final now = DateTime.now();
          if (_lastSeekTime == null || now.difference(_lastSeekTime!).inMilliseconds > 2000) {
            _controller.seekTo(Duration(milliseconds: seekPosition));
            _lastSeekTime = now;
            _lastSyncedPosition = message.position;
          }
        }
        _controller.play();
        // Reset sync flag after delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_isDisposed && mounted) {
            _isSyncing = false;
          }
        });
        break;
      case SyncMessageType.pause:
        _controller.pause();
        break;
      case SyncMessageType.seek:
        if (message.position != null) {
          _isSyncing = true;
          // Ensure position is within valid range
          final seekPosition = message.position!.inMilliseconds.clamp(
            0, 
            duration.inMilliseconds
          );
          // Add debounce to prevent rapid seeks
          final now = DateTime.now();
          if (_lastSeekTime == null || now.difference(_lastSeekTime!).inMilliseconds > 2000) {
            _controller.seekTo(Duration(milliseconds: seekPosition));
            _lastSeekTime = now;
            _lastSyncedPosition = message.position;
          }
          // Reset sync flag after delay
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!_isDisposed && mounted) {
              _isSyncing = false;
            }
          });
        }
        break;
      case SyncMessageType.roomUpdate:
        // Room updates are handled by provider
        break;
      default:
        break;
    }
  }

  Future<void> _showWatchPartyDialog() async {
    final videoUrl = widget.url ?? widget.mediaUrl ?? '';
    final videoTitle = widget.title ?? 'YouTube Video';
    
    final room = await showDialog<WatchPartyRoom>(
      context: context,
      builder: (context) => WatchPartyRoomDialog(
        videoUrl: videoUrl,
        videoTitle: videoTitle,
        currentPosition: _controller.value.position,
        isPlaying: _controller.value.isPlaying,
      ),
    );

    if (room != null && mounted) {
      setState(() {
        _watchPartyRoom = room;
        _showWatchParty = true;
      });
      
      // Start syncing if host
      if (_watchPartyService.isHost) {
        _startHostSync();
      }
    }
  }

  void _startHostSync() {
    _watchPartySyncTimer?.cancel();
    final provider = Provider.of<WatchPartyProvider>(context, listen: false);
    
    // First update with video URL and title when sync starts
    if (provider.isHost && provider.isInRoom) {
      final videoUrl = widget.url ?? widget.mediaUrl ?? '';
      final videoTitle = widget.title ?? 'YouTube Video';
      provider.updateRoomState(
        videoUrl: videoUrl,
        videoTitle: videoTitle,
        position: _controller.value.isReady ? _controller.value.position : Duration.zero,
        isPlaying: _controller.value.isReady ? _controller.value.isPlaying : false,
      );
    }
    
    _watchPartySyncTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isDisposed && _controller.value.isReady) {
        final videoUrl = widget.url ?? widget.mediaUrl ?? '';
        final videoTitle = widget.title ?? 'YouTube Video';
        provider.updateRoomState(
          position: _controller.value.position,
          isPlaying: _controller.value.isPlaying,
          videoUrl: videoUrl,
          videoTitle: videoTitle,
        );
      }
    });
  }

  void _syncPlayPause(bool isPlaying) {
    if (!_watchPartyService.isInRoom) return;
    
    if (_watchPartyService.isHost) {
      _watchPartyService.updateRoomState(isPlaying: isPlaying);
    } else {
      // Guest sends command to host
      _watchPartyService.sendSyncCommand(
        type: isPlaying ? SyncMessageType.play : SyncMessageType.pause,
        position: _controller.value.position,
        isPlaying: isPlaying,
      );
    }
  }

  void _syncSeek(Duration position) {
    if (!_watchPartyService.isInRoom) return;
    
    if (_watchPartyService.isHost) {
      _watchPartyService.updateRoomState(position: position);
    } else {
      // Guest sends command to host
      _watchPartyService.sendSyncCommand(
        type: SyncMessageType.seek,
        position: position,
      );
    }
  }

  void listener() {
    // Update watch party room state if host (when video becomes ready)
    if (_controller.value.isReady && !_wasPlayerReady) {
      _wasPlayerReady = true;
      final provider = Provider.of<WatchPartyProvider>(context, listen: false);
      if (provider.isHost && provider.isInRoom) {
        final videoUrl = widget.url ?? widget.mediaUrl ?? '';
        final videoTitle = widget.title ?? 'YouTube Video';
        provider.updateRoomState(
          videoUrl: videoUrl,
          videoTitle: videoTitle,
          position: _controller.value.position,
          isPlaying: _controller.value.isPlaying,
        );
        // Host: mark as initialized immediately
        _isVideoInitializing = false;
      } else if (!provider.isHost && provider.isInRoom) {
        // Guest: wait a bit before allowing sync to prevent rapid seeks during initialization
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (!_isDisposed && mounted && _controller.value.isReady) {
            _isVideoInitializing = false;
            // Now sync to host's position if available
            final room = provider.currentRoom;
            if (room != null) {
              final videoUrl = widget.url ?? widget.mediaUrl ?? '';
              if (room.videoUrl == videoUrl) {
                final duration = _controller.value.metaData.duration;
                if (duration.inMilliseconds > 0) {
                  final seekPosition = room.currentPosition.inMilliseconds.clamp(
                    0,
                    duration.inMilliseconds
                  );
                  _controller.seekTo(Duration(milliseconds: seekPosition));
                  if (room.isPlaying) {
                    _controller.play();
                  } else {
                    _controller.pause();
                  }
                  _lastSeekTime = DateTime.now();
                  _lastSyncedPosition = room.currentPosition;
                  _isSyncing = false;
                }
              } else if (room.videoUrl.isNotEmpty && room.videoUrl != videoUrl) {
                // Video URL mismatch - load the correct video
                _loadVideoFromUrl(room.videoUrl, room.videoTitle);
              }
            }
          }
        });
      }
    }
    
    if (_isPlayerReady && mounted && !_controller.value.isFullScreen) {
      setState(() {});
    }
    // Timer.periodic(
    //   Duration(seconds: 1),
    //   (timer) => setState(() {
    //     print('caleeedd');
    //   }),
    // );
  }

  void initializeVid() async {
    await Future.delayed(Duration(seconds: 2));
    if (_controller.value.isReady) {
      // Calculate ad positions 10%, 25, 50%, 80%
      final totalDuration = _controller.value.metaData.duration;

      setState(() {
        _adPositions.addAll([
          // Duration(milliseconds: (total_duration.inMilliseconds * 0.1).toInt()),
          // Duration(
          //   milliseconds: (total_duration.inMilliseconds * 0.25).toInt(),
          // ),
          Duration(milliseconds: (totalDuration.inMilliseconds * 0.5).toInt()),
          // Duration(milliseconds: (total_duration.inMilliseconds * 0.8).toInt()),
        ]);
      });

      // Seek to initial position if provided
      if (widget.initialPosition != null) {
        _controller.seekTo(widget.initialPosition!);
      }

        _controller.play();

      // Auto-enter PiP if requested
      if (widget.autoEnterPiP && mounted && !_isDisposed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isDisposed && _controller.value.isReady) {
            _enterPiPMode();
          }
        });
      }

      _controller.addListener(() {
        // trigger ad break
        _onMainVideoUpdate();
        // Trigger UI rebuild for timeline
        if (!_inAdBreak) setState(() {});
      });
    } else {
      // Handle error if video is not initialized
      debugPrint("Video player not initialized");
    }
  }

  void _onMainVideoUpdate() {
    if (!_inAdBreak &&
        _nextAdIndex < _adPositions.length &&
        _controller.value.position >= _adPositions[_nextAdIndex]) {
      _startAdBreak();
    }
  }

  Future<void> _initVolumeAndBrightness() async {
    _brightness = await ScreenBrightness().application;
    _volume = await FlutterVolumeController.getVolume() ?? 0;
  }

  void _startAdBreak() {
    setState(() {
      _inAdBreak = true;
      _showControls = false;
    });

    _controller.pause();

    final adUrl = _adUrls[_nextAdIndex];
    _adController = VideoPlayerController.networkUrl(Uri.parse(adUrl))
      ..initialize().then((_) {
        setState(() {
          _adController!.play();
          _adSecondsRemaining = 3; // Set ad duration to 30 seconds
          // _adSecondsRemaining = _adController!.value.duration.inSeconds;
        });

        _adCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _adSecondsRemaining--;
          });
          if (_adSecondsRemaining <= 0) {
            _endAdBreak();
          }
        });
      });

    _nextAdIndex++;
  }

  void _endAdBreak() {
    _adCountdownTimer?.cancel();
    _adController?.pause();
    _adController?.dispose();
    _adController = null;

    setState(() {
      _inAdBreak = false;
      _showControls = true;
    });

    _controller.play();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _sliderHideTimer?.cancel();
    _hideTimer?.cancel();
    _adCountdownTimer?.cancel();
    _watchPartySyncTimer?.cancel();
    
    // Update watch party room state if host (set video URL to empty when closing)
    try {
      final provider = Provider.of<WatchPartyProvider>(context, listen: false);
      if (provider.isHost && provider.isInRoom) {
        provider.updateRoomState(
          videoUrl: '',
          videoTitle: '',
          position: Duration.zero,
          isPlaying: false,
        );
      }
    } catch (e) {
      // Context might not be available, ignore
    }
    
    _watchPartyService.onRoomUpdate = null;
    _watchPartyService.onSyncMessage = null;
    _watchPartyService.onReaction = null;
    
    if (!_isInPiP) {
      _pipOverlayEntry?.remove();
      _pipOverlayEntry = null;
      _controller.removeListener(listener);
    _controller.dispose();
    } else {
      // In PiP mode, keep the controller alive but remove listener
      // The overlay will handle cleanup when PiP is exited
      _controller.removeListener(listener);
    }

    _adController?.dispose();
    super.dispose();
  }

  // Use shared format time function
  String _formatTime(Duration position) => sharedFormatTime(position);

  // Build video player - YouTube player always uses 16:9 aspect ratio
  Widget _buildVideoPlayer() {
    final player = YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
                progressIndicatorColor: Colors.amber,
                progressColors: const ProgressBarColors(
                  playedColor: Colors.amber,
                  handleColor: Colors.amberAccent,
                ),
                onReady: () {
                  _controller.addListener(listener);
                },
                onEnded: (metaData) {
                  int currentVideoIndex = _ids.indexOf(
                    _controller.metadata.videoId,
                  );
                  if (currentVideoIndex + 1 < _ids.length) {
                    currentVideoIndex++;
                    _controller.load(_ids[currentVideoIndex]);
                  }
                },
    );

    // YouTube player always uses 16:9 aspect ratio
    return Center(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: player,
      ),
    );
  }

  void _enterPiPMode() {
    if (_isInPiP || !mounted || _isDisposed) return;

    // Use root navigator to get the overlay - this persists after route pop
    final navigatorState = Navigator.of(context, rootNavigator: true);
    final overlay = navigatorState.overlay;
    if (overlay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PiP mode not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Reset orientation to portrait before entering PiP
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);

    // Hide controls and enter PiP
    setState(() {
      _isInPiP = true;
      _showControls = false;
    });

    // Create overlay entry for PiP - pass controller reference
    final controllerRef = _controller;
    _pipOverlayEntry = OverlayEntry(
      builder: (context) => _buildPiPOverlay(controllerRef),
    );

    // Insert overlay in root navigator's overlay
    overlay.insert(_pipOverlayEntry!);

    // Use post-frame callback to ensure overlay is inserted before popping
    // Add a small delay to ensure overlay is fully rendered
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && !_isDisposed) {
        // Navigate back to previous screen
        Navigator.pop(context);
      }
    });
  }

  void _exitPiPMode() {
    if (!_isInPiP) return;

    // Remove overlay
    _pipOverlayEntry?.remove();
    _pipOverlayEntry = null;

    // Clean up controller if widget was disposed
    if (_isDisposed) {
      _controller.removeListener(listener);
      _controller.dispose();
    } else if (mounted) {
      setState(() {
        _isInPiP = false;
        _showControls = true;
      });
    }
  }

  Widget _buildPiPOverlay(YoutubePlayerController controller) {
    // Use Builder to get a valid context from the overlay
    return Builder(
      builder: (overlayContext) {
        // Use StatefulBuilder to manage local state for position
        return StatefulBuilder(
          builder: (context, setOverlayState) {
            return Positioned(
              left: _pipPosition.dx,
              top: _pipPosition.dy,
              child: GestureDetector(
                key: _pipKey,
                onPanUpdate: (details) {
                  setOverlayState(() {
                    _pipPosition += details.delta;
                    // Keep within screen bounds
                    final screenSize = MediaQuery.of(overlayContext).size;
                    _pipPosition = Offset(
                      _pipPosition.dx.clamp(0.0, screenSize.width - 200),
                      _pipPosition.dy.clamp(0.0, screenSize.height - 150),
                    );
                  });
                  _pipOverlayEntry?.markNeedsBuild();
                },
                onTap: () {
                  // Single tap - toggle play/pause instead of exiting
                  if (controller.value.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                },
                onLongPress: () {
                  // Long press to exit PiP
                  _exitPiPMode();
                },
                child: Container(
                  width: 200,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        // Video player in PiP
                        ValueListenableBuilder<YoutubePlayerValue>(
                          valueListenable: controller,
                          builder: (context, value, child) {
                            return AspectRatio(
                              aspectRatio: 16 / 9,
                              child: YoutubePlayer(
                                controller: controller,
                                showVideoProgressIndicator: false,
                              ),
                            );
                          },
                        ),
                        // Control buttons row
              Positioned(
                          top: 4,
                          left: 4,
                          right: 4,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
                              // Full screen button
                              GestureDetector(
                                onTap: () {
                                  // Store current position before exiting
                                  final currentPosition = controller.value.position;

                                  // Remove PiP overlay but keep controller alive
                                  _pipOverlayEntry?.remove();
                                  _pipOverlayEntry = null;

                                  // Re-open video player in full screen with preserved position
                                  // Use a small delay to ensure overlay is removed
                                  Future.delayed(
                                    const Duration(milliseconds: 100),
                                    () {
                                      // Mark PiP as exited after pushing new route
                                      _isInPiP = false;
                                      
                                      navigatorKey.currentState?.push(
                                        MaterialPageRoute(
                                          builder: (context) => YTFull(
                                            videoId: widget.videoId,
                                            title: widget.title,
                                            description: widget.description,
                                            initialPosition: currentPosition,
                                            url: widget.url,
                                            listIds: widget.listIds,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.fullscreen,
                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                              // Close button
                              GestureDetector(
                onTap: () {
                                  controller.pause();
                                  _exitPiPMode();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                    color: Colors.white,
                                    size: 16,
                  ),
                                ),
                ),
            ],
          ),
              ),
                        // Play/Pause button overlay
                        ValueListenableBuilder<YoutubePlayerValue>(
                          valueListenable: controller,
                          builder: (context, value, child) {
                            // Show play button when paused
                            if (!value.isPlaying) {
                              return Center(
                                child: GestureDetector(
                onTap: () {
                                    controller.play();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow,
                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
      ),
    );
  }
                            return const SizedBox.shrink();
                          },
                    ),
                  ],
                ),
              ),
            ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop == true) {
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: Stack(
        children: [
            if (_inAdBreak &&
                _adController != null &&
                _adController!.value.isInitialized)
              VideoPlayer(_adController!)
            else if (!_inAdBreak)
              _buildVideoPlayer()
            else
              const Center(child: CircularProgressIndicator()),

            // Black overlay
            if (_showControls)
              const Positioned.fill(child: SharedControlsOverlay()),
            if (_inAdBreak)
              SharedAdCountdownOverlay(secondsRemaining: _adSecondsRemaining),

            if (!_inAdBreak) ...[
              SharedGestureDetectorOverlay(
                onTap: () {
                  setState(() {
                    _showControls = !_showControls;
                  });
                },
                onDoubleTap: (isRight) {
                  if (isRight) {
                    final newPosition = _controller.value.position + const Duration(seconds: 10);
                    _controller.seekTo(newPosition);
                    _syncSeek(newPosition);
                  } else {
                    final newPosition = _controller.value.position - const Duration(seconds: 10);
                    _controller.seekTo(newPosition);
                    _syncSeek(newPosition);
                  }
                },
                onVerticalDrag: (isRight, delta) {
                  if (isRight) {
                    // Volume
                    _volume = (_volume + delta).clamp(0.0, 1.0);
                    FlutterVolumeController.updateShowSystemUI(false);
                    FlutterVolumeController.setVolume(_volume);
                    _showSliderOverlay(isVolume: true);
                  } else {
                    // Brightness
                    _brightness = (_brightness + delta).clamp(0.0, 1.0);
                    ScreenBrightness.instance.setApplicationScreenBrightness(
                      _brightness,
                    );
                    _showSliderOverlay(isVolume: false);
                  }
                },
              ),
              if (_showBrightnessSlider || (_showControls && !_isLocked))
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: SharedBrightnessOverlay(brightness: _brightness),
                  ),
                ),
              if (_showVolumeSlider || (_showControls && !_isLocked))
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: SharedVolumeOverlay(volume: _volume),
                  ),
                ),
              SharedVideoAppBar(
                title: _controller.metadata.title.isNotEmpty
                    ? _controller.metadata.title
                    : widget.title ?? 'Video',
                showControls: _showControls,
                isLocked: _isLocked,
                onLockToggle: () {
                  setState(() {
                    _isLocked = !_isLocked;
                  });
                },
              ),
              if (_showControls && !_isLocked)
                ValueListenableBuilder<YoutubePlayerValue>(
                  valueListenable: _controller,
                  builder: (context, value, child) {
                    return SharedPlayPauseControlBar(
                      isPlaying: value.isPlaying,
                      onPlayPause: () {
                        if (value.isPlaying) {
                          _controller.pause();
                          _syncPlayPause(false);
                        } else {
                          _controller.play();
                          _syncPlayPause(true);
                        }
                      },
                      onSkipBackward: () {
                        final newPosition = _controller.value.position -
                            const Duration(seconds: 10);
                        _controller.seekTo(newPosition);
                        _syncSeek(newPosition);
                      },
                      onSkipForward: () {
                        final newPosition = _controller.value.position +
                            const Duration(seconds: 10);
                        _controller.seekTo(newPosition);
                        _syncSeek(newPosition);
                      },
                    );
                  },
                ),
              if (_showControls && !_isLocked)
                Positioned(
                  bottom: 0,
                  child: ControlBar(formatTime: sharedFormatTime),
                ),
              if (_showControls && _showEpisodeList && !_isLocked)
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: ListContentOverlay(
                    url: widget.url,
                    listIds: widget.listIds,
                    currentVideoId: _controller.metadata.videoId,
                  ),
                ),
              if (_showControls && _showWatchParty && _watchPartyRoom != null && !_isLocked)
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  left: 0,
                  child: WatchPartyParticipantsOverlay(
                    room: _watchPartyRoom!,
                    isHost: _watchPartyService.isHost,
                    onClose: () {
                      if (mounted) {
                        setState(() {
                          _showWatchParty = false;
                        });
                      }
                    },
                  ),
                ),
              // Show active reactions on video
              ..._activeReactions.map((reaction) => WatchPartyReactionOverlay(
                    reaction: reaction,
                    onComplete: () {
                      if (mounted) {
                        setState(() {
                          _activeReactions.remove(reaction);
                        });
                      }
                    },
                  )),
              // Show chat notification overlay
              if (_latestChatMessage != null)
                Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: WatchPartyChatNotification(
                    message: _latestChatMessage!,
                onTap: () {
                  setState(() {
                        _showWatchParty = true;
                  });
                },
                    onComplete: () {
                      if (mounted) {
                        setState(() {
                          _latestChatMessage = null;
                        });
                      }
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class ControlBar extends StatefulWidget {
  final String Function(Duration) formatTime;

  const ControlBar({super.key, required this.formatTime});

  @override
  ControlBarState createState() => ControlBarState();
}

class ControlBarState extends State<ControlBar> {
  bool _isDragging = false;
  double _dragValue = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_YTFullState>()!;
    final controller = state._controller;

    // Use ValueListenableBuilder to update when controller value changes
    return ValueListenableBuilder<YoutubePlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final isReady = value.isReady;
        final position = value.position;
        final duration = value.metaData.duration;

        // Check if video is initialized and has valid duration
        final bool isInitialized =
            isReady && duration.inMilliseconds > 0;

    // compute slider values
    final maxMillis = duration.inMilliseconds.toDouble();
    final currentMillis = _isDragging
        ? _dragValue
        : position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble();

    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Column(
        children: [
          // Progress + times
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // current time
                Text(
                  isInitialized ? widget.formatTime(position) : '00:00:00',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 5),

                // slider progress bar with thumb
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 15,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                      thumbColor: Colors.amber,
                      activeTrackColor: Colors.amber,
                      inactiveTrackColor: Colors.grey,
                      overlayColor: Colors.amber.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      min: 0,
                      max: maxMillis > 0 ? maxMillis : 1,
                      value: currentMillis,
                      onChangeStart: (v) {
                        setState(() {
                          _isDragging = true;
                          _dragValue = v;
                        });
                      },
                      onChanged: (v) {
                        setState(() {
                          _dragValue = v;
                        });
                      },
                      onChangeEnd: (v) {
                        final seekPosition = Duration(milliseconds: v.toInt());
                        controller.seekTo(seekPosition);
                        state._syncSeek(seekPosition);
                        setState(() {
                          _isDragging = false;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 5),
                // total time
                Text(
                  isInitialized ? widget.formatTime(duration) : '00:00:00',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

          // the rest of your controls (speed, episode, fullscreen, etc.) unchanged...
          Padding(
            padding: const EdgeInsets.only(left: 18.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // speed menu...
                PopupMenuButton<double>(
                  color: Colors.black,
                  initialValue: controller.value.playbackRate,
                  onSelected: (s) => controller.setPlaybackRate(s),
                  itemBuilder: (_) {
                    const textStyle = TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                    );
                    return const [
                      PopupMenuItem(
                        value: 0.5,
                        child: Text("0.5x", style: textStyle),
                      ),
                      PopupMenuItem(
                        value: 1.0,
                        child: Text("1.0x", style: textStyle),
                      ),
                      PopupMenuItem(
                        value: 1.5,
                        child: Text("1.5x", style: textStyle),
                      ),
                      PopupMenuItem(
                        value: 2.0,
                        child: Text("2.0x", style: textStyle),
                      ),
                    ];
                  },
                  child: Row(
                    children: [
                      Icon(Icons.speed, color: Colors.white),
                      const SizedBox(width: 5),
                      const Text(
                        "Speed ",
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "(${controller.value.playbackRate}x)",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),

                // episode, settings, PiP, fullscreen...
                Row(
                  children: [
                    TextButton.icon(
                      icon: Icon(
                        Icons.playlist_play,
                        color: state._showEpisodeList
                            ? Colors.amber
                            : Colors.white,
                      ),
                      label: Text(
                        "List Content",
                        style: TextStyle(
                          color: state._showEpisodeList
                              ? Colors.amber
                              : Colors.white,
                        ),
                      ),
                      onPressed: () =>
                          state.setState(() => state._showEpisodeList = true),
                    ),
                    TextButton.icon(
                      icon: Icon(
                        Icons.people,
                        color: state._watchPartyRoom != null
                            ? Colors.amber
                            : Colors.white,
                      ),
                      label: Text(
                        "Watch Party",
                        style: TextStyle(
                          color: state._watchPartyRoom != null
                              ? Colors.amber
                              : Colors.white,
                        ),
                      ),
                      onPressed: () {
                        if (state.mounted) {
                          if (state._watchPartyRoom != null) {
                            state.setState(() => state._showWatchParty = true);
                          } else {
                            state._showWatchPartyDialog();
                          }
                        }
                      },
                    ),
                    IconButton(
                      onPressed: () {
                        if (state._isInPiP) {
                          state._exitPiPMode();
                        } else {
                          state._enterPiPMode();
                        }
                      },
                      icon: Icon(
                        state._isInPiP
                            ? Icons.picture_in_picture_outlined
                            : Icons.picture_in_picture_alt_rounded,
                        color: Colors.white,
                      ),
                      tooltip: state._isInPiP ? 'Exit PiP' : 'Enter PiP',
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.fullscreen_exit,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitUp,
                        ]);
                        SystemChrome.setEnabledSystemUIMode(
                          SystemUiMode.leanBack,
                        );
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

// ... include your existing GestureDetectorOverlay, PlayPauseControlBar, and EpisodeListOverlay classes unchanged ...

class GestureDetectorOverlay extends StatelessWidget {
  const GestureDetectorOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_YTFullState>()!;

    void startHideTimer() {
      state._hideTimer?.cancel(); // Cancel any existing timer

      state._hideTimer = Timer(Duration(seconds: 3), () {
        state.setState(() {
          state._showControls = false;
        });
      });
    }

    void toggleControls() {
      state.setState(() {
        state._showControls = !state._showControls;
      });

      // TODO: Uncomment this to hide controls after a delay
      // if (state._showControls) {
      //   _startHideTimer(); // Start or reset timer when controls are shown
      // } else {
      //   state._hideTimer?.cancel(); // Cancel if manually hidden
      // }
    }

    return GestureDetector(
      onTap: toggleControls,
      onDoubleTapDown: (d) {
        state.setState(() {
          final width = MediaQuery.of(context).size.width;
          final isRight = d.localPosition.dx > width / 2;

          if (isRight) {
            // Skip forward 10 seconds
            state._controller.seekTo(
              state._controller.value.position + Duration(seconds: 10),
            );
            state.setState(() {});
          } else {
            // Skip backward 10 seconds
            state._controller.seekTo(
              state._controller.value.position - Duration(seconds: 10),
            );
            state.setState(() {});
          }
        });
      },
      onHorizontalDragUpdate: (d) {
        final delta = d.primaryDelta!;
        state._controller.seekTo(
          state._controller.value.position +
              Duration(milliseconds: (delta * 1000).toInt()),
        );
        state.setState(() {});
      },
      onVerticalDragUpdate: (d) {
        final width = MediaQuery.of(context).size.width;
        final isRight = d.localPosition.dx > width / 2;
        final delta = -d.primaryDelta! / 300;

        if (isRight) {
          // Volume
          state._volume = (state._volume + delta).clamp(0.0, 1.0);
          FlutterVolumeController.updateShowSystemUI(false);
          FlutterVolumeController.setVolume(state._volume);
          state._showSliderOverlay(isVolume: true);
        } else {
          // Brightness
          state._brightness = (state._brightness + delta).clamp(0.0, 1.0);
          ScreenBrightness.instance.setApplicationScreenBrightness(
            state._brightness,
          );
          state._showSliderOverlay(isVolume: false);
        }
      },
      child: Container(color: Colors.black.withValues(alpha: 0.1)),
    );
  }
}

class PlayPauseControlBar extends StatelessWidget {
  const PlayPauseControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_YTFullState>()!;
    final controller = state._controller;
    final iconSize = 120.0;

    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Skip‑back 10s
              Container(
                margin: const EdgeInsets.only(left: 100),
                width: iconSize,
                height: iconSize,
                child: IconButton(
                  icon: Icon(Icons.replay_10_rounded, color: Colors.white),
                  onPressed: () => state.setState(() {
                    controller.seekTo(
                      controller.value.position - const Duration(seconds: 10),
                    );
                  }),
                ),
              ),

              // Play/Pause button listens to controller.value changes
              ValueListenableBuilder<YoutubePlayerValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  return IconButton(
                    iconSize: 50,
                    color: Colors.white,
                    onPressed: () {
                      if (value.isPlaying) {
                        controller.pause();
                      } else {
                        controller.play();
                      }
                    },
                    icon: Icon(
                      value.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                  );
                },
              ),
              Container(
                margin: EdgeInsets.only(right: 100),
                width: iconSize,
                height: iconSize,
                child: IconButton(
                  icon: Icon(Icons.forward_10_rounded, color: Colors.white),
                  onPressed: () => state.setState(() {
                    state._controller.seekTo(
                      state._controller.value.position + Duration(seconds: 10),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ListContentOverlay extends StatefulWidget {
  final String? url;
  final List<String>? listIds;
  final String? currentVideoId;

  const ListContentOverlay({
    super.key,
    this.url,
    this.listIds,
    this.currentVideoId,
  });

  @override
  State<ListContentOverlay> createState() => _ListContentOverlayState();
}

class _ListContentOverlayState extends State<ListContentOverlay>
    with SingleTickerProviderStateMixin {
  List<UserList> _lists = [];
  List<List<SavedLink>> _listVideos = [];
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _loadListsAndVideos();
  }

  Future<void> _loadListsAndVideos() async {
    setState(() => _isLoading = true);
    try {
      // Get all lists
      final allLists = await StorageService.getUserLists();
      
      // Get list IDs for current video
      List<String> targetListIds = widget.listIds ?? [];
      if (targetListIds.isEmpty && widget.url != null) {
        // Try to find the link by URL
        final allLinks = await StorageService.getSavedLinks();
        try {
          final currentLink = allLinks.firstWhere((l) => l.url == widget.url);
          targetListIds = currentLink.listIds;
        } catch (e) {
          // Link not found, use default list
          targetListIds = [StorageService.defaultListId];
        }
      }
      
      if (targetListIds.isEmpty) {
        targetListIds = [StorageService.defaultListId];
      }

      // Show ALL lists, not just those containing this video
      _lists = allLists;
      
      // Find the index of the first list that contains this video (for default selection)
      // Prioritize the primary list (first in targetListIds)
      int defaultTabIndex = 0;
      if (targetListIds.isNotEmpty) {
        final primaryListId = targetListIds.first;
        // First try to find the primary list
        for (int i = 0; i < _lists.length; i++) {
          if (_lists[i].id == primaryListId) {
            defaultTabIndex = i;
            break;
          }
        }
        // If primary list not found, find any list containing the video
        if (defaultTabIndex == 0 && !targetListIds.contains(_lists[0].id)) {
          for (int i = 0; i < _lists.length; i++) {
            if (targetListIds.contains(_lists[i].id)) {
              defaultTabIndex = i;
              break;
            }
          }
        }
      }

      // Load videos for each list
      final allLinks = await StorageService.getSavedLinks();
      _listVideos = _lists.map((list) {
        final videos = allLinks
            .where((link) => link.listIds.contains(list.id))
            .toList();
        // Sort by date (latest first)
        videos.sort((a, b) => b.savedAt.compareTo(a.savedAt));
        return videos;
      }).toList();

      // Initialize tab controller
      if (_lists.isNotEmpty) {
        _tabController = TabController(
          length: _lists.length,
          initialIndex: defaultTabIndex,
          vsync: this,
        );
        _selectedTabIndex = defaultTabIndex;
        _tabController!.addListener(() {
          if (_tabController!.indexIsChanging) {
            setState(() => _selectedTabIndex = _tabController!.index);
          }
        });
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _playVideo(SavedLink link) {
    final state = context.findAncestorStateOfType<_YTFullState>()!;
    
    if (link.type == LinkType.youtube) {
      final videoId = LinkParser.extractYouTubeVideoId(link.url);
      if (videoId != null) {
        state._controller.load(videoId);
        if (mounted) {
          setState(() => state._showEpisodeList = false);
        }
        
        // Update watch party room state if host
        if (state._watchPartyService.isHost && state._watchPartyRoom != null) {
          state._watchPartyService.updateRoomState(
            videoUrl: link.url,
            videoTitle: link.title.isNotEmpty ? link.title : 'YouTube Video',
            position: Duration.zero,
            isPlaying: false,
          );
        }
      }
    } else {
      // For non-YouTube videos, navigate to detail page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoDetailScreen(link: link),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: MediaQuery.of(context).size.width / 2,
        decoration: const BoxDecoration(color: Color.fromARGB(223, 0, 0, 0)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_lists.isEmpty) {
      return Container(
        width: MediaQuery.of(context).size.width / 2,
        decoration: const BoxDecoration(color: Color.fromARGB(223, 0, 0, 0)),
        child: const Center(
          child: Text(
            'No lists available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Container(
      width: MediaQuery.of(context).size.width / 2,
      decoration: const BoxDecoration(color: Color.fromARGB(223, 0, 0, 0)),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(left: 12.0, top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Lists',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    final state = context.findAncestorStateOfType<_YTFullState>()!;
                    state.setState(() => state._showEpisodeList = false);
                  },
                ),
              ],
            ),
          ),
          
          // Tab Bar
          if (_tabController != null)
            TabBar(
              controller: _tabController,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.only(left: 10.0),
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white,
              tabs: _lists.asMap().entries.map((entry) {
                final index = entry.key;
                final list = entry.value;
                final isSelected = _selectedTabIndex == index;
                return Tab(
      child: Container(
                    height: 40.0,
                    decoration: !isSelected
                        ? BoxDecoration(
                            color: const Color(0xff2C2C2C),
                            borderRadius: BorderRadius.circular(100.0),
                          )
                        : BoxDecoration(
                            color: const Color(0xff16A34A),
                            borderRadius: BorderRadius.circular(100.0),
                          ),
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Center(
                      child: Text(
                        list.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                );
              }).toList(),
              indicator: const BoxDecoration(),
            ),
          
          const SizedBox(height: 5),
          
          // Videos List
          Expanded(
            child: _listVideos.isEmpty || _selectedTabIndex >= _listVideos.length
                ? const Center(
                    child: Text(
                      'No videos in this list',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    itemCount: _listVideos[_selectedTabIndex].length,
                    itemBuilder: (context, index) {
                      final video = _listVideos[_selectedTabIndex][index];
                      final isCurrentVideo = widget.currentVideoId != null &&
                          video.type == LinkType.youtube &&
                          LinkParser.extractYouTubeVideoId(video.url) == widget.currentVideoId;
                      
                      return GestureDetector(
                        onTap: () => _playVideo(video),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
                          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
                          color: isCurrentVideo ? Colors.amber.withOpacity(0.2) : Colors.transparent,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    ThumbnailImage(
                                      link: video,
                                      width: 50,
                                      height: 35,
                                    ),
                                    Container(
                                      width: 50,
                                      height: 35,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.play_circle_fill_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Text(
                                        video.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isCurrentVideo
                                              ? Colors.amber
                                              : Theme.of(context).primaryColor,
                                          fontSize: 12,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (video.description != null && video.description!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          video.description!,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class EpisodeViewMovieScreen extends StatelessWidget {
  const EpisodeViewMovieScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 0),
      child: Column(
        // shrinkWrap: true,
        // primary: false,
        // physics: NeverScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Seasons',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    final state = context
                        .findAncestorStateOfType<_YTFullState>()!;
                    state.setState(() => state._showEpisodeList = false);
                  },
                ),
              ],
            ),
          ),
          DefaultTabController(
            length: 2,
            child: TabBar(
              padding: EdgeInsets.zero,
              labelPadding: EdgeInsets.only(left: 10.0),
              isScrollable: true,

              labelColor: Colors.white, // Text color when selected
              unselectedLabelColor: Colors.white,
              tabs: List.generate(2, (index) {
                bool isSelected = 0 == index;
                return Tab(
                  child: Container(
                    height: 40.0,

                    // width: 80.w,
                    decoration: !isSelected
                        ? BoxDecoration(
                            color: Color(0xff2C2C2C),
                            // color: Color(0xff16A34A),
                            borderRadius: BorderRadius.circular(100.0),
                          )
                        : BoxDecoration(
                            color: Color(0xff16A34A),
                            borderRadius: BorderRadius.circular(100.0),
                          ),
                    padding: EdgeInsets.symmetric(
                      horizontal: !isSelected ? 12.0 : 12.0,
                    ),
                    child: Center(
                      child: Text(
                        'Season ${index + 1}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          // fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
              onTap: (index) {},
              indicator: BoxDecoration(),
            ),
          ),
          SizedBox(height: 5),
          Expanded(child: CustomEpisodeCard()),
          // SizedBox(height: 380, child: CustomEpisodeCard()),
        ],
      ),
    );
  }
}

class CustomEpisodeCard extends StatelessWidget {
  const CustomEpisodeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      primary: false,
      itemCount: 12,
      itemBuilder: (_, index) => GestureDetector(
        onTap: () {
          final state = context.findAncestorStateOfType<_YTFullState>()!;
          int currentVideoIndex = state._ids.indexOf(
            state._controller.metadata.videoId,
          );
          if (currentVideoIndex + 1 < state._ids.length) {
            currentVideoIndex++;
            state._controller.load(state._ids[currentVideoIndex]);
          }
        },
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 0, horizontal: 0),
          decoration: BoxDecoration(),
          padding: EdgeInsets.symmetric(vertical: 2, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      'assets/images/violet_evergarden.jpg',
                      width: 50,
                      height: 35,
                      fit: BoxFit.cover,
                    ),
                    Container(
                      width: 50,
                      height: 35,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 8,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 2),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        'Darkness Rising - Episode ${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        // episode loremipsum description
                        'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
