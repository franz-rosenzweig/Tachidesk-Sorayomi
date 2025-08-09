# Offline Persistence & Local Downloads Reliability Plan

Comprehensive blueprint to make locally downloaded manga fully usable when the server is unreachable (airplane mode, different network, server down) and eliminate TimeoutException / "No stream event" failures.

---
## 0. Executive Summary
Current offline flow is still logically coupled to online providers (chapter metadata + pages). When connectivity is lost, delayed / timed‑out network futures block the reader even though image files + manifests exist. We will decouple by introducing an **Offline Catalog** (manga + chapter index), strictly local providers, and early decision logic that never waits for network when offline.

**Core Outcome (Phase P1):** Opening a previously downloaded chapter offline is instant (<150 ms to first page) with zero network attempts.

---
## 1. Problem Analysis
| Issue | Description | Impact | Solution Anchor Section |
|-------|-------------|--------|-------------------------|
| A1: Unified provider still triggers network path | "chapterPagesUnified" awaits network before short‑circuit sometimes | Timeout offline | §8, §9 |
| A2: No offline catalog | Only per-chapter manifests; no global index for UI | Cannot list manga/chapters offline | §5, §6 |
| A3: Metadata dependency | Title / chapter info pulled live from server | Reader / lists break offline | §3, §5 |
| A4: Connectivity decision timing | Decision happens after starting async chain | Delay & timeouts | §8, §9 |
| A5: Settings not fully persisted | Reader prefs, last positions not available offline | User experience degraded | §14 |
| A6: No cover caching contract | Covers may require network | Blank UI offline | §11 |
| A7: Repair / corruption path ad‑hoc | Missing manifest / pages not gracefully rebuilt | Orphaned downloads | §17 |
| A8: Hard-coded path remnants (fixed) | Simulator path previously present | Wrong storage on device | Already removed |
| A9: Network fallback not bounded | No small timeout when local already exists | UI stall | §13 |
| A10: Race catalog writes | Future catalog introduces corruption risk | Data loss potential | §19, §21 |

---
## 2. Offline Capability Goals
- **P1 (Critical):** Instant offline chapter reading, offline catalog browsing, preserved read progress.
- **P2:** Basic metadata (title, chapter name, ordering, cover) available offline.
- **P3:** Reconnection sync (diff & enrich) without breaking offline assets.

---
## 3. Data to Persist Offline
| Level | Fields | Rationale |
|-------|--------|-----------|
| Manga | mangaId, title, optional cover path, sourceId, lastUpdated | List + display |
| Chapter | chapterId, mangaId, name, number, pageCount, downloadedAt, readPage | Chapter list + resume |
| Manifest (per chapter) | version, pageFiles, optional pages metadata (size, checksum, originalUrl) | Page resolution + validation |
| Global Settings Snapshot | reader mode, last read (mangaId, chapterId, page), theme toggles | Continuity |
| Integrity Markers | lastValidated, corruption flags | Repair logic |

---
## 4. Storage Layout Extension
```
sorayomi_downloads/
  catalog/
    offline_catalog.json        # or offline.db (future SQLite)
    covers/
      manga_<mangaId>.jpg
  manga_<mangaId>/
    chapter_<chapterId>/
      manifest.json
      page_0001.jpg
      ...
```

---
## 5. Offline Catalog (JSON v1 Schema)
```json
{
  "schema": 1,
  "manga": [
    {
      "mangaId": 729,
      "sourceId": "source_slug_or_id",
      "title": "A Silent Voice",
      "cover": "catalog/covers/manga_729.jpg",
      "lastUpdated": 1734738123000,
      "chapters": [
        {
          "chapterId": 17515,
          "name": "Chapter 62",
          "number": 62,
          "pageCount": 18,
          "downloadedAt": 1734737400000,
          "readPage": 5
        }
      ]
    }
  ]
}
```
**Migration Path:** Move to SQLite when catalog > 2–5K chapters or JSON write latency > 50 ms.

