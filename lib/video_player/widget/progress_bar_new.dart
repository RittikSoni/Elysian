import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class NewVideoWithThumb extends StatefulWidget {
  final VideoPlayerController controller;
  const NewVideoWithThumb(this.controller, {super.key});

  @override
  NewVideoWithThumbState createState() => NewVideoWithThumbState();
}

class NewVideoWithThumbState extends State<NewVideoWithThumb> {
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateState);
    widget.controller.initialize().then((_) {
      setState(() {
        _duration = widget.controller.value.duration;
      });
    });
  }

  void _updateState() {
    if (!_isDragging) {
      setState(() {
        _position = widget.controller.value.position;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playedMs = _position.inMilliseconds
        .clamp(0, _duration.inMilliseconds)
        .toDouble();
    final totalMs = _duration.inMilliseconds.toDouble();

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 8,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        thumbColor: Colors.amber,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: Colors.amber,
        inactiveTrackColor: Colors.grey,
      ),
      child: Slider(
        min: 0,
        max: totalMs > 0 ? totalMs : 1,
        value: playedMs,
        onChangeStart: (_) {
          setState(() => _isDragging = true);
        },
        onChanged: (value) {
          setState(() => _position = Duration(milliseconds: value.toInt()));
        },
        onChangeEnd: (value) {
          widget.controller.seekTo(Duration(milliseconds: value.toInt()));
          setState(() => _isDragging = false);
        },
      ),
    );
  }
}
