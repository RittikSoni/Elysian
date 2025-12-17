// ignore_for_file: invalid_use_of_protected_member, unused_element

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:elysian/utils/kroute.dart';
import 'package:elysian/video_player/shared_video_widgets.dart';
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

// VideoFitMode is now in shared_video_widgets.dart

class RSNewVideoPlayerScreen extends StatefulWidget {
  final String? mediaUrl;
  final VoidCallback? onError;
  final Duration? initialPosition; // Optional initial position to seek to
  final String? url; // Full URL to find the link in storage
  final List<String>? listIds; // List IDs this video belongs to
  final bool autoEnterPiP; // Auto-enter PiP mode after initialization
  final String? title; // Video title
  final bool adsEnabled; // Enable/disable ads

  const RSNewVideoPlayerScreen({
    super.key,
    this.mediaUrl,
    this.onError,
    this.initialPosition,
    this.url,
    this.listIds,
    this.autoEnterPiP = false,
    this.title,
    this.adsEnabled = false, // Default to false
  });

  @override
  State<RSNewVideoPlayerScreen> createState() => _RSNewVideoPlayerScreenState();
}

class _RSNewVideoPlayerScreenState extends State<RSNewVideoPlayerScreen> {
  late VideoPlayerController _controller;
  VideoPlayerController? _adController;
  String? _videoTitle;
  String? _currentVideoUrl; // Track current playing video URL for overlay

  // UI state
  bool _showControls = true;
  bool _showEpisodeList = false;
  bool _showWatchParty = false;
  double _brightness = 0.5, _volume = 0.5;
  bool _showVolumeSlider = false;
  bool _showBrightnessSlider = false;
  Timer? _sliderHideTimer;
  Timer? _hideTimer;
  bool _isDisposed = false;

  // WatchParty state
  final _watchPartyService = WatchPartyService();
  WatchPartyRoom? _watchPartyRoom;
  Timer? _watchPartySyncTimer;
  final List<Reaction> _activeReactions = [];
  ChatMessage? _latestChatMessage;
  bool _isVideoInitializing =
      false; // Track if video is being loaded/initialized
  DateTime? _lastSeekTime; // Track last seek to prevent rapid seeks
  bool _isSyncing = false; // Flag to prevent concurrent sync operations
  Duration?
  _lastSyncedPosition; // Track last synced position to avoid unnecessary seeks

  // Ad state
  final List<Duration> _adPositions = [];

  final List<String> _adUrls = [
    // 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    // 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
    // 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    // 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
  ];
  int _nextAdIndex = 0;
  bool _inAdBreak = false;
  int _adSecondsRemaining = 0;
  Timer? _adCountdownTimer;

  bool _isLocked = false;

  // Video fit mode
  VideoFitMode _videoFitMode = VideoFitMode.fit;

  // PiP state
  bool _isInPiP = false;
  OverlayEntry? _pipOverlayEntry;
  Offset _pipPosition = const Offset(20, 100);
  final GlobalKey _pipKey = GlobalKey();

