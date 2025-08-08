import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../../widgets/server_image.dart';
import '../../../data/local_downloads/local_downloads_repository.dart';

class ChapterPageImage extends ConsumerWidget {
  const ChapterPageImage({
    super.key,
    required this.imageUrl,
    required this.mangaId,
    required this.chapterId,
    required this.pageIndex,
    this.fit,
    this.showReloadButton = false,
    this.progressIndicatorBuilder,
    this.wrapper,
    this.size,
  });

  final String imageUrl;
  final int mangaId;
  final int chapterId;
  final int pageIndex; // 0-based
  final BoxFit? fit;
  final bool showReloadButton;
  final Widget Function(BuildContext, String, DownloadProgress)? progressIndicatorBuilder;
  final Widget Function(Widget child)? wrapper;
  final Size? size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<File?>(
      future: ref
          .read(localDownloadsRepositoryProvider)
          .getLocalPageFile(mangaId, chapterId, pageIndex),
      builder: (context, snap) {
        final file = snap.data;
        if (file != null) {
          // Local file exists - display it directly
          final image = Image.file(
            file, 
            fit: fit ?? BoxFit.contain,
            height: size?.height,
            width: size?.width,
            errorBuilder: (context, error, stackTrace) {
              if (kDebugMode) {
                print('Error loading local image ${file.path}: $error');
              }
              // Fallback to server image on error
              return ServerImage(
                imageUrl: imageUrl, 
                fit: fit,
                showReloadButton: showReloadButton,
                progressIndicatorBuilder: progressIndicatorBuilder,
                wrapper: wrapper,
                size: size,
              );
            },
          );
          return wrapper?.call(image) ?? image;
        }
        // Fallback to server image with all original parameters
        return ServerImage(
          imageUrl: imageUrl, 
          fit: fit,
          showReloadButton: showReloadButton,
          progressIndicatorBuilder: progressIndicatorBuilder,
          wrapper: wrapper,
          size: size,
        );
      },
    );
  }
}
