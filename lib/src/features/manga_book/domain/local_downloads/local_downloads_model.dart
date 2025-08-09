// Enhanced model types for local downloads manifest with integrity support

class PageManifestEntry {
  final int index;
  final String fileName;
  final int expectedSize;
  final String? checksum; // Optional MD5/SHA-1
  final String? originalUrl; // For repair

  PageManifestEntry({
    required this.index,
    required this.fileName,
    required this.expectedSize,
    this.checksum,
    this.originalUrl,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'fileName': fileName,
        'expectedSize': expectedSize,
        if (checksum != null) 'checksum': checksum,
        if (originalUrl != null) 'originalUrl': originalUrl,
      };

  static PageManifestEntry fromJson(Map<String, dynamic> json) =>
      PageManifestEntry(
        index: json['index'] as int,
        fileName: json['fileName'] as String,
        expectedSize: json['expectedSize'] as int,
        checksum: json['checksum'] as String?,
        originalUrl: json['originalUrl'] as String?,
      );
}

class LocalChapterManifest {
  final int manifestVersion; // Start with v2
  final int mangaId;
  final int chapterId;
  final String mangaTitle;
  final String chapterName;
  final List<String> pageFiles; // relative file names within chapter folder (legacy)
  final List<PageManifestEntry>? pages; // Enhanced page entries with metadata
  final DateTime savedAt;
  final DateTime? lastValidated;
  final String? mangaThumbnailUrl; // optional, may store downloaded later
  final String? sourceUrl; // For repair requests
  final String? integrityStatus; // ok / partial / corrupt / unknown
  final int? missingPageCount; // last validation result

  LocalChapterManifest({
    this.manifestVersion = 2,
    required this.mangaId,
    required this.chapterId,
    required this.mangaTitle,
    required this.chapterName,
    required this.pageFiles,
    this.pages,
    required this.savedAt,
    this.lastValidated,
    this.mangaThumbnailUrl,
    this.sourceUrl,
  this.integrityStatus,
  this.missingPageCount,
  });

  // Helper to get page count
  int get pageCount => pages?.length ?? pageFiles.length;

  // Helper to check if this is enhanced manifest
  bool get isEnhanced => manifestVersion >= 2 && pages != null;

  Map<String, dynamic> toJson() => {
        'manifestVersion': manifestVersion,
        'mangaId': mangaId,
        'chapterId': chapterId,
        'mangaTitle': mangaTitle,
        'chapterName': chapterName,
        'pageFiles': pageFiles,
        if (pages != null) 'pages': pages!.map((p) => p.toJson()).toList(),
        'savedAt': savedAt.toIso8601String(),
        if (lastValidated != null) 'lastValidated': lastValidated!.toIso8601String(),
        if (mangaThumbnailUrl != null) 'mangaThumbnailUrl': mangaThumbnailUrl,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
  if (integrityStatus != null) 'integrityStatus': integrityStatus,
  if (missingPageCount != null) 'missingPageCount': missingPageCount,
      };

  static LocalChapterManifest fromJson(Map<String, dynamic> json) {
    final version = json['manifestVersion'] as int? ?? 1;
    
    // Parse enhanced pages if available
    List<PageManifestEntry>? pages;
    if (json['pages'] != null) {
      pages = (json['pages'] as List<dynamic>)
          .map((p) => PageManifestEntry.fromJson(p as Map<String, dynamic>))
          .toList();
    }

    return LocalChapterManifest(
      manifestVersion: version,
      mangaId: json['mangaId'] as int,
      chapterId: json['chapterId'] as int,
      mangaTitle: json['mangaTitle'] as String? ?? '',
      chapterName: json['chapterName'] as String? ?? '',
      pageFiles: (json['pageFiles'] as List<dynamic>? ?? const []).cast<String>(),
      pages: pages,
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastValidated: json['lastValidated'] != null 
          ? DateTime.tryParse(json['lastValidated'] as String)
          : null,
      mangaThumbnailUrl: json['mangaThumbnailUrl'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
  integrityStatus: json['integrityStatus'] as String?,
  missingPageCount: json['missingPageCount'] as int?,
    );
  }

  // Create enhanced manifest from legacy manifest
  LocalChapterManifest upgradeToV2({
    List<PageManifestEntry>? enhancedPages,
    String? sourceUrl,
  }) {
    return LocalChapterManifest(
      manifestVersion: 2,
      mangaId: mangaId,
      chapterId: chapterId,
      mangaTitle: mangaTitle,
      chapterName: chapterName,
      pageFiles: pageFiles,
      pages: enhancedPages,
      savedAt: savedAt,
      lastValidated: DateTime.now(),
      mangaThumbnailUrl: mangaThumbnailUrl,
      sourceUrl: sourceUrl,
  integrityStatus: integrityStatus,
  missingPageCount: missingPageCount,
    );
  }
}
