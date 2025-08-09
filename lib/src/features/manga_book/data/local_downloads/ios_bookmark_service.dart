import 'dart:io';
import 'package:flutter/services.dart';

/// iOS security-scoped bookmark bridge. No-ops on non-iOS.
class IOSBookmarkService {
  static const _channel = MethodChannel('sorayomi.storage/bookmark');

  bool get supported => Platform.isIOS;

  Future<IOSBookmarkResult> pickFolderAndCreateBookmark() async {
    if (!supported) return IOSBookmarkResult.unsupported();
    try {
      final data = await _channel.invokeMethod<dynamic>('bookmarkFolder');
      if (data is ByteData) {
        return IOSBookmarkResult(bookmark: data, path: null, status: IOSBookmarkStatus.created);
      }
      return IOSBookmarkResult.failure('Unexpected result type ${data.runtimeType}');
    } on PlatformException catch (e) {
      return IOSBookmarkResult.failure(e.message ?? 'Platform error');
    }
  }

  Future<IOSBookmarkResolution> resolveBookmark(ByteData bookmark) async {
    if (!supported) return IOSBookmarkResolution.unsupported();
    try {
      final path = await _channel.invokeMethod<String>('resolveBookmark', {
        'bookmark': bookmark,
      });
      if (path == null) {
        return IOSBookmarkResolution.failure('Null path resolved');
      }
      return IOSBookmarkResolution(path: path, status: IOSBookmarkStatus.resolved);
    } on PlatformException catch (e) {
      return IOSBookmarkResolution.failure(e.message ?? 'Platform error');
    }
  }
}

enum IOSBookmarkStatus { created, resolved, unsupported, failed }

class IOSBookmarkResult {
  final ByteData? bookmark;
  final String? path;
  final IOSBookmarkStatus status;
  final String? error;
  const IOSBookmarkResult({this.bookmark, this.path, required this.status, this.error});
  factory IOSBookmarkResult.failure(String error) => IOSBookmarkResult(status: IOSBookmarkStatus.failed, error: error);
  factory IOSBookmarkResult.unsupported() => const IOSBookmarkResult(status: IOSBookmarkStatus.unsupported);
}

class IOSBookmarkResolution {
  final String? path;
  final IOSBookmarkStatus status;
  final String? error;
  const IOSBookmarkResolution({this.path, required this.status, this.error});
  factory IOSBookmarkResolution.failure(String error) => IOSBookmarkResolution(status: IOSBookmarkStatus.failed, error: error);
  factory IOSBookmarkResolution.unsupported() => const IOSBookmarkResolution(status: IOSBookmarkStatus.unsupported);
}
