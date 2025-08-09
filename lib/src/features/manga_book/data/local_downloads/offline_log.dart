/// Lightweight offline/download logging utility.
/// Provides leveled logging without external dependencies.

import 'package:flutter/foundation.dart';

enum OfflineLogLevel { debug, info, warn, error }

String _levelLabel(OfflineLogLevel level) {
  switch (level) {
    case OfflineLogLevel.debug:
      return 'DEBUG';
    case OfflineLogLevel.info:
      return 'INFO';
    case OfflineLogLevel.warn:
      return 'WARN';
    case OfflineLogLevel.error:
      return 'ERROR';
  }
}

/// Central logging function for offline persistence & downloads.
void logOffline(
  String message, {
  OfflineLogLevel level = OfflineLogLevel.debug,
  String component = 'general',
  Object? error,
}) {
  if (!kDebugMode && level == OfflineLogLevel.debug) return; // Skip debug in release
  final ts = DateTime.now().toIso8601String();
  final buffer = StringBuffer('[Offline][$ts][${_levelLabel(level)}][$component] ')..write(message);
  if (error != null) buffer.write(' | error=$error');
  // ignore: avoid_print
  print(buffer.toString());
}
