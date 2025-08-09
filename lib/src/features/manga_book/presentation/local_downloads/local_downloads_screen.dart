import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../utils/extensions/custom_extensions.dart';
import '../../data/offline_bootstrap_service.dart';

class LocalDownloadsScreen extends ConsumerWidget {
  const LocalDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(offlineCatalogProviderProvider);
    
    if (catalog.manga.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(context.l10n.noDownloads),
          const SizedBox(height: 16),
          Text(
            'Download some manga chapters to see them here.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    
    return ListView.builder(
      itemCount: catalog.manga.length,
      itemBuilder: (context, index) {
        final manga = catalog.manga[index];
        return ListTile(
          title: Text(manga.title),
          subtitle: Text('${manga.chapters.length} chapters downloaded'),
          onTap: () {
            // TODO: Navigate to manga details
          },
        );
      },
    );
  }
}
