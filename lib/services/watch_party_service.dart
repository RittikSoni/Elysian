import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:elysian/models/watch_party_models.dart';
import 'package:elysian/services/video_streaming_service.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:uuid/uuid.dart';

/// Service for managing watch party rooms and synchronization
class WatchPartyService {
  static final WatchPartyService _instance = WatchPartyService._internal();
  factory WatchPartyService() => _instance;
  WatchPartyService._internal();

  final _uuid = const Uuid();
  final _networkInfo = NetworkInfo();

  HttpServer? _server;
  WatchPartyRoom? _currentRoom;
  String? _currentParticipantId;
  bool _isHost = false;
  Timer? _syncTimer;
  String? _hostIp;
  int? _hostPort;

  // Callbacks
  Function(WatchPartyRoom)? onRoomUpdate;
  Function(SyncMessage)? onSyncMessage;
  Function(ChatMessage)? onChatMessage;
  Function(Reaction)? onReaction;
  Function(String videoUrl, String videoTitle)?
      onVideoChange; // Called when host changes video

  // Message persistence for session (last 100 messages)
  static const int _maxSessionMessages = 100;
  final List<ChatMessage> _sessionMessages = [];
  
  // Recent reactions (last 50, transient)
  static const int _maxRecentReactions = 50;
  final List<Reaction> _recentReactions = [];

  List<ChatMessage> get sessionMessages => List.unmodifiable(_sessionMessages);

  // Connection state
  bool _isConnected = false;
  String? _connectionError;

  bool get isConnected => _isConnected;
  String? get connectionError => _connectionError;

  // Get current room
  WatchPartyRoom? get currentRoom => _currentRoom;
  bool get isHost => _isHost;
  bool get isInRoom => _currentRoom != null;
  String? get currentParticipantId => _currentParticipantId;

  /// Generate a 6-digit room code
  String _generateRoomCode() {
    final random = DateTime.now().millisecondsSinceEpoch % 1000000;
    return random.toString().padLeft(6, '0');
  }

  /// Get local IP address
  /// Handles Android emulator IPs (10.0.2.x) by detecting them and providing alternatives
  Future<String?> getLocalIp() async {
    try {
      final wifiIP = await _networkInfo.getWifiIP();
      
      // Check if we're on an Android emulator (10.0.2.x range)
      if (wifiIP != null && wifiIP.startsWith('10.0.2.')) {
        debugPrint('WatchParty: Detected Android emulator IP: $wifiIP');
        debugPrint('WatchParty: Emulator IPs are not accessible from other devices');
        debugPrint('WatchParty: For emulator-to-emulator: use 10.0.2.2');
        debugPrint('WatchParty: For device-to-emulator: use host machine IP with port forwarding');
        
        // Try to get the actual network IP of the host machine
        // This works by trying to connect to a public DNS server and checking the local IP
        try {
          final interfaces = await NetworkInterface.list(
            includeLinkLocal: false,
            type: InternetAddressType.IPv4,
          );
          
          // Find a non-loopback, non-emulator IP
          for (final interface in interfaces) {
            for (final addr in interface.addresses) {
              final ip = addr.address;
              // Skip loopback and emulator IPs
              if (!ip.startsWith('127.') && 
                  !ip.startsWith('10.0.2.') && 
                  !ip.startsWith('169.254.')) {
                debugPrint('WatchParty: Found host machine IP: $ip');
                return ip;
              }
            }
          }
        } catch (e) {
          debugPrint('WatchParty: Could not get host machine IP: $e');
        }
        
        // Fallback: return 10.0.2.2 for emulator-to-emulator connections
        // Note: This only works for emulator-to-emulator, not device-to-emulator
        return '10.0.2.2';
      }
      
      return wifiIP;
    } catch (e) {
      debugPrint('Error getting local IP: $e');
      return null;
    }
  }
  
