import 'package:flutter/foundation.dart';
import 'package:elysian/models/models.dart';
import 'package:elysian/services/storage_service.dart';

/// Enterprise-level Links Provider with caching, pagination, and smart updates
/// Follows patterns used by Google, Microsoft, Meta for state management
class LinksProvider with ChangeNotifier {
  // Cache for all links
  List<SavedLink>? _cachedLinks;
  DateTime? _cacheTimestamp;
  static const Duration _cacheValidityDuration = Duration(minutes: 5);

  // Computed lists (cached)
  List<SavedLink>? _favoriteLinks;
  List<SavedLink>? _recentLinks;
  List<SavedLink>? _suggestedLinks;

  // Loading states
  bool _isLoading = false;
  bool _isInitialized = false;

  // Pagination
  static const int _pageSize = 20;
  int _currentPage = 0;
  bool _hasMore = true;

  // Getters
  List<SavedLink> get allLinks => _cachedLinks ?? [];
  List<SavedLink> get favoriteLinks => _favoriteLinks ?? [];
  List<SavedLink> get recentLinks => _recentLinks ?? [];
  List<SavedLink> get suggestedLinks => _suggestedLinks ?? [];
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get hasMore => _hasMore;

  /// Check if cache is still valid
  bool get _isCacheValid {
    if (_cachedLinks == null || _cacheTimestamp == null) return false;
    return DateTime.now().difference(_cacheTimestamp!) < _cacheValidityDuration;
  }

  /// Initialize and load data
  Future<void> initialize() async {
    if (_isInitialized && _isCacheValid) {
      return; // Already initialized and cache is valid
    }

    await loadLinks();
  }

