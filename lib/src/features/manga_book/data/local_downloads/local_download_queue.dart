// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'local_downloads_repository.dart';

part 'local_download_queue.g.dart';

/// Download task state for tracking individual chapter downloads
enum DownloadTaskState {
  queued,
  downloading,
  completed,
  failed,
  paused,
}

/// Enhanced download state for chapter integrity
enum ChapterDownloadStatus {
  notDownloaded,
  queued,
  downloading,
  downloaded,           // All files valid
  partiallyCorrupted,   // Some files missing/invalid
  fullyCorrupted,       // Manifest missing or majority files invalid
  repairNeeded,         // User acknowledged corruption, queued for repair
  repairing,           // Actively repairing
  error,               // Download/repair failed
}

/// Extension to add helper methods to ChapterDownloadStatus
extension ChapterDownloadStatusExtension on ChapterDownloadStatus {
  bool get isCorrupted {
    return this == ChapterDownloadStatus.partiallyCorrupted ||
           this == ChapterDownloadStatus.fullyCorrupted;
  }
  
  bool get isDownloaded {
    return this == ChapterDownloadStatus.downloaded;
  }
  
  bool get needsRepair {
    return isCorrupted || this == ChapterDownloadStatus.repairNeeded;
  }
}

/// Validation result for chapter integrity
enum ValidationResult {
  valid,
  missingFiles,
  corruptedFiles,
  sizeInconsistency,
  invalidImageFormat,
  checksumMismatch,
  manifestCorrupted,
}

/// Progress information for downloads with validation details
class ChapterDownloadProgress {
  final int downloadedPages;
  final int totalPages;
  final ChapterDownloadStatus status;
  final String? errorMessage;
  final List<int>? corruptedPageIndices;
  final ValidationResult? validationResult;

  ChapterDownloadProgress({
    required this.downloadedPages,
    required this.totalPages,
    required this.status,
    this.errorMessage,
    this.corruptedPageIndices,
    this.validationResult,
  });

  double get progress => totalPages == 0 ? 0 : downloadedPages / totalPages;

  bool get isComplete => status == ChapterDownloadStatus.downloaded;
  bool get isCorrupted => status == ChapterDownloadStatus.partiallyCorrupted || 
                         status == ChapterDownloadStatus.fullyCorrupted;
  bool get needsRepair => status == ChapterDownloadStatus.repairNeeded || 
                         status == ChapterDownloadStatus.repairing;
}

/// Individual download task for a chapter
class ChapterDownloadTask {
  final int mangaId;
  final int chapterId;
  final String mangaTitle;
  final String chapterName;
  final String? mangaThumbnailUrl;
  final DateTime queuedAt;
  
  DownloadTaskState state;
  int pagesDownloaded;
  int totalPages;
  String? errorMessage;
  DateTime? startedAt;
  DateTime? completedAt;
  
  ChapterDownloadTask({
    required this.mangaId,
    required this.chapterId,
    required this.mangaTitle,
    required this.chapterName,
    this.mangaThumbnailUrl,
    required this.queuedAt,
    this.state = DownloadTaskState.queued,
    this.pagesDownloaded = 0,
    this.totalPages = 0,
    this.errorMessage,
    this.startedAt,
    this.completedAt,
  });
  
  String get taskId => '${mangaId}_$chapterId';
  
  double get progress => totalPages > 0 ? pagesDownloaded / totalPages : 0.0;
  
  bool get isCompleted => state == DownloadTaskState.completed;
  bool get isFailed => state == DownloadTaskState.failed;
  bool get isActive => state == DownloadTaskState.downloading;
  bool get isQueued => state == DownloadTaskState.queued;
  
