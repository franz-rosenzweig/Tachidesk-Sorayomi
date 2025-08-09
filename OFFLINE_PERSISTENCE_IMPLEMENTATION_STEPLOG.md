# Offline Persistence Implementation Step Log

This file tracks concrete implementation steps derived from the triage plan to fix: (1) missing downloaded chapters in offline catalog, (2) incorrect / volatile storage path (Caches) ignoring user choice, and (3) preparation for user-accessible + future iCloud storage.

## Legend
- [ ] Pending
- [x] Done
- [~] In progress
- (!) Follow-up / decision required

## Phase 0: Diagnostics & Logging
- [x] Add verbose logging wrapper (`logOffline`) with level + component.
- [x] Log at start of each download: chosen root path, writable test result.
- [x] Log each page file write (first + failures, aggregate count).
- [x] Log manifest write success / failure path.
- [x] Log catalog upsert invocation + result.
- [x] Provide temporary Dev Overlay widget showing effective storage path.

## Phase 1: Stable Persistent Storage Path
- [x] Add Info.plist keys: UIFileSharingEnabled, LSSupportsOpeningDocumentsInPlace. (done)
- [ ] Introduce `StorageLocationType` & `StorageLocation` model. (not needed yet for baseline; may simplify later)
- [x] New resolver: prefer custom path then Application Support, then Documents, never Caches (implemented in `StoragePathResolver`).
- [x] Implement writable test (.write_test / write+read delete) before accepting path.
- [x] Add fallback warning when custom path invalid → revert to sandbox (snackbar implemented in settings screen).

## Phase 2: Download Pipeline Integrity
- [x] Extract `_downloadChapter` core pipeline with explicit order: mkdir → page writes → manifest → catalog upsert (sequence enforced in refactored code).
- [x] Fail fast on mkdir / writable issue (probe + `DownloadWriteException`).
- [x] Ensure `await` for catalog upsert.
- [x] Guard: only write manifest after all pages succeed; partial -> cleanup dir.
- [x] Add error type: `DownloadWriteException` (path, reason).

## Phase 3: Catalog Rebuild & Repair
- [x] Implement `rebuildFromFilesystem(root)` scanning manga_*/chapter_*/manifest.json (existing repository method).
- [x] Bootstrap: auto rebuild if catalog empty & manifests present (added logic).
- [x] Settings action: “Rebuild Offline Catalog” (button + snackbar wired in Downloads settings).

## Phase 4: Offline Decision Hardening
- [x] Verify `chapterPagesDecisionProvider` never instantiates network provider when offline mode true (guard logs added).
- [x] Add guard logging when offline path selected (confirmation log added).
- [x] Add explicit `OfflineNotAvailableException` -> friendly UI message (handled in reader_screen error state).

## Phase 5: Custom Folder & iCloud (Deferred until baseline stable)
- [x] Implement security-scoped bookmark storage (iOS) for custom folder selection (Swift MethodChannel + picker scaffold).
- [x] Add persistence of bookmark (SharedPreferences key) (base64 storage implemented).
- [ ] Acquire & release security scope at app start & termination (currently only during resolution; add lifecycle hooks).
 - [~] Acquire & release security scope at app start & termination (startup re-resolution implemented; release on termination pending).
 - [~] Acquire & release security scope at app start & termination (startup re-resolution + termination hook added; still need explicit stopAccessing on retained URLs if stored).
- [ ] (!) iCloud entitlements prep (requires manual project / Apple Dev Portal updates) — separate PR.

## Phase 6: UX Enhancements
- [x] Show storage location + free space in Local Downloads screen header.
- [x] Add ‘Validate Downloads’ quick action (lightweight integrity check).

## Metrics & Telemetry (Optional Later)
- [x] Log avg page write ms, catalog save ms (timing instrumentation added in repository metrics logs).
 - [ ] Persist integrity validation results (lastValidated update & badge accuracy) and repair metrics.
 - [~] Persist integrity validation results (lastValidated now saved; badge still simplistic; metrics logging partial). Repair action prototype added (full chapter re-download).
 - [~] Integrity badges now reflect status (ok/partial/corrupt) after validation (cache ephemeral; consider persistent status storage).
 - [x] Incremental single-page repair implemented; integrityStatus + missingPageCount persisted in manifest; badges update after repair.
 - [x] Catalog write mutex to avoid rebuild/download race.
 - [x] Fallback snackbar on failed external path resolution at startup.
 - [x] Repair disabled when chapter integrity ok.
 - [x] Temporary storage migration prompt added in settings.

---
## Immediate Next Commits (Batch 1)
This PR will include:
1. Info.plist keys addition.
2. StorageLocation models + resolver scaffold (no bookmark yet, just sandbox).
3. Logging helper + integration in LocalDownloadsRepository (basic root + chapter start + manifest + catalog upsert events).
4. Minimal rebuildFromFilesystem skeleton (not yet wired to UI).

After verifying downloads actually persist & appear, we’ll proceed with UI action + security-scoped bookmarks.

## Developer Notes
- Using Application Support avoids iOS purging & is okay for Files access once `UIFileSharingEnabled` is true. If you want the directory to show explicitly, Application Documents might be simpler—but support dir is semantically correct for managed app data.
- Security-scoped bookmarks require platform channel or a plugin (e.g. file_picker returns a path but not the bookmark). We may implement a small MethodChannel later.

---
Last Updated: 2025-08-09T01:05Z
