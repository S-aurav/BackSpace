import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/apis.dart';
import '../models/gif_item.dart';

/// Abstract GIF repository interface decoupling UI from provider implementation
abstract class GifRepository {
  String get providerName;
  Future<List<GifItem>> fetchTrending({int page = 1, int limit = 50, bool forceRefresh = false});
  Future<List<GifItem>> searchGifs(String query, {int page = 1, int limit = 50, bool forceRefresh = false});
  Future<void> clearCache();
}

/// Cache entry model holding items and expiration timestamp
class _CacheEntry {
  final DateTime cachedAt;
  final List<GifItem> items;

  _CacheEntry({required this.cachedAt, required this.items});

  bool isExpired(Duration ttl) => DateTime.now().difference(cachedAt) > ttl;

  Map<String, dynamic> toJson() => {
        'cachedAt': cachedAt.millisecondsSinceEpoch,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory _CacheEntry.fromJson(Map<String, dynamic> json) {
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(json['cachedAt'] as int? ?? 0);
    final rawItems = json['items'] as List? ?? [];
    final items = rawItems
        .map((i) => GifItem.fromJson(i as Map<String, dynamic>))
        .where((i) => i.mediaUrl.isNotEmpty)
        .toList();
    return _CacheEntry(cachedAt: cachedAt, items: items);
  }
}

/// KLIPY Implementation of [GifRepository] with persistent multi-tier caching
class KlipyGifService implements GifRepository {
  static final KlipyGifService _instance = KlipyGifService._internal();
  factory KlipyGifService() => _instance;
  KlipyGifService._internal();

  @override
  String get providerName => 'KLIPY';

  // Cache TTL settings
  static const Duration _trendingTtl = Duration(hours: 6);
  static const Duration _searchTtl = Duration(hours: 24);
  static const String _prefPrefix = 'klipy_cache_';
  static const String _indexKey = 'klipy_cache_keys_index';
  static const int _maxCachedQueries = 50;

  // In-memory cache for instant zero-latency retrieval
  final Map<String, _CacheEntry> _memCache = {};

  @override
  Future<List<GifItem>> fetchTrending({
    int page = 1,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'trending_$page';

    // 1. Check in-memory / persistent cache if not forcing refresh
    if (!forceRefresh) {
      final cached = await _getFromCache(cacheKey, _trendingTtl);
      if (cached != null && cached.isNotEmpty) {
        debugPrint('[KLIPY Cache] HIT (trending) -> ${cached.length} items (0 API calls)');
        return cached;
      }
    }

    // 2. Fetch from KLIPY API
    final items = await _fetchFromKlipyApi(endpoint: 'trending', params: {
      'page': page.toString(),
      'per_page': limit.toString(),
    });

    // 3. Save to cache on success
    if (items.isNotEmpty) {
      await _saveToCache(cacheKey, items);
      return items;
    }

    // 4. Fallback to expired cache if available during offline / error
    final fallback = await _getFromCache(cacheKey, const Duration(days: 30));
    if (fallback != null && fallback.isNotEmpty) {
      debugPrint('[KLIPY Cache] Fallback hit for trending -> ${fallback.length} items');
      return fallback;
    }

    return items;
  }

  @override
  Future<List<GifItem>> searchGifs(
    String query, {
    int page = 1,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      return fetchTrending(page: page, limit: limit, forceRefresh: forceRefresh);
    }

    final cacheKey = 'search_${cleanQuery}_$page';

    // 1. Check in-memory / persistent cache if not forcing refresh
    if (!forceRefresh) {
      final cached = await _getFromCache(cacheKey, _searchTtl);
      if (cached != null && cached.isNotEmpty) {
        debugPrint('[KLIPY Cache] HIT ("$cleanQuery") -> ${cached.length} items (0 API calls)');
        return cached;
      }
    }

    // 2. Fetch from KLIPY API
    final items = await _fetchFromKlipyApi(endpoint: 'search', params: {
      'q': cleanQuery,
      'page': page.toString(),
      'per_page': limit.toString(),
    });

    // 3. Save to cache on success
    if (items.isNotEmpty) {
      await _saveToCache(cacheKey, items);
      return items;
    }

    // 4. Fallback to expired cache if available during offline / rate-limit
    final fallback = await _getFromCache(cacheKey, const Duration(days: 30));
    if (fallback != null && fallback.isNotEmpty) {
      debugPrint('[KLIPY Cache] Fallback hit for "$cleanQuery" -> ${fallback.length} items');
      return fallback;
    }

    return items;
  }

  /// Retrieve items from In-Memory or SharedPreferences persistent storage
  Future<List<GifItem>?> _getFromCache(String cacheKey, Duration ttl) async {
    // Check Tier 1: Memory
    final memEntry = _memCache[cacheKey];
    if (memEntry != null) {
      if (!memEntry.isExpired(ttl)) {
        return memEntry.items;
      }
    }

    // Check Tier 2: Persistent Disk Cache (SharedPreferences)
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString('$_prefPrefix$cacheKey');
      if (rawJson != null) {
        // Offload JSON decoding and object mapping to worker Isolate
        final entry = await Isolate.run(() {
          final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
          return _CacheEntry.fromJson(decoded);
        });

        // Put back into memory cache
        _memCache[cacheKey] = entry;

        if (!entry.isExpired(ttl)) {
          return entry.items;
        }
      }
    } catch (e) {
      debugPrint('[KLIPY Cache] Error reading cache for $cacheKey: $e');
    }

    return null;
  }

