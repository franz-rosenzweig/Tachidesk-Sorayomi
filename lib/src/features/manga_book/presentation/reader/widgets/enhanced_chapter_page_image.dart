// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../../widgets/server_image.dart';
import '../../../data/local_downloads/local_downloads_repository.dart';
import '../services/reader_image_cache.dart';

/// Enhanced chapter page image with caching and smooth loading
class EnhancedChapterPageImage extends ConsumerStatefulWidget {
  const EnhancedChapterPageImage({
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
    this.forceOffline = false,
    this.enablePrecaching = true,
  });

  final String imageUrl;
  final int mangaId;
  final int chapterId;
  final int pageIndex;
  final BoxFit? fit;
  final bool showReloadButton;
  final Widget Function(BuildContext, String, DownloadProgress)? progressIndicatorBuilder;
  final Widget Function(Widget child)? wrapper;
  final Size? size;
  final bool forceOffline;
  final bool enablePrecaching;

  @override
  ConsumerState<EnhancedChapterPageImage> createState() => _EnhancedChapterPageImageState();
}

class _EnhancedChapterPageImageState extends ConsumerState<EnhancedChapterPageImage>
    with AutomaticKeepAliveClientMixin {
  
  ui.Image? _cachedImage;
  bool _isLoading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true; // Prevent widget rebuild/reload

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(EnhancedChapterPageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mangaId != widget.mangaId ||
        oldWidget.chapterId != widget.chapterId ||
        oldWidget.pageIndex != widget.pageIndex) {
      _loadImage();
    }
  }

  String get _cacheKey => ReaderPrecacheService.generateCacheKey(
        widget.mangaId,
        widget.chapterId,
        widget.pageIndex,
      );

  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cache = ref.read(readerImageCacheProvider);
      
      // Check cache first
      final cachedImage = cache.getImage(_cacheKey);
      if (cachedImage != null) {
        setState(() {
          _cachedImage = cachedImage;
          _isLoading = false;
        });
        return;
      }

      // Try local file first
      final localFile = await ref
          .read(localDownloadsRepositoryProvider)
          .getLocalPageFile(widget.mangaId, widget.chapterId, widget.pageIndex);

      if (localFile != null && await localFile.exists()) {
        await _loadFromFile(localFile);
        return;
      }

      // If force offline, don't try network
      if (widget.forceOffline) {
        setState(() {
          _error = 'Image not available offline';
          _isLoading = false;
        });
        return;
      }

      // Load from network
      await _loadFromNetwork();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFromFile(File file) async {
    try {
      final precacheService = ref.read(readerPrecacheServiceProvider);
      final image = await precacheService.precacheFromFile(file, _cacheKey);
      
      if (mounted) {
        setState(() {
          _cachedImage = image;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load local image: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFromNetwork() async {
    try {
      // For now, fall back to the existing ServerImage widget
      // In a full implementation, we'd also cache network images
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load network image: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    Widget child;

    if (_cachedImage != null) {
      // Use cached decoded image for maximum performance
      child = CustomPaint(
        painter: _ImagePainter(_cachedImage!),
        size: widget.size ?? Size.infinite,
      );
    } else if (_isLoading) {
      // Show loading indicator
      child = Container(
        color: Theme.of(context).colorScheme.surface, // Consistent background
        child: Center(
          child: widget.progressIndicatorBuilder?.call(
            context,
            widget.imageUrl,
            DownloadProgress(widget.imageUrl, 0, 0),
          ) ?? const CircularProgressIndicator(),
        ),
      );
    } else if (_error != null) {
      // Show error state
      child = Container(
        color: Theme.of(context).colorScheme.surface,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                'Failed to load image',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (widget.showReloadButton) ...[
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loadImage,
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      // Fallback to existing ServerImage for network loading
      child = Container(
        color: Theme.of(context).colorScheme.surface, // Consistent background
        child: ServerImage(
          imageUrl: widget.imageUrl,
          fit: widget.fit,
          progressIndicatorBuilder: widget.progressIndicatorBuilder,
          size: widget.size,
        ),
      );
    }

    return widget.wrapper?.call(child) ?? child;
  }

  @override
  void dispose() {
    // Don't dispose the cached image as it might be used by other widgets
    super.dispose();
  }
}

/// Custom painter for rendering decoded ui.Image
class _ImagePainter extends CustomPainter {
  final ui.Image image;

  _ImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;

    if (size.width == double.infinity || size.height == double.infinity) {
      // Paint at natural size
      canvas.drawImage(image, Offset.zero, paint);
    } else {
      // Scale to fit the available size
      final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      final dst = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(image, src, dst, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ImagePainter oldDelegate) {
    return oldDelegate.image != image;
  }
}
