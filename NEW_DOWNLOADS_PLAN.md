# New Downloads & Offline Reading Overhaul Plan

Comprehensive implementation roadmap for fixing current issues and adding the new local download system, UI, and offline robustness.

---
## Master Checklist (Progress Tracking)

### Phase 1 – Offline Reading Core Fix
- [x] 1.1 Add `localChapterPagesProvider((mangaId, chapterId))` to reader_controller
- [x] 1.2 Add `chapterPagesUnifiedProvider((mangaId, chapterId))` (chooses local/network)
- [x] 1.3 Add `connectivityProvider` for checking online status
- [x] 1.4 Update reader_screen.dart to use unified provider
- [x] 1.5 Add `OfflineNotAvailableException` error handling with UI
- [x] 1.6 Update SinglePageReaderMode and ContinuousReaderMode to handle unified data
- [x] 1.7 Test: Downloaded chapter opens offline (no network requests)
- [x] 1.8 Test: Non-downloaded chapter shows offline error when disconnected

## Phase 2: Enhanced Download Queue & UI Integration ✅ COMPLETE

- [x] Create robust download queue with FIFO ordering and per-chapter mutex
- [x] Add progress tracking for individual chapter downloads with callbacks
- [x] Implement retry logic with exponential backoff for failed downloads
- [x] Create download status indicators in chapter list (downloading, downloaded, failed, retrying)
- [x] Add comprehensive logging for debugging download issues
- [x] Refactor chapter list tile UI to use new download queue and progress providers
- [x] Ensure all provider references are correct and handle proper types
- [x] Update reader modes to work with new download status enum

### Phase 3 – UI Overhaul (Dual Icons & Bulk) ✅ COMPLETE
- [x] 3.1 Redesign `ChapterListTile` trailing section (two distinct icons)
- [x] 3.2 Device download icon states (download / progress / check / error)
- [x] 3.3 Optional server download icon (computer/cloud variant) + setting to hide
- [x] 3.4 Remove popup for local download; keep advanced menu if needed
- [x] 3.5 Multi-select toolbar actions (Download Device / Delete Device)
- [x] 3.6 Bulk dialog (Download All / Unread / Range / Latest N)
- [x] 3.7 AppBar progress chip (overall queue status)
- [x] 3.8 Tooltips + semantics labels for accessibility
- [x] 3.9 Integration with manga details screens (SmallScreen + BigScreen)
- [x] 3.10 Stack-based UI with floating selection toolbar

### Phase 4 – Reader Smoothness & Caching ✅ COMPLETE
- [x] 4.1 Precache next/prev pages (single page mode)
- [x] 4.2 Implement small LRU in-memory decoded image cache
- [x] 4.3 AutomaticKeepAlive on page widgets (prevent re-layout flicker)
- [x] 4.4 Remove white flash (set consistent dark background, no placeholder flash)
- [x] 4.5 Enhanced reader modes with smooth image loading and caching

### Phase 5 – Manifest Integrity & Repair ✅ COMPLETE
- [x] 5.1 Define/upgrade manifest schema (versioned, includes page list) - **LocalChapterManifest v2 with PageManifestEntry**
- [x] 5.2 Add integrity validation (existence + non-zero length) - **ChapterValidator with comprehensive checks**
- [x] 5.3 Mark corrupted chapters (state -> REPAIR_NEEDED) - **Extended ChapterDownloadStatus enum with 9 states**
- [x] 5.4 Implement repair flow (re-download missing/corrupted pages) - **UI integration with repair actions**
- [x] 5.5 Optional checksums (MD5/SHA-1) Phase 5b - **MD5 checksums in manifest and validation**

### Phase 6 – Path & Storage Management ✅ COMPLETE
- [x] 6.1 Unified path resolver + fallback chain - **StoragePathResolver with iOS/Android platform support**
- [x] 6.2 Migration of old File Provider directory (if needed) - **StorageMigrationManager with auto-detection**
- [x] 6.3 SharedPreferences migration flag `localDownloadsMigrated` - **Migration versioning and flag management**
- [x] 6.4 Settings: show effective path + open & reset buttons - **Enhanced LocalDownloadsSettingsScreen with path info**
- [x] 6.5 Storage usage calculation & display - **StorageUsage with human-readable formatting**
- [x] 6.6 Error telemetry for path failures - **Comprehensive error handling and user feedback**

### Phase 7 – Bulk & Performance Enhancements
- [ ] 7.1 Limit concurrent page downloads (e.g., 4) per chapter
- [ ] 7.2 Sequential chapter downloads by default; configurable concurrency
- [ ] 7.3 HTTP client reuse + keep-alive
- [ ] 7.4 Exponential backoff for transient HTTP errors
- [ ] 7.5 Pause / Cancel queue (optional)