---
## 6. Layered Architecture (Decoupling)
| Layer | Online | Offline |
|-------|--------|---------|
| Bootstrap | Ping server + hydrate remote providers | Load offline catalog + mark mode=offline |
| Manga List | GraphQL/REST | OfflineCatalogRepository.listManga() |
| Chapter List | Network chapters provider | OfflineCatalogRepository.listChapters(mangaId) |
| Reader Entry | chapterPagesProvider (network) | LocalManifestRepository.load() |
| Page Image | CachedNetworkImage | File.readAsBytes / memory decode |

---
## 7. New / Refactored Components
1. **OfflineCatalogRepository** (JSON + debounced atomic writes)
2. **LocalManifestRepository** (extract from current LocalDownloadsRepository; single responsibility)
3. **OfflineBootstrapService** (early mode decision)
4. **ReadProgressService** (persist page position)
5. **CoverCacheService** (download once, reuse offline)
6. **RepairService / Validator** (already partial; extend to rebuild catalog)

---
## 8. Provider Refactor Strategy
Current unified provider may still trigger network. New separation:
- `localChapterManifestProvider(mangaId, chapterId)` — filesystem only.
- `networkChapterPagesProvider(chapterId)` — network only.
- `chapterPagesDecisionProvider(mangaId, chapterId)` — synchronous decision, minimal awaits.

Decision Flow:
```
if (offlineMode) {
  if (localManifest != null) return Local;
  else throw OfflineNotAvailable;
}
if (localManifest != null && userPrefersLocalFirst) return Local;
return Network;
```

Guarantee: **No network Future awaited** when offlineMode true.

---
## 9. Reader Screen Adjustments
| Change | Purpose |
|--------|---------|
| Early offline snapshot before building async Future | Avoid starting network flows |
| Skeleton while manifest loads (fs latency) | Fast perceived response |
| Local-first decode using Image.memory with validation | Removes network dependencies |
| Reconnect banner (when network returns) | Offer metadata refresh |

---
## 10. Download Completion Pipeline Enhancements
Steps after chapter download success:
1. Save `manifest.json`.
2. Upsert manga + chapter in offline catalog (debounced write).
3. Cache cover if not present.
4. Persist `downloadedAt`.
5. Initialize `readPage = 0`.
6. (Optional) Pre-validate and store checksum metadata.

---
## 11. Cover & Metadata Caching
| Step | Detail |
|------|--------|
| Acquire | At first chapter download for manga |
| Store | `catalog/covers/manga_<id>.jpg` |
| Fallback | Placeholder if missing offline |
| Refresh | Optional on reconnect if hash changed |

---
## 12. Handling Incomplete Metadata
If some fields missing at download time:
- Store minimal: `mangaId`, `title` (empty fallback), `chapterId`, `chapterName`.
- Mark entry `metadataIncomplete: true` (future enrichment on reconnect).

---
## 13. Timeout & Network Stall Elimination
| Risk | Mitigation |
|------|------------|
| Hidden network call delaying local load | Early branch before instantiating network provider |
| Slow fallback when local exists | Wrap network attempt with short timeout (2s) only if local absent |
| Image widget still uses network path | Supply direct file bytes when offline |

---
## 14. Settings & Persistence Decoupling
Persist using SharedPreferences / Hive:
- Reader mode (vertical / horizontal)
- Scale / fit mode
- Last opened (mangaId, chapterId, page)
- Offline mode flag (computed + last known server reachable)
- User preference: local-first when both available

---
## 15. Offline Cold Start Sequence
1. Start app.
2. Parallel:
   - Load offline catalog (fast deserialize)
   - Attempt server ping (1s timeout, non-blocking)
3. If ping fails → set `appMode=offline` and route library to OfflineDownloads.
4. If ping succeeds → standard hybrid mode (show offline badge on downloaded items).

---
## 16. Reconnection Sync
| Step | Action |
|------|--------|
| 1 | Detect network restored (connectivity stream) |
| 2 | For each manga in catalog: enqueue metadata refresh (throttle) |
| 3 | Update titles / new chapters (mark new ones as notDownloaded) |
| 4 | Remove nothing automatically (user controls retention) |
| 5 | Refresh UI providers | 

Later enhancement: diff algorithm with ETag / updatedAt.

