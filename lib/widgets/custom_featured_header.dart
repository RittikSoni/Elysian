import 'package:elysian/models/models.dart';
import 'package:elysian/services/link_handler.dart';
import 'package:elysian/utils/kroute.dart';
import 'package:elysian/widgets/thumbnail_image.dart';
import 'package:elysian/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Custom featured header that displays a saved link with same UI as ContentHeader
class CustomFeaturedHeader extends StatelessWidget {
  final SavedLink savedLink;

  const CustomFeaturedHeader({super.key, required this.savedLink});

  @override
  Widget build(BuildContext context) {
    // Use MediaQuery directly instead of Responsive to avoid context issues
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    return isDesktop
        ? _DesktopCustomHeader(savedLink: savedLink)
        : _MobileCustomHeader(savedLink: savedLink);
  }
}

class _MobileCustomHeader extends StatelessWidget {
  final SavedLink savedLink;

  const _MobileCustomHeader({required this.savedLink});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 500,
          child: ThumbnailImage(
            link: savedLink,
            width: double.infinity,
            height: 500,
            fit: BoxFit.cover,
          ),
        ),
        Container(
          height: 500,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black, Colors.transparent],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
        ),
        Positioned(
          bottom: 110,
          child: SizedBox(
            width: 250,
            child: Text(
              savedLink.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    offset: Offset(2.0, 4.0),
                    blurRadius: 6.0,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              VericalIconButton(icon: Icons.add, title: 'Add', onTap: () {}),
              _PlayButton(savedLink: savedLink),
              VericalIconButton(
                icon: Icons.info_outline,
                title: 'info',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.grey[900],
                      title: Text(
                        savedLink.title,
                        style: const TextStyle(color: Colors.white),
                      ),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (savedLink.description != null) ...[
                              Text(
                                savedLink.description!,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Text(
                              'URL: ${savedLink.url}',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopCustomHeader extends StatefulWidget {
  final SavedLink savedLink;

  const _DesktopCustomHeader({required this.savedLink});

  @override
  State<_DesktopCustomHeader> createState() => _DesktopCustomHeaderState();
}

class _DesktopCustomHeaderState extends State<_DesktopCustomHeader>
    with RouteAware, WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  bool isMuted = true;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  Future<void> _initializeVideo() async {
    try {
      // Try to create video controller if URL is a video
      if (widget.savedLink.type.toString().contains('video') ||
          widget.savedLink.url.contains('youtube.com') ||
          widget.savedLink.url.contains('youtu.be')) {
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.savedLink.url),
        );
        await _videoController!.initialize();
        _videoController!.setLooping(true);
        _videoController!.setVolume(0);
        _videoController!.play();
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
          });
        }
      }
    } catch (e) {
      // If video fails, just show image
      _isVideoInitialized = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (_videoController == null || !_isVideoInitialized) return;

    if (state == AppLifecycleState.paused) {
      _videoController!.pause();
    } else if (state == AppLifecycleState.resumed) {
      _videoController!.play();
    }
  }

  @override
  void didPushNext() {
    if (_videoController != null && _isVideoInitialized) {
      _videoController!.pause();
    }
  }

  @override
  void didPopNext() {
    if (_videoController != null && _isVideoInitialized) {
      _videoController!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: 500,
          child: _isVideoInitialized && _videoController != null
              ? SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController!.value.size.width,
                      height: _videoController!.value.size.height,
                      child: VideoPlayer(_videoController!),
                    ),
                  ),
                )
              : ThumbnailImage(
                  link: widget.savedLink,
                  width: double.infinity,
                  height: 500,
                  fit: BoxFit.cover,
                ),
        ),
        Container(
          height: 500,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black, Colors.transparent],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
        ),
        Positioned(
          left: 60,
          right: 60,
          bottom: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Text(
                  widget.savedLink.title,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(3.0, 5.0),
                        blurRadius: 8.0,
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 20.0),
              if (widget.savedLink.description != null)
                Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Text(
                    widget.savedLink.description!,
                    style: const TextStyle(
                      fontSize: 20.0,
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(2.0, 4.0),
                          blurRadius: 6.0,
                        ),
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 30.0),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 800;
                  return SizedBox(
                    width: isDesktop ? 500 : 300,
                    height: 50,
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              LinkHandler.openLink(
                                context,
                                widget.savedLink.url,
                                linkType: widget.savedLink.type,
                                title: widget.savedLink.title,
                                description: widget.savedLink.description,
                                linkId: widget.savedLink.id,
                                savedLink: widget.savedLink,
                              );
                            },
                            icon: const Icon(Icons.play_arrow, size: 28),
                            label: const Text(
                              'Play',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Colors.grey[900],
                                  title: Text(
                                    widget.savedLink.title,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (widget.savedLink.description !=
                                            null) ...[
                                          Text(
                                            widget.savedLink.description!,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                        Text(
                                          'URL: ${widget.savedLink.url}',
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(Icons.info_outline, size: 20),
                            label: const Text(
                              'More Info',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 10,
          right: 10,
          child: IconButton(
            icon: Icon(
              isMuted ? Icons.volume_off : Icons.volume_up,
              color: Colors.white,
            ),
            onPressed: () {
              if (_videoController != null && _isVideoInitialized) {
                setState(() {
                  isMuted = !isMuted;
                  _videoController!.setVolume(isMuted ? 0 : 1);
                });
              }
            },
          ),
        ),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  final SavedLink savedLink;

  const _PlayButton({required this.savedLink});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        LinkHandler.openLink(
          context,
          savedLink.url,
          linkType: savedLink.type,
          title: savedLink.title,
          description: savedLink.description,
          linkId: savedLink.id,
          savedLink: savedLink,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.9),
        ),
        padding: const EdgeInsets.all(20),
        child: const Icon(Icons.play_arrow, color: Colors.black, size: 30),
      ),
    );
  }
}
