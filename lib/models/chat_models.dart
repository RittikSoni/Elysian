/// Represents a chat user
class ChatUser {
  final String email;
  final String? displayName;
  final DateTime? lastSeen;
  final DateTime createdAt;

  ChatUser({
    required this.email,
    this.displayName,
    this.lastSeen,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'displayName': displayName,
      'lastSeen': lastSeen?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

/// Friend request status
enum FriendRequestStatus { pending, accepted, rejected }

/// Represents a friend request
class FriendRequest {
  final String id;
  final String fromEmail;
  final String toEmail;
  final FriendRequestStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? fromDisplayName;
  final String? toDisplayName;

  FriendRequest({
    required this.id,
    required this.fromEmail,
    required this.toEmail,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.fromDisplayName,
    this.toDisplayName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromEmail': fromEmail,
      'toEmail': toEmail,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
      'fromDisplayName': fromDisplayName,
      'toDisplayName': toDisplayName,
    };
  }

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as String,
      fromEmail: json['fromEmail'] as String,
      toEmail: json['toEmail'] as String,
      status: FriendRequestStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => FriendRequestStatus.pending,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'] as String)
          : null,
      fromDisplayName: json['fromDisplayName'] as String?,
      toDisplayName: json['toDisplayName'] as String?,
    );
  }
}

/// Represents a chat conversation between two users
class ChatConversation {
  final String id;
  final String user1Email;
  final String user2Email;
  final String? user1DisplayName;
  final String? user2DisplayName;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final String? lastMessage;
  final int unreadCount;
  final DateTime? expiresAt; // Auto-delete after 24 hours
  final String? typingUserEmail; // User currently typing (for typing indicator)

  ChatConversation({
    required this.id,
    required this.user1Email,
    required this.user2Email,
    this.user1DisplayName,
    this.user2DisplayName,
    required this.createdAt,
    this.lastMessageAt,
    this.lastMessage,
    this.unreadCount = 0,
    this.expiresAt,
    this.typingUserEmail,
  });

  ChatConversation copyWith({
    String? id,
    String? user1Email,
    String? user2Email,
    String? user1DisplayName,
    String? user2DisplayName,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    String? lastMessage,
    int? unreadCount,
    DateTime? expiresAt,
    String? typingUserEmail,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      user1Email: user1Email ?? this.user1Email,
      user2Email: user2Email ?? this.user2Email,
      user1DisplayName: user1DisplayName ?? this.user1DisplayName,
      user2DisplayName: user2DisplayName ?? this.user2DisplayName,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      expiresAt: expiresAt ?? this.expiresAt,
      typingUserEmail: typingUserEmail ?? this.typingUserEmail,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user1Email': user1Email,
      'user2Email': user2Email,
      'user1DisplayName': user1DisplayName,
      'user2DisplayName': user2DisplayName,
      'createdAt': createdAt.toIso8601String(),
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'lastMessage': lastMessage,
      'unreadCount': unreadCount,
      'expiresAt': expiresAt?.toIso8601String(),
      'typingUserEmail': typingUserEmail,
    };
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] as String,
      user1Email: json['user1Email'] as String,
      user2Email: json['user2Email'] as String,
      user1DisplayName: json['user1DisplayName'] as String?,
      user2DisplayName: json['user2DisplayName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'] as String)
          : null,
      lastMessage: json['lastMessage'] as String?,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      typingUserEmail: json['typingUserEmail'] as String?,
    );
  }

  /// Get the other user's email in this conversation
  String getOtherUserEmail(String currentUserEmail) {
    return currentUserEmail == user1Email ? user2Email : user1Email;
  }

  /// Get the other user's display name
  String? getOtherUserDisplayName(String currentUserEmail) {
    return currentUserEmail == user1Email ? user2DisplayName : user1DisplayName;
  }
}

/// Message status for tracking delivery
enum MessageStatus {
  sending, // Message is being sent (optimistic UI)
  sent, // Message sent to server
  delivered, // Message delivered to recipient
  read, // Message read by recipient
}

/// Represents a chat message in a direct conversation
class DirectChatMessage {
  final String id;
  final String conversationId;
  final String senderEmail;
  final String? senderDisplayName;
  final String message;
  final DateTime timestamp;
  final DateTime expiresAt; // Auto-delete after 24 hours
  final bool isRead;
  final DateTime? readAt; // When the message was read (seen at time)
  final MessageStatus? status; // Message delivery status (for optimistic UI)

  DirectChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderEmail,
    this.senderDisplayName,
    required this.message,
    required this.timestamp,
    required this.expiresAt,
    this.isRead = false,
    this.readAt,
    this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderEmail': senderEmail,
      'senderDisplayName': senderDisplayName,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
      'status': status?.name,
    };
  }

  factory DirectChatMessage.fromJson(Map<String, dynamic> json) {
    MessageStatus? status;
    if (json['status'] != null) {
      try {
        status = MessageStatus.values.firstWhere(
          (e) => e.name == json['status'],
        );
      } catch (e) {
        // Invalid status, ignore
      }
    }

    return DirectChatMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderEmail: json['senderEmail'] as String,
      senderDisplayName: json['senderDisplayName'] as String?,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      isRead: (json['isRead'] as bool?) ?? false,
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'] as String)
          : null,
      status: status,
    );
  }

  DirectChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderEmail,
    String? senderDisplayName,
    String? message,
    DateTime? timestamp,
    DateTime? expiresAt,
    bool? isRead,
    DateTime? readAt,
    MessageStatus? status,
  }) {
    return DirectChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderEmail: senderEmail ?? this.senderEmail,
      senderDisplayName: senderDisplayName ?? this.senderDisplayName,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      expiresAt: expiresAt ?? this.expiresAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      status: status ?? this.status,
    );
  }

  /// Check if message has expired (should be deleted)
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Get time remaining until expiration
  Duration get timeUntilExpiration {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) {
      return Duration.zero;
    }
    return expiresAt.difference(now);
  }
}

