# Testing Plan for Phases 1-6 Implementation

## Overview
This document outlines comprehensive testing scenarios for the newly implemented local downloads, offline reading, storage management, and UI enhancements.

---

## 🧪 **Test Suite 1: Basic Local Downloads (Phase 1-2)**

### T1.1: Single Chapter Download & Read
**Objective**: Verify basic download and offline reading functionality
- [ ] **Setup**: Connect to a manga source, find a manga with available chapters
- [ ] **Action**: Download a single chapter using the device download icon
- [ ] **Verify**: Download progress shows in UI
- [ ] **Verify**: Download completes successfully (check mark appears)
- [ ] **Action**: Disconnect network/enable airplane mode
- [ ] **Action**: Open the downloaded chapter in reader
- [ ] **Expected**: Chapter opens instantly with all pages loading from local storage
- [ ] **Expected**: No network requests in Flutter logs
- [ ] **Expected**: Reader navigation works smoothly between pages

### T1.2: Download Queue & Progress
**Objective**: Test download queue functionality and progress tracking
- [ ] **Action**: Queue 3-5 chapters for download simultaneously
- [ ] **Verify**: Downloads process in FIFO order
- [ ] **Verify**: Progress indicators show real-time progress for active download
- [ ] **Verify**: Queued chapters show "queued" status
- [ ] **Verify**: AppBar download chip shows overall queue progress
- [ ] **Action**: Try to download an already-downloaded chapter
- [ ] **Expected**: UI shows it's already downloaded (no duplicate download)

### T1.3: Download Failure & Retry
**Objective**: Test error handling and retry mechanisms
- [ ] **Setup**: Disconnect network mid-download
- [ ] **Expected**: Download fails gracefully with error status
- [ ] **Action**: Reconnect network
- [ ] **Action**: Tap failed download icon to retry
- [ ] **Expected**: Download resumes/retries successfully
- [ ] **Verify**: Error logs are informative but not crashes

---

## 🎨 **Test Suite 2: UI & UX Enhancements (Phase 3-4)**

### T2.1: Dual Download Icons
**Objective**: Verify the new dual-icon system works correctly
- [ ] **Verify**: Two distinct icons visible in chapter list (device vs server)
- [ ] **Verify**: Device download icon states: download → progress → check
- [ ] **Verify**: Server download icon (if enabled) works independently
- [ ] **Action**: Toggle server download icon visibility in settings
- [ ] **Expected**: Server icons hide/show without affecting device downloads

### T2.2: Bulk Download Operations
**Objective**: Test bulk download functionality
- [ ] **Action**: Enter multi-select mode (long press on chapter)
- [ ] **Action**: Select multiple chapters
- [ ] **Verify**: Selection toolbar appears with "Download Device" action
- [ ] **Action**: Use "Download Device" bulk action
- [ ] **Expected**: All selected chapters queue for download
- [ ] **Action**: Open bulk download dialog
- [ ] **Test Options**: Download All, Download Unread, Download Latest N
- [ ] **Expected**: Appropriate chapters are queued based on selection

### T2.3: Enhanced Reader Experience
**Objective**: Verify smooth reader performance and caching
- [ ] **Action**: Open a multi-page chapter in single page mode
- [ ] **Test**: Rapid page swiping forward and backward
- [ ] **Expected**: No white flashes between pages
- [ ] **Expected**: Next/previous pages preload smoothly
- [ ] **Test**: Switch between single page and continuous modes
- [ ] **Expected**: Mode changes are seamless without re-downloading

### T2.4: Reader Performance & Memory
**Objective**: Test reader performance with large chapters
- [ ] **Setup**: Find a chapter with 20+ pages
- [ ] **Action**: Read through entire chapter rapidly
- [ ] **Monitor**: Memory usage in dev tools
- [ ] **Expected**: Memory usage stays reasonable (no memory leaks)
- [ ] **Expected**: Page transitions remain smooth throughout

---

## 🔧 **Test Suite 3: Integrity & Validation (Phase 5)**

### T3.1: Manifest Integrity Validation
**Objective**: Test the new integrity validation system
- [ ] **Action**: Download a chapter completely
- [ ] **Verify**: Manifest file exists with v2 schema
- [ ] **Action**: Check download status using new providers
- [ ] **Expected**: Status shows as "downloaded" with integrity check passed

### T3.2: Corruption Detection & Repair
**Objective**: Test corruption detection and repair flow
- [ ] **Setup**: Download a chapter completely
- [ ] **Action**: Manually corrupt/delete a page file from storage
- [ ] **Action**: Open the chapter or trigger validation
- [ ] **Expected**: Chapter status changes to "repair needed"
- [ ] **Action**: Tap repair action in UI
- [ ] **Expected**: Only missing/corrupted pages re-download
- [ ] **Expected**: Repair completes and chapter status returns to "downloaded"

### T3.3: Checksum Validation
**Objective**: Test MD5 checksum validation
- [ ] **Action**: Download a chapter with checksum validation enabled
- [ ] **Verify**: Manifest contains MD5 checksums for each page
- [ ] **Action**: Manually modify a page file
- [ ] **Action**: Trigger integrity validation
- [ ] **Expected**: Checksum mismatch detected and repair offered

---

## 📁 **Test Suite 4: Storage Management (Phase 6)**

### T4.1: Storage Path Resolution
**Objective**: Test the new unified storage path system
- [ ] **Action**: Navigate to Downloads Settings
- [ ] **Verify**: Current storage location shows with path details
- [ ] **Verify**: Path reliability indicator shows appropriate status
- [ ] **Action**: Check iOS Documents directory is used by default
- [ ] **Expected**: Path shows as reliable on iOS

