// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_downloads_settings_repository.dart';
import 'storage_path_resolver.dart';

/// Handles migration of downloads and settings to the new storage system
class StorageMigrationManager {
  final LocalDownloadsSettingsRepository _settingsRepo;
  final StoragePathResolver _pathResolver;
  
  static const String _migrationFlagKey = 'localDownloadsMigrated_v2';
  static const String _lastMigrationVersionKey = 'lastMigrationVersion';
  static const int _currentMigrationVersion = 2;
  
  const StorageMigrationManager(this._settingsRepo, this._pathResolver);
  
  /// Check if migration is needed and perform it
  Future<MigrationResult> checkAndMigrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isMigrated = prefs.getBool(_migrationFlagKey) ?? false;
      final lastVersion = prefs.getInt(_lastMigrationVersionKey) ?? 0;
      
      if (isMigrated && lastVersion >= _currentMigrationVersion) {
        return MigrationResult(
          success: true,
          alreadyMigrated: true,
          message: 'Migration already completed',
        );
      }
      
      if (kDebugMode) {
        print('StorageMigrationManager: Starting migration from version $lastVersion to $_currentMigrationVersion');
      }
      
      final migrationSteps = <MigrationStep>[];
      
      // Step 1: Find and validate current downloads
      final discoveryResult = await _discoverExistingDownloads();
      migrationSteps.add(discoveryResult);
      
      if (!discoveryResult.success) {
        return MigrationResult(
          success: false,
          message: 'Failed to discover existing downloads: ${discoveryResult.error}',
          steps: migrationSteps,
        );
      }
      
      // Step 2: Resolve optimal storage path
      final pathResult = await _resolveOptimalPath();
      migrationSteps.add(pathResult);
      
      if (!pathResult.success) {
        return MigrationResult(
          success: false,
          message: 'Failed to resolve storage path: ${pathResult.error}',
          steps: migrationSteps,
        );
      }
      
      // Step 3: Migrate downloads if needed
      if (discoveryResult.oldDownloadsFound) {
        final moveResult = await _migrateDownloads(
          discoveryResult.oldPaths!,
          pathResult.targetPath!,
        );
        migrationSteps.add(moveResult);
        
        if (!moveResult.success) {
          return MigrationResult(
            success: false,
            message: 'Failed to migrate downloads: ${moveResult.error}',
            steps: migrationSteps,
          );
        }
      }
      
      // Step 4: Update settings and mark as migrated
      final settingsResult = await _updateSettings(pathResult.targetPath!);
      migrationSteps.add(settingsResult);
      
      if (!settingsResult.success) {
        return MigrationResult(
          success: false,
          message: 'Failed to update settings: ${settingsResult.error}',
          steps: migrationSteps,
        );
      }
      
      // Mark migration as complete
      await prefs.setBool(_migrationFlagKey, true);
      await prefs.setInt(_lastMigrationVersionKey, _currentMigrationVersion);
      
      if (kDebugMode) {
        print('StorageMigrationManager: Migration completed successfully');
      }
      
