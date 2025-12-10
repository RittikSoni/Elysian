import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elysian/models/models.dart';

class StorageService {
  static const String _savedLinksKey = 'saved_links';
  static const String _userListsKey = 'user_lists';
  static const String _defaultListId = 'my_list';
  static const String _playerPreferenceKey = 'player_preference'; // 'inbuilt' or 'external'

  // Saved Links
  static Future<List<SavedLink>> getSavedLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final linksJson = prefs.getStringList(_savedLinksKey) ?? [];
    return linksJson
        .map((json) => SavedLink.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList();
  }

  static Future<List<SavedLink>> getSavedLinksByList(String listId) async {
    final allLinks = await getSavedLinks();
    return allLinks.where((link) => link.listIds.contains(listId)).toList();
  }

  static Future<void> saveLink(SavedLink link) async {
    final prefs = await SharedPreferences.getInstance();
    final links = await getSavedLinks();
    
    // Check if link already exists (by ID)
    final existingIndex = links.indexWhere((l) => l.id == link.id);
    if (existingIndex != -1) {
      // Update existing link
      links[existingIndex] = link;
    } else {
      // Check if same URL exists in any of the same lists
      final duplicateExists = links.any((l) => 
        l.url == link.url && 
        l.listIds.any((id) => link.listIds.contains(id))
      );
      if (!duplicateExists) {
        links.add(link);
      } else {
        return; // Already saved in one of these lists
      }
    }

    await _updateSavedLinks(prefs, links);
    // Update counts for all lists this link belongs to
    for (final listId in link.listIds) {
      await _updateListCount(listId);
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

  static Future<void> _updateSavedLinks(SharedPreferences prefs, List<SavedLink> links) async {
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
    
    final customLists = listsJson
        .map((json) => UserList.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList();

    // Update item counts
    final allLinks = await getSavedLinks();
    
    // Update custom lists with correct item counts
    final updatedCustomLists = customLists.map((list) {
      final count = allLinks.where((link) => link.listIds.contains(list.id)).length;
      return list.copyWith(itemCount: count);
    }).toList();

    final defaultCount = allLinks.where((link) => link.listIds.contains(_defaultListId)).length;
    final updatedDefault = defaultList.copyWith(itemCount: defaultCount);

    return [updatedDefault, ...updatedCustomLists];
  }

  static Future<UserList> createUserList(String name, {String? description}) async {
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
    
    final listsJson = customLists.map((list) => jsonEncode(list.toJson())).toList();
    await prefs.setStringList(_userListsKey, listsJson);

    return newList;
  }

  static Future<void> deleteUserList(String listId) async {
    if (listId == _defaultListId) {
      throw Exception('Cannot delete the default list');
    }

    final prefs = await SharedPreferences.getInstance();
    final lists = await getUserLists();
    final customLists = lists.where((l) => l.id != listId && l.id != _defaultListId).toList();
    
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

    final listsJson = customLists.map((list) => jsonEncode(list.toJson())).toList();
    await prefs.setStringList(_userListsKey, listsJson);
  }

  static Future<void> _updateListCount(String listId, {bool decrement = false}) async {
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

  static String get defaultListId => _defaultListId;
}

