import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../utils/extensions/cache_manager_extensions.dart';
import '../../domain/local_downloads/local_downloads_model.dart';
import '../manga_book/manga_book_repository.dart';

class LocalDownloadsRepository {
  static const downloadsFolderName = 'sorayomi_downloads';
  static const manifestFileName = 'manifest.json';

  Future<Directory> _baseDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, downloadsFolderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
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
    final base = await _baseDir();
    final results = <LocalChapterManifest>[];
    if (!await base.exists()) return results;
    await for (final entity in base.list(recursive: true)) {
      if (entity is File && p.basename(entity.path) == manifestFileName) {
        try {
          final data = jsonDecode(await entity.readAsString())
              as Map<String, dynamic>;
          results.add(LocalChapterManifest.fromJson(data));
        } catch (_) {/* skip bad manifest */}
      }
    }
    // Sort newest first
    results.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return results;
  }

  // Returns saved files (absolute paths)
  Future<List<File>> _downloadPagesToChapter(
    WidgetRef ref, {
    required int mangaId,
    required int chapterId,
    required List<String> pageUrls,
  }) async {
    final dir = await _chapterDir(mangaId, chapterId);
    final cache = DefaultCacheManager();
    final saved = <File>[];

    for (var i = 0; i < pageUrls.length; i++) {
      final url = pageUrls[i];
      // Reuse existing auth-aware fetch
      final cached = await cache.getServerFile(ref, url);
      final ext = _inferExtensionFromUrl(url) ?? '.jpg';
      final fileName = 'page_${(i + 1).toString().padLeft(4, '0')}$ext';
      final dest = File(p.join(dir.path, fileName));
      try {
        await cached.copy(dest.path);
        saved.add(dest);
      } catch (e) {
        if (kDebugMode) {
          print('Failed to copy page $i for chapter $chapterId: $e');
        }
        rethrow;
      }
    }
    return saved;
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
  }) async {
    final repo = ref.read(mangaBookRepositoryProvider);
    final pages = await repo.getChapterPages(chapterId: chapterId);
    final pageUrls = pages?.pages ?? const <String>[];
    if (pageUrls.isEmpty) {
      throw Exception('No pages to download for chapter $chapterId');
    }

    final files = await _downloadPagesToChapter(ref,
        mangaId: mangaId, chapterId: chapterId, pageUrls: pageUrls);

    final manifest = LocalChapterManifest(
      mangaId: mangaId,
      chapterId: chapterId,
      mangaTitle: mangaTitle,
      chapterName: chapterName,
      pageFiles: files.map((f) => p.basename(f.path)).toList(),
      savedAt: DateTime.now(),
    );

    final mf = await _manifestFile(mangaId, chapterId);
    await mf.writeAsString(jsonEncode(manifest.toJson()));
  }

  Future<void> deleteLocalChapter(int mangaId, int chapterId) async {
    final dir = await _chapterDir(mangaId, chapterId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<File?> getLocalPageFile(int mangaId, int chapterId, int index) async {
    final manifest = await getManifest(mangaId, chapterId);
    if (manifest == null) return null;
    if (index < 0 || index >= manifest.pageFiles.length) return null;
    final dir = await _chapterDir(mangaId, chapterId);
    final file = File(p.join(dir.path, manifest.pageFiles[index]));
    if (await file.exists()) return file;
    return null;
  }
}

final localDownloadsRepositoryProvider = Provider<LocalDownloadsRepository>(
  (ref) => LocalDownloadsRepository(),
);

final localDownloadsListProvider = FutureProvider.autoDispose((ref) async {
  return ref.read(localDownloadsRepositoryProvider).listDownloads();
});

final isChapterDownloadedProvider = FutureProvider.family<bool, (int mangaId, int chapterId)>(
  (ref, ids) async {
    return ref
        .read(localDownloadsRepositoryProvider)
        .isChapterDownloaded(ids.$1, ids.$2);
  },
);
