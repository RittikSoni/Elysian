import 'package:elysian/components/reusable_btn.dart';
import 'package:elysian/models/content_model.dart';
import 'package:elysian/video_player/yt_full.dart';
import 'package:flutter/material.dart';
import 'package:elysian/widgets/widgets.dart';
import 'package:video_player/video_player.dart';

class ContentHeader extends StatelessWidget {
  final Content featuredContent;

  const ContentHeader({super.key, required this.featuredContent});

  @override
  Widget build(BuildContext context) {
    return Responsive(
      mobile: _MobileContentHeader(featuredContent: featuredContent),
      desktop: _DesktopContentHeader(featuredContent: featuredContent),
    );
  }
}

class _MobileContentHeader extends StatelessWidget {
  final Content featuredContent;

  const _MobileContentHeader({required this.featuredContent});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 500,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(featuredContent.imageUrl),
              fit: BoxFit.cover,
            ),
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
            child: Image.asset(featuredContent.titleImageUrl),
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
              _PlayButton(),
              VericalIconButton(
                icon: Icons.info_outline,
                title: 'info',
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopContentHeader extends StatefulWidget {
  final Content featuredContent;

  const _DesktopContentHeader({required this.featuredContent});

  @override
  State<_DesktopContentHeader> createState() => _DesktopContentHeaderState();
}

class _DesktopContentHeaderState extends State<_DesktopContentHeader> {
  late VideoPlayerController _videoController;
  bool isMuted = true;
  @override
  void initState() {
    super.initState();
    _videoController =
        VideoPlayerController.networkUrl(
            Uri.parse(widget.featuredContent.videoUrl),
          )
          ..initialize().then(
            (_) => setState(() {
              _videoController.setVolume(0);
              _videoController.play();
            }),
          );
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _videoController.value.isPlaying
          ? _videoController.pause()
          : _videoController.play(),
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          AspectRatio(
            aspectRatio: _videoController.value.isInitialized
                ? _videoController.value.aspectRatio
                : 2.344,
            child: _videoController.value.isInitialized
                ? VideoPlayer(_videoController)
                : Image.asset(
                    widget.featuredContent.imageUrl,
                    fit: BoxFit.cover,
                  ),
          ),
          AspectRatio(
            aspectRatio: _videoController.value.isInitialized
                ? _videoController.value.aspectRatio
                : 2.344,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black, Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
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
                SizedBox(
                  width: 250.0,
                  child: Image.asset(widget.featuredContent.titleImageUrl),
                ),
                const SizedBox(height: 15.0),
                Text(
                  widget.featuredContent.description,
                  style: const TextStyle(
                    fontSize: 18.0,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(2.0, 4.0),
                        blurRadius: 6.0,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20.0),
                SizedBox(
                  width: Responsive.isDesktop(context) ? 500 : 300,
                  height: 50,
                  child: Row(
                    children: [
                      Expanded(child: _PlayButton()),
                      SizedBox(width: 10.0),
                      Expanded(
                        child: ReusableButton(
                          onTap: () {},
                          leading: const Icon(
                            Icons.info_outline,
                            color: Colors.white,
                          ),
                          label: 'More Info',
                        ),
                      ),
                      SizedBox(width: 10.0),

                      if (_videoController.value.isInitialized)
                        Expanded(
                          child: ReusableButton(
                            variant: ReusableButtonVariant.outline,
                            onTap: () => setState(() {
                              isMuted
                                  ? _videoController.setVolume(1)
                                  : _videoController.setVolume(0);
                              isMuted = _videoController.value.volume == 0;
                            }),
                            leading: Icon(
                              isMuted ? Icons.volume_off : Icons.volume_up,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ReusableButton(
      variant: ReusableButtonVariant.secondary,

      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => YTFull()),
        // MaterialPageRoute(builder: (context) => RSNewVideoPlayerScreen()),
      ),
      leading: Icon(Icons.play_arrow, color: Colors.white),
      label: 'Play',
    );
  }
}
