import 'package:flutter/foundation.dart';
import 'package:elysian/services/storage_service.dart';

/// Global app state provider for preferences and settings
class AppStateProvider with ChangeNotifier {
  // Player preference
  bool? _isInbuiltPlayer;
  bool _isLoadingPlayerPreference = false;

  // Recent searches
  List<String> _recentSearches = [];
  bool _isLoadingRecentSearches = false;

  // Getters
  bool get isInbuiltPlayer => _isInbuiltPlayer ?? true;
  bool get isLoadingPlayerPreference => _isLoadingPlayerPreference;
  List<String> get recentSearches => List.unmodifiable(_recentSearches);
  bool get isLoadingRecentSearches => _isLoadingRecentSearches;

  /// Initialize app state
  Future<void> initialize() async {
    await Future.wait([
      _loadPlayerPreference(),
      _loadRecentSearches(),
    ]);
  }

  /// Load player preference
  Future<void> _loadPlayerPreference() async {
    if (_isLoadingPlayerPreference) return;
    
    _isLoadingPlayerPreference = true;
    notifyListeners();

    try {
      _isInbuiltPlayer = await StorageService.isInbuiltPlayer();
    } catch (e) {
      debugPrint('Error loading player preference: $e');
    } finally {
      _isLoadingPlayerPreference = false;
      notifyListeners();
    }
  }

  /// Set player preference
  Future<void> setPlayerPreference(bool useInbuilt) async {
    try {
      await StorageService.setPlayerPreference(useInbuilt);
      _isInbuiltPlayer = useInbuilt;
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting player preference: $e');
      rethrow;
    }
  }

  /// Load recent searches
  Future<void> _loadRecentSearches() async {
    if (_isLoadingRecentSearches) return;
    
    _isLoadingRecentSearches = true;
    notifyListeners();

    try {
      _recentSearches = await StorageService.getRecentSearches();
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    } finally {
      _isLoadingRecentSearches = false;
      notifyListeners();
    }
  }

  /// Add recent search
  Future<void> addRecentSearch(String query) async {
    if (query.trim().isEmpty) return;

    try {
      await StorageService.addRecentSearch(query);
      _recentSearches = await StorageService.getRecentSearches();
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding recent search: $e');
    }
  }

  /// Clear recent searches
  Future<void> clearRecentSearches() async {
    try {
      await StorageService.clearRecentSearches();
      _recentSearches = [];
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing recent searches: $e');
      rethrow;
    }
  }
}

