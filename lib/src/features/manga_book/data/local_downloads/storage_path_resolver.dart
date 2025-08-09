// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'local_downloads_settings_repository.dart';

/// Comprehensive storage path resolver with fallback chain and iOS sandboxing support
class StoragePathResolver {
  final LocalDownloadsSettingsRepository _settingsRepo;
  
  const StoragePathResolver(this._settingsRepo);
  
  /// Get the best available downloads directory with fallback chain
  Future<StoragePathResult> resolveDownloadsPath() async {
    final pathAttempts = <StoragePathAttempt>[];
    
    try {
      // 1. Try user-configured custom path first
      final customPath = await _settingsRepo.getLocalDownloadsPath();
      if (customPath != null && customPath.isNotEmpty) {
        final customResult = await _tryPath(
          customPath, 
          PathType.custom, 
          'User-configured custom path'
        );
        pathAttempts.add(customResult.attempt);
        
        if (customResult.success) {
          return StoragePathResult(
            directory: customResult.directory!,
            pathType: PathType.custom,
            attempts: pathAttempts,
          );
        }
      }
      
      // 2. Try application documents directory (iOS-safe)
      final documentsResult = await _tryDocumentsDirectory();
      pathAttempts.add(documentsResult.attempt);
      
      if (documentsResult.success) {
        return StoragePathResult(
          directory: documentsResult.directory!,
          pathType: PathType.documents,
          attempts: pathAttempts,
        );
      }
      
      // 3. Try external storage directory (Android)
      if (Platform.isAndroid) {
        final externalResult = await _tryExternalStorageDirectory();
        pathAttempts.add(externalResult.attempt);
        
        if (externalResult.success) {
          return StoragePathResult(
            directory: externalResult.directory!,
            pathType: PathType.external,
            attempts: pathAttempts,
          );
        }
      }
      
      // 4. Fallback to downloads directory
      final downloadsResult = await _tryDownloadsDirectory();
      pathAttempts.add(downloadsResult.attempt);
      
      if (downloadsResult.success) {
        return StoragePathResult(
          directory: downloadsResult.directory!,
          pathType: PathType.downloads,
          attempts: pathAttempts,
        );
      }
      
      // 5. Final fallback to temporary directory
      final tempResult = await _tryTemporaryDirectory();
      pathAttempts.add(tempResult.attempt);
      
      if (tempResult.success) {
        return StoragePathResult(
          directory: tempResult.directory!,
          pathType: PathType.temporary,
          attempts: pathAttempts,
          isTemporary: true,
        );
      }
      
      // If all paths fail, throw with detailed information
      throw StoragePathException(
        'All storage path options failed',
        attempts: pathAttempts,
      );
      
    } catch (e) {
      if (e is StoragePathException) {
        rethrow;
      }
      
      throw StoragePathException(
        'Unexpected error resolving storage path: $e',
        attempts: pathAttempts,
        originalError: e,
      );
    }
  }
  
