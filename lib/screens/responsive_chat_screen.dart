import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elysian/providers/chat_provider.dart';
import 'package:elysian/models/chat_models.dart';
import 'package:elysian/widgets/responsive.dart';
import 'package:elysian/widgets/message_notification.dart';
import 'package:elysian/screens/friend_request_screen.dart';
import 'package:elysian/screens/chat_room_list_screen.dart';
import 'package:elysian/screens/chat_conversation_screen.dart';
import 'package:intl/intl.dart';

/// Responsive chat screen that adapts to screen size
/// Mobile: Shows list, navigates to conversation
/// Desktop/Tablet: Shows list and conversation side-by-side
class ResponsiveChatScreen extends StatefulWidget {
  const ResponsiveChatScreen({super.key});

  @override
  State<ResponsiveChatScreen> createState() => _ResponsiveChatScreenState();
}

class _ResponsiveChatScreenState extends State<ResponsiveChatScreen> {
  String? _selectedConversationId;
  ChatConversation? _selectedConversation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  Future<void> _initializeChat() async {
    final chatProvider = context.read<ChatProvider>();
    await chatProvider.initialize();

    if (chatProvider.currentUserEmail == null) {
      _showSignInDialog();
    } else {
      chatProvider.setOnNotificationTapped((conversationId) {
        _selectConversation(conversationId, chatProvider);
      });
    }
  }

  void _selectConversation(String conversationId, ChatProvider provider) {
    final conversation = provider.conversations.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => throw Exception('Conversation not found'),
    );

    setState(() {
      _selectedConversationId = conversationId;
      _selectedConversation = conversation;
    });

    // On mobile, navigate to conversation screen
    if (Responsive.isMobile(context)) {
      final otherUserEmail = conversation.getOtherUserEmail(
        provider.currentUserEmail!,
      );
      final otherUserDisplayName =
          conversation.getOtherUserDisplayName(provider.currentUserEmail!) ??
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
    }
  }

  void _showSignInDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SignInDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final chatProvider = context.watch<ChatProvider>();

    return MessageNotificationOverlay(
      chatProvider: chatProvider,
      child: Scaffold(
        body: isDesktop
            ? _buildDesktopLayout(chatProvider)
            : _buildMobileLayout(chatProvider),
      ),
    );
  }

  /// Desktop/Tablet layout: Side-by-side
  Widget _buildDesktopLayout(ChatProvider chatProvider) {
    return Row(
      children: [
        // Conversation list sidebar
        Container(
          width: 400,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              right: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: _ConversationList(
            conversations: chatProvider.conversations,
            selectedConversationId: _selectedConversationId,
            onConversationSelected: (conversation) {
              _selectConversation(conversation.id, chatProvider);
            },
            currentUserEmail: chatProvider.currentUserEmail,
            currentUserDisplayName: chatProvider.currentUserDisplayName,
            onSignIn: _showSignInDialog,
            onFriendRequests: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FriendRequestScreen()),
              );
            },
            onChatRooms: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatRoomListScreen()),
              );
            },
          ),
        ),
        // Conversation view
        Expanded(
          child: _selectedConversation != null
              ? _buildConversationView(_selectedConversation!, chatProvider)
              : _buildEmptyConversationView(),
        ),
      ],
    );
  }

  /// Mobile layout: Full screen list
  Widget _buildMobileLayout(ChatProvider chatProvider) {
    return _ConversationList(
      conversations: chatProvider.conversations,
      selectedConversationId: _selectedConversationId,
      onConversationSelected: (conversation) {
        _selectConversation(conversation.id, chatProvider);
      },
      currentUserEmail: chatProvider.currentUserEmail,
      currentUserDisplayName: chatProvider.currentUserDisplayName,
      onSignIn: _showSignInDialog,
      onFriendRequests: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FriendRequestScreen()),
        );
      },
      onChatRooms: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatRoomListScreen()),
        );
      },
    );
  }

  /// Conversation view for desktop
  Widget _buildConversationView(
    ChatConversation conversation,
    ChatProvider provider,
  ) {
    final otherUserEmail = conversation.getOtherUserEmail(
      provider.currentUserEmail!,
    );
    final otherUserDisplayName =
        conversation.getOtherUserDisplayName(provider.currentUserEmail!) ??
            otherUserEmail.split('@').first;

    return Column(
      children: [
        // Desktop header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  otherUserDisplayName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      otherUserDisplayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      otherUserEmail,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Conversation content
        Expanded(
          child: ChatConversationScreen(
            conversation: conversation,
            otherUserEmail: otherUserEmail,
            otherUserDisplayName: otherUserDisplayName,
          ),
        ),
      ],
    );
  }

  /// Empty state when no conversation is selected (desktop)
  Widget _buildEmptyConversationView() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a conversation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.grey.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a conversation from the list to start chatting',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Beautiful conversation list widget
