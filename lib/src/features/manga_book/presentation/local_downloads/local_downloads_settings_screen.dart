import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../widgets/emoticons.dart';
import '../../../../widgets/input_popup/domain/settings_prop_type.dart';
import '../../../../widgets/input_popup/settings_prop_tile.dart';
import '../../../../widgets/section_title.dart';
import '../../data/local_downloads/local_downloads_settings_repository.dart';

class LocalDownloadsSettingsScreen extends ConsumerWidget {
  const LocalDownloadsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localPathAsync = ref.watch(localDownloadsPathProvider);
    final repository = ref.read(localDownloadsSettingsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.downloads)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(localDownloadsPathProvider.future),
        child: localPathAsync.when(
          data: (localPath) {
            return ListView(
              children: [
                SectionTitle(title: "Local Downloads Settings"),
                SettingsPropTile(
                  title: "Local Downloads Directory",
                  description: localPath ?? "Choose where to save downloaded manga chapters on this device",
                  type: SettingsPropType.directoryPicker(
                    value: localPath,
                    hintText: "Select directory for downloads",
                    onChanged: (path) async {
                      await repository.setLocalDownloadsPath(path);
                      ref.invalidate(localDownloadsPathProvider);
                      return null; // Not server-side, so no return value needed
                    },
                  ),
                ),
                ListTile(
                  title: Text("Reset to Default"),
                  subtitle: Text("Use the default downloads directory"),
                  trailing: Icon(Icons.restore),
                  onTap: () async {
                    await repository.clearLocalDownloadsPath();
                    ref.invalidate(localDownloadsPathProvider);
                  },
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Note: Changing the downloads directory will not move existing downloads. "
                    "New downloads will be saved to the selected location.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Emoticons(
            title: "Error loading settings",
            subTitle: error.toString(),
          ),
        ),
      ),
    );
  }

  Future<String> _getDefaultPath() async {
    final docs = await getApplicationDocumentsDirectory();
    return docs.path;
  }
}
