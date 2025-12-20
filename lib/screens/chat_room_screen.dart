import 'package:elysian/utils/kroute.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elysian/providers/chat_room_provider.dart';
import 'package:elysian/models/chat_models.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:intl/intl.dart';

class ChatRoomScreen extends StatefulWidget {
  final ChatRoom room;

  const ChatRoomScreen({super.key, required this.room});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showExpirationWarning = false;
  String? _currentUserEmail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ChatRoomProvider>();
      _currentUserEmail = await StorageService.getUserEmail();

      // Load messages and set up listeners
      provider.loadMessages(widget.room.id);
      provider.listenToMessages(widget.room.id);
      provider.listenToRoom(widget.room.id);
      provider.markMessagesAsRead(widget.room.id);

      _checkExpirationWarning();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    final provider = context.read<ChatRoomProvider>();
    provider.stopListeningToMessages(widget.room.id);
    provider.stopListeningToRoom(widget.room.id);
    super.dispose();
  }

  void _checkExpirationWarning() {
    final timeUntilExpiration = widget.room.timeUntilExpiration;
    // Show warning if less than 2 hours remaining
    if (timeUntilExpiration.inHours < 2 && timeUntilExpiration.inMinutes > 0) {
      setState(() => _showExpirationWarning = true);
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final provider = context.read<ChatRoomProvider>();
    try {
      _messageController.clear();
      await provider.sendMessage(widget.room.id, message);
      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  void _showParticipantManagement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ParticipantManagementSheet(
        room: widget.room,
        currentUserEmail: _currentUserEmail ?? '',
      ),
    );
  }

  void _showAddParticipantDialog() {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Participant'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the email address of the person to add',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'friend@example.com',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an email address';
                    }
                    if (!RegExp(
                      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                    ).hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setState(() => isLoading = true);

                      try {
                        final provider = context.read<ChatRoomProvider>();
                        await provider.addParticipant(
                          roomId: widget.room.id,
                          participantEmail: emailController.text.trim(),
                        );

                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Participant added!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => isLoading = false);
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _leaveRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Room'),
        content: Text(
          widget.room.isHost(_currentUserEmail ?? '')
              ? 'You are the host. Leaving will delete the room and all messages. Are you sure?'
              : 'Are you sure you want to leave this room?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final provider = navigatorKey.currentContext!.read<ChatRoomProvider>();
        await provider.leaveRoom(widget.room.id);

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Left room'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(timestamp)}';
    } else {
      return DateFormat('MMM d, HH:mm').format(timestamp);
    }
  }

  String _formatSeenTime(DateTime readAt) {
    final now = DateTime.now();
    final difference = now.difference(readAt);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else {
      return DateFormat('MMM d').format(readAt);
    }
  }

  String _getExpirationWarning() {
    final timeUntilExpiration = widget.room.timeUntilExpiration;
    if (timeUntilExpiration.isNegative) {
      return '⚠️ This room has expired and will be deleted soon.';
    }

    if (timeUntilExpiration.inHours < 1) {
      final minutes = timeUntilExpiration.inMinutes;
      return '⚠️ Room will be auto-deleted in $minutes minute${minutes != 1 ? 's' : ''} for security.';
    } else {
      final hours = timeUntilExpiration.inHours;
      return '⚠️ Room will be auto-deleted in $hours hour${hours != 1 ? 's' : ''} for security and privacy.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatRoomProvider>();
    final room = provider.rooms.firstWhere(
      (r) => r.id == widget.room.id,
      orElse: () => widget.room,
    );
    final messages = provider.getMessages(room.id);
    final isHost = room.isHost(_currentUserEmail ?? '');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(room.roomName),
            if (room.roomDescription != null)
              Text(
                room.roomDescription!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: _showParticipantManagement,
            tooltip: 'Participants (${room.participantCount})',
          ),
          if (isHost)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _showAddParticipantDialog,
              tooltip: 'Add Participant',
            ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: _leaveRoom,
                child: const Row(
                  children: [
                    Icon(Icons.exit_to_app, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Leave Room'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Expiration warning banner
          if (_showExpirationWarning)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.withValues(alpha: 0.2),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getExpirationWarning(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Messages list
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet.\nStart the conversation!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isCurrentUser =
                          message.senderEmail == _currentUserEmail;
                      final showTime =
                          index == 0 ||
                          messages[index - 1].timestamp
                                  .difference(message.timestamp)
                                  .inMinutes >
                              5;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showTime)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  _formatMessageTime(message.timestamp),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          Align(
                            alignment: isCurrentUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isCurrentUser
                                    ? Colors.blue
                                    : Colors.grey[800],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.7,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isCurrentUser)
                                    Text(
                                      message.senderDisplayName ??
                                          message.senderEmail.split('@').first,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  Text(
                                    message.message,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        DateFormat(
                                          'HH:mm',
                                        ).format(message.timestamp),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                      ),
                                      if (message.isRead &&
                                          message.readAt != null) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.done_all,
                                          size: 12,
                                          color: Colors.blue.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Seen ${_formatSeenTime(message.readAt!)}',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.white.withValues(
                                              alpha: 0.6,
                                            ),
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantManagementSheet extends StatelessWidget {
  final ChatRoom room;
  final String currentUserEmail;

  const _ParticipantManagementSheet({
    required this.room,
    required this.currentUserEmail,
  });

  /// Get participant initial for avatar display
  String _getParticipantInitial(RoomParticipant participant) {
    final displayName = participant.displayName;
    final email = participant.email;

    if (displayName != null && displayName.isNotEmpty) {
      return displayName[0].toUpperCase();
    }
    if (email.isNotEmpty) {
      final emailPart = email.split('@').first;
      if (emailPart.isNotEmpty) {
        return emailPart[0].toUpperCase();
      }
    }
    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ChatRoomProvider>();
    final updatedRoom = provider.rooms.firstWhere(
      (r) => r.id == room.id,
      orElse: () => room,
    );
    final isHost = updatedRoom.isHost(currentUserEmail);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Participants',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${updatedRoom.participantCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: updatedRoom.participants.length,
                itemBuilder: (context, index) {
                  final participant = updatedRoom.participants[index];
                  final isCurrentUser =
                      participant.email.toLowerCase() ==
                      currentUserEmail.toLowerCase();
                  final canKick =
                      isHost && !participant.isHost && !isCurrentUser;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: participant.isHost
                          ? Colors.orange
                          : Colors.blue,
                      child: Text(
                        _getParticipantInitial(participant),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            participant.displayName ??
                                participant.email.split('@').first,
                            style: TextStyle(
                              fontWeight: participant.isHost
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (participant.isHost)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'HOST',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (isCurrentUser)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'YOU',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(participant.email),
                    trailing: canKick
                        ? IconButton(
                            icon: const Icon(
                              Icons.remove_circle,
                              color: Colors.red,
                            ),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Kick Participant'),
                                  content: Text(
                                    'Are you sure you want to remove ${participant.displayName ?? participant.email} from the room?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text('Kick'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                try {
                                  await provider.kickParticipant(
                                    roomId: updatedRoom.id,
                                    participantEmail: participant.email,
                                  );

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Participant removed'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
