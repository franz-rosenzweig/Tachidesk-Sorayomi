// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../../constants/db_keys.dart';
import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../utils/mixin/shared_preferences_client_mixin.dart';

part 'enhanced_reader_tile.g.dart';

@riverpod
class EnhancedReaderKey extends _$EnhancedReaderKey
    with SharedPreferenceClientMixin<bool> {
  @override
  bool? build() => initialize(DBKeys.enhancedReader);
}

class EnhancedReaderTile extends ConsumerWidget {
  const EnhancedReaderTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enhancedReader = ref.watch(enhancedReaderKeyProvider);
    return SwitchListTile(
      secondary: const Icon(Icons.flash_on_rounded),
      title: Text('Enhanced Reader Mode'),
      subtitle: Text('Improved image caching and smooth loading'),
      onChanged: ref.read(enhancedReaderKeyProvider.notifier).update,
      value: enhancedReader.ifNull(false),
    );
  }
}
