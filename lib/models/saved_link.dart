class SavedLink {
  final String id;
  final String url;
  final String title;
  final String? thumbnailUrl;
  final String? description;
  final LinkType type;
  final String listId;
  final DateTime savedAt;

  SavedLink({
    required this.id,
    required this.url,
    required this.title,
    this.thumbnailUrl,
    this.description,
    required this.type,
    required this.listId,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'title': title,
        'thumbnailUrl': thumbnailUrl,
        'description': description,
        'type': type.toString(),
        'listId': listId,
        'savedAt': savedAt.toIso8601String(),
      };

  factory SavedLink.fromJson(Map<String, dynamic> json) => SavedLink(
        id: json['id'] as String,
        url: json['url'] as String,
        title: json['title'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        description: json['description'] as String?,
        type: LinkType.fromString(json['type'] as String),
        listId: json['listId'] as String,
        savedAt: DateTime.parse(json['savedAt'] as String),
      );
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

