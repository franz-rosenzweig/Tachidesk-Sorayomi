# 🧪 Beta Testing Guide: Tachidesk-Sorayomi Phases 1-6

**Testing Version**: Phases 1-6 Complete  
**Date**: August 9, 2025  
**Platform**: iOS Simulator (iPhone 16 Plus)

---

## 🎯 **What's New & Ready to Test**

You now have access to a completely overhauled local downloads and offline reading system with 6 major improvements:

### ✨ **Key Features to Test**

1. **📱 New Download UI** - Dual icons for device vs server downloads
2. **⚡ Enhanced Download Queue** - Better progress tracking and retry logic  
3. **📖 Improved Offline Reading** - Seamless local/network switching
4. **🔄 Bulk Download Operations** - Multi-select and batch downloads
5. **🔍 Integrity Validation** - Corruption detection and repair
6. **💾 Storage Management** - iOS-optimized storage with migration

---

## 🚀 **Beta Testing Roadmap**

### **Phase 1: Basic Setup & Navigation**

#### 1.1 Initial App Launch
- [ ] **Launch App**: Open Tachidesk-Sorayomi on simulator
- [ ] **First Time Setup**: Configure server connection if needed
- [ ] **Navigation Check**: Ensure all main screens load properly
- [ ] **Performance Check**: App startup should be smooth and responsive

#### 1.2 Storage Settings Exploration  
- [ ] **Navigate to Settings** → **Downloads**
- [ ] **Check Storage Location**: Should show iOS Documents directory
- [ ] **View Storage Usage**: Initially should show 0 B used
- [ ] **Explore Options**: Storage path info, usage calculator, reset options

**Expected Behavior**: Clean, informative storage management interface

---

### **Phase 2: Download System Testing**

#### 2.1 Single Chapter Download
- [ ] **Find a Manga**: Browse sources and select a manga
- [ ] **Open Chapter List**: Look for the new dual-icon system
- [ ] **Device Download**: Tap the device download icon (should be a download arrow)
- [ ] **Watch Progress**: Progress indicator should show real-time download progress
- [ ] **Completion Check**: Icon should change to checkmark when complete

**Look For**: 
- Two distinct icons per chapter (device vs server)
- Smooth progress animation
- Clear status indicators

#### 2.2 Download Queue Testing
- [ ] **Queue Multiple Chapters**: Select 3-5 chapters for download
- [ ] **Monitor Queue**: Check AppBar for download progress chip
- [ ] **FIFO Verification**: Downloads should process in order
- [ ] **Progress Tracking**: Each chapter should show individual progress

**Expected Behavior**: 
- Downloads process sequentially
- Overall progress visible in app bar
- Individual chapter progress clear

#### 2.3 Bulk Download Operations
- [ ] **Long Press Chapter**: Enter multi-select mode
- [ ] **Select Multiple**: Choose several chapters
- [ ] **Bulk Download**: Use "Download Device" action from toolbar
- [ ] **Bulk Dialog Test**: Try "Download All" / "Download Unread" options

**Look For**:
- Intuitive selection interface
- Clear bulk action options
- Proper batch processing

---

### **Phase 3: Offline Reading Experience**

#### 3.1 Basic Offline Reading
- [ ] **Download Complete Chapter**: Ensure a chapter is fully downloaded
- [ ] **Enable Airplane Mode**: Disconnect from internet
- [ ] **Open Downloaded Chapter**: Tap to read the offline chapter
- [ ] **Navigate Pages**: Swipe through all pages smoothly
- [ ] **Check Performance**: No network requests, smooth transitions

**Expected Behavior**:
- Instant loading from local storage
- Smooth page transitions
- No white flashes or loading delays

#### 3.2 Enhanced Reader Features
- [ ] **Single Page Mode**: Test page-by-page navigation
- [ ] **Continuous Mode**: Test scroll-through reading
- [ ] **Mode Switching**: Switch between reading modes seamlessly
- [ ] **Precaching Test**: Pages should preload ahead/behind current page

**Look For**:
- Smooth mode transitions
- No re-loading when switching modes
- Fast page turns with precaching

#### 3.3 Online/Offline Transitions
- [ ] **Mixed Content Test**: Have both downloaded and non-downloaded chapters
- [ ] **Online → Offline**: Disable network while reading
- [ ] **Offline Error Handling**: Try to open non-downloaded chapter offline
- [ ] **Error Recovery**: Re-enable network and retry

**Expected Behavior**:
- Graceful offline error messages
- Clear distinction between available/unavailable content
- Smooth recovery when connection restored

---

### **Phase 4: Advanced Features Testing**

