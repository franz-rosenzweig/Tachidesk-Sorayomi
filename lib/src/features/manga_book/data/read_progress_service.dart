import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'offline_catalog_repository.dart';

part 'read_progress_service.g.dart';

/// Service for tracking and persisting read progress
class ReadProgressService {
  final OfflineCatalogRepository _catalogRepository;
  
  // Debounced updates
  Timer? _updateTimer;
  final Map<String, int> _pendingUpdates = {};

  ReadProgressService(this._catalogRepository);

  /// Update read progress for a chapter
  void updateProgress(int mangaId, int chapterId, int pageIndex) {
    final key = '${mangaId}_$chapterId';
    _pendingUpdates[key] = pageIndex;
    
    // Debounce updates to avoid excessive writes
    _updateTimer?.cancel();
    _updateTimer = Timer(const Duration(milliseconds: 1000), () {
      _flushPendingUpdates();
    });
  }

  /// Mark chapter as read (progress = last page)
  void markAsRead(int mangaId, int chapterId, int totalPages) {
    updateProgress(mangaId, chapterId, totalPages - 1);
  }

  /// Flush all pending updates
  Future<void> _flushPendingUpdates() async {
    if (_pendingUpdates.isEmpty) return;
    
    try {
      final catalog = await _catalogRepository.load();
      final updates = Map<String, int>.from(_pendingUpdates);
      _pendingUpdates.clear();
      
      for (final entry in updates.entries) {
        final parts = entry.key.split('_');
        if (parts.length == 2) {
          final mangaId = int.tryParse(parts[0]);
          final chapterId = int.tryParse(parts[1]);
          if (mangaId != null && chapterId != null) {
            await _catalogRepository.updateReadProgress(
              catalog,
              mangaId,
              chapterId,
              entry.value,
            );
          }
        }
      }
      
      if (kDebugMode) {
        print('ReadProgressService: Flushed ${updates.length} progress updates');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('ReadProgressService: Error flushing updates: $e');
      }
    }
  }

  /// Get read progress for a chapter
  Future<int> getProgress(int mangaId, int chapterId) async {
    try {
      final catalog = await _catalogRepository.load();
      final chapters = _catalogRepository.listChapters(catalog, mangaId);
      final chapter = chapters.firstWhere((c) => c.chapterId == chapterId);
      return chapter.readPage;
    } catch (e) {
      return 0; // Default to first page
    }
  }

  /// Dispose and cleanup
  void dispose() {
    _updateTimer?.cancel();
    if (_pendingUpdates.isNotEmpty) {
      // Synchronous final flush attempt
      _flushPendingUpdates();
    }
  }
}

@riverpod
ReadProgressService readProgressService(Ref ref) {
  final catalogRepo = ref.watch(offlineCatalogRepositoryProvider);
  final service = ReadProgressService(catalogRepo);
  
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
}
