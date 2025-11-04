# How to Add Modern UI Files to Xcode Project

## Problem
The modern UI files exist in `DoseTrackNew/DoseTrackNew/` but are not part of the Xcode project, causing build error:
```
Cannot find 'ThreeCardPlanningView' in scope
```

## Files That Need to Be Added

These 6 files are physically present but not in the Xcode project:
- ✅ `DesignTokens.swift` (dark palette, spacing)
- ✅ `WindowBar.swift` (compact progress bar)
- ✅ `StatusChip.swift` (status indicators)
- ✅ `ActionButtons.swift` (primary/secondary buttons)
- ✅ `NightCardViewModern.swift` (modern night card with Build 1.1.2)
- ✅ `ThreeCardPlanningView.swift` (3-card horizon selector)

## Step-by-Step Instructions

### 1. Open Xcode Project
```bash
open /Users/kevindialmb/Downloads/DoseTrack_v1.1.1c/DoseTrackNew/DoseTrackNew.xcodeproj
```

### 2. Add Files to Project

**In Xcode:**

1. **Click** on `DoseTrackNew` folder in left sidebar (Project Navigator, ⌘1)
2. **Right-click** on the `DoseTrackNew` group (the yellow folder icon)
3. Select **"Add Files to 'DoseTrackNew'..."**
4. Navigate to `/Users/kevindialmb/Downloads/DoseTrack_v1.1.1c/DoseTrackNew/DoseTrackNew/`
5. **Select these 6 files** (hold ⌘ to select multiple):
   - `ActionButtons.swift`
   - `DesignTokens.swift`
   - `NightCardViewModern.swift`
   - `StatusChip.swift`
   - `ThreeCardPlanningView.swift`
   - `WindowBar.swift`

6. **In the dialog that appears:**
   - **UNCHECK** ☐ "Copy items if needed" (files are already in place)
   - **CHECK** ☑️ "Add to targets: DoseTrackNew"
   - **CHECK** ☑️ "Create groups" (NOT "Create folder references")
   - Click **"Add"**

### 3. Verify Files Were Added

In Project Navigator, you should now see all 6 files listed under `DoseTrackNew`:
- ActionButtons.swift
- DesignTokens.swift
- NightCardViewModern.swift
- StatusChip.swift
- ThreeCardPlanningView.swift
- WindowBar.swift

### 4. Build and Run

Press **⌘R** or click the Run button (▶️)

## Expected Result

You should see:
- ✅ **Dark mode background** (#0F1117 - nearly black)
- ✅ **"Build 1.1.2"** text under "DoseTrack" title
- ✅ **Compact 10pt progress bar** at top (not big countdown ring)
- ✅ **Modern status chips** (green/blue/gray rounded capsules)
- ✅ **Modern action buttons** (blue primary, gray secondary)
- ✅ **Three-card planning view** (Last Night / Tonight / Tomorrow tabs)

## Troubleshooting

### If you still see "Cannot find ThreeCardPlanningView"
- Files weren't added to the project properly
- Check that all 6 files appear in Project Navigator
- Check that files show checkbox ☑️ in Target Membership inspector

### If you see white background
- App is using old `TodayLogView` instead of `ThreeCardPlanningView`
- Check `DoseTrackApp.swift` - should have `ThreeCardPlanningView()` not `TodayLogView()`

### If build fails with other errors
- Clean build folder: **⌘⇧K** (Cmd+Shift+K)
- Clean build: **⌘⇧K** then **⌘B**
- Restart Xcode
