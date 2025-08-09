// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../../data/manga_book/manga_book_repository.dart';
import '../../../data/local_downloads/local_downloads_repository.dart';
import '../../../domain/chapter/chapter_model.dart';
import '../../../domain/chapter_page/chapter_page_model.dart';
import '../../../domain/local_downloads/local_downloads_model.dart';
import '../../../domain/chapter_page/graphql/__generated__/fragment.graphql.dart';

part 'reader_controller.g.dart';

// Simple connectivity provider
@riverpod
class ConnectivityStatus extends _$ConnectivityStatus {
  @override
  Future<bool> build() async {
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    
    // Consider online if any connection type is available
    return result.contains(ConnectivityResult.mobile) || 
           result.contains(ConnectivityResult.wifi) ||
           result.contains(ConnectivityResult.ethernet) ||
           result.contains(ConnectivityResult.other);
  }
  
  void refresh() => ref.invalidateSelf();
}

// Exception for when chapter is not available offline
class OfflineNotAvailableException implements Exception {
  final String message;
  OfflineNotAvailableException(this.message);
  
  @override
  String toString() => 'OfflineNotAvailableException: $message';
}

// Result wrapper to distinguish local vs network pages
class ChapterPagesResult {
  final List<String> pages;
  final bool isLocal;
  final LocalChapterManifest? manifest; // Available if local
  
  ChapterPagesResult.local(this.manifest) : 
    pages = manifest?.pageFiles ?? [],
    isLocal = true;
    
  ChapterPagesResult.remote(ChapterPagesDto? networkPages) : 
    pages = networkPages?.pages ?? [],
    isLocal = false,
    manifest = null;
    
  // Convert to ChapterPagesDto for compatibility with existing reader modes
  ChapterPagesDto toChapterPagesDto(int chapterId) {
    return Fragment$ChapterPagesDto(
      chapter: Fragment$ChapterPagesDto$chapter(
        id: chapterId,
        pageCount: pages.length,
      ),
      pages: pages,
    );
  }
}

@riverpod
FutureOr<ChapterDto?> chapter(
  Ref ref, {
  required int chapterId,
}) =>
    ref.watch(mangaBookRepositoryProvider).getChapter(chapterId: chapterId);

@riverpod
Future<ChapterPagesDto?> chapterPages(Ref ref, {required int chapterId}) => ref
    .watch(mangaBookRepositoryProvider)
    .getChapterPages(chapterId: chapterId);

// Local chapter pages provider - loads manifest and returns local page file paths
@riverpod
Future<LocalChapterManifest?> localChapterPages(
  Ref ref, 
  int mangaId, 
  int chapterId,
) async {
  final repo = LocalDownloadsRepository(ref);
  final manifest = await repo.getLocalChapterManifest(mangaId, chapterId);
  
  if (kDebugMode && manifest != null) {
    print('LocalChapterPages: Found local manifest for manga $mangaId, chapter $chapterId with ${manifest.pageFiles.length} pages');
  }
  
  return manifest;
}

// Unified provider that decides between local and network
@riverpod
Future<ChapterPagesResult> chapterPagesUnified(
  Ref ref, 
  int mangaId, 
  int chapterId,
) async {
  try {
    // First check if we have a local manifest
    final localManifest = await ref.watch(localChapterPagesProvider(mangaId, chapterId).future);
    
    if (localManifest != null) {
      if (kDebugMode) {
        print('ChapterPagesUnified: Using local pages for manga $mangaId, chapter $chapterId');
      }
      return ChapterPagesResult.local(localManifest);
    }
    
    // Check connectivity
    final isOnline = await ref.watch(connectivityStatusProvider.future);
    if (!isOnline) {
      throw OfflineNotAvailableException(
        'Chapter $chapterId not downloaded and device is offline'
      );
    }
    
    // Fallback to network
    if (kDebugMode) {
      print('ChapterPagesUnified: Using network pages for manga $mangaId, chapter $chapterId');
    }
    final networkPages = await ref.watch(chapterPagesProvider(chapterId: chapterId).future);
    return ChapterPagesResult.remote(networkPages);
    
  } catch (e) {
    if (kDebugMode) {
      print('ChapterPagesUnified: Error loading pages for manga $mangaId, chapter $chapterId: $e');
    }
    rethrow;
  }
}
