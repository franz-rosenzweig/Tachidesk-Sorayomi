// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:disk_space_plus/disk_space_plus.dart';

import 'local_downloads_settings_repository.dart';

/// Central logging helper for storage related messages
void _storageLog(String message) {
  // ignore: avoid_print
  print('[StoragePathResolver] ' + message);
}

/// Comprehensive storage path resolver with fallback chain and iOS sandboxing support
class StoragePathResolver {
  final LocalDownloadsSettingsRepository _settingsRepo;

  const StoragePathResolver(this._settingsRepo);

  /// Convenience helper for tests with an in-memory stub
  factory StoragePathResolver.test() {
    return StoragePathResolver(_InMemorySettingsRepo());
  }

  /// Resolve the optimal downloads path with ordered fallbacks.
  Future<StoragePathResult> resolveDownloadsPath() async {
    final attempts = <StoragePathAttempt>[];

    Future<StoragePathResult> successResult(_PathAttemptResult r) async {
      return StoragePathResult(
        directory: r.directory!,
        pathType: r.attempt.type,
        attempts: attempts,
        isTemporary: r.attempt.type == PathType.temporary,
      );
    }

    try {
      // 1. Custom path
      final customPath = await _settingsRepo.getLocalDownloadsPath();
      if (customPath != null && customPath.isNotEmpty) {
        final r = await _tryPath(customPath, PathType.custom, 'User-configured custom path');
        attempts.add(r.attempt);
        if (r.success) return successResult(r);
      }

      // 2. Application Support
      final support = await _tryApplicationSupportDirectory();
      attempts.add(support.attempt);
      if (support.success) return successResult(support);

      // 3. Documents
      final docs = await _tryDocumentsDirectory();
      attempts.add(docs.attempt);
      if (docs.success) return successResult(docs);

      // 4. External (Android only)
      if (Platform.isAndroid) {
        final ext = await _tryExternalStorageDirectory();
        attempts.add(ext.attempt);
        if (ext.success) return successResult(ext);
      }

      // 5. Downloads folder (desktop/mobile platforms that support it)
      final dl = await _tryDownloadsDirectory();
      attempts.add(dl.attempt);
      if (dl.success) return successResult(dl);

      // 6. Temporary (last resort)
      final tmp = await _tryTemporaryDirectory();
      attempts.add(tmp.attempt);
      if (tmp.success) return successResult(tmp);

      throw StoragePathException('All storage path options failed', attempts: attempts);
    } catch (e) {
      if (e is StoragePathException) rethrow;
      throw StoragePathException('Unexpected error resolving storage path: $e', attempts: attempts, originalError: e);
    }
  }
  
