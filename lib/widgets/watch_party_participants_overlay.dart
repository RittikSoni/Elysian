import 'package:flutter/material.dart';
import 'package:elysian/models/watch_party_models.dart';
import 'package:elysian/services/watch_party_service.dart';
import 'package:elysian/widgets/watch_party_chat_overlay.dart';
import 'package:elysian/widgets/watch_party_reaction_overlay.dart';

class WatchPartyParticipantsOverlay extends StatefulWidget {
  final WatchPartyRoom room;
  final VoidCallback? onClose;
  final bool isHost;

  const WatchPartyParticipantsOverlay({
    super.key,
    required this.room,
    this.onClose,
    this.isHost = false,
  });

  @override
  State<WatchPartyParticipantsOverlay> createState() =>
      _WatchPartyParticipantsOverlayState();
}

class _WatchPartyParticipantsOverlayState
    extends State<WatchPartyParticipantsOverlay> {
  final _watchPartyService = WatchPartyService();
  bool _showChat = false;
  final List<Reaction> _activeReactions = [];

  @override
  void initState() {
    super.initState();
    // Store existing callbacks and chain them
    final existingReactionCallback = _watchPartyService.onReaction;
    final existingChatCallback = _watchPartyService.onChatMessage;
    
    _watchPartyService.onReaction = (reaction) {
      // Call existing callback first (from video player)
      existingReactionCallback?.call(reaction);
      // Then handle in this overlay
      if (mounted) {
        setState(() {
          _activeReactions.add(reaction);
        });
        // Remove reaction after animation
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _activeReactions.remove(reaction);
            });
          }
        });
      }
    };
    
    // Chain chat callback to ensure global manager also receives it
    _watchPartyService.onChatMessage = (message) {
      // Call existing callback first (from global manager/video player)
      existingChatCallback?.call(message);
      // Chat overlay will handle it via its own callback
    };
  }

  @override
  void dispose() {
    _watchPartyService.onReaction = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showChat) {
      return WatchPartyChatOverlay(
        room: widget.room,
        onClose: () {
          setState(() {
            _showChat = false;
          });
        },
      );
    }

    return Stack(
      children: [
        _buildParticipantsView(),
        // Show active reactions
        ..._activeReactions.map((reaction) => WatchPartyReactionOverlay(
              reaction: reaction,
              onComplete: () {
                setState(() {
                  _activeReactions.remove(reaction);
                });
              },
            )),
      ],
    );
  }

  Widget _buildParticipantsView() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Watch Party',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Connection status
                  _buildConnectionStatus(),
                  const SizedBox(width: 8),
                  if (widget.isHost)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: const Text(
                        'HOST',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.grey),
            
            // Room Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.room.videoTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Room Code: ${widget.room.roomCode ?? "N/A"}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${widget.room.participants.length} ${widget.room.participants.length == 1 ? "participant" : "participants"}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.grey),
            
            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showChat = true;
                        });
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Chat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ReactionPicker(
                      onReactionSelected: (type) {
                        _watchPartyService.sendReaction(type);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.grey),
            
            // Participants List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: widget.room.participants.length,
                itemBuilder: (context, index) {
                  final participant = widget.room.participants[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                      border: participant.isHost
                          ? Border.all(color: Colors.amber, width: 2)
                          : null,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: participant.isHost
                              ? Colors.amber
                              : Colors.grey[700],
                          child: Text(
                            participant.name.isNotEmpty
                                ? participant.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: participant.isHost
                                  ? Colors.black
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    participant.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (participant.isHost) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'HOST',
                                        style: TextStyle(
                                          color: Colors.amber,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Joined ${_formatTime(participant.joinedAt)}',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    final isConnected = _watchPartyService.isConnected;
    final error = _watchPartyService.connectionError;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isConnected
            ? Colors.green.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isConnected ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isConnected ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'Connected' : (error ?? 'Disconnected'),
            style: TextStyle(
              color: isConnected ? Colors.green : Colors.red,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