  /// Check if an IP address is an emulator IP
  bool isEmulatorIp(String? ip) {
    return ip != null && (ip.startsWith('10.0.2.') || ip == '10.0.2.2');
  }

  /// Create a new watch party room (host)
  Future<WatchPartyRoom> createRoom({
    required String hostName,
    required String videoUrl,
    required String videoTitle,
    Duration initialPosition = Duration.zero,
    bool initialPlaying = false,
  }) async {
    final roomId = _uuid.v4();
    final hostId = _uuid.v4();
    _currentParticipantId = hostId;
    _isHost = true;

    final roomCode = _generateRoomCode();

    // Check if video is a local file and start streaming if needed
    String finalVideoUrl = videoUrl;
    if (VideoStreamingService.isLocalFile(videoUrl)) {
      final localIp = await getLocalIp();
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
    );

    _currentRoom = room;

    // Start HTTP server for sync
    await _startServer();

    // Host is always connected when server starts successfully
    if (_server != null) {
      _isConnected = true;
      _connectionError = null;
      // Ensure _hostPort is set even if it wasn't set in _startServer
      if (_hostPort == null) {
        _hostPort = _server!.port;
        debugPrint('WatchParty: _hostPort was null, set to ${_server!.port}');
      }
      debugPrint('WatchParty: Server confirmed running, port: ${_server!.port}, _hostPort: $_hostPort');
    } else {
      debugPrint('WatchParty: WARNING - Server is null after _startServer()');
    }

    return room;
  }

  /// Start HTTP server for receiving sync messages
  Future<void> _startServer() async {
    if (_server != null) {
      debugPrint('WatchParty: Server already running on port ${_server!.port}');
      return;
    }

    try {
      debugPrint('WatchParty: Starting server...');
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      final port = _server!.port;
      _hostPort = port; // Store the port
      debugPrint('WatchParty: Server started successfully on port $port');
      debugPrint('WatchParty: _hostPort set to $_hostPort');

      _server!.listen((HttpRequest request) async {
        await _handleRequest(request);
      });
    } catch (e, stackTrace) {
      debugPrint('WatchParty: Error starting server: $e');
      debugPrint('WatchParty: Stack trace: $stackTrace');
      _hostPort = null;
      _server = null;
    }
  }

