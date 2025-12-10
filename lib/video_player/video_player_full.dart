// ignore_for_file: invalid_use_of_protected_member, unused_element

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:elysian/utils/kroute.dart';

enum VideoFitMode {
  fit, // Contain - shows entire video (letterboxing)
  fill, // Cover - fills screen (may crop)
  stretch, // Stretch - distorts to fill
  original, // Original aspect ratio
  zoom, // Zoom - crop to fill (aggressive)
}

extension VideoFitModeExtension on VideoFitMode {
  String get label {
    switch (this) {
      case VideoFitMode.fit:
        return 'Fit';
      case VideoFitMode.fill:
        return 'Fill';
      case VideoFitMode.stretch:
        return 'Stretch';
      case VideoFitMode.original:
        return 'Original';
      case VideoFitMode.zoom:
        return 'Zoom';
    }
  }

  String get description {
    switch (this) {
      case VideoFitMode.fit:
        return 'Show entire video';
      case VideoFitMode.fill:
        return 'Fill screen (may crop)';
      case VideoFitMode.stretch:
        return 'Stretch to fill';
      case VideoFitMode.original:
        return 'Original aspect ratio';
      case VideoFitMode.zoom:
        return 'Zoom to fill';
    }
  }
}

class RSNewVideoPlayerScreen extends StatefulWidget {
  final String? mediaUrl;
  final VoidCallback? onError;
  final Duration? initialPosition; // Optional initial position to seek to

  const RSNewVideoPlayerScreen({
    super.key,
    this.mediaUrl,
    this.onError,
    this.initialPosition,
  });

  @override
  State<RSNewVideoPlayerScreen> createState() => _RSNewVideoPlayerScreenState();
}

class _RSNewVideoPlayerScreenState extends State<RSNewVideoPlayerScreen> {
  late VideoPlayerController _controller;
  VideoPlayerController? _adController;

  // UI state
  bool _showControls = true;
  bool _showEpisodeList = false;
  double _brightness = 0.5, _volume = 0.5;
  bool _showVolumeSlider = false;
  bool _showBrightnessSlider = false;
  Timer? _sliderHideTimer;
  Timer? _hideTimer;
  bool _isDisposed = false;

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
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(
        widget.mediaUrl ??
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      ),
    );
    initializeVid();
  }

  void initializeVid() async {
    if (_isDisposed || !mounted) return;

    _controller
      ..initialize()
          .then((_) {
            if (_isDisposed || !mounted) return;
            // Calculate ad positions 10%, 25, 50%, 80%
            final totalDuration = _controller.value.duration;

            if (totalDuration.inMilliseconds > 0) {
              if (mounted) {
                setState(() {
                  _adPositions.addAll([
                    Duration(
                      milliseconds: (totalDuration.inMilliseconds * 0.1)
                          .toInt(),
                    ),
                    Duration(
                      milliseconds: (totalDuration.inMilliseconds * 0.25)
                          .toInt(),
                    ),
                    Duration(
                      milliseconds: (totalDuration.inMilliseconds * 0.5)
                          .toInt(),
                    ),
                    Duration(
                      milliseconds: (totalDuration.inMilliseconds * 0.8)
                          .toInt(),
                    ),
                  ]);

                  // If initial position is provided, seek to it
                  if (widget.initialPosition != null) {
                    final seekPosition = Duration(
                      milliseconds: widget.initialPosition!.inMilliseconds
                          .clamp(0, totalDuration.inMilliseconds),
                    );
                    _controller.seekTo(seekPosition);
                  }

                  _controller.play();
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
        body: Stack(
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
              Positioned.fill(
                child: Container(color: const Color.fromARGB(87, 0, 0, 0)),
              ),
            if (_inAdBreak)
              _AdCountdownOverlayWidget(secondsRemaining: _adSecondsRemaining),

            if (!_inAdBreak) ...[
              GestureDetectorOverlay(),
              if (_showBrightnessSlider || _showControls && !_isLocked)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: _buildBrightnessOverlay(),
                  ),
                ),
              if (_showVolumeSlider || _showControls && !_isLocked)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _buildVolumeOverlay(),
                  ),
                ),
              _appBar(context),
              if (_showControls && !_isLocked) const PlayPauseControlBar(),
              if (_showControls && !_isLocked)
                Positioned(
                  bottom: 0,
                  child: ControlBar(formatTime: _formatTime),
                ),
              if (_showControls && _showEpisodeList && !_isLocked)
                const Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  // alignment: Alignment.centerRight,
                  child: EpisodeListOverlay(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _appBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (_showControls && !_isLocked)
                IconButton(
                  onPressed: () {
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.portraitUp,
                    ]);
                    SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                ),
              if (_showControls && !_isLocked)
                Text(
                  'Iron Sky: The Coming Race',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
            ],
          ),
          if (_showControls)
            Container(
              margin: _isLocked
                  ? const EdgeInsets.only(right: 30, top: 10)
                  : EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: () {
                  if (!_isDisposed && mounted) {
                    setState(() {
                      _isLocked = !_isLocked;
                    });
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      _isLocked
                          ? Icons.lock_outline_rounded
                          : Icons.lock_open_rounded,
                      color: Colors.white,
                    ),
                    SizedBox(width: 5),
                    Text(
                      _isLocked ? 'Unlock' : 'Lock',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Optimized: Extract to separate widget to prevent rebuilds
  Widget _buildVolumeOverlay() {
    return _VolumeOverlayWidget(volume: _volume);
  }

  Widget _buildBrightnessOverlay() {
    return _BrightnessOverlayWidget(brightness: _brightness);
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
                            controller.seekTo(
                              Duration(milliseconds: v.toInt()),
                            );
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
                            Icons.list,
                            color: state._showEpisodeList
                                ? Colors.amber
                                : Colors.white,
                          ),
                          label: Text(
                            "Episode",
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

class EpisodeListOverlay extends StatefulWidget {
  const EpisodeListOverlay({super.key});

  @override
  State<EpisodeListOverlay> createState() => _EpisodeListOverlayState();
}

class _EpisodeListOverlayState extends State<EpisodeListOverlay>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext ctx) {
    final state = ctx.findAncestorStateOfType<_RSNewVideoPlayerScreenState>()!;
    return Positioned(
      right: 0,
      top: 0,
      child: Container(
        width: MediaQuery.of(ctx).size.width / 2,
        margin: EdgeInsets.only(bottom: 80),
        decoration: BoxDecoration(color: const Color.fromARGB(223, 0, 0, 0)),
        child: Column(
          children: [
            SizedBox(height: 290, child: EpisodeViewMovieScreen()),
            TextButton(
              child: Text("Close", style: TextStyle(color: Colors.white)),
              onPressed: () {
                if (!state._isDisposed && state.mounted) {
                  state.setState(() => state._showEpisodeList = false);
                }
              },
            ),
          ],
        ),
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
