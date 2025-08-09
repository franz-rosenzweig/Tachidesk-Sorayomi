import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:tachidesk_sorayomi/src/features/manga_book/data/local_downloads/local_downloads_repository.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/data/local_downloads/downloads_integrity_service.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/data/local_downloads/storage_path_resolver.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/data/local_downloads/local_downloads_settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('DownloadsIntegrityService', () {
    test('validateAll returns a report even with empty downloads', () async {
  final settings = _InMemorySettingsRepo();
  final repo = LocalDownloadsRepository.test(settings);
      final service = DownloadsIntegrityService(repo);

      // Ensure base directory exists
      final baseInfo = await repo.getStoragePathInfo();
      expect(await baseInfo.directory.exists(), true);

      final report = await service.validateAll();
      expect(report.chaptersChecked >= 0, true);
      expect(report.pagesChecked >= 0, true);
      expect(report.missingFiles >= 0, true);
    });
  });
}

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
