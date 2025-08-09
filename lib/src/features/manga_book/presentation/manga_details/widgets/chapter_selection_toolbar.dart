// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../data/local_downloads/local_download_queue.dart';
import '../../../data/local_downloads/local_downloads_repository.dart';
import '../../../domain/chapter/chapter_model.dart';
import '../../../domain/manga/manga_model.dart';
import 'bulk_download_dialog.dart';

class ChapterSelectionToolbar extends ConsumerWidget {
  const ChapterSelectionToolbar({
    super.key,
    required this.manga,
    required this.selectedChapters,
    required this.allChapters,
    required this.onClearSelection,
    required this.onSelectAll,
  });

  final MangaDto manga;
  final Map<int, ChapterDto> selectedChapters;
  final List<ChapterDto> allChapters;
  final VoidCallback onClearSelection;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedList = selectedChapters.values.toList();
    final isAllSelected = selectedChapters.length == allChapters.length;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: context.theme.colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Gap(16),
          
          // Selection count
          Expanded(
            child: Text(
              '${selectedChapters.length} chapter${selectedChapters.length == 1 ? '' : 's'} selected',
              style: context.theme.textTheme.titleMedium?.copyWith(
                color: context.theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // Select all / Clear all button
          TextButton.icon(
            onPressed: isAllSelected ? onClearSelection : onSelectAll,
            icon: Icon(
              isAllSelected ? Icons.clear_all : Icons.select_all,
              color: context.theme.colorScheme.onPrimaryContainer,
            ),
            label: Text(
              isAllSelected ? 'Clear' : 'All',
              style: TextStyle(
                color: context.theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          
          const Gap(8),
          
          // Download selected button
          ElevatedButton.icon(
            onPressed: selectedList.isEmpty ? null : () => _downloadSelected(context, ref, selectedList),
            icon: const Icon(Icons.download),
            label: const Text('Download'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.theme.colorScheme.primary,
              foregroundColor: context.theme.colorScheme.onPrimary,
            ),
          ),
          
          const Gap(8),
          
          // Delete selected button
          if (selectedList.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () => _deleteSelected(context, ref, selectedList),
              icon: const Icon(Icons.delete),
              label: const Text('Delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.theme.colorScheme.error,
                foregroundColor: context.theme.colorScheme.onError,
              ),
            ),
          
          const Gap(8),
          
          // More actions
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: context.theme.colorScheme.onPrimaryContainer,
            ),
            onSelected: (value) => _handleMoreAction(context, ref, value, selectedList),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'bulk_download',
                child: ListTile(
                  leading: Icon(Icons.download_for_offline),
                  title: Text('Bulk Download'),
                  subtitle: Text('Download all/unread/range'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'mark_read',
                child: ListTile(
                  leading: Icon(Icons.visibility),
                  title: Text('Mark as Read'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'mark_unread',
                child: ListTile(
                  leading: Icon(Icons.visibility_off),
                  title: Text('Mark as Unread'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'bookmark',
                child: ListTile(
                  leading: Icon(Icons.bookmark_add),
                  title: Text('Bookmark'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'remove_bookmark',
                child: ListTile(
                  leading: Icon(Icons.bookmark_remove),
                  title: Text('Remove Bookmark'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          
          const Gap(16),
        ],
      ),
    );
  }

  Future<void> _downloadSelected(BuildContext context, WidgetRef ref, List<ChapterDto> chapters) async {
    final downloadQueue = ref.read(localDownloadQueueProvider.notifier);
    
    for (final chapter in chapters) {
      await downloadQueue.enqueueChapter(
        mangaId: manga.id,
        chapterId: chapter.id,
        mangaTitle: manga.title,
        chapterName: chapter.name,
        mangaThumbnailUrl: manga.thumbnailUrl,
      );
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${chapters.length} chapters to download queue'),
        ),
      );
    }
  }

  Future<void> _deleteSelected(BuildContext context, WidgetRef ref, List<ChapterDto> chapters) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Downloads'),
        content: Text('Delete ${chapters.length} downloaded chapters from device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.theme.colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repository = ref.read(localDownloadsRepositoryProvider);
      
      for (final chapter in chapters) {
        await repository.deleteLocalChapter(manga.id, chapter.id);
        ref.invalidate(isChapterDownloadedProvider((manga.id, chapter.id)));
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${chapters.length} chapters'),
          ),
        );
      }
    }
  }

  void _handleMoreAction(BuildContext context, WidgetRef ref, String action, List<ChapterDto> chapters) {
    switch (action) {
      case 'bulk_download':
        showDialog(
          context: context,
          builder: (context) => BulkDownloadDialog(
            manga: manga,
            chapters: allChapters,
          ),
        );
        break;
      case 'mark_read':
        // TODO: Implement mark as read
        break;
      case 'mark_unread':
        // TODO: Implement mark as unread
        break;
      case 'bookmark':
        // TODO: Implement bookmark
        break;
      case 'remove_bookmark':
        // TODO: Implement remove bookmark
        break;
    }
  }
}
