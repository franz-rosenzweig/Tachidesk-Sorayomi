// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../constants/enum.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../history/presentation/history_controller.dart';
import '../../../settings/presentation/reader/widgets/reader_ignore_safe_area_tile/reader_ignore_safe_area_tile.dart';
import '../../../settings/presentation/reader/widgets/reader_mode_tile/reader_mode_tile.dart';
import '../../data/manga_book/manga_book_repository.dart';
import '../../domain/chapter_batch/chapter_batch_model.dart';
import '../../domain/chapter/chapter_model.dart';
import '../../domain/chapter_page/chapter_page_model.dart';
import '../../domain/manga/manga_model.dart';
import '../manga_details/controller/manga_details_controller.dart';
import 'controller/reader_controller.dart';
import 'widgets/reader_mode/continuous_reader_mode.dart';
import 'widgets/reader_mode/single_page_reader_mode.dart';
import 'widgets/reader_mode/enhanced_single_page_reader_mode.dart';
import 'widgets/reader_mode/enhanced_continuous_reader_mode.dart';
import 'widgets/reader_mode/enhanced_webtoon_reader_mode.dart';
import '../../../settings/presentation/reader/widgets/enhanced_reader_tile/enhanced_reader_tile.dart';

class ReaderScreen extends HookConsumerWidget {
  const ReaderScreen({
    super.key,
    required this.mangaId,
    required this.chapterId,
    this.showReaderLayoutAnimation = false,
  });
  final int mangaId;
  final int chapterId;
  final bool showReaderLayoutAnimation;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mangaProvider = mangaWithIdProvider(mangaId: mangaId);
    final chapterProviderWithIndex = chapterProvider(chapterId: chapterId);
    // Use unified provider instead of direct network provider
    final chapterPagesUnified = ref.watch(chapterPagesUnifiedProvider(mangaId, chapterId));
    final manga = ref.watch(mangaProvider);
    final chapter = ref.watch(chapterProviderWithIndex);
    final defaultReaderMode = ref.watch(readerModeKeyProvider);
    final ignoreSafeArea = ref.watch(readerIgnoreSafeAreaProvider).ifNull();

    final debounce = useRef<Timer?>(null);

    final updateLastRead = useCallback((int currentPage) async {
      final chapterValue = chapter.valueOrNull;
      final chapterPagesValue = chapterPagesUnified.valueOrNull;
      if (chapterValue == null || chapterPagesValue == null) return;

      // Use the actual loaded pages count, not the chapter's pageCount metadata
      final actualPageCount = chapterPagesValue.pages.length;

      // Only mark as completed if we've reached the actual last page
      final isReadingCompleted =
          (currentPage >= (actualPageCount - 1)) && actualPageCount > 0;

      await AsyncValue.guard(
        () => ref.read(mangaBookRepositoryProvider).putChapter(
              chapterId: chapterValue.id,
              patch: ChapterChange(
                lastPageRead: isReadingCompleted ? 0 : currentPage,
                isRead: isReadingCompleted,
              ),
            ),
      );

      // Invalidate history to refresh the reading progress
      ref.invalidate(readingHistoryProvider);
    }, [chapter.valueOrNull, chapterPagesUnified.valueOrNull]);

    final onPageChanged = useCallback<AsyncValueSetter<int>>(
      (int index) async {
        final chapterValue = chapter.valueOrNull;
        final chapterPagesValue = chapterPagesUnified.valueOrNull;
        if (chapterValue == null || chapterPagesValue == null) return;

        // Skip if chapter is already read or if we're going backwards
        if ((chapterValue.isRead).ifNull() ||
            (chapterValue.lastPageRead).getValueOnNullOrNegative() >= index) {
          return;
        }

        final finalDebounce = debounce.value;
        if ((finalDebounce?.isActive).ifNull()) {
          finalDebounce?.cancel();
        }

        // Use actual loaded pages count instead of chapter metadata
        final actualPageCount = chapterPagesValue.pages.length;

        if (index >= (actualPageCount - 1) && actualPageCount > 0) {
          updateLastRead(index);
        } else {
          debounce.value = Timer(
            const Duration(seconds: 2),
            () => updateLastRead(index),
          );
        }
        return;
      },
      [chapter, chapterPagesUnified],
    );