  // call this to show one slider and auto‐hide it
  void _showSliderOverlay({required bool isVolume}) {
    if (_isDisposed || !mounted) return;
    _sliderHideTimer?.cancel();
    setState(() {
      _showVolumeSlider = isVolume;
      _showBrightnessSlider = !isVolume;
    });
    _sliderHideTimer = Timer(Duration(seconds: 1, milliseconds: 500), () {
      if (!_isDisposed && mounted) {
        setState(() {
          _showVolumeSlider = false;
          _showBrightnessSlider = false;
        });
      }
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
    _loadVideoTitle();
    _currentVideoUrl =
        widget.url ?? widget.mediaUrl; // Initialize current video URL
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(_currentVideoUrl ?? ''),
    );
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
        if (!_watchPartyService.isHost && _controller.value.isInitialized) {
          // Don't sync if video is still initializing or already syncing
          if (_isVideoInitializing || _isSyncing) return;

          // Ensure video has valid duration before syncing
          final duration = _controller.value.duration;
          if (duration.inMilliseconds <= 0) return;

          // Check if current video URL matches room video URL
          // If not, trigger video change to load correct video
          if (room.videoUrl.isNotEmpty &&
              widget.url != room.videoUrl &&
              _currentVideoUrl != room.videoUrl) {
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

          // Sync position with position prediction for better accuracy
          final now = DateTime.now();
          final currentPosition = _controller.value.position;

          // Calculate predicted host position based on elapsed time since last update
          Duration predictedHostPosition = room.currentPosition;
          if (room.isPlaying && room.positionUpdatedAt != null) {
            final elapsedMs = now
                .difference(room.positionUpdatedAt!)
                .inMilliseconds;
            predictedHostPosition = Duration(
              milliseconds: room.currentPosition.inMilliseconds + elapsedMs,
            );
            // Clamp to video duration
            if (predictedHostPosition.inMilliseconds >
                duration.inMilliseconds) {
              predictedHostPosition = duration;
            }
          }

          // Only sync if:
          // 1. Enough time has passed since last seek (1 second debounce - reduced for better sync)
          // 2. Position difference is significant (1+ seconds - reduced threshold)
          // 3. Video is playing OR paused (sync during pauses too for accuracy)
          // 4. Position actually changed from last sync
          if (_lastSeekTime == null ||
              now.difference(_lastSeekTime!).inMilliseconds > 1000) {
            // Use predicted position if video is playing, otherwise use actual position
            final targetPosition = room.isPlaying
                ? predictedHostPosition
                : room.currentPosition;

            final positionDiff =
                (targetPosition.inMilliseconds - currentPosition.inMilliseconds)
                    .abs();

            // Check if position changed significantly from last synced position
            final lastSyncedDiff = _lastSyncedPosition != null
                ? (targetPosition.inMilliseconds -
                          _lastSyncedPosition!.inMilliseconds)
                      .abs()
                : 999999;

            // Only seek if:
            // - Difference is more than 1 second (reduced threshold for better sync)
            // - Host position actually changed (not just polling noise)
            // - Or if this is initial sync (lastSyncedPosition is null)
            if ((positionDiff > 1000 && lastSyncedDiff > 200) ||
                _lastSyncedPosition == null) {
              _isSyncing = true;
              // Ensure seek position is within valid range
              final seekPosition = targetPosition.inMilliseconds.clamp(
                0,
                duration.inMilliseconds,
              );
              _controller.seekTo(Duration(milliseconds: seekPosition));
              _lastSeekTime = now;
              _lastSyncedPosition = targetPosition;

              // Reset sync flag after a short delay
              Future.delayed(const Duration(milliseconds: 300), () {
                if (!_isDisposed && mounted) {
                  _isSyncing = false;
                }
              });
            } else {
              // Update last synced position even if we don't seek
              _lastSyncedPosition = targetPosition;
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
      // Find the link in storage
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

      // Check if video can be played in-app
      if (link.type.canPlayInbuilt) {
        // Replace current video
        await _replaceVideo(link);
      } else {
        // External link - show message and open externally
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text(
                'External Video',
                style: TextStyle(color: Colors.white),
              ),
              content: Text(
                'This video cannot be played in the built-in player. Opening externally...',
                style: TextStyle(color: Colors.grey[300]),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Open externally
                    launchUrl(
                      Uri.parse(videoUrl),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: const Text('Open'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading video from watch party: $e');
    }
  }

  void _handleSyncMessage(SyncMessage message) {
    if (!_controller.value.isInitialized) return;

    // Don't handle sync messages if video is still initializing or already syncing
    if (_isVideoInitializing || _isSyncing) return;

    // Ensure video has valid duration
    final duration = _controller.value.duration;
    if (duration.inMilliseconds <= 0) return;

    // Check if message has room info and verify video URL matches
    if (message.room != null && message.room!.videoUrl.isNotEmpty) {
      if (widget.url != message.room!.videoUrl &&
          _currentVideoUrl != message.room!.videoUrl) {
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
            duration.inMilliseconds,
          );
          // Add debounce to prevent rapid seeks
          final now = DateTime.now();
          if (_lastSeekTime == null ||
              now.difference(_lastSeekTime!).inMilliseconds > 2000) {
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
            duration.inMilliseconds,
          );
          // Add debounce to prevent rapid seeks
          final now = DateTime.now();
          if (_lastSeekTime == null ||
              now.difference(_lastSeekTime!).inMilliseconds > 2000) {
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
    final room = await showDialog<WatchPartyRoom>(
      context: context,
      builder: (context) => WatchPartyRoomDialog(
        videoUrl: widget.url ?? widget.mediaUrl ?? '',
        videoTitle: _videoTitle ?? 'Video',
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
    if (provider.isHost && provider.isInRoom && widget.url != null) {
      provider.updateRoomState(
        videoUrl: widget.url!,
        videoTitle: _videoTitle ?? widget.title ?? 'Video',
        position: _controller.value.isInitialized
            ? _controller.value.position
            : Duration.zero,
        isPlaying: _controller.value.isInitialized
            ? _controller.value.isPlaying
            : false,
      );
    }

    // No longer using continuous sync - sync is now button-based
    // Auto-sync only happens on video start or when late joiners join
  }

  /// Manual sync button handler (host only)
  void _manualSync() {
    if (!_watchPartyService.isHost || !_watchPartyService.isInRoom) return;
    if (!_controller.value.isInitialized) return;

    final provider = Provider.of<WatchPartyProvider>(context, listen: false);
    provider.updateRoomState(
      position: _controller.value.position,
      isPlaying: _controller.value.isPlaying,
      videoUrl: widget.url,
      videoTitle: _videoTitle ?? widget.title,
    );
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

  Future<void> _loadVideoTitle() async {
    // Use provided title or try to get from storage
    if (widget.title != null) {
      _videoTitle = widget.title;
      return;
    }

    if (widget.url != null) {
      try {
        final allLinks = await StorageService.getSavedLinks();
        final link = allLinks.firstWhere((l) => l.url == widget.url);
        _videoTitle = link.title;
        if (mounted) setState(() {});
      } catch (e) {
        // Link not found, keep title as null
      }
    }
  }

  Future<void> _replaceVideo(SavedLink link) async {
    if (_isDisposed || !mounted) return;

    // Mark video as initializing
    _isVideoInitializing = true;
    _lastSeekTime = null;

    // Stop and dispose current controller - ensure audio is stopped
    _controller.pause();
    await Future.delayed(const Duration(milliseconds: 100)); // Give time for audio to stop
    _controller.removeListener(_videoPlayerListener);
    await _controller.dispose();
    await Future.delayed(const Duration(milliseconds: 100)); // Additional delay to ensure cleanup

    // Clear ad state
    _adController?.pause();
    await _adController?.dispose();
    _adController = null;
    _adCountdownTimer?.cancel();
    _adPositions.clear();
    _nextAdIndex = 0;
    _inAdBreak = false;

    // Update title and current video URL
    _videoTitle = link.title;
    _currentVideoUrl = link.url;

    // Update watch party room state if host
    final provider = Provider.of<WatchPartyProvider>(context, listen: false);
    if (provider.isHost && provider.isInRoom) {
      provider.updateRoomState(
        videoUrl: link.url,
        videoTitle: link.title,
        position: Duration.zero,
        isPlaying: false,
      );
    }

    // Create new controller
    _controller = VideoPlayerController.networkUrl(Uri.parse(link.url));
    _controller.addListener(_videoPlayerListener);

    // Initialize and play
    initializeVid();

    if (mounted) {
      setState(() {
        _showControls = true;
      });
    }
  }

  void initializeVid() async {
    if (_isDisposed || !mounted) return;

    _controller
        .initialize()
        .then((_) {
          if (_isDisposed || !mounted) return;
          // Calculate ad positions 10%, 25, 50%, 80%
          final totalDuration = _controller.value.duration;

          if (totalDuration.inMilliseconds > 0) {
            if (mounted) {
              setState(() {
                _adPositions.addAll([
                  Duration(
                    milliseconds: (totalDuration.inMilliseconds * 0.1).toInt(),
                  ),
                  Duration(
                    milliseconds: (totalDuration.inMilliseconds * 0.25).toInt(),
                  ),
                  Duration(
                    milliseconds: (totalDuration.inMilliseconds * 0.5).toInt(),
                  ),
                  Duration(
                    milliseconds: (totalDuration.inMilliseconds * 0.8).toInt(),
                  ),
                ]);

                // If initial position is provided, seek to it
                if (widget.initialPosition != null) {
                  final seekPosition = Duration(
                    milliseconds: widget.initialPosition!.inMilliseconds.clamp(
                      0,
                      totalDuration.inMilliseconds,
                    ),
                  );
                  _controller.seekTo(seekPosition);
                }

                _controller.play();

                // Update watch party room state if host (when video initializes)
                final provider = Provider.of<WatchPartyProvider>(
                  context,
                  listen: false,
                );
                if (provider.isHost &&
                    provider.isInRoom &&
                    widget.url != null) {
                  provider.updateRoomState(
                    videoUrl: widget.url!,
                    videoTitle: _videoTitle ?? widget.title ?? 'Video',
                    position: Duration.zero,
                    isPlaying: true,
                  );
                  // Host: mark as initialized immediately
                  _isVideoInitializing = false;
                } else if (!provider.isHost && provider.isInRoom) {
                  // Guest: auto-sync to host's position for late joiners when video initializes
                  Future.delayed(const Duration(milliseconds: 800), () {
                    if (!_isDisposed && mounted) {
                      _isVideoInitializing = false;
                      // Now sync to host's position if available
                      final room = provider.currentRoom;
                      if (room != null &&
                          (room.videoUrl == widget.url ||
                              room.videoUrl == _currentVideoUrl)) {
                        final duration = _controller.value.duration;
                        if (duration.inMilliseconds > 0) {
                          // Calculate predicted position for late joiners
                          Duration targetPosition = room.currentPosition;
                          if (room.isPlaying &&
                              room.positionUpdatedAt != null) {
                            final now = DateTime.now();
                            final elapsedMs = now
                                .difference(room.positionUpdatedAt!)
                                .inMilliseconds;
                            targetPosition = Duration(
                              milliseconds:
                                  (room.currentPosition.inMilliseconds +
                                          elapsedMs)
                                      .clamp(0, duration.inMilliseconds),
                            );
                          }

                          final seekPosition = targetPosition.inMilliseconds
                              .clamp(0, duration.inMilliseconds);
                          _controller.seekTo(
                            Duration(milliseconds: seekPosition),
                          );
                          if (room.isPlaying) {
                            _controller.play();
                          } else {
                            _controller.pause();
                          }
                          _lastSeekTime = DateTime.now();
                          _lastSyncedPosition = targetPosition;
                        }
                      } else if (room != null &&
                          room.videoUrl.isNotEmpty &&
                          room.videoUrl != widget.url &&
                          room.videoUrl != _currentVideoUrl) {
                        // Video URL mismatch - load the correct video
                        _loadVideoFromUrl(room.videoUrl, room.videoTitle);
                      }
                    }
                  });
                }
                
                // Auto-sync on first video start (host only)
                if (provider.isHost && provider.isInRoom && widget.url != null) {
                  provider.updateRoomState(
                    videoUrl: widget.url!,
                    videoTitle: _videoTitle ?? widget.title ?? 'Video',
                    position: _controller.value.position,
                    isPlaying: _controller.value.isPlaying,
                  );
                }

                // Auto-enter PiP if requested
                if (widget.autoEnterPiP && mounted && !_isDisposed) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted &&
                        !_isDisposed &&
                        _controller.value.isInitialized) {
                      _enterPiPMode();
                    }
                  });
                }
              });
            }
          }
        })
        .catchError((error) {
          // Handle initialization errors
          if (!_isDisposed && mounted) {
            _handleVideoError(error);
          }
        });

    // Listen for video player errors - optimized to avoid unnecessary setState
    _controller.addListener(_videoPlayerListener);
  }

  void _videoPlayerListener() {
    if (_isDisposed || !mounted) return;

    if (_controller.value.hasError) {
      _handleVideoError(_controller.value.errorDescription);
    } else {
      /// trigger ad break
      _onMainVideoUpdate();
      // Note: Removed setState here - UI updates via ValueListenableBuilder
    }
  }

  void _handleVideoError(dynamic error) {
    // Show error dialog and allow fallback to external player
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Playback Error',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Unable to play video in built-in player. Would you like to open it in an external player?',
            style: TextStyle(color: Colors.grey[300]),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close video player
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close video player

                // Open in external player
                if (widget.onError != null) {
                  widget.onError!();
                } else {
                  // Fallback: try to open URL externally
                  final url = widget.mediaUrl;
                  if (url != null) {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  }
                }
              },
              child: const Text('Open Externally'),
            ),
          ],
        ),
      );
    }
  }

  void _onMainVideoUpdate() {
    // Only trigger ads if ads are enabled
    if (!widget.adsEnabled) return;

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
    if (_isDisposed || !mounted) return;

    setState(() {
      _inAdBreak = true;
      _showControls = false;
    });

    _controller.pause();

    final adUrl = _adUrls[_nextAdIndex];
    _adController = VideoPlayerController.networkUrl(Uri.parse(adUrl))
      ..initialize()
          .then((_) {
            if (_isDisposed || !mounted) return;

            if (mounted) {
              setState(() {
                _adController!.play();
                _adSecondsRemaining = 30; // Set ad duration to 30 seconds
                // _adSecondsRemaining = _adController!.value.duration.inSeconds;
              });
            }

            _adCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
              timer,
            ) {
              if (_isDisposed || !mounted) {
                timer.cancel();
                return;
              }
              if (mounted) {
                setState(() {
                  _adSecondsRemaining--;
                });
              }
              if (_adSecondsRemaining <= 0) {
                _endAdBreak();
              }
            });
          })
          .catchError((error) {
            // If ad fails to load, end ad break immediately and resume video
            if (!_isDisposed && mounted) {
              _endAdBreak();
            }
          });

    _nextAdIndex++;
  }

  void _endAdBreak() {
    _adCountdownTimer?.cancel();
    _adController?.pause();
    _adController?.dispose();
    _adController = null;

    if (!_isDisposed && mounted) {
      setState(() {
        _inAdBreak = false;
        _showControls = true;
      });
      _controller.play();
    }
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

    // Only remove PiP overlay if not in PiP mode (to prevent closing PiP when route is popped)
    if (!_isInPiP) {
      _pipOverlayEntry?.remove();
      _pipOverlayEntry = null;
      _controller.removeListener(_videoPlayerListener);
      _controller.dispose();
    } else {
      // In PiP mode, keep the controller alive but remove listener
      // The overlay will handle cleanup when PiP is exited
      _controller.removeListener(_videoPlayerListener);
    }

    _adController?.dispose();
    super.dispose();
  }

  String _formatTime(Duration position) {
    final hours = position.inHours.toString().padLeft(2, '0');
    final minutes = position.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = position.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _enterPiPMode() {
    if (_isInPiP || !mounted) return;

    // Use global navigatorKey to get the overlay - this persists after route pop
    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PiP mode not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
      if (mounted) {
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
      _controller.removeListener(_videoPlayerListener);
      _controller.dispose();
    } else if (mounted) {
      setState(() {
        _isInPiP = false;
        _showControls = true;
      });
    }
  }

  Widget _buildPiPOverlay(VideoPlayerController controller) {
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
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        // Video player in PiP - use ValueListenableBuilder to react to state changes
                        ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: controller,
                          builder: (context, value, child) {
                            if (!value.isInitialized) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            return AspectRatio(
                              aspectRatio: value.aspectRatio,
                              child: VideoPlayer(controller),
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
                                  final currentPosition =
                                      controller.value.position;

                                  // Exit PiP first
                                  _exitPiPMode();

                                  // Re-open video player in full screen with preserved position
                                  // Use a small delay to ensure PiP is fully exited
                                  Future.delayed(
                                    const Duration(milliseconds: 100),
                                    () {
                                      navigatorKey.currentState?.push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              RSNewVideoPlayerScreen(
                                                mediaUrl: widget.mediaUrl,
                                                onError: widget.onError,
                                                initialPosition:
                                                    currentPosition,
                                              ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
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
                                    color: Colors.black.withOpacity(0.7),
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
                        // Play/Pause button overlay - use ValueListenableBuilder to show/hide based on playing state
                        ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: controller,
                          builder: (context, value, child) {
                            if (!value.isInitialized) {
                              return const SizedBox.shrink();
                            }
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
                                      color: Colors.black.withOpacity(0.7),
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
                            // When playing, show a small pause indicator on tap (optional)
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

  Widget _buildVideoPlayer(VideoPlayerController controller) {
    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final aspectRatio = controller.value.aspectRatio;
    Widget videoWidget = VideoPlayer(controller);

    switch (_videoFitMode) {
      case VideoFitMode.fit:
        // Contain - show entire video with letterboxing
        return Center(
          child: AspectRatio(aspectRatio: aspectRatio, child: videoWidget),
        );
      case VideoFitMode.fill:
        // Cover - fill screen, may crop
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: videoWidget,
            ),
          ),
        );
      case VideoFitMode.stretch:
        // Stretch - distort to fill
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: videoWidget,
            ),
          ),
        );
      case VideoFitMode.original:
        // Original aspect ratio - center it
        return Center(
          child: AspectRatio(aspectRatio: aspectRatio, child: videoWidget),
        );
      case VideoFitMode.zoom:
        // Zoom - aggressive crop to fill
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.center,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: videoWidget,
            ),
          ),
        );
    }
  }

