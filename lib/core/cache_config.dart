import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CacheConfig {
  static const keyAudio = 'audioCache';
  static const keyImages = 'imageCache';

  /// Audio Cache Manager (Configured to approx 200MB via max objects limit)
  /// At an average of 2-3MB per compressed M4A/WebM stream, 100 objects is roughly 200MB-300MB.
  static final CacheManager audioCache = CacheManager(
    Config(
      keyAudio,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 100, // LRU eviction when limit reached
    ),
  );

  /// Image Cache Manager
  static final CacheManager imageCache = CacheManager(
    Config(
      keyImages,
      stalePeriod: const Duration(days: 15),
      maxNrOfCacheObjects: 500, 
    ),
  );
}
