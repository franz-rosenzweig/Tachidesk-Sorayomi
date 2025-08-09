# Phase 9 Testing & QA Guide

## 🎯 Testing Matrix for Tachidesk-Sorayomi Downloads & Offline Reading

This guide covers comprehensive testing for the new downloads and offline reading system implemented in Phases 1-8.

---

## ✅ Quick Test Checklist

### Core Functionality Tests

#### 🔌 **T9.1: Online → Download → Offline Test**
**Objective**: Verify offline reading works with zero network calls
- [ ] **Step 1**: Connect to Tachidesk server, browse manga
- [ ] **Step 2**: Download 2-3 chapters to device storage
- [ ] **Step 3**: Enable airplane mode / disconnect WiFi
- [ ] **Step 4**: Open downloaded chapters in reader
- [ ] **Expected**: Pages load instantly, no network logs in debug console
- [ ] **Pass Criteria**: No HTTP requests visible, smooth page transitions

#### 📥 **T9.2: Multi-Chapter Queue Test**  
**Objective**: Test bulk download reliability
- [ ] **Step 1**: Select 5+ chapters using multi-select
- [ ] **Step 2**: Tap "Download to Device" button
- [ ] **Step 3**: Monitor download progress in queue
- [ ] **Expected**: All chapters complete successfully
- [ ] **Pass Criteria**: Progress accurate, no failed downloads

#### 🔧 **T9.3: Corruption & Repair Test**
**Objective**: Verify repair functionality
- [ ] **Step 1**: Download a chapter successfully
- [ ] **Step 2**: Manually delete 1-2 page files from storage
- [ ] **Step 3**: Open chapter in reader
- [ ] **Expected**: Chapter flagged as corrupted with repair option
- [ ] **Pass Criteria**: Repair restores missing files, chapter readable

#### 🚀 **T9.4: Bulk Manga Download Stress Test**
**Objective**: Test system stability under load
- [ ] **Step 1**: Use bulk download dialog
- [ ] **Step 2**: Select "Download All" for a large manga (50+ chapters)
- [ ] **Step 3**: Monitor queue and device performance
- [ ] **Expected**: Stable queue processing, reasonable memory usage
- [ ] **Pass Criteria**: No crashes, progress updates correctly

#### ⚡ **T9.5: Reader Performance Test**
**Objective**: Ensure smooth reading experience
- [ ] **Step 1**: Open downloaded chapter with 15+ pages
- [ ] **Step 2**: Rapidly swipe between pages (forward/backward)
- [ ] **Expected**: No white flashes, instant page loads
- [ ] **Pass Criteria**: Smooth transitions, pre-cached pages load instantly

#### ✈️ **T9.6: Airplane Mode Cold Start**
**Objective**: Test complete offline functionality
- [ ] **Step 1**: Enable airplane mode before opening app
- [ ] **Step 2**: Cold start the app (force close first)
- [ ] **Step 3**: Navigate to downloaded manga
- [ ] **Expected**: App works normally, downloaded content accessible
- [ ] **Pass Criteria**: No crashes, offline content fully functional

#### 📁 **T9.7: Storage Path Fallback Test**
**Objective**: Verify path resolution robustness
- [ ] **Step 1**: Set invalid custom downloads path in settings
- [ ] **Step 2**: Attempt to download chapter
- [ ] **Expected**: App falls back to default path, user notified
- [ ] **Pass Criteria**: Download succeeds with fallback, clear user feedback

#### 🧠 **T9.8: Memory Footprint Test**
**Objective**: Ensure efficient memory usage
- [ ] **Step 1**: Open reader with downloaded manga
- [ ] **Step 2**: Read through 20+ pages, monitor memory
- [ ] **Expected**: Memory usage remains stable
- [ ] **Pass Criteria**: No memory leaks, reasonable peak usage

#### 📱 **T9.9: iOS Sandbox Verification**
**Objective**: Verify iOS storage compliance
- [ ] **Step 1**: Download chapters on real iOS device
- [ ] **Step 2**: Check storage location using debug logs
- [ ] **Expected**: Files stored in appropriate sandbox directory
- [ ] **Pass Criteria**: Complies with iOS storage guidelines

#### 🌐 **T9.10: Localization Test**
**Objective**: Verify new strings appear correctly
- [ ] **Step 1**: Switch app language (if available translations exist)
- [ ] **Step 2**: Check download buttons, status texts
- [ ] **Expected**: New download strings appear translated or fallback to English
- [ ] **Pass Criteria**: No missing translations, proper fallbacks

---

## 🔍 Detailed Testing Procedures

### Advanced Test Scenarios

#### **Edge Case Testing**

**Partial Downloads**
- Start download, kill app mid-process
- Verify resume capability and corruption detection

**Network Interruption**
- Download during poor connectivity
- Test retry logic and exponential backoff

**Storage Full**
- Attempt download when device storage is nearly full
- Verify graceful error handling

**Server Changes**
- Download chapters, change server URL
- Verify offline content remains accessible

#### **Performance Benchmarks**

**Download Speed**
- Time single chapter download
- Compare sequential vs concurrent page downloads

**Reader Responsiveness**
- Measure page load times (local vs network)
- Test rapid page navigation under load

**Memory Efficiency**
- Monitor memory during bulk downloads
- Check for memory leaks during extended reading

#### **User Experience Testing**

**UI Responsiveness**
- Verify download progress updates in real-time
- Test multi-selection UX smoothness

**Error Handling**
- Trigger various error conditions
- Verify user-friendly error messages

**Accessibility**
- Test with screen readers
- Verify tooltip and semantic labels

---

## 🚦 Pass/Fail Criteria

### Must Pass (Critical)
- ✅ Offline reading works with zero network requests
- ✅ Multi-chapter downloads complete successfully  
- ✅ No crashes under normal usage
- ✅ Corrupted chapters are properly detected and repairable

### Should Pass (Important)
- ✅ Smooth reader performance with no white flashes
- ✅ Reasonable memory usage during downloads
- ✅ Graceful error handling for edge cases
- ✅ Proper iOS sandbox compliance

### Nice to Have (Enhancement)
- ⭐ Fast download speeds with concurrency
- ⭐ Instant app startup in offline mode
- ⭐ Perfect localization coverage

---

## 🐛 Known Issues & Workarounds

### Potential Issues to Watch For

1. **HTTP Client Connections**
   - Monitor for connection leaks
   - Verify keep-alive functionality

2. **File System Race Conditions**
   - Test concurrent manifest updates
   - Check file lock handling

3. **iOS Memory Warnings**
   - Test behavior under memory pressure
   - Verify image cache management

4. **Background Downloads**
   - Test app backgrounding during downloads
   - Verify state persistence

---

## 📊 Test Results Template

```
Test: T9.X - [Test Name]
Date: [Date]
Device: [iOS Simulator/Real Device]
iOS Version: [Version]
App Build: [Build Number]

Steps Performed:
1. [Step 1]
2. [Step 2]
3. [Step 3]

Results:
✅ PASS / ❌ FAIL

Notes:
[Any observations, performance metrics, or issues encountered]

Logs:
[Relevant debug output or screenshots]
```

---

## 🎯 Final Validation

Before considering Phases 7-9 complete, ensure:

- [ ] All T9.1-T9.10 tests pass
- [ ] No critical performance regressions
- [ ] User experience meets expectations
- [ ] Code is ready for production deployment

---

This testing matrix ensures the robustness and reliability of the new downloads and offline reading system across all supported scenarios.