#### 4.1 Integrity & Validation System
- [ ] **Download Status Check**: Use download status indicators
- [ ] **Corruption Simulation**: (Advanced) Manually corrupt a file if possible
- [ ] **Repair Function**: Test repair functionality if corruption detected
- [ ] **Validation Feedback**: Check for integrity validation messages

**Note**: Corruption testing is advanced - focus on normal integrity indicators

#### 4.2 Storage Management
- [ ] **Storage Usage Monitoring**: Download several chapters, check usage updates
- [ ] **Path Information**: Verify iOS Documents directory usage
- [ ] **Reset Testing**: Try "Reset to Default" storage option
- [ ] **Clear All Downloads**: Test bulk deletion functionality

**Expected Behavior**:
- Accurate storage usage calculation
- Proper iOS path handling
- Safe deletion with confirmations

---

### **Phase 5: Performance & Edge Cases**

#### 5.1 Performance Testing
- [ ] **Large Chapter Test**: Download and read a chapter with 20+ pages
- [ ] **Multiple Downloads**: Queue 10+ chapters simultaneously
- [ ] **Memory Monitoring**: Watch for any memory issues or crashes
- [ ] **Rapid Navigation**: Quickly swipe through pages and chapters

#### 5.2 Error Scenarios
- [ ] **Network Interruption**: Disconnect during download
- [ ] **Retry Functionality**: Test download retry after failure
- [ ] **Storage Full**: (If possible) Test behavior with limited storage
- [ ] **Concurrent Operations**: Download while reading other chapters

#### 5.3 UI/UX Verification
- [ ] **Icon States**: Verify all download icon states (download → progress → complete → error)
- [ ] **Selection UI**: Test multi-select interface responsiveness
- [ ] **Settings Integration**: Ensure all settings work and persist
- [ ] **Accessibility**: Check that UI elements are clear and accessible

---

## 🔍 **What to Look For**

### ✅ **Positive Indicators**
- **Smooth Performance**: No lag, crashes, or freezing
- **Clear UI**: Icons and status indicators are intuitive
- **Reliable Downloads**: Downloads complete successfully and files are accessible
- **Seamless Offline**: Downloaded content works perfectly without internet
- **Storage Transparency**: Clear information about storage usage and location

### ⚠️ **Issues to Report**
- **Crashes or Freezes**: Any app instability
- **UI Confusion**: Unclear icons or confusing workflows
- **Download Failures**: Incomplete or failed downloads
- **Performance Issues**: Slow loading, memory problems, or lag
- **Storage Problems**: Incorrect paths or missing files

### 🐛 **Common Things to Test**
- **Download Progress**: Does it show accurate progress?
- **Icon Consistency**: Do download icons match their actual status?
- **Offline Reliability**: Do downloaded chapters work 100% offline?
- **Storage Accuracy**: Is storage usage calculation correct?
- **Error Handling**: Are error messages helpful and clear?

---

## 📱 **Beta Testing Workflow**

### **Step 1**: Basic Functionality (15 minutes)
- Launch app and navigate to Downloads settings
- Download 2-3 chapters and verify completion
- Test offline reading of downloaded content

### **Step 2**: Advanced Features (15 minutes)  
- Test bulk download operations
- Verify storage management features
- Test download queue with multiple chapters

### **Step 3**: Edge Cases (10 minutes)
- Test network interruption scenarios
- Verify error handling and recovery
- Test performance with larger downloads

### **Step 4**: User Experience (10 minutes)
- Evaluate overall UI/UX improvements
- Test accessibility and intuitiveness
- Verify all features work as expected

---

## 📊 **Testing Checklist**

| Feature | Status | Notes |
|---------|--------|-------|
| App Launch | ⬜ | |
| Storage Settings | ⬜ | |
| Single Download | ⬜ | |
| Download Queue | ⬜ | |
| Bulk Downloads | ⬜ | |
| Offline Reading | ⬜ | |
| Reader Modes | ⬜ | |
| Storage Management | ⬜ | |
| Error Handling | ⬜ | |
| Performance | ⬜ | |

**Legend**: ✅ Pass | ⚠️ Issues | ❌ Fail | ⬜ Not Tested

---

## 🎯 **Success Criteria**

Your beta test is successful if:
- ✅ App launches and runs smoothly
- ✅ Downloads work reliably with clear progress
- ✅ Offline reading is seamless and fast
- ✅ Storage management is clear and functional
- ✅ UI improvements are intuitive and helpful
- ✅ No major crashes or data loss

---

## 📝 **Feedback Collection**

As you test, please note:
1. **What works well** - Features that feel smooth and intuitive
2. **What needs improvement** - Confusing UI, performance issues, or bugs
3. **Missing features** - Anything you expected but don't see
4. **User experience** - Overall feel and usability compared to before

**Enjoy testing the new download system!** 🚀
