import 'package:flutter/material.dart';
import 'package:elysian/models/watch_party_models.dart';
import 'package:elysian/providers/providers.dart';
import 'package:provider/provider.dart';

class WatchPartyChatOverlay extends StatefulWidget {
  final WatchPartyRoom room;
  final VoidCallback? onClose;

  const WatchPartyChatOverlay({super.key, required this.room, this.onClose});

  @override
  State<WatchPartyChatOverlay> createState() => _WatchPartyChatOverlayState();
}

class _WatchPartyChatOverlayState extends State<WatchPartyChatOverlay> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  static const int _maxMessages = 100; // Keep last 100 messages for session

  @override
  void initState() {
    super.initState();
    // Load existing messages from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<WatchPartyProvider>(context, listen: false);
      _messages.addAll(provider.recentMessages);
      if (mounted) {
        setState(() {});
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // Don't clear callback - video player might still need it
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    final provider = Provider.of<WatchPartyProvider>(context, listen: false);
    await provider.sendChatMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.95),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.amber,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Chat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.grey),

            // Messages
            Expanded(
              child: Consumer<WatchPartyProvider>(
                builder: (context, provider, child) {
                  // Sync messages from provider
                  final recentMessages = provider.recentMessages;
                  for (final message in recentMessages) {
                    if (!_messages.any((m) => m.id == message.id)) {
                      _messages.add(message);
                      // Keep only last _maxMessages messages for optimization
                      if (_messages.length > _maxMessages) {
                        _messages.removeAt(0);
                      }
                    }
                  }
                  // Scroll to bottom when new messages arrive
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });

                  return _messages.isEmpty
                      ? Center(
                          child: Text(
                            'No messages yet.\nStart the conversation!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isCurrentUser =
                                message.participantId ==
                                provider.currentParticipantId;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                mainAxisAlignment: isCurrentUser
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isCurrentUser) ...[
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.grey[700],
                                      child: Text(
                                        message.participantName.isNotEmpty
                                            ? message.participantName[0]
                                                  .toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isCurrentUser
                                            ? Colors.amber
                                            : Colors.grey[800],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (!isCurrentUser)
                                            Text(
                                              message.participantName,
                                              style: TextStyle(
                                                color: Colors.grey[300],
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          if (!isCurrentUser)
                                            const SizedBox(height: 4),
                                          Text(
                                            message.message,
                                            style: TextStyle(
                                              color: isCurrentUser
                                                  ? Colors.black
                                                  : Colors.white,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatTime(message.timestamp),
                                            style: TextStyle(
                                              color: isCurrentUser
                                                  ? Colors.black54
                                                  : Colors.grey[400],
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isCurrentUser) ...[
                                    const SizedBox(width: 8),
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.amber.withOpacity(
                                        0.3,
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.amber,
                                        size: 16,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                },
              ),
            ),

            // Input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border(top: BorderSide(color: Colors.grey[800]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send, color: Colors.amber),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.amber.withOpacity(0.2),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    } else {
      final hour = time.hour;
      final minute = time.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    }
  }
}
