# Downloads & Offline Reading Architecture

## 🏗️ System Overview

The Tachidesk-Sorayomi offline reading system provides robust local manga storage with fallback capabilities, designed for iOS compliance and optimal performance.

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                    UI Layer                                 │
├─────────────────────────────────────────────────────────────┤
│  BulkDownloadDialog  │  MultiChapterBar  │  ReaderScreen    │
└─────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────┐
│                  Business Logic                             │
├─────────────────────────────────────────────────────────────┤
│  LocalDownloadQueue  │  DownloadProvider  │  OfflineLogic   │
└─────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────┐
│                 Storage Layer                               │
├─────────────────────────────────────────────────────────────┤
│  LocalDownloadsRepo  │  Hive Cache  │  File System         │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 Download Flow

### Single Chapter Download
```dart
// 1. User initiates download
onDownload(chapterId) 
  ↓
// 2. Add to queue
LocalDownloadQueue.addChapter(chapterId)
  ↓
// 3. Process with concurrency
_processQueue() // maxConcurrentDownloads: 3
  ↓
// 4. Download pages concurrently  
_downloadPagesForChapter() // maxConcurrentPagesPerChapter: 5
  ↓
// 5. Store with manifest
LocalDownloadsRepository.saveChapter()
```

### Bulk Download (Entire Manga)
```dart
BulkDownloadDialog.downloadEntireManga()
  ↓
// Batch chapters into queue
LocalDownloadQueue.addMultipleChapters(List<Chapter>)
  ↓
// Process with priority ordering
_processQueue() // Latest chapters first
```

---

## 📁 Storage Structure

### File Organization
```
ApplicationDocumentsDirectory/
├── tachidesk_downloads/
│   ├── manga_[id]/
│   │   ├── chapter_[id]/
│   │   │   ├── manifest.json      # Chapter metadata
│   │   │   ├── page_001.jpg       # Page images
│   │   │   ├── page_002.jpg
│   │   │   └── ...
│   │   └── chapter_[id2]/
│   └── manga_[id2]/
└── cache/                          # Temporary/cached data
```

### Manifest Structure
```json
{
  "chapterId": "123",
  "mangaId": "456", 
  "title": "Chapter 1",
  "pageCount": 15,
  "downloadedAt": "2024-01-01T12:00:00Z",
  "pages": [
    {
      "index": 0,
      "filename": "page_001.jpg",
      "url": "original_page_url",
      "size": 245760
    }
  ],
  "isComplete": true,
  "version": 2
}
```

---

## 🧠 Provider Architecture

### Key Providers

**`localChapterPagesProvider`**
- **Input**: `(mangaId, chapterId)`
- **Output**: `List<String>` (local file paths)
- **Purpose**: Provides page paths for offline reader

**`downloadQueueProvider`**
- **Output**: `AsyncValue<DownloadQueue>`
- **Purpose**: Real-time queue state for UI

**`chapterDownloadProvider`**
- **Input**: `chapterId`
- **Output**: `AsyncValue<DownloadState>`
- **Purpose**: Individual chapter download status

### Provider Flow
```dart
// Offline reading detection
ref.watch(localChapterPagesProvider((mangaId, chapterId)))
  ↓
// Falls back to network if local unavailable
if (localPages.isEmpty) {
  return ref.watch(networkChapterPagesProvider(...));
}
```

---

## ⚡ Performance Optimizations

### Concurrency Configuration
```dart
class LocalDownloadQueue {
  static const int maxConcurrentDownloads = 3;        // Total chapters
  static const int maxConcurrentPagesPerChapter = 5;  // Pages per chapter
  static const Duration retryDelay = Duration(seconds: 2);
}
```

### HTTP Client Optimization
```dart
// Shared client with keep-alive
static final _httpClient = http.Client();

// Exponential backoff for retries
static Future<Uint8List> _downloadWithRetry(String url) async {
  for (int attempt = 0; attempt < 3; attempt++) {
    try {
      final response = await _httpClient.get(Uri.parse(url));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (e) {
      await Future.delayed(Duration(seconds: math.pow(2, attempt).toInt()));
    }
  }
  throw Exception('Download failed after retries');
}
```

### Memory Management
- Image caching with `flutter_cache_manager`
- Lazy loading of page data
- Automatic cleanup of temp files
- Bounded concurrent operations

---

## 🔧 Error Handling

### Corruption Detection
```dart
Future<bool> _isChapterCorrupted(String chapterId) async {
  final manifest = await _loadManifest(chapterId);
  if (manifest == null) return true;
  
  // Check each page file exists
  for (final page in manifest.pages) {
    final file = File(page.localPath);
    if (!await file.exists()) return true;
  }
  return false;
}
```

### Repair Flow
```dart
Future<void> repairChapter(String chapterId) async {
  // Re-download missing/corrupted pages
  final manifest = await _loadManifest(chapterId);
  final missingPages = await _findMissingPages(manifest);
  
  await _downloadPages(missingPages);
  await _updateManifest(chapterId, isComplete: true);
}
```

---

## 🌐 Localization Integration

### New Strings Added
```dart
// app_en.arb additions
"downloadToDevice": "Download to Device",
"downloadToServer": "Download to Server", 
"downloadQueued": "Queued",
"downloadInProgress": "Downloading...",
"downloadFailed": "Failed",
"repairChapter": "Repair Chapter",
"pauseDownloads": "Pause",
"resumeDownloads": "Resume"
```

### Usage in UI
```dart
Text(context.l10n?.downloadToDevice ?? 'Download to Device')
```

---

## 📊 Monitoring & Debugging

### Queue State Monitoring
```dart
// Watch queue in real-time
final queueState = ref.watch(downloadQueueProvider);
queueState.when(
  data: (queue) => Text('Active: ${queue.activeDownloads.length}'),
  loading: () => CircularProgressIndicator(),
  error: (e, _) => Text('Queue Error: $e'),
);
```

### Debug Logging
```dart
class LocalDownloadQueue {
  static void _debugLog(String message) {
    if (kDebugMode) {
      print('[LocalDownloadQueue] $message');
    }
  }
}
```

### Performance Metrics
- Download speed (MB/s)
- Queue processing time
- Memory usage during downloads
- File system operation latency

---

## 🧪 Testing Strategy

### Unit Tests
- Repository CRUD operations
- Queue state management
- Manifest serialization/deserialization
- Error condition handling

### Integration Tests
- Full download → offline read flow
- Queue processing under load
- Network interruption scenarios
- Storage path fallback logic

### UI Tests
- Download button states
- Progress indicator accuracy
- Error message display
- Accessibility compliance

---

## 🚀 Future Enhancements

### Planned Features
- [ ] Background download support
- [ ] Download scheduling (WiFi-only, specific times)
- [ ] Compression options for storage efficiency
- [ ] Cloud backup integration
- [ ] Advanced retry strategies

### Performance Improvements
- [ ] Image format optimization (WebP conversion)
- [ ] Incremental page loading
- [ ] Predictive downloading
- [ ] Delta updates for chapters

---

This architecture provides a robust foundation for offline manga reading while maintaining performance, reliability, and iOS compliance.