  /// Application Support (preferred persistent sandbox)
  Future<_PathAttemptResult> _tryApplicationSupportDirectory() async {
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory(p.join(base.path, 'sorayomi_downloads'));
      return await _tryPath(dir.path, PathType.applicationSupport, 'Application support directory');
    } catch (e) {
      return _failedAttempt(PathType.applicationSupport, 'Application support directory', e);
    }
  }

  /// Documents (secondary sandbox)
  Future<_PathAttemptResult> _tryDocumentsDirectory() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(base.path, 'sorayomi_downloads'));
      return await _tryPath(dir.path, PathType.documents, 'Application documents directory');
    } catch (e) {
      return _failedAttempt(PathType.documents, 'Application documents directory', e);
    }
  }
  
  /// External (Android only)
  Future<_PathAttemptResult> _tryExternalStorageDirectory() async {
    try {
      final base = await getExternalStorageDirectory();
      if (base == null) {
        return _failedAttempt(PathType.external, 'External storage directory', 'External storage not available');
      }
      final dir = Directory(p.join(base.path, 'sorayomi_downloads'));
      return await _tryPath(dir.path, PathType.external, 'External storage directory');
    } catch (e) {
      return _failedAttempt(PathType.external, 'External storage directory', e);
    }
  }
  
  /// Downloads directory (platform support varies)
  Future<_PathAttemptResult> _tryDownloadsDirectory() async {
    try {
      final base = await getDownloadsDirectory();
      if (base == null) {
        return _failedAttempt(PathType.downloads, 'Downloads directory', 'Downloads directory not available');
      }
      final dir = Directory(p.join(base.path, 'sorayomi_downloads'));
      return await _tryPath(dir.path, PathType.downloads, 'Downloads directory');
    } catch (e) {
      return _failedAttempt(PathType.downloads, 'Downloads directory', e);
    }
  }
  
  /// Temporary directory (last resort)
  Future<_PathAttemptResult> _tryTemporaryDirectory() async {
    try {
      final base = await getTemporaryDirectory();
      final dir = Directory(p.join(base.path, 'sorayomi_downloads'));
      return await _tryPath(dir.path, PathType.temporary, 'Temporary directory (WARNING: may be cleared)');
    } catch (e) {
      return _failedAttempt(PathType.temporary, 'Temporary directory', e);
    }
  }
  
  /// Attempt a specific path (create, write test, read test)
  Future<_PathAttemptResult> _tryPath(String path, PathType type, String description) async {
    final dir = Directory(path);
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final writable = await _isWritable(dir);
      if (writable) {
        _storageLog('Validated path: $path');
        return _PathAttemptResult(
          attempt: StoragePathAttempt(path: path, type: type, description: description, success: true),
          success: true,
          directory: dir,
        );
      }
      return _failedAttempt(type, description, 'Directory not writable', path: path);
    } catch (e) {
      return _failedAttempt(type, description, e, path: path);
    }
  }

  /// Determine if directory is writable by creating and deleting a test file
  Future<bool> _isWritable(Directory dir) async {
    try {
      final f = File(p.join(dir.path, '.sorayomi_write_test'));
      await f.writeAsString(DateTime.now().toIso8601String());
      await f.readAsString();
      await f.delete();
      return true;
    } catch (e) {
      _storageLog('Write test failed in ${dir.path}: $e');
      return false;
    }
  }

  _PathAttemptResult _failedAttempt(PathType type, String description, Object error, {String? path}) {
    final attempt = StoragePathAttempt(
      path: path ?? 'Unknown',
      type: type,
      description: description,
      success: false,
      error: error.toString(),
    );
    _storageLog('Attempt FAILED type=$type path=${attempt.path} error=${attempt.error}');
    return _PathAttemptResult(attempt: attempt, success: false);
  }
  
  /// Get storage usage for a directory
  Future<StorageUsage> calculateStorageUsage(Directory directory) async {
    try {
      int totalSize = 0;
      int totalFiles = 0;
      int totalChapters = 0;
      final chapterSizes = <String, int>{};
      
      if (!await directory.exists()) {
        return StorageUsage(
          totalSize: 0,
          totalFiles: 0,
          totalChapters: 0,
          freeSpace: await _tryGetFreeSpace(),
          totalSpace: await _tryGetTotalSpace(),
        );
      }
      
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final file = entity;
          final stat = await file.stat();
          final size = stat.size;
          
          totalSize += size;
          totalFiles++;
          
          // Extract chapter info from path
          final relativePath = p.relative(file.path, from: directory.path);
          final pathParts = p.split(relativePath);
          
          if (pathParts.length >= 2) {
            final chapterKey = p.join(pathParts[0], pathParts[1]); // manga_X/chapter_Y
            chapterSizes[chapterKey] = (chapterSizes[chapterKey] ?? 0) + size;
          }
        }
      }
      
      totalChapters = chapterSizes.length;
      
      return StorageUsage(
        totalSize: totalSize,
        totalFiles: totalFiles,
        totalChapters: totalChapters,
        freeSpace: await _tryGetFreeSpace(),
        totalSpace: await _tryGetTotalSpace(),
      );
      
    } catch (e) {
      if (kDebugMode) {
        print('Error calculating storage usage: $e');
      }
      
      return StorageUsage(
        totalSize: 0,
        totalFiles: 0,
        totalChapters: 0,
        freeSpace: await _tryGetFreeSpace(),
        totalSpace: await _tryGetTotalSpace(),
        error: e.toString(),
      );
    }
  }

  Future<int?> _tryGetFreeSpace() async {
    try {
  final free = await DiskSpacePlus().getFreeDiskSpace; // MB (instance getter)
      if (free == null) return null;
      return (free * 1024 * 1024).round();
    } catch (_) {
      return null;
    }
  }

  Future<int?> _tryGetTotalSpace() async {
    try {
  final total = await DiskSpacePlus().getTotalDiskSpace; // MB (instance getter)
      if (total == null) return null;
      return (total * 1024 * 1024).round();
    } catch (_) {
      return null;
    }
  }
}

