import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Global cache manager for chat images with persistent disk caching
class ChatImageCacheManager {
  static final CacheManager instance = DefaultCacheManager();
}

/// Global cache manager for profile/avatar images with persistent disk caching
class AvatarCacheManager {
  static final CacheManager instance = DefaultCacheManager();
}
