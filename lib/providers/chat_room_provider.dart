import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:elysian/models/chat_models.dart';
import 'package:elysian/services/chat_room_service.dart';
import 'package:elysian/services/storage_service.dart';

/// Provider for managing chat room state
class ChatRoomProvider extends ChangeNotifier {
  final ChatRoomService _roomService = ChatRoomService();

  List<ChatRoom> _rooms = [];
  Map<String, List<RoomMessage>> _messages = {};
  Map<String, StreamSubscription> _subscriptions = {};

  bool _isLoading = false;
  String? _error;

  // Getters
  List<ChatRoom> get rooms => _rooms;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<RoomMessage> getMessages(String roomId) {
    return _messages[roomId] ?? [];
  }

  int get totalUnreadCount {
    return _rooms.fold(0, (sum, room) => sum + room.unreadCount);
  }

  /// Initialize the provider
  Future<void> initialize() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final userEmail = await StorageService.getUserEmail();
      if (userEmail == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Set up real-time listeners
      _setupListeners(userEmail);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize chat rooms: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('ChatRoomProvider initialization error: $e');
    }
  }

  /// Set up real-time listeners
  void _setupListeners(String userEmail) {
    // Cancel existing subscriptions
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Listen to user's rooms
    _subscriptions['rooms'] = _roomService
        .listenToUserRooms(userEmail)
        .listen(
      (rooms) {
        _rooms = rooms;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Error listening to rooms: $error');
        _error = 'Failed to load rooms';
        notifyListeners();
      },
    );

    // Set up callbacks
    _roomService.onRoomUpdated = (room) {
      final index = _rooms.indexWhere((r) => r.id == room.id);
      if (index != -1) {
        _rooms[index] = room;
      } else {
        _rooms.add(room);
      }
      notifyListeners();
    };

    _roomService.onRoomDeleted = (roomId) {
      _rooms.removeWhere((r) => r.id == roomId);
      _messages.remove(roomId);
      stopListeningToMessages(roomId);
      notifyListeners();
    };

    _roomService.onParticipantAdded = (roomId, email) {
      final index = _rooms.indexWhere((r) => r.id == roomId);
      if (index != -1) {
        loadRoom(roomId); // Reload room to get updated participants
      }
    };

    _roomService.onParticipantRemoved = (roomId, email) {
      final index = _rooms.indexWhere((r) => r.id == roomId);
      if (index != -1) {
        loadRoom(roomId); // Reload room to get updated participants
      }
    };
  }

  /// Create a new room
  Future<ChatRoom> createRoom({
    required String roomName,
    String? roomDescription,
  }) async {
    try {
      _error = null;
      final userEmail = await StorageService.getUserEmail();
      final userDisplayName = await StorageService.getUserDisplayName();

      if (userEmail == null) {
        throw Exception('User email not set');
      }

      final room = await _roomService.createRoom(
        hostEmail: userEmail,
        roomName: roomName,
        roomDescription: roomDescription,
        hostDisplayName: userDisplayName,
      );

      _rooms.add(room);
      notifyListeners();

      return room;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Load a specific room
  Future<void> loadRoom(String roomId) async {
    try {
      final room = await _roomService.getRoom(roomId);
      if (room != null) {
        final index = _rooms.indexWhere((r) => r.id == roomId);
        if (index != -1) {
          _rooms[index] = room;
        } else {
          _rooms.add(room);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading room: $e');
    }
  }

  /// Load messages for a room
  Future<void> loadMessages(String roomId) async {
    try {
      final messages = await _roomService.getMessages(roomId);
      _messages[roomId] = messages;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }

  /// Listen to messages in a room (real-time)
  void listenToMessages(String roomId) {
    if (_subscriptions.containsKey('messages_$roomId')) {
      return; // Already listening
    }

    _subscriptions['messages_$roomId'] = _roomService
        .listenToMessages(roomId)
        .listen(
      (messages) {
        _messages[roomId] = messages;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Error listening to messages: $error');
      },
    );
  }

  /// Listen to room updates (real-time)
  void listenToRoom(String roomId) {
    if (_subscriptions.containsKey('room_$roomId')) {
      return; // Already listening
    }

    _subscriptions['room_$roomId'] = _roomService.listenToRoom(roomId).listen(
      (room) {
        if (room == null) {
          // Room was deleted
          _rooms.removeWhere((r) => r.id == roomId);
          _messages.remove(roomId);
          stopListeningToMessages(roomId);
          stopListeningToRoom(roomId);
          notifyListeners();
          return;
        }

        final index = _rooms.indexWhere((r) => r.id == roomId);
        if (index != -1) {
          _rooms[index] = room;
        } else {
          _rooms.add(room);
        }
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Error listening to room: $error');
      },
    );
  }

  /// Stop listening to messages
  void stopListeningToMessages(String roomId) {
    _subscriptions['messages_$roomId']?.cancel();
    _subscriptions.remove('messages_$roomId');
  }

  /// Stop listening to room
  void stopListeningToRoom(String roomId) {
    _subscriptions['room_$roomId']?.cancel();
    _subscriptions.remove('room_$roomId');
  }

  /// Add a participant (host only)
  Future<void> addParticipant({
    required String roomId,
    required String participantEmail,
  }) async {
    try {
      _error = null;
      final userEmail = await StorageService.getUserEmail();
      if (userEmail == null) {
        throw Exception('User email not set');
      }

      await _roomService.addParticipant(
        roomId: roomId,
        hostEmail: userEmail,
        participantEmail: participantEmail,
      );

      await loadRoom(roomId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Kick a participant (host only)
  Future<void> kickParticipant({
    required String roomId,
    required String participantEmail,
  }) async {
    try {
      _error = null;
      final userEmail = await StorageService.getUserEmail();
      if (userEmail == null) {
        throw Exception('User email not set');
      }

      await _roomService.kickParticipant(
        roomId: roomId,
        hostEmail: userEmail,
        participantEmail: participantEmail,
      );

      await loadRoom(roomId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Leave a room
  Future<void> leaveRoom(String roomId) async {
    try {
      _error = null;
      final userEmail = await StorageService.getUserEmail();
      if (userEmail == null) {
        throw Exception('User email not set');
      }

      await _roomService.leaveRoom(
        roomId: roomId,
        userEmail: userEmail,
      );

      // Room will be removed from list via onRoomDeleted callback
      _rooms.removeWhere((r) => r.id == roomId);
      _messages.remove(roomId);
      stopListeningToMessages(roomId);
      stopListeningToRoom(roomId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Send a message
  Future<void> sendMessage(String roomId, String message) async {
    try {
      _error = null;
      final userEmail = await StorageService.getUserEmail();
      final userDisplayName = await StorageService.getUserDisplayName();

      if (userEmail == null) {
        throw Exception('User email not set');
      }

      await _roomService.sendMessage(
        roomId: roomId,
        senderEmail: userEmail,
        message: message,
        senderDisplayName: userDisplayName,
      );

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String roomId) async {
    try {
      final userEmail = await StorageService.getUserEmail();
      if (userEmail == null) return;

      await _roomService.markMessagesAsRead(roomId, userEmail);

      // Update local state
      final index = _rooms.indexWhere((r) => r.id == roomId);
      if (index != -1) {
        _rooms[index] = _rooms[index].copyWith(unreadCount: 0);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
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

