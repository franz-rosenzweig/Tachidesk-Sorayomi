import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalDownloadsSettingsRepository {
  static const String _localDownloadsPathKey = 'local_downloads_path';
  static const String _localDownloadsBookmarkKey = 'local_downloads_path_bookmark_v1';
  
  Future<String?> getLocalDownloadsPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localDownloadsPathKey);
  }
  
  Future<void> setLocalDownloadsPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localDownloadsPathKey, path);
  }
  
  Future<void> clearLocalDownloadsPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localDownloadsPathKey);
    await prefs.remove(_localDownloadsBookmarkKey);
  }

  // iOS: store security-scoped bookmark (raw bytes base64) associated with custom path
  Future<void> setBookmark(String base64) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localDownloadsBookmarkKey, base64);
  }

  Future<String?> getBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localDownloadsBookmarkKey);
  }
}

final localDownloadsSettingsRepositoryProvider = Provider<LocalDownloadsSettingsRepository>(
  (ref) => LocalDownloadsSettingsRepository(),
);

final localDownloadsPathProvider = FutureProvider<String?>((ref) async {
  return ref.read(localDownloadsSettingsRepositoryProvider).getLocalDownloadsPath();
});
