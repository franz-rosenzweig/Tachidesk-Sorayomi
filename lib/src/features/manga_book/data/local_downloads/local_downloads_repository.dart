import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../constants/endpoints.dart';
import '../../../../constants/enum.dart';
import '../../../../features/settings/presentation/server/widget/client/server_port_tile/server_port_tile.dart';
import '../../../../features/settings/presentation/server/widget/client/server_url_tile/server_url_tile.dart';
import '../../../../features/settings/presentation/server/widget/credential_popup/credentials_popup.dart';
import '../../../../global_providers/global_providers.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../domain/local_downloads/local_downloads_model.dart';
import '../manga_book/manga_book_repository.dart';
import 'local_downloads_settings_repository.dart';
import 'storage_migration_manager.dart';
import 'storage_path_resolver.dart';

class LocalDownloadsRepository {
  static const downloadsFolderName = 'sorayomi_downloads';
  static const manifestFileName = 'manifest.json';

  final Ref _ref;
  
  LocalDownloadsRepository(this._ref);

  /// Get storage path resolver
  StoragePathResolver get _pathResolver => StoragePathResolver(
    _ref.read(localDownloadsSettingsRepositoryProvider)
  );

  /// Get migration manager
  StorageMigrationManager get _migrationManager => StorageMigrationManager(
    _ref.read(localDownloadsSettingsRepositoryProvider),
    _pathResolver,
  );

  Future<Directory> _baseDir() async {
    try {
      // Perform migration check first (this is fast if already migrated)
      final migrationResult = await _migrationManager.checkAndMigrate();
      
      if (!migrationResult.success) {
        if (kDebugMode) {
          print('LocalDownloadsRepository: Migration failed: ${migrationResult.message}');
        }
        // Continue with fallback behavior
      } else if (!migrationResult.alreadyMigrated) {
        if (kDebugMode) {
          print('LocalDownloadsRepository: Migration completed: ${migrationResult.message}');
        }
      }
      
      // Use path resolver to get optimal storage path
      final pathResult = await _pathResolver.resolveDownloadsPath();
      
      if (kDebugMode) {
        print('LocalDownloadsRepository: Using storage path: ${pathResult.directory.path} (${pathResult.description})');
        if (!pathResult.isReliable) {
          print('LocalDownloadsRepository: WARNING - Using temporary storage path that may be cleared');
        }
      }
      
      return pathResult.directory;
      
    } catch (e) {
      if (kDebugMode) {
        print('LocalDownloadsRepository: Storage resolution failed: $e. Using fallback.');
      }
      
      // Fallback to original behavior
      return await _legacyBaseDir();
    }
  }

