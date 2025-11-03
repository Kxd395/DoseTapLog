# Quick Integration Guide - Add ios/ Files to Xcode

## ⚡ Fast Track (5 Minutes)

### Step 1: Add ios/ Files
**In Xcode (now open):**

1. Look at **left sidebar** (Project Navigator)
2. **Right-click** on **"DoseTrackIOS"** (the blue folder icon near the top)
3. Select **"Add Files to 'DoseTrackIOS'..."**

### Step 2: Select All Files from ios/

In the file picker dialog:

1. Navigate to: `DoseTrack_v1.1.1c/ios/`
2. Press **⌘A** to select all .swift files
3. ✅ Check **"Copy items if needed"**
4. ✅ Select **"Create groups"** (radio button)
5. ✅ Check **"Add to targets: DoseTrackIOS"**
6. Click **"Add"**

### Step 3: Delete Old Duplicate Files

In Project Navigator, find and delete these OLD files:

```
DoseTrackIOS/
  DoseTrackIOS/
    ❌ TodayLogView.swift          (OLD - delete this)
    ❌ TodayViewModel.swift        (OLD - delete this)
    ❌ DoseLogController.swift     (OLD - delete this)
    ❌ Models.swift                (OLD - delete this)
```

**How to delete:**
- Right-click each file → **Delete**
- Choose **"Move to Trash"**

### Step 4: Build & Run

1. **Clean Build Folder**: Press **⌘⇧K**
2. **Build**: Press **⌘B**
3. **Run**: Press **⌘R**

### Step 5: Verify New Features Work

In the simulator:
- ✅ Log Dose 1
- ✅ Scroll down - you should see **red "Reset Night"** button
- ✅ If window expires, you should see **orange banner** with Reset Night option

---

## What You're Adding

All these files from `ios/` directory will be added to your Xcode project:

**Core files with fixes:**
- `TodayLogView.swift` ← Has Reset Night button
- `TodayViewModel.swift` ← Fixed Dose 1 button, late dose protocol
- `DoseLogController.swift` ← Fixed SwiftData persistence
- `Models.swift` ← Has override fields

**New features:**
- `LateDoseSheetView.swift` ← Late dose modal
- `ResetNightSheet.swift` ← Reset night modal  
- `TodayViewModel+LateDose.swift` ← Late dose logic
- `AppPreferencesEnhanced+LateDose.swift` ← Late dose settings

**Supporting files:**
- `AppGroupStore.swift`
- `Config.swift`
- `CSVExporter.swift`
- `Date+UTC.swift`
- `HealthKitManager.swift`
- `NightPlanRecommender.swift`
- `Rounding+Display.swift`
- `AppIntents+DoseLog.swift`
- And all other .swift files in `ios/`

---

## Troubleshooting

**"I don't see the Add Files option"**
- Make sure you right-clicked on the **DoseTrackIOS** folder (blue icon)
- Try right-clicking on the project name at the very top

**"Build fails with duplicate symbols"**
- You didn't delete the old files
- Delete old TodayLogView.swift, TodayViewModel.swift, etc. from DoseTrackIOS/DoseTrackIOS/

**"Reset Night button still not showing"**
- Clean build folder (⌘⇧K)
- Rebuild (⌘B)
- Make sure `ios/TodayLogView.swift` was added to the target

---

## Keyboard Shortcuts Reference

- **⌘B** = Build
- **⌘R** = Run
- **⌘⇧K** = Clean Build Folder
- **⌘A** = Select All
- **⌘1** = Show Project Navigator