  /// Save items to In-Memory and SharedPreferences disk storage
  Future<void> _saveToCache(String cacheKey, List<GifItem> items) async {
    final entry = _CacheEntry(cachedAt: DateTime.now(), items: items);
    _memCache[cacheKey] = entry;

    // Asynchronously encode in worker Isolate & persist to SharedPreferences
    try {
      final encoded = await Isolate.run(() => jsonEncode(entry.toJson()));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefPrefix$cacheKey', encoded);

      // Manage index to evict oldest entries if too large
      final List<String> index = prefs.getStringList(_indexKey) ?? [];
      if (!index.contains(cacheKey)) {
        index.add(cacheKey);
      }
      while (index.length > _maxCachedQueries) {
        final evictedKey = index.removeAt(0);
        await prefs.remove('$_prefPrefix$evictedKey');
        _memCache.remove(evictedKey);
      }
      await prefs.setStringList(_indexKey, index);
    } catch (e) {
      debugPrint('[KLIPY Cache] Error writing cache for $cacheKey: $e');
    }
  }

  @override
  Future<void> clearCache() async {
    _memCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getStringList(_indexKey) ?? [];
      for (final key in index) {
        await prefs.remove('$_prefPrefix$key');
      }
      await prefs.remove(_indexKey);
      debugPrint('[KLIPY Cache] Cleared all cached GIFs');
    } catch (e) {
      debugPrint('[KLIPY Cache] Error clearing cache: $e');
    }
  }

  Future<List<GifItem>> _fetchFromKlipyApi({
    required String endpoint,
    required Map<String, String> params,
  }) async {
    final apiKey = await APIs.getKlipyApiKey();
    if (apiKey.isEmpty) {
      debugPrint('[KLIPY API] ⚠️ No API key found in Firestore config/services or --dart-define');
      return [];
    }
    final Uri uri = Uri.https('api.klipy.com', '/api/v1/$apiKey/gifs/$endpoint', params);
    debugPrint('[KLIPY API] → GET $uri (Network call)');

    try {
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'BackSpace/2.2.0',
      }).timeout(const Duration(seconds: 25));

      debugPrint('[KLIPY API] ← ${response.statusCode} (${response.body.length} bytes)');

      if (response.statusCode == 200) {
        // Offload heavy JSON parsing and model extraction to background worker Isolate
        final items = await Isolate.run(() => _parseKlipyJsonInWorker(response.body));
        debugPrint('[KLIPY API] (Worker Isolate) successfully parsed ${items.length} items');
        return items;
      } else {
        debugPrint('[KLIPY API] error ${response.statusCode}');
        return [];
      }
    } on SocketException catch (e) {
      debugPrint('[KLIPY API] SocketException: $e');
      return [];
    } on TimeoutException catch (e) {
      debugPrint('[KLIPY API] TimeoutException: $e');
      return [];
    } catch (e, st) {
      debugPrint('[KLIPY API] error: $e\n$st');
      return [];
    }
  }
}

/// Standalone top-level parser executing inside worker Isolate
List<GifItem> _parseKlipyJsonInWorker(String responseBody) {
  try {
    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;

    final outer = decoded['data'];
    List? rawList;
    if (outer is Map) {
      rawList = outer['data'] as List?;
    } else if (outer is List) {
      rawList = outer;
    }

    if (rawList == null || rawList.isEmpty) {
      return [];
    }

    final List<GifItem> items = [];

    for (final dynamic raw in rawList) {
      try {
        final item = raw as Map<String, dynamic>;
        final id = item['id']?.toString() ?? '';
        if (id.isEmpty) continue;

        final title = item['title']?.toString() ?? '';

        final fileObj = item['file'] as Map<String, dynamic>?;
        if (fileObj == null) continue;

        // SM rendition for grid preview
        final smObj = (fileObj['sm'] ?? fileObj['xs'] ?? fileObj['md']) as Map<String, dynamic>?;
        final smGif = smObj != null ? (smObj['gif'] as Map<String, dynamic>?) : null;
        final smWebp = smObj != null ? (smObj['webp'] as Map<String, dynamic>?) : null;
        final smMp4 = smObj != null ? (smObj['mp4'] as Map<String, dynamic>?) : null;
        final previewUrl = (smGif?['url'] ?? smWebp?['url'] ?? smMp4?['url'] ?? '') as String;

        // HD rendition for chat bubble
        final hdObj = (fileObj['hd'] ?? fileObj['md'] ?? fileObj['sm']) as Map<String, dynamic>?;
        final hdGif = hdObj != null ? (hdObj['gif'] as Map<String, dynamic>?) : null;
        final hdWebp = hdObj != null ? (hdObj['webp'] as Map<String, dynamic>?) : null;
        final mediaUrl = (hdGif?['url'] ?? hdWebp?['url'] ?? previewUrl) as String;

        // Dimensions & Aspect Ratio (Discord-style dynamic height)
        final num? rawW = smGif?['width'] ?? smWebp?['width'] ?? hdGif?['width'] ?? hdWebp?['width'];
        final num? rawH = smGif?['height'] ?? smWebp?['height'] ?? hdGif?['height'] ?? hdWebp?['height'];
        final double w = rawW?.toDouble() ?? 200.0;
        final double h = rawH?.toDouble() ?? 150.0;
        final double aspectRatio = (w > 0 && h > 0) ? (w / h) : 1.33;

        if (mediaUrl.isNotEmpty) {
          items.add(GifItem(
            id: id,
            provider: 'klipy',
            title: title,
            previewUrl: previewUrl.isNotEmpty ? previewUrl : mediaUrl,
            mediaUrl: mediaUrl,
            aspectRatio: aspectRatio,
          ));
        }
      } catch (_) {
        // Skip malformed item
      }
    }

    return items;
  } catch (_) {
    return [];
  }
}
