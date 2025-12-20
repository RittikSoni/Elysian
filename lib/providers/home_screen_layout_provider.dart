import 'package:flutter/foundation.dart';
import 'package:elysian/models/home_screen_section.dart';
import 'package:elysian/services/storage_service.dart';

/// Provider for managing home screen layout configuration
class HomeScreenLayoutProvider with ChangeNotifier {
  List<HomeScreenSection> _sections = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  List<HomeScreenSection> get sections => List.unmodifiable(_sections);
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  /// Get visible sections in order
  List<HomeScreenSection> get visibleSections {
    return _sections
        .where((s) => s.isVisible)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Initialize and load layout
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      _sections = await StorageService.getHomeScreenLayout();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error loading home screen layout: $e');
      // Use default layout on error
      _sections = HomeScreenSection.getDefaultSections();
      _isInitialized = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update section visibility
  Future<void> setSectionVisibility(String sectionId, bool isVisible) async {
    final index = _sections.indexWhere((s) => s.id == sectionId);
    if (index == -1) return;

    _sections[index] = _sections[index].copyWith(isVisible: isVisible);
    await _saveLayout();
    notifyListeners();
  }

  /// Reorder sections
  Future<void> reorderSections(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = _sections.removeAt(oldIndex);
    _sections.insert(newIndex, item);

    // Update order values
    for (int i = 0; i < _sections.length; i++) {
      _sections[i] = _sections[i].copyWith(order: i);
    }

    await _saveLayout();
    notifyListeners();
  }

  /// Update section configuration
  Future<void> updateSectionConfig(String sectionId, Map<String, dynamic> config) async {
    final index = _sections.indexWhere((s) => s.id == sectionId);
    if (index == -1) return;

    _sections[index] = _sections[index].copyWith(config: config);
    await _saveLayout();
    notifyListeners();
  }

  /// Add a new section (for dynamic list content sections)
  Future<void> addListContentSection(String listId, String listName) async {
    final maxOrder = _sections.isEmpty
        ? 0
        : _sections.map((s) => s.order).reduce((a, b) => a > b ? a : b);

    final newSection = HomeScreenSection(
      id: 'list_$listId',
      type: HomeSectionType.userList,
      title: listName,
      order: maxOrder + 1,
      config: {
        'listId': listId,
        'layout': ListLayoutStyle.rectangle.toString(),
      },
    );

    _sections.add(newSection);
    await _saveLayout();
    notifyListeners();
  }

  /// Remove a section
  Future<void> removeSection(String sectionId) async {
    _sections.removeWhere((s) => s.id == sectionId);
    await _saveLayout();
    notifyListeners();
  }

  /// Reset to default layout
  Future<void> resetToDefault() async {
    _sections = HomeScreenSection.getDefaultSections();
    await _saveLayout();
    notifyListeners();
  }

  /// Save layout to storage
  Future<void> _saveLayout() async {
    try {
      await StorageService.saveHomeScreenLayout(_sections);
    } catch (e) {
      debugPrint('Error saving home screen layout: $e');
    }
  }

  /// Get section by ID
  HomeScreenSection? getSectionById(String sectionId) {
    try {
      return _sections.firstWhere((s) => s.id == sectionId);
    } catch (e) {
      return null;
    }
  }
}

