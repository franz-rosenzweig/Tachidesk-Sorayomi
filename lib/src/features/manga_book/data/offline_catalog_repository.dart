import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/offline_catalog/offline_catalog_model.dart';
import 'local_downloads/local_downloads_repository.dart';

part 'offline_catalog_repository.g.dart';

/// Repository for managing the offline catalog of downloaded manga and chapters
class OfflineCatalogRepository {
  static const String catalogFileName = 'offline_catalog.json';
  static const String catalogDirName = 'catalog';
  static const String coversDirName = 'covers';

  final LocalDownloadsRepository _downloadsRepository;
  
  // Debounced write state
  Timer? _writeTimer;
  OfflineCatalog? _pendingCatalog;

  OfflineCatalogRepository(this._downloadsRepository);

  /// Get the catalog directory path
  Future<Directory> _catalogDir() async {
    final baseDir = await _downloadsRepository.getBaseDirectory();
    final dir = Directory(p.join(baseDir.path, catalogDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Get the covers directory path
  Future<Directory> _coversDir() async {
    final catalogDir = await _catalogDir();
    final dir = Directory(p.join(catalogDir.path, coversDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Get the catalog file path
  Future<File> _catalogFile() async {
    final catalogDir = await _catalogDir();
    return File(p.join(catalogDir.path, catalogFileName));
  }

  /// Load the offline catalog from disk
  Future<OfflineCatalog> load() async {
    try {
      final file = await _catalogFile();
      if (!await file.exists()) {
        if (kDebugMode) {
          print('OfflineCatalogRepository: No catalog file found, returning empty catalog');
        }
        return const OfflineCatalog();
      }

      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final catalog = OfflineCatalog.fromJson(jsonData);
      
      if (kDebugMode) {
        print('OfflineCatalogRepository: Loaded catalog with ${catalog.manga.length} manga entries');
      }
      
      return catalog;
    } catch (e) {
      if (kDebugMode) {
        print('OfflineCatalogRepository: Error loading catalog: $e');
        print('OfflineCatalogRepository: Attempting to rebuild from manifests...');
      }
      
      // Fallback: rebuild from existing manifests
      return await rebuildFromManifests();
    }
  }

  /// Save the catalog to disk (immediate)
  Future<void> save(OfflineCatalog catalog) async {
    try {
      final file = await _catalogFile();
      final tempFile = File('${file.path}.tmp');
      
      // Add timestamp
      final catalogWithTimestamp = catalog.copyWith(
        lastUpdated: DateTime.now(),
      );
      
      // Write to temp file first for atomic operation
      await tempFile.writeAsString(
        jsonEncode(catalogWithTimestamp.toJson()),
        flush: true,
      );
      
      // Atomic rename
      await tempFile.rename(file.path);
      
      if (kDebugMode) {
        print('OfflineCatalogRepository: Saved catalog with ${catalog.manga.length} manga entries');
      }
    } catch (e) {
      if (kDebugMode) {
        print('OfflineCatalogRepository: Error saving catalog: $e');
      }
      rethrow;
    }
  }

  /// Save the catalog with debounced writes (500ms delay)
  Future<void> saveDebounced(OfflineCatalog catalog) async {
    _pendingCatalog = catalog;
    
    // Cancel existing timer
    _writeTimer?.cancel();
    
    // Set new timer
    _writeTimer = Timer(const Duration(milliseconds: 500), () async {
      if (_pendingCatalog != null) {
        try {
          await save(_pendingCatalog!);
          _pendingCatalog = null;
        } catch (e) {
          if (kDebugMode) {
            print('OfflineCatalogRepository: Debounced save failed: $e');
          }
        }
      }
    });
  }

  /// Rebuild catalog from existing manifests
  Future<OfflineCatalog> rebuildFromManifests() async {
    if (kDebugMode) {
      print('OfflineCatalogRepository: Rebuilding catalog from manifests...');
    }
    
    try {
      final manifests = await _downloadsRepository.listDownloads();
      final mangaMap = <int, MangaEntry>{};
      
      for (final manifest in manifests) {
        // Get or create manga entry
        MangaEntry mangaEntry;
        if (mangaMap.containsKey(manifest.mangaId)) {
          mangaEntry = mangaMap[manifest.mangaId]!;
        } else {
          mangaEntry = MangaEntry(
            mangaId: manifest.mangaId,
            sourceId: 'unknown', // Will be enriched later
            title: manifest.mangaTitle,
            lastUpdated: manifest.savedAt.millisecondsSinceEpoch,
          );
        }
        
        // Create chapter entry
        final chapterEntry = ChapterEntry(
          chapterId: manifest.chapterId,
          mangaId: manifest.mangaId,
          name: manifest.chapterName,
          number: _extractChapterNumber(manifest.chapterName),
          pageCount: manifest.pageCount,
          downloadedAt: manifest.savedAt.millisecondsSinceEpoch,
          readPage: 0, // Default, will be updated by read progress
        );
        
        // Add chapter to manga entry
        final updatedChapters = [...mangaEntry.chapters, chapterEntry];
        mangaEntry = mangaEntry.copyWith(chapters: updatedChapters);
        mangaMap[manifest.mangaId] = mangaEntry;
      }
      
      final manga = mangaMap.values.toList();
      
      // Sort chapters by number within each manga
      final sortedManga = manga.map((m) {
        final sortedChapters = [...m.chapters];
        sortedChapters.sort((a, b) => a.number.compareTo(b.number));
        return m.copyWith(chapters: sortedChapters);
      }).toList();
      
      final catalog = OfflineCatalog(
        schema: 1,
        manga: sortedManga,
        lastUpdated: DateTime.now(),
      );
      
      if (kDebugMode) {
        print('OfflineCatalogRepository: Rebuilt catalog with ${catalog.manga.length} manga, total ${catalog.manga.fold(0, (sum, m) => sum + m.chapters.length)} chapters');
      }
      
      // Save the rebuilt catalog
      await save(catalog);
      return catalog;
      
    } catch (e) {
      if (kDebugMode) {
        print('OfflineCatalogRepository: Error rebuilding catalog: $e');
      }
      return const OfflineCatalog();
    }
  }

  /// Upsert a manga entry in the catalog
  Future<void> upsertManga(OfflineCatalog catalog, MangaEntry mangaEntry) async {
    final existingIndex = catalog.manga.indexWhere((m) => m.mangaId == mangaEntry.mangaId);
    
    List<MangaEntry> updatedManga;
    if (existingIndex >= 0) {
      // Update existing entry, preserving chapters
      final existing = catalog.manga[existingIndex];
      final merged = mangaEntry.copyWith(chapters: existing.chapters);
      updatedManga = [...catalog.manga];
      updatedManga[existingIndex] = merged;
    } else {
      // Add new entry
      updatedManga = [...catalog.manga, mangaEntry];
    }
    
    final updatedCatalog = catalog.copyWith(manga: updatedManga);
    await saveDebounced(updatedCatalog);
  }

  /// Upsert a chapter entry in the catalog
  Future<void> upsertChapter(OfflineCatalog catalog, int mangaId, ChapterEntry chapterEntry) async {
    final mangaIndex = catalog.manga.indexWhere((m) => m.mangaId == mangaId);
    
    if (mangaIndex < 0) {
      if (kDebugMode) {
        print('OfflineCatalogRepository: Warning - manga $mangaId not found when upserting chapter ${chapterEntry.chapterId}');
      }
      return;
    }
    
    final manga = catalog.manga[mangaIndex];
    final chapterIndex = manga.chapters.indexWhere((c) => c.chapterId == chapterEntry.chapterId);
    
    List<ChapterEntry> updatedChapters;
    if (chapterIndex >= 0) {
      // Update existing chapter
      updatedChapters = [...manga.chapters];
      updatedChapters[chapterIndex] = chapterEntry;
    } else {
      // Add new chapter
      updatedChapters = [...manga.chapters, chapterEntry];
      // Sort by chapter number
      updatedChapters.sort((a, b) => a.number.compareTo(b.number));
    }
    
    final updatedManga = manga.copyWith(chapters: updatedChapters);
    final allManga = [...catalog.manga];
    allManga[mangaIndex] = updatedManga;
    
    final updatedCatalog = catalog.copyWith(manga: allManga);
    await saveDebounced(updatedCatalog);
  }

  /// Get all manga from catalog
  List<MangaEntry> listManga(OfflineCatalog catalog) {
    return catalog.manga;
  }

  /// Get chapters for a specific manga
  List<ChapterEntry> listChapters(OfflineCatalog catalog, int mangaId) {
    final manga = catalog.manga.firstWhere(
      (m) => m.mangaId == mangaId,
      orElse: () => throw OfflineCatalogMissingException('Manga $mangaId not found in offline catalog'),
    );
    return manga.chapters;
  }

  /// Check if a chapter exists in the catalog
  bool hasChapter(OfflineCatalog catalog, int mangaId, int chapterId) {
    try {
      final chapters = listChapters(catalog, mangaId);
      return chapters.any((c) => c.chapterId == chapterId);
    } catch (e) {
      return false;
    }
  }

  /// Update read progress for a chapter
  Future<void> updateReadProgress(OfflineCatalog catalog, int mangaId, int chapterId, int pageIndex) async {
    try {
      final chapters = listChapters(catalog, mangaId);
      final chapterIndex = chapters.indexWhere((c) => c.chapterId == chapterId);
      
      if (chapterIndex >= 0) {
        final updatedChapter = chapters[chapterIndex].copyWith(readPage: pageIndex);
        await upsertChapter(catalog, mangaId, updatedChapter);
      }
    } catch (e) {
      if (kDebugMode) {
        print('OfflineCatalogRepository: Error updating read progress: $e');
      }
    }
  }

  /// Extract chapter number from chapter name (best effort)
  double _extractChapterNumber(String chapterName) {
    // Try to extract number from common patterns
    final patterns = [
      RegExp(r'Chapter (\d+(?:\.\d+)?)', caseSensitive: false),
      RegExp(r'Ch\.? (\d+(?:\.\d+)?)', caseSensitive: false),
      RegExp(r'^(\d+(?:\.\d+)?)'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(chapterName);
      if (match != null) {
        final numberStr = match.group(1);
        if (numberStr != null) {
          return double.tryParse(numberStr) ?? 0.0;
        }
      }
    }
    
    return 0.0; // Default if no number found
  }

  /// Dispose and cleanup
  void dispose() {
    _writeTimer?.cancel();
  }
}

@riverpod
OfflineCatalogRepository offlineCatalogRepository(Ref ref) {
  final downloadsRepo = LocalDownloadsRepository(ref);
  final catalogRepo = OfflineCatalogRepository(downloadsRepo);
  
  ref.onDispose(() {
    catalogRepo.dispose();
  });
  
  return catalogRepo;
}
