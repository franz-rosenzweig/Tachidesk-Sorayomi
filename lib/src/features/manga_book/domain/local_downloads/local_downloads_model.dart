// Basic model types for local downloads manifest

class LocalChapterManifest {
  final int mangaId;
  final int chapterId;
  final String mangaTitle;
  final String chapterName;
  final List<String> pageFiles; // relative file names within chapter folder
  final DateTime savedAt;
  final String? mangaThumbnailUrl; // optional, may store downloaded later

  LocalChapterManifest({
    required this.mangaId,
    required this.chapterId,
    required this.mangaTitle,
    required this.chapterName,
    required this.pageFiles,
    required this.savedAt,
    this.mangaThumbnailUrl,
  });

  Map<String, dynamic> toJson() => {
        'mangaId': mangaId,
        'chapterId': chapterId,
        'mangaTitle': mangaTitle,
        'chapterName': chapterName,
        'pageFiles': pageFiles,
        'savedAt': savedAt.toIso8601String(),
        'mangaThumbnailUrl': mangaThumbnailUrl,
      };

  static LocalChapterManifest fromJson(Map<String, dynamic> json) =>
      LocalChapterManifest(
        mangaId: json['mangaId'] as int,
        chapterId: json['chapterId'] as int,
        mangaTitle: json['mangaTitle'] as String? ?? '',
        chapterName: json['chapterName'] as String? ?? '',
        pageFiles:
            (json['pageFiles'] as List<dynamic>? ?? const []).cast<String>(),
        savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        mangaThumbnailUrl: json['mangaThumbnailUrl'] as String?,
      );
}
