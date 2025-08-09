// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../domain/local_downloads/local_downloads_model.dart';
import 'local_download_queue.dart';
import 'local_downloads_repository.dart';

/// Chapter integrity validation engine
class ChapterValidator {
  static const int sizeTolerance = 5; // 5% size tolerance for compression variations
  
  /// Validate a downloaded chapter's integrity
  static Future<ValidationResult> validateChapter(
    LocalDownloadsRepository repository,
    int mangaId,
    int chapterId,
  ) async {
    try {
      if (kDebugMode) {
        print('ChapterValidator: Starting validation for manga $mangaId, chapter $chapterId');
      }

      // Load manifest
      final manifest = await repository.getManifest(mangaId, chapterId);
      if (manifest == null) {
        if (kDebugMode) {
          print('ChapterValidator: No manifest found');
        }
        return ValidationResult.manifestCorrupted;
      }

      // Get chapter directory
      final chapterDir = await repository.getChapterDirectory(mangaId, chapterId);
      if (!await chapterDir.exists()) {
        if (kDebugMode) {
          print('ChapterValidator: Chapter directory does not exist');
        }
        return ValidationResult.missingFiles;
      }

      List<String> pagesToCheck;
      List<PageManifestEntry>? enhancedPages;

      if (manifest.isEnhanced && manifest.pages != null) {
        // Use enhanced manifest with detailed page info
        enhancedPages = manifest.pages!;
        pagesToCheck = enhancedPages.map((p) => p.fileName).toList();
        
        if (kDebugMode) {
          print('ChapterValidator: Using enhanced manifest with ${enhancedPages.length} page entries');
        }
      } else {
        // Fall back to legacy page files list
        pagesToCheck = manifest.pageFiles;
        
        if (kDebugMode) {
          print('ChapterValidator: Using legacy manifest with ${pagesToCheck.length} page files');
        }
      }

      // Check each page file
      final corruptedPages = <int>[];
      
      for (int i = 0; i < pagesToCheck.length; i++) {
        final fileName = pagesToCheck[i];
        final pageFile = File(p.join(chapterDir.path, fileName));
        
        if (!await pageFile.exists()) {
          if (kDebugMode) {
            print('ChapterValidator: Missing page file: $fileName');
          }
          corruptedPages.add(i);
          continue;
        }

        // Enhanced validation if we have metadata
        if (enhancedPages != null && i < enhancedPages.length) {
          final pageEntry = enhancedPages[i];
          final isValid = await _validatePageFile(pageFile, pageEntry);
          
          if (!isValid) {
            if (kDebugMode) {
              print('ChapterValidator: Corrupted page file: $fileName');
            }
            corruptedPages.add(i);
          }
        } else {
          // Basic validation for legacy manifests
          final isValid = await _validateBasicPageFile(pageFile);
          
          if (!isValid) {
            if (kDebugMode) {
              print('ChapterValidator: Invalid page file: $fileName');
            }
            corruptedPages.add(i);
          }
        }
      }

      // Determine validation result
      if (corruptedPages.isEmpty) {
        if (kDebugMode) {
          print('ChapterValidator: All pages valid');
        }
        return ValidationResult.valid;
      } else if (corruptedPages.length >= pagesToCheck.length * 0.5) {
        if (kDebugMode) {
          print('ChapterValidator: Majority of pages corrupted (${corruptedPages.length}/${pagesToCheck.length})');
        }
        return ValidationResult.corruptedFiles;
      } else {
        if (kDebugMode) {
          print('ChapterValidator: Some pages corrupted (${corruptedPages.length}/${pagesToCheck.length})');
        }
        return ValidationResult.missingFiles;
      }

    } catch (e) {
      if (kDebugMode) {
        print('ChapterValidator: Validation error: $e');
      }
      return ValidationResult.manifestCorrupted;
    }
  }

  /// Get list of corrupted page indices
  static Future<List<int>> getCorruptedPageIndices(
    LocalDownloadsRepository repository,
    int mangaId,
    int chapterId,
  ) async {
    try {
      final manifest = await repository.getManifest(mangaId, chapterId);
      if (manifest == null) return [];

      final chapterDir = await repository.getChapterDirectory(mangaId, chapterId);
      if (!await chapterDir.exists()) return [];

      final corruptedPages = <int>[];
      List<String> pagesToCheck;
      List<PageManifestEntry>? enhancedPages;

      if (manifest.isEnhanced && manifest.pages != null) {
        enhancedPages = manifest.pages!;
        pagesToCheck = enhancedPages.map((p) => p.fileName).toList();
      } else {
        pagesToCheck = manifest.pageFiles;
      }

      for (int i = 0; i < pagesToCheck.length; i++) {
        final fileName = pagesToCheck[i];
        final pageFile = File(p.join(chapterDir.path, fileName));
        
        if (!await pageFile.exists()) {
          corruptedPages.add(i);
          continue;
        }

        bool isValid;
        if (enhancedPages != null && i < enhancedPages.length) {
          isValid = await _validatePageFile(pageFile, enhancedPages[i]);
        } else {
          isValid = await _validateBasicPageFile(pageFile);
        }

        if (!isValid) {
          corruptedPages.add(i);
        }
      }

      return corruptedPages;
    } catch (e) {
      if (kDebugMode) {
        print('ChapterValidator: Error getting corrupted indices: $e');
      }
      return [];
    }
  }

