import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:elysian/models/watch_party_models.dart';
import 'package:elysian/services/watch_party_firestore_service.dart';
import 'package:elysian/services/video_streaming_service.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:uuid/uuid.dart';

/// Firebase Realtime Database service for watch party
/// Provides online sync across any network (not just local)
class WatchPartyFirebaseService {
  static final WatchPartyFirebaseService _instance =
      WatchPartyFirebaseService._internal();
  factory WatchPartyFirebaseService() => _instance;
  WatchPartyFirebaseService._internal();

  final _uuid = const Uuid();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final _firestoreService = WatchPartyFirestoreService();

  DatabaseReference? _roomRef;
  StreamSubscription<DatabaseEvent>? _roomSubscription;

  String? _currentRoomId;
  String? _currentParticipantId;
  String? _currentParticipantName;
  bool _isHost = false;
  bool _isConnected = false;
  String? _connectionError;
  WatchPartyRoom? _lastKnownRoom;

  // Optimization: Track last sent values to avoid redundant writes
  Duration? _lastSentPosition;
  bool? _lastSentIsPlaying;
  String? _lastSentVideoUrl;
  String? _lastSentVideoTitle;

  // Reconnection logic
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _initialReconnectDelay = Duration(seconds: 2);

  // Callbacks
  Function(WatchPartyRoom)? onRoomUpdate;
  Function(SyncMessage)? onSyncMessage;
  Function(ChatMessage)? onChatMessage;
  Function(Reaction)? onReaction;
  Function(String videoUrl, String videoTitle)? onVideoChange;
  Function(String reason)?
  onRoomEnded; // Called when host ends party or room is deleted

  // Getters
  bool get isConnected => _isConnected;
  String? get connectionError => _connectionError;
  bool get isHost => _isHost;
  String? get currentParticipantId => _currentParticipantId;
  String? get currentRoomId => _currentRoomId;

  /// Generate a 6-digit room code
  String _generateRoomCode() {
    final random = DateTime.now().millisecondsSinceEpoch % 1000000;
    return random.toString().padLeft(6, '0');
  }

  /// Safely convert Firebase data to `Map<String, dynamic>`
  Map<String, dynamic> _convertFirebaseData(dynamic data) {
    if (data == null) return {};
    if (data is Map) {
      return data.map(
        (key, value) => MapEntry(
          key.toString(),
          value is Map ? _convertFirebaseData(value) : value,
        ),
      );
    }
    return {};
  }

