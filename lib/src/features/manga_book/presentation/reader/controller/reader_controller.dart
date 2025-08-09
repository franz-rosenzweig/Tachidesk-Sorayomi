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
import '../../../data/offline_bootstrap_service.dart';
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
  // Redirect to new provider
  return await ref.watch(localChapterManifestProvider(mangaId, chapterId).future);
}

// Unified provider that decides between local and network
@riverpod
Future<ChapterPagesResult> chapterPagesUnified(
  Ref ref, 
  int mangaId, 
  int chapterId,
) async {
  // NEW: Use decision provider for early branching
  return await ref.watch(chapterPagesDecisionProvider(mangaId, chapterId).future);
}

// NEW: Decision provider that implements early offline/online branching
@riverpod
Future<ChapterPagesResult> chapterPagesDecision(
  Ref ref,
  int mangaId,
  int chapterId,
) async {
  if (kDebugMode) {
    print('ChapterPagesDecision: Starting decision for manga $mangaId, chapter $chapterId');
  }
  
  try {
    // Get app mode synchronously (no await)
    final appMode = ref.read(appModeProviderProvider);
    final isOfflineMode = appMode == AppMode.offline;
    
    if (kDebugMode) {
      print('ChapterPagesDecision: App mode is $appMode, offline mode: $isOfflineMode');
    }
    
    // Check for local manifest first
    final localManifest = await ref.watch(localChapterManifestProvider(mangaId, chapterId).future);
    
    if (isOfflineMode) {
      // OFFLINE MODE: Only use local, never attempt network
      if (localManifest != null) {
        if (kDebugMode) {
          print('ChapterPagesDecision: OFFLINE - Using local manifest with ${localManifest.pageFiles.length} pages');
        }
        return ChapterPagesResult.local(localManifest);
      } else {
        if (kDebugMode) {
          print('ChapterPagesDecision: OFFLINE - No local manifest available');
            print('ChapterPagesDecision: CONFIRM no network request will be made in offline mode.');
        }
        throw OfflineNotAvailableException('Chapter $chapterId not downloaded and device is offline');
      }
    }
    
    // ONLINE MODE: Prefer local if available, fallback to network
    if (localManifest != null) {
      if (kDebugMode) {
        print('ChapterPagesDecision: ONLINE - Local manifest available, using local pages');
      }
      return ChapterPagesResult.local(localManifest);
    }
    
    // Fallback to network
    if (kDebugMode) {
      print('ChapterPagesDecision: ONLINE - No local manifest, fetching from network');
    }
    
    final networkPages = await ref.watch(chapterPagesProvider(chapterId: chapterId).future);
    if (kDebugMode) {
      print('ChapterPagesDecision: Network pages loaded, ${networkPages?.pages.length ?? 0} pages');
    }
    
    return ChapterPagesResult.remote(networkPages);
    
  } catch (e) {
    if (kDebugMode) {
      print('ChapterPagesDecision: ERROR for manga $mangaId, chapter $chapterId: $e');
      print('ChapterPagesDecision: Error type: ${e.runtimeType}');
      if (e is OfflineNotAvailableException) {
        print('ChapterPagesDecision: This is an offline availability error - expected behavior');
      } else {
        print('ChapterPagesDecision: This is an unexpected error that should be investigated');
      }
    }
    rethrow;
  }
}

// NEW: Local manifest provider (replaces localChapterPages)
@riverpod
Future<LocalChapterManifest?> localChapterManifest(
  Ref ref, 
  int mangaId, 
  int chapterId,
) async {
  if (kDebugMode) {
    print('LocalChapterManifest: Checking for manifest - manga $mangaId, chapter $chapterId');
  }
  
  final repo = LocalDownloadsRepository(ref);
  final manifest = await repo.getLocalChapterManifest(mangaId, chapterId);
  
  if (kDebugMode) {
    if (manifest != null) {
      print('LocalChapterManifest: Found manifest with ${manifest.pageFiles.length} pages');
      print('LocalChapterManifest: Chapter: ${manifest.chapterName}');
      print('LocalChapterManifest: Manga: ${manifest.mangaTitle}');
    } else {
      print('LocalChapterManifest: No manifest found');
    }
  }
  
  return manifest;
}
