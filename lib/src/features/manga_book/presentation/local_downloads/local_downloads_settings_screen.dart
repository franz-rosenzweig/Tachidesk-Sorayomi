import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../widgets/emoticons.dart';
import '../../../../widgets/input_popup/domain/settings_prop_type.dart';
import '../../../../widgets/input_popup/settings_prop_tile.dart';
import '../../../../widgets/section_title.dart';
import '../../data/local_downloads/local_downloads_repository.dart';
import '../../data/local_downloads/local_downloads_settings_repository.dart';
import '../../data/local_downloads/storage_path_resolver.dart';

class LocalDownloadsSettingsScreen extends ConsumerWidget {
  const LocalDownloadsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localPathAsync = ref.watch(localDownloadsPathProvider);
    final repository = ref.read(localDownloadsSettingsRepositoryProvider);
    final downloadsRepository = ref.read(localDownloadsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.downloads)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(localDownloadsPathProvider.future),
        child: localPathAsync.when(
          data: (localPath) {
            return ListView(
              children: [
                // Storage Path Section
                SectionTitle(title: "Storage Location"),
                
                // Current Path Info
                FutureBuilder<StoragePathResult>(
                  future: downloadsRepository.getStoragePathInfo(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final pathInfo = snapshot.data!;
                      return Column(
                        children: [
                          ListTile(
                            title: Text("Current Storage Location"),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pathInfo.directory.path),
                                Text(
                                  pathInfo.description,
                                  style: TextStyle(
                                    color: pathInfo.isReliable 
                                        ? Colors.green 
                                        : Colors.orange,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            leading: Icon(
                              pathInfo.isReliable 
                                  ? Icons.folder 
                                  : Icons.warning,
                              color: pathInfo.isReliable 
                                  ? Colors.green 
                                  : Colors.orange,
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.folder_open),
                              onPressed: () async {
                                // TODO: Open folder in system file manager
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Path: ${pathInfo.directory.path}')),
                                );
                              },
                            ),
                          ),
                          if (!pathInfo.isReliable)
                            Card(
                              color: Colors.orange.withOpacity(0.1),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning, color: Colors.orange),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Warning: Using temporary storage. Downloads may be lost when the app is closed.',
                                        style: TextStyle(color: Colors.orange),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    } else if (snapshot.hasError) {
                      return ListTile(
                        title: Text("Storage Path Error"),
                        subtitle: Text("${snapshot.error}"),
                        leading: Icon(Icons.error, color: Colors.red),
                      );
                    } else {
                      return ListTile(
                        title: Text("Loading storage information..."),
                        leading: CircularProgressIndicator(),
                      );
                    }
                  },
                ),
                
                SettingsPropTile(
                  title: "Custom Downloads Directory",
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
                    try {
                      await downloadsRepository.resetStoragePathToDefault();
                      ref.invalidate(localDownloadsPathProvider);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Storage path reset to default')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                ),
                
                // Storage Usage Section
                SectionTitle(title: "Storage Usage"),
                
                FutureBuilder<StorageUsage>(
                  future: downloadsRepository.getStorageUsage(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final usage = snapshot.data!;
                      
                      if (usage.error != null) {
                        return ListTile(
                          title: Text("Storage Usage Error"),
                          subtitle: Text("${usage.error}"),
                          leading: Icon(Icons.error, color: Colors.red),
                        );
                      }
                      
                      return Column(
                        children: [
                          ListTile(
                            title: Text("Total Storage Used"),
                            subtitle: Text("${usage.totalChapters} chapters, ${usage.totalFiles} files"),
                            trailing: Text(
                              usage.formattedSize,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            leading: Icon(Icons.storage),
                          ),
                          if (usage.totalChapters > 0)
                            ListTile(
                              title: Text("Average Chapter Size"),
                              trailing: Text(usage.formattedAverageChapterSize),
                              leading: Icon(Icons.analytics),
                            ),
                          if (usage.totalSize == 0)
                            ListTile(
                              title: Text("No downloads found"),
                              subtitle: Text("Start downloading chapters to see storage usage"),
                              leading: Icon(Icons.info),
                            ),
                        ],
                      );
                    } else if (snapshot.hasError) {
                      return ListTile(
                        title: Text("Storage Usage Error"),
                        subtitle: Text("${snapshot.error}"),
                        leading: Icon(Icons.error, color: Colors.red),
                      );
                    } else {
                      return ListTile(
                        title: Text("Calculating storage usage..."),
                        leading: CircularProgressIndicator(),
                      );
                    }
                  },
                ),
                
                // Migration Section
                SectionTitle(title: "Migration & Maintenance"),
                
                FutureBuilder<bool>(
                  future: downloadsRepository.isStorageMigrationNeeded(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data == true) {
                      return Card(
                        color: Colors.blue.withOpacity(0.1),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.move_to_inbox, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text(
                                    'Migration Available',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Your downloads can be moved to a more reliable location.',
                                style: TextStyle(color: Colors.blue),
                              ),
                              SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () async {
                                  try {
                                    await downloadsRepository.performStorageMigration();
                                    ref.invalidate(localDownloadsPathProvider);
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Migration completed successfully')),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Migration failed: $e')),
                                    );
                                  }
                                },
                                child: Text('Migrate Downloads'),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      return SizedBox.shrink();
                    }
                  },
                ),
                
                ListTile(
                  title: Text("Clear All Downloads"),
                  subtitle: Text("Remove all downloaded chapters and free up space"),
                  trailing: Icon(Icons.delete_forever, color: Colors.red),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Clear All Downloads'),
                        content: Text(
                          'This will permanently delete all downloaded chapters. This action cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text('Delete All', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      try {
                        await downloadsRepository.clearAllDownloads();
                        ref.invalidate(localDownloadsPathProvider);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('All downloads cleared')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error clearing downloads: $e')),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Note: On iOS, downloads are saved within the app's document directory for security. "
                    "Changing the downloads directory will not move existing downloads. "
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
