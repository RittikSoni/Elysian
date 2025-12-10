// ignore_for_file: invalid_use_of_protected_member, unused_element

import 'dart:async';

import 'package:elysian/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class YTFull extends StatefulWidget {
  final String? mediaUrl;
  final String? videoId;
  final String? title;
  final String? description;

  const YTFull({
    super.key,
    this.mediaUrl,
    this.videoId,
    this.title,
    this.description,
  });

  @override
  State<YTFull> createState() => _YTFullState();
}

class _YTFullState extends State<YTFull> {
  late YoutubePlayerController _controller;

  final bool _isPlayerReady = false;

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
  double _brightness = 0.5, _volume = 0.5;
  bool _showVolumeSlider = false;
  bool _showBrightnessSlider = false;
  Timer? _sliderHideTimer;
  Timer? _hideTimer;

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
  }

  void listener() {
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
        _controller.play();
      });

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
    _sliderHideTimer?.cancel();
    _hideTimer?.cancel();
    _adCountdownTimer?.cancel();
    _controller.dispose();
    _adController?.dispose();
    super.dispose();
  }

  String _formatTime(Duration position) {
    final hours = position.inHours.toString().padLeft(2, '0');
    final minutes = position.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = position.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
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
              YoutubePlayer(
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
              )
            else
              const Center(child: CircularProgressIndicator()),

            // Black overlay
            if (_showControls)
              Positioned.fill(
                child: Container(color: const Color.fromARGB(87, 0, 0, 0)),
              ),
            if (_inAdBreak)
              Positioned(
                bottom: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black54,
                  child: Text(
                    'Ad ends in $_adSecondsRemaining s',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),

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
                  (_controller.metadata.title.isNotEmpty
                      ? _controller.metadata.title
                      : widget.title ?? 'Shared Video'),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                  setState(() {
                    _isLocked = !_isLocked;
                  });
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

  Widget _buildVolumeOverlay() {
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
                value: _volume,
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

  Widget _buildBrightnessOverlay() {
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
                value: _brightness,
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
    final position = controller.value.position;
    final duration = controller.value.metaData.duration;

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
                  widget.formatTime(position),
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
                        controller.seekTo(Duration(milliseconds: v.toInt()));
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
                  widget.formatTime(duration),
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
                      onPressed: () =>
                          state.setState(() => state._showEpisodeList = true),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.settings, color: Colors.white),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(
                        Icons.picture_in_picture_alt_rounded,
                        color: Colors.white,
                      ),
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

class EpisodeListOverlay extends StatefulWidget {
  const EpisodeListOverlay({super.key});

  @override
  State<EpisodeListOverlay> createState() => _EpisodeListOverlayState();
}

class _EpisodeListOverlayState extends State<EpisodeListOverlay>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext ctx) {
    return Positioned(
      right: 0,
      top: 0,
      child: Container(
        width: MediaQuery.of(ctx).size.width / 2,
        margin: EdgeInsets.only(
          bottom: Responsive.isMobile(context) ? 120 : 80,
        ),
        decoration: BoxDecoration(color: const Color.fromARGB(223, 0, 0, 0)),
        child: Column(children: [Expanded(child: EpisodeViewMovieScreen())]),
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
