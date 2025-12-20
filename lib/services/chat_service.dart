import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:elysian/models/chat_models.dart';
import 'package:uuid/uuid.dart';
import 'package:async/async.dart';

/// Service for managing chat functionality using Firestore
/// Optimized for performance and budget
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final _uuid = const Uuid();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream subscriptions
  final Map<String, StreamSubscription> _subscriptions = {};
  Timer? _cleanupTimer;

  // Callbacks
  Function(FriendRequest)? onFriendRequestReceived;
  Function(ChatConversation)? onConversationUpdated;
  Function(DirectChatMessage)? onNewMessage;
  Function(String conversationId)? onConversationExpired;

  /// Initialize the service
  void initialize() {
    // Start periodic cleanup of expired messages (every hour)
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _cleanupExpiredMessages();
    });
  }

  /// Dispose the service
  void dispose() {
    _cleanupTimer?.cancel();
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// Get or create user profile
  Future<ChatUser> getOrCreateUser({
    required String email,
    String? displayName,
  }) async {
    try {
      final userRef = _firestore.collection('chat_users').doc(email);
      final userDoc = await userRef.get();

      if (userDoc.exists) {
        return ChatUser.fromJson({'email': email, ...userDoc.data()!});
      } else {
        // Create new user
        final newUser = ChatUser(
          email: email,
          displayName: displayName ?? email.split('@').first,
          createdAt: DateTime.now(),
        );
        await userRef.set(newUser.toJson());
        return newUser;
      }
    } catch (e) {
      debugPrint('Error getting/creating user: $e');
      rethrow;
    }
  }

  /// Update user's last seen timestamp
  Future<void> updateLastSeen(String email) async {
    try {
      await _firestore.collection('chat_users').doc(email).update({
        'lastSeen': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error updating last seen: $e');
    }
  }

  /// Send a friend request
  Future<void> sendFriendRequest({
    required String fromEmail,
    required String toEmail,
    String? fromDisplayName,
  }) async {
    try {
      // Validate emails are different
      if (fromEmail.toLowerCase() == toEmail.toLowerCase()) {
        throw Exception('Cannot send request to yourself');
      }

      // Check if request already exists
      final existingRequest = await _firestore
          .collection('friend_requests')
          .where('fromEmail', isEqualTo: fromEmail)
          .where('toEmail', isEqualTo: toEmail)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('Friend request already sent');
      }

      // Check if users are already friends
      final conversation = await getConversation(
        user1Email: fromEmail,
        user2Email: toEmail,
      );
      if (conversation != null) {
        throw Exception('Users are already friends');
      }

      // Get recipient's display name
      final toUserDoc = await _firestore
          .collection('chat_users')
          .doc(toEmail)
          .get();
      final toDisplayName = toUserDoc.exists
          ? (toUserDoc.data()?['displayName'] as String?)
          : null;

      // Create friend request
      final requestId = _uuid.v4();
      final request = FriendRequest(
        id: requestId,
        fromEmail: fromEmail,
        toEmail: toEmail,
        status: FriendRequestStatus.pending,
        createdAt: DateTime.now(),
        fromDisplayName: fromDisplayName,
        toDisplayName: toDisplayName,
      );

      await _firestore
          .collection('friend_requests')
          .doc(requestId)
          .set(request.toJson());

      debugPrint('Friend request sent: $fromEmail -> $toEmail');
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      rethrow;
    }
  }

  /// Accept a friend request
  Future<ChatConversation> acceptFriendRequest(
    String requestId, {
    String? currentUserEmail,
  }) async {
    try {
      // Security: Validate input
      if (requestId.trim().isEmpty) {
        throw Exception('Request ID cannot be empty');
      }

      final requestRef = _firestore
          .collection('friend_requests')
          .doc(requestId);
      final requestDoc = await requestRef.get();

      if (!requestDoc.exists) {
        throw Exception('Friend request not found');
      }

      final request = FriendRequest.fromJson({
        'id': requestId,
        ...requestDoc.data()!,
      });

      // Security: Verify current user is the recipient
      if (currentUserEmail != null) {
        if (request.toEmail.toLowerCase() != currentUserEmail.toLowerCase()) {
          throw Exception(
            'Unauthorized: You can only accept requests sent to you',
          );
        }
      }

      if (request.status != FriendRequestStatus.pending) {
        throw Exception('Friend request already responded to');
      }

      // Update request status atomically
      await requestRef.update({
        'status': FriendRequestStatus.accepted.name,
        'respondedAt': DateTime.now().toIso8601String(),
      });

      // Create conversation (this will be picked up by real-time listeners for both users)
      final conversation = await createConversation(
        user1Email: request.fromEmail,
        user2Email: request.toEmail,
        user1DisplayName: request.fromDisplayName,
        user2DisplayName: request.toDisplayName,
      );

      debugPrint('Friend request accepted: $requestId');
      return conversation;
    } catch (e) {
      debugPrint('Error accepting friend request: $e');
      rethrow;
    }
  }

  /// Reject a friend request
  Future<void> rejectFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friend_requests').doc(requestId).update({
        'status': FriendRequestStatus.rejected.name,
        'respondedAt': DateTime.now().toIso8601String(),
      });
      debugPrint('Friend request rejected: $requestId');
    } catch (e) {
      debugPrint('Error rejecting friend request: $e');
      rethrow;
    }
  }

  /// Get pending friend requests for a user
  Future<List<FriendRequest>> getPendingFriendRequests(String email) async {
    try {
      final snapshot = await _firestore
          .collection('friend_requests')
          .where('toEmail', isEqualTo: email)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => FriendRequest.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      debugPrint('Error getting pending requests: $e');
      return [];
    }
  }

  /// Get sent friend requests
  Future<List<FriendRequest>> getSentFriendRequests(String email) async {
    try {
      final snapshot = await _firestore
          .collection('friend_requests')
          .where('fromEmail', isEqualTo: email)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => FriendRequest.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      debugPrint('Error getting sent requests: $e');
      return [];
    }
  }

  /// Create or get conversation between two users
  Future<ChatConversation> createConversation({
    required String user1Email,
    required String user2Email,
    String? user1DisplayName,
    String? user2DisplayName,
  }) async {
    try {
      // Security: Validate inputs
      final normalizedUser1 = user1Email.toLowerCase().trim();
      final normalizedUser2 = user2Email.toLowerCase().trim();

      if (normalizedUser1.isEmpty || normalizedUser2.isEmpty) {
        throw Exception('Email addresses cannot be empty');
      }
      if (normalizedUser1 == normalizedUser2) {
        throw Exception('Cannot create conversation with yourself');
      }

      // Check if conversation already exists
      final existing = await getConversation(
        user1Email: normalizedUser1,
        user2Email: normalizedUser2,
      );
      if (existing != null) {
        return existing;
      }

      // Create conversation ID (sorted emails for consistency)
      final emails = [normalizedUser1, normalizedUser2]..sort();
      final conversationId = '${emails[0]}_${emails[1]}';

      final expiresAt = DateTime.now().add(const Duration(hours: 24));

      final conversation = ChatConversation(
        id: conversationId,
        user1Email: emails[0],
        user2Email: emails[1],
        user1DisplayName: emails[0] == user1Email
            ? user1DisplayName
            : user2DisplayName,
        user2DisplayName: emails[1] == user2Email
            ? user2DisplayName
            : user1DisplayName,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
      );

      await _firestore
          .collection('chat_conversations')
          .doc(conversationId)
          .set(conversation.toJson());

      return conversation;
    } catch (e) {
      debugPrint('Error creating conversation: $e');
      rethrow;
    }
  }

  /// Get conversation between two users
  Future<ChatConversation?> getConversation({
    required String user1Email,
    required String user2Email,
  }) async {
    try {
      final emails = [user1Email, user2Email]..sort();
      final conversationId = '${emails[0]}_${emails[1]}';

      final doc = await _firestore
          .collection('chat_conversations')
          .doc(conversationId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return ChatConversation.fromJson({'id': conversationId, ...doc.data()!});
    } catch (e) {
      debugPrint('Error getting conversation: $e');
      return null;
    }
  }

  /// Get all conversations for a user
  Future<List<ChatConversation>> getConversations(String email) async {
    try {
      final snapshot = await _firestore
          .collection('chat_conversations')
          .where('user1Email', isEqualTo: email)
          .get();

      final snapshot2 = await _firestore
          .collection('chat_conversations')
          .where('user2Email', isEqualTo: email)
          .get();

      final allConversations = <ChatConversation>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        // Check if expired
        if (data['expiresAt'] != null) {
          final expiresAt = DateTime.parse(data['expiresAt'] as String);
          if (DateTime.now().isAfter(expiresAt)) {
            continue; // Skip expired conversations
          }
        }
        allConversations.add(
          ChatConversation.fromJson({'id': doc.id, ...data}),
        );
      }

      for (final doc in snapshot2.docs) {
        final data = doc.data();
        // Check if expired
        if (data['expiresAt'] != null) {
          final expiresAt = DateTime.parse(data['expiresAt'] as String);
          if (DateTime.now().isAfter(expiresAt)) {
            continue; // Skip expired conversations
          }
        }
        allConversations.add(
          ChatConversation.fromJson({'id': doc.id, ...data}),
        );
      }

      // Sort by last message time
      allConversations.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      return allConversations;
    } catch (e) {
      debugPrint('Error getting conversations: $e');
      return [];
    }
  }

  /// Listen to conversations for a user (real-time)
  Stream<List<ChatConversation>> listenToConversations(String email) {
    // Use composite query with OR logic (Firestore limitation workaround)
    // We'll listen to both queries and merge results
    final stream1 = _firestore
        .collection('chat_conversations')
        .where('user1Email', isEqualTo: email)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    ChatConversation.fromJson({'id': doc.id, ...doc.data()}),
              )
              .where((conv) {
                // Filter expired conversations
                if (conv.expiresAt == null) return true;
                return !DateTime.now().isAfter(conv.expiresAt!);
              })
              .toList(),
        );

    final stream2 = _firestore
        .collection('chat_conversations')
        .where('user2Email', isEqualTo: email)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    ChatConversation.fromJson({'id': doc.id, ...doc.data()}),
              )
              .where((conv) {
                // Filter expired conversations
                if (conv.expiresAt == null) return true;
                return !DateTime.now().isAfter(conv.expiresAt!);
              })
              .toList(),
        );

    // Merge and deduplicate streams
    return StreamZip([stream1, stream2]).map((lists) {
      final all = <String, ChatConversation>{};
      for (final conv in lists.expand((list) => list)) {
        all[conv.id] = conv;
      }
      final result = all.values.toList();
      result.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      return result;
    });
  }

  /// Listen to friend requests for a user (real-time)
  Stream<List<FriendRequest>> listenToFriendRequests(String email) {
    return _firestore
        .collection('friend_requests')
        .where('toEmail', isEqualTo: email)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => FriendRequest.fromJson({'id': doc.id, ...doc.data()}),
              )
              .toList(),
        );
  }

  /// Listen to sent friend requests for a user (real-time)
  Stream<List<FriendRequest>> listenToSentFriendRequests(String email) {
    return _firestore
        .collection('friend_requests')
        .where('fromEmail', isEqualTo: email)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => FriendRequest.fromJson({'id': doc.id, ...doc.data()}),
              )
              .toList(),
        );
  }

  /// Send a message
  Future<void> sendMessage({
    required String conversationId,
    required String senderEmail,
    required String message,
    String? senderDisplayName,
  }) async {
    try {
      // Security: Validate inputs
      if (conversationId.trim().isEmpty) {
        throw Exception('Conversation ID cannot be empty');
      }
      if (senderEmail.trim().isEmpty) {
        throw Exception('Sender email cannot be empty');
      }
      final trimmedMessage = message.trim();
      if (trimmedMessage.isEmpty) {
        throw Exception('Message cannot be empty');
      }
      // Security: Limit message length
      if (trimmedMessage.length > 5000) {
        throw Exception('Message is too long (max 5000 characters)');
      }

      // Check if conversation exists and is not expired
      final convDoc = await _firestore
          .collection('chat_conversations')
          .doc(conversationId)
          .get();

      if (!convDoc.exists) {
        throw Exception('Conversation not found');
      }

      final convData = convDoc.data()!;

      // Security: Verify sender is part of the conversation
      final user1Email = convData['user1Email'] as String?;
      final user2Email = convData['user2Email'] as String?;
      if (user1Email?.toLowerCase() != senderEmail.toLowerCase() &&
          user2Email?.toLowerCase() != senderEmail.toLowerCase()) {
        throw Exception('Unauthorized: You are not part of this conversation');
      }

      if (convData['expiresAt'] != null) {
        final expiresAt = DateTime.parse(convData['expiresAt'] as String);
        if (DateTime.now().isAfter(expiresAt)) {
          throw Exception('Conversation has expired');
        }
      }

      // Create message
      final messageId = _uuid.v4();
      final expiresAt = DateTime.now().add(const Duration(hours: 24));
      final now = DateTime.now();

      final chatMessage = DirectChatMessage(
        id: messageId,
        conversationId: conversationId,
        senderEmail: senderEmail.toLowerCase().trim(),
        senderDisplayName: senderDisplayName?.trim(),
        message: trimmedMessage,
        timestamp: now,
        expiresAt: expiresAt,
        isRead: false,
      );

      // Save message
      await _firestore
          .collection('chat_conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .set(chatMessage.toJson());

      // Update conversation
      // Note: We increment unread count for the other user
      // Using FieldValue.increment for atomic operation
      await _firestore
          .collection('chat_conversations')
          .doc(conversationId)
          .update({
            'lastMessageAt': now.toIso8601String(),
            'lastMessage': trimmedMessage,
            // Reset expiration when new message is sent
            'expiresAt': expiresAt.toIso8601String(),
            // Increment unread count for the other user only (atomic operation)
            'unreadCount': FieldValue.increment(1),
          });

      debugPrint('Message sent: $conversationId');
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Get messages for a conversation with pagination support
  Future<List<DirectChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    DirectChatMessage? startAfter, // For pagination
  }) async {
    try {
      var query = _firestore
          .collection('chat_conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      // Pagination: start after the specified message
      if (startAfter != null) {
        query = query.startAfter([startAfter.timestamp]);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map(
            (doc) => DirectChatMessage.fromJson({'id': doc.id, ...doc.data()}),
          )
          .where((msg) => !msg.isExpired) // Filter expired messages
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } catch (e) {
      debugPrint('Error getting messages: $e');
      return [];
    }
  }

  /// Listen to messages in a conversation (real-time)
  /// Optimized: Only listens to recent messages to reduce costs
  Stream<List<DirectChatMessage>> listenToMessages(
    String conversationId, {
    int limit = 50, // Reduced from 100 to save costs
  }) {
    return _firestore
        .collection('chat_conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit) // Optimized limit for cost efficiency
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    DirectChatMessage.fromJson({'id': doc.id, ...doc.data()}),
              )
              .where((msg) => !msg.isExpired) // Filter expired messages
              .toList(),
        )
        .map((messages) {
          // Sort chronologically
          messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return messages;
        });
  }

  /// Set typing indicator for a user in a conversation
  Future<void> setTypingIndicator({
    required String conversationId,
    required String userEmail,
    required bool isTyping,
  }) async {
    try {
      if (conversationId.trim().isEmpty || userEmail.trim().isEmpty) {
        return;
      }

      await _firestore
          .collection('chat_conversations')
          .doc(conversationId)
          .update({
            'typingUserEmail': isTyping ? userEmail.toLowerCase().trim() : null,
            'typingUpdatedAt': isTyping
                ? DateTime.now().toIso8601String()
                : null,
          });
    } catch (e) {
      debugPrint('Error setting typing indicator: $e');
      // Don't throw - typing indicator is non-critical
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(
    String conversationId,
    String currentUserEmail,
  ) async {
    try {
      // Get all unread messages and filter client-side
      // Firestore doesn't support isNotEqualTo in where clauses
      final snapshot = await _firestore
          .collection('chat_conversations')
          .doc(conversationId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) return;

      // Filter to only messages from other users
      final unreadMessages = snapshot.docs.where((doc) {
        final data = doc.data();
        return data['senderEmail'] != currentUserEmail;
      }).toList();

      if (unreadMessages.isEmpty) return;

      // Batch update with readAt timestamp
      final readAt = DateTime.now();
      final batch = _firestore.batch();
      for (final doc in unreadMessages) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': readAt.toIso8601String(),
        });
      }
      await batch.commit();

      // Reset unread count in conversation
      await _firestore
          .collection('chat_conversations')
          .doc(conversationId)
          .update({'unreadCount': 0});

      debugPrint('Messages marked as read: $conversationId');
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  /// Cleanup expired messages and conversations
  Future<void> _cleanupExpiredMessages() async {
    try {
      final now = DateTime.now();

      // Cleanup expired conversations
      final conversationsSnapshot = await _firestore
          .collection('chat_conversations')
          .where('expiresAt', isLessThan: now.toIso8601String())
          .limit(50) // Process in batches
          .get();

      final batch = _firestore.batch();
      for (final doc in conversationsSnapshot.docs) {
        // Delete conversation and all its messages
        final messagesSnapshot = await doc.reference
            .collection('messages')
            .get();
        for (final msgDoc in messagesSnapshot.docs) {
          batch.delete(msgDoc.reference);
        }
        batch.delete(doc.reference);
      }

      if (conversationsSnapshot.docs.isNotEmpty) {
        await batch.commit();
        debugPrint(
          'Cleaned up ${conversationsSnapshot.docs.length} expired conversations',
        );
      }

      // Cleanup expired messages in active conversations
      final activeConversations = await _firestore
          .collection('chat_conversations')
          .where('expiresAt', isGreaterThan: now.toIso8601String())
          .get();

      for (final convDoc in activeConversations.docs) {
        final expiredMessages = await convDoc.reference
            .collection('messages')
            .where('expiresAt', isLessThan: now.toIso8601String())
            .limit(50)
            .get();

        if (expiredMessages.docs.isNotEmpty) {
          final msgBatch = _firestore.batch();
          for (final msgDoc in expiredMessages.docs) {
            msgBatch.delete(msgDoc.reference);
          }
          await msgBatch.commit();
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up expired messages: $e');
    }
  }

  /// Delete a conversation (manual deletion)
  Future<void> deleteConversation(String conversationId) async {
    try {
      // Delete all messages first
      final messagesSnapshot = await _firestore
          .collection('chat_conversations')
          .doc(conversationId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (final msgDoc in messagesSnapshot.docs) {
        batch.delete(msgDoc.reference);
      }
      await batch.commit();

      // Delete conversation
      await _firestore
          .collection('chat_conversations')
          .doc(conversationId)
          .delete();

      debugPrint('Conversation deleted: $conversationId');
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      rethrow;
    }
  }
}
