import 'dart:io';

/// High-level storage location abstraction (Phase 1 enhancement)
class StorageLocation {
  final StorageLocationType type;
  final Directory directory;
  final bool isReliable;
  final bool isTemporary;
  final bool viaSecurityScopedBookmark; // iOS future support
  final String description;

  const StorageLocation({
    required this.type,
    required this.directory,
    required this.isReliable,
    required this.isTemporary,
    required this.viaSecurityScopedBookmark,
    required this.description,
  });
}

/// User visible classification
enum StorageLocationType {
  custom,
  applicationSupport,
  documents,
  external,
  downloads,
  temporary,
}