  /// Load all links with caching
  Future<void> loadLinks({bool forceRefresh = false}) async {
    if (_isLoading) return; // Prevent concurrent loads

    // Use cache if valid and not forcing refresh
    if (!forceRefresh && _isCacheValid) {
      _updateComputedLists();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final links = await StorageService.getSavedLinks();
      
      _cachedLinks = links;
      _cacheTimestamp = DateTime.now();
      _currentPage = 0;
      _hasMore = links.length >= _pageSize;

      _updateComputedLists();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error loading links: $e');
      // Keep existing cache on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update computed lists from cache
  void _updateComputedLists() {
    if (_cachedLinks == null) return;

    _favoriteLinks = _cachedLinks!
        .where((link) => link.isFavorite)
        .toList();

    _recentLinks = _cachedLinks!
        .where((link) => link.lastViewedAt != null)
        .toList();
    _recentLinks!.sort((a, b) {
      final aTime = a.lastViewedAt!;
      final bTime = b.lastViewedAt!;
      return bTime.compareTo(aTime);
    });

    // Smart suggestions based on view count and recency
    _suggestedLinks = _cachedLinks!
        .where((link) => 
            link.viewCount > 0 || 
            (link.lastViewedAt != null && 
             DateTime.now().difference(link.lastViewedAt!).inDays < 7))
        .toList();
    _suggestedLinks!.sort((a, b) {
      // Sort by view count first, then recency
      final viewDiff = b.viewCount - a.viewCount;
      if (viewDiff != 0) return viewDiff;
      
      if (a.lastViewedAt == null && b.lastViewedAt == null) return 0;
      if (a.lastViewedAt == null) return 1;
      if (b.lastViewedAt == null) return -1;
      return b.lastViewedAt!.compareTo(a.lastViewedAt!);
    });
    _suggestedLinks = _suggestedLinks!.take(10).toList();
  }

  /// Get paginated links
  List<SavedLink> getPaginatedLinks({int? limit}) {
    if (_cachedLinks == null) return [];
    
    final effectiveLimit = limit ?? (_currentPage + 1) * _pageSize;
    return _cachedLinks!.take(effectiveLimit).toList();
  }

  /// Load more links (pagination)
  Future<void> loadMore() async {
    if (!_hasMore || _isLoading) return;

    _currentPage++;
    _hasMore = _cachedLinks != null && 
               (_currentPage + 1) * _pageSize < _cachedLinks!.length;
    
    notifyListeners();
  }

  /// Get links by list ID
  List<SavedLink> getLinksByList(String listId) {
    if (_cachedLinks == null) return [];
    return _cachedLinks!.where((link) => link.listIds.contains(listId)).toList();
  }

  /// Save a new link
  Future<void> saveLink(SavedLink link) async {
    try {
      await StorageService.saveLink(link);
      
      // Update cache
      if (_cachedLinks != null) {
        // Check if link already exists (update vs add)
        final index = _cachedLinks!.indexWhere((l) => l.id == link.id);
        if (index != -1) {
          _cachedLinks![index] = link;
        } else {
          _cachedLinks!.add(link);
        }
        _cacheTimestamp = DateTime.now();
        _updateComputedLists();
      } else {
        // Reload if cache is empty
        await loadLinks(forceRefresh: true);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving link: $e');
      rethrow;
    }
  }

  /// Delete a link
  Future<void> deleteLink(String linkId) async {
    try {
      await StorageService.deleteLink(linkId);
      
      // Update cache
      if (_cachedLinks != null) {
        _cachedLinks!.removeWhere((link) => link.id == linkId);
        _cacheTimestamp = DateTime.now();
        _updateComputedLists();
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting link: $e');
      rethrow;
    }
  }

  /// Bulk delete links
  Future<void> deleteLinks(List<String> linkIds) async {
    try {
      await StorageService.deleteLinks(linkIds);
      
      // Update cache
      if (_cachedLinks != null) {
        _cachedLinks!.removeWhere((link) => linkIds.contains(link.id));
        _cacheTimestamp = DateTime.now();
        _updateComputedLists();
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting links: $e');
      rethrow;
    }
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String linkId) async {
    try {
      await StorageService.toggleFavorite(linkId);
      
      // Update cache
      if (_cachedLinks != null) {
        final index = _cachedLinks!.indexWhere((l) => l.id == linkId);
        if (index != -1) {
          _cachedLinks![index] = _cachedLinks![index].copyWith(
            isFavorite: !_cachedLinks![index].isFavorite,
          );
          _cacheTimestamp = DateTime.now();
          _updateComputedLists();
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      rethrow;
    }
  }

  /// Bulk toggle favorites
  Future<void> toggleFavorites(List<String> linkIds, bool isFavorite) async {
    try {
      await StorageService.toggleFavoritesForLinks(linkIds, isFavorite);
      
      // Update cache
      if (_cachedLinks != null) {
        for (final linkId in linkIds) {
          final index = _cachedLinks!.indexWhere((l) => l.id == linkId);
          if (index != -1) {
            _cachedLinks![index] = _cachedLinks![index].copyWith(
              isFavorite: isFavorite,
            );
          }
        }
        _cacheTimestamp = DateTime.now();
        _updateComputedLists();
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling favorites: $e');
      rethrow;
    }
  }

  /// Move links to lists
  Future<void> moveLinksToLists(List<String> linkIds, List<String> targetListIds) async {
    try {
      await StorageService.moveLinksToLists(linkIds, targetListIds);
      
      // Update cache
      if (_cachedLinks != null) {
        for (final linkId in linkIds) {
          final index = _cachedLinks!.indexWhere((l) => l.id == linkId);
          if (index != -1) {
            _cachedLinks![index] = _cachedLinks![index].copyWith(
              listIds: targetListIds,
            );
          }
        }
        _cacheTimestamp = DateTime.now();
        _updateComputedLists();
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error moving links: $e');
      rethrow;
    }
  }

  /// Record link view (for tracking)
  Future<void> recordLinkView(String linkId) async {
    try {
      await StorageService.recordLinkView(linkId);
      
      // Update cache
      if (_cachedLinks != null) {
        final index = _cachedLinks!.indexWhere((l) => l.id == linkId);
        if (index != -1) {
          final link = _cachedLinks![index];
          _cachedLinks![index] = link.copyWith(
            viewCount: link.viewCount + 1,
            lastViewedAt: DateTime.now(),
          );
          _cacheTimestamp = DateTime.now();
          _updateComputedLists();
        }
      }
      
      // Don't notify listeners for view tracking (performance)
    } catch (e) {
      debugPrint('Error recording link view: $e');
    }
  }

  /// Update link notes
  Future<void> updateLinkNotes(String linkId, String? notes) async {
    try {
      await StorageService.updateLinkNotes(linkId, notes);
      
      // Update cache
      if (_cachedLinks != null) {
        final index = _cachedLinks!.indexWhere((l) => l.id == linkId);
        if (index != -1) {
          _cachedLinks![index] = _cachedLinks![index].copyWith(notes: notes);
          _cacheTimestamp = DateTime.now();
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating link notes: $e');
      rethrow;
    }
  }

  /// Clear cache (force refresh on next load)
  void clearCache() {
    _cachedLinks = null;
    _cacheTimestamp = null;
    _favoriteLinks = null;
    _recentLinks = null;
    _suggestedLinks = null;
    _currentPage = 0;
    _hasMore = true;
  }

  /// Invalidate cache (mark as stale)
  void invalidateCache() {
    _cacheTimestamp = null;
  }
}

