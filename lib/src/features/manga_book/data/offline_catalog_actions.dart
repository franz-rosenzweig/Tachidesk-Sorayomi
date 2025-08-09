import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'offline_catalog_repository.dart';

part 'offline_catalog_actions.g.dart';

@riverpod
class OfflineCatalogRebuildController extends _$OfflineCatalogRebuildController {
  @override
  FutureOr<void> build() {}

  Future<void> rebuild() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(offlineCatalogRepositoryProvider);
      final catalog = await repo.rebuildFromManifests();
      if (kDebugMode) {
        print('OfflineCatalogRebuildController: Rebuild done manga=${catalog.manga.length}');
      }
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
