// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../../constants/app_constants.dart';
import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../utils/misc/app_utils.dart';
import '../../../../../../widgets/custom_circular_progress_indicator.dart';
import '../../../../../settings/presentation/reader/widgets/reader_scroll_animation_tile/reader_scroll_animation_tile.dart';
import '../../../../data/local_downloads/local_download_queue.dart';
import '../../../../domain/chapter/chapter_model.dart';
import '../../../../domain/chapter_page/chapter_page_model.dart';
import '../../../../domain/manga/manga_model.dart';
import '../../controller/reader_precache_controller.dart';
import '../enhanced_chapter_page_image.dart';
import '../reader_wrapper.dart';

class EnhancedSinglePageReaderMode extends HookConsumerWidget {
  const EnhancedSinglePageReaderMode({
    super.key,
    required this.manga,
    required this.chapter,
    required this.chapterPages,
    this.onPageChanged,
    this.reverse = false,
    this.scrollDirection = Axis.horizontal,
    this.showReaderLayoutAnimation = false,
  });

  final MangaDto manga;
  final ChapterDto chapter;
  final ValueSetter<int>? onPageChanged;
  final bool reverse;
  final Axis scrollDirection;
  final bool showReaderLayoutAnimation;
  final ChapterPagesDto chapterPages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = usePageController(
      initialPage: chapter.lastPageRead.getValueOnNullOrNegative(),
    );
    
    final precacheController = ref.watch(readerPrecacheControllerProvider);
    final currentPageIndex = useState<int>(chapter.lastPageRead.getValueOnNullOrNegative());

    // Precache adjacent pages when page changes
    useEffect(() {
      void handlePageChange() {
        final page = currentPageIndex.value;
        
        // Warm decode current page immediately
        precacheController.warmDecodeCurrentPage(
          mangaId: manga.id,
          chapterId: chapter.id,
          pageIndex: page,
        );
        
        // Precache adjacent pages
        precacheController.precacheAdjacentPages(
          mangaId: manga.id,
          chapterId: chapter.id,
          chapterPages: chapterPages,
          currentPageIndex: page,
          lookahead: 2,
        );
      }

      // Initial precaching
      handlePageChange();

      return null;
    }, [currentPageIndex.value]);

    // Check if this chapter is downloaded to enable offline mode
    final isDownloaded = ref.watch(isChapterDownloadedProvider((manga.id, chapter.id)));

    return LayoutBuilder(
      builder: (context, constraints) => PageView.builder(
        controller: scrollController,
        scrollDirection: scrollDirection,
        reverse: reverse,
        onPageChanged: (index) {
          currentPageIndex.value = index;
          onPageChanged?.call(index);
        },
        itemCount: chapterPages.pages.length,
        itemBuilder: (context, index) {
          if (index >= chapterPages.pages.length) {
            return const Center(
              child: CenterSorayomiShimmerIndicator(),
            );
          }

          final image = EnhancedChapterPageImage(
            imageUrl: chapterPages.pages[index],
            mangaId: manga.id,
            chapterId: chapter.id,
            pageIndex: index,
            fit: BoxFit.contain,
            size: Size.fromHeight(context.height),
            showReloadButton: true,
            forceOffline: isDownloaded.maybeWhen(
              data: (status) => status == ChapterDownloadStatus.downloaded,
              orElse: () => false,
            ),
            enablePrecaching: true,
            progressIndicatorBuilder: (context, url, downloadProgress) =>
                CenterSorayomiShimmerIndicator(
              value: downloadProgress.progress,
            ),
          );

          return Container(
            // Consistent dark background to prevent white flash
            color: Theme.of(context).colorScheme.surface,
            child: Center(
              child: AnimatedContainer(
                duration: showReaderLayoutAnimation
                    ? const Duration(milliseconds: 500)
                    : Duration.zero,
                curve: Curves.ease,
                child: image,
              ),
            ),
          );
        },
      ),
    );
  }
}
