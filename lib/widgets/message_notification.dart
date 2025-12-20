import 'package:flutter/material.dart';
import 'package:elysian/models/chat_models.dart';
import 'package:elysian/providers/chat_provider.dart';

/// A beautiful in-app notification widget for new messages
class MessageNotification extends StatefulWidget {
  final DirectChatMessage message;
  final String senderName;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const MessageNotification({
    super.key,
    required this.message,
    required this.senderName,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<MessageNotification> createState() => _MessageNotificationState();
}

class _MessageNotificationState extends State<MessageNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              onTap: () {
                widget.onTap();
                _dismiss();
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade400,
                            Colors.blue.shade600,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          widget.senderName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Message content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.senderName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.message.message,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Dismiss button
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _dismiss,
                      color: Colors.grey[600],
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Overlay widget to show message notifications
class MessageNotificationOverlay extends StatefulWidget {
  final Widget child;
  final ChatProvider chatProvider;

  const MessageNotificationOverlay({
    super.key,
    required this.child,
    required this.chatProvider,
  });

  @override
  State<MessageNotificationOverlay> createState() =>
      _MessageNotificationOverlayState();
}

class _MessageNotificationOverlayState
    extends State<MessageNotificationOverlay> {
  DirectChatMessage? _currentNotification;
  String? _currentSenderName;
  String? _currentConversationId;

  @override
  void initState() {
    super.initState();
    widget.chatProvider.addListener(_onChatProviderUpdate);
  }

  @override
  void dispose() {
    widget.chatProvider.removeListener(_onChatProviderUpdate);
    super.dispose();
  }

  void _onChatProviderUpdate() {
    final newMessage = widget.chatProvider.latestNewMessage;
    final conversationId = widget.chatProvider.latestNewMessageConversationId;

    // Only show notification if:
    // 1. There's a new message
    // 2. It's not from the current user
    // 3. It's not already being shown
    // 4. User is not currently viewing that conversation
    if (newMessage != null &&
        conversationId != null &&
        newMessage.senderEmail != widget.chatProvider.currentUserEmail &&
        (_currentNotification?.id != newMessage.id) &&
        !widget.chatProvider.isViewingConversation(conversationId)) {
      // Get sender name from conversation
      ChatConversation? conversation;
      try {
        conversation = widget.chatProvider.conversations.firstWhere(
          (c) => c.id == conversationId,
        );
      } catch (e) {
        // Conversation not found
        return;
      }

      final senderName = conversation.getOtherUserDisplayName(
            widget.chatProvider.currentUserEmail!,
          ) ??
          newMessage.senderEmail.split('@').first;

        setState(() {
          _currentNotification = newMessage;
          _currentSenderName = senderName;
          _currentConversationId = conversationId;
        });

      // Auto-dismiss after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _currentNotification?.id == newMessage.id) {
          setState(() {
            _currentNotification = null;
            _currentSenderName = null;
            _currentConversationId = null;
          });
        }
      });
    }
  }

  void _handleNotificationTap() {
    if (_currentConversationId != null) {
      // Navigate to conversation
      // This will be handled by the parent widget
      widget.chatProvider.onNotificationTapped(_currentConversationId!);
    }
    setState(() {
      _currentNotification = null;
      _currentSenderName = null;
      _currentConversationId = null;
    });
  }

  void _handleNotificationDismiss() {
    setState(() {
      _currentNotification = null;
      _currentSenderName = null;
      _currentConversationId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentNotification != null && _currentSenderName != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: SafeArea(
              child: MessageNotification(
                message: _currentNotification!,
                senderName: _currentSenderName!,
                onTap: _handleNotificationTap,
                onDismiss: _handleNotificationDismiss,
              ),
            ),
          ),
      ],
    );
  }
}

