import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../widgets/emoticons.dart';
import '../../data/offline_bootstrap_service.dart';
import '../../domain/offline_catalog/offline_catalog_model.dart';

/// Screen showing locally downloaded manga from the offline catalog
class OfflineDownloadsScreen extends HookConsumerWidget {
  const OfflineDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(offlineCatalogProviderProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Downloads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              ref.read(offlineCatalogProviderProvider.notifier).refresh();
            },
            tooltip: 'Refresh catalog',
          ),
        ],
      ),
      body: _buildBody(context, catalog),
    );
  }

  Widget _buildBody(BuildContext context, OfflineCatalog catalog) {
    if (catalog.manga.isEmpty) {
      return const Emoticons(
        title: 'No offline downloads',
        subTitle: 'Download some chapters to read them offline.',
      );
    }

    return ListView.builder(
      itemCount: catalog.manga.length,
      itemBuilder: (context, index) {
        final manga = catalog.manga[index];
        return _buildMangaCard(context, manga);
      },
    );
  }

  Widget _buildMangaCard(BuildContext context, MangaEntry manga) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: manga.cover != null
            ? Container(
                width: 48,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey[300],
                ),
                child: const Icon(Icons.book, size: 24),
              )
            : Container(
                width: 48,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey[300],
                ),
                child: const Icon(Icons.book, size: 24),
              ),
        title: Text(
          manga.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${manga.chapters.length} chapters downloaded'),
        children: manga.chapters.map((chapter) => _buildChapterTile(context, manga, chapter)).toList(),
      ),
    );
  }

  Widget _buildChapterTile(BuildContext context, MangaEntry manga, ChapterEntry chapter) {
    final progress = chapter.readPage > 0 ? '${chapter.readPage}/${chapter.pageCount}' : '';
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      title: Text(chapter.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${chapter.pageCount} pages'),
          if (progress.isNotEmpty) Text('Progress: $progress'),
        ],
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        // Navigate to offline reader
        Navigator.pushNamed(
          context,
          '/reader/offline',
          arguments: {
            'mangaId': manga.mangaId,
            'chapterId': chapter.chapterId,
          },
        );
      },
    );
  }
}
