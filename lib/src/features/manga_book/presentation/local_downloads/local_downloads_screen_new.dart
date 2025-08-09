                    // Provide repair action: after a validation run user can tap integrity icon to attempt repair (full re-download for now)
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// import '../../../../routes/router_config.dart'; // not used currently
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../widgets/server_image.dart';
import '../../data/local_downloads/local_downloads_repository.dart';
import '../../data/offline_catalog_repository.dart';
import '../../data/offline_bootstrap_service.dart';
import '../../data/local_downloads/downloads_integrity_service.dart';
import '../../data/local_downloads/storage_path_resolver.dart';

class LocalDownloadsScreen extends ConsumerWidget {
  const LocalDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
  // Generated provider name from @riverpod class OfflineCatalogProvider is offlineCatalogProviderProvider
  final catalog = ref.watch(offlineCatalogProviderProvider);
  final downloadsRepo = ref.read(localDownloadsRepositoryProvider);
    
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
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  // Debug info about the directory we're checking
                  await ref.read(localDownloadsRepositoryProvider).debugBaseDirectory();
                  
                  // Refresh the catalog
          final repo = ref.read(offlineCatalogRepositoryProvider);
          final rebuilt = await repo.rebuildFromManifests();
          ref.read(offlineCatalogProviderProvider.notifier).setCatalog(rebuilt);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Refreshed offline catalog')),
                    );
                  }
                },
                child: const Text('Refresh Catalog'),
              ),
            ],
          );
    }

  return FutureBuilder(
          future: Future.wait([
            downloadsRepo.getStoragePathInfo(),
            downloadsRepo.getStorageUsage(),
          ]),
          builder: (context, snapshot) {
            final headerWidgets = <Widget>[];
            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
              final pathInfo = snapshot.data![0] as StoragePathResult;
              final usage = snapshot.data![1] as StorageUsage;
              headerWidgets.add(
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: ListTile(
                    title: Text('Storage: ${pathInfo.directory.path}'),
                    subtitle: Text('Used ${usage.formattedSize} • Free ${usage.formattedFreeSpace}'),
                    leading: Icon(pathInfo.isReliable ? Icons.folder : Icons.warning, color: pathInfo.isReliable ? Colors.green : Colors.orange),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Validate Downloads',
                      onPressed: () async {
                        final report = await ref.read(downloadsIntegrityServiceProvider).validateAll();
                        ref.read(integrityStatusCacheProvider.notifier).updateFromReport(report);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Validation: missing=${report.missingFiles} sizeMismatch=${report.sizeMismatches} in ${report.pagesChecked} pages (${report.elapsed.inMilliseconds}ms)')),
                          );
                        }
                      },
                    ),
                  ),
                ),
              );
            } else {
              headerWidgets.add(const LinearProgressIndicator());
            }
            final totalItems = headerWidgets.length + catalog.manga.length; // ensure int
            return ListView.builder(
              itemCount: totalItems,
              itemBuilder: (context, index) {
                if (index < headerWidgets.length) return headerWidgets[index];
                final manga = catalog.manga[index - headerWidgets.length];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ExpansionTile(
                leading: (manga.cover != null && manga.cover!.isNotEmpty) 
                  ? ServerImage(
                      imageUrl: manga.cover!,
                      size: const Size(56, 80),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 56,
                      height: 80,
                      color: Colors.grey[300],
                      child: const Icon(Icons.book),
                    ),
                title: Text(
                  manga.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text('${manga.chapters.length} chapters downloaded'),
                children: manga.chapters.map((chapter) {
                  // Simple integrity status badge placeholder (green if pageCount > 0 else warning)
                  final statusMap = ref.watch(integrityStatusCacheProvider);
                  final key = '${manga.mangaId}:${chapter.chapterId}';
                  final status = statusMap[key];
                  Color color;
                  IconData icon;
                  switch (status) {
                    case ChapterIntegrityStatus.ok:
                      color = Colors.green.shade600; icon = Icons.verified;
                      break;
                    case ChapterIntegrityStatus.partial:
                      color = Colors.amber.shade700; icon = Icons.warning_amber_rounded;
                      break;
                    case ChapterIntegrityStatus.corrupt:
                      color = Colors.red.shade600; icon = Icons.error_outline;
                      break;
                    default:
                      color = Colors.grey; icon = Icons.help_outline;
                  }
                  final integrityIcon = Icon(icon, color: color, size: 18);
                  return ListTile(
                    title: Text(chapter.name),
                    subtitle: Text(
                      'Chapter ${chapter.number} • ${chapter.pageCount} pages${chapter.readPage > 0 ? ' • Page ${chapter.readPage}' : ''}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (chapter.readPage > 0)
                          Icon(Icons.bookmark, color: Theme.of(context).primaryColor, size: 20),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: (status == ChapterIntegrityStatus.ok) ? null : () async {
                            // Naive: always attempt repair (could gate on status != ok later)
                            try {
                              final manifest = await downloadsRepo.getLocalChapterManifest(manga.mangaId, chapter.chapterId);
                              if (manifest != null) {
                                final repaired = await ref.read(downloadsIntegrityServiceProvider).repairChapter(manifest, ref: ref as Ref);
                                if (repaired > 0) {
                                  final report = await ref.read(downloadsIntegrityServiceProvider).validateAll();
                                  ref.read(integrityStatusCacheProvider.notifier).updateFromReport(report);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Repair attempted (repaired $repaired pages)')));
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Repair failed: $e')));
                              }
                            }
                          },
                          child: Opacity(
                            opacity: status == ChapterIntegrityStatus.ok ? 0.4 : 1,
                            child: integrityIcon,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      // TODO: integrate with app router when routes are typed
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SizedBox.shrink()),
                      );
                    },
                  );
                }).toList(),
                  ),
                );
              },
            );
          },
        );
  }
}
