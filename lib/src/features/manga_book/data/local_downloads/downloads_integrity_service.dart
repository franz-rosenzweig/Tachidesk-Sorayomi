import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'local_downloads_repository.dart';
import '../../domain/local_downloads/local_downloads_model.dart';
import 'offline_log.dart';

class DownloadsIntegrityReport {
  final int chaptersChecked;
  final int pagesChecked;
  final int missingFiles;
  final int sizeMismatches;
  final Duration elapsed;
  final Map<String, ChapterIntegrityStatus> chapterStatuses; // key: mangaId:chapterId
  const DownloadsIntegrityReport({
    required this.chaptersChecked,
    required this.pagesChecked,
    required this.missingFiles,
    required this.sizeMismatches,
    required this.elapsed,
    required this.chapterStatuses,
  });
}

enum ChapterIntegrityStatus { ok, partial, corrupt }

class DownloadsIntegrityService {
  final LocalDownloadsRepository _repo;
  DownloadsIntegrityService(this._repo);

  /// Incremental repair of only missing/mismatched pages. Returns count repaired.
  Future<int> repairChapter(LocalChapterManifest m, {Ref? ref}) async {
    if (!m.isEnhanced) return 0;
    if (ref == null) return 0;
    int repaired = 0;
    final chapterDir = await _repo.getChapterDirectory(m.mangaId, m.chapterId);
    for (final entry in m.pages!) {
      final file = File(p.join(chapterDir.path, entry.fileName));
      bool bad = false;
      if (!await file.exists()) {
        bad = true;
      } else if (entry.expectedSize > 0) {
        final stat = await file.stat();
        if (stat.size != entry.expectedSize) bad = true;
      }
      if (bad && entry.originalUrl != null) {
        try {
          final client = HttpClient();
          try {
            final req = await client.getUrl(Uri.parse(entry.originalUrl!));
            final res = await req.close();
            if (res.statusCode == 200) {
              final bytes = await res.fold<List<int>>(<int>[], (p, e) => p..addAll(e));
              await file.writeAsBytes(bytes, flush: true);
              repaired++;
            } else {
              logOffline('Repair HTTP ${res.statusCode} page=${entry.index}', component: 'integrity', level: OfflineLogLevel.warn);
            }
          } finally { client.close(); }
        } catch (e) {
          logOffline('Single-page repair failed page=${entry.index} chapter=${m.chapterId} error=$e', component: 'integrity', level: OfflineLogLevel.warn);
        }
      }
    }
    return repaired;
  }

  Future<DownloadsIntegrityReport> validateAll() async {
    final start = DateTime.now();
    int chapters = 0;
    int pages = 0;
    int missing = 0;
    int sizeBad = 0;

    final manifests = await _repo.listDownloads();
    final chapterStatuses = <String, ChapterIntegrityStatus>{};
    for (final m in manifests) {
      chapters++;
      final dir = await _repo.getChapterDirectory(m.mangaId, m.chapterId);
      int missingForChapter = 0;
      int mismatchForChapter = 0;
      for (final pageName in m.pageFiles) {
        pages++;
        final f = File(p.join(dir.path, pageName));
        if (!await f.exists()) {
          missing++;
          missingForChapter++;
          continue;
        }
        if (m.isEnhanced) {
          final entry = m.pages!.firstWhere((e) => e.fileName == pageName, orElse: () => PageManifestEntry(index: -1, fileName: pageName, expectedSize: -1));
          if (entry.expectedSize > 0) {
            final stat = await f.stat();
            if (stat.size != entry.expectedSize) { sizeBad++; mismatchForChapter++; }
          }
        }
      }
      final key = '${m.mangaId}:${m.chapterId}';
      if (missingForChapter == 0 && mismatchForChapter == 0) {
        chapterStatuses[key] = ChapterIntegrityStatus.ok;
      } else if (missingForChapter < m.pageFiles.length) {
        chapterStatuses[key] = ChapterIntegrityStatus.partial;
      } else {
        chapterStatuses[key] = ChapterIntegrityStatus.corrupt;
      }
  // Update lastValidated + integrity metadata in manifest
      try {
        await _repo.saveManifest(m.mangaId, m.chapterId, LocalChapterManifest(
          manifestVersion: m.manifestVersion,
          mangaId: m.mangaId,
          chapterId: m.chapterId,
          mangaTitle: m.mangaTitle,
            chapterName: m.chapterName,
            pageFiles: m.pageFiles,
            pages: m.pages,
            savedAt: m.savedAt,
            lastValidated: DateTime.now(),
            mangaThumbnailUrl: m.mangaThumbnailUrl,
            sourceUrl: m.sourceUrl,
    integrityStatus: chapterStatuses[key]!.name,
    missingPageCount: missingForChapter,
        ));
      } catch (_) {}
    }

    final report = DownloadsIntegrityReport(
      chaptersChecked: chapters,
      pagesChecked: pages,
      missingFiles: missing,
      sizeMismatches: sizeBad,
      elapsed: DateTime.now().difference(start),
      chapterStatuses: chapterStatuses,
    );

    logOffline('Integrity validate chapters=$chapters pages=$pages missing=$missing sizeMismatches=$sizeBad elapsedMs=${report.elapsed.inMilliseconds}', component: 'integrity', level: OfflineLogLevel.info);
    return report;
  }
}

final downloadsIntegrityServiceProvider = Provider<DownloadsIntegrityService>((ref) => DownloadsIntegrityService(ref.read(localDownloadsRepositoryProvider)));

/// Simple in-memory cache of latest integrity report for UI badges.
class IntegrityStatusCache extends StateNotifier<Map<String, ChapterIntegrityStatus>> {
  IntegrityStatusCache(): super(const {});
  void updateFromReport(DownloadsIntegrityReport report) => state = report.chapterStatuses;
}

final integrityStatusCacheProvider = StateNotifierProvider<IntegrityStatusCache, Map<String, ChapterIntegrityStatus>>((ref) => IntegrityStatusCache());
