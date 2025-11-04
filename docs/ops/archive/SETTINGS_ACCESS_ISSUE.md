# Settings Access Issue - DIAGNOSIS

## Problem
You cannot access settings to check/change dose amounts because the Settings screen has a configuration mismatch.

## Root Cause
`SettingsViewEnhanced.swift` is trying to use the **wrong preferences class**:

```swift
// CURRENT (BROKEN)
@Bindable var prefs = AppPreferences.shared  ❌

// SHOULD BE
@Bindable var prefs = AppPreferencesEnhanced.shared  ✅
```

## Why This Breaks
1. **AppPreferences** (old class):
   - Uses `@Observable` macro
   - Has different property names (`roundingStepG` vs `roundingIncrement`)
   - Missing methods like `calculateDoses()`
   - Missing properties like `allowLateDose`, `maxLateMinutes`

2. **AppPreferencesEnhanced** (current class):
   - Uses `@AppStorage` for automatic persistence
   - Has all the correct property names matching the UI
   - Has helper methods the UI expects
   - Properly configured with App Group for widget sync

## What You're Experiencing
When you try to open Settings:
- ❌ Settings sheet won't open, OR
- ❌ Settings opens but fields don't update, OR  
- ❌ Settings shows wrong values/crashes on property access

## Fix Required
Update `ios/SettingsViewEnhanced.swift` line 14 to use the correct preferences class:

**Before:**
```swift
@Bindable var prefs = AppPreferences.shared
```

**After:**
```swift
@Bindable var prefs = AppPreferencesEnhanced.shared
```

**Additional fixes needed:**
- Line 32: `roundingStepG` → `roundingStepG` (AppPreferencesEnhanced uses this name)
- Line 42: `calculateDoses()` → Use `planDose1G` and `planDose2G` properties directly
- Line 48: `planViolatesSafety` → Needs to be added to AppPreferencesEnhanced or removed
- Line 61: `formatMinutes()` → Needs to be a standalone function or added to AppPreferencesEnhanced
- Line 79: `requireEarlyReason` → `earlyRequireReason` (property name mismatch)
- Line 96: `allowLateDose` → Verify this exists in AppPreferencesEnhanced
- Line 99: `maxLateMinutes` → Verify this exists in AppPreferencesEnhanced

## Quick Test
After the app builds successfully, you should be able to:
1. ✅ Tap the gear icon (⚙️) in the top-right corner
2. ✅ See the Settings sheet open
3. ✅ View and modify:
   - Total night dose (3.0g - 9.0g)
   - Split ratio (50/50, 60/40, 40/60)
   - Dose 2 window times
   - Early/late dose policies

## Status
⚠️ **BLOCKED** - Settings screen cannot be tested until build succeeds.

Current build is failing due to `TodayLogView_Checklist.swift` errors (30+ errors in legacy file).

## Recommendation
1. **First**: Fix build by excluding `TodayLogView_Checklist.swift` from build targets
2. **Then**: Update `SettingsViewEnhanced.swift` to use `AppPreferencesEnhanced`
3. **Finally**: Test settings screen functionality

---

**File:** `/Users/kevindialmb/Downloads/DoseTrack_v1.1.1c/ios/SettingsViewEnhanced.swift`  
**Line:** 14  
**Priority:** HIGH - Settings are completely inaccessible with current configuration