---
## 17. Failure & Integrity Strategies
| Scenario | Handling |
|----------|----------|
| Corrupt catalog JSON | Rebuild by scanning `manga_*/chapter_*/manifest.json` |
| Manifest missing, pages present | Reconstruct minimal manifest from files; mark `needsRepair` |
| Missing page during read | Show repair badge; skip page gracefully |
| Partial download (no manifest) | Skip listing; optional cleanup job |
| Orphan cover (no manga entry) | Remove during periodic maintenance |

Provide **"Rebuild Offline Catalog"** action in settings for manual recovery.

---
## 18. Implementation Order (Incremental)
| Order | Task | Phase |
|-------|------|-------|
| 1 | Implement OfflineCatalog models & repository (JSON) | P1 |
| 2 | Hook catalog upserts into download completion | P1 |
| 3 | Add offline bootstrap + `appMode` provider | P1 |
| 4 | Refactor chapter providers (decision split) | P1 |
| 5 | Adjust reader screen offline-first | P1 |
| 6 | Persist read progress on page change | P1 |
| 7 | Cover caching on first download | P2 |
| 8 | Rebuild / repair utilities | P2 |
| 9 | Reconnection sync pass (basic) | P2 |
| 10 | Integrity validation integration with catalog | P2 |
| 11 | Short network timeouts & local-first toggle | P2 |
| 12 | Performance tuning (batch fs + decode) | P3 |
| 13 | Optional migration to SQLite (threshold) | P3 |

---
## 19. Pseudocode Highlights
**Decision Provider:**
```dart
Future<ChapterPagesResult> decidePages(int mangaId, int chapterId) async {
  final offline = offlineModeProvider.read(); // snapshot (sync accessor)
  final local = await localManifestRepo.load(mangaId, chapterId);
  if (offline) {
    if (local != null) return ChapterPagesResult.local(local.pageFiles);
    throw OfflineNotAvailableException();
  }
  if (local != null && userPrefs.localFirst) return ChapterPagesResult.local(local.pageFiles);
  final network = await networkChapterRepo.fetchPages(chapterId);
  return ChapterPagesResult.remote(network.urls);
}
```
**Catalog Upsert After Download:**
```dart
Future<void> onDownloadComplete(Manifest m, MangaMeta meta) async {
  final catalog = await catalogRepo.load();
  catalog.upsertManga(meta.basic());
  catalog.upsertChapter(m.mangaId, ChapterEntry(
    chapterId: m.chapterId,
    name: m.chapterName,
    number: m.chapterNumber,
    pageCount: m.pageCount,
    downloadedAt: DateTime.now().millisecondsSinceEpoch,
    readPage: 0,
  ));
  await catalogRepo.saveDebounced(catalog);
}
```
**Bootstrap:**
```dart
Future<void> bootstrap() async {
  final catalogFuture = catalogRepo.safeLoad();
  final pingFuture = connectivity.tryPing(timeout: Duration(seconds:1));
  final catalog = await catalogFuture; offlineCatalogState.set(catalog);
  final reachable = await pingFuture.catchError((_) => false);
  connectivityState.set(reachable);
}
```

---
## 20. Testing Matrix
| Test | Steps | Expectation |
|------|-------|-------------|
| T1 Offline Cold Start | Kill app, airplane mode, launch | Offline list loads, no network errors |
| T2 Open Downloaded Chapter Offline | Tap downloaded chapter | First page <150 ms, no timeout |
| T3 Missing Manifest | Delete manifest.json, reopen | Reconstructed entry or flagged repair, no crash |
| T4 Corrupt Catalog | Corrupt JSON, relaunch | Auto rebuild from manifests |
| T5 Read Progress | Read to page 8, close, reopen offline | Resumes page 8 |
| T6 Reconnect Sync | Go online after offline | New chapters appear (not downloaded) |
| T7 Local-First Online | Have local + network, enable local-first | Uses local immediately |
| T8 Cover Caching | Disconnect after cache | Cover still shows |
| T9 Partial File Loss | Delete one page file | Page skipped + repair indicator |
| T10 Performance | Swipe quickly offline | No stutter / network log |

