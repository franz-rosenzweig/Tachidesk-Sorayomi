// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

part of '../custom_extensions.dart';

extension AsyncValueExtensions<T> on AsyncValue<T> {
  bool get isNotLoading => !isLoading;

  void _showToastOnError(Toast toast) {
    if (!isRefreshing) {
      whenOrNull(
        error: (error, stackTrace) {
          toast.close();
          toast.showError(error.toString());
        },
      );
    }
  }

  void showToastOnError(Toast? toast, {bool withMicrotask = false}) {
    if (toast == null) return;
    if (withMicrotask) {
      Future.microtask(() => (this._showToastOnError(toast)));
    } else {
      this._showToastOnError(toast);
    }
  }

  T? valueOrToast(Toast? toast, {bool withMicrotask = false}) =>
      (this..showToastOnError(toast, withMicrotask: withMicrotask)).valueOrNull;

  U showUiWhenData<U extends Widget>(
    BuildContext context,
    U Function(T data) data,
  ) {
    return switch (this) {
      AsyncData(:final value) => data(value),
      AsyncError(:final error) => Emoticons(
          title: error.toString(),
        ) as U,
      _ => const CenterSorayomiShimmerIndicator() as U,
    };
  }

  AsyncValue<U> copyWithData<U>(U Function(T) data) => when(
        skipError: true,
        data: (prev) => AsyncData(data(prev)),
        error: (error, stackTrace) => AsyncError<U>(error, stackTrace),
        loading: () => AsyncLoading<U>(),
      );
}
