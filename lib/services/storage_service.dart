import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elysian/models/models.dart';

class StorageService {
  static const String _savedLinksKey = 'saved_links';
  static const String _userListsKey = 'user_lists';
  static const String _defaultListId = 'my_list';
  static const String _playerPreferenceKey =
      'player_preference'; // 'inbuilt' or 'external'
  static const String _recentSearchesKey = 'recent_searches';
  static const String _themePreferenceKey =
      'theme_preference'; // 'dark' or 'light'
  static const String _homeScreenLayoutKey = 'home_screen_layout';
  static const String _hasCompletedOnboardingKey = 'has_completed_onboarding';
  static const String _userEmailKey = 'user_email';
  static const String _userDisplayNameKey = 'user_display_name';
  static const String _userSignedOutKey = 'user_signed_out';
  static const int _maxRecentSearches = 10;

  // Saved Links
  static Future<List<SavedLink>> getSavedLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final linksJson = prefs.getStringList(_savedLinksKey) ?? [];
    final List<SavedLink> links = [];

    // Parse links with error handling to skip corrupted entries
    for (final json in linksJson) {
      try {
        final link = SavedLink.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
        links.add(link);
      } catch (e) {
        // Skip corrupted entries - log error but continue
        debugPrint('Error parsing saved link: $e');
      }
    }

