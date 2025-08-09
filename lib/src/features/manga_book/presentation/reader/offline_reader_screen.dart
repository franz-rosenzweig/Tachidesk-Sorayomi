import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../widgets/emoticons.dart';
import '../../data/local_downloads/local_downloads_repository.dart';
import '../../domain/local_downloads/local_downloads_model.dart';
import 'widgets/chapter_page_image.dart';

/// Offline reader for locally downloaded chapters
class OfflineReaderScreen extends HookConsumerWidget {
  const OfflineReaderScreen({
    super.key,
    required this.mangaId,
    required this.chapterId,
  });

  final int mangaId;
  final int chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(localDownloadsRepositoryProvider);
    
    return FutureBuilder<LocalChapterManifest?>(
      future: repository.getLocalChapterManifest(mangaId, chapterId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final manifest = snapshot.data;
        if (manifest == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Chapter Not Found')),
            body: Emoticons(
              title: 'Chapter not available offline',
              subTitle: 'This chapter has not been downloaded for offline reading.',
            ),
          );
        }
        
        return _OfflineReaderContent(
          manifest: manifest,
        );
      },
    );
  }
}

class _OfflineReaderContent extends HookConsumerWidget {
  const _OfflineReaderContent({
    required this.manifest,
  });

  final LocalChapterManifest manifest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageCount = manifest.pageFiles.length;
    final currentPageIndex = useState(0);
    final isVertical = useState(false); // Default to horizontal for now
    
    if (kDebugMode) {
      print('OfflineReader: Chapter ${manifest.chapterId}, ${manifest.pageFiles.length} pages');
      print('OfflineReader: Page files: ${manifest.pageFiles}');
    }
    
    if (pageCount == 0) {
      return Scaffold(
        appBar: AppBar(title: Text(manifest.chapterName)),
        body: const Emoticons(
          title: 'No pages found',
          subTitle: 'This chapter appears to be empty.',
        ),
      );
    }

    Widget buildPageImage(int pageIndex) {
      return ChapterPageImage(
        imageUrl: '', // Not used in offline mode
        mangaId: manifest.mangaId,
        chapterId: manifest.chapterId,
        pageIndex: pageIndex,
        forceOffline: true, // Force offline mode
        fit: BoxFit.contain,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(manifest.chapterName),
        backgroundColor: Colors.black.withOpacity(0.8),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(isVertical.value ? Icons.view_agenda : Icons.view_stream),
            onPressed: () => isVertical.value = !isVertical.value,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Reader content
          if (isVertical.value)
            // Vertical/Continuous reading mode
            ListView.builder(
              itemCount: pageCount,
              itemBuilder: (context, index) => buildPageImage(index),
            )
          else
            // Horizontal/Single page mode
            PageView.builder(
              itemCount: pageCount,
              onPageChanged: (index) => currentPageIndex.value = index,
              itemBuilder: (context, index) => Center(
                child: buildPageImage(index),
              ),
            ),
          
          // Page indicator
          if (!isVertical.value)
            Positioned(
              bottom: 50,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${currentPageIndex.value + 1} / $pageCount',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
