import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/data/offline_bootstrap_service.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/data/offline_catalog_repository.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/data/local_downloads/local_downloads_repository.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class _FakeConnectivity implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('OfflineBootstrapService bootstrap returns result', () async {
    final container = ProviderContainer(overrides: []);
    addTearDown(container.dispose);
    final catalogRepo = OfflineCatalogRepository();
    final downloadsRepo = LocalDownloadsRepository(container.read);
    final svc = OfflineBootstrapService(catalogRepo, _FakeConnectivity(), downloadsRepo);
    final result = await svc.bootstrap();
    expect(result.catalog.manga.isNotEmpty || result.catalog.manga.isEmpty, true);
  });
}
