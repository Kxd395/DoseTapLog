# DoseTrack - Integrate ios/ Directory into Xcode

## Current Situation

- ❌ **Building:** `DoseTrackIOS/DoseTrackIOS/*.swift` (old legacy code)
- ✅ **Available:** `ios/*.swift` (new code with all fixes)

## Goal

Add the `ios/` directory files to the Xcode project so they compile instead of the old files.

---

## Manual Integration Steps (RECOMMENDED)

### Step 1: Open Xcode Project

```bash
open DoseTrackIOS/DoseTrackIOS.xcodeproj
```

### Step 2: Add ios/ Files to Project

1. In Xcode's **Project Navigator** (left sidebar), right-click on **DoseTrackIOS** (the blue folder icon at the top)

2. Select **"Add Files to 'DoseTrackIOS'..."**

3. In the file picker:
   - Navigate to the `ios/` folder
   - Select **ALL .swift files** (⌘A to select all)
   - Make sure these options are checked:
     - ✅ **"Copy items if needed"**
     - ✅ **"Create groups"** (not "Create folder references")
     - ✅ **"Add to targets: DoseTrackIOS"**

4. Click **"Add"**

### Step 3: Remove or Archive Old Files

You have two options:

#### Option A: Delete Old Files (Clean Approach)

1. In Project Navigator, find these old files in `DoseTrackIOS/DoseTrackIOS/`:
   - `TodayLogView.swift`
   - `TodayViewModel.swift`
   - `DoseLogController.swift`
   - `Models.swift`
   - (Any other files that duplicate what's in `ios/`)

2. Right-click each file → **Delete**

3. Choose **"Move to Trash"** (permanently deletes)

#### Option B: Remove References (Keeps Files for Reference)

1. Right-click each old file → **Delete**
2. Choose **"Remove Reference"** (keeps file on disk but removes from project)

### Step 4: Verify File Structure

After adding files, your Project Navigator should show:

```
DoseTrackIOS/
  ├── AppGroupStore.swift
  ├── TodayLogView.swift          ← FROM ios/ (NEW - has Reset Night button)
  ├── TodayViewModel.swift        ← FROM ios/ (NEW - has late dose logic)
  ├── DoseLogController.swift     ← FROM ios/ (NEW - has SwiftData persistence fix)
  ├── Models.swift                ← FROM ios/ (NEW - has override fields)
  ├── LateDoseSheetView.swift     ← FROM ios/ (NEW)
  ├── ResetNightSheet.swift       ← FROM ios/ (NEW)
  ├── AppPreferencesEnhanced.swift
  ├── TodayViewModel+LateDose.swift ← FROM ios/ (NEW)
  ├── AppPreferencesEnhanced+LateDose.swift ← FROM ios/ (NEW)
  └── ... (other files)
```

### Step 5: Build the Project

1. Press **⌘B** to build

2. If you get errors:
   - Check that all files are added to the target
   - Make sure old duplicate files are removed
   - Verify import statements

3. Expected result: **Build Succeeds** ✅

### Step 6: Run on Simulator

1. Press **⌘R** to run

2. Expected new features:
   - ✅ Orange "Window Expired" banner (when window closes without Dose 2)
   - ✅ Reset Night button (red, at bottom of Primary Actions)
   - ✅ Late Dose Override (orange button when window expired)

---

## Quick Verification Checklist

After integration, verify these features work:

### Test 1: Clean Start State
- [ ] App shows "Tap Dose 1 to start the window"
- [ ] "In bed now" button works
- [ ] "Dose 1 now" button works

### Test 2: Reset Night Feature
- [ ] After logging Dose 1, scroll down
- [ ] Red "Reset Night" button visible at bottom
- [ ] Tapping it shows modal with Soft/Hard reset options

### Test 3: Late Dose Override (if window expired)
- [ ] Log Dose 1
- [ ] Advance simulator time past window end (or wait 240 minutes)
- [ ] Orange banner appears: "Window Expired"
- [ ] Orange "Reset Night" button in banner
- [ ] OR: Orange "Log Dose 2 (late)" button appears
- [ ] Tapping shows modal with reason picker

---

## Files Being Added (from ios/ directory)

New files with all fixes:
- ✅ `TodayLogView.swift` (199 lines) - Has Reset Night button, orange banner
- ✅ `TodayViewModel.swift` (206 lines) - Fixed protocol, late dose support
- ✅ `DoseLogController.swift` (545 lines) - Fixed SwiftData persistence
- ✅ `Models.swift` (97 lines) - Has override fields, CSV export
- ✅ `LateDoseSheetView.swift` (247 lines) - Late dose modal
- ✅ `ResetNightSheet.swift` (135 lines) - Reset night modal
- ✅ `TodayViewModel+LateDose.swift` (156 lines) - Late dose logic
- ✅ `AppPreferencesEnhanced+LateDose.swift` (76 lines) - Late dose settings

Supporting files:
- `AppGroupStore.swift`
- `AppIntents+DoseLog.swift`
- `Config.swift`
- `CSVExporter.swift`
- `Date+UTC.swift`
- `HealthKitManager.swift`
- `NightPlanRecommender.swift`
- `Rounding+Display.swift`
- All other files in `ios/`

---

## Troubleshooting

### "Duplicate symbol" errors
- You have both old and new files in the project
- Remove old files from `DoseTrackIOS/DoseTrackIOS/`

### "Cannot find type in scope" errors
- Missing files not added to project
- Add all files from `ios/` directory

### Reset Night button not appearing
- Still running old code
- Verify `ios/TodayLogView.swift` is in the project
- Clean build folder (⌘⇧K) and rebuild

---

## Command to Open Xcode

```bash
cd /Users/kevindialmb/Downloads/DoseTrack_v1.1.1c
open DoseTrackIOS/DoseTrackIOS.xcodeproj
```

---

**Next Step:** Follow Step 1 above to open the Xcode project, then proceed with the manual integration.