  ChapterDownloadTask copyWith({
    DownloadTaskState? state,
    int? pagesDownloaded,
    int? totalPages,
    String? errorMessage,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return ChapterDownloadTask(
      mangaId: mangaId,
      chapterId: chapterId,
      mangaTitle: mangaTitle,
      chapterName: chapterName,
      mangaThumbnailUrl: mangaThumbnailUrl,
      queuedAt: queuedAt,
      state: state ?? this.state,
      pagesDownloaded: pagesDownloaded ?? this.pagesDownloaded,
      totalPages: totalPages ?? this.totalPages,
      errorMessage: errorMessage ?? this.errorMessage,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// Queue state for the download system
class DownloadQueueState {
  final List<ChapterDownloadTask> tasks;
  final bool isActive;
  final int maxConcurrentDownloads;
  
  const DownloadQueueState({
    required this.tasks,
    required this.isActive,
    this.maxConcurrentDownloads = 1, // Sequential for now
  });
  
  List<ChapterDownloadTask> get queuedTasks => 
    tasks.where((t) => t.state == DownloadTaskState.queued).toList();
  
  List<ChapterDownloadTask> get activeTasks => 
    tasks.where((t) => t.state == DownloadTaskState.downloading).toList();
  
  List<ChapterDownloadTask> get completedTasks => 
    tasks.where((t) => t.state == DownloadTaskState.completed).toList();
  
  List<ChapterDownloadTask> get failedTasks => 
    tasks.where((t) => t.state == DownloadTaskState.failed).toList();
  
  DownloadQueueState copyWith({
    List<ChapterDownloadTask>? tasks,
    bool? isActive,
    int? maxConcurrentDownloads,
  }) {
    return DownloadQueueState(
      tasks: tasks ?? this.tasks,
      isActive: isActive ?? this.isActive,
      maxConcurrentDownloads: maxConcurrentDownloads ?? this.maxConcurrentDownloads,
    );
  }
}

/// Download queue manager - handles sequential chapter downloads with progress tracking
@riverpod
class LocalDownloadQueue extends _$LocalDownloadQueue {
  final Map<String, Completer<void>> _downloadMutexes = {};
  Timer? _queueProcessor;
  
  @override
  DownloadQueueState build() {
    ref.onDispose(() {
      _queueProcessor?.cancel();
      _downloadMutexes.clear();
    });
    
    return const DownloadQueueState(
      tasks: [],
      isActive: false,
    );
  }
  
  /// Add a chapter to the download queue
  Future<void> enqueueChapter({
    required int mangaId,
    required int chapterId,
    required String mangaTitle,
    required String chapterName,
    String? mangaThumbnailUrl,
  }) async {
    final taskId = '${mangaId}_$chapterId';
    
    // Check if already in queue or downloaded
    final existingTask = state.tasks.where((t) => t.taskId == taskId).firstOrNull;
    if (existingTask != null) {
      if (kDebugMode) {
        print('LocalDownloadQueue: Task $taskId already exists in queue with state ${existingTask.state}');
      }
      return; // Already queued/downloading/completed
    }
    
    // Check if already downloaded locally
    final repo = LocalDownloadsRepository(ref);
    final manifest = await repo.getLocalChapterManifest(mangaId, chapterId);
    if (manifest != null) {
      if (kDebugMode) {
        print('LocalDownloadQueue: Chapter $chapterId already downloaded locally');
      }
      return; // Already downloaded
    }
    
    final task = ChapterDownloadTask(
      mangaId: mangaId,
      chapterId: chapterId,
      mangaTitle: mangaTitle,
      chapterName: chapterName,
      mangaThumbnailUrl: mangaThumbnailUrl,
      queuedAt: DateTime.now(),
    );
    
    final newTasks = [...state.tasks, task];
    state = state.copyWith(tasks: newTasks);
    
    if (kDebugMode) {
      print('LocalDownloadQueue: Enqueued chapter $chapterId for manga $mangaId');
      print('LocalDownloadQueue: Queue size: ${newTasks.length}');
    }
    
    // Start processing if not already active
    if (!state.isActive) {
      _startQueueProcessing();
    }
  }
  
  /// Remove a task from the queue
  void removeTask(String taskId) {
    final newTasks = state.tasks.where((t) => t.taskId != taskId).toList();
    state = state.copyWith(tasks: newTasks);
    
    if (kDebugMode) {
      print('LocalDownloadQueue: Removed task $taskId');
    }
  }
  
  /// Retry a failed task
  Future<void> retryTask(String taskId) async {
    final taskIndex = state.tasks.indexWhere((t) => t.taskId == taskId);
    if (taskIndex == -1) return;
    
    final task = state.tasks[taskIndex];
    if (task.state != DownloadTaskState.failed) return;
    
    final newTasks = [...state.tasks];
    newTasks[taskIndex] = task.copyWith(
      state: DownloadTaskState.queued,
      errorMessage: null,
      pagesDownloaded: 0,
    );
    
    state = state.copyWith(tasks: newTasks);
    
    if (kDebugMode) {
      print('LocalDownloadQueue: Retrying task $taskId');
    }
    
    if (!state.isActive) {
      _startQueueProcessing();
    }
  }
  
  /// Clear completed and failed tasks
  void clearCompleted() {
    final newTasks = state.tasks.where((t) => 
      t.state != DownloadTaskState.completed && 
      t.state != DownloadTaskState.failed
    ).toList();
    state = state.copyWith(tasks: newTasks);
    
    if (kDebugMode) {
      print('LocalDownloadQueue: Cleared completed/failed tasks');
    }
  }
  
  /// Pause/resume queue processing
  void pauseQueue() {
    state = state.copyWith(isActive: false);
    _queueProcessor?.cancel();
    
    if (kDebugMode) {
      print('LocalDownloadQueue: Queue paused');
    }
  }
  
  void resumeQueue() {
    if (!state.isActive && state.queuedTasks.isNotEmpty) {
      _startQueueProcessing();
    }
  }
  
  /// Start processing the download queue
  void _startQueueProcessing() {
    if (state.isActive) return;
    
    state = state.copyWith(isActive: true);
    
    if (kDebugMode) {
      print('LocalDownloadQueue: Starting queue processing');
    }
    
    _queueProcessor = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _processNextTask();
    });
  }
  
  /// Process the next available task in the queue
  Future<void> _processNextTask() async {
    if (!state.isActive) {
      _queueProcessor?.cancel();
      return;
    }
    
    final activeTasks = state.activeTasks;
    final queuedTasks = state.queuedTasks;
    
    // Check if we can start more downloads
    if (activeTasks.length >= state.maxConcurrentDownloads || queuedTasks.isEmpty) {
      // No available slots or no queued tasks
      if (activeTasks.isEmpty && queuedTasks.isEmpty) {
        // Queue is empty, stop processing
        state = state.copyWith(isActive: false);
        _queueProcessor?.cancel();
        
        if (kDebugMode) {
          print('LocalDownloadQueue: Queue processing stopped - no tasks remaining');
        }
      }
      return;
    }
    
    // Start downloading the next queued task
    final nextTask = queuedTasks.first;
    await _downloadTask(nextTask);
  }
  
  /// Download a specific task with progress tracking
  Future<void> _downloadTask(ChapterDownloadTask task) async {
    final taskId = task.taskId;
    
    // Use mutex to prevent concurrent downloads of the same chapter
    if (_downloadMutexes.containsKey(taskId)) {
      if (kDebugMode) {
        print('LocalDownloadQueue: Task $taskId already being processed');
      }
      return;
    }
    
    final completer = Completer<void>();
    _downloadMutexes[taskId] = completer;
    
    try {
      // Update task state to downloading
      _updateTaskState(taskId, task.copyWith(
        state: DownloadTaskState.downloading,
        startedAt: DateTime.now(),
        errorMessage: null,
      ));
      
      if (kDebugMode) {
        print('LocalDownloadQueue: Starting download for task $taskId');
      }
      
      await _performDownload(task);
      
      // Download successful
      _updateTaskState(taskId, task.copyWith(
        state: DownloadTaskState.completed,
        completedAt: DateTime.now(),
      ));
      
      // Invalidate the isChapterDownloadedProvider to update UI
      ref.invalidate(isChapterDownloadedProvider((task.mangaId, task.chapterId)));
      
      if (kDebugMode) {
        print('LocalDownloadQueue: Completed download for task $taskId');
      }
      
    } catch (e) {
      // Download failed
      _updateTaskState(taskId, task.copyWith(
        state: DownloadTaskState.failed,
        errorMessage: e.toString(),
        completedAt: DateTime.now(),
      ));
      
      if (kDebugMode) {
        print('LocalDownloadQueue: Failed download for task $taskId: $e');
      }
    } finally {
      _downloadMutexes.remove(taskId);
      completer.complete();
    }
  }
  
  /// Perform the actual download with progress updates
  Future<void> _performDownload(ChapterDownloadTask task) async {
    final repo = LocalDownloadsRepository(ref);
    
    // Use a custom download method with progress tracking
    await repo.downloadChapterWithProgress(
      ref,
      mangaId: task.mangaId,
      chapterId: task.chapterId,
      mangaTitle: task.mangaTitle,
      chapterName: task.chapterName,
      mangaThumbnailUrl: task.mangaThumbnailUrl,
      onProgress: (pagesDownloaded, totalPages) {
        _updateTaskProgress(task.taskId, pagesDownloaded, totalPages);
      },
    );
  }
  
  /// Update task state in the queue
  void _updateTaskState(String taskId, ChapterDownloadTask updatedTask) {
    final taskIndex = state.tasks.indexWhere((t) => t.taskId == taskId);
    if (taskIndex == -1) return;
    
    final newTasks = [...state.tasks];
    newTasks[taskIndex] = updatedTask;
    state = state.copyWith(tasks: newTasks);
  }
  
  /// Update task progress
  void _updateTaskProgress(String taskId, int pagesDownloaded, int totalPages) {
    final taskIndex = state.tasks.indexWhere((t) => t.taskId == taskId);
    if (taskIndex == -1) return;
    
    final task = state.tasks[taskIndex];
    final newTasks = [...state.tasks];
    newTasks[taskIndex] = task.copyWith(
      pagesDownloaded: pagesDownloaded,
      totalPages: totalPages,
    );
    state = state.copyWith(tasks: newTasks);
  }
}

/// Provider for individual chapter download progress
@riverpod
ChapterDownloadTask? chapterLocalDownloadProgress(
  Ref ref,
  int mangaId,
  int chapterId,
) {
  final queue = ref.watch(localDownloadQueueProvider);
  final taskId = '${mangaId}_$chapterId';
  return queue.tasks.where((t) => t.taskId == taskId).firstOrNull;
}

/// Check if a chapter is downloaded with enhanced states
@riverpod
Future<ChapterDownloadStatus> isChapterDownloaded(
  Ref ref,
  (int, int) chapterInfo,
) async {
  final mangaId = chapterInfo.$1;
  final chapterId = chapterInfo.$2;
  
  final repo = LocalDownloadsRepository(ref);
  final manifest = await repo.getLocalChapterManifest(mangaId, chapterId);
  
  if (manifest == null) {
    return ChapterDownloadStatus.notDownloaded;
  }
  
  // Check if all page files exist
  try {
    for (int i = 0; i < manifest.pageFiles.length; i++) {
      final file = await repo.getLocalPageFile(mangaId, chapterId, i);
      if (file == null || !await file.exists()) {
        return ChapterDownloadStatus.partiallyCorrupted;
      }
    }
    return ChapterDownloadStatus.downloaded;
  } catch (e) {
    if (kDebugMode) {
      print('Error checking chapter download status: $e');
    }
    return ChapterDownloadStatus.fullyCorrupted;
  }
}
