import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elysian/models/watch_party_models.dart';

class WatchPartyReactionOverlay extends StatelessWidget {
  final Reaction reaction;
  final VoidCallback? onComplete;

  const WatchPartyReactionOverlay({
    super.key,
    required this.reaction,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    // Auto-remove after 3 seconds
    Timer(const Duration(seconds: 3), () {
      onComplete?.call();
    });

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
                          color: Colors.black.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          reaction.type.emoji,
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
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${reaction.participantName} ${reaction.type.emoji}',
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

  const ReactionPicker({
    super.key,
    required this.onReactionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: ReactionType.values.map((type) {
            return GestureDetector(
              onTap: () => onReactionSelected(type),
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  type.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