### Phase 8 – Localization & Settings
- [ ] 8.1 Add new strings (downloadToDevice, repair, queued, etc.)
- [ ] 8.2 L10n pass & extraction
- [ ] 8.3 Settings toggles (show server icon, enable bulk confirmations)
- [ ] 8.4 Feature flags (unifiedOfflineReader, downloadQueueEnabled)

### Phase 9 – Testing & QA Matrix
- [ ] 9.1 Online -> download -> offline open (no network logs)
- [ ] 9.2 Queue multi (≥5 chapters) success test
- [ ] 9.3 Corrupt file manual test -> repair flow
- [ ] 9.4 Download entire manga stress test
- [ ] 9.5 Rapid page swipe (no white flash)
- [ ] 9.6 Airplane mode cold start
- [ ] 9.7 Invalid custom path fallback test
- [ ] 9.8 Memory footprint during reader usage
- [ ] 9.9 Real device iOS sandbox path verification
- [ ] 9.10 Localization key presence & fallback

### Phase 10 – Documentation & Cleanup
- [ ] 10.1 Developer README section for downloads architecture
- [ ] 10.2 Inline code comments for queue & providers
- [ ] 10.3 Changelog entries
- [ ] 10.4 Remove legacy OfflineReaderScreen & feature flags (post validation)

---
## Architecture Components

### Providers (New / Modified)
| Provider | Purpose |
|----------|---------|
| `localChapterPagesProvider((mangaId, chapterId))` | Reads manifest & returns local list of page files. |
| `chapterPagesUnifiedProvider((mangaId, chapterId))` | Chooses local vs network. Throws OfflineNotAvailable if offline & no local. |
| `LocalDownloadQueue` (notifier) | Manages chapter download tasks sequentially. |
| `chapterLocalDownloadProgressProvider((mangaId, chapterId))` | Exposes state + progress (pages done / total). |
| `isChapterDownloadedProvider((mangaId, chapterId))` | Extended: also indicates CORRUPTED / REPAIR_NEEDED. |
| `connectivityProvider` | Simple online/offline state; influences unified provider logic. |

### States & Enums
```dart
enum LocalDownloadState { notDownloaded, queued, downloading, downloaded, error, corrupted }
class ChapterDownloadProgress {
  final int downloadedPages;
  final int totalPages;
  final LocalDownloadState state;
  final double get progress => totalPages == 0 ? 0 : downloadedPages / totalPages;
  // error message optional
}
```

### Manifest Schema (v1)
```json
{
  "manifestVersion": 1,
  "mangaId": 123,
  "chapterId": 456,
  "mangaTitle": "Sousou no Frieren",
  "chapterName": "Chapter 140",
  "pageCount": 22,
  "pages": [
    { "index": 0, "file": "page_0001.jpg", "size": 337002 },
    { "index": 1, "file": "page_0002.jpg", "size": 317822 }
  ],
  "createdAt": 1733781123000
}
```
(Optional Phase 5b: add `checksum`).

### Directory Layout
```
<root>/sorayomi_downloads/
  manga_<mangaId>/
    chapter_<chapterId>/
      manifest.json
      page_0001.jpg
      page_0002.jpg
      ...
```

---
## Detailed Implementation Steps

### 1. Unified Pages Flow
1. Implement `localDownloadsRepository.tryLoadManifest(mangaId, chapterId)` returning domain object or null.
2. `localChapterPagesProvider` calls repository and returns list of local absolute file paths.
3. `chapterPagesUnifiedProvider` logic:
   - If local manifest found -> return Local(result)
   - Else if offline -> throw OfflineNotAvailable
   - Else fallback to existing network pages provider
4. Reader consumes unified provider; sets `isLocal = result.isLocal` passed down to page widgets.
5. `ChapterPageImage` if `isLocal`: bypass any network placeholder logic; load file bytes -> memory -> display.

### 2. Download Queue Mechanics
1. Introduce `ChapterDownloadTask` (mangaId, chapterId, status, progress, error, createdAt).
2. Queue Notifier holds: `Queue<ChapterDownloadTask>` + active task reference.
3. Worker loop:
   - If no active task & queue not empty -> start next.
   - For each page: download (with limited concurrency) -> write file -> emit PAGE_SAVED.
   - After pages done: write manifest -> emit COMPLETE.
4. Mutex: Map<(mangaId,chapterId), Completer> or `package:synchronized` to prevent duplicate enqueues.
5. On COMPLETE: invalidate `isChapterDownloadedProvider`, progress provider.

