import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../widgets/emoticons.dart';
import '../../../../widgets/input_popup/domain/settings_prop_type.dart';
import '../../../../widgets/input_popup/settings_prop_tile.dart';
import '../../../../widgets/section_title.dart';
import '../../../manga_book/presentation/local_downloads/local_downloads_settings_screen.dart';
import '../../../manga_book/data/offline_catalog_actions.dart';
import '../../controller/server_controller.dart';
import '../../domain/settings/settings.dart';
import 'data/downloads_settings_repository.dart';

class DownloadsSettingsScreen extends ConsumerWidget {
  const DownloadsSettingsScreen({super.key});

  @override
  Widget build(context, ref) {
    final repository = ref.watch(downloadsSettingsRepositoryProvider);
    final serverSettings = ref.watch(settingsProvider);
    return ListTileTheme(
      data: const ListTileThemeData(
        subtitleTextStyle: TextStyle(color: Colors.grey),
      ),
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.downloads)),
        body: RefreshIndicator(
          onRefresh: () => ref.refresh(settingsProvider.future),
          child: serverSettings.when(
            data: (data) {
              final DownloadsSettingsDto? downloadsSettingsDto = data;
              if (downloadsSettingsDto == null) {
                return _buildOfflineView(context);
              }
              final rebuildState = ref.watch(offlineCatalogRebuildControllerProvider);
              return ListView(
                children: [
                  SectionTitle(title: "Local Downloads"),
                  ListTile(
                    title: Text("Local Downloads Settings"),
                    subtitle: Text("Configure on-device downloads storage"),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const LocalDownloadsSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.build_circle_outlined),
                    title: const Text('Rebuild Offline Catalog'),
                    subtitle: Text(rebuildState.isLoading
                        ? 'Rebuilding catalog from manifests...'
                        : 'Scan downloaded chapters and recreate catalog index'),
                    trailing: rebuildState.isLoading
                        ? const SizedBox(width:24,height:24,child:CircularProgressIndicator(strokeWidth:2))
                        : const Icon(Icons.play_arrow),
                    onTap: rebuildState.isLoading ? null : () async {
                      final controller = ref.read(offlineCatalogRebuildControllerProvider.notifier);
                      await controller.rebuild();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Offline catalog rebuild complete')),
                        );
                      }
                    },
                  ),
                  SectionTitle(title: context.l10n.general),
                  SettingsPropTile(
                    title: context.l10n.downloadLocation,
                    description: context.l10n.downloadLocationHint,
                    type: SettingsPropType.textField(
                      hintText:
                          context.l10n.enterProp(context.l10n.downloadLocation),
                      value: downloadsSettingsDto.downloadsPath,
                      onChanged: repository.updateDownloadsLocation,
                    ),
                    subtitle: downloadsSettingsDto.downloadsPath,
                  ),
                  SettingsPropTile(
                    title: context.l10n.saveAsCBZArchive,
                    type: SettingsPropType.switchTile(
                      value: downloadsSettingsDto.downloadAsCbz,
                      onChanged: repository.updateDownloadAsCbz,
                    ),
                  ),
                  SectionTitle(title: context.l10n.autoDownload),
                  SettingsPropTile(
                    title: context.l10n.autoDownloadNewChapters,
                    type: SettingsPropType.switchTile(
                      value: downloadsSettingsDto.autoDownloadNewChapters,
                      onChanged: repository.toggleAutoDownloadNewChapters,
                    ),
                  ),
                  SettingsPropTile(
                    title: context.l10n.chapterDownloadLimit,
                    description: context.l10n.chapterDownloadLimitDesc,
                    type: SettingsPropType.numberSlider(
                      value: downloadsSettingsDto.autoDownloadNewChaptersLimit,
                      min: 0,
                      max: 20,
                      onChanged: repository.updateAutoDownloadNewChaptersLimit,
                    ),
                    subtitle: context.l10n.nChapters(
                        downloadsSettingsDto.autoDownloadNewChaptersLimit),
                  ),
                  SettingsPropTile(
                    title: context.l10n.excludeEntryWithUnreadChapters,
                    type: SettingsPropType.switchTile(
                      value:
                          downloadsSettingsDto.excludeEntryWithUnreadChapters,
                      onChanged:
                          repository.toggleExcludeEntryWithUnreadChapters,
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _buildOfflineView(context),
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineView(BuildContext context) {
    return ListView(
      children: [
        SectionTitle(title: "Local Downloads"),
        ListTile(
          title: Text("Local Downloads Settings"),
          subtitle: Text("Configure on-device downloads storage"),
          trailing: Icon(Icons.arrow_forward_ios),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const LocalDownloadsSettingsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  "Server Offline",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  "Server downloads settings are not available while offline. Local downloads settings are still accessible above.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