  void _showAspectRatioMenu(BuildContext context) {
    // This method is no longer used - aspect ratio is now handled by PopupMenuButton
    // Keeping for backward compatibility but can be removed
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop == true) {
          if (!_isInPiP) {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
            ]);
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
          }
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: SizedBox.expand(
          child: Stack(
            children: [
              if (_inAdBreak &&
                  _adController != null &&
                  _adController!.value.isInitialized)
                _buildVideoPlayer(_adController!)
              else if (!_inAdBreak && _controller.value.isInitialized)
                _buildVideoPlayer(_controller)
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
                    if (!_isDisposed && mounted) {
                      setState(() {
                        _showControls = !_showControls;
                      });
                    }
                  },
                  onDoubleTap: (isRight) {
                    if (!_isDisposed && mounted) {
                      if (isRight) {
                        _controller.seekTo(
                          _controller.value.position +
                              const Duration(seconds: 10),
                        );
                      } else {
                        _controller.seekTo(
                          _controller.value.position -
                              const Duration(seconds: 10),
                        );
                      }
                    }
                  },
                  onHorizontalDrag: (delta) {
                    if (!_isDisposed && mounted) {
                      _controller.seekTo(
                        _controller.value.position +
                            Duration(milliseconds: (delta * 1000).toInt()),
                      );
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
                  title: _videoTitle,
                  showControls: _showControls,
                  isLocked: _isLocked,
                  onLockToggle: () {
                    if (!_isDisposed && mounted) {
                      setState(() {
                        _isLocked = !_isLocked;
                      });
                    }
                  },
                ),
                if (_showControls && !_isLocked)
                  ValueListenableBuilder<VideoPlayerValue>(
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
                          if (!_isDisposed && mounted) {
                            final newPosition =
                                _controller.value.position -
                                const Duration(seconds: 10);
                            _controller.seekTo(newPosition);
                            _syncSeek(newPosition);
                          }
                        },
                        onSkipForward: () {
                          if (!_isDisposed && mounted) {
                            final newPosition =
                                _controller.value.position +
                                const Duration(seconds: 10);
                            _controller.seekTo(newPosition);
                            _syncSeek(newPosition);
                          }
                        },
                      );
                    },
                  ),
                if (_showControls && !_isLocked)
                  Positioned(
                    bottom: 0,
                    child: ControlBar(
                      formatTime: _formatTime,
                      onSync: _watchPartyService.isHost && _watchPartyService.isInRoom
                          ? _manualSync
                          : null,
                    ),
                  ),
                if (_showControls && _showEpisodeList && !_isLocked)
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: ListContentOverlay(
                      url: _currentVideoUrl ?? widget.url ?? widget.mediaUrl,
                      listIds: widget.listIds,
                    ),
                  ),
                Consumer<WatchPartyProvider>(
                  builder: (context, provider, child) {
                    if (_showControls &&
                        _showWatchParty &&
                        provider.isInRoom &&
                        !_isLocked) {
                      return Positioned(
                        top: 0,
                        right: 0,
                        bottom: 0,
                        left: 0,
                        child: WatchPartyParticipantsOverlay(
                          room: provider.currentRoom!,
                          isHost: provider.isHost,
                          onClose: () {
                            debugPrint('WatchParty: Video player overlay onClose called');
                            if (mounted) {
                              setState(() {
                                _showWatchParty = false;
                              });
                            }
                            // Don't hide the indicator - just close the overlay
                            // The indicator should remain visible as long as we're in a room
                          },
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                // Show active reactions on video
                ..._activeReactions.map(
                  (reaction) => WatchPartyReactionOverlay(
                    reaction: reaction,
                    onComplete: () {
                      if (mounted) {
                        setState(() {
                          _activeReactions.remove(reaction);
                        });
                      }
                    },
                  ),
                ),
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
      ),
    );
  }
}

class ControlBar extends StatefulWidget {
  final String Function(Duration) formatTime;
  final VoidCallback? onSync;

  const ControlBar({super.key, required this.formatTime, this.onSync});

  @override
  ControlBarState createState() => ControlBarState();
}

class ControlBarState extends State<ControlBar> {
  bool _isDragging = false;
  double _dragValue = 0;

  @override
  Widget build(BuildContext context) {
    final state = context
        .findAncestorStateOfType<_RSNewVideoPlayerScreenState>()!;
    final controller = state._controller;

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        // Only show times if video is initialized and has valid duration
        final position = value.position;
        final duration = value.duration;
        final isInitialized =
            value.isInitialized && duration.inMilliseconds > 0;

        // compute slider values
        final maxMillis = duration.inMilliseconds.toDouble();
        final currentMillis = _isDragging
            ? _dragValue
            : position.inMilliseconds
                  .clamp(0, duration.inMilliseconds)
                  .toDouble();

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
                            final seekPosition = Duration(
                              milliseconds: v.toInt(),
                            );
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
                    // Sync button (host only in watch party)
                    if (widget.onSync != null)
                      IconButton(
                        onPressed: widget.onSync,
                        icon: const Icon(Icons.sync, color: Colors.amber),
                        tooltip: 'Sync time for all participants',
                      ),
                    // speed menu...
                    PopupMenuButton<double>(
                      color: Colors.black,
                      initialValue: value.playbackSpeed,
                      onSelected: (s) => controller.setPlaybackSpeed(s),
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
                            "(${value.playbackSpeed}x)",
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
                          onPressed: () {
                            if (state.mounted) {
                              state.setState(
                                () => state._showEpisodeList = true,
                              );
                            }
                          },
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
                              final provider = Provider.of<WatchPartyProvider>(
                                context,
                                listen: false,
                              );
                              if (provider.isInRoom) {
                                state.setState(
                                  () => state._showWatchParty = true,
                                );
                              } else {
                                state._showWatchPartyDialog();
                              }
                            }
                          },
                        ),
                        // Aspect Ratio - compact popup menu
                        PopupMenuButton<VideoFitMode>(
                          color: Colors.black,
                          icon: const Icon(
                            Icons.aspect_ratio,
                            color: Colors.white,
                          ),
                          tooltip:
                              'Aspect Ratio (${state._videoFitMode.label})',
                          onSelected: (mode) {
                            if (!state._isDisposed && state.mounted) {
                              state.setState(() {
                                state._videoFitMode = mode;
                              });
                            }
                          },
                          itemBuilder: (context) =>
                              VideoFitMode.values.map((mode) {
                                final isSelected = state._videoFitMode == mode;
                                return PopupMenuItem<VideoFitMode>(
                                  value: mode,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isSelected ? Icons.check : null,
                                        color: Colors.amber,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              mode.label,
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Colors.amber
                                                    : Colors.white,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              mode.description,
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 10,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                        ),
                        PopupMenuButton<String>(
                          color: Colors.black,
                          icon: const Icon(Icons.settings, color: Colors.white),
                          onSelected: (value) {
                            if (value == 'aspect_ratio') {
                              // Show aspect ratio menu via the aspect ratio button
                              // This is handled by the PopupMenuButton above
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'aspect_ratio',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.aspect_ratio,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Aspect Ratio (${state._videoFitMode.label})',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                            color: state._isInPiP ? Colors.amber : Colors.white,
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
    final state = context
        .findAncestorStateOfType<_RSNewVideoPlayerScreenState>()!;

    void startHideTimer() {
      if (state._isDisposed || !state.mounted) return;
      state._hideTimer?.cancel(); // Cancel any existing timer

      state._hideTimer = Timer(Duration(seconds: 3), () {
        if (!state._isDisposed && state.mounted) {
          state.setState(() {
            state._showControls = false;
          });
        }
      });
    }

    void toggleControls() {
      if (state._isDisposed || !state.mounted) return;
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
        if (state._isDisposed || !state.mounted) return;
        final width = MediaQuery.of(context).size.width;
        final isRight = d.localPosition.dx > width / 2;

        if (isRight) {
          // Skip forward 10 seconds
          state._controller.seekTo(
            state._controller.value.position + Duration(seconds: 10),
          );
        } else {
          // Skip backward 10 seconds
          state._controller.seekTo(
            state._controller.value.position - Duration(seconds: 10),
          );
        }
      },
      onHorizontalDragUpdate: (d) {
        if (state._isDisposed || !state.mounted) return;
        final delta = d.primaryDelta!;
        state._controller.seekTo(
          state._controller.value.position +
              Duration(milliseconds: (delta * 1000).toInt()),
        );
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
      child: Container(color: Colors.transparent),
    );
  }
}

class PlayPauseControlBar extends StatelessWidget {
  const PlayPauseControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context
        .findAncestorStateOfType<_RSNewVideoPlayerScreenState>()!;
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
                  onPressed: () {
                    if (!state._isDisposed && state.mounted) {
                      controller.seekTo(
                        controller.value.position - const Duration(seconds: 10),
                      );
                    }
                  },
                ),
              ),

              // Play/Pause button listens to controller.value changes
              ValueListenableBuilder<VideoPlayerValue>(
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
                  onPressed: () {
                    if (!state._isDisposed && state.mounted) {
                      state._controller.seekTo(
                        state._controller.value.position +
                            Duration(seconds: 10),
                      );
                    }
                  },
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

  const ListContentOverlay({super.key, this.url, this.listIds});

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
    final state = context
        .findAncestorStateOfType<_RSNewVideoPlayerScreenState>()!;

    // If it's a video that can play in the same player, replace the current video
    if (link.type.canPlayInbuilt) {
      state._replaceVideo(link);
      if (mounted) {
        setState(() => state._showEpisodeList = false);
      }
    } else {
      // For other types, navigate to detail page
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => VideoDetailScreen(link: link)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context
        .findAncestorStateOfType<_RSNewVideoPlayerScreenState>()!;

    if (_isLoading) {
      return Container(
        width: MediaQuery.of(context).size.width / 2,
        margin: const EdgeInsets.only(bottom: 80),
        decoration: const BoxDecoration(color: Color.fromARGB(223, 0, 0, 0)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_lists.isEmpty) {
      return Container(
        width: MediaQuery.of(context).size.width / 2,
        margin: const EdgeInsets.only(bottom: 80),
        decoration: const BoxDecoration(color: Color.fromARGB(223, 0, 0, 0)),
        child: Column(
          children: [
            const Expanded(
              child: Center(
                child: Text(
                  'No lists available',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                if (!state._isDisposed && state.mounted) {
                  state.setState(() => state._showEpisodeList = false);
                }
              },
              child: const Text("Close", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return Container(
      width: MediaQuery.of(context).size.width / 2,
      margin: const EdgeInsets.only(bottom: 80),
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
                    if (!state._isDisposed && state.mounted) {
                      state.setState(() => state._showEpisodeList = false);
                    }
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
            child:
                _listVideos.isEmpty || _selectedTabIndex >= _listVideos.length
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
                      final isCurrentVideo =
                          widget.url != null && video.url == widget.url;

                      return GestureDetector(
                        onTap: () => _playVideo(video),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 2,
                            horizontal: 0,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 2,
                            horizontal: 12,
                          ),
                          color: isCurrentVideo
                              ? Colors.amber.withOpacity(0.2)
                              : Colors.transparent,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      if (video.description != null &&
                                          video.description!.isNotEmpty) ...[
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
            child: Text(
              'Seasons',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
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
        onTap: () {},
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

// Optimized widget classes to reduce rebuild scope

/// Optimized ad countdown overlay - only rebuilds when seconds change
class _AdCountdownOverlayWidget extends StatelessWidget {
  final int secondsRemaining;

  const _AdCountdownOverlayWidget({required this.secondsRemaining});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(8),
        color: Colors.black54,
        child: Text(
          'Ad ends in $secondsRemaining s',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}

/// Optimized volume overlay - only rebuilds when volume changes
class _VolumeOverlayWidget extends StatelessWidget {
  final double volume;

  const _VolumeOverlayWidget({required this.volume});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 700,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.volume_up_outlined, color: Colors.white),
          const SizedBox(height: 8),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: LinearProgressIndicator(
                value: volume,
                backgroundColor: Colors.white24,
                borderRadius: BorderRadius.circular(10),
                minHeight: 10,
                valueColor: const AlwaysStoppedAnimation(Colors.greenAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Optimized brightness overlay - only rebuilds when brightness changes
class _BrightnessOverlayWidget extends StatelessWidget {
  final double brightness;

  const _BrightnessOverlayWidget({required this.brightness});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 700,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wb_sunny_outlined, color: Colors.white),
          const SizedBox(height: 8),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: LinearProgressIndicator(
                value: brightness,
                backgroundColor: Colors.white24,
                borderRadius: BorderRadius.circular(10),
                minHeight: 10,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