  /// Try application documents directory (most reliable on iOS)
  Future<_PathAttemptResult> _tryDocumentsDirectory() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(docs.path, 'sorayomi_downloads'));
      
      return await _tryPath(
        downloadsDir.path,
        PathType.documents,
        'Application documents directory',
      );
    } catch (e) {
      return _PathAttemptResult(
        attempt: StoragePathAttempt(
          path: 'Unknown',
          type: PathType.documents,
          description: 'Application documents directory',
          success: false,
          error: e.toString(),
        ),
        success: false,
      );
    }
  }
  
  /// Try external storage directory (Android)
  Future<_PathAttemptResult> _tryExternalStorageDirectory() async {
    try {
      final external = await getExternalStorageDirectory();
      if (external == null) {
        return _PathAttemptResult(
          attempt: StoragePathAttempt(
            path: 'null',
            type: PathType.external,
            description: 'External storage directory',
            success: false,
            error: 'External storage not available',
          ),
          success: false,
        );
      }
      
      final downloadsDir = Directory(p.join(external.path, 'sorayomi_downloads'));
      
      return await _tryPath(
        downloadsDir.path,
        PathType.external,
        'External storage directory',
      );
    } catch (e) {
      return _PathAttemptResult(
        attempt: StoragePathAttempt(
          path: 'Unknown',
          type: PathType.external,
          description: 'External storage directory',
          success: false,
          error: e.toString(),
        ),
        success: false,
      );
    }
  }
  
  /// Try downloads directory
  Future<_PathAttemptResult> _tryDownloadsDirectory() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads == null) {
        return _PathAttemptResult(
          attempt: StoragePathAttempt(
            path: 'null',
            type: PathType.downloads,
            description: 'Downloads directory',
            success: false,
            error: 'Downloads directory not available',
          ),
          success: false,
        );
      }
      
      final downloadsDir = Directory(p.join(downloads.path, 'sorayomi_downloads'));
      
      return await _tryPath(
        downloadsDir.path,
        PathType.downloads,
        'Downloads directory',
      );
    } catch (e) {
      return _PathAttemptResult(
        attempt: StoragePathAttempt(
          path: 'Unknown',
          type: PathType.downloads,
          description: 'Downloads directory',
          success: false,
          error: e.toString(),
        ),
        success: false,
      );
    }
  }
  
  /// Try temporary directory (last resort)
  Future<_PathAttemptResult> _tryTemporaryDirectory() async {
    try {
      final temp = await getTemporaryDirectory();
      final downloadsDir = Directory(p.join(temp.path, 'sorayomi_downloads'));
      
      return await _tryPath(
        downloadsDir.path,
        PathType.temporary,
        'Temporary directory (WARNING: may be cleared)',
      );
    } catch (e) {
      return _PathAttemptResult(
        attempt: StoragePathAttempt(
          path: 'Unknown',
          type: PathType.temporary,
          description: 'Temporary directory',
          success: false,
          error: e.toString(),
        ),
        success: false,
      );
    }
  }
  
  /// Try to create and access a specific path
  Future<_PathAttemptResult> _tryPath(
    String path,
    PathType type,
    String description,
  ) async {
    try {
      final dir = Directory(path);
      
      // Test if we can create the directory
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      // Test write permissions by creating a test file
      final testFile = File(p.join(dir.path, '.sorayomi_test_${DateTime.now().millisecondsSinceEpoch}'));
      await testFile.writeAsString('test');
      
      // Test read permissions
      await testFile.readAsString();
      
      // Clean up test file
      await testFile.delete();
      
      if (kDebugMode) {
        print('StoragePathResolver: Successfully validated path: $path');
      }
      
      return _PathAttemptResult(
        attempt: StoragePathAttempt(
          path: path,
          type: type,
          description: description,
          success: true,
        ),
        success: true,
        directory: dir,
      );
      
    } catch (e) {
      if (kDebugMode) {
        print('StoragePathResolver: Failed to validate path $path: $e');
      }
      
      return _PathAttemptResult(
        attempt: StoragePathAttempt(
          path: path,
          type: type,
          description: description,
          success: false,
          error: e.toString(),
        ),
        success: false,
      );
    }
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
      );
      
    } catch (e) {
      if (kDebugMode) {
        print('Error calculating storage usage: $e');
      }
      
      return StorageUsage(
        totalSize: 0,
        totalFiles: 0,
        totalChapters: 0,
        error: e.toString(),
      );
    }
  }
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
  
  /// Get human-readable description of the chosen path
  String get description {
    switch (pathType) {
      case PathType.custom:
        return 'Custom path';
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
  
  /// Whether this path is considered reliable for long-term storage
  bool get isReliable => pathType != PathType.temporary;
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
  custom,     // User-configured custom path
  documents,  // Application documents directory (iOS-safe)
  external,   // External storage directory (Android)
  downloads,  // Downloads directory
  temporary,  // Temporary directory (last resort)
}

/// Storage usage information
class StorageUsage {
  final int totalSize;
  final int totalFiles;
  final int totalChapters;
  final String? error;
  
  const StorageUsage({
    required this.totalSize,
    required this.totalFiles,
    required this.totalChapters,
    this.error,
  });
  
  /// Get human-readable size string
  String get formattedSize => _formatBytes(totalSize);
  
  /// Get average chapter size
  double get averageChapterSize => 
      totalChapters > 0 ? totalSize / totalChapters : 0;
  
  String get formattedAverageChapterSize => _formatBytes(averageChapterSize.round());
  
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
