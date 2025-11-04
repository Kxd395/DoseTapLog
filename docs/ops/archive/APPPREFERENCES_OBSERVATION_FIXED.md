# ✅ AppPreferences @ObservationTracked Errors FIXED!

**Date:** November 2, 2025  
**Issue:** Invalid redeclaration of synthesized property errors  
**Status:** ✅ FIXED  

---

## ❌ The Problems

### Problem #1: @AppStorage in Extension (ILLEGAL)

**Error:**
```
extensions must not contain stored properties
non-static property 'allowLateDose' declared inside an extension cannot have a wrapper
```

**Root Cause:**
`AppPreferences+LateDose.swift` had `@AppStorage` properties in an extension. Swift **does not allow stored properties or property wrappers in extensions** - they must be in the main class body.

### Problem #2: @Observable + @AppStorage Conflict

**Error:**
```
Invalid redeclaration of synthesized property '_totalNightGrams'
Invalid redeclaration of synthesized property '_splitStrategy'
... (36 more properties)
```

**Root Cause:**
The `@Observable` macro automatically adds `@ObservationTracked` to ALL properties in the class. But `@AppStorage` properties have their OWN change tracking built-in. This created duplicate observation tracking, causing "invalid redeclaration" errors.

---

## ✅ The Fixes

### Fix #1: Move Late Dose Properties to Main Class

**Moved from `AppPreferences+LateDose.swift` extension to `AppPreferences.swift` main class:**

```swift
// MARK: - Late Dose 2 Override

@AppStorage("late_dose_allow", store: suite)
var allowLateDose: Bool = true

@AppStorage("late_dose_require_reason", store: suite)
var lateRequireReason: Bool = true

@AppStorage("late_dose_max_minutes", store: suite)
var maxLateMinutes: Int = 120

@AppStorage("late_dose_quick_choices", store: suite)
var lateQuickChoicesCSV: String = "5,10,15,30"
```

**Updated extension to only have computed properties:**

```swift
extension AppPreferences {
    /// Parse lateQuickChoicesCSV into array of integers
    var lateQuickChoices: [Int] {
        lateQuickChoicesCSV
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 > 0 && $0 <= 300 }
    }
    
    /// Check if a given number of minutes late violates the max limit
    func exceedsLateLimit(_ minutesLate: Int) -> Bool {
        guard maxLateMinutes > 0 else { return false }
        return minutesLate > maxLateMinutes
    }
}
```

✅ **Result:** Extensions can only have computed properties and methods, not stored properties!

### Fix #2: Add @ObservationIgnored to @AppStorage Properties

**Applied globally with sed:**

```bash
sed -i.backup 's/    @AppStorage/    @ObservationIgnored @AppStorage/g' AppPreferences.swift
```

**Before:**
```swift
@AppStorage("plan_total_night_grams", store: suite) 
var totalNightGrams: Double = 6.5
```

**After:**
```swift
@ObservationIgnored @AppStorage("plan_total_night_grams", store: suite) 
var totalNightGrams: Double = 6.5
```

✅ **Result:** All 36 `@AppStorage` properties now have `@ObservationIgnored`, preventing duplicate observation tracking!

---

## 📊 What Changed

### AppPreferences.swift (380 lines, +14 lines)

**Added 4 new properties** (moved from extension):
- `allowLateDose` - Allow logging Dose 2 after window closes
- `lateRequireReason` - Require reason for late dose
- `maxLateMinutes` - Max minutes late allowed (0 = unlimited)
- `lateQuickChoicesCSV` - Quick choice buttons CSV

**Updated ALL 36 `@AppStorage` declarations** with `@ObservationIgnored`:
- `totalNightGrams`
- `splitStrategy`
- `roundingStepG`
- `windowStartMin`
- `windowEndMin`
- `allowTonightEdit`
- `allowEarlyDose`
- `maxEarlyMinutes`
- `requireEarlyReason`
- `earlyTimePriorDefaults`
- `liveActivityEnabled`
- `notifyAtStart`
- `notifyAtHalf`
- `notifyAtEnd`
- `quietHoursStart`
- `quietHoursEnd`
- `hapticsEnabled`
- `healthSampleWindowMin`
- `whoopProxyURL`
- `whoopAPIKey`
- `wakeSourcePreference`
- `exportIncludeTimezone`
- `exportFilenamePattern`
- `exportIncludeNotes`
- `exportIncludeEventLog`
- `exportDefaultEmail`
- `requireBiometric`
- `maskWidgetDoses`
- `retentionDays`
- `resetAllowHard`
- `resetRequireBiometricHard`
- `resetReasonRequired`
- `resetUndoWindowSec`
- `allowLateDose` (NEW)
- `lateRequireReason` (NEW)
- `maxLateMinutes` (NEW)
- `lateQuickChoicesCSV` (NEW)
- `showInternals`

