import 'package:flutter/foundation.dart';
import 'package:elysian/models/models.dart';
import 'package:elysian/services/storage_service.dart';

/// Enterprise-level Lists Provider with caching and optimized updates
class ListsProvider with ChangeNotifier {
  // Cache for all lists
  List<UserList>? _cachedLists;
  DateTime? _cacheTimestamp;
  static const Duration _cacheValidityDuration = Duration(minutes: 5);

  // Loading states
  bool _isLoading = false;
  bool _isInitialized = false;

  // Getters
  List<UserList> get allLists => _cachedLists ?? [];
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  /// Check if cache is still valid
  bool get _isCacheValid {
    if (_cachedLists == null || _cacheTimestamp == null) return false;
    return DateTime.now().difference(_cacheTimestamp!) < _cacheValidityDuration;
  }

  /// Initialize and load data
  Future<void> initialize() async {
    if (_isInitialized && _isCacheValid) {
      return; // Already initialized and cache is valid
    }

    await loadLists();
  }

  /// Load all lists with caching
  Future<void> loadLists({bool forceRefresh = false}) async {
    if (_isLoading) return; // Prevent concurrent loads

    // Use cache if valid and not forcing refresh
    if (!forceRefresh && _isCacheValid) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final lists = await StorageService.getUserLists();

      _cachedLists = lists;
      _cacheTimestamp = DateTime.now();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error loading lists: $e');
      // Keep existing cache on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get list by ID
  UserList? getListById(String listId) {
    if (_cachedLists == null) return null;
    try {
      return _cachedLists!.firstWhere((list) => list.id == listId);
    } catch (e) {
      return null;
    }
  }

  /// Create a new list
  Future<UserList> createList(String name, {String? description}) async {
    try {
      final newList = await StorageService.createUserList(
        name,
        description: description,
      );

      // Update cache
      if (_cachedLists != null) {
        _cachedLists!.add(newList);
        _cacheTimestamp = DateTime.now();
      } else {
        // Reload if cache is empty
        await loadLists(forceRefresh: true);
      }

      notifyListeners();
      return newList;
    } catch (e) {
      debugPrint('Error creating list: $e');
      rethrow;
    }
  }

  /// Delete a list
  Future<void> deleteList(String listId) async {
    try {
      await StorageService.deleteUserList(listId);

      // Update cache
      if (_cachedLists != null) {
        _cachedLists!.removeWhere((list) => list.id == listId);
        _cacheTimestamp = DateTime.now();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting list: $e');
      rethrow;
    }
  }

  /// Update list item counts (called when links change)
  Future<void> refreshItemCounts() async {
    // Invalidate cache to force refresh of item counts
    _cacheTimestamp = null;
    await loadLists(forceRefresh: true);
  }

  /// Clear cache (force refresh on next load)
  void clearCache() {
    _cachedLists = null;
    _cacheTimestamp = null;
  }

  /// Invalidate cache (mark as stale)
  void invalidateCache() {
    _cacheTimestamp = null;
  }
}