  /// Legacy base directory method (fallback)
  Future<Directory> _legacyBaseDir() async {
    // Check if user has set a custom downloads path
    final customPath = await _ref.read(localDownloadsSettingsRepositoryProvider).getLocalDownloadsPath();
    
    if (kDebugMode) {
      print('LocalDownloadsRepository._baseDir() called');
      print('Custom path from settings: $customPath');
    }
    
    if (customPath != null && customPath.isNotEmpty) {
      try {
        final dir = Directory(p.join(customPath, downloadsFolderName));
        if (kDebugMode) {
          print('Attempting to use custom downloads path: ${dir.path}');
          print('Custom path exists: ${await dir.exists()}');
        }
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        if (kDebugMode) {
          print('Using custom downloads path: ${dir.path}');
        }
        return dir;
      } catch (e) {
        if (kDebugMode) {
          print('Failed to use custom path $customPath: $e. Falling back to default.');
        }
        // Fall through to default path if custom path fails
      }
    }
    
    // Default path: Use iOS-safe Documents directory
    final docs = await getApplicationDocumentsDirectory();
    
    // TEMPORARY FIX: Check if downloads exist in File Provider Storage location
    // This handles the case where downloads were saved to a different location
    final fileProviderPath = "/Users/home/Library/Developer/CoreSimulator/Devices/BE87C899-F379-4995-B9AC-E5EFA09E6054/data/Containers/Shared/AppGroup/8F6C4E93-B0BB-43CF-8F8E-F695F35FE799/File Provider Storage/Manga";
    final fileProviderDir = Directory(p.join(fileProviderPath, downloadsFolderName));
    
    if (await fileProviderDir.exists()) {
      if (kDebugMode) {
        print('Found downloads in File Provider Storage, using: ${fileProviderDir.path}');
      }
      return fileProviderDir;
    }
    
    final dir = Directory(p.join(docs.path, downloadsFolderName));
    if (kDebugMode) {
      print('Getting default documents directory: ${docs.path}');
      print('Using default downloads path: ${dir.path}');
      print('Default path exists: ${await dir.exists()}');
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    if (kDebugMode) {
      print('Final downloads directory: ${dir.path}');
    }
    return dir;
  }

  /// Get chapter directory
  Future<Directory> getChapterDirectory(int mangaId, int chapterId) async {
    return await _chapterDir(mangaId, chapterId);
  }

  /// Save manifest to file
  Future<void> saveManifest(int mangaId, int chapterId, LocalChapterManifest manifest) async {
    final manifestFile = await _manifestFile(mangaId, chapterId);
    await manifestFile.writeAsString(jsonEncode(manifest.toJson()));
  }

  Future<Directory> _chapterDir(int mangaId, int chapterId) async {
    final base = await _baseDir();
    final dir = Directory(p.join(base.path, 'manga_$mangaId', 'chapter_$chapterId'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _manifestFile(int mangaId, int chapterId) async {
    final dir = await _chapterDir(mangaId, chapterId);
    return File(p.join(dir.path, manifestFileName));
  }

  Future<bool> isChapterDownloaded(int mangaId, int chapterId) async {
    final manifest = await _manifestFile(mangaId, chapterId);
    return manifest.existsSync();
  }

  /// Get the manifest for a downloaded chapter
  Future<LocalChapterManifest?> getLocalChapterManifest(int mangaId, int chapterId) async {
    return await getManifest(mangaId, chapterId);
  }

  /// Get the number of pages for a locally downloaded chapter
  Future<int?> getLocalChapterPageCount(int mangaId, int chapterId) async {
    final manifest = await getManifest(mangaId, chapterId);
    return manifest?.pageFiles.length;
  }

  /// Check if chapter is available locally with page count
  Future<bool> isChapterFullyDownloaded(int mangaId, int chapterId) async {
    final manifest = await getManifest(mangaId, chapterId);
    if (manifest == null) return false;
    
    // Verify all page files exist
    final chapterDir = await _chapterDir(mangaId, chapterId);
    for (final pageFile in manifest.pageFiles) {
      final file = File(p.join(chapterDir.path, pageFile));
      if (!await file.exists()) return false;
    }
    return true;
  }

  /// Reset downloads path to default (for fixing iOS permission issues)
  Future<void> resetToDefaultPath() async {
    await _ref.read(localDownloadsSettingsRepositoryProvider).clearLocalDownloadsPath();
    if (kDebugMode) {
      print('Reset downloads path to default iOS Documents directory');
    }
  }

  /// Debug method to check current base directory
  Future<void> debugBaseDirectory() async {
    try {
      final dir = await _baseDir();
      if (kDebugMode) {
        print('Debug: Base directory: ${dir.path}');
        print('Debug: Directory exists: ${await dir.exists()}');
        if (await dir.exists()) {
          final contents = await dir.list().toList();
          print('Debug: Directory contents: ${contents.map((e) => e.path).toList()}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Debug: Error checking base directory: $e');
      }
    }
  }

  Future<LocalChapterManifest?> getManifest(int mangaId, int chapterId) async {
    final f = await _manifestFile(mangaId, chapterId);
    if (!await f.exists()) return null;
    try {
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return LocalChapterManifest.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<List<LocalChapterManifest>> listDownloads() async {
    if (kDebugMode) {
      print('LocalDownloadsRepository.listDownloads() called');
    }
    
    final base = await _baseDir();
    final results = <LocalChapterManifest>[];
    
    if (kDebugMode) {
      print('Base downloads directory: ${base.path}');
      print('Base directory exists: ${await base.exists()}');
    }
    
    if (!await base.exists()) {
      if (kDebugMode) {
        print('Base directory does not exist, returning empty list');
      }
      return results;
    }
    
    if (kDebugMode) {
      print('Scanning for manifest files...');
    }
    
    var manifestCount = 0;
    await for (final entity in base.list(recursive: true)) {
      if (kDebugMode && entity is Directory) {
        print('Found directory: ${entity.path}');
      }
      if (entity is File && p.basename(entity.path) == manifestFileName) {
        manifestCount++;
        if (kDebugMode) {
          print('Found manifest file #$manifestCount: ${entity.path}');
        }
        try {
          final data = jsonDecode(await entity.readAsString())
              as Map<String, dynamic>;
          final manifest = LocalChapterManifest.fromJson(data);
          results.add(manifest);
          if (kDebugMode) {
            print('Successfully loaded manifest: manga ${manifest.mangaId}, chapter ${manifest.chapterId}');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Failed to parse manifest ${entity.path}: $e');
          }
        }
      }
    }
    
    if (kDebugMode) {
      print('Total manifests found: ${results.length}');
    }
    
    // Sort newest first
    results.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return results;
  }

  // Returns saved files (absolute paths)
  Future<List<File>> _downloadPagesToChapter(
    Ref ref, {
    required int mangaId,
    required int chapterId,
    required List<String> pageUrls,
  }) async {
    return _downloadPagesToChapterWithProgress(
      ref,
      mangaId: mangaId,
      chapterId: chapterId,
      pageUrls: pageUrls,
    );
  }

  /// Enhanced download method with progress tracking and retry logic
  Future<List<File>> _downloadPagesToChapterWithProgress(
    Ref ref, {
    required int mangaId,
    required int chapterId,
    required List<String> pageUrls,
    void Function(int pagesDownloaded, int totalPages)? onProgress,
    int maxRetries = 3,
  }) async {
    final dir = await _chapterDir(mangaId, chapterId);
    final saved = <File>[];

    for (var i = 0; i < pageUrls.length; i++) {
      final url = pageUrls[i];
      final fileName = 'page_${(i + 1).toString().padLeft(4, '0')}.jpg';
      final dest = File(p.join(dir.path, fileName));
      
      bool success = false;
      int attempts = 0;
      Exception? lastError;
      
      while (!success && attempts < maxRetries) {
        attempts++;
        
        try {
          if (kDebugMode) {
            print('downloadChapterWithProgress PAGE_START: $i/$pageUrls.length (attempt $attempts)');
          }
          
          await _downloadSinglePage(ref, url, dest, i);
          
          saved.add(dest);
          success = true;
          
          if (kDebugMode) {
            print('downloadChapterWithProgress PAGE_SAVED: $i/$pageUrls.length');
          }
          
          // Report progress after each successful page
          onProgress?.call(saved.length, pageUrls.length);
          
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          
          if (kDebugMode) {
            print('downloadChapterWithProgress PAGE_FAILED: $i/$pageUrls.length (attempt $attempts): $e');
          }
          
          // Clean up failed attempt
          if (await dest.exists()) {
            try {
              await dest.delete();
            } catch (deleteError) {
              if (kDebugMode) {
                print('Failed to delete corrupted file: $deleteError');
              }
            }
          }
          
          // Wait before retry (exponential backoff)
          if (attempts < maxRetries) {
            final delay = Duration(milliseconds: 500 * attempts);
            await Future.delayed(delay);
          }
        }
      }
      
      if (!success) {
        throw Exception('Failed to download page $i after $maxRetries attempts: ${lastError?.toString() ?? 'Unknown error'}');
      }
    }
    
    return saved;
  }

  /// Download a single page with robust error handling
  Future<void> _downloadSinglePage(Ref ref, String url, File dest, int pageIndex) async {
    // Build the full authenticated URL
    final authType = ref.read(authTypeKeyProvider);
    final basicToken = ref.read(credentialsProvider);
    
    // First get the base API URL without the page URL
    final baseApiUrl = Endpoints.baseApi(
      baseUrl: ref.read(serverUrlProvider),
      port: ref.read(serverPortProvider),
      addPort: ref.read(serverPortToggleProvider).ifNull(),
      appendApiToUrl: false, // Don't append API path yet
    );
    
    // Now properly construct the full URL
    // The pageUrl should be something like "/api/v1/manga/52/chapter/24111/page/0"
    final fullUrl = url.startsWith('/') ? "$baseApiUrl$url" : "$baseApiUrl/$url";
    
    if (kDebugMode) {
      print('Downloading page $pageIndex from URL: $url');
      print('Base API URL: $baseApiUrl');
      print('Page URL: $url');
      print('Full download URL: $fullUrl');
    }
    
    // Download directly using HTTP client with proper auth
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(fullUrl));
      
      // Add auth headers if needed
      if (authType == AuthType.basic && basicToken != null) {
        request.headers.add('Authorization', basicToken);
      }
      
      final response = await request.close();
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: Failed to download image');
      }
      
      // Collect response bytes
      final bytes = await response.fold<List<int>>(<int>[], (previous, element) => previous..addAll(element));
      
      if (kDebugMode) {
        print('Downloaded ${bytes.length} bytes for page $pageIndex');
        if (bytes.isNotEmpty) {
          final header = bytes.take(10).toList();
          print('Response header bytes: ${header.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
        }
      }
      
      if (bytes.isEmpty) {
        throw Exception('Empty response from server');
      }
      
      // Validate image format
      bool isValidImage = false;
      if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
        isValidImage = true; // JPEG
        if (kDebugMode) print('Detected JPEG format');
      } else if (bytes.length >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
        isValidImage = true; // PNG
        if (kDebugMode) print('Detected PNG format');
      } else if (bytes.length >= 12 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) {
        isValidImage = true; // WebP
        if (kDebugMode) print('Detected WebP format');
      }
      
      if (!isValidImage) {
        if (kDebugMode) {
          print('WARNING: Downloaded data does not appear to be a valid image');
          print('First 20 bytes: ${bytes.take(20).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
          // Convert to string to see if it's HTML/text error
          final text = String.fromCharCodes(bytes.take(200));
          print('As text: $text');
        }
        throw Exception('Downloaded data is not a valid image format');
      }
      
      // Write to file
      await dest.writeAsBytes(bytes);
      
      // Verify the saved file
      if (!await dest.exists()) {
        throw Exception('Failed to save file to ${dest.path}');
      }
      
      final savedBytes = await dest.readAsBytes();
      if (savedBytes.length != bytes.length) {
        throw Exception('File size mismatch: saved ${savedBytes.length} vs downloaded ${bytes.length}');
      }
      
      if (kDebugMode) {
        print('Successfully saved page $pageIndex to ${dest.path} (${savedBytes.length} bytes)');
      }
      
    } finally {
      client.close();
    }
  }

  String? _inferExtensionFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    final dot = seg.lastIndexOf('.');
    if (dot != -1) return seg.substring(dot);
    return null;
  }

  Future<void> downloadChapter(
    WidgetRef ref, {
    required int mangaId,
    required int chapterId,
    required String mangaTitle,
    required String chapterName,
    String? mangaThumbnailUrl,
  }) async {
    await downloadChapterWithProgress(
      ref as Ref,
      mangaId: mangaId,
      chapterId: chapterId,
      mangaTitle: mangaTitle,
      chapterName: chapterName,
      mangaThumbnailUrl: mangaThumbnailUrl,
    );
  }

  /// Enhanced download method with progress tracking and structured logging
  Future<void> downloadChapterWithProgress(
    Ref ref, {
    required int mangaId,
    required int chapterId,
    required String mangaTitle,
    required String chapterName,
    String? mangaThumbnailUrl,
    void Function(int pagesDownloaded, int totalPages)? onProgress,
  }) async {
    if (kDebugMode) {
      print('downloadChapterWithProgress START: manga $mangaId, chapter $chapterId');
    }
    
    final repo = ref.read(mangaBookRepositoryProvider);
    final pages = await repo.getChapterPages(chapterId: chapterId);
    final pageUrls = pages?.pages ?? const <String>[];
    if (pageUrls.isEmpty) {
      throw Exception('No pages to download for chapter $chapterId');
    }

    if (kDebugMode) {
      print('downloadChapterWithProgress: Found ${pageUrls.length} pages to download');
    }

    // Report initial progress
    onProgress?.call(0, pageUrls.length);

    final files = await _downloadPagesToChapterWithProgress(ref,
        mangaId: mangaId, 
        chapterId: chapterId, 
        pageUrls: pageUrls,
        onProgress: onProgress);

    if (kDebugMode) {
      print('downloadChapterWithProgress: Successfully downloaded ${files.length} files');
    }

    // Create enhanced manifest with page metadata
    final enhancedPages = <PageManifestEntry>[];
    
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final fileName = p.basename(file.path);
      final stat = await file.stat();
      
      // Calculate checksum for integrity checking
      String? checksum;
      try {
        final bytes = await file.readAsBytes();
        checksum = md5.convert(bytes).toString();
      } catch (e) {
        if (kDebugMode) {
          print('Failed to calculate checksum for $fileName: $e');
        }
      }
      
      // Store original URL for repair purposes
      final originalUrl = i < pageUrls.length ? pageUrls[i] : null;
      
      enhancedPages.add(PageManifestEntry(
        index: i,
        fileName: fileName,
        expectedSize: stat.size,
        checksum: checksum,
        originalUrl: originalUrl,
      ));
    }

    final manifest = LocalChapterManifest(
      manifestVersion: 2, // Enhanced manifest
      mangaId: mangaId,
      chapterId: chapterId,
      mangaTitle: mangaTitle,
      chapterName: chapterName,
      pageFiles: files.map((f) => p.basename(f.path)).toList(), // Keep for backward compatibility
      pages: enhancedPages, // Enhanced page metadata
      savedAt: DateTime.now(),
      lastValidated: DateTime.now(), // Mark as validated since we just downloaded
      mangaThumbnailUrl: mangaThumbnailUrl,
      sourceUrl: null, // Could be populated with server URL for repair
    );

    final mf = await _manifestFile(mangaId, chapterId);
    await mf.writeAsString(jsonEncode(manifest.toJson()));
    
    if (kDebugMode) {
      print('downloadChapterWithProgress MANIFEST_WRITTEN: ${mf.path}');
      print('downloadChapterWithProgress COMPLETE: chapter $chapterId');
    }

    // Report final progress
    onProgress?.call(pageUrls.length, pageUrls.length);
  }

  Future<void> deleteLocalChapter(int mangaId, int chapterId) async {
    final dir = await _chapterDir(mangaId, chapterId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<File?> getLocalPageFile(int mangaId, int chapterId, int index) async {
    final manifest = await getManifest(mangaId, chapterId);
    
    if (manifest == null) {
      if (kDebugMode) {
        print('No manifest found for manga $mangaId, chapter $chapterId');
        print('Attempting fallback: direct file system scan...');
      }
      
      // Fallback: Try to find files directly without manifest
      return await _getLocalPageFileWithoutManifest(mangaId, chapterId, index);
    }
    
    if (kDebugMode) {
      print('Manifest for chapter $chapterId has ${manifest.pageFiles.length} pages: ${manifest.pageFiles}');
      print('Requested index: $index (looking for file: ${index < manifest.pageFiles.length ? manifest.pageFiles[index] : 'OUT_OF_RANGE'})');
    }
    
    if (index < 0 || index >= manifest.pageFiles.length) {
      if (kDebugMode) {
        print('Index $index out of range for chapter $chapterId (0-${manifest.pageFiles.length - 1})');
      }
      return null;
    }
    final dir = await _chapterDir(mangaId, chapterId);
    final file = File(p.join(dir.path, manifest.pageFiles[index]));
    if (await file.exists()) {
      if (kDebugMode) {
        print('Found local file: ${file.path}');
      }
      return file;
    }
    if (kDebugMode) {
      print('Local file does not exist: ${file.path}');
    }
    return null;
  }

  /// Fallback method to find page files without manifest
  Future<File?> _getLocalPageFileWithoutManifest(int mangaId, int chapterId, int index) async {
    try {
      final dir = await _chapterDir(mangaId, chapterId);
      if (!await dir.exists()) {
        if (kDebugMode) {
          print('Chapter directory does not exist: ${dir.path}');
        }
        return null;
      }

      // List all files in the chapter directory
      final files = await dir.list().where((entity) => entity is File).cast<File>().toList();
      
      // Filter for page files and sort them
      final pageFiles = files
          .where((file) => p.basename(file.path).startsWith('page_') && 
                          (p.basename(file.path).endsWith('.jpg') || 
                           p.basename(file.path).endsWith('.png') ||
                           p.basename(file.path).endsWith('.webp')))
          .toList();
      
      // Sort by filename to ensure correct order
      pageFiles.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
      
      if (kDebugMode) {
        print('Found ${pageFiles.length} page files without manifest: ${pageFiles.map((f) => p.basename(f.path)).toList()}');
      }
      
      if (index >= 0 && index < pageFiles.length) {
        final file = pageFiles[index];
        if (kDebugMode) {
          print('Fallback found file for index $index: ${file.path}');
        }
        return file;
      }
      
      if (kDebugMode) {
        print('Fallback: Index $index out of range (0-${pageFiles.length - 1})');
      }
      return null;
      
    } catch (e) {
      if (kDebugMode) {
        print('Error in fallback file search: $e');
      }
      return null;
    }
  }

  /// Get current storage usage information
  Future<StorageUsage> getStorageUsage() async {
    try {
      final baseDir = await _baseDir();
      return await _pathResolver.calculateStorageUsage(baseDir);
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

  /// Get current storage path information
  Future<StoragePathResult> getStoragePathInfo() async {
    return await _pathResolver.resolveDownloadsPath();
  }

  /// Reset to default storage path and trigger migration
  Future<void> resetStoragePathToDefault() async {
    try {
      // Clear custom path setting
      await _ref.read(localDownloadsSettingsRepositoryProvider).clearLocalDownloadsPath();
      
      // Reset migration flag to trigger re-migration
      await _migrationManager.resetMigrationFlag();
      
      if (kDebugMode) {
        print('LocalDownloadsRepository: Storage path reset to default');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error resetting storage path: $e');
      }
      rethrow;
    }
  }

  /// Validate storage path accessibility
  Future<bool> validateStoragePath() async {
    try {
      final pathResult = await _pathResolver.resolveDownloadsPath();
      return pathResult.isReliable;
    } catch (e) {
      return false;
    }
  }

  /// Check if storage migration is needed
  Future<bool> isStorageMigrationNeeded() async {
    return await _migrationManager.isMigrationNeeded();
  }
  
  /// Perform storage migration
  Future<void> performStorageMigration() async {
    await _migrationManager.performMigration();
  }
  
  /// Clear all downloads from storage
  Future<void> clearAllDownloads() async {
    final baseDir = await _baseDir();
    
    if (baseDir.existsSync()) {
      await baseDir.delete(recursive: true);
      await baseDir.create(recursive: true);
    }
  }
}

final localDownloadsRepositoryProvider = Provider<LocalDownloadsRepository>(
  (ref) => LocalDownloadsRepository(ref),
);

final localDownloadsListProvider = FutureProvider.autoDispose((ref) async {
  return ref.read(localDownloadsRepositoryProvider).listDownloads();
});


