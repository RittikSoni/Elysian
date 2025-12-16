import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:elysian/models/watch_party_models.dart';

/// Firestore service for watch party chat and reactions
/// Uses Firestore for structured data (chat/reactions) while Realtime DB handles position sync
/// This splits the load and uses each service for what it's best at
class WatchPartyFirestoreService {
  static final WatchPartyFirestoreService _instance =
      WatchPartyFirestoreService._internal();
  factory WatchPartyFirestoreService() => _instance;
  WatchPartyFirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentRoomId;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<QuerySnapshot>? _reactionsSubscription;

  // Callbacks
  Function(ChatMessage)? onChatMessage;
  Function(Reaction)? onReaction;

  /// Initialize chat and reactions for a room
  void initializeRoom(String roomId) {
    _currentRoomId = roomId;
    _setupChatListeners(roomId);
    _setupReactionListeners(roomId);
  }

  /// Set up chat message listeners
  void _setupChatListeners(String roomId) {
    _messagesSubscription?.cancel();

    _messagesSubscription = _firestore
        .collection('watch_party_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limitToLast(100)
        .snapshots()
        .listen((snapshot) {
      for (final docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.added) {
          try {
            final data = docChange.doc.data();
            if (data != null) {
              final message = ChatMessage(
                id: docChange.doc.id,
                participantId: data['participantId'] as String? ?? '',
                participantName: data['participantName'] as String? ?? 'Unknown',
                message: data['message'] as String? ?? '',
                timestamp: (data['timestamp'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
              );
              onChatMessage?.call(message);
            }
          } catch (e) {
            debugPrint('Error parsing chat message from Firestore: $e');
          }
        }
      }
    });
  }

  /// Set up reaction listeners
  void _setupReactionListeners(String roomId) {
    _reactionsSubscription?.cancel();

    _reactionsSubscription = _firestore
        .collection('watch_party_rooms')
        .doc(roomId)
        .collection('reactions')
        .orderBy('timestamp', descending: false)
        .limitToLast(50)
        .snapshots()
        .listen((snapshot) {
      for (final docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.added) {
          try {
            final data = docChange.doc.data();
            if (data != null) {
              final reaction = Reaction(
                id: docChange.doc.id,
                participantId: data['participantId'] as String? ?? '',
                participantName: data['participantName'] as String? ?? 'Unknown',
                type: ReactionType.values.firstWhere(
                  (type) => type.name == data['type'],
                  orElse: () => ReactionType.like,
                ),
                timestamp: (data['timestamp'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
              );
              onReaction?.call(reaction);
            }
          } catch (e) {
            debugPrint('Error parsing reaction from Firestore: $e');
          }
        }
      }
    });
  }

  /// Send chat message
  Future<void> sendChatMessage({
    required String message,
    required String participantId,
    required String participantName,
  }) async {
    if (_currentRoomId == null) return;

    try {
      final chatMessage = {
        'participantId': participantId,
        'participantName': participantName,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('watch_party_rooms')
          .doc(_currentRoomId)
          .collection('messages')
          .add(chatMessage);
    } catch (e) {
      debugPrint('Error sending chat message to Firestore: $e');
      rethrow;
    }
  }

  /// Send reaction
  Future<void> sendReaction({
    required ReactionType type,
    required String participantId,
    required String participantName,
  }) async {
    if (_currentRoomId == null) return;

    try {
      final reaction = {
        'participantId': participantId,
        'participantName': participantName,
        'type': type.name,
        'timestamp': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore
          .collection('watch_party_rooms')
          .doc(_currentRoomId)
          .collection('reactions')
          .add(reaction);

      // Reactions are ephemeral - auto-delete after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        docRef.delete();
      });
    } catch (e) {
      debugPrint('Error sending reaction to Firestore: $e');
      rethrow;
    }
  }

  /// Get chat history (for loading previous messages)
  Future<List<ChatMessage>> getChatHistory({int limit = 50}) async {
    if (_currentRoomId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('watch_party_rooms')
          .doc(_currentRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      final messages = snapshot.docs.map((doc) {
        final data = doc.data();
        return ChatMessage(
          id: doc.id,
          participantId: data['participantId'] as String? ?? '',
          participantName: data['participantName'] as String? ?? 'Unknown',
          message: data['message'] as String? ?? '',
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ??
              DateTime.now(),
        );
      }).toList();
      
      // Reverse to get chronological order (oldest first)
      return messages.reversed.toList();
    } catch (e) {
      debugPrint('Error getting chat history: $e');
      return [];
    }
  }

  /// Delete all chat messages and reactions for a room (when party ends)
  Future<void> deleteRoomData(String roomId) async {
    try {
      final roomRef = _firestore
          .collection('watch_party_rooms')
          .doc(roomId);

      // Get all messages and delete them in batch
      final messagesSnapshot = await roomRef
          .collection('messages')
          .get();
      
      if (messagesSnapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in messagesSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      // Get all reactions and delete them in batch
      final reactionsSnapshot = await roomRef
          .collection('reactions')
          .get();
      
      if (reactionsSnapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in reactionsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      debugPrint('Deleted all chat messages and reactions for room $roomId');
    } catch (e) {
      debugPrint('Error deleting room data from Firestore: $e');
      // Don't rethrow - cleanup should be best effort
    }
  }

  /// Clean up resources
  void dispose() {
    _messagesSubscription?.cancel();
    _reactionsSubscription?.cancel();
    _messagesSubscription = null;
    _reactionsSubscription = null;
    _currentRoomId = null;
  }
}

