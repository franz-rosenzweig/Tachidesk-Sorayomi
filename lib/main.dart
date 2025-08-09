// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/features/about/presentation/about/controllers/about_controller.dart';
import 'dart:io';
import 'dart:convert';
import 'src/features/manga_book/data/local_downloads/local_downloads_settings_repository.dart';
import 'src/features/manga_book/data/local_downloads/ios_bookmark_service.dart';
import 'src/global_providers/global_providers.dart';
import 'src/sorayomi.dart';

final GlobalKey<ScaffoldMessengerState> globalScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final packageInfo = await PackageInfo.fromPlatform();
  final sharedPreferences = await SharedPreferences.getInstance();
  await initHiveForFlutter();

  SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  GoRouter.optionURLReflectsImperativeAPIs = true;
  runApp(
    ProviderScope(
      overrides: [
        packageInfoProvider.overrideWithValue(packageInfo),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        hiveStoreProvider.overrideWithValue(HiveStore())
      ],
  child: Sorayomi(scaffoldMessengerKey: globalScaffoldMessengerKey),
    ),
  );

  // Phase 5: Attempt bookmark re-resolution after runApp (non-blocking)
  if (Platform.isIOS) {
    Future.microtask(() async {
      final repo = LocalDownloadsSettingsRepository();
      final b64 = await repo.getBookmark();
      if (b64 != null) {
        try {
          final bytes = base64Decode(b64);
          final bd = ByteData.view(bytes.buffer);
          final service = IOSBookmarkService();
          final resolved = await service.resolveBookmark(bd);
          if (resolved.status == IOSBookmarkStatus.resolved && resolved.path != null) {
            // Re-set path silently (will be validated later in resolver)
            await repo.setLocalDownloadsPath(resolved.path!);
          } else {
            globalScaffoldMessengerKey.currentState?.showSnackBar(
              const SnackBar(content: Text('External folder unavailable – reverted to sandbox')),
            );
          }
        } catch (_) {
          // Ignore; fallback will occur via resolver
          globalScaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Failed to access external folder – using internal storage')),
          );
        }
      }
    });
  }
}
