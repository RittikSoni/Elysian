import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:elysian/models/watch_party_models.dart';
import 'package:elysian/models/models.dart';
import 'package:elysian/widgets/watch_party_chat_overlay.dart';
import 'package:elysian/widgets/watch_party_reaction_overlay.dart';
import 'package:elysian/providers/providers.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/services/link_parser.dart';
import 'package:elysian/video_player/yt_full.dart';
import 'package:elysian/video_player/video_player_full.dart';
import 'package:provider/provider.dart';

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
  bool _showChat = false;
  final List<Reaction> _activeReactions = [];
  final Map<String, Future<void>> _pendingReactionRemovals = {};

  @override
  Widget build(BuildContext context) {
    if (_showChat) {
      return WatchPartyChatOverlay(
        room: widget.room,
        onClose: () {
          if (mounted) {
            setState(() {
              _showChat = false;
            });
          }
        },
      );
    }

    return Consumer<WatchPartyProvider>(
      builder: (context, provider, child) {
        // Sync reactions from provider - only show reactions from last 3 seconds
        final now = DateTime.now();
        final recentReactions = provider.recentReactions.where((reaction) {
          final age = now.difference(reaction.timestamp);
          return age.inSeconds < 3; // Only show reactions less than 3 seconds old
        }).toList();
        
        // Add new reactions that aren't already active
        for (final reaction in recentReactions) {
          if (!_activeReactions.any((r) => r.id == reaction.id)) {
            _activeReactions.add(reaction);
            // Remove reaction after animation (3 seconds from now)
            final removalFuture = Future.delayed(
              const Duration(seconds: 3),
              () {
                if (mounted) {
                  setState(() {
                    _activeReactions.remove(reaction);
                    _pendingReactionRemovals.remove(reaction.id);
                  });
                }
              },
            );
            _pendingReactionRemovals[reaction.id] = removalFuture;
          }
        }
        
        // Remove reactions that are too old or no longer in recent reactions
        _activeReactions.removeWhere((reaction) {
          final age = now.difference(reaction.timestamp);
          final isOld = age.inSeconds >= 3;
          final notInRecent = !recentReactions.any((r) => r.id == reaction.id);
          if (isOld || notInRecent) {
            _pendingReactionRemovals.remove(reaction.id);
            return true;
          }
          return false;
        });

        return Stack(
          children: [
            _buildParticipantsView(),
            // Show active reactions
            ..._activeReactions.map(
              (reaction) => WatchPartyReactionOverlay(
                reaction: reaction,
                onComplete: () {
                  if (mounted) {
                    setState(() {
                      _activeReactions.remove(reaction);
                      _pendingReactionRemovals.remove(reaction.id);
                    });
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    // Clear all pending reaction removals
    _pendingReactionRemovals.clear();
    _activeReactions.clear();
    super.dispose();
  }

  Widget _buildParticipantsView() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button always visible
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
                  // Close button - always visible
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      debugPrint('WatchParty: Close button pressed in participants overlay');
                      if (widget.onClose != null) {
                        debugPrint('WatchParty: Calling onClose callback');
                        widget.onClose!();
                      } else {
                        debugPrint('WatchParty: onClose callback is null!');
                      }
                    },
                    tooltip: 'Close',
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
              child: Column(
                children: [
                  // Go to Video button (for joiners only, if video URL is available)
                  Consumer<WatchPartyProvider>(
                    builder: (context, provider, child) {
                      // Only show for joiners (not hosts) and if video URL is available
                      if (!widget.isHost && widget.room.videoUrl.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                // Close the dialog first
                                if (widget.onClose != null) {
                                  widget.onClose!();
                                }
                                
                                // Wait a bit for dialog to close
                                await Future.delayed(const Duration(milliseconds: 200));
                                
                                // Navigate to video using the provider's navigation
                                // Access the provider's internal navigation method via a helper
                                final watchPartyProvider = Provider.of<WatchPartyProvider>(
                                  context,
                                  listen: false,
                                );
                                
                                // Check if we're still in the room and have a valid video URL
                                if (watchPartyProvider.currentRoom != null && 
                                    watchPartyProvider.currentRoom!.videoUrl == widget.room.videoUrl) {
                                  // Use a direct navigation approach since we can't access private methods
                                  // The provider will handle navigation when room state is checked
                                  // For now, we'll manually trigger navigation by checking room state
                                  final navigator = Navigator.of(context, rootNavigator: true);
                                  
                                  // Import necessary services
                                  try {
                                    final allLinks = await StorageService.getSavedLinks();
                                    final link = allLinks.firstWhere(
                                      (l) => l.url == widget.room.videoUrl,
                                      orElse: () => SavedLink(
                                        id: '',
                                        url: widget.room.videoUrl,
                                        title: widget.room.videoTitle,
                                        type: LinkParser.parseLinkType(widget.room.videoUrl) ?? LinkType.unknown,
                                        listIds: [],
                                        savedAt: DateTime.now(),
                                      ),
                                    );

                                    if (link.type == LinkType.youtube) {
                                      navigator.push(
                                        MaterialPageRoute(
                                          builder: (context) => YTFull(
                                            url: link.url,
                                            title: link.title.isNotEmpty ? link.title : widget.room.videoTitle,
                                            listIds: link.listIds,
                                          ),
                                        ),
                                      );
                                    } else if (link.type.canPlayInbuilt) {
                                      navigator.push(
                                        MaterialPageRoute(
                                          builder: (context) => RSNewVideoPlayerScreen(
                                            url: link.url,
                                            title: link.title.isNotEmpty ? link.title : widget.room.videoTitle,
                                            listIds: link.listIds,
                                            adsEnabled: false,
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint('Error navigating to video: $e');
                                  }
                                }
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Go to Video'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  Row(
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
                        child: Consumer<WatchPartyProvider>(
                          builder: (context, provider, child) {
                            return ReactionPicker(
                              onReactionSelected: (type) {
                                provider.sendReaction(type);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.grey),

            // Exit Watch Party Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Consumer<WatchPartyProvider>(
                builder: (context, provider, child) {
                  return ElevatedButton.icon(
                    onPressed: () async {
                      debugPrint('WatchParty: Leave button pressed');
                      debugPrint('WatchParty: Is in room: ${provider.isInRoom}');
                      
                      // Show confirmation dialog
                      final shouldExit = await showDialog<bool>(
                        context: context,
                        barrierDismissible: true,
                        builder: (dialogContext) => AlertDialog(
                          backgroundColor: Colors.grey[900],
                          title: const Text(
                            'Exit Watch Party?',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: Text(
                            widget.isHost
                                ? 'Are you sure you want to end this watch party? All participants will be disconnected.'
                                : 'Are you sure you want to leave this watch party?',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                debugPrint('WatchParty: Leave cancelled');
                                Navigator.of(dialogContext).pop(false);
                              },
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                debugPrint('WatchParty: Leave confirmed');
                                Navigator.of(dialogContext).pop(true);
                              },
                              child: const Text(
                                'Exit',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );

                      debugPrint('WatchParty: Confirmation result: $shouldExit');
                      
                      if (shouldExit == true) {
                        debugPrint('WatchParty: Starting leave process');
                        try {
                          // Close the main watch party dialog BEFORE leaving room
                          // This prevents black screen by ensuring dialog is closed first
                          if (widget.onClose != null) {
                            debugPrint('WatchParty: Closing main dialog');
                            widget.onClose!();
                          }

                          // Wait for dialog to fully close before leaving room
                          await Future.delayed(const Duration(milliseconds: 200));

                          // Leave the room (this will clean up state)
                          // This is done after dialog is closed to prevent UI issues
                          debugPrint('WatchParty: Calling provider.leaveRoom()');
                          await provider.leaveRoom();
                          debugPrint('WatchParty: Successfully left room');
                        } catch (e, stackTrace) {
                          debugPrint('WatchParty: Error during leave process: $e');
                          debugPrint('WatchParty: Stack trace: $stackTrace');
                          // Show error to user
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error leaving watch party: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } else {
                        debugPrint('WatchParty: Leave cancelled by user');
                      }
                    },
                    icon: const Icon(Icons.exit_to_app),
                    label: Text(
                      widget.isHost ? 'End Watch Party' : 'Leave Watch Party',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  );
                },
              ),
            ),
            const Divider(color: Colors.grey),

            // Participants List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
            // Small padding to prevent 1px overflow
            const SizedBox(height: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    // Use provider to get connection status (works for both Firebase and local)
    final watchPartyProvider = Provider.of<WatchPartyProvider>(
      context,
      listen: true,
    );
    final isConnected = watchPartyProvider.isConnected;
    final error = watchPartyProvider.connectionError;

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
