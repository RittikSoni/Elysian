import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:elysian/models/chat_models.dart';
import 'package:uuid/uuid.dart';

/// Service for managing chat rooms with host controls
/// Handles participant management, messaging, and auto-deletion
class ChatRoomService {
  static final ChatRoomService _instance = ChatRoomService._internal();
  factory ChatRoomService() => _instance;
  ChatRoomService._internal();

  final _uuid = const Uuid();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream subscriptions
  final Map<String, StreamSubscription> _subscriptions = {};
  Timer? _cleanupTimer;

  // Callbacks
  Function(ChatRoom)? onRoomUpdated;
  Function(RoomMessage)? onNewMessage;
  Function(String roomId)? onRoomDeleted;
  Function(String roomId, String participantEmail)? onParticipantAdded;
  Function(String roomId, String participantEmail)? onParticipantRemoved;

  /// Initialize the service
  void initialize() {
    // Start periodic cleanup of expired rooms and messages (every hour)
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _cleanupExpiredRooms();
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

  /// Create a new chat room (host)
  Future<ChatRoom> createRoom({
    required String hostEmail,
    required String roomName,
    String? roomDescription,
    String? hostDisplayName,
  }) async {
    try {
      final roomId = _uuid.v4();
      final expiresAt = DateTime.now().add(const Duration(hours: 24));

      // Create host participant
      final hostParticipant = RoomParticipant(
        email: hostEmail,
        displayName: hostDisplayName ?? hostEmail.split('@').first,
        joinedAt: DateTime.now(),
        isHost: true,
      );

      final room = ChatRoom(
        id: roomId,
        hostEmail: hostEmail,
        hostDisplayName: hostDisplayName,
        roomName: roomName,
        roomDescription: roomDescription,
        participants: [hostParticipant],
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        isActive: true,
      );

      // Save to Firestore
      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .set(room.toJson());

      debugPrint('Chat room created: $roomId by $hostEmail');
      return room;
    } catch (e) {
      debugPrint('Error creating room: $e');
      rethrow;
    }
  }

  /// Get a room by ID
  Future<ChatRoom?> getRoom(String roomId) async {
    try {
      final doc = await _firestore.collection('chat_rooms').doc(roomId).get();

      if (!doc.exists) {
        return null;
      }

      final room = ChatRoom.fromJson({
        'id': roomId,
        ...doc.data()!,
      });

      // Check if expired
      if (room.isExpired) {
        // Auto-delete expired room
        await deleteRoom(roomId);
        return null;
      }

      return room;
    } catch (e) {
      debugPrint('Error getting room: $e');
      return null;
    }
  }

  /// Get all rooms for a user (where user is participant)
  Future<List<ChatRoom>> getUserRooms(String userEmail) async {
    try {
      // Get rooms where user is a participant
      // Note: Firestore doesn't support array-contains queries on nested fields easily
      // So we'll get all active rooms and filter client-side
      final snapshot = await _firestore
          .collection('chat_rooms')
          .where('isActive', isEqualTo: true)
          .get();

      final rooms = <ChatRoom>[];

      for (final doc in snapshot.docs) {
        try {
          final room = ChatRoom.fromJson({
            'id': doc.id,
            ...doc.data(),
          });

          // Check expiration
          if (room.isExpired) {
            continue; // Skip expired rooms
          }

          // Check if user is participant
          if (room.isParticipant(userEmail)) {
            rooms.add(room);
          }
        } catch (e) {
          debugPrint('Error parsing room: $e');
          continue;
        }
      }

      // Sort by last message time or creation time
      rooms.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      return rooms;
    } catch (e) {
      debugPrint('Error getting user rooms: $e');
      return [];
    }
  }

  /// Listen to user's rooms (real-time)
  Stream<List<ChatRoom>> listenToUserRooms(String userEmail) {
    return _firestore
        .collection('chat_rooms')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final rooms = <ChatRoom>[];

      for (final doc in snapshot.docs) {
        try {
          final room = ChatRoom.fromJson({
            'id': doc.id,
            ...doc.data(),
          });

          // Check expiration
          if (room.isExpired) {
            continue;
          }

          // Check if user is participant
          if (room.isParticipant(userEmail)) {
            rooms.add(room);
          }
        } catch (e) {
          debugPrint('Error parsing room: $e');
          continue;
        }
      }

      // Sort by last message time
      rooms.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      return rooms;
    });
  }

  /// Add a participant to the room (host only)
  Future<void> addParticipant({
    required String roomId,
    required String hostEmail,
    required String participantEmail,
    String? participantDisplayName,
  }) async {
    try {
      // Verify host
      final room = await getRoom(roomId);
      if (room == null) {
        throw Exception('Room not found');
      }

      if (!room.isHost(hostEmail)) {
        throw Exception('Only the host can add participants');
      }

      // Check if room is expired
      if (room.isExpired) {
        throw Exception('Room has expired');
      }

      // Check if already a participant
      if (room.isParticipant(participantEmail)) {
        throw Exception('User is already a participant');
      }

      // Get or create user profile for display name
      if (participantDisplayName == null) {
        try {
          final userDoc = await _firestore
              .collection('chat_users')
              .doc(participantEmail)
              .get();
          participantDisplayName = userDoc.exists
              ? (userDoc.data()?['displayName'] as String?)
              : null;
        } catch (e) {
          debugPrint('Error getting user profile: $e');
        }
      }

      // Add participant
      final newParticipant = RoomParticipant(
        email: participantEmail,
        displayName: participantDisplayName ?? participantEmail.split('@').first,
        joinedAt: DateTime.now(),
        isHost: false,
      );

      final updatedParticipants = [...room.participants, newParticipant];

      await _firestore.collection('chat_rooms').doc(roomId).update({
        'participants': updatedParticipants.map((p) => p.toJson()).toList(),
      });

      debugPrint('Participant added: $participantEmail to room $roomId');
      onParticipantAdded?.call(roomId, participantEmail);
    } catch (e) {
      debugPrint('Error adding participant: $e');
      rethrow;
    }
  }

  /// Kick a participant from the room (host only)
  Future<void> kickParticipant({
    required String roomId,
    required String hostEmail,
    required String participantEmail,
  }) async {
    try {
      // Verify host
      final room = await getRoom(roomId);
      if (room == null) {
        throw Exception('Room not found');
      }

      if (!room.isHost(hostEmail)) {
        throw Exception('Only the host can kick participants');
      }

      // Cannot kick host
      if (room.isHost(participantEmail)) {
        throw Exception('Cannot kick the host');
      }

      // Check if participant exists
      if (!room.isParticipant(participantEmail)) {
        throw Exception('User is not a participant');
      }

      // Remove participant
      final updatedParticipants = room.participants
          .where((p) => p.email.toLowerCase() != participantEmail.toLowerCase())
          .toList();

      await _firestore.collection('chat_rooms').doc(roomId).update({
        'participants': updatedParticipants.map((p) => p.toJson()).toList(),
      });

      debugPrint('Participant kicked: $participantEmail from room $roomId');
      onParticipantRemoved?.call(roomId, participantEmail);
    } catch (e) {
      debugPrint('Error kicking participant: $e');
      rethrow;
    }
  }

  /// Leave a room (any participant, including host)
  Future<void> leaveRoom({
    required String roomId,
    required String userEmail,
  }) async {
    try {
      final room = await getRoom(roomId);
      if (room == null) {
        throw Exception('Room not found');
      }

      // Check if user is participant
      if (!room.isParticipant(userEmail)) {
        throw Exception('User is not a participant');
      }

      // If host is leaving
      if (room.isHost(userEmail)) {
        // Delete the room (host leaving = room ends)
        await deleteRoom(roomId);
        debugPrint('Host left, room deleted: $roomId');
        return;
      }

      // Regular participant leaving
      final updatedParticipants = room.participants
          .where((p) => p.email.toLowerCase() != userEmail.toLowerCase())
          .toList();

      // If no participants left, delete room
      if (updatedParticipants.isEmpty) {
        await deleteRoom(roomId);
        debugPrint('Last participant left, room deleted: $roomId');
        return;
      }

      // Update participants list
      await _firestore.collection('chat_rooms').doc(roomId).update({
        'participants': updatedParticipants.map((p) => p.toJson()).toList(),
      });

      debugPrint('Participant left: $userEmail from room $roomId');
      onParticipantRemoved?.call(roomId, userEmail);
    } catch (e) {
      debugPrint('Error leaving room: $e');
      rethrow;
    }
  }

  /// Send a message to the room
  Future<void> sendMessage({
    required String roomId,
    required String senderEmail,
    required String message,
    String? senderDisplayName,
  }) async {
    try {
      // Security: Validate inputs
      if (roomId.trim().isEmpty) {
        throw Exception('Room ID cannot be empty');
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

      // Verify room exists and user is participant
      final room = await getRoom(roomId);
      if (room == null) {
        throw Exception('Room not found');
      }

      if (room.isExpired) {
        throw Exception('Room has expired');
      }

      if (!room.isParticipant(senderEmail)) {
        throw Exception('Unauthorized: You are not a participant in this room');
      }

      // Security: Verify room is active
      if (!room.isActive) {
        throw Exception('Room is not active');
      }

      // Create message
      final messageId = _uuid.v4();
      final expiresAt = DateTime.now().add(const Duration(hours: 24));
      final now = DateTime.now();

      final roomMessage = RoomMessage(
        id: messageId,
        roomId: roomId,
        senderEmail: senderEmail.toLowerCase().trim(),
        senderDisplayName: senderDisplayName?.trim(),
        message: trimmedMessage,
        timestamp: now,
        expiresAt: expiresAt,
        isRead: false,
      );

      // Save message
      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .doc(messageId)
          .set(roomMessage.toJson());

      // Update room (last message, reset expiration)
      // Use FieldValue.increment for atomic operation
      await _firestore.collection('chat_rooms').doc(roomId).update({
        'lastMessageAt': now.toIso8601String(),
        'lastMessage': trimmedMessage,
        // Reset expiration when new message is sent
        'expiresAt': expiresAt.toIso8601String(),
        // Increment unread count for all other participants (atomic operation)
        'unreadCount': FieldValue.increment(1),
      });

      debugPrint('Message sent to room: $roomId');
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Get messages for a room
  Future<List<RoomMessage>> getMessages(
    String roomId, {
    int limit = 100,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => RoomMessage.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .where((msg) => !msg.isExpired) // Filter expired messages
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } catch (e) {
      debugPrint('Error getting messages: $e');
      return [];
    }
  }

  /// Listen to messages in a room (real-time)
  Stream<List<RoomMessage>> listenToMessages(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100) // Limit for performance
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RoomMessage.fromJson({
                  'id': doc.id,
                  ...doc.data(),
                }))
            .where((msg) => !msg.isExpired) // Filter expired messages
            .toList())
        .map((messages) {
      // Sort chronologically
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  /// Listen to room updates (real-time)
  Stream<ChatRoom?> listenToRoom(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      try {
        final room = ChatRoom.fromJson({
          'id': roomId,
          ...snapshot.data()!,
        });

        // Check expiration
        if (room.isExpired) {
          // Auto-delete expired room
          deleteRoom(roomId);
          return null;
        }

        return room;
      } catch (e) {
        debugPrint('Error parsing room: $e');
        return null;
      }
    });
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(
    String roomId,
    String userEmail,
  ) async {
    try {
      // Get unread messages (from other users)
      final snapshot = await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) return;

      // Filter to only messages from other users
      final unreadMessages = snapshot.docs
          .where((doc) {
            final data = doc.data();
            return data['senderEmail'] != userEmail;
          })
          .toList();

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

      // Reset unread count in room
      await _firestore.collection('chat_rooms').doc(roomId).update({
        'unreadCount': 0,
      });

      debugPrint('Messages marked as read: $roomId');
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  /// Delete a room (host only or auto-delete)
  Future<void> deleteRoom(String roomId) async {
    try {
      // Delete all messages first
      final messagesSnapshot = await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (final msgDoc in messagesSnapshot.docs) {
        batch.delete(msgDoc.reference);
      }
      await batch.commit();

      // Delete room
      await _firestore.collection('chat_rooms').doc(roomId).delete();

      debugPrint('Room deleted: $roomId');
      onRoomDeleted?.call(roomId);
    } catch (e) {
      debugPrint('Error deleting room: $e');
      rethrow;
    }
  }

  /// Cleanup expired rooms and messages
  Future<void> _cleanupExpiredRooms() async {
    try {
      final now = DateTime.now();

      // Get all active rooms
      final roomsSnapshot = await _firestore
          .collection('chat_rooms')
          .where('isActive', isEqualTo: true)
          .get();

      final expiredRoomIds = <String>[];

      for (final doc in roomsSnapshot.docs) {
        try {
          final room = ChatRoom.fromJson({
            'id': doc.id,
            ...doc.data(),
          });

          if (room.isExpired) {
            expiredRoomIds.add(room.id);
          }
        } catch (e) {
          debugPrint('Error parsing room for cleanup: $e');
          continue;
        }
      }

      // Delete expired rooms
      for (final roomId in expiredRoomIds) {
        await deleteRoom(roomId);
      }

      if (expiredRoomIds.isNotEmpty) {
        debugPrint('Cleaned up ${expiredRoomIds.length} expired chat rooms');
      }

      // Cleanup expired messages in active rooms
      final activeRooms = await _firestore
          .collection('chat_rooms')
          .where('isActive', isEqualTo: true)
          .get();

      for (final roomDoc in activeRooms.docs) {
        try {
          final room = ChatRoom.fromJson({
            'id': roomDoc.id,
            ...roomDoc.data(),
          });

          if (room.isExpired) continue;

          final expiredMessages = await roomDoc.reference
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
        } catch (e) {
          debugPrint('Error cleaning up messages: $e');
          continue;
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up expired rooms: $e');
    }
  }
}