    return links;
  }

  static Future<List<SavedLink>> getSavedLinksByList(String listId) async {
    final allLinks = await getSavedLinks();
    return allLinks.where((link) => link.listIds.contains(listId)).toList();
  }

  static Future<void> saveLink(SavedLink link) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final links = await getSavedLinks();

      // Validate listIds exist (except default list)
      final allLists = await getUserLists();
      final validListIds = allLists.map((l) => l.id).toSet();
      final validatedListIds = link.listIds
          .where((id) => validListIds.contains(id))
          .toList();

      // If no valid list IDs, add to default list
      if (validatedListIds.isEmpty) {
        validatedListIds.add(_defaultListId);
      }

      final linkWithValidLists = link.copyWith(listIds: validatedListIds);

      // Check if link already exists (by ID)
      final existingIndex = links.indexWhere(
        (l) => l.id == linkWithValidLists.id,
      );
      if (existingIndex != -1) {
        // Update existing link
        links[existingIndex] = linkWithValidLists;
      } else {
        // Check if same URL exists in any of the same lists
        final duplicateExists = links.any(
          (l) =>
              l.url == linkWithValidLists.url &&
              l.listIds.any((id) => linkWithValidLists.listIds.contains(id)),
        );
        if (!duplicateExists) {
          links.add(linkWithValidLists);
        } else {
          return; // Already saved in one of these lists
        }
      }

      await _updateSavedLinks(prefs, links);
      // Update counts for all lists this link belongs to
      for (final listId in linkWithValidLists.listIds) {
        await _updateListCount(listId);
      }
    } catch (e) {
      debugPrint('Error saving link: $e');
      rethrow; // Re-throw to let caller handle it
    }
  }

  static Future<void> deleteLink(String linkId) async {
    final prefs = await SharedPreferences.getInstance();
    final links = await getSavedLinks();
    final link = links.firstWhere((l) => l.id == linkId);

    links.removeWhere((l) => l.id == linkId);
    await _updateSavedLinks(prefs, links);
    // Update counts for all lists this link belonged to
    for (final listId in link.listIds) {
      await _updateListCount(listId, decrement: true);
    }
  }

  static Future<void> _updateSavedLinks(
    SharedPreferences prefs,
    List<SavedLink> links,
  ) async {
    final linksJson = links.map((link) => jsonEncode(link.toJson())).toList();
    await prefs.setStringList(_savedLinksKey, linksJson);
  }

  // User Lists
  static Future<List<UserList>> getUserLists() async {
    final prefs = await SharedPreferences.getInstance();
    final listsJson = prefs.getStringList(_userListsKey) ?? [];

    // Always include default "My List"
    final defaultList = UserList(
      id: _defaultListId,
      name: 'My List',
      createdAt: DateTime.now(),
    );

    // Parse lists with error handling to skip corrupted entries
    final List<UserList> customLists = [];
    for (final json in listsJson) {
      try {
        final list = UserList.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
        customLists.add(list);
      } catch (e) {
        // Skip corrupted entries - log error but continue
        debugPrint('Error parsing user list: $e');
      }
    }

    // Update item counts
    final allLinks = await getSavedLinks();

    // Update custom lists with correct item counts
    final updatedCustomLists = customLists.map((list) {
      final count = allLinks
          .where((link) => link.listIds.contains(list.id))
          .length;
      return list.copyWith(itemCount: count);
    }).toList();

    final defaultCount = allLinks
        .where((link) => link.listIds.contains(_defaultListId))
        .length;
    final updatedDefault = defaultList.copyWith(itemCount: defaultCount);

    return [updatedDefault, ...updatedCustomLists];
  }

  static Future<UserList> createUserList(
    String name, {
    String? description,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lists = await getUserLists();

    // Check if list with same name exists
    if (lists.any((l) => l.name.toLowerCase() == name.toLowerCase())) {
      throw Exception('A list with this name already exists');
    }

    final newList = UserList(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      createdAt: DateTime.now(),
    );

    final customLists = lists.where((l) => l.id != _defaultListId).toList();
    customLists.add(newList);

    final listsJson = customLists
        .map((list) => jsonEncode(list.toJson()))
        .toList();
    await prefs.setStringList(_userListsKey, listsJson);

    return newList;
  }

  static Future<void> deleteUserList(String listId) async {
    if (listId == _defaultListId) {
      throw Exception('Cannot delete the default list');
    }

    final prefs = await SharedPreferences.getInstance();
    final lists = await getUserLists();
    final customLists = lists
        .where((l) => l.id != listId && l.id != _defaultListId)
        .toList();

    // Move all links from deleted list to default list
    final allLinks = await getSavedLinks();
    for (var link in allLinks) {
      if (link.listIds.contains(listId)) {
        // Remove the deleted listId and add default if not already present
        final updatedListIds = List<String>.from(link.listIds)..remove(listId);
        if (!updatedListIds.contains(_defaultListId)) {
          updatedListIds.add(_defaultListId);
        }

        final updatedLink = SavedLink(
          id: link.id,
          url: link.url,
          title: link.title,
          thumbnailUrl: link.thumbnailUrl,
          description: link.description,
          type: link.type,
          listIds: updatedListIds,
          savedAt: link.savedAt,
        );
        await deleteLink(link.id);
        await saveLink(updatedLink);
      }
    }

    final listsJson = customLists
        .map((list) => jsonEncode(list.toJson()))
        .toList();
    await prefs.setStringList(_userListsKey, listsJson);
  }

  static Future<void> _updateListCount(
    String listId, {
    bool decrement = false,
  }) async {
    // List count is calculated dynamically, so we don't need to update it here
    // This method is kept for future use if needed
  }

  // Player Preference
  static Future<bool> isInbuiltPlayer() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to inbuilt player (true)
    return prefs.getBool(_playerPreferenceKey) ?? true;
  }

  static Future<void> setPlayerPreference(bool useInbuilt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_playerPreferenceKey, useInbuilt);
  }

  // Theme Preference
  static const String _themeTypeKey =
      'theme_type'; // 'light', 'dark', 'liquidGlass'

  static Future<String> getThemeType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeTypeKey) ?? 'dark'; // Default to dark
  }

  static Future<void> setThemeType(String themeType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeTypeKey, themeType);
  }

  // Legacy support - keep for backward compatibility
  static Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themePreferenceKey) ?? true; // Default to dark mode
  }

  static Future<void> setThemePreference(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themePreferenceKey, isDark);
  }

  static String get defaultListId => _defaultListId;

  // Favorites
  static Future<List<SavedLink>> getFavoriteLinks() async {
    final allLinks = await getSavedLinks();
    return allLinks.where((link) => link.isFavorite).toList();
  }

  static Future<void> toggleFavorite(String linkId) async {
    final prefs = await SharedPreferences.getInstance();
    final links = await getSavedLinks();
    final index = links.indexWhere((l) => l.id == linkId);
    if (index != -1) {
      links[index] = links[index].copyWith(
        isFavorite: !links[index].isFavorite,
      );
      await _updateSavedLinks(prefs, links);
    }
  }

  // Watch History / Recent Activity
  static Future<List<SavedLink>> getRecentlyViewedLinks({
    int limit = 10,
  }) async {
    final allLinks = await getSavedLinks();
    final viewedLinks =
        allLinks.where((link) => link.lastViewedAt != null).toList()..sort(
          (a, b) => (b.lastViewedAt ?? DateTime(1970)).compareTo(
            a.lastViewedAt ?? DateTime(1970),
          ),
        );
    return viewedLinks.take(limit).toList();
  }

  static Future<void> recordLinkView(String linkId) async {
    final prefs = await SharedPreferences.getInstance();
    final links = await getSavedLinks();
    final index = links.indexWhere((l) => l.id == linkId);
    if (index != -1) {
      final link = links[index];
      links[index] = link.copyWith(
        lastViewedAt: DateTime.now(),
        viewCount: link.viewCount + 1,
      );
      await _updateSavedLinks(prefs, links);
    }
  }

  // Notes
  static Future<void> updateLinkNotes(String linkId, String? notes) async {
    final prefs = await SharedPreferences.getInstance();
    final links = await getSavedLinks();
    final index = links.indexWhere((l) => l.id == linkId);
    if (index != -1) {
      links[index] = links[index].copyWith(notes: notes);
      await _updateSavedLinks(prefs, links);
    }
  }

  // Bulk Operations
  static Future<void> deleteLinks(List<String> linkIds) async {
    final prefs = await SharedPreferences.getInstance();
    final links = await getSavedLinks();
    final linksToDelete = links.where((l) => linkIds.contains(l.id)).toList();

    // Update list counts
    for (final link in linksToDelete) {
      for (final listId in link.listIds) {
        await _updateListCount(listId, decrement: true);
      }
    }

    links.removeWhere((l) => linkIds.contains(l.id));
    await _updateSavedLinks(prefs, links);
  }

  static Future<void> moveLinksToLists(
    List<String> linkIds,
    List<String> targetListIds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final links = await getSavedLinks();

    for (final linkId in linkIds) {
      final index = links.indexWhere((l) => l.id == linkId);
      if (index != -1) {
        links[index] = links[index].copyWith(listIds: targetListIds);
      }
    }

    await _updateSavedLinks(prefs, links);
    // Update counts for all affected lists
    for (final listId in targetListIds) {
      await _updateListCount(listId);
    }
  }

  static Future<void> toggleFavoritesForLinks(
    List<String> linkIds,
    bool isFavorite,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final links = await getSavedLinks();

    for (final linkId in linkIds) {
      final index = links.indexWhere((l) => l.id == linkId);
      if (index != -1) {
        links[index] = links[index].copyWith(isFavorite: isFavorite);
      }
    }

    await _updateSavedLinks(prefs, links);
  }

  // Duplicate Detection
  static Future<List<SavedLink>> findDuplicates(String url) async {
    final allLinks = await getSavedLinks();
    return allLinks.where((link) => link.url == url).toList();
  }

  // Export/Import
  static Future<String> exportData() async {
    final links = await getSavedLinks();
    final lists = await getUserLists();
    final data = {
      'links': links.map((l) => l.toJson()).toList(),
      'lists': lists.map((l) => l.toJson()).toList(),
      'exportDate': DateTime.now().toIso8601String(),
    };
    return jsonEncode(data);
  }

  static Future<void> importData(String jsonData) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonDecode(jsonData) as Map<String, dynamic>;

    // Import lists
    if (data['lists'] != null) {
      final importedLists = (data['lists'] as List)
          .map((json) => UserList.fromJson(json as Map<String, dynamic>))
          .toList();

      // Filter out default list and merge with existing
      final customLists = importedLists
          .where((l) => l.id != _defaultListId)
          .toList();
      final listsJson = customLists
          .map((list) => jsonEncode(list.toJson()))
          .toList();
      await prefs.setStringList(_userListsKey, listsJson);
    }

    // Import links
    if (data['links'] != null) {
      final importedLinks = (data['links'] as List)
          .map((json) => SavedLink.fromJson(json as Map<String, dynamic>))
          .toList();

      // Merge with existing links (avoid duplicates by URL)
      final existingLinks = await getSavedLinks();
      final existingUrls = existingLinks.map((l) => l.url).toSet();

      final newLinks = importedLinks
          .where((l) => !existingUrls.contains(l.url))
          .toList();
      final allLinks = [...existingLinks, ...newLinks];

      await _updateSavedLinks(prefs, allLinks);
    }
  }

  /// Export a single list with its links in a shareable format
  static Future<String> exportListForSharing(String listId) async {
    final list = (await getUserLists()).firstWhere(
      (l) => l.id == listId,
      orElse: () => throw Exception('List not found'),
    );

    final links = await getSavedLinksByList(listId);

    final shareData = {
      'type': 'elysian_list',
      'version': '1.0',
      'list': {
        'name': list.name,
        'description': list.description,
        'itemCount': links.length,
      },
      'links': links
          .map(
            (l) => {
              'url': l.url,
              'title': l.title,
              'description': l.description,
              'type': l.type.toString(),
              'thumbnailUrl': l.thumbnailUrl,
              'duration': l.duration,
            },
          )
          .toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };

    return jsonEncode(shareData);
  }

  /// Import a shared list
  static Future<UserList> importSharedList(String jsonData) async {
    final data = jsonDecode(jsonData) as Map<String, dynamic>;

    // Validate format
    if (data['type'] != 'elysian_list') {
      throw Exception('Invalid list format');
    }

    final listData = data['list'] as Map<String, dynamic>;
    final linksData = data['links'] as List;

    // Check if list with same name exists
    final existingLists = await getUserLists();
    final listName = listData['name'] as String;
    var finalListName = listName;
    var counter = 1;

    while (existingLists.any(
      (l) => l.name.toLowerCase() == finalListName.toLowerCase(),
    )) {
      finalListName = '$listName ($counter)';
      counter++;
    }

    // Create new list
    final newList = await createUserList(
      finalListName,
      description: listData['description'] as String?,
    );

    // Import links
    final existingLinks = await getSavedLinks();
    final existingUrls = existingLinks.map((l) => l.url).toSet();

    for (final linkData in linksData) {
      final url = linkData['url'] as String;

      // Skip if link already exists
      if (existingUrls.contains(url)) {
        // Add to this list if not already in it
        final existingLink = existingLinks.firstWhere((l) => l.url == url);
        if (!existingLink.listIds.contains(newList.id)) {
          final updatedLink = SavedLink(
            id: existingLink.id,
            url: existingLink.url,
            title: existingLink.title,
            thumbnailUrl: existingLink.thumbnailUrl,
            customThumbnailPath: existingLink.customThumbnailPath,
            description: existingLink.description,
            type: existingLink.type,
            listIds: [...existingLink.listIds, newList.id],
            savedAt: existingLink.savedAt,
            isFavorite: existingLink.isFavorite,
            notes: existingLink.notes,
            lastViewedAt: existingLink.lastViewedAt,
            viewCount: existingLink.viewCount,
            duration: existingLink.duration,
          );
          await saveLink(updatedLink);
        }
        continue;
      }

      // Create new link
      final linkType = LinkType.values.firstWhere(
        (t) => t.toString() == linkData['type'],
        orElse: () => LinkType.unknown,
      );

      final newLink = SavedLink(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: url,
        title: linkData['title'] as String? ?? 'Untitled',
        thumbnailUrl: linkData['thumbnailUrl'] as String?,
        description: linkData['description'] as String?,
        type: linkType,
        listIds: [newList.id],
        savedAt: DateTime.now(),
        duration: linkData['duration'] as String?,
      );

      await saveLink(newLink);
    }

    return newList;
  }

  // Statistics
  static Future<Map<String, dynamic>> getStatistics() async {
    final allLinks = await getSavedLinks();
    final lists = await getUserLists();

    // Count by type
    final typeCounts = <LinkType, int>{};
    for (final link in allLinks) {
      typeCounts[link.type] = (typeCounts[link.type] ?? 0) + 1;
    }

    // Most viewed
    final mostViewed = allLinks.toList()
      ..sort((a, b) => b.viewCount.compareTo(a.viewCount));

    // Recent activity
    final recentlyViewed =
        allLinks.where((l) => l.lastViewedAt != null).toList()..sort(
          (a, b) => (b.lastViewedAt ?? DateTime(1970)).compareTo(
            a.lastViewedAt ?? DateTime(1970),
          ),
        );

    return {
      'totalLinks': allLinks.length,
      'totalLists': lists.length,
      'favoriteLinks': allLinks.where((l) => l.isFavorite).length,
      'typeCounts': typeCounts.map((k, v) => MapEntry(k.toString(), v)),
      'mostViewed': mostViewed.take(5).map((l) => l.toJson()).toList(),
      'recentlyViewed': recentlyViewed.take(5).map((l) => l.toJson()).toList(),
      'totalViews': allLinks.fold(0, (sum, link) => sum + link.viewCount),
    };
  }

  // Recent Searches
  static Future<List<String>> getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentSearchesKey) ?? [];
  }

  static Future<void> addRecentSearch(String query) async {
    if (query.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final searches = await getRecentSearches();

    // Remove if already exists
    searches.remove(query.trim());

    // Add to beginning
    searches.insert(0, query.trim());

    // Keep only max recent searches
    if (searches.length > _maxRecentSearches) {
      searches.removeRange(_maxRecentSearches, searches.length);
    }

    await prefs.setStringList(_recentSearchesKey, searches);
  }

  static Future<void> clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }

  // Smart Suggestions
  static Future<List<SavedLink>> getSuggestedLinks({int limit = 5}) async {
    final allLinks = await getSavedLinks();

    // Get most viewed links that user hasn't viewed recently
    final viewedLinks = allLinks.where((link) => link.viewCount > 0).toList()
      ..sort((a, b) => b.viewCount.compareTo(a.viewCount));

    // Get links similar to recently viewed (by type)
    final recentLinks = await getRecentlyViewedLinks(limit: 5);
    if (recentLinks.isEmpty) {
      return viewedLinks.take(limit).toList();
    }

    // Find links of same types as recently viewed
    final recentTypes = recentLinks.map((l) => l.type).toSet();
    final suggested = allLinks
        .where(
          (link) =>
              recentTypes.contains(link.type) &&
              !recentLinks.any((r) => r.id == link.id),
        )
        .toList();

    // Combine with most viewed
    final combined = [...suggested, ...viewedLinks];
    final unique = <String, SavedLink>{};
    for (final link in combined) {
      if (!unique.containsKey(link.id)) {
        unique[link.id] = link;
      }
    }

    return unique.values.take(limit).toList();
  }

  // Home Screen Layout
  static Future<void> saveHomeScreenLayout(
    List<HomeScreenSection> sections,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final sectionsJson = sections.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_homeScreenLayoutKey, sectionsJson);
  }

  static Future<List<HomeScreenSection>> getHomeScreenLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final sectionsJson = prefs.getStringList(_homeScreenLayoutKey);

    if (sectionsJson == null || sectionsJson.isEmpty) {
      // Return default layout
      return HomeScreenSection.getDefaultSections();
    }

    try {
      return sectionsJson
          .map(
            (json) => HomeScreenSection.fromJson(
              jsonDecode(json) as Map<String, dynamic>,
            ),
          )
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    } catch (e) {
      // If parsing fails, return default layout
      return HomeScreenSection.getDefaultSections();
    }
  }

  // Reset/Delete All Data
  static Future<void> resetAllData() async {
    final prefs = await SharedPreferences.getInstance();

    // Clear all app data
    await prefs.remove(_savedLinksKey);
    await prefs.remove(_userListsKey);
    await prefs.remove(_recentSearchesKey);
    await prefs.remove(_homeScreenLayoutKey);

    // Clear user authentication data
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userDisplayNameKey);
    await prefs.remove(_userSignedOutKey);

    // Note: We keep theme and player preferences as they are user settings
    // If you want to reset everything including settings, uncomment below:
    // await prefs.remove(_themePreferenceKey);
    // await prefs.remove(_playerPreferenceKey);

    // Clear all keys (nuclear option - removes everything)
    // await prefs.clear();
  }

  // Onboarding
  static Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasCompletedOnboardingKey) ?? false;
  }

  static Future<void> setHasCompletedOnboarding(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasCompletedOnboardingKey, completed);
  }

  // Chat User Email
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  static Future<void> setUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      // Remove the key if email is empty (sign-out)
      await prefs.remove(_userEmailKey);
    } else {
      await prefs.setString(_userEmailKey, trimmedEmail.toLowerCase());
    }
  }

  static Future<String?> getUserDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userDisplayNameKey);
  }

  static Future<void> setUserDisplayName(String displayName) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      // Remove the key if display name is empty (sign-out)
      await prefs.remove(_userDisplayNameKey);
    } else {
      await prefs.setString(_userDisplayNameKey, trimmedName);
    }
  }

  // User Sign-Out State (to prevent auto-restore after explicit sign-out)
  static Future<bool> getUserSignedOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_userSignedOutKey) ?? false;
  }

  static Future<void> setUserSignedOut(bool signedOut) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_userSignedOutKey, signedOut);
  }
}
