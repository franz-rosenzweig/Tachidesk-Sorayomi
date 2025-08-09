// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../widgets/custom_circular_progress_indicator.dart';
import '../../../../../widgets/emoticons.dart';
import '../../../data/manga_book/manga_book_repository.dart';
import '../../../domain/chapter/chapter_model.dart';
import '../../../domain/manga/manga_model.dart';
import 'bulk_download_dialog.dart';
import 'chapter_list_tile.dart';
import 'chapter_selection_toolbar.dart';
import 'manga_description.dart';

class SmallScreenMangaDetails extends ConsumerWidget {
  const SmallScreenMangaDetails({
    super.key,
    required this.chapterList,
    required this.manga,
    required this.selectedChapters,
    required this.mangaId,
    required this.onRefresh,
    required this.onDescriptionRefresh,
    required this.onListRefresh,
  });
  final int mangaId;
  final MangaDto manga;
  final AsyncValueSetter<bool> onRefresh;
  final ValueNotifier<Map<int, ChapterDto>> selectedChapters;
  final AsyncValue<List<ChapterDto>?> chapterList;
  final AsyncValueSetter<bool> onListRefresh;
  final AsyncValueSetter<bool> onDescriptionRefresh;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredChapterList = chapterList.valueOrNull ?? [];
    final hasSelection = selectedChapters.value.isNotEmpty;
    
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => onRefresh(true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  child: MangaDescription(
                    manga: manga,
                    refresh: () => onDescriptionRefresh(false),
                    removeMangaFromLibrary: () => ref
                        .read(mangaBookRepositoryProvider)
                        .removeMangaFromLibrary(mangaId),
                    addMangaToLibrary: () => ref
                        .read(mangaBookRepositoryProvider)
                        .addMangaToLibrary(mangaId),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: Text(
                          context.l10n.noOfChapters(filteredChapterList.length),
                        ),
                      ),
                    ),
                    if (!hasSelection)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.phone_android),
                        tooltip: 'Device Download Options',
                        onSelected: (value) {
                          if (value == 'bulk_download') {
                            showDialog(
                              context: context,
                              builder: (context) => BulkDownloadDialog(
                                manga: manga,
                                chapters: filteredChapterList,
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'bulk_download',
                            child: ListTile(
                              leading: Icon(Icons.phone_android),
                              title: Text('Download to Device'),
                              subtitle: Text('Bulk download chapters to your device'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // Handle sliver context with custom loader
              switch (chapterList) {
                AsyncData(:final value) => () {
                  if (value.isNotBlank) {
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => ChapterListTile(
                          key: ValueKey("${filteredChapterList[index].id}"),
                          manga: manga,
                          chapter: filteredChapterList[index],
                          updateData: () => onRefresh(false),
                          isSelected: selectedChapters.value
                              .containsKey(filteredChapterList[index].id),
                          canTapSelect: selectedChapters.value.isNotEmpty,
                          selectionMode: selectedChapters.value.isNotEmpty,
                          showServerDownloadIcon: true, // Can be made configurable
                          toggleSelect: (ChapterDto val) {
                            if ((val.id).isNull) return;
                            selectedChapters.value =
                                selectedChapters.value.toggleKey(val.id, val);
                          },
                        ),
                        childCount: filteredChapterList.length,
                      ),
                    );
                  } else {
                    return SliverToBoxAdapter(
                      child: Emoticons(
                        title: context.l10n.noChaptersFound,
                        button: TextButton(
                          onPressed: () => onDescriptionRefresh(true),
                          child: Text(context.l10n.refresh),
                        ),
                      ),
                    );
                  }
                }(),
                AsyncError(:final error) => SliverToBoxAdapter(
                  child: Emoticons(
                    title: error.toString(),
                  ),
                ),
                _ => const SliverToBoxAdapter(
                  child: CenterSorayomiShimmerIndicator(),
                ),
              },
              // Add bottom padding when selection toolbar is visible
              if (hasSelection) 
                const SliverToBoxAdapter(
                  child: SizedBox(height: 72),
                ),
            ],
          ),
        ),
        
        // Selection toolbar (floating at bottom)
        if (hasSelection)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ChapterSelectionToolbar(
              manga: manga,
              selectedChapters: selectedChapters.value,
              allChapters: filteredChapterList,
              onClearSelection: () => selectedChapters.value = {},
              onSelectAll: () {
                final newSelection = <int, ChapterDto>{};
                for (final chapter in filteredChapterList) {
                  if (chapter.id != null) {
                    newSelection[chapter.id!] = chapter;
                  }
                }
                selectedChapters.value = newSelection;
              },
            ),
          ),
      ],
    );
  }
}
