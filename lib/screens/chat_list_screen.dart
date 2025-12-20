import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elysian/providers/chat_provider.dart';
import 'package:elysian/models/chat_models.dart';
import 'package:elysian/screens/chat_conversation_screen.dart';
import 'package:elysian/screens/friend_request_screen.dart';
import 'package:elysian/screens/chat_room_list_screen.dart';
import 'package:elysian/widgets/message_notification.dart';
import 'package:intl/intl.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  Future<void> _initializeChat() async {
    final chatProvider = context.read<ChatProvider>();

    // Try to initialize (will check for Google Sign-In or stored email)
    await chatProvider.initialize();

    // If still not signed in, show sign-in dialog
    if (chatProvider.currentUserEmail == null) {
      _showSignInDialog();
    } else {
      // Set up notification tap handler
      chatProvider.setOnNotificationTapped((conversationId) {
        final conversation = chatProvider.conversations.firstWhere(
          (c) => c.id == conversationId,
        );
        final otherUserEmail = conversation.getOtherUserEmail(
          chatProvider.currentUserEmail!,
        );
        final otherUserDisplayName =
            conversation.getOtherUserDisplayName(
              chatProvider.currentUserEmail!,
            ) ??
            otherUserEmail.split('@').first;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatConversationScreen(
              conversation: conversation,
              otherUserEmail: otherUserEmail,
              otherUserDisplayName: otherUserDisplayName,
            ),
          ),
        );
      });
    }
  }

  void _showSignInDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SignInDialog(),
    );
  }

  /// Get user initial for avatar display
  String _getUserInitial(String? displayName, String? email) {
    if (displayName != null && displayName.isNotEmpty) {
      return displayName[0].toUpperCase();
    }
    if (email != null && email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    return MessageNotificationOverlay(
      chatProvider: chatProvider,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chat'),
          actions: [
            // Sign out button
            if (chatProvider.currentUserEmail != null)
              PopupMenuButton<String>(
                icon: CircleAvatar(
                  backgroundColor: Colors.blue,
                  radius: 16,
                  child: Text(
                    _getUserInitial(
                      chatProvider.currentUserDisplayName,
                      chatProvider.currentUserEmail,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onSelected: (value) {
                  if (value == 'signout') {
                    chatProvider.signOut();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chatProvider.currentUserDisplayName ??
                              chatProvider.currentUserEmail ??
                              'User',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          chatProvider.currentUserEmail ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'signout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20),
                        SizedBox(width: 8),
                        Text('Sign Out'),
                      ],
                    ),
                  ),
                ],
              ),
            // Chat rooms button (only show when signed in)
            if (chatProvider.currentUserEmail != null)
              IconButton(
                icon: const Icon(Icons.group),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChatRoomListScreen(),
                    ),
                  );
                },
                tooltip: 'Chat Rooms',
              ),
            // Friend requests button with badge (only show when signed in)
            if (chatProvider.currentUserEmail != null)
              Consumer<ChatProvider>(
                builder: (context, provider, _) {
                  final unreadCount = provider.pendingRequests.length;
                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.person_add),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FriendRequestScreen(),
                            ),
                          );
                        },
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              unreadCount > 9 ? '9+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
        body: Consumer<ChatProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.currentUserEmail == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sign in to start chatting',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use Google Sign-In for secure authentication',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _showSignInDialog,
                      icon: const Icon(Icons.login),
                      label: const Text('Sign In with Google'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            if (provider.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      provider.error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.initialize(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (provider.conversations.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No conversations yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Send a friend request to start chatting',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FriendRequestScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Friend'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: provider.conversations.length,
              itemBuilder: (context, index) {
                final conversation = provider.conversations[index];
                final otherUserEmail = conversation.getOtherUserEmail(
                  provider.currentUserEmail!,
                );
                final otherUserDisplayName =
                    conversation.getOtherUserDisplayName(
                      provider.currentUserEmail!,
                    ) ??
                    otherUserEmail.split('@').first;

                return _ConversationTile(
                  conversation: conversation,
                  otherUserDisplayName: otherUserDisplayName,
                  otherUserEmail: otherUserEmail,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatConversationScreen(
                          conversation: conversation,
                          otherUserEmail: otherUserEmail,
                          otherUserDisplayName: otherUserDisplayName,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ChatConversation conversation;
  final String otherUserDisplayName;
  final String otherUserEmail;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.otherUserDisplayName,
    required this.otherUserEmail,
    required this.onTap,
  });

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(dateTime);
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpiringSoon =
        conversation.expiresAt != null &&
        DateTime.now()
            .add(const Duration(hours: 1))
            .isAfter(conversation.expiresAt!);

    final hasUnread = conversation.unreadCount > 0;

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue,
            child: Text(
              otherUserDisplayName.isNotEmpty
                  ? otherUserDisplayName[0].toUpperCase()
                  : 'U',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          // Red dot indicator for unread messages
          if (hasUnread)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              otherUserDisplayName,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (conversation.lastMessage != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    conversation.lastMessage!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: hasUnread
                          ? FontWeight.w500
                          : FontWeight.normal,
                      color: hasUnread ? Colors.black87 : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          if (isExpiringSoon)
            const Text(
              '⚠️ Messages will be deleted soon',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(conversation.lastMessageAt),
            style: TextStyle(
              fontSize: 12,
              color: hasUnread ? Colors.blue : Colors.grey,
              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (hasUnread)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Center(
                child: Text(
                  conversation.unreadCount > 99
                      ? '99+'
                      : (conversation.unreadCount > 9
                            ? '9+'
                            : '${conversation.unreadCount}'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _SignInDialog extends StatefulWidget {
  @override
  State<_SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<_SignInDialog> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final chatProvider = context.read<ChatProvider>();
      await chatProvider.signInWithGoogle();

      if (mounted) {
        Navigator.of(context).pop();
        // Set up notification tap handler
        chatProvider.setOnNotificationTapped((conversationId) {
          final conversation = chatProvider.conversations.firstWhere(
            (c) => c.id == conversationId,
          );
          final otherUserEmail = conversation.getOtherUserEmail(
            chatProvider.currentUserEmail!,
          );
          final otherUserDisplayName =
              conversation.getOtherUserDisplayName(
                chatProvider.currentUserEmail!,
              ) ??
              otherUserEmail.split('@').first;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatConversationScreen(
                conversation: conversation,
                otherUserEmail: otherUserEmail,
                otherUserDisplayName: otherUserDisplayName,
              ),
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sign In to Chat'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Sign in with Google to start chatting with friends',
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your email and profile will be used for secure authentication',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _signInWithGoogle,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.login, size: 20),
          label: Text(_isLoading ? 'Signing in...' : 'Sign in with Google'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }
}
