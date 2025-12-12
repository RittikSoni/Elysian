import 'dart:convert';

/// Represents a watch party room
class WatchPartyRoom {
  final String roomId;
  final String hostId;
  final String hostName;
  final String videoUrl;
  final String videoTitle;
  final Duration currentPosition;
  final bool isPlaying;
  final DateTime createdAt;
  final List<WatchPartyParticipant> participants;
  final String? roomCode; // 6-digit code for easy joining

  WatchPartyRoom({
    required this.roomId,
    required this.hostId,
    required this.hostName,
    required this.videoUrl,
    required this.videoTitle,
    required this.currentPosition,
    required this.isPlaying,
    required this.createdAt,
    required this.participants,
    this.roomCode,
  });

  WatchPartyRoom copyWith({
    String? roomId,
    String? hostId,
    String? hostName,
    String? videoUrl,
    String? videoTitle,
    Duration? currentPosition,
    bool? isPlaying,
    DateTime? createdAt,
    List<WatchPartyParticipant>? participants,
    String? roomCode,
  }) {
    return WatchPartyRoom(
      roomId: roomId ?? this.roomId,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      videoUrl: videoUrl ?? this.videoUrl,
      videoTitle: videoTitle ?? this.videoTitle,
      currentPosition: currentPosition ?? this.currentPosition,
      isPlaying: isPlaying ?? this.isPlaying,
      createdAt: createdAt ?? this.createdAt,
      participants: participants ?? this.participants,
      roomCode: roomCode ?? this.roomCode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'hostId': hostId,
      'hostName': hostName,
      'videoUrl': videoUrl,
      'videoTitle': videoTitle,
      'currentPosition': currentPosition.inMilliseconds,
      'isPlaying': isPlaying,
      'createdAt': createdAt.toIso8601String(),
      'participants': participants.map((p) => p.toJson()).toList(),
      'roomCode': roomCode,
    };
  }

  factory WatchPartyRoom.fromJson(Map<String, dynamic> json) {
    return WatchPartyRoom(
      roomId: json['roomId'] as String,
      hostId: json['hostId'] as String,
      hostName: json['hostName'] as String,
      videoUrl: json['videoUrl'] as String,
      videoTitle: json['videoTitle'] as String,
      currentPosition: Duration(milliseconds: json['currentPosition'] as int),
      isPlaying: json['isPlaying'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      participants: (json['participants'] as List)
          .map((p) => WatchPartyParticipant.fromJson(p as Map<String, dynamic>))
          .toList(),
      roomCode: json['roomCode'] as String?,
    );
  }
}

/// Represents a participant in a watch party
class WatchPartyParticipant {
  final String id;
  final String name;
  final bool isHost;
  final DateTime joinedAt;
  final String? deviceInfo;

  WatchPartyParticipant({
    required this.id,
    required this.name,
    required this.isHost,
    required this.joinedAt,
    this.deviceInfo,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isHost': isHost,
      'joinedAt': joinedAt.toIso8601String(),
      'deviceInfo': deviceInfo,
    };
  }

  factory WatchPartyParticipant.fromJson(Map<String, dynamic> json) {
    return WatchPartyParticipant(
      id: json['id'] as String,
      name: json['name'] as String,
      isHost: json['isHost'] as bool,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      deviceInfo: json['deviceInfo'] as String?,
    );
  }
}

/// Sync message types for watch party
enum SyncMessageType {
  play,
  pause,
  seek,
  join,
  leave,
  roomUpdate,
  ping,
  chat,
  reaction,
}

/// Message for synchronizing playback
class SyncMessage {
  final SyncMessageType type;
  final String? participantId;
  final String? participantName;
  final Duration? position;
  final bool? isPlaying;
  final WatchPartyRoom? room;
  final DateTime timestamp;
  final ChatMessage? chatMessage;
  final Reaction? reaction;

  SyncMessage({
    required this.type,
    this.participantId,
    this.participantName,
    this.position,
    this.isPlaying,
    this.room,
    DateTime? timestamp,
    this.chatMessage,
    this.reaction,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'participantId': participantId,
      'participantName': participantName,
      'position': position?.inMilliseconds,
      'isPlaying': isPlaying,
      'room': room?.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'chatMessage': chatMessage?.toJson(),
      'reaction': reaction?.toJson(),
    };
  }

  factory SyncMessage.fromJson(Map<String, dynamic> json) {
    return SyncMessage(
      type: SyncMessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SyncMessageType.ping,
      ),
      participantId: json['participantId'] as String?,
      participantName: json['participantName'] as String?,
      position: json['position'] != null
          ? Duration(milliseconds: json['position'] as int)
          : null,
      isPlaying: json['isPlaying'] as bool?,
      room: json['room'] != null
          ? WatchPartyRoom.fromJson(json['room'] as Map<String, dynamic>)
          : null,
      timestamp: DateTime.parse(json['timestamp'] as String),
      chatMessage: json['chatMessage'] != null
          ? ChatMessage.fromJson(json['chatMessage'] as Map<String, dynamic>)
          : null,
      reaction: json['reaction'] != null
          ? Reaction.fromJson(json['reaction'] as Map<String, dynamic>)
          : null,
    );
  }

  String toJsonString() => jsonEncode(toJson());
  factory SyncMessage.fromJsonString(String json) =>
      SyncMessage.fromJson(jsonDecode(json) as Map<String, dynamic>);
}

/// Chat message in watch party
class ChatMessage {
  final String id;
  final String participantId;
  final String participantName;
  final String message;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.participantId,
    required this.participantName,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participantId': participantId,
      'participantName': participantName,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      participantId: json['participantId'] as String,
      participantName: json['participantName'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Reaction types for watch party
enum ReactionType {
  like,
  love,
  laugh,
  wow,
  sad,
  angry,
}

extension ReactionTypeExtension on ReactionType {
  String get emoji {
    switch (this) {
      case ReactionType.like:
        return '👍';
      case ReactionType.love:
        return '❤️';
      case ReactionType.laugh:
        return '😂';
      case ReactionType.wow:
        return '😮';
      case ReactionType.sad:
        return '😢';
      case ReactionType.angry:
        return '😠';
    }
  }

  String get name {
    switch (this) {
      case ReactionType.like:
        return 'Like';
      case ReactionType.love:
        return 'Love';
      case ReactionType.laugh:
        return 'Laugh';
      case ReactionType.wow:
        return 'Wow';
      case ReactionType.sad:
        return 'Sad';
      case ReactionType.angry:
        return 'Angry';
    }
  }
}

/// Reaction in watch party
class Reaction {
  final String id;
  final String participantId;
  final String participantName;
  final ReactionType type;
  final DateTime timestamp;

  Reaction({
    required this.id,
    required this.participantId,
    required this.participantName,
    required this.type,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participantId': participantId,
      'participantName': participantName,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Reaction.fromJson(Map<String, dynamic> json) {
    return Reaction(
      id: json['id'] as String,
      participantId: json['participantId'] as String,
      participantName: json['participantName'] as String,
      type: ReactionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ReactionType.like,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

