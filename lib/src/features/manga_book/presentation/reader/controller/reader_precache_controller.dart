// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/local_downloads/local_downloads_repository.dart';
import '../../../domain/chapter_page/chapter_page_model.dart';
import '../services/reader_image_cache.dart';

part 'reader_precache_controller.g.dart';

/// Controller for managing image precaching in the reader
class ReaderPrecacheController {
  final LocalDownloadsRepository _downloadsRepository;
  final ReaderPrecacheService _precacheService;
  
  // Active precaching operations
  final Map<String, Completer<void>> _activePrecaching = {};
  
  ReaderPrecacheController(
    this._downloadsRepository,
    this._precacheService,
  );

  /// Precache the next and previous pages relative to current page
  Future<void> precacheAdjacentPages({
    required int mangaId,
    required int chapterId,
    required ChapterPagesDto chapterPages,
    required int currentPageIndex,
    int lookahead = 2, // Precache 2 pages ahead and behind
  }) async {
    final futures = <Future<void>>[];

    // Precache next pages
    for (int i = 1; i <= lookahead; i++) {
      final nextIndex = currentPageIndex + i;
      if (nextIndex < chapterPages.pages.length) {
        futures.add(_precachePage(mangaId, chapterId, nextIndex));
      }
    }

    // Precache previous pages
    for (int i = 1; i <= lookahead; i++) {
      final prevIndex = currentPageIndex - i;
      if (prevIndex >= 0) {
        futures.add(_precachePage(mangaId, chapterId, prevIndex));
      }
    }

    // Wait for all precaching operations (but don't block UI)
    unawaited(Future.wait(futures));
  }

  /// Precache a specific page
  Future<void> _precachePage(int mangaId, int chapterId, int pageIndex) async {
    final cacheKey = ReaderPrecacheService.generateCacheKey(mangaId, chapterId, pageIndex);
    
    // Avoid duplicate precaching operations
    if (_activePrecaching.containsKey(cacheKey)) {
      return _activePrecaching[cacheKey]!.future;
    }

    final completer = Completer<void>();
    _activePrecaching[cacheKey] = completer;

    try {
      // Check if already cached
      final cache = _precacheService;
      if (cache.isCached(cacheKey)) {
        completer.complete();
        return;
      }

      // Try to get local file
      final localFile = await _downloadsRepository.getLocalPageFile(
        mangaId,
        chapterId,
        pageIndex,
      );

      if (localFile != null && await localFile.exists()) {
        await _precacheService.precacheFromFile(localFile, cacheKey);
        if (kDebugMode) {
          print('ReaderPrecacheController: Precached page $pageIndex from local file');
        }
      } else {
        if (kDebugMode) {
          print('ReaderPrecacheController: Page $pageIndex not available locally, skipping precache');
        }
      }

      completer.complete();
    } catch (e) {
      if (kDebugMode) {
        print('ReaderPrecacheController: Failed to precache page $pageIndex: $e');
      }
      completer.completeError(e);
    } finally {
      _activePrecaching.remove(cacheKey);
    }
  }

  /// Warm decode the current page to ensure smooth display
  Future<void> warmDecodeCurrentPage({
    required int mangaId,
    required int chapterId,
    required int pageIndex,
  }) async {
    try {
      final cacheKey = ReaderPrecacheService.generateCacheKey(mangaId, chapterId, pageIndex);
      
      // Skip if already cached
      if (_precacheService.isCached(cacheKey)) {
        return;
      }

      final localFile = await _downloadsRepository.getLocalPageFile(
        mangaId,
        chapterId,
        pageIndex,
      );

      if (localFile != null && await localFile.exists()) {
        await _precacheService.precacheFromFile(localFile, cacheKey);
        if (kDebugMode) {
          print('ReaderPrecacheController: Warm decoded current page $pageIndex');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ReaderPrecacheController: Failed to warm decode page $pageIndex: $e');
      }
    }
  }

  /// Clear all active precaching operations
  void clearActivePrecaching() {
    for (final completer in _activePrecaching.values) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _activePrecaching.clear();
  }

  void dispose() {
    clearActivePrecaching();
  }
}

/// Provider for the reader precache controller
@riverpod
ReaderPrecacheController readerPrecacheController(ReaderPrecacheControllerRef ref) {
  final downloadsRepository = ref.watch(localDownloadsRepositoryProvider);
  final precacheService = ref.watch(readerPrecacheServiceProvider);
  
  final controller = ReaderPrecacheController(downloadsRepository, precacheService);
  
  ref.onDispose(() {
    controller.dispose();
  });
  
  return controller;
}
