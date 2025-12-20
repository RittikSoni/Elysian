/// Types of sections that can appear on the home screen
enum HomeSectionType {
  header, // Featured content header
  userList, // User's custom list with configurable layout
  favorites, // Favorite links
  recentActivity, // Recently viewed links
  suggestions, // Smart suggestions
  savedLinks, // All saved links
}

/// Layout styles for list sections
enum ListLayoutStyle {
  circular, // Circular items (like previews)
  rectangle, // Rectangular cards (horizontal)
  smaller, // Small rectangular cards
  medium, // Medium rectangular cards
  square, // Square cards
  large, // Large rectangular cards (like originals)
}

/// Configuration for a home screen section
class HomeScreenSection {
  final String id;
  final HomeSectionType type;
  final String title;
  final bool isVisible;
  final int order;
  final Map<String, dynamic>? config; // Additional configuration (e.g., which list to show)

  HomeScreenSection({
    required this.id,
    required this.type,
    required this.title,
    this.isVisible = true,
    required this.order,
    this.config,
  });

  HomeScreenSection copyWith({
    String? id,
    HomeSectionType? type,
    String? title,
    bool? isVisible,
    int? order,
    Map<String, dynamic>? config,
  }) {
    return HomeScreenSection(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      isVisible: isVisible ?? this.isVisible,
      order: order ?? this.order,
      config: config ?? this.config,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toString(),
        'title': title,
        'isVisible': isVisible,
        'order': order,
        'config': config,
      };

  factory HomeScreenSection.fromJson(Map<String, dynamic> json) {
    return HomeScreenSection(
      id: json['id'] as String,
      type: HomeSectionType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => HomeSectionType.userList,
      ),
      title: json['title'] as String,
      isVisible: json['isVisible'] as bool? ?? true,
      order: json['order'] as int,
      config: json['config'] as Map<String, dynamic>?,
    );
  }

  /// Get layout style from config
  ListLayoutStyle get layoutStyle {
    final layoutStr = config?['layout'] as String?;
    if (layoutStr == null) {
      return ListLayoutStyle.rectangle; // Default
    }
    // Handle both "ListLayoutStyle.rectangle" and "rectangle" formats
    final cleanStr = layoutStr.replaceFirst('ListLayoutStyle.', '');
    return ListLayoutStyle.values.firstWhere(
      (e) => e.toString().replaceFirst('ListLayoutStyle.', '') == cleanStr,
      orElse: () => ListLayoutStyle.rectangle,
    );
  }

  /// Get default sections in order
  static List<HomeScreenSection> getDefaultSections() {
    return [
      HomeScreenSection(
        id: 'header',
        type: HomeSectionType.header,
        title: 'Featured Content',
        order: 0,
        config: {'contentId': 'sintel'},
      ),
      HomeScreenSection(
        id: 'favorites',
        type: HomeSectionType.favorites,
        title: 'Favorites',
        order: 1,
      ),
      HomeScreenSection(
        id: 'recent_activity',
        type: HomeSectionType.recentActivity,
        title: 'Recent Activity',
        order: 2,
      ),
      HomeScreenSection(
        id: 'suggestions',
        type: HomeSectionType.suggestions,
        title: 'Suggestions',
        order: 3,
      ),
      HomeScreenSection(
        id: 'saved_links',
        type: HomeSectionType.savedLinks,
        title: 'All Saved Links',
        order: 4,
      ),
    ];
  }
}

