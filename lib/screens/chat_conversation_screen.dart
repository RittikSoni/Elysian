import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elysian/providers/chat_provider.dart';
import 'package:elysian/models/chat_models.dart';
import 'package:elysian/widgets/responsive.dart';
import 'package:intl/intl.dart';

class ChatConversationScreen extends StatefulWidget {
  final ChatConversation conversation;
  final String otherUserEmail;
  final String otherUserDisplayName;

  const ChatConversationScreen({
    super.key,
    required this.conversation,
    required this.otherUserEmail,
    required this.otherUserDisplayName,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showExpirationWarning = false;
  ChatProvider? _provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save provider reference safely
    _provider ??= context.read<ChatProvider>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ChatProvider>();
      provider.setViewingConversation(widget.conversation.id);
      provider.loadMessages(widget.conversation.id);
      provider.listenToMessages(widget.conversation.id);
      provider.markMessagesAsRead(widget.conversation.id);
      _checkExpirationWarning();
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    // Use saved provider reference instead of context
    _provider?.stopListeningToMessages(widget.conversation.id);
    _provider?.setViewingConversation(null);
    // Clear typing indicator
    _provider?.setTypingIndicator(widget.conversation.id, false);
    super.dispose();
  }

  void _checkExpirationWarning() {
    final expiresAt = widget.conversation.expiresAt;
    if (expiresAt != null) {
      final timeUntilExpiration = expiresAt.difference(DateTime.now());
      // Show warning if less than 2 hours remaining
      if (timeUntilExpiration.inHours < 2 &&
          timeUntilExpiration.inMinutes > 0) {
        setState(() => _showExpirationWarning = true);
      }
    }
  }

  Timer? _typingTimer;
  
  void _onTextChanged(String text) {
    // Set typing indicator when user types
    final provider = context.read<ChatProvider>();
    provider.setTypingIndicator(widget.conversation.id, text.isNotEmpty);
    
    // Auto-clear typing indicator after 2 seconds of no typing
    _typingTimer?.cancel();
    if (text.isNotEmpty) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        provider.setTypingIndicator(widget.conversation.id, false);
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final provider = context.read<ChatProvider>();
    try {
      // Clear typing indicator
      provider.setTypingIndicator(widget.conversation.id, false);
      _typingTimer?.cancel();
      
      _messageController.clear();
      
      // Optimistic UI update (message appears immediately)
      await provider.sendMessage(widget.conversation.id, message);
      
      // Scroll to bottom
      if (_scrollController.hasClients) {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
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
    final expiresAt = widget.conversation.expiresAt;
    if (expiresAt == null) return '';

    final timeUntilExpiration = expiresAt.difference(DateTime.now());
    if (timeUntilExpiration.isNegative) {
      return '⚠️ This conversation has expired and will be deleted soon.';
    }

    if (timeUntilExpiration.inHours < 1) {
      final minutes = timeUntilExpiration.inMinutes;
      return '⚠️ Messages will be auto-deleted in $minutes minute${minutes != 1 ? 's' : ''} for security.';
    } else {
      final hours = timeUntilExpiration.inHours;
      return '⚠️ Messages will be auto-deleted in $hours hour${hours != 1 ? 's' : ''} for security and privacy.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final messages = provider.getMessages(widget.conversation.id);
    final currentUserEmail = provider.currentUserEmail;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUserDisplayName),
            Text(
              widget.otherUserEmail,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Expiration warning banner
          if (_showExpirationWarning && widget.conversation.expiresAt != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.withOpacity(0.2),
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
                    reverse: false, // Messages are already sorted chronologically
                    key: const PageStorageKey('chat_messages'), // For scroll position persistence
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isCurrentUser =
                          message.senderEmail == currentUserEmail;
                      final showTime =
                          index == 0 ||
                          messages[index - 1].timestamp
                                  .difference(message.timestamp)
                                  .inMinutes >
                              5;

                      // Use key for better ListView performance
                      return Column(
                        key: ValueKey(message.id),
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
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).brightness == Brightness.light
                                        ? Colors.grey[700]
                                        : Colors.grey[400],
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
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).cardColor,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(
                                    isCurrentUser ? 18 : 4,
                                  ),
                                  bottomRight: Radius.circular(
                                    isCurrentUser ? 4 : 18,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              constraints: BoxConstraints(
                                maxWidth: Responsive.isDesktop(context)
                                    ? MediaQuery.of(context).size.width * 0.5
                                    : MediaQuery.of(context).size.width * 0.75,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isCurrentUser)
                                    Text(
                                      message.senderDisplayName ??
                                          message.senderEmail.split('@').first,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isCurrentUser
                                            ? Colors.white
                                            : Theme.of(context).brightness == Brightness.light
                                                ? Colors.black87
                                                : Colors.white70,
                                      ),
                                    ),
                                  Text(
                                    message.message,
                                    style: TextStyle(
                                      color: isCurrentUser
                                          ? Colors.white
                                          : Theme.of(context).brightness == Brightness.light
                                              ? Colors.black87
                                              : Colors.white,
                                    ),
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
                                          color: isCurrentUser
                                              ? Colors.white.withOpacity(0.9)
                                              : Theme.of(context).brightness == Brightness.light
                                                  ? Colors.black54
                                                  : Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                      if (isCurrentUser) ...[
                                        const SizedBox(width: 4),
                                        // Show message status (sending, sent, delivered, read)
                                        if (message.status == MessageStatus.sending)
                                          SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.white.withOpacity(0.5),
                                              ),
                                            ),
                                          )
                                        else
                                          Icon(
                                            message.status == MessageStatus.read ||
                                                    message.isRead
                                                ? Icons.done_all
                                                : Icons.done,
                                            size: 12,
                                            color: message.isRead ||
                                                    message.status == MessageStatus.read
                                                ? Colors.blue
                                                : message.status == MessageStatus.delivered
                                                    ? Colors.green
                                                    : Colors.white.withOpacity(0.5),
                                          ),
                                        if (message.isRead && message.readAt != null) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            'Seen ${_formatSeenTime(message.readAt!)}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: isCurrentUser
                                                  ? Colors.white.withOpacity(0.8)
                                                  : Theme.of(context).brightness == Brightness.light
                                                      ? Colors.black54
                                                      : Colors.white.withOpacity(0.7),
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
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
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.isDesktop(context) ? 24 : 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        hintStyle: TextStyle(
                          color: Colors.grey.withOpacity(0.6),
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onChanged: _onTextChanged,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _sendMessage,
                      borderRadius: BorderRadius.circular(28),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
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
