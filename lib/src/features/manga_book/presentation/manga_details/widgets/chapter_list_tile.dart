// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../routes/router_config.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../data/local_downloads/chapter_download_status_provider.dart';
import '../../../data/local_downloads/local_download_queue.dart';
import '../../../domain/chapter/chapter_model.dart';
import '../../../domain/manga/manga_model.dart';
import '../../../widgets/download_status_icon.dart';

class ChapterListTile extends StatelessWidget {
  const ChapterListTile({
    super.key,
    required this.manga,
    required this.chapter,
    required this.updateData,
    required this.toggleSelect,
    this.canTapSelect = false,
    this.isSelected = false,
    this.showServerDownloadIcon = true,
    this.selectionMode = false,
  });
  final MangaDto manga;
  final ChapterDto chapter;
  final AsyncCallback updateData;
  final ValueChanged<ChapterDto> toggleSelect;
  final bool canTapSelect;
  final bool isSelected;
  final bool showServerDownloadIcon;
  final bool selectionMode;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key("manga-${manga.id}-chapter-${chapter.id}"),
      onSecondaryTap: () => toggleSelect(chapter),
      child: ListTile(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chapter.isBookmarked.ifNull()) ...[
              Icon(
                Icons.bookmark_rounded,
                color:
                    chapter.isRead.ifNull() ? Colors.grey : context.iconColor,
                size: 20,
              ),
              const Gap(4),
            ],
            Expanded(
              child: Text(
                chapter.name,
                style: TextStyle(
                  color: chapter.isRead.ifNull() ? Colors.grey : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              int.tryParse(chapter.uploadDate).toDaysAgo(context),
              style: TextStyle(
                color: chapter.isRead.ifNull() ? Colors.grey : null,
              ),
            ),
            if (!chapter.isRead.ifNull() &&
                (chapter.lastPageRead).getValueOnNullOrNegative() != 0)
              Text(
                " • ${context.l10n.page(chapter.lastPageRead.getValueOnNullOrNegative() + 1)}",
                style: const TextStyle(color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            if (chapter.scanlator.isNotBlank)
              Expanded(
                child: Text(
                  " • ${chapter.scanlator}",
                  style: TextStyle(
                    color: chapter.isRead.ifNull() ? Colors.grey : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selection checkbox in selection mode
            if (selectionMode) ...[
              Checkbox(
                value: isSelected,
                onChanged: (_) => toggleSelect(chapter),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const Gap(8),
            ],
            
            // Device download status (local storage)
            _DeviceDownloadIcon(
              manga: manga,
              chapter: chapter,
              updateData: updateData,
            ),
            
            // Server download status (optional)
            if (showServerDownloadIcon) ...[
              const Gap(8),
              _ServerDownloadIcon(
                chapter: chapter,
                mangaId: manga.id,
                updateData: updateData,
              ),
            ],
          ],
        ),
        selectedColor: context.theme.colorScheme.onSurface,
        selectedTileColor:
            context.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
        selected: isSelected,
        onTap: canTapSelect
            ? () => toggleSelect(chapter)
            : () => ReaderRoute(
                  mangaId: manga.id,
                  chapterId: chapter.id,
                  showReaderLayoutAnimation: true,
                ).push(context),
        onLongPress: () => toggleSelect(chapter),
      ),
    );
  }
}

/// Widget to show device download status (local storage)
class _DeviceDownloadIcon extends ConsumerWidget {
  const _DeviceDownloadIcon({
    required this.manga,
    required this.chapter,
    required this.updateData,
  });

  final MangaDto manga;
  final ChapterDto chapter;
  final AsyncCallback updateData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadProgress = ref.watch(
      chapterLocalDownloadProgressProvider(manga.id, chapter.id),
    );
    final localStatus = ref.watch(
      chapterDownloadStatusProvider(manga.id, chapter.id),
    );

    return localStatus.when(
      data: (status) {
        // Show download progress if in queue
        if (downloadProgress != null) {
          switch (downloadProgress.state) {
            case DownloadTaskState.queued:
              return Tooltip(
                message: 'Queued for download',
                child: Icon(
                  Icons.schedule,
                  color: Colors.orange,
                  size: 20,
                ),
              );
            case DownloadTaskState.downloading:
              return Tooltip(
                message: 'Downloading ${downloadProgress.pagesDownloaded}/${downloadProgress.totalPages}',
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    value: downloadProgress.progress,
                    strokeWidth: 2,
                    color: Colors.blue,
                  ),
                ),
              );
            case DownloadTaskState.failed:
              return Tooltip(
                message: 'Download failed - tap to retry',
                child: GestureDetector(
                  onTap: () => ref
                      .read(localDownloadQueueProvider.notifier)
                      .retryTask('${manga.id}_${chapter.id}'),
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
              );
            case DownloadTaskState.completed:
              return Tooltip(
                message: 'Downloaded to device',
                child: Icon(
                  Icons.phone_android,
                  color: Colors.green,
                  size: 20,
                ),
              );
            default:
              break;
          }
        }

        // Show status based on local download state
        switch (status) {
          case ChapterDownloadStatus.downloaded:
            return Tooltip(
              message: 'Downloaded to device',
              child: Icon(
                Icons.phone_android,
                color: Colors.green,
                size: 20,
              ),
            );
          case ChapterDownloadStatus.notDownloaded:
            return Tooltip(
              message: 'Download to device',
              child: GestureDetector(
                onTap: () async {
                  await ref
                      .read(localDownloadQueueProvider.notifier)
                      .enqueueChapter(
                        mangaId: manga.id,
                        chapterId: chapter.id,
                        mangaTitle: manga.title,
                        chapterName: chapter.name,
                        mangaThumbnailUrl: manga.thumbnailUrl,
                      );
                },
                child: Icon(
                  Icons.file_download_outlined,
                  color: context.iconColor?.withOpacity(0.7),
                  size: 20,
                ),
              ),
            );
          case ChapterDownloadStatus.queued:
            return Tooltip(
              message: 'Queued for download',
              child: Icon(
                Icons.schedule,
                color: Colors.orange,
                size: 20,
              ),
            );
          case ChapterDownloadStatus.downloading:
            return Tooltip(
              message: 'Downloading...',
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.blue,
                ),
              ),
            );
          case ChapterDownloadStatus.partiallyCorrupted:
            return Tooltip(
              message: 'Some pages corrupted - tap to repair',
              child: GestureDetector(
                onTap: () => ref
                    .read(localDownloadQueueProvider.notifier)
                    .enqueueChapter(
                      mangaId: manga.id,
                      chapterId: chapter.id,
                      mangaTitle: manga.title,
                      chapterName: chapter.name,
                      mangaThumbnailUrl: manga.thumbnailUrl,
                    ),
                child: Icon(
                  Icons.warning,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
            );
          case ChapterDownloadStatus.fullyCorrupted:
            return Tooltip(
              message: 'Chapter corrupted - tap to re-download',
              child: GestureDetector(
                onTap: () => ref
                    .read(localDownloadQueueProvider.notifier)
                    .enqueueChapter(
                      mangaId: manga.id,
                      chapterId: chapter.id,
                      mangaTitle: manga.title,
                      chapterName: chapter.name,
                      mangaThumbnailUrl: manga.thumbnailUrl,
                    ),
                child: Icon(
                  Icons.error,
                  color: Colors.red,
                  size: 20,
                ),
              ),
            );
          case ChapterDownloadStatus.repairNeeded:
            return Tooltip(
              message: 'Queued for repair',
              child: Icon(
                Icons.build,
                color: Colors.orange,
                size: 20,
              ),
            );
          case ChapterDownloadStatus.repairing:
            return Tooltip(
              message: 'Repairing...',
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.orange,
                ),
              ),
            );
          case ChapterDownloadStatus.error:
            return Tooltip(
              message: 'Download failed - tap to retry',
              child: GestureDetector(
                onTap: () => ref
                    .read(localDownloadQueueProvider.notifier)
                    .enqueueChapter(
                      mangaId: manga.id,
                      chapterId: chapter.id,
                      mangaTitle: manga.title,
                      chapterName: chapter.name,
                      mangaThumbnailUrl: manga.thumbnailUrl,
                    ),
                child: Icon(
                  Icons.warning_outlined,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
            );
        }
      },
      loading: () => SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => Icon(
        Icons.error_outline,
        color: Colors.red,
        size: 20,
      ),
    );
  }
}

/// Widget to show server download status (optional)
class _ServerDownloadIcon extends StatelessWidget {
  const _ServerDownloadIcon({
    required this.chapter,
    required this.mangaId,
    required this.updateData,
  });

  final ChapterDto chapter;
  final int mangaId;
  final AsyncCallback updateData;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: chapter.isDownloaded.ifNull() 
          ? 'Downloaded on server' 
          : 'Download to server',
      child: DownloadStatusIcon(
        updateData: updateData,
        chapter: chapter,
        mangaId: mangaId,
        isDownloaded: chapter.isDownloaded.ifNull(),
      ),
    );
  }
}