### T4.2: Storage Usage & Analytics
**Objective**: Test storage usage calculation and display
- [ ] **Action**: Download several chapters of varying sizes
- [ ] **Action**: View storage usage in settings
- [ ] **Verify**: Total storage used shows accurate size (B/KB/MB/GB)
- [ ] **Verify**: Chapter count and file count are accurate
- [ ] **Verify**: Average chapter size calculation is reasonable

### T4.3: Custom Path & Migration
**Objective**: Test custom path setting and migration
- [ ] **Action**: Set a custom downloads directory
- [ ] **Action**: Download a chapter to custom location
- [ ] **Action**: Reset to default storage location
- [ ] **Verify**: Migration option appears if needed
- [ ] **Action**: Perform migration
- [ ] **Expected**: Downloads move to new location successfully
- [ ] **Expected**: All chapters remain accessible

### T4.4: Storage Management Actions
**Objective**: Test storage management features
- [ ] **Action**: Use "Clear All Downloads" option
- [ ] **Verify**: Confirmation dialog appears
- [ ] **Action**: Confirm deletion
- [ ] **Expected**: All local downloads are removed
- [ ] **Expected**: Storage usage resets to zero
- [ ] **Expected**: Download icons return to "download" state

---

## 🌐 **Test Suite 5: Network & Connectivity (Phase 1)**

### T5.1: Online/Offline Transitions
**Objective**: Test behavior during connectivity changes
- [ ] **Setup**: Have both downloaded and non-downloaded chapters
- [ ] **Action**: Start reading online chapter, then disable network
- [ ] **Expected**: Current chapter continues reading (cached)
- [ ] **Action**: Try to open non-downloaded chapter offline
- [ ] **Expected**: Clear offline error message with retry option
- [ ] **Action**: Re-enable network and retry
- [ ] **Expected**: Chapter loads normally

### T5.2: Unified Provider System
**Objective**: Test the new unified chapter pages provider
- [ ] **Action**: Read a downloaded chapter
- [ ] **Verify**: Pages load from local provider
- [ ] **Action**: Read a non-downloaded chapter online
- [ ] **Verify**: Pages load from network provider
- [ ] **Expected**: Same reading experience regardless of source

---

## 📱 **Test Suite 6: Platform-Specific (iOS Focus)**

### T6.1: iOS Sandboxing Compliance
**Objective**: Verify iOS-specific path handling
- [ ] **Verify**: Downloads save to app's Documents directory
- [ ] **Action**: Check file system using device tools
- [ ] **Expected**: Files are in sandboxed location
- [ ] **Expected**: No permission errors in logs

### T6.2: iOS App Lifecycle
**Objective**: Test behavior during iOS app lifecycle events
- [ ] **Action**: Start download, then background app
- [ ] **Expected**: Download continues in background (if supported)
- [ ] **Action**: Force-quit app during download
- [ ] **Action**: Restart app
- [ ] **Expected**: Download queue state is restored appropriately

---

## 📋 **Test Suite 7: Settings & Configuration**

### T7.1: Download Settings
**Objective**: Test all download-related settings
- [ ] **Action**: Toggle server download icon visibility
- [ ] **Action**: Change download directory path
- [ ] **Action**: Test various storage management options
- [ ] **Expected**: All settings persist between app restarts
- [ ] **Expected**: Settings changes take effect immediately

---

## 🔍 **Test Suite 8: Error Scenarios & Edge Cases**

### T8.1: Storage Full Scenarios
**Objective**: Test behavior when device storage is low
- [ ] **Setup**: Fill device storage to near capacity
- [ ] **Action**: Attempt to download large chapters
- [ ] **Expected**: Graceful error handling with clear messages
- [ ] **Expected**: No app crashes or data corruption

### T8.2: Concurrent Access
**Objective**: Test multiple simultaneous operations
- [ ] **Action**: Download chapters while reading others
- [ ] **Action**: Delete chapters while downloads are active
- [ ] **Expected**: No race conditions or data corruption
- [ ] **Expected**: UI remains responsive

### T8.3: Large Manga Collections
**Objective**: Test performance with many downloads
- [ ] **Setup**: Download 50+ chapters
- [ ] **Action**: Navigate chapter lists and settings
- [ ] **Expected**: UI remains responsive
- [ ] **Expected**: Storage calculations complete reasonably quickly

---

## ✅ **Success Criteria**

Each test should pass with:
- ✅ **Functionality**: Feature works as designed
- ✅ **Performance**: No significant lag or memory issues
- ✅ **Reliability**: No crashes or data corruption
- ✅ **UX**: Clear feedback and error messages
- ✅ **Platform**: iOS-specific requirements met

---

## 📊 **Testing Status**

| Test Suite | Status | Notes |
|------------|--------|-------|
| T1: Basic Downloads | 🟡 Pending | Ready to test |
| T2: UI & UX | 🟡 Pending | Ready to test |
| T3: Integrity | 🟡 Pending | Ready to test |
| T4: Storage Mgmt | 🟡 Pending | Ready to test |
| T5: Network | 🟡 Pending | Ready to test |
| T6: iOS Platform | 🟡 Pending | Ready to test |
| T7: Settings | 🟡 Pending | Ready to test |
| T8: Edge Cases | 🟡 Pending | Ready to test |

**Legend**: 🟢 Pass | 🟡 Pending | 🔴 Fail | ⚠️ Issues Found