---
## 21. Risk Mitigation
| Risk | Mitigation |
|------|------------|
| Concurrent catalog writes | Mutex + debounced write (e.g., 500 ms) + atomic temp rename |
| Large catalog JSON | Auto-migrate to SQLite above threshold |
| Corruption mid-write | Write to `offline_catalog.tmp` then rename |
| Memory spike decoding many pages | Keep existing decode reuse + LRU in image cache |
| User deletes files externally | Validation pass marks corrupted; repair path |
| Race between download finishing & reader open | Reader always checks manifest existence after write; use `await` completion before upsert |

---
## 22. Minimal Viable Offline (Fast Path)
Deliver these first:
1. OfflineCatalogRepository (JSON) + bootstrap load
2. Upsert on download complete
3. Provider refactor (decision provider offline-first)
4. Reader offline path (no network futures)
5. OfflineDownloadsScreen using catalog

Then iterate with cover caching, progress, sync.

---
## 23. Metadata Strategy Recommendation
Adopt **Offline Catalog (JSON)** now; design interfaces for a future SQLite backend. Provide adapter pattern so switch is non-breaking.

---
## 24. Immediate Action Checklist (Actionable TODO)
- [ ] Create models: `OfflineCatalog`, `MangaEntry`, `ChapterEntry`
- [ ] Implement `offline_catalog_repository.dart` (load, save, upsert, rebuildFromManifests)
- [ ] Add debounced save utility (Timer or stream-based)
- [ ] Integrate upsert into download completion pipeline
- [ ] Expose `offlineCatalogProvider` (StateNotifier / AsyncValue cache)
- [ ] Add `appModeProvider` (offline/online enum)
- [ ] Implement `offlineBootstrap()` in app startup (e.g. main.dart before runApp)
- [ ] Refactor providers: split local vs network vs decision
- [ ] Update reader: early offline decision & local-first code path
- [ ] Add read progress persistence (page change listener)
- [ ] Build OfflineDownloadsScreen fed only by catalog
- [ ] Implement cover caching step & fallback placeholder
- [ ] Add repair/rebuild settings action
- [ ] Add short network timeout wrapper for network chapter fetches when local absent
- [ ] Add local-first user preference toggle
- [ ] Add reconnect sync stub (logs + manual refresh trigger)
- [ ] Add integrity validation integration (mark corrupted chapters in catalog)
- [ ] Write developer doc (this file) + update README offline section
- [ ] QA: Execute Testing Matrix items T1–T10
- [ ] Measure cold offline open latency; optimize if >150 ms

---
## 25. Success Criteria (Definition of Done)
- Opening a downloaded chapter offline never triggers network requests (verified via logs).
- Library offline shows only catalog entries, no errors.
- Reconnecting enriches metadata without breaking offline chapters.
- Corrupt catalog or manifest automatically recoverable.
- Latency to show first offline page ≤150 ms median.

---
## 26. Future Enhancements (Deferred)
| Idea | Benefit |
|------|--------|
| SQLite migration | Scale & query performance |
| Predictive pre-download next chapter | Seamless binge reading |
| Background image decoding isolate | Reduce UI jank on low-end devices |
| Differential sync protocol | Faster reconciliation |
| Encrypted storage option | Privacy for downloaded chapters |

---
## 27. Glossary
| Term | Meaning |
|------|---------|
| Manifest | Per-chapter JSON describing page files & optional metadata |
| Offline Catalog | Aggregated JSON index of all downloaded manga/chapters |
| Local-First | User preference to prefer local content even when online |
| Repair | Flow to rebuild corrupted or missing chapter assets |

---
## 28. Tracking & Telemetry (Optional)
Lightweight event logging (debug only): `OFFLINE_BOOTSTRAP`, `CATALOG_SAVE(ms)`, `READER_OFFLINE_OPEN(latency_ms)`, `REPAIR_TRIGGERED`.

---
## 29. Implementation Notes
- Keep functions small & pure; side-effects centralized in repositories.
- Wrap all filesystem ops with error handling returning domain-level failures.
- Use `compute()` or isolate only after baseline performance measured.

---
## 30. Final Notes
This plan focuses on **removing network coupling as the root cause** of offline failures. Implement the minimal path first, then layer resilience and enrichment. Each additional feature (sync, cover caching) is strictly additive.

> Ready to proceed with scaffolding repositories and providers.
