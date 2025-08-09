// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reader_image_cache.g.dart';

/// Enhanced LRU cache for decoded images in the reader
class ReaderImageCache {
  static const int _maxCacheSize = 20; // Keep 20 decoded images in memory
  static const int _maxSizeBytes = 100 * 1024 * 1024; // 100MB max
  
  final Map<String, _CachedImage> _cache = <String, _CachedImage>{};
  final List<String> _keys = <String>[];
  int _currentSizeBytes = 0;

  /// Get cached image if available
  ui.Image? getImage(String key) {
    final cached = _cache[key];
    if (cached != null) {
      // Move to end (most recently used)
      _keys.remove(key);
      _keys.add(key);
      return cached.image;
    }
    return null;
  }

  /// Cache a decoded image
  void putImage(String key, ui.Image image, int sizeBytes) {
    // Remove if already exists
    _removeKey(key);
    
    // Add new entry
    _cache[key] = _CachedImage(image, sizeBytes);
    _keys.add(key);
    _currentSizeBytes += sizeBytes;
    
    // Evict old entries if necessary
    _evictIfNeeded();
    
    if (kDebugMode) {
      print('ReaderImageCache: Cached $key (${sizeBytes ~/ 1024}KB), total: ${_currentSizeBytes ~/ 1024}KB, count: ${_cache.length}');
    }
  }

  /// Check if image is cached
  bool containsKey(String key) => _cache.containsKey(key);

  /// Clear all cached images
  void clear() {
    for (final cached in _cache.values) {
      cached.image.dispose();
    }
    _cache.clear();
    _keys.clear();
    _currentSizeBytes = 0;
  }

  /// Remove specific key
  void _removeKey(String key) {
    final cached = _cache.remove(key);
    if (cached != null) {
      _keys.remove(key);
      _currentSizeBytes -= cached.sizeBytes;
      cached.image.dispose();
    }
  }

  /// Evict least recently used entries
  void _evictIfNeeded() {
    while ((_cache.length > _maxCacheSize || _currentSizeBytes > _maxSizeBytes) && _keys.isNotEmpty) {
      final oldestKey = _keys.first;
      _removeKey(oldestKey);
      if (kDebugMode) {
        print('ReaderImageCache: Evicted $oldestKey');
      }
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'count': _cache.length,
      'sizeBytes': _currentSizeBytes,
      'sizeMB': _currentSizeBytes / (1024 * 1024),
      'maxCount': _maxCacheSize,
      'maxSizeMB': _maxSizeBytes / (1024 * 1024),
    };
  }
}

class _CachedImage {
  final ui.Image image;
  final int sizeBytes;

  _CachedImage(this.image, this.sizeBytes);
}

/// Provider for the global reader image cache
@riverpod
ReaderImageCache readerImageCache(ReaderImageCacheRef ref) {
  final cache = ReaderImageCache();
  
  // Clean up when provider is disposed
  ref.onDispose(() {
    cache.clear();
  });
  
  return cache;
}

/// Service for pre-caching and managing reader images
class ReaderPrecacheService {
  final ReaderImageCache _cache;
  
  ReaderPrecacheService(this._cache);

  /// Pre-decode an image from file
  Future<ui.Image?> precacheFromFile(File file, String cacheKey) async {
    try {
      if (_cache.containsKey(cacheKey)) {
        return _cache.getImage(cacheKey);
      }

      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      // Estimate size (width * height * 4 bytes per pixel for RGBA)
      final sizeBytes = image.width * image.height * 4;
      
      _cache.putImage(cacheKey, image, sizeBytes);
      return image;
    } catch (e) {
      if (kDebugMode) {
        print('ReaderPrecacheService: Failed to precache $cacheKey: $e');
      }
      return null;
    }
  }

  /// Pre-decode an image from network
  Future<ui.Image?> precacheFromBytes(Uint8List bytes, String cacheKey) async {
    try {
      if (_cache.containsKey(cacheKey)) {
        return _cache.getImage(cacheKey);
      }

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      // Estimate size
      final sizeBytes = image.width * image.height * 4;
      
      _cache.putImage(cacheKey, image, sizeBytes);
      return image;
    } catch (e) {
      if (kDebugMode) {
        print('ReaderPrecacheService: Failed to precache from bytes $cacheKey: $e');
      }
      return null;
    }
  }

  /// Check if an image is cached
  bool isCached(String key) {
    return _cache.containsKey(key);
  }

  /// Generate cache key for a page
  static String generateCacheKey(int mangaId, int chapterId, int pageIndex) {
    return 'manga_${mangaId}_chapter_${chapterId}_page_$pageIndex';
  }
}

/// Provider for the precache service
@riverpod
ReaderPrecacheService readerPrecacheService(ReaderPrecacheServiceRef ref) {
  final cache = ref.watch(readerImageCacheProvider);
  return ReaderPrecacheService(cache);
}
