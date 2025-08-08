# Testing Guide for Bug Fixes & Local Downloads Settings

## What I've Fixed

### 1. 🐛 **"Invalid Image Data" Bug Debugging**
- Added comprehensive error handling and debug logging for local image loading
- Images will now fallback gracefully to server versions if local files have issues
- Debug output will help identify the root cause of image loading problems

### 2. ⚙️ **Local Downloads Directory Setting**
- Added a complete settings system for choosing where to store downloaded manga
- New "Local Downloads Settings" section in Downloads settings
- Directory picker UI for easy folder selection
- Option to reset to default location

## How to Test

### Testing the Settings Feature:
1. **Navigate to Settings**: Open the app and go to Settings → Downloads
2. **Find Local Downloads**: Look for "Local Downloads Settings" at the top of the screen
3. **Set Custom Directory**: Tap on "Local Downloads Settings" → "Local Downloads Directory" 
4. **Pick Folder**: Tap the folder icon to select where you want downloads saved
5. **Test Downloads**: Download a new chapter and verify it's saved to your chosen location

### Testing the Debug Output:
1. **Download a Chapter**: Use the local downloads feature to download a manga chapter
2. **Read Downloaded Chapter**: Try to read the downloaded chapter (the one with the "Invalid image data" error)
3. **Check Debug Output**: 
   - In Xcode, open the debug console (View → Debug Area → Debug Console)
   - Look for messages like:
     - "Found local file: [path]" 
     - "Error loading local image [path]: [error]"
     - "Successfully saved page X to [path]"
     - "No manifest found for manga X, chapter Y"

## Expected Outcomes

### ✅ **Settings Should Work**:
- You can navigate to the new Local Downloads Settings screen
- Directory picker opens when you tap the folder icon
- Selected directory is saved and displayed
- Future downloads use your chosen directory

### 🔍 **Debugging Should Provide Info**:
- Debug messages in the console will show exactly what's happening with local files
- If images fail to load, you'll see the specific error message
- The app will gracefully fall back to server images instead of showing "Invalid image data"

### 🚨 **If You Still See Issues**:
- Check the debug console output and share any error messages
- Try downloading to different directories to see if it's a permissions issue
- Test with different manga to see if it's content-specific

The debug output will help us identify exactly why the downloaded CBZ images aren't loading properly, and the settings feature gives you full control over where your downloads are stored on your device.