    useEffect(() {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      return () => SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.manual,
            overlays: SystemUiOverlay.values,
          );
    }, []);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          ref.invalidate(chapterProviderWithIndex);
          ref.invalidate(mangaChapterListProvider(mangaId: mangaId));
        }
      },
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SafeArea(
          top: !ignoreSafeArea,
          bottom: !ignoreSafeArea,
          left: !ignoreSafeArea,
          right: !ignoreSafeArea,
          child: manga.showUiWhenData(
            context,
            (data) {
              if (data == null) return const SizedBox.shrink();
              return chapter.showUiWhenData(
                context,
                (chapterData) {
                  if (chapterData == null) return const SizedBox.shrink();
                  return chapterPagesUnified.when(
                    data: (chapterPagesResult) {
                      // Convert unified result to compatible ChapterPagesDto
                      final chapterPagesData = chapterPagesResult.toChapterPagesDto(chapterData.id ?? 0);
                      final isLocal = chapterPagesResult.isLocal;
                      
                      if (kDebugMode) {
                        print('ReaderScreen: Using ${isLocal ? 'local' : 'network'} pages for chapter ${chapterData.id}');
                      }
                      
                      // Check if enhanced reader mode is enabled
                      final enhancedReaderEnabled = ref.watch(enhancedReaderKeyProvider).ifNull(false);
                      
                      return _buildReaderWidget(
                        readerMode: data.metaData.readerMode ?? defaultReaderMode,
                        defaultReaderMode: defaultReaderMode,
                        chapterData: chapterData,
                        data: data,
                        onPageChanged: onPageChanged,
                        showReaderLayoutAnimation: showReaderLayoutAnimation,
                        chapterPagesData: chapterPagesData,
                        enhancedReaderEnabled: enhancedReaderEnabled,
                      );
                    },
                    loading: () => const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stack) {
                      if (error is OfflineNotAvailableException) {
                        return Scaffold(
                          appBar: AppBar(title: Text('Chapter ${chapterData.name ?? chapterData.id}')),
                          body: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text(
                                  'Chapter not downloaded',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'This chapter is not available offline.\nConnect to internet or download it first.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => ref.refresh(chapterPagesUnifiedProvider(mangaId, chapterId)),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return Scaffold(
                        appBar: AppBar(title: const Text('Error')),
                        body: Center(child: Text('Error: $error')),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// Build the appropriate reader widget based on mode and settings
  Widget _buildReaderWidget({
    required ReaderMode? readerMode,
    required ReaderMode? defaultReaderMode,
    required ChapterDto chapterData,
    required MangaDto data,
    required ValueSetter<int>? onPageChanged,
    required bool showReaderLayoutAnimation,
    required ChapterPagesDto chapterPagesData,
    required bool enhancedReaderEnabled,
  }) {
    final actualReaderMode = readerMode ?? defaultReaderMode ?? ReaderMode.webtoon;

    // Helper to choose between standard and enhanced widgets
    Widget buildSinglePageReader({
      Axis scrollDirection = Axis.horizontal,
      bool reverse = false,
    }) {
      if (enhancedReaderEnabled) {
        return EnhancedSinglePageReaderMode(
          chapter: chapterData,
          manga: data,
          onPageChanged: onPageChanged,
          scrollDirection: scrollDirection,
          reverse: reverse,
          showReaderLayoutAnimation: showReaderLayoutAnimation,
          chapterPages: chapterPagesData,
        );
      } else {
        return SinglePageReaderMode(
          chapter: chapterData,
          manga: data,
          onPageChanged: onPageChanged,
          scrollDirection: scrollDirection,
          reverse: reverse,
          showReaderLayoutAnimation: showReaderLayoutAnimation,
          chapterPages: chapterPagesData,
        );
      }
    }

    Widget buildContinuousReader({
      Axis scrollDirection = Axis.vertical,
      bool reverse = false,
      bool showSeparator = false,
    }) {
      if (enhancedReaderEnabled) {
        return EnhancedContinuousReaderMode(
          chapter: chapterData,
          manga: data,
          onPageChanged: onPageChanged,
          scrollDirection: scrollDirection,
          reverse: reverse,
          showSeparator: showSeparator,
          showReaderLayoutAnimation: showReaderLayoutAnimation,
          chapterPages: chapterPagesData,
        );
      } else {
        return ContinuousReaderMode(
          chapter: chapterData,
          manga: data,
          onPageChanged: onPageChanged,
          scrollDirection: scrollDirection,
          reverse: reverse,
          showSeparator: showSeparator,
          showReaderLayoutAnimation: showReaderLayoutAnimation,
          chapterPages: chapterPagesData,
        );
      }
    }

    Widget buildWebtoonReader() {
      if (enhancedReaderEnabled) {
        return EnhancedWebtoonReaderMode(
          chapter: chapterData,
          manga: data,
          onPageChanged: onPageChanged,
          showReaderLayoutAnimation: showReaderLayoutAnimation,
          chapterPages: chapterPagesData,
        );
      } else {
        return ContinuousReaderMode(
          chapter: chapterData,
          manga: data,
          onPageChanged: onPageChanged,
          showReaderLayoutAnimation: showReaderLayoutAnimation,
          chapterPages: chapterPagesData,
        );
      }
    }

    return switch (actualReaderMode) {
      ReaderMode.singleVertical => buildSinglePageReader(scrollDirection: Axis.vertical),
      ReaderMode.singleHorizontalLTR => buildSinglePageReader(),
      ReaderMode.singleHorizontalRTL => buildSinglePageReader(reverse: true),
      ReaderMode.continuousVertical => buildContinuousReader(showSeparator: true),
      ReaderMode.continuousHorizontalLTR => buildContinuousReader(scrollDirection: Axis.horizontal),
      ReaderMode.continuousHorizontalRTL => buildContinuousReader(
        scrollDirection: Axis.horizontal,
        reverse: true,
      ),
      ReaderMode.webtoon => buildWebtoonReader(),
      ReaderMode.defaultReader => buildWebtoonReader(), // Default to webtoon
    };
  }
}