  /// Safely convert list from Firebase
  List<dynamic> _convertFirebaseList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((item) {
        if (item is Map) {
          return _convertFirebaseData(item);
        }
        return item;
      }).toList();
    }
    return [];
  }

  /// Create a new watch party room (host)
  Future<WatchPartyRoom> createRoom({
    required String hostName,
    required String videoUrl,
    required String videoTitle,
    Duration initialPosition = Duration.zero,
    bool initialPlaying = false,
  }) async {
    try {
      final roomId = _uuid.v4();
      final hostId = _uuid.v4();
      _currentParticipantId = hostId;
      _currentParticipantName = hostName;
      _currentRoomId = roomId;
      _isHost = true;

      final roomCode = _generateRoomCode();

      // Check if video is a local file and start streaming if needed
      String finalVideoUrl = videoUrl;
      if (VideoStreamingService.isLocalFile(videoUrl)) {
        final networkInfo = NetworkInfo();
        final localIp = await networkInfo.getWifiIP();
        if (localIp != null) {
          final streamingUrl = await VideoStreamingService().startStreaming(
            videoPath: videoUrl,
            hostIp: localIp,
          );
          if (streamingUrl != null) {
            finalVideoUrl = streamingUrl;
            debugPrint('Local video streaming started: $streamingUrl');
          } else {
            debugPrint('Failed to start video streaming, using original path');
          }
        }
      }

      final room = WatchPartyRoom(
        roomId: roomId,
        hostId: hostId,
        hostName: hostName,
        videoUrl: finalVideoUrl,
        videoTitle: videoTitle,
        currentPosition: initialPosition,
        isPlaying: initialPlaying,
        createdAt: DateTime.now(),
        participants: [
          WatchPartyParticipant(
            id: hostId,
            name: hostName,
            isHost: true,
            joinedAt: DateTime.now(),
          ),
        ],
        roomCode: roomCode,
        positionUpdatedAt: DateTime.now(),
      );

      // Save room to Firebase
      final roomRef = _database.child('watch_party_rooms').child(roomId);
      await roomRef.set({
        ...room.toJson(),
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 24))
            .toIso8601String(),
      });

      // Set up real-time listeners (Realtime DB for position sync)
      _setupRoomListeners(roomId);

      // Set up host disconnect handler
      _setupHostDisconnectHandler(roomId);

      // Initialize Firestore for chat and reactions
      _firestoreService.initializeRoom(roomId);
      _firestoreService.onChatMessage = onChatMessage;
      _firestoreService.onReaction = onReaction;

      // Set connection state after listeners are set up
      _isConnected = true;
      _connectionError = null;

      // Reset optimization tracking
      _lastSentPosition = initialPosition;
      _lastSentIsPlaying = initialPlaying;
      _lastSentVideoUrl = videoUrl;
      _lastSentVideoTitle = videoTitle;

      // Trigger initial room update callback to notify provider
      Future.delayed(const Duration(milliseconds: 50), () {
        if (onRoomUpdate != null) {
          onRoomUpdate!(room);
        }
      });

      return room;
    } catch (e) {
      _isConnected = false;
      _connectionError = 'Failed to create room: $e';
      debugPrint('Error creating room: $e');
      rethrow;
    }
  }

  /// Join an existing room
  Future<WatchPartyRoom?> joinRoom({
    required String participantName,
    required String roomCode,
  }) async {
    try {
      // Find room by room code
      final roomsSnapshot = await _database
          .child('watch_party_rooms')
          .orderByChild('roomCode')
          .equalTo(roomCode)
          .once();

      if (roomsSnapshot.snapshot.value == null) {
        _isConnected = false;
        _connectionError = 'Room not found';
        return null;
      }

      // Get the first matching room
      final roomsData = _convertFirebaseData(roomsSnapshot.snapshot.value);
      if (roomsData.isEmpty) {
        _isConnected = false;
        _connectionError = 'Room not found';
        return null;
      }

      final roomEntry = roomsData.entries.first;
      final roomId = roomEntry.key;
      final roomData = _convertFirebaseData(roomEntry.value);

      // Check if room expired
      if (roomData['expiresAt'] != null) {
        final expiresAt = DateTime.parse(roomData['expiresAt'] as String);
        if (DateTime.now().isAfter(expiresAt)) {
          _isConnected = false;
          _connectionError = 'Room has expired';
          return null;
        }
      }

      // Parse participants safely
      final participantsList = _convertFirebaseList(roomData['participants']);
      final existingParticipants = participantsList
          .map((p) => WatchPartyParticipant.fromJson(_convertFirebaseData(p)))
          .toList();

      // Add participant
      final participantId = _uuid.v4();
      _currentParticipantId = participantId;
      _currentParticipantName = participantName;
      _currentRoomId = roomId;
      _isHost = false;

      final updatedParticipants = [
        ...existingParticipants,
        WatchPartyParticipant(
          id: participantId,
          name: participantName,
          isHost: false,
          joinedAt: DateTime.now(),
        ),
      ];

      // Create room object with updated participants
      final room = WatchPartyRoom(
        roomId: roomData['roomId'] as String,
        hostId: roomData['hostId'] as String,
        hostName: roomData['hostName'] as String,
        videoUrl: roomData['videoUrl'] as String,
        videoTitle: roomData['videoTitle'] as String,
        currentPosition: Duration(
          milliseconds: roomData['currentPosition'] as int,
        ),
        isPlaying: roomData['isPlaying'] as bool,
        createdAt: DateTime.parse(roomData['createdAt'] as String),
        participants: existingParticipants,
        roomCode: roomData['roomCode'] as String?,
        positionUpdatedAt: roomData['positionUpdatedAt'] != null
            ? DateTime.parse(roomData['positionUpdatedAt'] as String)
            : null,
      );

      // Update room with new participant
      final roomRef = _database.child('watch_party_rooms').child(roomId);
      await roomRef.update({
        'participants': updatedParticipants.map((p) => p.toJson()).toList(),
      });

      // Set up real-time listeners (Realtime DB for position sync)
      _setupRoomListeners(roomId);

      // Set up connection monitoring
      _setupConnectionMonitoring();

      // Initialize Firestore for chat and reactions
      _firestoreService.initializeRoom(roomId);
      _firestoreService.onChatMessage = onChatMessage;
      _firestoreService.onReaction = onReaction;

      _isConnected = true;
      _connectionError = null;

      // Reset optimization tracking
      _lastSentPosition = null;
      _lastSentIsPlaying = null;
      _lastSentVideoUrl = null;
      _lastSentVideoTitle = null;

      return room.copyWith(participants: updatedParticipants);
    } catch (e) {
      _isConnected = false;
      _connectionError = 'Failed to join room: $e';
      debugPrint('Error joining room: $e');
      return null;
    }
  }

  /// Set up real-time listeners for room updates
  void _setupRoomListeners(String roomId) {
    _roomRef = _database.child('watch_party_rooms').child(roomId);

    // Listen for room state changes
    _roomSubscription?.cancel();
    _roomSubscription = _roomRef!.onValue.listen((event) {
      if (event.snapshot.value == null) {
        // Room was deleted (host ended party)
        _isConnected = false;
        _connectionError = 'Room was closed';
        // Notify that room ended
        if (!_isHost) {
          onRoomEnded?.call('Host ended the watch party');
        }
        // Don't clear onRoomUpdate callback, let provider handle it
        return;
      }

      try {
        final rawData = event.snapshot.value;
        if (rawData == null) {
          // Room was deleted (host ended party)
          _isConnected = false;
          _connectionError = 'Room was closed';
          // Notify that room ended
          if (!_isHost) {
            onRoomEnded?.call('Host ended the watch party');
          }
          return;
        }

        final roomData = _convertFirebaseData(rawData);
        if (roomData.isEmpty) {
          return;
        }

        // Parse participants safely and filter stale ones (joined >30 min ago without activity)
        final participantsList = _convertFirebaseList(roomData['participants']);
        final now = DateTime.now();
        final participants = participantsList
            .map((p) => WatchPartyParticipant.fromJson(_convertFirebaseData(p)))
            .where((p) {
              // Keep host always, and participants who joined recently (<30 min)
              if (p.isHost) return true;
              final timeSinceJoin = now.difference(p.joinedAt);
              return timeSinceJoin.inMinutes < 30;
            })
            .toList();

        // Auto-cleanup: Remove stale participants if we're the host
        if (_isHost && participants.length < participantsList.length) {
          _roomRef!.update({
            'participants': participants.map((p) => p.toJson()).toList(),
          });
        }

        // Create room object manually to avoid type casting issues
        final room = WatchPartyRoom(
          roomId: roomData['roomId'] as String? ?? '',
          hostId: roomData['hostId'] as String? ?? '',
          hostName: roomData['hostName'] as String? ?? '',
          videoUrl: roomData['videoUrl'] as String? ?? '',
          videoTitle: roomData['videoTitle'] as String? ?? '',
          currentPosition: Duration(
            milliseconds: (roomData['currentPosition'] as num?)?.toInt() ?? 0,
          ),
          isPlaying: roomData['isPlaying'] as bool? ?? false,
          createdAt: roomData['createdAt'] != null
              ? DateTime.parse(roomData['createdAt'] as String)
              : DateTime.now(),
          participants: participants,
          roomCode: roomData['roomCode'] as String?,
          positionUpdatedAt: roomData['positionUpdatedAt'] != null
              ? DateTime.parse(roomData['positionUpdatedAt'] as String)
              : null,
        );

        // Update connection state - we're connected if we received data
        _isConnected = true;
        _connectionError = null;

        // Store last known room for comparison
        final previousVideoUrl = _lastKnownRoom?.videoUrl;
        _lastKnownRoom = room;

        // Check if video changed - but only trigger if actually different
        // This prevents infinite loops when video starts playing
        if (onVideoChange != null && room.videoUrl.isNotEmpty) {
          // Only trigger if video URL actually changed (not just position/playing state)
          // Also trigger if previousVideoUrl is null (first time loading)
          if (previousVideoUrl == null || previousVideoUrl != room.videoUrl) {
            debugPrint(
              'WatchPartyFirebaseService: Video changed from ${previousVideoUrl ?? "null"} to ${room.videoUrl}',
            );
            onVideoChange?.call(room.videoUrl, room.videoTitle);
          }
        }

        // Notify room update (this will update provider state)
        onRoomUpdate?.call(room);
      } catch (e) {
        debugPrint('Error parsing room update: $e');
        _isConnected = false;
        _connectionError = 'Error parsing room data: $e';
      }
    });

    // Note: Chat and reactions are now handled by Firestore service
    // See _firestoreService initialization in createRoom/joinRoom
  }

  /// Update room state (host only) - Optimized to only send changes
  Future<void> updateRoomState({
    Duration? position,
    bool? isPlaying,
    String? videoUrl,
    String? videoTitle,
  }) async {
    if (!_isHost || _roomRef == null) return;

    // Optimization: Only update if values actually changed
    bool hasChanges = false;
    final updates = <String, dynamic>{};

    // Check position change (with 100ms threshold to reduce noise)
    if (position != null) {
      final positionDiff = _lastSentPosition == null
          ? 1000
          : (position.inMilliseconds - _lastSentPosition!.inMilliseconds).abs();
      if (positionDiff > 100) {
        updates['currentPosition'] = position.inMilliseconds;
        updates['positionUpdatedAt'] = DateTime.now().toIso8601String();
        _lastSentPosition = position;
        hasChanges = true;
      }
    }

    // Check playing state change
    if (isPlaying != null && isPlaying != _lastSentIsPlaying) {
      updates['isPlaying'] = isPlaying;
      _lastSentIsPlaying = isPlaying;
      hasChanges = true;
    }

    // Check video URL change - when video changes, reset position to zero
    if (videoUrl != null && videoUrl != _lastSentVideoUrl) {
      updates['videoUrl'] = videoUrl;
      updates['currentPosition'] = 0; // Reset position when video changes
      updates['positionUpdatedAt'] = DateTime.now().toIso8601String();
      _lastSentVideoUrl = videoUrl;
      _lastSentPosition = Duration.zero; // Reset tracked position
      hasChanges = true;
    }

    // Check video title change
    if (videoTitle != null && videoTitle != _lastSentVideoTitle) {
      updates['videoTitle'] = videoTitle;
      _lastSentVideoTitle = videoTitle;
      hasChanges = true;
    }

    // Only write to Firebase if there are actual changes
    if (!hasChanges) return;

    try {
      await _roomRef!.update(updates);
      _reconnectAttempts = 0; // Reset on successful update
    } catch (e) {
      debugPrint('Error updating room state: $e');
      _handleUpdateError(e);
    }
  }

  /// Handle update errors with reconnection logic
  void _handleUpdateError(dynamic error) {
    _reconnectAttempts++;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _isConnected = false;
      _connectionError = 'Connection lost. Please try rejoining.';
      debugPrint('Max reconnection attempts reached');
      return;
    }

    // Exponential backoff for reconnection
    final delay = Duration(
      milliseconds:
          _initialReconnectDelay.inMilliseconds *
          (1 << (_reconnectAttempts - 1)),
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      // Try to reconnect by checking connection
      _checkConnection();
    });
  }

  /// Check Firebase connection status
  void _checkConnection() async {
    try {
      final connectedRef = FirebaseDatabase.instance.ref('.info/connected');
      final snapshot = await connectedRef.once();
      if (snapshot.snapshot.value == true) {
        _isConnected = true;
        _connectionError = null;
        _reconnectAttempts = 0;
      } else {
        _isConnected = false;
        _connectionError = 'Disconnected from Firebase';
      }
    } catch (e) {
      _isConnected = false;
      _connectionError = 'Connection check failed: $e';
    }
  }

  /// Set up connection monitoring
  void _setupConnectionMonitoring() {
    final connectedRef = FirebaseDatabase.instance.ref('.info/connected');
    connectedRef.onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (connected) {
        _isConnected = true;
        _connectionError = null;
        _reconnectAttempts = 0;
      } else {
        _isConnected = false;
        _connectionError = 'Disconnected from Firebase';
      }
    });
  }

  /// Set up host disconnect handler (auto-cleanup when host disconnects)
  void _setupHostDisconnectHandler(String roomId) {
    if (!_isHost) return;

    final hostPresenceRef = _database
        .child('watch_party_rooms')
        .child(roomId)
        .child('hostPresence');

    // Set presence to true when connected
    hostPresenceRef.set(true);

    // Set up onDisconnect to delete room when host disconnects
    // This ensures rooms are cleaned up automatically
    hostPresenceRef.onDisconnect().remove();

    // Also set up room deletion on disconnect
    _roomRef?.onDisconnect().remove();
  }

  /// Clean up expired rooms (called periodically or on app start)
  static Future<void> cleanupExpiredRooms() async {
    try {
      final roomsRef = FirebaseDatabase.instance.ref('watch_party_rooms');
      final snapshot = await roomsRef.once();

      if (snapshot.snapshot.value == null) return;

      final roomsData = snapshot.snapshot.value as Map<dynamic, dynamic>?;
      if (roomsData == null) return;

      final now = DateTime.now();
      final expiredRoomIds = <String>[];

      for (final entry in roomsData.entries) {
        final roomId = entry.key as String;
        final roomData = entry.value as Map<dynamic, dynamic>?;

        if (roomData == null) continue;

        // Check expiration
        if (roomData['expiresAt'] != null) {
          try {
            final expiresAt = DateTime.parse(roomData['expiresAt'] as String);
            if (now.isAfter(expiresAt)) {
              expiredRoomIds.add(roomId);
              continue;
            }
          } catch (e) {
            // Invalid date, mark for cleanup
            expiredRoomIds.add(roomId);
            continue;
          }
        }

        // Check host presence (if host offline >5 min, mark as stale)
        if (roomData['hostPresence'] == false ||
            roomData['hostPresence'] == null) {
          final createdAt = roomData['createdAt'] != null
              ? DateTime.tryParse(roomData['createdAt'] as String)
              : null;

          if (createdAt != null) {
            final timeSinceCreation = now.difference(createdAt);
            if (timeSinceCreation.inMinutes > 5) {
              expiredRoomIds.add(roomId);
            }
          }
        }
      }

      // Delete expired rooms
      for (final roomId in expiredRoomIds) {
        await roomsRef.child(roomId).remove();
      }

      if (expiredRoomIds.isNotEmpty) {
        debugPrint(
          'Cleaned up ${expiredRoomIds.length} expired watch party rooms',
        );
      }
    } catch (e) {
      debugPrint('Error cleaning up expired rooms: $e');
    }
  }

  /// Send chat message (via Firestore)
  Future<void> sendChatMessage(String message) async {
    if (_currentParticipantId == null || _currentParticipantName == null) {
      return;
    }

    try {
      await _firestoreService.sendChatMessage(
        message: message,
        participantId: _currentParticipantId!,
        participantName: _currentParticipantName!,
      );
    } catch (e) {
      debugPrint('Error sending chat message to Firestore: $e');
    }
  }

  /// Send reaction (via Firestore)
  Future<void> sendReaction(ReactionType type) async {
    if (_currentParticipantId == null || _currentParticipantName == null) {
      return;
    }

    try {
      await _firestoreService.sendReaction(
        type: type,
        participantId: _currentParticipantId!,
        participantName: _currentParticipantName!,
      );
    } catch (e) {
      debugPrint('Error sending reaction to Firestore: $e');
    }
  }

  /// Leave room
  Future<void> leaveRoom() async {
    // Cancel all timers
    _reconnectTimer?.cancel();

    // Cancel Realtime DB subscriptions
    _roomSubscription?.cancel();

    // Dispose Firestore service (chat/reactions)
    _firestoreService.dispose();

    // Stop video streaming if host is leaving
    if (_isHost) {
      await VideoStreamingService().stopStreaming();
    }

    // Remove participant from room if not host
    if (!_isHost && _roomRef != null && _currentParticipantId != null) {
      try {
        final roomSnapshot = await _roomRef!.once();
        if (roomSnapshot.snapshot.value != null) {
          final roomData = _convertFirebaseData(roomSnapshot.snapshot.value);
          final participantsList = _convertFirebaseList(
            roomData['participants'],
          );
          final participants = participantsList
              .map(
                (p) => WatchPartyParticipant.fromJson(_convertFirebaseData(p)),
              )
              .toList();

          final updatedParticipants = participants
              .where((p) => p.id != _currentParticipantId)
              .toList();

          await _roomRef!.update({
            'participants': updatedParticipants.map((p) => p.toJson()).toList(),
          });
        }
      } catch (e) {
        debugPrint('Error removing participant: $e');
      }
    }

    // If host, delete the room and all chat/reactions
    if (_isHost && _roomRef != null && _currentRoomId != null) {
      try {
        // Delete all Firestore chat messages and reactions first
        await _firestoreService.deleteRoomData(_currentRoomId!);

        // Then delete the room from Realtime DB (this will trigger onRoomEnded for participants)
        await _roomRef!.remove();

        debugPrint(
          'Host ended watch party - deleted room and all chat/reactions',
        );
      } catch (e) {
        debugPrint('Error deleting room: $e');
      }
    }

    // Clean up
    _roomRef = null;
    _currentRoomId = null;
    _currentParticipantId = null;
    _currentParticipantName = null;
    _isHost = false;
    _isConnected = false;
    _connectionError = null;
    _lastKnownRoom = null;

    // Reset optimization tracking
    _lastSentPosition = null;
    _lastSentIsPlaying = null;
    _lastSentVideoUrl = null;
    _lastSentVideoTitle = null;
    _reconnectAttempts = 0;
  }

  /// Check if Firebase is available
  static Future<bool> isAvailable() async {
    try {
      // Try to read from Firebase to check connection
      final ref = FirebaseDatabase.instance.ref('.info/connected');
      await ref.once();
      return true;
    } catch (e) {
      return false;
    }
  }
}
