// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../../../constants/enum.dart';
import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../utils/misc/app_utils.dart';
import '../../../../../settings/presentation/reader/widgets/reader_pinch_to_zoom/reader_pinch_to_zoom.dart';
import '../../../../data/local_downloads/local_download_queue.dart';
import '../../../../domain/chapter/chapter_model.dart';
import '../../../../domain/chapter_page/chapter_page_model.dart';
import '../../../../domain/manga/manga_model.dart';
import '../../controller/reader_precache_controller.dart';
import '../enhanced_chapter_page_image.dart';
import '../chapter_separator.dart';

/// Configuration constants for improved scroll behavior
class _ScrollConfig {
  static const double minScrollUpdateInterval = 16.0; // ~60fps
  static const int visibilityMargin = 200; // Pixels
  static const Duration precacheDelay = Duration(milliseconds: 100);
}

class EnhancedContinuousReaderMode extends HookConsumerWidget {
  const EnhancedContinuousReaderMode({
    super.key,
    required this.manga,
    required this.chapter,
    required this.chapterPages,
    this.onPageChanged,
    this.reverse = false,
    this.scrollDirection = Axis.vertical,
    this.showReaderLayoutAnimation = false,
    this.showSeparator = false,
  });

  final MangaDto manga;
  final ChapterDto chapter;
  final ValueSetter<int>? onPageChanged;
  final bool reverse;
  final Axis scrollDirection;
  final bool showReaderLayoutAnimation;
  final bool showSeparator;
  final ChapterPagesDto chapterPages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemScrollController = ItemScrollController();
    final itemPositionsListener = ItemPositionsListener.create();
    final precacheController = ref.watch(readerPrecacheControllerProvider);
    
    final currentPageIndex = useState<int>(chapter.lastPageRead.getValueOnNullOrNegative());
    final lastPrecacheTime = useRef<DateTime?>(null);

    // Throttled precaching to avoid excessive operations
    void throttledPrecache(int pageIndex) {
      final now = DateTime.now();
      if (lastPrecacheTime.value == null ||
          now.difference(lastPrecacheTime.value!) > _ScrollConfig.precacheDelay) {
        lastPrecacheTime.value = now;
        
        // Precache visible and nearby pages
        precacheController.precacheAdjacentPages(
          mangaId: manga.id,
          chapterId: chapter.id,
          chapterPages: chapterPages,
          currentPageIndex: pageIndex,
          lookahead: 3, // More aggressive for continuous mode
        );
      }
    }

    // Listen to scroll position changes
    useEffect(() {
      void handlePositionChange() {
        final positions = itemPositionsListener.itemPositions.value;
        if (positions.isNotEmpty) {
          // Find the most visible item
          var mostVisible = positions.first;
          for (final position in positions) {
            if (position.itemLeadingEdge >= 0 && position.itemTrailingEdge <= 1) {
              // Fully visible item
              mostVisible = position;
              break;
            } else if (position.itemLeadingEdge < mostVisible.itemLeadingEdge &&
                      position.itemTrailingEdge > mostVisible.itemTrailingEdge) {
              // More visible than current
              mostVisible = position;
            }
          }
          
          final newPageIndex = mostVisible.index;
          if (newPageIndex != currentPageIndex.value) {
            currentPageIndex.value = newPageIndex;
            onPageChanged?.call(newPageIndex);
            throttledPrecache(newPageIndex);
          }
        }
      }

      final subscription = itemPositionsListener.itemPositions.addListener(handlePositionChange);
      
      // Initial precaching
      throttledPrecache(currentPageIndex.value);
      
      return () {
        itemPositionsListener.itemPositions.removeListener(handlePositionChange);
      };
    }, []);

    // Jump to initial page
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (itemScrollController.isAttached) {
          itemScrollController.jumpTo(
            index: chapter.lastPageRead.getValueOnNullOrNegative(),
          );
        }
      });
      return null;
    }, []);

    // Check if this chapter is downloaded to enable offline mode
    final isDownloaded = ref.watch(isChapterDownloadedProvider((manga.id, chapter.id)));
    final isPinchToZoomEnabled = ref.watch(pinchToZoomProvider).ifNull(true);

    return Container(
      // Consistent background to prevent white flash
      color: Theme.of(context).colorScheme.surface,
      child: (!kIsWeb &&
              (Platform.isAndroid || Platform.isIOS) &&
              isPinchToZoomEnabled)
          ? InteractiveViewer(
              maxScale: 5,
              child: ScrollablePositionedList.builder(
                itemCount: chapterPages.pages.length,
                itemBuilder: (BuildContext context, int index) => _buildPageItem(
                  context,
                  ref,
                  index,
                  isDownloaded,
                ),
                itemScrollController: itemScrollController,
                itemPositionsListener: itemPositionsListener,
                scrollDirection: scrollDirection,
                reverse: reverse,
                physics: const ClampingScrollPhysics(),
              ),
            )
          : ScrollablePositionedList.builder(
              itemCount: chapterPages.pages.length,
              itemBuilder: (BuildContext context, int index) => _buildPageItem(
                context,
                ref,
                index,
                isDownloaded,
              ),
              itemScrollController: itemScrollController,
              itemPositionsListener: itemPositionsListener,
              scrollDirection: scrollDirection,
              reverse: reverse,
              physics: const ClampingScrollPhysics(),
            ),
    );
  }

  Widget _buildPageItem(
    BuildContext context,
    WidgetRef ref,
    int index,
    AsyncValue<ChapterDownloadStatus> isDownloaded,
  ) {
    return Column(
      children: [
        if (showSeparator && index > 0) ...[
          ChapterSeparator(
            manga: manga,
            chapter: chapter,
            isPreviousChapterSeparator: false,
          ),
          const Gap(16),
        ],
        
        AutomaticKeepAlive(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: scrollDirection == Axis.vertical
                  ? context.width
                  : context.width * 2,
              maxHeight: scrollDirection == Axis.vertical
                  ? context.height * 2
                  : context.width * 2,
            ),
            child: EnhancedChapterPageImage(
              imageUrl: chapterPages.pages[index],
              mangaId: manga.id,
              chapterId: chapter.id,
              pageIndex: index,
              fit: scrollDirection == Axis.vertical
                  ? BoxFit.fitWidth
                  : BoxFit.fitHeight,
              showReloadButton: true,
              forceOffline: isDownloaded.maybeWhen(
                data: (status) => status == ChapterDownloadStatus.downloaded,
                orElse: () => false,
              ),
              enablePrecaching: true,
              progressIndicatorBuilder: (_, __, downloadProgress) => Center(
                child: CircularProgressIndicator(
                  value: downloadProgress.progress,
                ),
              ),
              wrapper: (child) => AnimatedContainer(
                duration: showReaderLayoutAnimation
                    ? const Duration(milliseconds: 500)
                    : Duration.zero,
                curve: Curves.ease,
                child: child,
              ),
            ),
          ),
        ),
        
        if (showSeparator)
          const Gap(16),
      ],
    );
  }
}

/// Widget that stays alive to prevent rebuild
class AutomaticKeepAlive extends StatefulWidget {
  const AutomaticKeepAlive({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AutomaticKeepAlive> createState() => _AutomaticKeepAliveState();
}

class _AutomaticKeepAliveState extends State<AutomaticKeepAlive>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
