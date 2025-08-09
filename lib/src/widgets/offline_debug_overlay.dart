import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../features/manga_book/data/offline_bootstrap_service.dart';
import '../features/manga_book/data/local_downloads/local_downloads_repository.dart';
import '../features/manga_book/data/local_downloads/offline_log.dart';

/// Small corner overlay showing offline diagnostics in debug/profile builds.
class OfflineDebugOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const OfflineDebugOverlay({super.key, required this.child});

  @override
  ConsumerState<OfflineDebugOverlay> createState() => _OfflineDebugOverlayState();
}

class _OfflineDebugOverlayState extends ConsumerState<OfflineDebugOverlay> {
  String _storagePath = '';
  String _mode = '';
  bool _expanded = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      _refresh();
      _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    try {
      final downloadsRepo = ref.read(localDownloadsRepositoryProvider);
      final pathInfo = await downloadsRepo.getStoragePathInfo();
      final sizeInfo = await downloadsRepo.getStorageUsage();
      final mode = ref.read(appModeProviderProvider);
      if (mounted) {
        setState(() {
          _storagePath = '${pathInfo.directory.path} (${pathInfo.description}) ${sizeInfo.formattedSize}';
          _mode = mode.name;
        });
      }
    } catch (e) {
      logOffline('Overlay refresh error: $e', component: 'overlay', level: OfflineLogLevel.error);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return widget.child; // No overlay in release
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 8,
          bottom: 8,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                width: _expanded ? 320 : 160,
                child: DefaultTextStyle(
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Mode: $_mode'),
                      const SizedBox(height: 2),
                      if (_expanded) ...[
                        const Text('Storage:'),
                        Text(_storagePath, maxLines: 4, overflow: TextOverflow.ellipsis),
                      ] else ...[
                        Text(_storagePath, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(_expanded ? 'Tap to collapse' : 'Tap for details', style: const TextStyle(fontSize: 9, color: Colors.white70)),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
