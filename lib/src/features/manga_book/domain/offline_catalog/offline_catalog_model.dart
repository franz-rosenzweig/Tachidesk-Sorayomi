// Enhanced offline catalog models for persistent manga/chapter metadata

import 'package:freezed_annotation/freezed_annotation.dart';

part 'offline_catalog_model.freezed.dart';
part 'offline_catalog_model.g.dart';

@freezed
class OfflineCatalog with _$OfflineCatalog {
  const factory OfflineCatalog({
    @Default(1) int schema,
    @Default([]) List<MangaEntry> manga,
    DateTime? lastUpdated,
  }) = _OfflineCatalog;

  factory OfflineCatalog.fromJson(Map<String, dynamic> json) =>
      _$OfflineCatalogFromJson(json);
}

@freezed 
class MangaEntry with _$MangaEntry {
  const factory MangaEntry({
    required int mangaId,
    required String sourceId,
    required String title,
    String? cover,
    int? lastUpdated,
    @Default([]) List<ChapterEntry> chapters,
  }) = _MangaEntry;

  factory MangaEntry.fromJson(Map<String, dynamic> json) =>
      _$MangaEntryFromJson(json);
}

@freezed
class ChapterEntry with _$ChapterEntry {
  const factory ChapterEntry({
    required int chapterId,
    required int mangaId,
    required String name,
    required double number,
    required int pageCount,
    required int downloadedAt,
    @Default(0) int readPage,
  }) = _ChapterEntry;

  factory ChapterEntry.fromJson(Map<String, dynamic> json) =>
      _$ChapterEntryFromJson(json);
}

/// Exception for when a chapter is not available in the offline catalog
class OfflineCatalogMissingException implements Exception {
  final String message;
  OfflineCatalogMissingException(this.message);
  
  @override
  String toString() => 'OfflineCatalogMissingException: $message';
}
