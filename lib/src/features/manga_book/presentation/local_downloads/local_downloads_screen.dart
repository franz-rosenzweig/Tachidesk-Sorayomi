import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../routes/router_config.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../data/local_downloads/local_downloads_repository.dart';
import '../../domain/local_downloads/local_downloads_model.dart';

class LocalDownloadsScreen extends ConsumerWidget {
  const LocalDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(localDownloadsListProvider);
    return list.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(child: Text(context.l10n.noDownloads));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = items[index];
            return _LocalDownloadTile(item: item);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
    );
  }
}

class _LocalDownloadTile extends ConsumerWidget {
  const _LocalDownloadTile({required this.item});
  final LocalChapterManifest item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(item.mangaTitle, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${item.chapterName} • ${item.savedAt.toLocal()}',
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodySmall,
      ),
      onTap: () => ReaderRoute(
        mangaId: item.mangaId,
        chapterId: item.chapterId,
        showReaderLayoutAnimation: true,
      ).push(context),
      trailing: IconButton(
        icon: const Icon(Icons.delete_forever_rounded),
        onPressed: () async {
          await ref
              .read(localDownloadsRepositoryProvider)
              .deleteLocalChapter(item.mangaId, item.chapterId);
          ref.invalidate(localDownloadsListProvider);
        },
      ),
    );
  }
}
