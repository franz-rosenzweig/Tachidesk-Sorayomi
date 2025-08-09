import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/offline_catalog/offline_catalog_model.dart';
import 'offline_catalog_repository.dart';

part 'offline_bootstrap_service.g.dart';

/// Enum for app mode
enum AppMode {
  online,
  offline,
  hybrid, // Has offline content but also online
}

/// Service for handling early offline/online bootstrapping
class OfflineBootstrapService {
  final OfflineCatalogRepository _catalogRepository;
  final Connectivity _connectivity;

  OfflineBootstrapService(this._catalogRepository, this._connectivity);

  /// Bootstrap the app by loading offline catalog and checking connectivity
  Future<BootstrapResult> bootstrap() async {
    if (kDebugMode) {
      print('OfflineBootstrapService: Starting bootstrap...');
    }

    // Load catalog and check connectivity in parallel
    final catalogFuture = _catalogRepository.load();
    final connectivityFuture = _checkConnectivity();

    final catalog = await catalogFuture;
    final isOnline = await connectivityFuture;

    final hasOfflineContent = catalog.manga.isNotEmpty;

    // Determine app mode
    AppMode appMode;
    if (!isOnline && !hasOfflineContent) {
      appMode = AppMode.offline; // Offline with no content
    } else if (!isOnline && hasOfflineContent) {
      appMode = AppMode.offline; // Offline with content
    } else if (isOnline && !hasOfflineContent) {
      appMode = AppMode.online; // Online only
    } else {
      appMode = AppMode.hybrid; // Online with offline content
    }

    if (kDebugMode) {
      print('OfflineBootstrapService: Bootstrap complete');
      print('  - Connectivity: ${isOnline ? 'online' : 'offline'}');
      print('  - Offline manga: ${catalog.manga.length}');
      print('  - Total chapters: ${catalog.manga.fold(0, (sum, m) => sum + m.chapters.length)}');
      print('  - App mode: $appMode');
    }

    return BootstrapResult(
      catalog: catalog,
      isOnline: isOnline,
      appMode: appMode,
    );
  }

  /// Check connectivity with timeout
  Future<bool> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity().timeout(
        const Duration(seconds: 1),
        onTimeout: () => [ConnectivityResult.none],
      );

      final isConnected = result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.ethernet) ||
          result.contains(ConnectivityResult.other);

      if (kDebugMode) {
        print('OfflineBootstrapService: Connectivity check - ${isConnected ? 'online' : 'offline'}');
      }

      return isConnected;
    } catch (e) {
      if (kDebugMode) {
        print('OfflineBootstrapService: Connectivity check failed: $e, assuming offline');
      }
      return false;
    }
  }
}

/// Result of bootstrap operation
class BootstrapResult {
  final OfflineCatalog catalog;
  final bool isOnline;
  final AppMode appMode;

  BootstrapResult({
    required this.catalog,
    required this.isOnline,
    required this.appMode,
  });
}

/// Provider for offline bootstrap service
@riverpod
OfflineBootstrapService offlineBootstrapService(Ref ref) {
  final catalogRepo = ref.watch(offlineCatalogRepositoryProvider);
  final connectivity = Connectivity();
  return OfflineBootstrapService(catalogRepo, connectivity);
}

/// Provider for app mode (computed from bootstrap)
@riverpod
class AppModeProvider extends _$AppModeProvider {
  @override
  AppMode build() {
    return AppMode.online; // Default
  }

  void setMode(AppMode mode) {
    state = mode;
  }
}

/// Provider for offline catalog state
@riverpod
class OfflineCatalogProvider extends _$OfflineCatalogProvider {
  @override
  OfflineCatalog build() {
    return const OfflineCatalog(); // Default empty
  }

  void setCatalog(OfflineCatalog catalog) {
    state = catalog;
  }

  /// Refresh catalog from disk
  Future<void> refresh() async {
    final repository = ref.read(offlineCatalogRepositoryProvider);
    final catalog = await repository.load();
    state = catalog;
  }
}