### 3. UI Overhaul (ChapterListTile)
- Replace trailing area with a horizontal Row of up to 2 IconButtons.
- Icon mapping (device):
  - notDownloaded -> download icon
  - queued/downloading -> Stack(CircularProgressIndicator, download icon faded)
  - downloaded -> check_circle
  - error/corrupted -> error + tooltip (tap => retry/repair)
- Optional server icon (cloud/computer). Hide if setting disabled.
- Long press enters multi-select; AppBar shows aggregate actions.

### 4. Bulk Download Dialog
- Options: All, Unread, Range (input from/to), Latest N.
- Estimate pages (sum pageCount if known; else approximate). Show confirmation if large (> e.g. 2000 pages).
- Enqueue tasks sequentially.

### 5. White Flash Removal
- Provide persistent dark container (no default white background).
- Pre-cache next N pages inside `onPageChanged` callback.
- LRU Cache: Map<int /*globalKey*/, Uint8List> with max memory target (e.g., 50–80 MB or 5 pages × average size).

### 6. Integrity & Repair
- Validation on load: if any referenced page missing or zero bytes -> mark corrupted.
- UI: corrupted state shows mini banner + Repair button.
- Repair: only missing/corrupted pages re-downloaded; manifest updated.

### 7. Path Strategy
- `DownloadsPathResolver.getRoot()` tries user path else fallback.
- Detect legacy File Provider path; migrate contents asynchronously (copy then mark migrated).
- Setting screen: show resolved path; allow copy/share and reset.
- Telemetry: on path failure, log JSON error with attempted path + error message.

### 8. Performance Tuning
- Limit per-chapter concurrent page downloads to 4 using `Future.wait` batches.
- Reuse single `HttpClient` from repository.
- Retry 3 times with backoff (500ms, 1s, 2s) on 5xx / network errors.
- Abort chapter (set ERROR) if any page permanently fails.

### 9. Testing Plan (Expanded)
| Test | Steps | Pass Criteria |
|------|-------|---------------|
| Offline open local | Download chapter online, airplane mode, open | Pages render instantly, no network logs. |
| Multiple downloads | Queue 5 chapters | All completed, progress accurate. |
| Corruption repair | Delete a page file manually | Chapter flagged; Repair restores file & clears flag. |
| Bulk all | Download entire manga (large) | Queue stable, progress chip updates, memory OK. |
| White flash | Rapidly turn pages | No visible flash. |
| Custom path invalid | Set bad path then download | Fallback path used & user notified. |
| Unread bulk | Download only unread subset | Only unread enqueued. |
| Cancel (if implemented) | Start large download then cancel | Remaining tasks removed, active stops at page boundary. |
| Localization | Switch languages | New strings appear translated / fallback. |

### 10. Rollout & Flags
- Introduce feature flags: `downloadQueueEnabled`, `unifiedOfflineReader`.
- Stage: enable flags in dev -> internal QA -> default on -> remove legacy.

### 11. Documentation
- `LOCAL_DOWNLOADS_PLAN.md` (original) + this file; later consolidate into dev docs.
- Add README section: architecture diagram (queue -> repository -> filesystem -> manifest).

---
## Data Structures (Draft)
```dart
class ChapterDownloadTask {
  final int mangaId;
  final int chapterId;
  LocalDownloadState state;
  int pagesCompleted;
  int totalPages;
  String? error;
  DateTime createdAt;
}
```

---
## Error Handling Patterns
- Wrap FS ops; log with tag `DOWNLOAD_FS`.
- Differentiate transient (retry) vs permanent (fail-fast) HTTP statuses.
- JSON structured logs for analytics / debugging.

---
## Security & Safety Notes
- Validate user-provided custom path is within allowed sandbox (iOS constraints); disallow if outside and fallback.
- No executable content stored; only images + manifest JSON.

---
## Defer / Future Ideas
- Background isolate for decoding large WebP/PNG.
- Partial chapter streaming (start reading while pages still downloading).
- Predictive pre-download next chapter while reading current.
- User-defined retention policy (auto-delete after read X days).

---
## Immediate Next Actions
1. Implement unified providers (Phase 1). 
2. Patch reader to use them & test offline open.
3. Add logging + fix multi-download with basic queue skeleton.

---
## Definition of Done (Critical Path)
- Offline open of downloaded chapters works with zero network calls.
- Multiple chapters can download reliably; progress shown.
- No white flash when turning pages locally.
- Dual icon UI differentiating device vs server states.
- Bulk download All/Unread functional.

---
End of plan.