  /// Handle incoming HTTP requests
  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.method == 'POST') {
        final body = await utf8.decoder.bind(request).join();
        final message = SyncMessage.fromJsonString(body);

        if (message.type == SyncMessageType.ping) {
          // Respond with current room state
          final response = SyncMessage(
            type: SyncMessageType.roomUpdate,
            room: _currentRoom,
          );
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(response.toJsonString());
          await request.response.close();
        } else if (_isHost) {
          // Host processes sync commands
          _processSyncMessage(message);
          request.response
            ..statusCode = 200
            ..write('OK');
          await request.response.close();
        }
      } else if (request.method == 'GET') {
        // Return current room state along with recent messages and reactions
        if (_currentRoom != null) {
          final responseData = {
            'room': _currentRoom!.toJson(),
            'recentMessages': _sessionMessages.map((m) => m.toJson()).toList(),
            'recentReactions': _recentReactions.map((r) => r.toJson()).toList(),
          };
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(responseData));
        } else {
          request.response.statusCode = 404;
        }
        await request.response.close();
      }
    } catch (e) {
      debugPrint('Error handling request: $e');
      request.response.statusCode = 500;
      await request.response.close();
    }
  }

  /// Process sync message (host only)
  void _processSyncMessage(SyncMessage message) {
    if (!_isHost || _currentRoom == null) return;

    switch (message.type) {
      case SyncMessageType.play:
        if (message.position != null) {
          _currentRoom = _currentRoom!.copyWith(
            currentPosition: message.position!,
            isPlaying: true,
          );
          _broadcastSync(
            SyncMessage(
              type: SyncMessageType.play,
              position: message.position,
              isPlaying: true,
            ),
          );
        }
        break;
      case SyncMessageType.pause:
        _currentRoom = _currentRoom!.copyWith(isPlaying: false);
        _broadcastSync(
          SyncMessage(type: SyncMessageType.pause, isPlaying: false),
        );
        break;
      case SyncMessageType.seek:
        if (message.position != null) {
          _currentRoom = _currentRoom!.copyWith(
            currentPosition: message.position!,
          );
          _broadcastSync(
            SyncMessage(type: SyncMessageType.seek, position: message.position),
          );
        }
        break;
      case SyncMessageType.chat:
        if (message.chatMessage != null) {
          // Store message for session persistence
          _sessionMessages.add(message.chatMessage!);
          if (_sessionMessages.length > _maxSessionMessages) {
            _sessionMessages.removeAt(0);
          }
          // Broadcast to all participants (including host)
          _broadcastSync(message);
          // Also trigger chat message callback directly for host
          onChatMessage?.call(message.chatMessage!);
        }
        break;
      case SyncMessageType.reaction:
        if (message.reaction != null) {
          // Broadcast to all participants (including host)
          _broadcastSync(message);
          // Also trigger reaction callback directly for host
          onReaction?.call(message.reaction!);
        }
        break;
      default:
        break;
    }

    onRoomUpdate?.call(_currentRoom!);
  }

  /// Broadcast sync message to all participants (simplified - in real app would use WebSocket)
  void _broadcastSync(SyncMessage message) {
    // Call sync message callback
    onSyncMessage?.call(message);

    // Also call specific callbacks for chat and reactions
    // These callbacks are called for ALL participants including host
    if (message.type == SyncMessageType.chat && message.chatMessage != null) {
      // Store message for session persistence
      _sessionMessages.add(message.chatMessage!);
      if (_sessionMessages.length > _maxSessionMessages) {
        _sessionMessages.removeAt(0);
      }
      // Call chat message callback for all (host and guests)
      onChatMessage?.call(message.chatMessage!);
    }
    if (message.type == SyncMessageType.reaction && message.reaction != null) {
      // Call reaction callback for all (host and guests)
      onReaction?.call(message.reaction!);
    }
  }

  /// Join a room (guest)
  Future<WatchPartyRoom?> joinRoom({
    required String hostIp,
    required int hostPort,
    required String participantName,
    String? roomCode,
  }) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse('http://$hostIp:$hostPort');
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final responseData = jsonDecode(body) as Map<String, dynamic>;
        
        // Handle both old format (just room) and new format (room + messages + reactions)
        WatchPartyRoom room;
        if (responseData.containsKey('room')) {
          // New format with messages and reactions
          room = WatchPartyRoom.fromJson(responseData['room'] as Map<String, dynamic>);
        } else {
          // Old format (backward compatibility)
          room = WatchPartyRoom.fromJson(responseData);
        }

        // Check room code if provided
        if (roomCode != null && room.roomCode != roomCode) {
          return null;
        }

        // Add participant
        final participantId = _uuid.v4();
        _currentParticipantId = participantId;
        _isHost = false;

        final updatedParticipants = [
          ...room.participants,
          WatchPartyParticipant(
            id: participantId,
            name: participantName,
            isHost: false,
            joinedAt: DateTime.now(),
          ),
        ];

        _currentRoom = room.copyWith(participants: updatedParticipants);
        _hostIp = hostIp;
        _hostPort = hostPort;
        _isConnected = true;
        _connectionError = null;

        // Start polling for updates
        _startPolling(hostIp, hostPort);

        return _currentRoom;
      } else {
        _isConnected = false;
        _connectionError = 'Room not found (${response.statusCode})';
        return null;
      }
    } on SocketException catch (e) {
      _isConnected = false;
      _connectionError = 'Connection failed: ${e.message}';
      debugPrint('Error joining room: $e');
      return null;
    } on TimeoutException catch (e) {
      _isConnected = false;
      _connectionError = 'Connection timeout';
      debugPrint('Error joining room: $e');
      return null;
    } catch (e) {
      _isConnected = false;
      _connectionError = 'Unknown error: $e';
      debugPrint('Error joining room: $e');
      return null;
    }
  }

  /// Start polling for room updates (guest)
  void _startPolling(String hostIp, int hostPort) {
    _syncTimer?.cancel();
    // Increased polling frequency for more responsive sync (250ms instead of 500ms)
    _syncTimer = Timer.periodic(const Duration(milliseconds: 250), (
      timer,
    ) async {
      if (!_isHost && _currentRoom != null) {
        try {
          final client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 3);
          final uri = Uri.parse('http://$hostIp:$hostPort');
          final request = await client.getUrl(uri);
          final response = await request.close();

          if (response.statusCode == 200) {
            final body = await response.transform(utf8.decoder).join();
            final responseData = jsonDecode(body) as Map<String, dynamic>;
            
            // Handle both old format (just room) and new format (room + messages + reactions)
            WatchPartyRoom updatedRoom;
            List<ChatMessage> recentMessages = [];
            List<Reaction> recentReactions = [];
            
            if (responseData.containsKey('room')) {
              // New format with messages and reactions
              updatedRoom = WatchPartyRoom.fromJson(responseData['room'] as Map<String, dynamic>);
              recentMessages = (responseData['recentMessages'] as List<dynamic>?)
                  ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
                  .toList() ?? [];
              recentReactions = (responseData['recentReactions'] as List<dynamic>?)
                  ?.map((r) => Reaction.fromJson(r as Map<String, dynamic>))
                  .toList() ?? [];
            } else {
              // Old format (backward compatibility)
              updatedRoom = WatchPartyRoom.fromJson(responseData);
            }

            _isConnected = true;
            _connectionError = null;

            // Always update room state and notify
            _currentRoom = updatedRoom;
            _isConnected = true;
            _connectionError = null;
            
            // Process new messages (check against session messages to avoid duplicates)
            for (final message in recentMessages) {
              // Check if we've already seen this message
              if (!_sessionMessages.any((m) => m.id == message.id)) {
                _sessionMessages.add(message);
                if (_sessionMessages.length > _maxSessionMessages) {
                  _sessionMessages.removeAt(0);
                }
                // Trigger callback for new message
                onChatMessage?.call(message);
              }
            }
            
            // Process new reactions (check against recent reactions to avoid duplicates)
            // Reactions are transient, so we check by timestamp and participant
            for (final reaction in recentReactions) {
              // Check if we've already seen this reaction (same ID or very recent from same participant)
              final isNew = !_recentReactions.any((r) => 
                r.id == reaction.id || 
                (r.participantId == reaction.participantId && 
                 r.type == reaction.type &&
                 (reaction.timestamp.difference(r.timestamp).inSeconds < 2))
              );
              
              if (isNew) {
                _recentReactions.add(reaction);
                if (_recentReactions.length > _maxRecentReactions) {
                  _recentReactions.removeAt(0);
                }
                // Trigger callback for new reaction
                onReaction?.call(reaction);
              }
            }
            
            // Always notify room update (provider will handle deduplication)
            onRoomUpdate?.call(updatedRoom);
            
            // Check if room state changed
            final previousVideoUrl = _currentRoom!.videoUrl;
            final previousVideoTitle = _currentRoom!.videoTitle;
            final videoChanged =
                previousVideoUrl != updatedRoom.videoUrl ||
                previousVideoTitle != updatedRoom.videoTitle;
            final positionChanged =
                _currentRoom!.currentPosition != updatedRoom.currentPosition;
            final playingChanged =
                _currentRoom!.isPlaying != updatedRoom.isPlaying;

            // If video changed, notify listeners
            // This is critical for guests to navigate when host starts a video
            if (videoChanged && updatedRoom.videoUrl.isNotEmpty) {
              debugPrint('WatchPartyService: Video changed from "$previousVideoUrl" to "${updatedRoom.videoUrl}"');
              onVideoChange?.call(
                updatedRoom.videoUrl,
                updatedRoom.videoTitle,
              );
            }
            
            // Trigger sync messages for play/pause/seek
            if (playingChanged) {
              if (updatedRoom.isPlaying) {
                onSyncMessage?.call(SyncMessage(
                  type: SyncMessageType.play,
                  position: updatedRoom.currentPosition,
                  isPlaying: true,
                ));
              } else {
                onSyncMessage?.call(SyncMessage(
                  type: SyncMessageType.pause,
                  isPlaying: false,
                ));
              }
            } else if (positionChanged && !playingChanged) {
              // Only seek if position changed but playing state didn't
              onSyncMessage?.call(SyncMessage(
                type: SyncMessageType.seek,
                position: updatedRoom.currentPosition,
              ));
            }
          } else {
            _isConnected = false;
            _connectionError = 'Server error (${response.statusCode})';
          }
        } on SocketException catch (e) {
          _isConnected = false;
          _connectionError = 'Connection lost: ${e.message}';
          debugPrint('Polling error: $e');
        } on TimeoutException {
          _isConnected = false;
          _connectionError = 'Connection timeout';
          debugPrint('Polling timeout');
        } catch (e) {
          _isConnected = false;
          _connectionError = 'Polling error: $e';
          debugPrint('Polling error: $e');
        }
      }
    });
  }

  /// Send sync command (guest sends to host)
  Future<void> sendSyncCommand({
    String? hostIp,
    int? hostPort,
    required SyncMessageType type,
    Duration? position,
    bool? isPlaying,
    ChatMessage? chatMessage,
    Reaction? reaction,
  }) async {
    if (_isHost || _currentParticipantId == null) return;

    final targetIp = hostIp ?? _hostIp;
    final targetPort = hostPort ?? _hostPort;

    if (targetIp == null || targetPort == null) {
      _connectionError = 'Host connection info missing';
      return;
    }

    try {
      final message = SyncMessage(
        type: type,
        participantId: _currentParticipantId,
        position: position,
        isPlaying: isPlaying,
        chatMessage: chatMessage,
        reaction: reaction,
      );

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final uri = Uri.parse('http://$targetIp:$targetPort');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(message.toJsonString());
      final response = await request.close();

      if (response.statusCode == 200) {
        _isConnected = true;
        _connectionError = null;
      } else {
        _isConnected = false;
        _connectionError = 'Server error (${response.statusCode})';
      }
    } on SocketException catch (e) {
      _isConnected = false;
      _connectionError = 'Connection failed: ${e.message}';
      debugPrint('Error sending sync command: $e');
    } on TimeoutException {
      _isConnected = false;
      _connectionError = 'Connection timeout';
      debugPrint('Error sending sync command: timeout');
    } catch (e) {
      _isConnected = false;
      _connectionError = 'Error: $e';
      debugPrint('Error sending sync command: $e');
    }
  }

  /// Send chat message
  Future<void> sendChatMessage(String message) async {
    if (_currentParticipantId == null) return;

    final participant = _currentRoom?.participants.firstWhere(
      (p) => p.id == _currentParticipantId,
      orElse: () => WatchPartyParticipant(
        id: _currentParticipantId!,
        name: 'Unknown',
        isHost: false,
        joinedAt: DateTime.now(),
      ),
    );

    final chatMessage = ChatMessage(
      id: _uuid.v4(),
      participantId: _currentParticipantId!,
      participantName: participant?.name ?? 'Unknown',
      message: message,
      timestamp: DateTime.now(),
    );

    if (_isHost) {
      // Host broadcasts directly (will trigger onChatMessage via _broadcastSync)
      // Also trigger callback immediately for host
      onChatMessage?.call(chatMessage);
      _broadcastSync(
        SyncMessage(type: SyncMessageType.chat, chatMessage: chatMessage),
      );
    } else {
      // Guest sends to host
      await sendSyncCommand(
        type: SyncMessageType.chat,
        chatMessage: chatMessage,
      );
    }
  }

  /// Send reaction
  Future<void> sendReaction(ReactionType type) async {
    if (_currentParticipantId == null) return;

    final participant = _currentRoom?.participants.firstWhere(
      (p) => p.id == _currentParticipantId,
      orElse: () => WatchPartyParticipant(
        id: _currentParticipantId!,
        name: 'Unknown',
        isHost: false,
        joinedAt: DateTime.now(),
      ),
    );

    final reaction = Reaction(
      id: _uuid.v4(),
      participantId: _currentParticipantId!,
      participantName: participant?.name ?? 'Unknown',
      type: type,
      timestamp: DateTime.now(),
    );

    if (_isHost) {
      // Store reaction for session
      _recentReactions.add(reaction);
      if (_recentReactions.length > _maxRecentReactions) {
        _recentReactions.removeAt(0);
      }
      // Host broadcasts directly (will trigger onReaction via _broadcastSync)
      _broadcastSync(
        SyncMessage(type: SyncMessageType.reaction, reaction: reaction),
      );
    } else {
      // Guest sends to host
      await sendSyncCommand(type: SyncMessageType.reaction, reaction: reaction);
    }
  }

  /// Update room state (host only)
  void updateRoomState({
    Duration? position,
    bool? isPlaying,
    String? videoUrl,
    String? videoTitle,
  }) {
    if (!_isHost || _currentRoom == null) return;

    final videoChanged =
        (videoUrl != null && videoUrl != _currentRoom!.videoUrl) ||
        (videoTitle != null && videoTitle != _currentRoom!.videoTitle);

    // Update position timestamp when position changes
    final positionChanged = position != null && 
        position != _currentRoom!.currentPosition;

    _currentRoom = _currentRoom!.copyWith(
      currentPosition: position ?? _currentRoom!.currentPosition,
      isPlaying: isPlaying ?? _currentRoom!.isPlaying,
      videoUrl: videoUrl ?? _currentRoom!.videoUrl,
      videoTitle: videoTitle ?? _currentRoom!.videoTitle,
      positionUpdatedAt: positionChanged ? DateTime.now() : _currentRoom!.positionUpdatedAt,
    );

    // Broadcast update
    _broadcastSync(
      SyncMessage(
        type: SyncMessageType.roomUpdate,
        room: _currentRoom,
        position: position,
        isPlaying: isPlaying,
      ),
    );

    // Notify about video change
    if (videoChanged) {
      onVideoChange?.call(_currentRoom!.videoUrl, _currentRoom!.videoTitle);
    }

    onRoomUpdate?.call(_currentRoom!);
  }

  /// Leave the current room
  Future<void> leaveRoom() async {
    _syncTimer?.cancel();
    _syncTimer = null;

    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }

    // Stop video streaming if host is leaving
    if (_isHost) {
      await VideoStreamingService().stopStreaming();
    }

    _currentRoom = null;
    _currentParticipantId = null;
    _isHost = false;
    _hostIp = null;
    _hostPort = null;
    _isConnected = false;
    _connectionError = null;
    // Clear session messages and reactions when leaving room
    _sessionMessages.clear();
    _recentReactions.clear();
  }

  /// Get server port (for sharing with guests)
  int? getServerPort() {
    // Return stored port or server port
    // Try multiple sources to ensure we get the port
    int? port = _hostPort;
    if (port == null && _server != null) {
      port = _server!.port;
      // Update _hostPort if we got it from server
      _hostPort = port;
    }
    debugPrint('WatchParty: getServerPort() called - _hostPort: $_hostPort, _server?.port: ${_server?.port}, _server is null: ${_server == null}, returning: $port');
    return port;
  }

  /// Dispose resources
  void dispose() {
    leaveRoom();
  }
}
