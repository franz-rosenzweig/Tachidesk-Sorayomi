# Local Downloads Feature - Implementation Checkli## Chapter Actions – Trigger Local Download
- [x] Update `ChapterListTile` to add a menu button with:
  - [x] "Download to device" (starts local download for that chapter)
  - [x] If already downloaded locally: "Delete local"

## Deletion
- [x] Implement `deleteLocalChapter` to remove files and manifest
- [x] Wire "Delete" action in Local Downloads tab and in chapter menu

## iOS Considerations
- [x] Use application documents directory (no extra permission)
- [ ] (Later) Consider excluding from iCloud backup for large content
- [x] Foreground-only downloads for MVP **ALL CORE ITEMS COMPLETED!** 

### 📋 COMPLETION STATUS:
- [x] **Data & Storage**: LocalDownloadsRepository with manifest system ✓
- [x] **UI Entry Points**: Downloads screen with Local/Server tabs ✓  
- [x] **Reader Integration**: ChapterPageImage with offline-first loading ✓
- [x] **Chapter Actions**: Download/delete menu in chapter lists ✓
- [x] **Deletion**: Full delete functionality implemented ✓
- [x] **iOS Considerations**: Documents directory, no permissions needed ✓

### 🚀 **READY FOR TESTING**
All requested functionality has been implemented and is ready to run!ATUS: COMPLETE** - All core functionality implemented and ready for testing.

The following features have been successfully implemented:
- True on-device storage using Documents/sorayomi_downloads folder structure
- Local Downloads tab in Downloads screen with list of saved chapters
- Chapter actions menu with "Download to device" and "Delete local" options
- Reader integration that automatically shows local images when available
- Proper error handling and state management with Riverpod providers

Goal: Add true on-device storage for chapters (iOS-friendly), a Local Downloads tab, and basic delete controls. Prefer file-based manifests for simplicity and avoid codegen.

## Data & Storage
- [x] Create repository `LocalDownloadsRepository` to manage:
  - [x] Base dir: Documents/sorayomi_downloads
  - [x] Folder structure: downloads/manga_<mangaId>/chapter_<chapterId>/
  - [x] Manifest per chapter: manifest.json (manga/chapter metadata, page paths, savedAt)
  - [x] Download pages using existing authenticated cache flow (reuse CacheManagerExtension.getServerFile, then copy files to local dir)
  - [x] Helpers: isChapterDownloaded, listDownloads (scan manifests), deleteLocalChapter, getLocalPageFile(chapterId, index)
  - [ ] Optional: download and store manga thumbnail locally
- [x] Add Riverpod providers (no codegen): repository provider, list provider, per-chapter downloaded provider

## UI – Entry Points
- [x] Extend Downloads screen with a two-tab UI:
  - [x] Tab 1: Server Queue (existing)
  - [x] Tab 2: Local Downloads (new `LocalDownloadsScreen`)
- [x] Implement `LocalDownloadsScreen` list:
  - [x] Show manga title, chapter name, saved date, optional thumbnail
  - [x] Actions: Open (navigates to reader), Delete local

## Reader Integration (Offline Display)
- [x] Add a `ChapterPageImage` widget that:
  - [x] Tries to resolve a local file via repository (chapterId + page index)
  - [x] Falls back to `ServerImage` with the remote URL
- [x] Replace page image calls in:
  - [x] `single_page_reader_mode.dart`
  - [x] `continuous_reader_mode.dart`

## Chapter Actions – Trigger Local Download
- [ ] Update `ChapterListTile` to add a menu button with:
  - [ ] “Download to device” (starts local download for that chapter)
  - [ ] If already downloaded locally: “Delete local”

## Deletion
- [ ] Implement `deleteLocalChapter` to remove files and manifest
- [ ] Wire “Delete” action in Local Downloads tab and in chapter menu

## iOS Considerations
- [ ] Use application documents directory (no extra permission)
- [ ] (Later) Consider excluding from iCloud backup for large content
- [ ] Foreground-only downloads for MVP

## Nice-to-haves (deferred)
- [ ] Auto-delete after X days setting with periodic cleanup
- [ ] Progress UI for local downloads
- [ ] Background/queued local downloads with isolates
- [ ] Settings page for local storage location/limits

---
This file is a working checklist; we’ll update items as we implement.