  /// Validate a single page file with enhanced metadata
  static Future<bool> _validatePageFile(File pageFile, PageManifestEntry expected) async {
    try {
      // Check file size with tolerance
      final stat = await pageFile.stat();
      final actualSize = stat.size;
      final expectedSize = expected.expectedSize;
      
      if (expectedSize > 0) {
        final sizeDiff = (actualSize - expectedSize).abs();
        final tolerance = (expectedSize * sizeTolerance / 100).round();
        
        if (sizeDiff > tolerance) {
          if (kDebugMode) {
            print('ChapterValidator: Size mismatch for ${expected.fileName}: expected $expectedSize, got $actualSize (tolerance: $tolerance)');
          }
          return false;
        }
      }

      // Check image format
      final isValidImage = await _validateImageFormat(pageFile);
      if (!isValidImage) {
        if (kDebugMode) {
          print('ChapterValidator: Invalid image format for ${expected.fileName}');
        }
        return false;
      }

      // Check checksum if available
      if (expected.checksum != null) {
        final actualChecksum = await _calculateMD5(pageFile);
        if (actualChecksum != expected.checksum) {
          if (kDebugMode) {
            print('ChapterValidator: Checksum mismatch for ${expected.fileName}');
          }
          return false;
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('ChapterValidator: Error validating ${expected.fileName}: $e');
      }
      return false;
    }
  }

  /// Basic validation for legacy page files
  static Future<bool> _validateBasicPageFile(File pageFile) async {
    try {
      // Check if file exists and has content
      final stat = await pageFile.stat();
      if (stat.size == 0) {
        return false;
      }

      // Check image format
      return await _validateImageFormat(pageFile);
    } catch (e) {
      if (kDebugMode) {
        print('ChapterValidator: Error validating ${pageFile.path}: $e');
      }
      return false;
    }
  }

  /// Validate image file format by checking headers
  static Future<bool> _validateImageFormat(File file) async {
    try {
      // Read first 10 bytes to check image headers
      final bytes = await file.openRead(0, 10).first;
      
      if (bytes.length < 2) return false;

      // JPEG: FF D8
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
        return true;
      }

      // PNG: 89 50 4E 47
      if (bytes.length >= 4 && 
          bytes[0] == 0x89 && bytes[1] == 0x50 && 
          bytes[2] == 0x4E && bytes[3] == 0x47) {
        return true;
      }

      // WebP: RIFF....WEBP
      if (bytes.length >= 8) {
        final riff = String.fromCharCodes(bytes.sublist(0, 4));
        final webp = String.fromCharCodes(bytes.sublist(8, 12));
        if (riff == 'RIFF' && webp == 'WEBP') {
          return true;
        }
      }

      // GIF: GIF8
      if (bytes.length >= 4) {
        final gif = String.fromCharCodes(bytes.sublist(0, 4));
        if (gif == 'GIF8') {
          return true;
        }
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('ChapterValidator: Error checking image format: $e');
      }
      return false;
    }
  }

  /// Calculate MD5 checksum for a file
  static Future<String> _calculateMD5(File file) async {
    final bytes = await file.readAsBytes();
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Calculate MD5 checksum for byte data
  static String calculateMD5FromBytes(Uint8List bytes) {
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Update manifest with validation timestamp
  static Future<void> markAsValidated(
    LocalDownloadsRepository repository,
    int mangaId,
    int chapterId,
  ) async {
    try {
      final manifest = await repository.getManifest(mangaId, chapterId);
      if (manifest == null) return;

      // Create updated manifest with validation timestamp
      final updatedManifest = LocalChapterManifest(
        manifestVersion: manifest.manifestVersion,
        mangaId: manifest.mangaId,
        chapterId: manifest.chapterId,
        mangaTitle: manifest.mangaTitle,
        chapterName: manifest.chapterName,
        pageFiles: manifest.pageFiles,
        pages: manifest.pages,
        savedAt: manifest.savedAt,
        lastValidated: DateTime.now(),
        mangaThumbnailUrl: manifest.mangaThumbnailUrl,
        sourceUrl: manifest.sourceUrl,
      );

      await repository.saveManifest(mangaId, chapterId, updatedManifest);
      
      if (kDebugMode) {
        print('ChapterValidator: Marked chapter as validated: manga $mangaId, chapter $chapterId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ChapterValidator: Error marking as validated: $e');
      }
    }
  }
}
