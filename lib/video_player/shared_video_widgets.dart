// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Shared video player UI widgets for both YouTube and regular video players

/// Optimized volume overlay - only rebuilds when volume changes
class SharedVolumeOverlay extends StatelessWidget {
  final double volume;

  const SharedVolumeOverlay({super.key, required this.volume});

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
class SharedBrightnessOverlay extends StatelessWidget {
  final double brightness;

  const SharedBrightnessOverlay({super.key, required this.brightness});

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

/// Optimized ad countdown overlay - only rebuilds when seconds change
class SharedAdCountdownOverlay extends StatelessWidget {
  final int secondsRemaining;

  const SharedAdCountdownOverlay({super.key, required this.secondsRemaining});

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

/// Shared controls overlay (black semi-transparent overlay)
class SharedControlsOverlay extends StatelessWidget {
  const SharedControlsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(color: const Color.fromARGB(87, 0, 0, 0));
  }
}

/// Shared video app bar with back button, title, and lock/unlock
class SharedVideoAppBar extends StatelessWidget {
  final String? title;
  final bool showControls;
  final bool isLocked;
  final VoidCallback? onBackPressed;
  final VoidCallback? onLockToggle;

  const SharedVideoAppBar({
    super.key,
    this.title,
    required this.showControls,
    required this.isLocked,
    this.onBackPressed,
    this.onLockToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (showControls && !isLocked)
                  IconButton(
                    onPressed:
                        onBackPressed ??
                        () {
                          SystemChrome.setPreferredOrientations([
                            DeviceOrientation.portraitUp,
                          ]);
                          SystemChrome.setEnabledSystemUIMode(
                            SystemUiMode.leanBack,
                          );
                          Navigator.pop(context);
                        },
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                if (showControls && !isLocked && title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          if (showControls)
            Container(
              margin: isLocked
                  ? const EdgeInsets.only(right: 30, top: 10)
                  : const EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: onLockToggle,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLocked
                          ? Icons.lock_outline_rounded
                          : Icons.lock_open_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isLocked ? 'Unlock' : 'Lock',
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shared play/pause control bar with skip buttons
class SharedPlayPauseControlBar extends StatelessWidget {
  final VoidCallback? onPlayPause;
  final VoidCallback? onSkipBackward;
  final VoidCallback? onSkipForward;
  final bool isPlaying;

  const SharedPlayPauseControlBar({
    super.key,
    this.onPlayPause,
    this.onSkipBackward,
    this.onSkipForward,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = 120.0;

    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Skip backward 10s
              Container(
                margin: const EdgeInsets.only(left: 100),
                width: iconSize,
                height: iconSize,
                child: IconButton(
                  icon: const Icon(
                    Icons.replay_10_rounded,
                    color: Colors.white,
                  ),
                  onPressed: onSkipBackward,
                ),
              ),

              // Play/Pause button
              IconButton(
                iconSize: 50,
                color: Colors.white,
                onPressed: onPlayPause,
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              ),

              // Skip forward 10s
              Container(
                margin: const EdgeInsets.only(right: 100),
                width: iconSize,
                height: iconSize,
                child: IconButton(
                  icon: const Icon(
                    Icons.forward_10_rounded,
                    color: Colors.white,
                  ),
                  onPressed: onSkipForward,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shared gesture detector overlay for tap, double tap, and drag gestures
class SharedGestureDetectorOverlay extends StatelessWidget {
  final VoidCallback? onTap;
  final void Function(bool isRight)? onDoubleTap;
  final void Function(double delta)? onHorizontalDrag;
  final void Function(bool isRight, double delta)? onVerticalDrag;

  const SharedGestureDetectorOverlay({
    super.key,
    this.onTap,
    this.onDoubleTap,
    this.onVerticalDrag,
    this.onHorizontalDrag,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTapDown: onDoubleTap != null
          ? (d) {
              final width = MediaQuery.of(context).size.width;
              final isRight = d.localPosition.dx > width / 2;
              onDoubleTap!(isRight);
            }
          : null,
      onHorizontalDragUpdate: onHorizontalDrag != null
          ? (d) {
              onHorizontalDrag!(d.primaryDelta ?? 0);
            }
          : null,
      onVerticalDragUpdate: onVerticalDrag != null
          ? (d) {
              final width = MediaQuery.of(context).size.width;
              final isRight = d.localPosition.dx > width / 2;
              final delta = -(d.primaryDelta ?? 0) / 300;
              onVerticalDrag!(isRight, delta);
            }
          : null,
      child: Container(color: Colors.transparent),
    );
  }
}

/// Shared format time function
String sharedFormatTime(Duration position) {
  final hours = position.inHours.toString().padLeft(2, '0');
  final minutes = position.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = position.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
