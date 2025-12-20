import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elysian/models/watch_party_models.dart';

class WatchPartyReactionOverlay extends StatefulWidget {
  final Reaction reaction;
  final VoidCallback? onComplete;

  const WatchPartyReactionOverlay({
    super.key,
    required this.reaction,
    this.onComplete,
  });

  @override
  State<WatchPartyReactionOverlay> createState() =>
      _WatchPartyReactionOverlayState();
}

class _WatchPartyReactionOverlayState extends State<WatchPartyReactionOverlay> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Auto-remove after 3 seconds
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Reaction emoji
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(
                      opacity: value,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          widget.reaction.type.emoji,
                          style: const TextStyle(fontSize: 64),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // Participant name
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.reaction.participantName} ${widget.reaction.type.emoji}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reaction picker widget
class ReactionPicker extends StatelessWidget {
  final Function(ReactionType) onReactionSelected;

  const ReactionPicker({super.key, required this.onReactionSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: ReactionType.values.map((type) {
            return GestureDetector(
              onTap: () => onReactionSelected(type),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(type.emoji, style: const TextStyle(fontSize: 20)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
