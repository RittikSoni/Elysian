import 'package:elysian/models/models.dart';
import 'package:elysian/services/link_parser.dart';
import 'package:elysian/widgets/thumbnail_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class SmallVideoPlayer extends StatefulWidget {
  final SavedLink link;
  final void Function(Duration? position) onFullScreen;
  final void Function(Duration? position)? onPiP;

  const SmallVideoPlayer({
    super.key,
    required this.link,
    required this.onFullScreen,
    this.onPiP,
  });

  @override
  State<SmallVideoPlayer> createState() => _SmallVideoPlayerState();
}

class _SmallVideoPlayerState extends State<SmallVideoPlayer> {
  VideoPlayerController? _videoController;
  YoutubePlayerController? _youtubeController;
  bool _isPlaying = false;
  bool _isMuted = true;
  bool _isInitialized = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (widget.link.type == LinkType.youtube) {
      final videoId = LinkParser.extractYouTubeVideoId(widget.link.url);
      if (videoId != null) {
        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            mute: true,
            autoPlay: true,
            loop: true,
            hideControls: true,
          ),
        );
        setState(() {
          _isInitialized = true;
          _isPlaying = true;
        });
      }
    } else if (widget.link.type.canPlayInbuilt) {
      try {
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.link.url),
        );
        await _videoController!.initialize();
        _videoController!.setVolume(0);
        _videoController!.setLooping(true);
        _videoController!.play();
        
        if (mounted && !_isDisposed) {
          setState(() {
            _isInitialized = true;
            _isPlaying = true;
          });
        }
      } catch (e) {
        // If initialization fails, show thumbnail instead
        if (mounted && !_isDisposed) {
          setState(() => _isInitialized = false);
        }
      }
    }
  }

  void _togglePlayPause() {
    if (_videoController != null) {
      if (_isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
      setState(() => _isPlaying = !_isPlaying);
    } else if (_youtubeController != null) {
      if (_isPlaying) {
        _youtubeController!.pause();
      } else {
        _youtubeController!.play();
      }
      setState(() => _isPlaying = !_isPlaying);
    }
  }

  void _toggleMute() {
    if (_videoController != null) {
      setState(() {
        _isMuted = !_isMuted;
        _videoController!.setVolume(_isMuted ? 0 : 1);
      });
    } else if (_youtubeController != null) {
      setState(() {
        _isMuted = !_isMuted;
        _youtubeController!.mute();
      });
    }
  }

  void _enterPiP() {
    // Get current position
    Duration? currentPosition;
    if (_videoController != null && _videoController!.value.isInitialized) {
      currentPosition = _videoController!.value.position;
    } else if (_youtubeController != null) {
      currentPosition = _youtubeController!.value.position;
    }
    
    // Call PiP callback if available, otherwise open full screen
    if (widget.onPiP != null) {
      widget.onPiP!(currentPosition);
    } else {
      widget.onFullScreen(currentPosition);
    }
  }

  void _openFullScreen() {
    // Get current position
    Duration? currentPosition;
    if (_videoController != null && _videoController!.value.isInitialized) {
      currentPosition = _videoController!.value.position;
    } else if (_youtubeController != null) {
      currentPosition = _youtubeController!.value.position;
    }
    
    widget.onFullScreen(currentPosition);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _videoController?.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      // Show thumbnail if player not initialized
      return GestureDetector(
        onTap: () => _openFullScreen(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ThumbnailImage(
              link: widget.link,
              width: double.infinity,
              height: 300,
            ),
            const Center(
              child: Icon(
                Icons.play_circle_filled,
                color: Colors.white,
                size: 64,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video Player
        if (_youtubeController != null)
          YoutubePlayer(
            controller: _youtubeController!,
            showVideoProgressIndicator: false,
            bottomActions: const [],
          )
        else if (_videoController != null)
          AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
        
        // Controls Overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Control Buttons
        Positioned(
          bottom: 16,
          right: 16,
          child: Row(
            children: [
              // Mute/Unmute
              IconButton(
                onPressed: _toggleMute,
                icon: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 8),
              
              // Full Screen
              IconButton(
                onPressed: _openFullScreen,
                icon: const Icon(
                  Icons.fullscreen,
                  color: Colors.white,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.6),
                ),
              ),
              
              // PiP (only for supported types)
              if (widget.link.type == LinkType.youtube ||
                  widget.link.type == LinkType.directVideo) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _enterPiP,
                  icon: const Icon(
                    Icons.picture_in_picture_alt,
                    color: Colors.white,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

