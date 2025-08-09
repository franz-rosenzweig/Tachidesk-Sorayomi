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
import '../../../domain/chapter/chapter_model.dart';
import '../../../domain/manga/manga_model.dart';

class BulkDownloadDialog extends ConsumerStatefulWidget {
  const BulkDownloadDialog({
    super.key,
    required this.manga,
    required this.chapters,
  });

  final MangaDto manga;
  final List<ChapterDto> chapters;

  @override
  ConsumerState<BulkDownloadDialog> createState() => _BulkDownloadDialogState();
}

class _BulkDownloadDialogState extends ConsumerState<BulkDownloadDialog> {
  BulkDownloadOption _selectedOption = BulkDownloadOption.all;
  int _latestCount = 5;
  int _startIndex = 0;
  int _endIndex = 0;

  @override
  void initState() {
    super.initState();
    _endIndex = widget.chapters.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final unreadChapters = widget.chapters.where((c) => !c.isRead.ifNull()).toList();
    
    return AlertDialog(
      title: Text('Download to Device'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose which chapters to download to your device:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Gap(16),
            
            RadioListTile<BulkDownloadOption>(
              title: Text('All chapters (${widget.chapters.length})'),
              value: BulkDownloadOption.all,
              groupValue: _selectedOption,
              onChanged: (value) => setState(() => _selectedOption = value!),
              dense: true,
            ),
            
            RadioListTile<BulkDownloadOption>(
              title: Text('Unread chapters (${unreadChapters.length})'),
              value: BulkDownloadOption.unread,
              groupValue: _selectedOption,
              onChanged: (value) => setState(() => _selectedOption = value!),
              dense: true,
            ),
            
            RadioListTile<BulkDownloadOption>(
              title: Text('Latest chapters'),
              value: BulkDownloadOption.latest,
              groupValue: _selectedOption,
              onChanged: (value) => setState(() => _selectedOption = value!),
              dense: true,
            ),
            if (_selectedOption == BulkDownloadOption.latest) ...[
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Row(
                  children: [
                    Text('Count: '),
                    Expanded(
                      child: Slider(
                        value: _latestCount.toDouble(),
                        min: 1,
                        max: widget.chapters.length.toDouble(),
                        divisions: widget.chapters.length - 1,
                        label: _latestCount.toString(),
                        onChanged: (value) => setState(() => _latestCount = value.round()),
                      ),
                    ),
                    Text(_latestCount.toString()),
                  ],
                ),
              ),
            ],
            
            RadioListTile<BulkDownloadOption>(
              title: Text('Chapter range'),
              value: BulkDownloadOption.range,
              groupValue: _selectedOption,
              onChanged: (value) => setState(() => _selectedOption = value!),
              dense: true,
            ),
            if (_selectedOption == BulkDownloadOption.range) ...[
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('From: '),
                        Expanded(
                          child: Slider(
                            value: _startIndex.toDouble(),
                            min: 0,
                            max: widget.chapters.length - 1.0,
                            divisions: widget.chapters.length - 1,
                            label: widget.chapters[_startIndex].name ?? 'Chapter ${_startIndex + 1}',
                            onChanged: (value) {
                              setState(() {
                                _startIndex = value.round();
                                if (_startIndex > _endIndex) {
                                  _endIndex = _startIndex;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text('To: '),
                        Expanded(
                          child: Slider(
                            value: _endIndex.toDouble(),
                            min: _startIndex.toDouble(),
                            max: widget.chapters.length - 1.0,
                            divisions: widget.chapters.length - 1 - _startIndex,
                            label: widget.chapters[_endIndex].name ?? 'Chapter ${_endIndex + 1}',
                            onChanged: (value) => setState(() => _endIndex = value.round()),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Chapters ${_startIndex + 1} to ${_endIndex + 1} (${_endIndex - _startIndex + 1} chapters)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final chaptersToDownload = _getChaptersToDownload();
            await _downloadChapters(chaptersToDownload);
            Navigator.of(context).pop();
          },
          child: Text('Download ${_getChaptersToDownload().length} chapters to device'),
        ),
      ],
    );
  }

  List<ChapterDto> _getChaptersToDownload() {
    switch (_selectedOption) {
      case BulkDownloadOption.all:
        return widget.chapters;
      case BulkDownloadOption.unread:
        return widget.chapters.where((c) => !c.isRead.ifNull()).toList();
      case BulkDownloadOption.latest:
        return widget.chapters.take(_latestCount).toList();
      case BulkDownloadOption.range:
        return widget.chapters.sublist(_startIndex, _endIndex + 1);
    }
  }

  Future<void> _downloadChapters(List<ChapterDto> chapters) async {
    final downloadQueue = ref.read(localDownloadQueueProvider.notifier);
    
    for (final chapter in chapters) {
      await downloadQueue.enqueueChapter(
        mangaId: widget.manga.id,
        chapterId: chapter.id,
        mangaTitle: widget.manga.title,
        chapterName: chapter.name,
        mangaThumbnailUrl: widget.manga.thumbnailUrl,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${chapters.length} chapters to download queue'),
          action: SnackBarAction(
            label: 'View Queue',
            onPressed: () {
              // TODO: Navigate to download queue screen
            },
          ),
        ),
      );
    }
  }
}

enum BulkDownloadOption {
  all,
  unread,
  latest,
  range,
}
