// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../data/local_downloads/local_download_queue.dart';

class DownloadQueueChip extends ConsumerWidget {
  const DownloadQueueChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueState = ref.watch(localDownloadQueueProvider);
    
    if (queueState.tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeDownloads = queueState.tasks.where((task) => 
        task.state == DownloadTaskState.downloading || 
        task.state == DownloadTaskState.queued).length;
    
    final failedDownloads = queueState.tasks.where((task) => 
        task.state == DownloadTaskState.failed).length;

    if (activeDownloads == 0 && failedDownloads == 0) {
      return const SizedBox.shrink();
    }

    Color chipColor;
    IconData chipIcon;
    String chipText;

    if (failedDownloads > 0) {
      chipColor = Colors.red;
      chipIcon = Icons.error_outline;
      chipText = failedDownloads == 1 ? '1 failed' : '$failedDownloads failed';
    } else if (activeDownloads > 0) {
      chipColor = Colors.blue;
      chipIcon = Icons.download;
      chipText = activeDownloads == 1 ? '1 downloading' : '$activeDownloads downloading';
    } else {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        // TODO: Navigate to download queue screen
        _showDownloadQueueBottomSheet(context, ref, queueState);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: chipColor.withOpacity(0.1),
          border: Border.all(color: chipColor, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              chipIcon,
              size: 16,
              color: chipColor,
            ),
            const SizedBox(width: 4),
            Text(
              chipText,
              style: context.theme.textTheme.bodySmall?.copyWith(
                color: chipColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDownloadQueueBottomSheet(BuildContext context, WidgetRef ref, DownloadQueueState queueState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: context.theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.download_for_offline, color: context.iconColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Download Queue (${queueState.tasks.length})',
                        style: context.theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _clearCompletedTasks(ref),
                      icon: const Icon(Icons.clear_all),
                      tooltip: 'Clear completed',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: queueState.tasks.length,
                  itemBuilder: (context, index) {
                    final task = queueState.tasks[index];
                    return _DownloadTaskTile(task: task, ref: ref);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearCompletedTasks(WidgetRef ref) {
    ref.read(localDownloadQueueProvider.notifier).clearCompleted();
  }
}

class _DownloadTaskTile extends StatelessWidget {
  const _DownloadTaskTile({
    required this.task,
    required this.ref,
  });

  final ChapterDownloadTask task;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    IconData stateIcon;
    Color stateColor;
    String stateText;

    switch (task.state) {
      case DownloadTaskState.queued:
        stateIcon = Icons.schedule;
        stateColor = Colors.orange;
        stateText = 'Queued';
        break;
      case DownloadTaskState.downloading:
        stateIcon = Icons.download;
        stateColor = Colors.blue;
        stateText = 'Downloading ${task.pagesDownloaded}/${task.totalPages}';
        break;
      case DownloadTaskState.completed:
        stateIcon = Icons.check_circle;
        stateColor = Colors.green;
        stateText = 'Completed';
        break;
      case DownloadTaskState.failed:
        stateIcon = Icons.error;
        stateColor = Colors.red;
        stateText = 'Failed';
        break;
      case DownloadTaskState.paused:
        stateIcon = Icons.pause_circle;
        stateColor = Colors.yellow;
        stateText = 'Paused';
        break;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: task.mangaThumbnailUrl?.isNotEmpty == true
            ? NetworkImage(task.mangaThumbnailUrl!)
            : null,
        child: task.mangaThumbnailUrl?.isEmpty != false
            ? const Icon(Icons.book)
            : null,
      ),
      title: Text(
        task.chapterName ?? 'Chapter ${task.chapterId}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.mangaTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(stateIcon, size: 14, color: stateColor),
              const SizedBox(width: 4),
              Text(
                stateText,
                style: context.theme.textTheme.bodySmall?.copyWith(
                  color: stateColor,
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: task.state == DownloadTaskState.downloading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: task.progress,
                strokeWidth: 2,
                color: stateColor,
              ),
            )
          : task.state == DownloadTaskState.failed
              ? IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref
                      .read(localDownloadQueueProvider.notifier)
                      .retryTask(task.taskId),
                  tooltip: 'Retry',
                )
              : task.state == DownloadTaskState.completed
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => ref
                          .read(localDownloadQueueProvider.notifier)
                          .removeTask(task.taskId),
                      tooltip: 'Remove',
                    )
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => ref
                          .read(localDownloadQueueProvider.notifier)
                          .removeTask(task.taskId),
                      tooltip: 'Remove',
                    ),
    );
  }
}
