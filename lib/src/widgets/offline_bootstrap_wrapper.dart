import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../features/manga_book/data/offline_bootstrap_service.dart';

/// Widget that handles offline bootstrap initialization
class OfflineBootstrapWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const OfflineBootstrapWrapper({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<OfflineBootstrapWrapper> createState() => _OfflineBootstrapWrapperState();
}

class _OfflineBootstrapWrapperState extends ConsumerState<OfflineBootstrapWrapper> {
  bool _isBootstrapped = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _performBootstrap();
  }

  Future<void> _performBootstrap() async {
    try {
      if (kDebugMode) {
        print('OfflineBootstrapWrapper: Starting offline bootstrap...');
      }

      final bootstrapService = ref.read(offlineBootstrapServiceProvider);
      final result = await bootstrapService.bootstrap();

      // Update providers with bootstrap results
      ref.read(appModeProviderProvider.notifier).setMode(result.appMode);
      ref.read(offlineCatalogProviderProvider.notifier).setCatalog(result.catalog);

      if (kDebugMode) {
        print('OfflineBootstrapWrapper: Bootstrap complete');
        print('  - App mode: ${result.appMode}');
        print('  - Offline manga: ${result.catalog.manga.length}');
        print('  - Online: ${result.isOnline}');
      }

      if (mounted) {
        setState(() {
          _isBootstrapped = true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('OfflineBootstrapWrapper: Bootstrap failed: $e');
      }

      if (mounted) {
        setState(() {
          _hasError = true;
          _isBootstrapped = true; // Continue anyway
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBootstrapped) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing offline catalog...'),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}
