// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'chapter_validator.dart';
import 'local_download_queue.dart';
import 'local_downloads_repository.dart';

part 'chapter_download_status_provider.g.dart';

/// Provider for chapter download status with integrity checking
@riverpod
Future<ChapterDownloadStatus> chapterDownloadStatus(
  Ref ref,
  int mangaId,
  int chapterId,
) async {
  final repository = ref.read(localDownloadsRepositoryProvider);
  
  try {
    // Check if chapter is downloaded
    final isDownloaded = await repository.isChapterDownloaded(mangaId, chapterId);
    
    if (!isDownloaded) {
      // Check if it's queued for download
      final queueState = ref.read(localDownloadQueueProvider);
      final isQueued = queueState.tasks.any((task) => 
          task.mangaId == mangaId && task.chapterId == chapterId);
      
      if (isQueued) {
        return ChapterDownloadStatus.queued;
      }
      
      return ChapterDownloadStatus.notDownloaded;
    }

    // Validate integrity if downloaded
    final validationResult = await ChapterValidator.validateChapter(
      repository, 
      mangaId, 
      chapterId,
    );

    switch (validationResult) {
      case ValidationResult.valid:
        return ChapterDownloadStatus.downloaded;
      
      case ValidationResult.missingFiles:
        return ChapterDownloadStatus.partiallyCorrupted;
      
      case ValidationResult.corruptedFiles:
      case ValidationResult.sizeInconsistency:
      case ValidationResult.invalidImageFormat:
      case ValidationResult.checksumMismatch:
        return ChapterDownloadStatus.fullyCorrupted;
      
      case ValidationResult.manifestCorrupted:
        return ChapterDownloadStatus.fullyCorrupted;
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error checking chapter download status: $e');
    }
    return ChapterDownloadStatus.error;
  }
}

/// Provider for chapter download progress with validation details
@riverpod
Future<ChapterDownloadProgress> chapterDownloadProgress(
  Ref ref,
  int mangaId,
  int chapterId,
) async {
  final status = await ref.watch(chapterDownloadStatusProvider(mangaId, chapterId).future);
  final repository = ref.read(localDownloadsRepositoryProvider);
  
  try {
    final manifest = await repository.getManifest(mangaId, chapterId);
    final totalPages = manifest?.pageCount ?? 0;
    
    List<int>? corruptedIndices;
    ValidationResult? validationResult;
    
    if (status.isCorrupted) {
      corruptedIndices = await ChapterValidator.getCorruptedPageIndices(
        repository, 
        mangaId, 
        chapterId,
      );
      
      validationResult = await ChapterValidator.validateChapter(
        repository, 
        mangaId, 
        chapterId,
      );
    }

    final downloadedPages = totalPages - (corruptedIndices?.length ?? 0);
    
    return ChapterDownloadProgress(
      downloadedPages: downloadedPages,
      totalPages: totalPages,
      status: status,
      corruptedPageIndices: corruptedIndices,
      validationResult: validationResult,
    );
  } catch (e) {
    if (kDebugMode) {
      print('Error getting chapter download progress: $e');
    }
    
    return ChapterDownloadProgress(
      downloadedPages: 0,
      totalPages: 0,
      status: ChapterDownloadStatus.error,
      errorMessage: e.toString(),
    );
  }
}

/// Provider that checks if a chapter needs repair
@riverpod
Future<bool> chapterNeedsRepair(
  Ref ref,
  int mangaId,
  int chapterId,
) async {
  final status = await ref.watch(chapterDownloadStatusProvider(mangaId, chapterId).future);
  return status.isCorrupted;
}

/// Provider for validation results
@riverpod
Future<ValidationResult> chapterValidationResult(
  Ref ref,
  int mangaId,
  int chapterId,
) async {
  final repository = ref.read(localDownloadsRepositoryProvider);
  return await ChapterValidator.validateChapter(repository, mangaId, chapterId);
}

/// Background validation service for periodic integrity checks
@riverpod
class BackgroundValidator extends _$BackgroundValidator {
  @override
  Future<void> build() async {
    // Start background validation for recently accessed chapters
    _startBackgroundValidation();
  }

  Future<void> _startBackgroundValidation() async {
    try {
      final repository = ref.read(localDownloadsRepositoryProvider);
      final downloads = await repository.listDownloads();
      
      // Validate chapters that haven't been checked in the last 7 days
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      for (final manifest in downloads) {
        if (manifest.lastValidated == null || 
            manifest.lastValidated!.isBefore(oneWeekAgo)) {
          
          // Validate in background without blocking UI
          _validateChapterInBackground(repository, manifest.mangaId, manifest.chapterId);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Background validation error: $e');
      }
    }
  }

  Future<void> _validateChapterInBackground(
    LocalDownloadsRepository repository,
    int mangaId,
    int chapterId,
  ) async {
    try {
      final result = await ChapterValidator.validateChapter(repository, mangaId, chapterId);
      
      if (result == ValidationResult.valid) {
        // Mark as validated
        await ChapterValidator.markAsValidated(repository, mangaId, chapterId);
        
        if (kDebugMode) {
          print('Background validation passed for manga $mangaId, chapter $chapterId');
        }
      } else {
        if (kDebugMode) {
          print('Background validation failed for manga $mangaId, chapter $chapterId: $result');
        }
        
        // Invalidate relevant providers to update UI
        ref.invalidate(chapterDownloadStatusProvider(mangaId, chapterId));
        ref.invalidate(chapterDownloadProgressProvider(mangaId, chapterId));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Background validation error for manga $mangaId, chapter $chapterId: $e');
      }
    }
  }

  /// Manually validate a specific chapter
  Future<ValidationResult> validateChapter(int mangaId, int chapterId) async {
    final repository = ref.read(localDownloadsRepositoryProvider);
    final result = await ChapterValidator.validateChapter(repository, mangaId, chapterId);
    
    // Invalidate providers to refresh UI
    ref.invalidate(chapterDownloadStatusProvider(mangaId, chapterId));
    ref.invalidate(chapterDownloadProgressProvider(mangaId, chapterId));
    
    return result;
  }

  /// Validate all downloaded chapters
  Future<Map<String, ValidationResult>> validateAllChapters() async {
    final repository = ref.read(localDownloadsRepositoryProvider);
    final downloads = await repository.listDownloads();
    final results = <String, ValidationResult>{};
    
    for (final manifest in downloads) {
      final result = await ChapterValidator.validateChapter(
        repository, 
        manifest.mangaId, 
        manifest.chapterId,
      );
      
      results['${manifest.mangaId}_${manifest.chapterId}'] = result;
      
      // Invalidate providers
      ref.invalidate(chapterDownloadStatusProvider(manifest.mangaId, manifest.chapterId));
      ref.invalidate(chapterDownloadProgressProvider(manifest.mangaId, manifest.chapterId));
    }
    
    return results;
  }
}