      return MigrationResult(
        success: true,
        message: 'Migration completed successfully',
        steps: migrationSteps,
        downloadsFound: discoveryResult.downloadsCount,
        downloadsMigrated: discoveryResult.oldDownloadsFound,
      );
      
    } catch (e) {
      if (kDebugMode) {
        print('StorageMigrationManager: Migration failed with error: $e');
      }
      
      return MigrationResult(
        success: false,
        message: 'Migration failed: $e',
        error: e.toString(),
      );
    }
  }
  
  /// Discover existing downloads from various locations
  Future<MigrationStep> _discoverExistingDownloads() async {
    try {
      final candidatePaths = <String>[];
      final downloadsFound = <String, int>{};
      
      // Check current configured path
      final currentPath = await _settingsRepo.getLocalDownloadsPath();
      if (currentPath != null && currentPath.isNotEmpty) {
        candidatePaths.add(currentPath);
      }
      
      // Check file provider paths (old system)
      try {
        // This method might not exist in older versions, so we'll skip it
        // final fileProviderPath = await _settingsRepo.getFileProviderDownloadsPath();
        // if (fileProviderPath != null && fileProviderPath.isNotEmpty) {
        //   candidatePaths.add(fileProviderPath);
        // }
      } catch (e) {
        // File provider path method might not exist in older versions
      }
      
      // Check common download locations
      candidatePaths.addAll(await _getCommonDownloadPaths());
      
      // Remove duplicates
      final uniquePaths = candidatePaths.toSet().toList();
      
      for (final path in uniquePaths) {
        final count = await _countDownloadsInPath(path);
        if (count > 0) {
          downloadsFound[path] = count;
        }
      }
      
      final totalDownloads = downloadsFound.values.fold(0, (a, b) => a + b);
      
      return MigrationStep(
        name: 'Discover existing downloads',
        success: true,
        message: 'Found $totalDownloads downloads in ${downloadsFound.length} locations',
        oldDownloadsFound: downloadsFound.isNotEmpty,
        oldPaths: downloadsFound.keys.toList(),
        downloadsCount: totalDownloads,
      );
      
    } catch (e) {
      return MigrationStep(
        name: 'Discover existing downloads',
        success: false,
        error: e.toString(),
      );
    }
  }
  
  /// Get common download paths to check
  Future<List<String>> _getCommonDownloadPaths() async {
    final paths = <String>[];
    
    try {
      // Documents directory with various subdirectories
      final docs = await getApplicationDocumentsDirectory();
      paths.addAll([
        p.join(docs.path, 'sorayomi_downloads'),
        p.join(docs.path, 'tachidesk_downloads'),
        p.join(docs.path, 'downloads'),
      ]);
    } catch (e) {
      // Ignore
    }
    
    if (Platform.isAndroid) {
      try {
        final external = await getExternalStorageDirectory();
        if (external != null) {
          paths.addAll([
            p.join(external.path, 'sorayomi_downloads'),
            p.join(external.path, 'tachidesk_downloads'),
            p.join(external.path, 'downloads'),
          ]);
        }
      } catch (e) {
        // Ignore
      }
    }
    
    return paths;
  }
  
  /// Count downloads in a specific path
  Future<int> _countDownloadsInPath(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) return 0;
      
      int count = 0;
      await for (final entity in dir.list()) {
        if (entity is Directory) {
          final dirName = p.basename(entity.path);
          if (dirName.startsWith('manga_')) {
            // Count chapter directories within manga directory
            await for (final chapterEntity in entity.list()) {
              if (chapterEntity is Directory) {
                final chapterName = p.basename(chapterEntity.path);
                if (chapterName.startsWith('chapter_')) {
                  // Check if it has a manifest file
                  final manifestFile = File(p.join(chapterEntity.path, 'manifest.json'));
                  if (await manifestFile.exists()) {
                    count++;
                  }
                }
              }
            }
          }
        }
      }
      
      return count;
    } catch (e) {
      return 0;
    }
  }
  
  /// Resolve the optimal storage path for the current environment
  Future<MigrationStep> _resolveOptimalPath() async {
    try {
      final pathResult = await _pathResolver.resolveDownloadsPath();
      
      return MigrationStep(
        name: 'Resolve storage path',
        success: true,
        message: 'Resolved to: ${pathResult.directory.path} (${pathResult.description})',
        targetPath: pathResult.directory.path,
        pathType: pathResult.pathType,
        isReliable: pathResult.isReliable,
      );
      
    } catch (e) {
      return MigrationStep(
        name: 'Resolve storage path',
        success: false,
        error: e.toString(),
      );
    }
  }
  
  /// Migrate downloads from old paths to new path
  Future<MigrationStep> _migrateDownloads(List<String> oldPaths, String targetPath) async {
    try {
      int totalMigrated = 0;
      final errors = <String>[];
      
      for (final oldPath in oldPaths) {
        if (oldPath == targetPath) {
          continue; // Skip if already at target location
        }
        
        final migratedCount = await _migrateFromPath(oldPath, targetPath);
        totalMigrated += migratedCount;
      }
      
      return MigrationStep(
        name: 'Migrate downloads',
        success: errors.isEmpty,
        message: errors.isEmpty 
            ? 'Successfully migrated $totalMigrated downloads'
            : 'Migrated $totalMigrated downloads with ${errors.length} errors',
        migratedCount: totalMigrated,
        errors: errors.isEmpty ? null : errors,
      );
      
    } catch (e) {
      return MigrationStep(
        name: 'Migrate downloads',
        success: false,
        error: e.toString(),
      );
    }
  }
  
  /// Migrate downloads from a specific old path to target path
  Future<int> _migrateFromPath(String oldPath, String targetPath) async {
    int migratedCount = 0;
    
    try {
      final oldDir = Directory(oldPath);
      final targetDir = Directory(targetPath);
      
      if (!await oldDir.exists()) return 0;
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      
      await for (final entity in oldDir.list()) {
        if (entity is Directory) {
          final dirName = p.basename(entity.path);
          if (dirName.startsWith('manga_')) {
            final targetMangaDir = Directory(p.join(targetPath, dirName));
            
            // Copy manga directory structure
            await _copyDirectory(entity, targetMangaDir);
            
            // Count migrated chapters
            await for (final chapterEntity in entity.list()) {
              if (chapterEntity is Directory) {
                final chapterName = p.basename(chapterEntity.path);
                if (chapterName.startsWith('chapter_')) {
                  final manifestFile = File(p.join(chapterEntity.path, 'manifest.json'));
                  if (await manifestFile.exists()) {
                    migratedCount++;
                  }
                }
              }
            }
            
            // Remove old directory after successful copy
            await entity.delete(recursive: true);
          }
        }
      }
      
      // Remove old root directory if empty
      final remaining = await oldDir.list().length;
      if (remaining == 0) {
        await oldDir.delete();
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Error migrating from $oldPath: $e');
      }
    }
    
    return migratedCount;
  }
  
  /// Copy directory recursively
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }
    
    await for (final entity in source.list()) {
      if (entity is Directory) {
        final newDirectory = Directory(p.join(destination.path, p.basename(entity.path)));
        await _copyDirectory(entity, newDirectory);
      } else if (entity is File) {
        final newFile = File(p.join(destination.path, p.basename(entity.path)));
        await entity.copy(newFile.path);
      }
    }
  }
  
  /// Update settings with new path
  Future<MigrationStep> _updateSettings(String targetPath) async {
    try {
      await _settingsRepo.setLocalDownloadsPath(targetPath);
      
      return MigrationStep(
        name: 'Update settings',
        success: true,
        message: 'Updated downloads path to: $targetPath',
      );
      
    } catch (e) {
      return MigrationStep(
        name: 'Update settings',
        success: false,
        error: e.toString(),
      );
    }
  }
  
  /// Reset migration flag (for testing/debugging)
  Future<void> resetMigrationFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_migrationFlagKey);
    await prefs.remove(_lastMigrationVersionKey);
  }

  /// Check if migration is needed (simplified for UI)
  Future<bool> isMigrationNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isMigrated = prefs.getBool(_migrationFlagKey) ?? false;
      final lastVersion = prefs.getInt(_lastMigrationVersionKey) ?? 0;
      
      return !isMigrated || lastVersion < _currentMigrationVersion;
    } catch (e) {
      return false;
    }
  }
  
  /// Perform migration (simplified for UI)
  Future<void> performMigration() async {
    final result = await checkAndMigrate();
    if (!result.success) {
      throw Exception(result.error ?? 'Migration failed');
    }
  }
}

/// Result of the migration process
class MigrationResult {
  final bool success;
  final bool alreadyMigrated;
  final String message;
  final String? error;
  final List<MigrationStep> steps;
  final int downloadsFound;
  final bool downloadsMigrated;
  
  const MigrationResult({
    required this.success,
    this.alreadyMigrated = false,
    required this.message,
    this.error,
    this.steps = const [],
    this.downloadsFound = 0,
    this.downloadsMigrated = false,
  });
}

/// Individual migration step result
class MigrationStep {
  final String name;
  final bool success;
  final String? message;
  final String? error;
  final List<String>? errors;
  final bool oldDownloadsFound;
  final List<String>? oldPaths;
  final int downloadsCount;
  final String? targetPath;
  final PathType? pathType;
  final bool isReliable;
  final int migratedCount;
  
  const MigrationStep({
    required this.name,
    required this.success,
    this.message,
    this.error,
    this.errors,
    this.oldDownloadsFound = false,
    this.oldPaths,
    this.downloadsCount = 0,
    this.targetPath,
    this.pathType,
    this.isReliable = true,
    this.migratedCount = 0,
  });
}
