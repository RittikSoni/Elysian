import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:elysian/models/chat_models.dart';
import 'package:elysian/services/chat_service.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/services/auth_service.dart';
import 'package:elysian/services/chat_cache_service.dart';

/// Provider for managing chat state
/// Optimized for memory, performance, and cost efficiency
class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final ChatCacheService _cacheService = ChatCacheService();

  String? _currentUserEmail;
  String? _currentUserDisplayName;
  ChatUser? _currentUser;

  List<ChatConversation> _conversations = [];
  List<FriendRequest> _pendingRequests = [];
  List<FriendRequest> _sentRequests = [];
  Map<String, List<DirectChatMessage>> _messages = {};
  final Map<String, StreamSubscription> _subscriptions = {};

  bool _isLoading = false;
  String? _error;

  // Notification tracking
  DirectChatMessage? _latestNewMessage;
  String? _latestNewMessageConversationId;
  String? _currentlyViewingConversationId;
  Function(String conversationId)? _onNotificationTapped;

  // Pagination tracking
  final Map<String, bool> _hasMoreMessages = {};
  final Map<String, bool> _isLoadingMoreMessages = {};

  // Typing indicators
  final Map<String, String?> _typingUsers = {};

  // Optimistic message tracking (for UI updates before server confirmation)
  final Map<String, DirectChatMessage> _optimisticMessages = {};

  // Getters
  String? get currentUserEmail => _currentUserEmail;
  String? get currentUserDisplayName => _currentUserDisplayName;
  ChatUser? get currentUser => _currentUser;
  List<ChatConversation> get conversations => _conversations;
  List<FriendRequest> get pendingRequests => _pendingRequests;
  List<FriendRequest> get sentRequests => _sentRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<DirectChatMessage> getMessages(String conversationId) {
    final messages = _messages[conversationId] ?? [];
    // Merge with optimistic messages
    final optimistic = _optimisticMessages.values
        .where((m) => m.conversationId == conversationId)
        .toList();

    if (optimistic.isEmpty) return messages;

    // Combine and sort
    final allMessages = [...messages, ...optimistic];
    allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Remove duplicates (optimistic messages that are now confirmed)
    final seenIds = <String>{};
    return allMessages.where((m) {
      if (seenIds.contains(m.id)) return false;
      seenIds.add(m.id);
      return true;
    }).toList();
  }

  bool hasMoreMessages(String conversationId) {
    return _hasMoreMessages[conversationId] ?? false;
  }

  bool isLoadingMoreMessages(String conversationId) {
    return _isLoadingMoreMessages[conversationId] ?? false;
  }

  String? getTypingUser(String conversationId) {
    return _typingUsers[conversationId];
  }

  int get totalUnreadCount {
    return _conversations.fold(0, (sum, conv) => sum + conv.unreadCount);
  }

  // Notification getters
  DirectChatMessage? get latestNewMessage => _latestNewMessage;
  String? get latestNewMessageConversationId => _latestNewMessageConversationId;

  bool isViewingConversation(String conversationId) {
    return _currentlyViewingConversationId == conversationId;
  }

  void setViewingConversation(String? conversationId) {
    _currentlyViewingConversationId = conversationId;
    // Clear notification if viewing the conversation
    if (conversationId == _latestNewMessageConversationId) {
      _latestNewMessage = null;
      _latestNewMessageConversationId = null;
    }
  }

  void setOnNotificationTapped(Function(String conversationId)? callback) {
    _onNotificationTapped = callback;
  }

  void onNotificationTapped(String conversationId) {
    _onNotificationTapped?.call(conversationId);
  }

  /// Initialize the provider
  Future<void> initialize() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Check for Google Sign-In first
      final googleAccount = await _authService.getLastSignedInAccount();

      if (googleAccount != null) {
        // User is signed in with Google
        _currentUserEmail = googleAccount.email;
        _currentUserDisplayName =
            googleAccount.displayName ?? googleAccount.email.split('@').first;

        // Save to storage for backward compatibility
        await StorageService.setUserEmail(_currentUserEmail!);
        await StorageService.setUserDisplayName(_currentUserDisplayName!);
      } else {
        // Fallback to stored email (for backward compatibility)
        final storedEmail = await StorageService.getUserEmail();
        // Check for both null and empty string
        if (storedEmail != null && storedEmail.trim().isNotEmpty) {
          _currentUserEmail = storedEmail;
          _currentUserDisplayName = await StorageService.getUserDisplayName();
        } else {
          _currentUserEmail = null;
          _currentUserDisplayName = null;
        }
      }

      // Check for both null and empty string
      if (_currentUserEmail == null || _currentUserEmail!.trim().isEmpty) {
        _isLoading = false;
        notifyListeners();
        return; // User not set up yet
      }

      // Get or create user profile
      _currentUser = await _chatService.getOrCreateUser(
        email: _currentUserEmail!,
        displayName: _currentUserDisplayName,
      );

      // Update display name if changed
      if (_currentUserDisplayName != _currentUser?.displayName) {
        await StorageService.setUserDisplayName(
          _currentUser?.displayName ?? _currentUserEmail!.split('@').first,
        );
        _currentUserDisplayName = _currentUser?.displayName;
      }

      // Set up real-time listeners
      _setupListeners();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize chat: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('ChatProvider initialization error: $e');
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final account = await _authService.signIn();
      if (account == null) {
        _isLoading = false;
        notifyListeners();
        return; // User cancelled sign-in
      }

      _currentUserEmail = account.email;
      _currentUserDisplayName =
          account.displayName ?? account.email.split('@').first;

      // Save to storage
      await StorageService.setUserEmail(_currentUserEmail!);
      await StorageService.setUserDisplayName(_currentUserDisplayName!);

      // Get or create user profile
      _currentUser = await _chatService.getOrCreateUser(
        email: _currentUserEmail!,
        displayName: _currentUserDisplayName,
      );

      // Set up real-time listeners
      _setupListeners();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to sign in: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Sign out from Google and Firebase
      await _authService.signOut();

      // Clear local state
      _currentUserEmail = null;
      _currentUserDisplayName = null;
      _currentUser = null;
      _conversations = [];
      _pendingRequests = [];
      _sentRequests = [];
      _messages = {};

      // Cancel all subscriptions
      for (final subscription in _subscriptions.values) {
        subscription.cancel();
      }
      _subscriptions.clear();

      // Clear storage to ensure clean sign-out
      await StorageService.setUserEmail('');
      await StorageService.setUserDisplayName('');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to sign out: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Set up user email (deprecated - use signInWithGoogle instead)
  /// Kept for backward compatibility
  @Deprecated('Use signInWithGoogle() instead for better security')
  Future<void> setUserEmail(String email, {String? displayName}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final normalizedEmail = email.toLowerCase().trim();
      if (!_isValidEmail(normalizedEmail)) {
        throw Exception('Invalid email address');
      }

      // Save to storage
      await StorageService.setUserEmail(normalizedEmail);
      if (displayName != null) {
        await StorageService.setUserDisplayName(displayName);
      }

      _currentUserEmail = normalizedEmail;
      _currentUserDisplayName = displayName ?? normalizedEmail.split('@').first;

      // Get or create user profile
      _currentUser = await _chatService.getOrCreateUser(
        email: _currentUserEmail!,
        displayName: _currentUserDisplayName,
      );

      // Set up real-time listeners
      _setupListeners();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to set user email: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Set up real-time listeners
  void _setupListeners() {
    if (_currentUserEmail == null) return;

    // Cancel existing subscriptions
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Listen to conversations
    _subscriptions['conversations'] = _chatService
        .listenToConversations(_currentUserEmail!)
        .listen(
          (conversations) {
            // Update typing indicators from conversation data
            for (final conversation in conversations) {
              _typingUsers[conversation.id] = conversation.typingUserEmail;
            }

            // Check for new messages in conversations
            // OPTIMIZATION: Only listen to messages for conversations with recent activity
            // Don't listen to all conversations to save costs
            for (final conversation in conversations) {
              // Only listen to messages if:
              // 1. Conversation is being viewed, OR
              // 2. Conversation has unread messages, OR
              // 3. Conversation has very recent activity (last 5 minutes)
              final hasRecentActivity =
                  conversation.lastMessageAt != null &&
                  DateTime.now().difference(conversation.lastMessageAt!) <
                      const Duration(minutes: 5);

              final shouldListen =
                  conversation.id == _currentlyViewingConversationId ||
                  conversation.unreadCount > 0 ||
                  hasRecentActivity;

              if (shouldListen &&
                  !_subscriptions.containsKey('messages_${conversation.id}')) {
                listenToMessages(conversation.id);
              } else if (!shouldListen &&
                  _subscriptions.containsKey('messages_${conversation.id}') &&
                  conversation.id != _currentlyViewingConversationId) {
                // Stop listening to inactive conversations to save costs
                stopListeningToMessages(conversation.id);
              }
            }

            _conversations = conversations;

            // Cache conversations
            _cacheService.cacheConversations(conversations);

            notifyListeners();
          },
          onError: (error) {
            debugPrint('Error listening to conversations: $error');
            _error = 'Failed to load conversations';
            notifyListeners();
          },
        );

    // Listen to friend requests
    _subscriptions['friendRequests'] = _chatService
        .listenToFriendRequests(_currentUserEmail!)
        .listen(
          (requests) {
            _pendingRequests = requests;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('Error listening to friend requests: $error');
          },
        );

    // Listen to sent friend requests
    _subscriptions['sentFriendRequests'] = _chatService
        .listenToSentFriendRequests(_currentUserEmail!)
        .listen(
          (requests) {
            _sentRequests = requests;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('Error listening to sent friend requests: $error');
          },
        );
  }

  /// Load sent friend requests
  Future<void> loadSentRequests() async {
    if (_currentUserEmail == null) return;

    try {
      _sentRequests = await _chatService.getSentFriendRequests(
        _currentUserEmail!,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading sent requests: $e');
    }
  }

  /// Send a friend request
  Future<void> sendFriendRequest(String toEmail) async {
    if (_currentUserEmail == null) {
      throw Exception('User email not set');
    }

    try {
      _error = null;
      await _chatService.sendFriendRequest(
        fromEmail: _currentUserEmail!,
        toEmail: toEmail.toLowerCase().trim(),
        fromDisplayName: _currentUserDisplayName,
      );
      await loadSentRequests();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Accept a friend request
  Future<void> acceptFriendRequest(String requestId) async {
    if (_currentUserEmail == null) {
      throw Exception('User email not set');
    }

    try {
      _error = null;
      // Pass current user email for security validation
      final conversation = await _chatService.acceptFriendRequest(
        requestId,
        currentUserEmail: _currentUserEmail,
      );
      // Add conversation if it doesn't already exist (real-time listener will update it)
      if (!_conversations.any((c) => c.id == conversation.id)) {
        _conversations.add(conversation);
      }
      // Real-time listeners will automatically update:
      // - conversations list (for both users) - should appear immediately
      // - pending requests (for the user who accepted) - will disappear
      // - sent requests (for the user who sent the request) - will disappear
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Reject a friend request
  Future<void> rejectFriendRequest(String requestId) async {
    try {
      _error = null;
      await _chatService.rejectFriendRequest(requestId);
      await loadPendingRequests();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Load pending friend requests
  Future<void> loadPendingRequests() async {
    if (_currentUserEmail == null) return;

    try {
      _pendingRequests = await _chatService.getPendingFriendRequests(
        _currentUserEmail!,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading pending requests: $e');
    }
  }

  /// Load conversations (with caching)
  Future<void> loadConversations({bool forceRefresh = false}) async {
    if (_currentUserEmail == null) return;

    try {
      _isLoading = true;
      _error = null;

      // Try to load from cache first (unless force refresh)
      if (!forceRefresh) {
        final cached = await _cacheService.getCachedConversations();
        if (cached != null && cached.isNotEmpty) {
          _conversations = cached;
          _isLoading = false;
          notifyListeners();
        }
      }

      // Load from Firestore
      _conversations = await _chatService.getConversations(_currentUserEmail!);

      // Cache the result
      await _cacheService.cacheConversations(_conversations);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load conversations: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load messages for a conversation (with caching and pagination)
  Future<void> loadMessages(
    String conversationId, {
    bool loadMore = false,
  }) async {
    try {
      // Check cache first
      if (!loadMore) {
        final cached = _cacheService.getCachedMessages(conversationId);
        if (cached != null && cached.isNotEmpty) {
          _messages[conversationId] = cached;
          notifyListeners();
        }
      }

      // Determine pagination
      DirectChatMessage? startAfter;
      if (loadMore && _messages[conversationId]?.isNotEmpty == true) {
        // Load older messages
        final sortedMessages = List<DirectChatMessage>.from(
          _messages[conversationId]!,
        );
        sortedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        startAfter = sortedMessages.first;
      }

      _isLoadingMoreMessages[conversationId] = true;
      notifyListeners();

      final messages = await _chatService.getMessages(
        conversationId,
        limit: 50,
        startAfter: startAfter,
      );

      if (loadMore) {
        // Append older messages
        final existing = _messages[conversationId] ?? [];
        final combined = [...messages, ...existing];
        combined.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        _messages[conversationId] = combined;
        _hasMoreMessages[conversationId] =
            messages.length == 50; // More available if we got full limit
      } else {
        _messages[conversationId] = messages;
        _hasMoreMessages[conversationId] = messages.length == 50;
      }

      // Cache messages
      await _cacheService.cacheMessages(
        conversationId,
        _messages[conversationId]!,
      );

      _isLoadingMoreMessages[conversationId] = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading messages: $e');
      _isLoadingMoreMessages[conversationId] = false;
      notifyListeners();
    }
  }

  /// Listen to messages in a conversation (real-time)
  void listenToMessages(String conversationId) {
    if (_subscriptions.containsKey('messages_$conversationId')) {
      return; // Already listening
    }

    // Only listen to active conversations to reduce costs
    // Limit to 50 messages for cost efficiency
    _subscriptions['messages_$conversationId'] = _chatService
        .listenToMessages(conversationId, limit: 50)
        .listen(
          (messages) {
            final previousMessages = _messages[conversationId] ?? [];
            final previousMessageIds = previousMessages
                .map((m) => m.id)
                .toSet();
            _messages[conversationId] = messages;

            // Detect new messages (messages that weren't in the previous list)
            if (messages.isNotEmpty && previousMessages.isNotEmpty) {
              final newMessages = messages
                  .where((m) => !previousMessageIds.contains(m.id))
                  .toList();

              // If there's a new message and it's not from the current user
              if (newMessages.isNotEmpty &&
                  _currentUserEmail != null &&
                  newMessages.last.senderEmail.toLowerCase() !=
                      _currentUserEmail!.toLowerCase()) {
                // Only show notification if not currently viewing this conversation
                if (_currentlyViewingConversationId != conversationId) {
                  _latestNewMessage = newMessages.last;
                  _latestNewMessageConversationId = conversationId;
                  // Force notify to trigger notification overlay
                  notifyListeners();
                  // Small delay to ensure state is updated
                  Future.delayed(const Duration(milliseconds: 100), () {
                    notifyListeners();
                  });
                }
              }
            } else if (messages.isNotEmpty &&
                previousMessages.isEmpty &&
                _currentUserEmail != null &&
                messages.last.senderEmail.toLowerCase() !=
                    _currentUserEmail!.toLowerCase()) {
              // First load of messages - don't notify on initial load
              // (only notify on actual new messages)
            }

            // Cache messages
            _cacheService.cacheMessages(conversationId, messages);

            notifyListeners();
          },
          onError: (error) {
            debugPrint('Error listening to messages: $error');
            _error = 'Failed to load messages';
            notifyListeners();
          },
        );
  }

  /// Stop listening to messages (to save costs)
  void stopListeningToMessages(String conversationId) {
    final key = 'messages_$conversationId';
    _subscriptions[key]?.cancel();
    _subscriptions.remove(key);

    // Clear messages from memory if not viewing (memory optimization)
    if (_currentlyViewingConversationId != conversationId) {
      // Keep last 20 messages in memory for quick access
      final messages = _messages[conversationId];
      if (messages != null && messages.length > 20) {
        _messages[conversationId] = messages.sublist(messages.length - 20);
      }
    }
  }

  /// Send a message (with optimistic UI update)
  Future<void> sendMessage(String conversationId, String message) async {
    if (_currentUserEmail == null) return;

    try {
      _error = null;

      // Create optimistic message for immediate UI update
      final optimisticId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final optimisticMessage = DirectChatMessage(
        id: optimisticId,
        conversationId: conversationId,
        senderEmail: _currentUserEmail!,
        senderDisplayName: _currentUserDisplayName,
        message: message.trim(),
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        isRead: false,
        status: MessageStatus.sending,
      );

      // Add to optimistic messages and update UI immediately
      _optimisticMessages[optimisticId] = optimisticMessage;
      final currentMessages = _messages[conversationId] ?? [];
      _messages[conversationId] = [...currentMessages, optimisticMessage];
      notifyListeners();

      // Send to server
      await _chatService.sendMessage(
        conversationId: conversationId,
        senderEmail: _currentUserEmail!,
        message: message,
        senderDisplayName: _currentUserDisplayName,
      );

      // Remove optimistic message (real message will come via stream)
      _optimisticMessages.remove(optimisticId);
      notifyListeners();
    } catch (e) {
      // Remove failed optimistic message
      final optimisticId = _optimisticMessages.keys.firstWhere(
        (id) =>
            _optimisticMessages[id]?.conversationId == conversationId &&
            _optimisticMessages[id]?.message == message.trim(),
        orElse: () => '',
      );
      if (optimisticId.isNotEmpty) {
        _optimisticMessages.remove(optimisticId);
        final currentMessages = _messages[conversationId] ?? [];
        _messages[conversationId] = currentMessages
            .where((m) => m.id != optimisticId)
            .toList();
      }

      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Set typing indicator (with debouncing to save costs)
  Timer? _typingTimer;
  void setTypingIndicator(String conversationId, bool isTyping) {
    if (_currentUserEmail == null) return;

    // Debounce typing indicator updates (save costs)
    _typingTimer?.cancel();

    if (isTyping) {
      _chatService.setTypingIndicator(
        conversationId: conversationId,
        userEmail: _currentUserEmail!,
        isTyping: true,
      );

      // Auto-clear typing indicator after 3 seconds
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _chatService.setTypingIndicator(
          conversationId: conversationId,
          userEmail: _currentUserEmail!,
          isTyping: false,
        );
      });
    } else {
      _chatService.setTypingIndicator(
        conversationId: conversationId,
        userEmail: _currentUserEmail!,
        isTyping: false,
      );
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String conversationId) async {
    if (_currentUserEmail == null) return;

    try {
      await _chatService.markMessagesAsRead(conversationId, _currentUserEmail!);
      // Update local state
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        _conversations[index] = _conversations[index].copyWith(unreadCount: 0);
      }
      // Update messages in local cache to reflect read status
      // The real-time listener will update them, but we can also update locally
      if (_messages.containsKey(conversationId)) {
        final messages = _messages[conversationId]!;
        final now = DateTime.now();
        for (var i = 0; i < messages.length; i++) {
          if (!messages[i].isRead &&
              messages[i].senderEmail != _currentUserEmail) {
            _messages[conversationId]![i] = messages[i].copyWith(
              isRead: true,
              readAt: now,
            );
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  /// Update last seen
  Future<void> updateLastSeen() async {
    if (_currentUserEmail == null) return;

    try {
      await _chatService.updateLastSeen(_currentUserEmail!);
    } catch (e) {
      debugPrint('Error updating last seen: $e');
    }
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    try {
      _error = null;
      await _chatService.deleteConversation(conversationId);
      _conversations.removeWhere((c) => c.id == conversationId);
      _messages.remove(conversationId);
      stopListeningToMessages(conversationId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
