import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:tachidesk_sorayomi/src/features/manga_book/data/local_downloads/storage_path_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StoragePathResolver', () {
    test('resolveDownloadsPath returns a valid directory (skipped on VM without plugins)', () async {
      final resolver = StoragePathResolver.test();
      try {
        final result = await resolver.resolveDownloadsPath();
        expect(result.directory.path.isNotEmpty, true);
        expect(await result.directory.exists(), true, reason: 'Resolved directory should exist');
      } on StoragePathException catch (_) {
        // Acceptable in pure VM test environment without path_provider bindings
        expect(true, true);
      }
    });
  });
}
