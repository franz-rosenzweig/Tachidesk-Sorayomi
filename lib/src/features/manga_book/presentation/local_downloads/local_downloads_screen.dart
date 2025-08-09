import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/router_config.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../widgets/server_image.dart';
import '../../data/local_downloads/local_downloads_repository.dart';
import '../../domain/local_downloads/local_downloads_model.dart';

class LocalDownloadsScreen extends ConsumerWidget {
  const LocalDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(localDownloadsListProvider);
    return list.when(
      data: (items) {
        if (items.isEmpty) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(context.l10n.noDownloads),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  // Debug info about the directory we're checking
                  await ref.read(localDownloadsRepositoryProvider).debugBaseDirectory();
                  
                  await ref.read(localDownloadsRepositoryProvider).resetToDefaultPath();
                  ref.invalidate(localDownloadsListProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reset downloads path to default')),
                    );
                  }
                },
                child: const Text('Reset Downloads Path'),
              ),
            ],
          );
        }
        
        // Group items by manga
        final groupedByManga = <int, List<LocalChapterManifest>>{};
        for (final item in items) {
          groupedByManga.putIfAbsent(item.mangaId, () => []).add(item);
        }
        
        return ListView.separated(
          itemCount: groupedByManga.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final mangaId = groupedByManga.keys.elementAt(index);
            final chapters = groupedByManga[mangaId]!;
            return _MangaDownloadTile(mangaId: mangaId, chapters: chapters);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Error: ${e.toString()}'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              await ref.read(localDownloadsRepositoryProvider).resetToDefaultPath();
              ref.invalidate(localDownloadsListProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reset downloads path to default')),
                );
              }
            },
            child: const Text('Fix Downloads Path'),
          ),
        ],
      ),
    );
  }
}

class _MangaDownloadTile extends ConsumerStatefulWidget {
  const _MangaDownloadTile({required this.mangaId, required this.chapters});
  final int mangaId;
  final List<LocalChapterManifest> chapters;

  @override
  ConsumerState<_MangaDownloadTile> createState() => _MangaDownloadTileState();
}

class _MangaDownloadTileState extends ConsumerState<_MangaDownloadTile> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Use the first chapter for manga info
    final firstChapter = widget.chapters.first;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            leading: SizedBox(
              width: 56,
              height: 80,
              child: firstChapter.mangaThumbnailUrl != null
                  ? ServerImage(
                      imageUrl: firstChapter.mangaThumbnailUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                      ),
                    ),
            ),
            title: Text(
              firstChapter.mangaTitle,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${widget.chapters.length} chapter${widget.chapters.length != 1 ? 's' : ''} downloaded',
              style: context.textTheme.bodySmall,
            ),
            trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
            onTap: () {
              setState(() {
                isExpanded = !isExpanded;
              });
            },
          ),
          if (isExpanded)
            // List of chapters
            ...widget.chapters.map((chapter) => _ChapterDownloadTile(item: chapter)),
        ],
      ),
    );
  }
}

class _ChapterDownloadTile extends ConsumerWidget {
  const _ChapterDownloadTile({required this.item});
  final LocalChapterManifest item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 72, right: 16),
      title: Text(
        item.chapterName,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodyMedium,
      ),
      subtitle: Text(
        '${item.pageFiles.length} pages • ${_formatDate(item.savedAt)}',
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodySmall?.copyWith(
          color: Colors.grey[600],
        ),
      ),
      onTap: () {
        // Navigate to the standard reader which will use offline data if available
        ReaderRoute(
          mangaId: item.mangaId, 
          chapterId: item.chapterId,
        ).push(context);
      },
      trailing: IconButton(
        icon: const Icon(Icons.delete_forever_rounded, size: 20),
        onPressed: () async {
          await ref
              .read(localDownloadsRepositoryProvider)
              .deleteLocalChapter(item.mangaId, item.chapterId);
          ref.invalidate(localDownloadsListProvider);
        },
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  
  if (diff.inDays > 0) {
    return '${diff.inDays}d ago';
  } else if (diff.inHours > 0) {
    return '${diff.inHours}h ago';
  } else if (diff.inMinutes > 0) {
    return '${diff.inMinutes}m ago';
  } else {
    return 'Just now';
  }
}