/// Represents a participant in a chat room
class RoomParticipant {
  final String email;
  final String? displayName;
  final DateTime joinedAt;
  final bool isHost;

  RoomParticipant({
    required this.email,
    this.displayName,
    required this.joinedAt,
    this.isHost = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'displayName': displayName,
      'joinedAt': joinedAt.toIso8601String(),
      'isHost': isHost,
    };
  }

  factory RoomParticipant.fromJson(Map<String, dynamic> json) {
    return RoomParticipant(
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      isHost: (json['isHost'] as bool?) ?? false,
    );
  }

  RoomParticipant copyWith({
    String? email,
    String? displayName,
    DateTime? joinedAt,
    bool? isHost,
  }) {
    return RoomParticipant(
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      joinedAt: joinedAt ?? this.joinedAt,
      isHost: isHost ?? this.isHost,
    );
  }
}

/// Represents a chat room with multiple participants
class ChatRoom {
  final String id;
  final String hostEmail;
  final String? hostDisplayName;
  final String roomName;
  final String? roomDescription;
  final List<RoomParticipant> participants;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final String? lastMessage;
  final int unreadCount;
  final DateTime expiresAt; // Auto-delete after 24 hours
  final bool isActive;

  ChatRoom({
    required this.id,
    required this.hostEmail,
    this.hostDisplayName,
    required this.roomName,
    this.roomDescription,
    required this.participants,
    required this.createdAt,
    this.lastMessageAt,
    this.lastMessage,
    this.unreadCount = 0,
    required this.expiresAt,
    this.isActive = true,
  });

  ChatRoom copyWith({
    String? id,
    String? hostEmail,
    String? hostDisplayName,
    String? roomName,
    String? roomDescription,
    List<RoomParticipant>? participants,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    String? lastMessage,
    int? unreadCount,
    DateTime? expiresAt,
    bool? isActive,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      hostEmail: hostEmail ?? this.hostEmail,
      hostDisplayName: hostDisplayName ?? this.hostDisplayName,
      roomName: roomName ?? this.roomName,
      roomDescription: roomDescription ?? this.roomDescription,
      participants: participants ?? this.participants,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hostEmail': hostEmail,
      'hostDisplayName': hostDisplayName,
      'roomName': roomName,
      'roomDescription': roomDescription,
      'participants': participants.map((p) => p.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'lastMessage': lastMessage,
      'unreadCount': unreadCount,
      'expiresAt': expiresAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] as String,
      hostEmail: json['hostEmail'] as String,
      hostDisplayName: json['hostDisplayName'] as String?,
      roomName: json['roomName'] as String,
      roomDescription: json['roomDescription'] as String?,
      participants: (json['participants'] as List)
          .map((p) => RoomParticipant.fromJson(p as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'] as String)
          : null,
      lastMessage: json['lastMessage'] as String?,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      isActive: (json['isActive'] as bool?) ?? true,
    );
  }

  /// Check if room has expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Get time remaining until expiration
  Duration get timeUntilExpiration {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) {
      return Duration.zero;
    }
    return expiresAt.difference(now);
  }

  /// Check if user is host
  bool isHost(String email) => hostEmail.toLowerCase() == email.toLowerCase();

  /// Check if user is participant
  bool isParticipant(String email) {
    return participants.any(
      (p) => p.email.toLowerCase() == email.toLowerCase(),
    );
  }

  /// Get participant count
  int get participantCount => participants.length;

  /// Get participant by email
  RoomParticipant? getParticipant(String email) {
    try {
      return participants.firstWhere(
        (p) => p.email.toLowerCase() == email.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }
}

/// Represents a message in a chat room
class RoomMessage {
  final String id;
  final String roomId;
  final String senderEmail;
  final String? senderDisplayName;
  final String message;
  final DateTime timestamp;
  final DateTime expiresAt; // Auto-delete after 24 hours
  final bool isRead;
  final DateTime? readAt; // When the message was read (seen at time)

  RoomMessage({
    required this.id,
    required this.roomId,
    required this.senderEmail,
    this.senderDisplayName,
    required this.message,
    required this.timestamp,
    required this.expiresAt,
    this.isRead = false,
    this.readAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'senderEmail': senderEmail,
      'senderDisplayName': senderDisplayName,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
    };
  }

  factory RoomMessage.fromJson(Map<String, dynamic> json) {
    return RoomMessage(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      senderEmail: json['senderEmail'] as String,
      senderDisplayName: json['senderDisplayName'] as String?,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      isRead: (json['isRead'] as bool?) ?? false,
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'] as String)
          : null,
    );
  }

  RoomMessage copyWith({
    String? id,
    String? roomId,
    String? senderEmail,
    String? senderDisplayName,
    String? message,
    DateTime? timestamp,
    DateTime? expiresAt,
    bool? isRead,
    DateTime? readAt,
  }) {
    return RoomMessage(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderEmail: senderEmail ?? this.senderEmail,
      senderDisplayName: senderDisplayName ?? this.senderDisplayName,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      expiresAt: expiresAt ?? this.expiresAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
    );
  }

  /// Check if message has expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Get time remaining until expiration
  Duration get timeUntilExpiration {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) {
      return Duration.zero;
    }
    return expiresAt.difference(now);
  }
}
