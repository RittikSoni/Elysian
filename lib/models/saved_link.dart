import 'package:elysian/services/storage_service.dart';

class SavedLink {
  final String id;
  final String url;
  final String title;
  final String? thumbnailUrl;
  final String? description;
  final LinkType type;
  final List<String> listIds; // Changed from single listId to multiple listIds
  final DateTime savedAt;
  final bool isFavorite; // Favorite/starred link
  final String? notes; // Personal notes/annotations
  final DateTime? lastViewedAt; // Last time link was viewed
  final int viewCount; // Number of times viewed

  SavedLink({
    required this.id,
    required this.url,
    required this.title,
    this.thumbnailUrl,
    this.description,
    required this.type,
    required this.listIds,
    required this.savedAt,
    this.isFavorite = false,
    this.notes,
    this.lastViewedAt,
    this.viewCount = 0,
  });

  // Helper getter for backward compatibility (returns first listId)
  String get listId => listIds.isNotEmpty ? listIds.first : StorageService.defaultListId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'title': title,
        'thumbnailUrl': thumbnailUrl,
        'description': description,
        'type': type.toString(),
        'listIds': listIds, // New field
        'listId': listIds.isNotEmpty ? listIds.first : null, // Keep for backward compatibility
        'savedAt': savedAt.toIso8601String(),
        'isFavorite': isFavorite,
        'notes': notes,
        'lastViewedAt': lastViewedAt?.toIso8601String(),
        'viewCount': viewCount,
      };

  factory SavedLink.fromJson(Map<String, dynamic> json) {
    // Handle migration from old single listId to new listIds
    List<String> listIds;
    if (json['listIds'] != null) {
      // New format with listIds
      listIds = List<String>.from(json['listIds'] as List);
    } else if (json['listId'] != null) {
      // Old format with single listId - migrate to listIds
      listIds = [json['listId'] as String];
    } else {
      // Fallback to default list
      listIds = [StorageService.defaultListId];
    }

    return SavedLink(
      id: json['id'] as String,
      url: json['url'] as String,
      title: json['title'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      description: json['description'] as String?,
      type: LinkType.fromString(json['type'] as String),
      listIds: listIds,
      savedAt: DateTime.parse(json['savedAt'] as String),
      isFavorite: json['isFavorite'] as bool? ?? false,
      notes: json['notes'] as String?,
      lastViewedAt: json['lastViewedAt'] != null
          ? DateTime.parse(json['lastViewedAt'] as String)
          : null,
      viewCount: json['viewCount'] as int? ?? 0,
    );
  }

  // Helper method to create a copy with updated fields
  SavedLink copyWith({
    String? id,
    String? url,
    String? title,
    String? thumbnailUrl,
    String? description,
    LinkType? type,
    List<String>? listIds,
    DateTime? savedAt,
    bool? isFavorite,
    String? notes,
    DateTime? lastViewedAt,
    int? viewCount,
  }) {
    return SavedLink(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      description: description ?? this.description,
      type: type ?? this.type,
      listIds: listIds ?? this.listIds,
      savedAt: savedAt ?? this.savedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      notes: notes ?? this.notes,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      viewCount: viewCount ?? this.viewCount,
    );
  }
}

enum LinkType {
  youtube,
  instagram,
  vimeo,
  googledrive,
  directVideo, // Direct video URLs (mp4, webm, m3u8, etc.)
  web, // Generic web video links
  unknown;

  static LinkType fromString(String value) {
    switch (value) {
      case 'LinkType.youtube':
        return LinkType.youtube;
      case 'LinkType.instagram':
        return LinkType.instagram;
      case 'LinkType.vimeo':
        return LinkType.vimeo;
      case 'LinkType.googledrive':
        return LinkType.googledrive;
      case 'LinkType.directVideo':
        return LinkType.directVideo;
      case 'LinkType.web':
        return LinkType.web;
      default:
        return LinkType.unknown;
    }
  }

  /// Returns true if this link type can be played in inbuilt player
  bool get canPlayInbuilt {
    switch (this) {
      case LinkType.youtube:
      case LinkType.directVideo:
        return true;
      case LinkType.vimeo:
      case LinkType.googledrive:
        // Can attempt, but may need URL extraction
        return true;
      case LinkType.instagram:
      case LinkType.web:
      case LinkType.unknown:
        return false;
    }
  }
}