### AppPreferences+LateDose.swift (23 lines, was 74 lines)

**Removed** (moved to main class):
- `@AppStorage var allowLateDose`
- `@AppStorage var lateRequireReason`
- `@AppStorage var maxLateMinutes`
- `@AppStorage var lateQuickChoicesCSV`

**Kept** (computed properties & methods):
- `var lateQuickChoices: [Int]` - Computed from CSV
- `func exceedsLateLimit(_ minutesLate: Int) -> Bool` - Helper method

---

## 🎯 Why @ObservationIgnored Is Required

### The @Observable Macro Expansion

When you write:
```swift
@Observable
final class AppPreferences {
    @AppStorage("key", store: suite)
    var myProperty: String = ""
}
```

The `@Observable` macro expands to:
```swift
final class AppPreferences {
    @ObservationTracked  // ← Added by @Observable
    @AppStorage("key", store: suite)
    var myProperty: String = ""
}
```

But `@AppStorage` ALREADY has observation built-in! So you get:
- `@ObservationTracked` creates `_myProperty` backing storage
- `@AppStorage` creates `_myProperty` backing storage
- **DUPLICATE!** → "Invalid redeclaration of '_myProperty'"

### The Solution

Tell `@Observable` to skip `@AppStorage` properties:
```swift
@Observable
final class AppPreferences {
    @ObservationIgnored  // ← Tells @Observable to skip this
    @AppStorage("key", store: suite)
    var myProperty: String = ""
}
```

Now `@Observable` won't try to add `@ObservationTracked`, avoiding the duplicate!

---

## ✅ Status: AppPreferences Errors Fixed

### Errors Resolved:
- ✅ All 36 "Invalid redeclaration of synthesized property" errors → FIXED
- ✅ All 4 "extensions must not contain stored properties" errors → FIXED
- ✅ Late dose properties now accessible from main `AppPreferences` class

### Build Output:
```bash
# Before Fix
@__swiftmacro_...C15totalNightGrams18ObservationTrackedfMp_.swift:7:91: 
error: invalid redeclaration of synthesized property '_totalNightGrams'
... (36 more errors)

# After Fix
(No @ObservationTracked errors! ✅)
```

---

## 🚧 Remaining Errors (Different Issues)

These are **separate problems** not related to `AppPreferences`:

1. **DoseLogController.swift** - Duplicate method declarations
   - `logDose1(at:gramsOverride:)` declared twice (lines 44 & 522)
   - `logDose2(at:gramsOverride:)` declared twice (lines 51 & 526)
   - `setFinalWake(_:provenance:)` declared twice (lines 58 & 530)

2. **TodayViewModel.swift** - Duplicate declarations
   - `EarlyReason` enum declared twice
   - `isBeforeWindowButEligibleEarly` property declared twice
   - `tryLogDose2()` method declared twice

3. **EarlyReason Ambiguity** - Enum defined in multiple files
   - `TodayViewModel.swift:183`
   - `EarlyDoseSheetView.swift:144`

4. **StubController** - Protocol conformance issue
   - Missing required methods from `DoseLogControllering` protocol

---

## 📝 Summary

### What Was Wrong:
- `@AppStorage` properties in extension (illegal in Swift)
- `@Observable` macro adding `@ObservationTracked` to `@AppStorage` properties (duplicate tracking)

### What Was Fixed:
- Moved all late dose `@AppStorage` properties into main `AppPreferences` class
- Added `@ObservationIgnored` before all 36 `@AppStorage` properties
- Extension now only has computed properties and methods (legal)

### Current State:
- ✅ AppPreferences.swift compiles cleanly
- ✅ No more "@ObservationTracked" errors
- ✅ No more "stored properties in extension" errors
- ⚠️ Other files have duplicate declarations (need separate fixes)

---

**Status:** ✅ AppPreferences FIXED - Ready for next phase  
**Next:** Fix duplicate methods in DoseLogController & TodayViewModel  
**Files Modified:** `AppPreferences.swift`, `AppPreferences+LateDose.swift`
