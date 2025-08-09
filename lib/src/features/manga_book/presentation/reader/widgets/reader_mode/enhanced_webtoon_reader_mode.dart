// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../utils/misc/app_utils.dart';
import '../../../../../settings/presentation/reader/widgets/reader_pinch_to_zoom/reader_pinch_to_zoom.dart';
import '../../../../../settings/presentation/reader/widgets/reader_pinch_to_zoom/reader_pinch_to_zoom.dart';
import '../../../../../settings/presentation/reader/widgets/reader_scroll_animation_tile/reader_scroll_animation_tile.dart';
import '../../../../data/local_downloads/local_download_queue.dart';
import '../../../../domain/chapter/chapter_model.dart';
import '../../../../domain/chapter_page/chapter_page_model.dart';
import '../../../../domain/manga/manga_model.dart';
import '../../controller/reader_precache_controller.dart';
import '../enhanced_chapter_page_image.dart';
import '../chapter_separator.dart';
import '../reader_wrapper.dart';

/// Configuration for webtoon-style reading
class _WebtoonConfig {
  static const double minScrollUpdateInterval = 16.0; // ~60fps
  static const int visibilityMargin = 100; // Pixels
  static const Duration precacheDelay = Duration(milliseconds: 50);
  static const double pageSpacing = 8.0; // Space between pages
}

class EnhancedWebtoonReaderMode extends HookConsumerWidget {
  const EnhancedWebtoonReaderMode({
    super.key,
    required this.manga,
    required this.chapter,
    required this.chapterPages,
    this.onPageChanged,
    this.reverse = false,
    this.showReaderLayoutAnimation = false,
  });

  final MangaDto manga;
  final ChapterDto chapter;
  final ValueSetter<int>? onPageChanged;
  final bool reverse;
  final bool showReaderLayoutAnimation;
  final ChapterPagesDto chapterPages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();
    final precacheController = ref.watch(readerPrecacheControllerProvider);
    
    final currentPageIndex = useState<int>(chapter.lastPageRead.getValueOnNullOrNegative());
    final lastPrecacheTime = useRef<DateTime?>(null);
    final pagePositions = useRef<List<double>>([]);

    // Throttled precaching optimized for webtoon
    void throttledPrecache(int pageIndex) {
      final now = DateTime.now();
      if (lastPrecacheTime.value == null ||
          now.difference(lastPrecacheTime.value!) > _WebtoonConfig.precacheDelay) {
        lastPrecacheTime.value = now;
        
        // More aggressive precaching for webtoon
        precacheController.precacheAdjacentPages(
          mangaId: manga.id,
          chapterId: chapter.id,
          chapterPages: chapterPages,
          currentPageIndex: pageIndex,
          lookahead: 5, // Higher lookahead for smooth scrolling
        );
      }
    }

    // Track scroll position and determine current page
    useEffect(() {
      void handleScroll() {
        if (pagePositions.value.isEmpty) return;
        
        final offset = scrollController.offset;
        final viewHeight = context.height;
        
        // Find the page that's most visible in the center of the screen
        final centerOffset = offset + (viewHeight / 2);
        
        int newPageIndex = currentPageIndex.value;
        for (int i = 0; i < pagePositions.value.length; i++) {
          if (centerOffset >= pagePositions.value[i] && 
              (i == pagePositions.value.length - 1 || centerOffset < pagePositions.value[i + 1])) {
            newPageIndex = i;
            break;
          }
        }
        
        if (newPageIndex != currentPageIndex.value) {
          currentPageIndex.value = newPageIndex;
          onPageChanged?.call(newPageIndex);
          throttledPrecache(newPageIndex);
        }
      }

      scrollController.addListener(handleScroll);
      
      // Initial precaching
      throttledPrecache(currentPageIndex.value);
      
      return () => scrollController.removeListener(handleScroll);
    }, []);

    // Scroll to initial page position
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients && pagePositions.value.isNotEmpty) {
          final targetIndex = chapter.lastPageRead.getValueOnNullOrNegative();
          if (targetIndex < pagePositions.value.length) {
            scrollController.animateTo(
              pagePositions.value[targetIndex],
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        }
      });
      return null;
    }, [pagePositions.value]);

    // Check if this chapter is downloaded
    final isDownloaded = ref.watch(isChapterDownloadedProvider((manga.id, chapter.id)));
    final isPinchToZoomEnabled = ref.watch(pinchToZoomProvider).ifNull(true);

    return Container(
      // Consistent background to prevent white flash
      color: Theme.of(context).colorScheme.surface,
      child: AppUtils.wrapOn(
        !kIsWeb &&
                (Platform.isAndroid || Platform.isIOS) &&
                isPinchToZoomEnabled
            ? (Widget child) => InteractiveViewer(maxScale: 5, child: child)
            : null,
        CustomScrollView(
          controller: scrollController,
          reverse: reverse,
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildPageItem(
                  context,
                  ref,
                  index,
                  isDownloaded,
                  pagePositions,
                ),
                childCount: chapterPages.pages.length,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageItem(
    BuildContext context,
    WidgetRef ref,
    int index,
    AsyncValue<ChapterDownloadStatus> isDownloaded,
    ObjectRef<List<double>> pagePositions,
  ) {
    return WebtoonPageContainer(
      key: ValueKey('page_$index'),
      onLayout: (offset) {
        // Store page position for scroll tracking
        if (pagePositions.value.length <= index) {
          pagePositions.value = List.generate(
            chapterPages.pages.length,
            (i) => i < pagePositions.value.length ? pagePositions.value[i] : 0.0,
          );
        }
        pagePositions.value[index] = offset;
      },
      child: Container(
        margin: EdgeInsets.symmetric(
          vertical: _WebtoonConfig.pageSpacing / 2,
        ),
        child: EnhancedChapterPageImage(
          imageUrl: chapterPages.pages[index],
          mangaId: manga.id,
          chapterId: chapter.id,
          pageIndex: index,
          fit: BoxFit.fitWidth, // Always fit width for webtoon
          showReloadButton: true,
          forceOffline: isDownloaded.maybeWhen(
            data: (status) => status == ChapterDownloadStatus.downloaded,
            orElse: () => false,
          ),
          enablePrecaching: true,
          progressIndicatorBuilder: (_, __, downloadProgress) => Container(
            height: 200, // Minimum height for loading state
            alignment: Alignment.center,
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
    );
  }
}

/// Container that reports its layout position for scroll tracking
class WebtoonPageContainer extends StatefulWidget {
  const WebtoonPageContainer({
    super.key,
    required this.child,
    this.onLayout,
  });

  final Widget child;
  final ValueChanged<double>? onLayout;

  @override
  State<WebtoonPageContainer> createState() => _WebtoonPageContainerState();
}

class _WebtoonPageContainerState extends State<WebtoonPageContainer>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (notification) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final offset = renderBox.localToGlobal(Offset.zero).dy;
            widget.onLayout?.call(offset);
          }
        });
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: widget.child,
      ),
    );
  }
}