/// Simple in-memory settings stub for tests (avoids SharedPreferences IO)
class _InMemorySettingsRepo extends LocalDownloadsSettingsRepository {
  String? _path;
  String? _bookmark;
  @override
  Future<String?> getLocalDownloadsPath() async => _path;
  @override
  Future<void> setLocalDownloadsPath(String path) async { _path = path; }
  @override
  Future<void> clearLocalDownloadsPath() async { _path = null; _bookmark = null; }
  @override
  Future<void> setBookmark(String base64) async { _bookmark = base64; }
  @override
  Future<String?> getBookmark() async => _bookmark;
}

/// Result of storage path resolution
class StoragePathResult {
  final Directory directory;
  final PathType pathType;
  final List<StoragePathAttempt> attempts;
  final bool isTemporary;

  const StoragePathResult({
    required this.directory,
    required this.pathType,
    required this.attempts,
    this.isTemporary = false,
  });

  String get description {
    switch (pathType) {
      case PathType.custom:
        return 'Custom path';
      case PathType.applicationSupport:
        return 'Application support';
      case PathType.documents:
        return 'Application documents';
      case PathType.external:
        return 'External storage';
      case PathType.downloads:
        return 'Downloads folder';
      case PathType.temporary:
        return 'Temporary storage (may be cleared)';
    }
  }

  bool get isReliable => pathType != PathType.temporary;
  bool get isCustom => pathType == PathType.custom;
}

/// Individual path attempt result
class StoragePathAttempt {
  final String path;
  final PathType type;
  final String description;
  final bool success;
  final String? error;
  
  const StoragePathAttempt({
    required this.path,
    required this.type,
    required this.description,
    required this.success,
    this.error,
  });
}

/// Types of storage paths
enum PathType {
  custom,             // User-configured custom path
  applicationSupport, // Application support directory (preferred persistent)
  documents,          // Application documents directory
  external,           // External storage directory (Android)
  downloads,          // Downloads directory
  temporary,          // Temporary directory (last resort)
}

/// Storage usage information
class StorageUsage {
  final int totalSize;
  final int totalFiles;
  final int totalChapters;
  final int? freeSpace; // bytes
  final int? totalSpace; // bytes
  final String? error;
  
  const StorageUsage({
    required this.totalSize,
    required this.totalFiles,
    required this.totalChapters,
    this.freeSpace,
    this.totalSpace,
    this.error,
  });
  
  /// Get human-readable size string
  String get formattedSize => _formatBytes(totalSize);
  
  /// Get average chapter size
  double get averageChapterSize => 
      totalChapters > 0 ? totalSize / totalChapters : 0;
  
  String get formattedAverageChapterSize => _formatBytes(averageChapterSize.round());
  String get formattedFreeSpace => freeSpace == null ? '—' : _formatBytes(freeSpace!);
  String get formattedTotalSpace => totalSpace == null ? '—' : _formatBytes(totalSpace!);
  
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Exception thrown when storage path resolution fails
class StoragePathException implements Exception {
  final String message;
  final List<StoragePathAttempt> attempts;
  final Object? originalError;
  
  const StoragePathException(
    this.message, {
    this.attempts = const [],
    this.originalError,
  });
  
  @override
  String toString() {
    final buffer = StringBuffer('StoragePathException: $message');
    
    if (attempts.isNotEmpty) {
      buffer.writeln('\n\nPath attempts:');
      for (final attempt in attempts) {
        buffer.writeln('  ${attempt.description}: ${attempt.success ? 'SUCCESS' : 'FAILED'}');
        buffer.writeln('    Path: ${attempt.path}');
        if (attempt.error != null) {
          buffer.writeln('    Error: ${attempt.error}');
        }
      }
    }
    
    if (originalError != null) {
      buffer.writeln('\nOriginal error: $originalError');
    }
    
    return buffer.toString();
  }
}

/// Internal helper class for path attempt results
class _PathAttemptResult {
  final StoragePathAttempt attempt;
  final bool success;
  final Directory? directory;
  
  const _PathAttemptResult({
    required this.attempt,
    required this.success,
    this.directory,
  });
}
