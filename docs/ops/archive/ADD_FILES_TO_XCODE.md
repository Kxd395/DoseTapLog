# Add New Files to Xcode Project

## Files to Add (7 total)

### Dose 2 Override System (from earlier)
- ✅ `ios/TodayViewModel+Dose2Override.swift` (367 lines)
- ✅ `ios/EarlyDoseSheetView.swift` (already in project)
- ✅ `ios/LateDoseSheetView.swift` (already in project)

### Wake Event Tracking (from earlier)
- ✅ `ios/TodayViewModel+WakeEvents.swift` (210 lines)
- ✅ `ios/WakeReason.swift` (95 lines)
- ✅ `ios/WakeSheetView.swift` (142 lines)

### Alarm Ladder System (just created)
- ✅ `ios/WindowState.swift` (220 lines)
- ✅ `ios/NightAlarmPlan.swift` (175 lines)
- ✅ `ios/AlarmOrchestrator.swift` (400 lines)

## Steps to Add Files

### 1. Open Xcode Project
```bash
open DoseTrackNew/DoseTrackNew.xcodeproj
```

### 2. In Xcode
1. Click on **Project Navigator** (folder icon, or press `⌘1`)
2. Right-click on **"DoseTrackNew"** folder (blue icon at top)
3. Select **"Add Files to DoseTrackNew..."**

### 3. Navigate to Files
1. Press `⌘⇧G` (Go to Folder)
2. Type: `/Users/kevindialmb/Downloads/DoseTrack_v1.1.1c/ios`
3. Press Enter

### 4. Select All Files
Hold `⌘` and click each file:
- `TodayViewModel+Dose2Override.swift`
- `TodayViewModel+WakeEvents.swift`
- `WakeReason.swift`
- `WakeSheetView.swift`
- `WindowState.swift`
- `NightAlarmPlan.swift`
- `AlarmOrchestrator.swift`

### 5. Configure Import Options
**IMPORTANT**:
- ☑️ **UNCHECK** "Copy items if needed" (files are already in correct location)
- ☑️ **CHECK** "DoseTrackNew" under "Add to targets"
- ☑️ "Create groups" should be selected (default)

### 6. Click "Add"

### 7. Verify Files Added
In Project Navigator, you should see all 7 files listed under DoseTrackNew folder with the blue DoseTrackNew icon.

### 8. Build to Verify
Press `⌘B` to build. Fix any compilation errors.

## Expected Compilation Issues (and fixes)

### Issue 1: Missing imports
If you see "Cannot find type 'X' in scope":
- Add `import Foundation` at top of file
- Add `import SwiftUI` if using SwiftUI types
- Add `import UserNotifications` for AlarmOrchestrator

### Issue 2: AppPreferences.DNDPolicy not found
AlarmOrchestrator references `AppPreferences.DNDPolicy` - this should already be defined in AppPreferences.swift.

### Issue 3: Circular dependencies
If ViewModel extensions reference each other, you may need to reorganize imports.

## After Adding Files

### Build Project
```
⌘B (Build)
```

### Run Tests
```
⌘U (Test)
```

### Run on Simulator
```
⌘R (Run)
```

## Verification Checklist

After adding files and building successfully:

- [ ] All 7 files appear in Project Navigator
- [ ] Build succeeds (⌘B) with no errors
- [ ] Dose 2 override system:
  - [ ] Early dose sheet appears when tapping early
  - [ ] Late dose sheet appears when tapping late
  - [ ] Banner shows two-tap message
  - [ ] Override logged to database
  
- [ ] Wake event tracking:
  - [ ] Wake sheet appears after tapping wake event
  - [ ] 11 wake reasons available in picker
  - [ ] Wake event logged to database
  
- [ ] Alarm ladder:
  - [ ] Settings shows Alarm Ladder section
  - [ ] Can select alarm style (quiet/normal/strong)
  - [ ] Consent toggles appear for strong/time-sensitive

## Troubleshooting

### Files don't appear in navigator
- Make sure you selected "DoseTrackNew" target
- Try closing and reopening Xcode

### Build errors about duplicate symbols
- One of the files may already be in the project
- Check if there are duplicate file references

### Runtime errors
- Make sure database migration 005 exists
- Check AppPreferences has all new alarm ladder properties
- Verify SettingsViewEnhanced imports NightAlarmPlan

## Files Already in Project (no need to add)

These files were created earlier and should already be in Xcode:
- `AppPreferences.swift` (updated with alarm ladder settings)
- `SettingsViewEnhanced.swift` (updated with alarm ladder section)
- `TodayLogView.swift` (updated with banner and sheets)
- `EarlyDoseSheetView.swift`
- `LateDoseSheetView.swift`
- `DoseLogController.swift` (has override support)
- `Models.swift` (has CSV export with override columns)

## Quick Add Script (Alternative)

If you prefer command line (Xcode must be closed):

```bash
cd /Users/kevindialmb/Downloads/DoseTrack_v1.1.1c

# Create symbolic links in DoseTrackNew folder
ln -sf ../../ios/TodayViewModel+Dose2Override.swift DoseTrackNew/DoseTrackNew/
ln -sf ../../ios/TodayViewModel+WakeEvents.swift DoseTrackNew/DoseTrackNew/
ln -sf ../../ios/WakeReason.swift DoseTrackNew/DoseTrackNew/
ln -sf ../../ios/WakeSheetView.swift DoseTrackNew/DoseTrackNew/
ln -sf ../../ios/WindowState.swift DoseTrackNew/DoseTrackNew/
ln -sf ../../ios/NightAlarmPlan.swift DoseTrackNew/DoseTrackNew/
ln -sf ../../ios/AlarmOrchestrator.swift DoseTrackNew/DoseTrackNew/

# Open Xcode - it should detect new files
open DoseTrackNew/DoseTrackNew.xcodeproj
```

⚠️ **Note**: This creates symlinks but Xcode still needs to be told to include them in the target.

## Status

**Current**: Files exist in `ios/` folder but NOT yet added to Xcode project  
**Next**: Follow steps above to add files to Xcode  
**After**: Build (⌘B) and test all features
