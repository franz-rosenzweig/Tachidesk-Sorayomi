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
    this.forceOffline = false, // New parameter for offline-only mode
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
  final bool forceOffline; // When true, never attempt server fallback

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<File?>(
      future: ref
          .read(localDownloadsRepositoryProvider)
          .getLocalPageFile(mangaId, chapterId, pageIndex),
      builder: (context, snap) {
        if (kDebugMode) {
          print('ChapterPageImage: mangaId=$mangaId, chapterId=$chapterId, pageIndex=$pageIndex');
          print('ChapterPageImage: snapshot state=${snap.connectionState}, hasData=${snap.hasData}, data=${snap.data?.path}');
          if (snap.hasError) {
            print('ChapterPageImage: Future error: ${snap.error}');
          }
        }
        
        final file = snap.data;
        if (file != null) {
          if (kDebugMode) {
            print('ChapterPageImage: Attempting to load local file: ${file.path}');
            print('ChapterPageImage: File exists check: ${file.existsSync()}');
            if (file.existsSync()) {
              final stats = file.statSync();
              print('ChapterPageImage: File size: ${stats.size} bytes');
              
              // Additional validation: check if file looks like an image
              try {
                final bytes = file.readAsBytesSync();
                print('ChapterPageImage: Read ${bytes.length} bytes from file');
                
                // Check for common image file signatures
                if (bytes.isNotEmpty) {
                  final header = bytes.take(10).toList();
                  print('ChapterPageImage: File header bytes: ${header.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
                  
                  // Check for JPEG signature (FF D8)
                  bool isJpeg = bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
                  // Check for PNG signature (89 50 4E 47)
                  bool isPng = bytes.length >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
                  // Check for WebP signature (52 49 46 46)
                  bool isWebp = bytes.length >= 4 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46;
                  
                  print('ChapterPageImage: Image format detected - JPEG: $isJpeg, PNG: $isPng, WebP: $isWebp');
                  
                  if (!isJpeg && !isPng && !isWebp) {
                    print('ChapterPageImage: WARNING: File does not appear to be a valid image format');
                  }
                } else {
                  print('ChapterPageImage: ERROR: File is empty');
                }
              } catch (e) {
                print('ChapterPageImage: ERROR reading file bytes: $e');
              }
            }
          }
          
          // Local file exists - try to display it directly
          Widget image;
          
          try {
            // Try using Image.memory for better error handling
            final bytes = file.readAsBytesSync();
            if (kDebugMode) {
              print('ChapterPageImage: Using Image.memory with ${bytes.length} bytes');
            }
            
            image = Image.memory(
              bytes,
              fit: fit ?? BoxFit.contain,
              height: size?.height,
              width: size?.width,
              errorBuilder: (context, error, stackTrace) {
                if (kDebugMode) {
                  print('ChapterPageImage: Image.memory error: $error');
                  print('ChapterPageImage: Error type: ${error.runtimeType}');
                  print('ChapterPageImage: StackTrace: $stackTrace');
                }
                
                // If Image.memory fails, try Image.file as fallback
                return Image.file(
                  file, 
                  fit: fit ?? BoxFit.contain,
                  height: size?.height,
                  width: size?.width,
                  errorBuilder: (context, error2, stackTrace2) {
                    if (kDebugMode) {
                      print('ChapterPageImage: Image.file also failed: $error2');
                    }
                    
                    if (forceOffline) {
                      return Container(
                        height: size?.height ?? 200,
                        width: size?.width ?? double.infinity,
                        color: Colors.grey[300],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load:\n${file.path}\nMemory Error: $error\nFile Error: $error2',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ),
                      );
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
              },
            );
          } catch (e) {
            if (kDebugMode) {
              print('ChapterPageImage: Failed to read file bytes: $e');
            }
            
            // Fall back to Image.file if byte reading fails
            image = Image.file(
              file, 
              fit: fit ?? BoxFit.contain,
              height: size?.height,
              width: size?.width,
              errorBuilder: (context, error, stackTrace) {
                if (kDebugMode) {
                  print('ChapterPageImage: Error loading local image ${file.path}: $error');
                  print('ChapterPageImage: Error type: ${error.runtimeType}');
                  print('ChapterPageImage: StackTrace: $stackTrace');
                  print('ChapterPageImage: File still exists: ${file.existsSync()}');
                }
                
                // If in offline mode, show error instead of trying server
                if (forceOffline) {
                  return Container(
                    height: size?.height ?? 200,
                    width: size?.width ?? double.infinity,
                    color: Colors.grey[300],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.grey,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load:\n${file.path}\nError: $error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  );
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
          }
          return wrapper?.call(image) ?? image;
        }
        
        if (kDebugMode) {
          print('ChapterPageImage: No local file found, forceOffline=$forceOffline');
        }
        
        // No local file found
        if (forceOffline) {
          // In offline mode, show placeholder instead of trying server
          return Container(
            height: size?.height ?? 200,
            width: size?.width ?? double.infinity,
            color: Colors.grey[300],
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi_off_outlined,
                    color: Colors.grey,
                    size: 48,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Offline Mode - No local file',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
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
