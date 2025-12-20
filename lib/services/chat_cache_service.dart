import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:elysian/models/chat_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for caching chat data locally to reduce Firestore reads and improve performance
class ChatCacheService {
  static final ChatCacheService _instance = ChatCacheService._internal();
  factory ChatCacheService() => _instance;
  ChatCacheService._internal();

  static const String _conversationsCacheKey = 'chat_conversations_cache';
  static const String _messagesCachePrefix = 'chat_messages_cache_';
  static const String _cacheTimestampKey = 'chat_cache_timestamp';
  static const Duration _cacheExpiry = Duration(
    hours: 1,
  ); // Cache expires after 1 hour

  // In-memory cache for faster access
  final Map<String, List<DirectChatMessage>> _messageCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final int _maxCachedMessages = 50; // Limit cached messages per conversation

  /// Cache conversations list
  Future<void> cacheConversations(List<ChatConversation> conversations) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = conversations.map((c) => c.toJson()).toList();
      await prefs.setString(_conversationsCacheKey, jsonEncode(json));
      await prefs.setString(
        _cacheTimestampKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('Error caching conversations: $e');
    }
  }

  /// Get cached conversations
  Future<List<ChatConversation>?> getCachedConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampStr = prefs.getString(_cacheTimestampKey);
      if (timestampStr == null) return null;

      final timestamp = DateTime.parse(timestampStr);
      if (DateTime.now().difference(timestamp) > _cacheExpiry) {
        // Cache expired
        await prefs.remove(_conversationsCacheKey);
        await prefs.remove(_cacheTimestampKey);
        return null;
      }

      final jsonStr = prefs.getString(_conversationsCacheKey);
      if (jsonStr == null) return null;

      final json = jsonDecode(jsonStr) as List<dynamic>;
      return json
          .map((j) => ChatConversation.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting cached conversations: $e');
      return null;
    }
  }

  /// Cache messages for a conversation
  Future<void> cacheMessages(
    String conversationId,
    List<DirectChatMessage> messages,
  ) async {
    try {
      // Limit cached messages to reduce memory usage
      final messagesToCache = messages.length > _maxCachedMessages
          ? messages.sublist(messages.length - _maxCachedMessages)
          : messages;

      // Update in-memory cache
      _messageCache[conversationId] = messagesToCache;
      _cacheTimestamps[conversationId] = DateTime.now();

      // Persist to disk (only last 20 messages to save space)
      final prefs = await SharedPreferences.getInstance();
      final messagesToPersist = messagesToCache.length > 20
          ? messagesToCache.sublist(messagesToCache.length - 20)
          : messagesToCache;
      final json = messagesToPersist.map((m) => m.toJson()).toList();
      await prefs.setString(
        '$_messagesCachePrefix$conversationId',
        jsonEncode(json),
      );
    } catch (e) {
      debugPrint('Error caching messages: $e');
    }
  }

  /// Get cached messages for a conversation
  List<DirectChatMessage>? getCachedMessages(String conversationId) {
    // Check in-memory cache first
    if (_messageCache.containsKey(conversationId)) {
      final timestamp = _cacheTimestamps[conversationId];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _messageCache[conversationId];
      } else {
        // Cache expired, remove it
        _messageCache.remove(conversationId);
        _cacheTimestamps.remove(conversationId);
      }
    }
    return null;
  }

  /// Get persisted messages (for offline support)
  Future<List<DirectChatMessage>?> getPersistedMessages(
    String conversationId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('$_messagesCachePrefix$conversationId');
      if (jsonStr == null) return null;

      final json = jsonDecode(jsonStr) as List<dynamic>;
      return json
          .map((j) => DirectChatMessage.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting persisted messages: $e');
      return null;
    }
  }

  /// Clear cache for a conversation
  Future<void> clearConversationCache(String conversationId) async {
    _messageCache.remove(conversationId);
    _cacheTimestamps.remove(conversationId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_messagesCachePrefix$conversationId');
    } catch (e) {
      debugPrint('Error clearing conversation cache: $e');
    }
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    _messageCache.clear();
    _cacheTimestamps.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_conversationsCacheKey);
      await prefs.remove(_cacheTimestampKey);
      // Clear all message caches
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_messagesCachePrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('Error clearing all cache: $e');
    }
  }

  /// Clean up old cache entries (memory management)
  void cleanupOldCache() {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _cacheExpiry) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _messageCache.remove(key);
      _cacheTimestamps.remove(key);
    }

    // Limit total cache size
    if (_messageCache.length > 10) {
      // Keep only the 10 most recently accessed conversations
      final sortedEntries = _cacheTimestamps.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final keysToKeep = sortedEntries.take(10).map((e) => e.key).toSet();
      final keysToRemove = _messageCache.keys
          .where((k) => !keysToKeep.contains(k))
          .toList();

      for (final key in keysToRemove) {
        _messageCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }
  }
}
