import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../utils/extensions/custom_extensions.dart';
import '../data/settings_repository.dart';
import '../domain/settings/settings.dart';

part 'server_controller.g.dart';

@riverpod
class Settings extends _$Settings {
  @override
  Future<SettingsDto?> build() async {
    try {
      return await ref.watch(settingsRepositoryProvider).getServerSettings();
    } catch (e) {
      // Return null for connection errors (timeout, network, etc.)
      // This allows the UI to show offline state instead of error
      return null;
    }
  }

  void updateState(SettingsDto value) =>
      state = state.copyWithData((_) => value);
}