class _ConversationList extends StatelessWidget {
  final List<ChatConversation> conversations;
  final String? selectedConversationId;
  final Function(ChatConversation) onConversationSelected;
  final String? currentUserEmail;
  final String? currentUserDisplayName;
  final VoidCallback onSignIn;
  final VoidCallback onFriendRequests;
  final VoidCallback onChatRooms;

  const _ConversationList({
    required this.conversations,
    required this.selectedConversationId,
    required this.onConversationSelected,
    required this.currentUserEmail,
    required this.currentUserDisplayName,
    required this.onSignIn,
    required this.onFriendRequests,
    required this.onChatRooms,
  });

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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: const Text(
          'Chat',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (currentUserEmail != null) ...[
            PopupMenuButton<String>(
              icon: CircleAvatar(
                backgroundColor: Colors.blue,
                radius: 18,
                child: Text(
                  _getUserInitial(currentUserDisplayName, currentUserEmail),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              onSelected: (value) {
                if (value == 'signout') {
                  context.read<ChatProvider>().signOut();
                }
              },
              itemBuilder: (context) => [
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
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.group),
              tooltip: 'Chat Rooms',
              onPressed: onChatRooms,
            ),
            Consumer<ChatProvider>(
              builder: (context, provider, _) {
                final pendingCount = provider.pendingRequests.length;
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.person_add),
                      tooltip: 'Friend Requests',
                      onPressed: onFriendRequests,
                    ),
                    if (pendingCount > 0)
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
                            pendingCount > 9 ? '9+' : '$pendingCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: currentUserEmail == null
          ? _buildSignInPrompt()
          : Column(
              children: [
                // Search bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search conversations...',
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey.withOpacity(0.7),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                // Conversations list
                Expanded(
                  child: conversations.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: conversations.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.grey.withOpacity(0.1),
                            indent: 80,
                          ),
                          itemBuilder: (context, index) {
                            final conversation = conversations[index];
                            final isSelected =
                                conversation.id == selectedConversationId;

                            return _ConversationTile(
                              conversation: conversation,
                              isSelected: isSelected,
                              currentUserEmail: currentUserEmail!,
                              onTap: () => onConversationSelected(conversation),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSignInPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sign in to start chatting',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in with Google to access chat features',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onSignIn,
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new conversation to begin chatting',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Beautiful conversation tile
class _ConversationTile extends StatelessWidget {
  final ChatConversation conversation;
  final bool isSelected;
  final String currentUserEmail;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.isSelected,
    required this.currentUserEmail,
    required this.onTap,
  });

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
    final theme = Theme.of(context);
    final otherUserEmail = conversation.getOtherUserEmail(currentUserEmail);
    final otherUserDisplayName =
        conversation.getOtherUserDisplayName(currentUserEmail) ??
            otherUserEmail.split('@').first;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected
            ? theme.colorScheme.primary.withOpacity(0.1)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    _getUserInitial(otherUserDisplayName, otherUserEmail),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (conversation.unreadCount > 0)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        conversation.unreadCount > 9
                            ? '9+'
                            : '${conversation.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherUserDisplayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: conversation.unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.lastMessageAt != null)
                        Text(
                          _formatTime(conversation.lastMessageAt!),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.light
                                ? Colors.grey[600]
                                : Colors.grey[400],
                            fontWeight: conversation.unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child:                         Text(
                          conversation.lastMessage ?? 'No messages yet',
                          style: TextStyle(
                            fontSize: 14,
                            color: conversation.unreadCount > 0
                                ? theme.colorScheme.onSurface
                                : Theme.of(context).brightness == Brightness.light
                                    ? Colors.grey[700]
                                    : Colors.grey[400],
                            fontWeight: conversation.unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            conversation.unreadCount > 9
                                ? '9+'
                                : '${conversation.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
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

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(time);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(time);
    } else {
      return DateFormat('MMM d').format(time);
    }
  }
}

/// Sign in dialog
class _SignInDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final chatProvider = context.read<ChatProvider>();

    return AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Row(
        children: [
          Icon(Icons.chat, color: Colors.amber),
          SizedBox(width: 8),
          Text(
            'Sign In to Chat',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
      content: const Text(
        'Please sign in with Google to use chat features.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            try {
              await chatProvider.signInWithGoogle();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sign in failed: $e')),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
          ),
          child: const Text('Sign In'),
        ),
      ],
    );
  }
}

