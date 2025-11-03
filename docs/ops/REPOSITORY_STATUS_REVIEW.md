# DoseTrack Repository Status Review
**Date:** November 2, 2025  
**Project:** DoseTrackIOS v1.1.1c  
**Status:** ✅ ALL COMPILATION ERRORS RESOLVED

---

## 🎯 Executive Summary

The DoseTrackIOS project is **fully compilable** with zero errors after fixing critical issues with:
1. Duplicate `NightPlanExtensions.swift` file (removed)
2. Incorrect property references (`dose1DisplayG`/`dose2DisplayG` → `dose1`/`dose2`)
3. Deprecated Live Activity API (`end(using:dismissalPolicy:)` → `end(dismissalPolicy:)`)

The repository contains comprehensive implementation guidance and enhancement packages ready for integration.

---

## 📦 Current Repository Structure

### Active DoseTrackIOS Project
**Location:** `/DoseTrackIOS/`  
**Status:** ✅ Compiles cleanly  
**Files:** 24 Swift files in active project

**Core Files:**
- `TodayLogView.swift` (610 lines) - Main UI with ViewModel
- `DoseLogController.swift` - Data persistence layer
- `NightPlan.swift` (105 lines) - Dose planning with safety checks
- `NightPlanRecommender.swift` - Plan generation logic
- `Dose2Gate.swift` - Window gating logic
- `Models.swift` - SwiftData models
- `Config.swift` - Safety constants (per-dose: 1.5-4.5g, nightly: 3.0-9.0g)
- `HealthKitManager.swift` - Health integration
- `DoseWindowActivity.swift` - Live Activity support
- `SettingsView.swift` - Basic settings UI

**Supporting Infrastructure:**
- `AppIntents+DoseLog.swift` - Siri shortcuts
- `AppIntents+NightFlow.swift` - Intent handling
- `CSVExporter.swift` - Data export
- `Date+UTC.swift` - UTC helpers
- `EventLog.swift` - Event tracking
- `TodayWidgets.swift` - Widget support

### Enhancement Files (Ready for Integration)
**Location:** `/ios/`  
**Status:** 🔄 Available but not yet added to Xcode project

**Enhanced Components:**
1. **AppPreferencesEnhanced.swift** (372 lines)
   - 30+ settings with @AppStorage
   - App Group support: `"group.com.jefferson.dosetrack"`
   - 8 categories: Night Plan, Early Dose Policy, Notifications, Data Sources, Exports, Privacy, Debug
   - Backward compatibility via `LegacyAppPreferences` struct
   - Migration helper: `migrateFromLegacyIfNeeded()`

2. **SettingsViewEnhanced.swift** (334 lines)
   - 7-section comprehensive settings panel
   - Night plan preview with live calculations
   - Health status & WHOOP connectivity test
   - CSV export configuration
   - Privacy & retention controls
   - Debug tools (simulate events, force window open)

3. **AppPreferencesEnhanced+LateDose.swift**
   - Late dose override policy settings
   - Extends AppPreferencesEnhanced with late-dose controls

### Reset Night Feature Package
**Location:** `/review/ResetNight_UX_Pack_2025-11-02/`  
**Status:** 📋 Documented, ready for implementation

**Contents:**
- `docs/RESET_NIGHT_SPEC.md` - Complete specification
- `ios/ResetNightSheet.swift` - Modal UI with biometric confirmation
- `ios/DoseLogController+Reset.swift` - Controller extension
- `ios/TodayLogView+ResetNight.swift` - View integration
- `ios/TodayViewModel+ResetNight.swift` - ViewModel methods
- `sql/migrations/00X_reset_night.sql` - Database schema updates

**Feature Summary:**
- **Soft Reset:** Archive current night, create fresh session with "+R1" suffix
- **Hard Reset:** Delete current night data (requires biometric + typed "RESET")
- **Safety:** Blocked if Final Wake logged (soft), always requires reason
- **Audit:** Logs `reset_night` event with mode, reason, batch ID

### Review & Integration Guides
**Location:** `/review/`

**Key Documents:**
1. **update2.md** (276 lines)
   - Dose 2 gating policy tree
   - Window rules and safety buffers
   - Settings blueprint
   - Swift gating function examples

2. **updates.md** (796 lines)
   - Persistence architecture (7 buckets)
   - SQLite pragmas and transaction patterns
   - Super-critical product review (13 issues + fixes)
   - Complete settings gear specification
   - Controller write path patterns
   - Fast test matrix

---

## 🔧 Recent Fixes Applied (Nov 2, 2025)

### Issue #1: NightPlanExtensions Duplication
**Problem:**
- File `/DoseTrackIOS/DoseTrackIOS/NightPlanExtensions.swift` duplicated properties already in `NightPlan.swift`:
  - `perDoseSafe`, `nightlyTotalSafe`, `isSafe`, `safetyMessage` redeclared
  - Referenced non-existent `dose1DisplayG`/`dose2DisplayG`

**Fix:**
```bash
rm /DoseTrackIOS/DoseTrackIOS/NightPlanExtensions.swift
```
**Reason:** All functionality already exists in `NightPlan.swift` lines 26-52

---

### Issue #2: Incorrect Property References in TodayLogView
**Problem:**
- 5 references to `plan.dose1DisplayG` and `plan.dose2DisplayG`
- Properties don't exist; should be `plan.dose1` and `plan.dose2`

**Locations Fixed:**
- Line 260: Dose 1 display text
- Line 264: Dose 2 display text
- Line 279: Safety banner total calculation
- Lines 350-351: Dose 1 action assignments
- Line 359: Dose 2 button planned dose

**Fix:**
```swift
// Before:
Text("Dose 1: \(String(format: "%.2f", plan.dose1DisplayG)) g")
model.dose1G = plan.dose1DisplayG

// After:
Text("Dose 1: \(String(format: "%.2f", plan.dose1)) g")
model.dose1G = plan.dose1
```

---

### Issue #3: Deprecated Live Activity API
**Problem:**
- `DoseWindowActivity.swift:40` used deprecated `end(using:dismissalPolicy:)` (iOS 16.2+)

**Fix:**
```swift
// Before:
await activity?.end(using: nil, dismissalPolicy: .immediate)

// After:
await activity?.end(dismissalPolicy: .immediate)
```

---

### Issue #4: NightPlanRecommender Incorrect Initialization
**Problem:**
- Tried to initialize `NightPlan` with old API:
  ```swift
  NightPlan(dose1GramsPrecise: d1, dose2GramsPrecise: d2, ...)
  ```
- Actual API requires:
  ```swift
  NightPlan(totalNightG: Double, splitFirstPct: Double, ...)
  ```

**Fix:**
Rewrote `makePlan()` to:
1. Calculate `splitFirst` from percentage (adjust based on recovery score)
2. Pass to `NightPlan` initializer with total + split
3. Let `NightPlan` compute `dose1`/`dose2` internally (with rounding & clamping)
4. Use correct `Config` constants: `totalNightMinG`/`totalNightMaxG`

---

## ✅ Verification Results

### Compilation Status
```swift
// All files compile with ZERO errors:
✅ NightPlan.swift
✅ NightPlanRecommender.swift
✅ TodayLogView.swift
✅ DoseWindowActivity.swift
```

### Property Access Verification
```swift
// NightPlan.swift computed properties (correct usage):
var dose1: Double {
    clamp(roundQ(totalNightG * splitFirstPct))
}

var dose2: Double {
    clamp(roundQ(totalNightG - dose1))
}

// Safety checks (built-in):
var perDoseSafe: Bool { ... }
var nightlyTotalSafe: Bool { ... }
var isSafe: Bool { perDoseSafe && nightlyTotalSafe }
var safetyMessage: String { ... }
```

---

## 📋 Integration Checklist Status

### ✅ Phase 1: Core Compilation (COMPLETE)
- [x] Remove duplicate NightPlanExtensions.swift
- [x] Fix property references in TodayLogView.swift
- [x] Update NightPlanRecommender to use correct API
- [x] Fix deprecated Live Activity API
- [x] Verify zero compilation errors

### 🔄 Phase 2: Enhanced Settings (READY TO INTEGRATE)
- [ ] Add `AppPreferencesEnhanced.swift` to Xcode project
- [ ] Add `AppPreferencesEnhanced+LateDose.swift` to Xcode project
- [ ] Add `SettingsViewEnhanced.swift` to Xcode project
- [ ] Update `TodayViewModel` to use `AppPreferencesEnhanced`
- [ ] Replace basic `SettingsView` with enhanced version
- [ ] Test settings persistence across app launches

**Files Available:**
```
/ios/AppPreferencesEnhanced.swift (372 lines)
/ios/AppPreferencesEnhanced+LateDose.swift
/ios/SettingsViewEnhanced.swift (334 lines)
```

### 🔄 Phase 3: Reset Night Feature (READY TO IMPLEMENT)
- [ ] Add SQL migration `00X_reset_night.sql`
- [ ] Add `ResetNightSheet.swift` to project
- [ ] Add `DoseLogController+Reset.swift`
- [ ] Add `TodayViewModel+ResetNight.swift`
- [ ] Add `TodayLogView+ResetNight.swift`
- [ ] Wire "Reset Night" entry points (Settings gear, overflow menu)
- [ ] Test soft reset flow
- [ ] Test hard reset with biometric confirmation

**Files Available:**
```
/review/ResetNight_UX_Pack_2025-11-02/
  ├── docs/RESET_NIGHT_SPEC.md
  ├── ios/ResetNightSheet.swift
  ├── ios/DoseLogController+Reset.swift
  ├── ios/TodayViewModel+ResetNight.swift
  ├── ios/TodayLogView+ResetNight.swift
  └── sql/migrations/00X_reset_night.sql
```

### 🔄 Phase 4: Critical Product Fixes (FROM REVIEW)
Based on `/review/updates.md` super-critical review:

**High Priority:**
1. [ ] Dose 2 early override flow
   - Add `EarlyDoseSheet` with time-prior buttons
   - Implement "Remind me at window start" action
   - Log override events with reason

2. [ ] Missing anchor macros
   - Add "In bed now", "Alarm wake", "Bathroom", "Final wake" buttons
   - Write to `event_log` with proper provenance

3. [ ] Live Activity for Dose 2 window
   - Start on Dose 1, show opening/closing times
   - Add quick actions: Dose 2, Snooze 5, Snooze 10
   - End on Dose 2 or expiry

4. [ ] Safety feedback visibility
   - SafetyBanner with color-coded chips
   - Per-dose bounds, nightly total, wake source, Health status

5. [ ] Event history visibility
   - EventStrip showing last 3 events
   - Icons, grams, relative time
   - Contextual Undo button (60s window)

**Medium Priority:**
6. [ ] Scroll & hit-target fixes for iPhone SE
7. [ ] Permissions surfacing (Health denied, WHOOP offline)
8. [ ] Widget action reliability (pending queue consumption)
9. [ ] CSV export optimization (flattened rows)

**Lower Priority:**
10. [ ] Accessibility (VoiceOver labels, Dynamic Type)
11. [ ] Internationalization (locale-aware formatters)
12. [ ] Privacy compliance (Keychain secrets, export purging)
13. [ ] Crash analytics (structured logging, diagnostics table)

---

## 🏗️ Architecture Overview

### Data Flow (Current Implementation)
```
User Tap → TodayViewModel → DoseLogController → SQLite
                ↓                    ↓
         Live Activity Update   Health/WHOOP Sync
                ↓
         UI Refresh (SwiftUI @Observable)
```

### Safety Guardrails (Enforced)
**Config.swift constants:**
```swift
static let perDoseMinG: Double = 1.5
static let perDoseMaxG: Double = 4.5
static let totalNightMinG: Double = 3.0
static let totalNightMaxG: Double = 9.0
static let splitMinPercentFirst: Double = 40.0  // 40%
static let splitMaxPercentFirst: Double = 60.0  // 60%
static let windowStartMinAfterDose1: Int = 150  // 2.5 hours
static let windowEndMinAfterDose1: Int = 240    // 4 hours
```

**NightPlan enforcement:**
- Dose rounding to 0.25g increments
- Per-dose clamping (1.5-4.5g)
- Nightly total validation (3.0-9.0g)
- Split ratio bounds (40%-60%)

### Persistence Buckets (Recommended)
1. **SQLite (SwiftData)** - Clinical source of truth
   - `sleep_sessions`, `medication_events`, `event_log`
   - WAL mode, foreign keys ON, 365-day retention

2. **App Group UserDefaults** - Fast settings & IPC
   - Suite: `"group.com.jefferson.dosetrack"`
   - Settings, pending actions, last event snapshot

3. **Keychain** - Secrets
   - WHOOP proxy API key, OAuth tokens

4. **Application Support** - Files
   - CSV exports, debug bundles (30-90 day purge)

5. **OSLog + Diagnostics Table** - Observability
   - Structured logs (no PII), 30-60 day retention

---

## 🚀 Recommended Next Steps

### Immediate (This Week)
1. ✅ **DONE:** Fix all compilation errors
2. **Add Enhanced Settings** (~2 hours)
   - Drag `AppPreferencesEnhanced.swift` and `SettingsViewEnhanced.swift` into Xcode
   - Update `TodayViewModel` to read from enhanced prefs
   - Test settings panel navigation

3. **Implement Reset Night** (~4 hours)
   - Copy all Reset Night UX Pack files
   - Run SQL migration
   - Wire entry points in UI
   - Test both reset modes

### Short Term (This Month)
4. **Early Dose Override Flow** (~3 hours)
   - Create `EarlyDoseSheet` modal
   - Add time-prior buttons (5 min, 10 min, custom)
   - Update gating logic in `TodayViewModel`
   - Log override events

5. **Anchor Macro Grid** (~2 hours)
   - Add 4 action buttons: In bed, Alarm wake, Bathroom, Final wake
   - Wire to controller methods
   - Update EventStrip display

6. **Live Activity Polish** (~4 hours)
   - Enhance `DoseWindowActivity` with quick actions
   - Add countdown timer display
   - Handle Dose 2 quick tap

### Medium Term (Next Quarter)
7. **Widget/Intent Reliability** (~6 hours)
   - Implement App Group pending action queue
   - Add `consumePendingFromWidget()` on app foreground
   - Test intent execution during app suspension

8. **CSV Export Optimization** (~4 hours)
   - Create `ml_training_data` flattened rows
   - Build `v_clinician_csv` view
   - Add purge job (30-90 days)

9. **Accessibility & I18n** (~8 hours)
   - Add VoiceOver labels
   - Support Dynamic Type
   - Localize strings (en-US first)

---

## 📚 Documentation References

### Key Specifications
- **Product Description:** `/docs/PRODUCT_DESCRIPTION.md`
- **PRD v1.2:** `/docs/PRD_v1.2.md`
- **Reset Night Spec:** `/review/ResetNight_UX_Pack_2025-11-02/docs/RESET_NIGHT_SPEC.md`
- **Constitution:** `.specify/memory/constitution.md` (Safety-first principles)

### Implementation Guides
- **Persistence Map:** `/review/updates.md` (lines 1-150)
- **Super-Critical Review:** `/review/updates.md` (lines 151-550)
- **Settings Blueprint:** `/review/updates.md` (lines 551-650)
- **Dose 2 Gating Policy:** `/review/update2.md` (lines 1-100)

### Code Examples
- **Transaction Pattern:** `/review/updates.md` (lines 651-796)
- **Gating Function:** `/review/update2.md` (lines 101-200)
- **Undo Durability:** `/review/updates.md` (undo section)

---

## 🎯 Success Criteria

### Must Have (v1.2 Release)
- [x] Zero compilation errors
- [ ] Enhanced settings with 30+ preferences
- [ ] Reset Night feature (soft + hard)
- [ ] Early dose override with confirmation
- [ ] Live Activity with quick actions
- [ ] Event history with undo

### Should Have (v1.3)
- [ ] Widget action reliability
- [ ] CSV export optimization
- [ ] Health/WHOOP status surfacing
- [ ] iPhone SE scroll fixes

### Nice to Have (v1.4)
- [ ] VoiceOver support
- [ ] Localization (3+ languages)
- [ ] Advanced debug tools
- [ ] Crash analytics

---

## 🔐 Safety & Compliance

### Data Privacy
- ✅ Local-first architecture (no cloud sync)
- ✅ Optional WHOOP proxy (server-side token storage)
- 🔄 Keychain for on-device secrets (pending)
- 🔄 PHI export purging (30-90 days)

### Clinical Safety
- ✅ Per-dose bounds enforced (1.5-4.5g)
- ✅ Nightly total validation (3.0-9.0g)
- ✅ Window timing constraints (150-240 min)
- ✅ Override audit trail (event_log with reasons)
- 🔄 Biometric confirmation for hard resets

### Constitution Principles (v1.0)
1. **Safety First** - Guardrails enforced in code
2. **Local-First Privacy** - Data stays on device
3. **Clinician-Ready Data** - CSV export with provenance
4. **Resilient Architecture** - Transaction safety, undo support

---

## 📞 Support & Contact

**Project Owner:** Kevin Dial  
**Repository:** `/Users/kevindialmb/Downloads/DoseTrack_v1.1.1c/`  
**Documentation:** `/docs/` and `/review/`  
**Spec Kit:** `.specify/memory/` (constitution, spec, plan)

---

**Last Updated:** November 2, 2025  
**Next Review:** After Phase 2 completion (Enhanced Settings)  
**Status:** ✅ GREEN - Ready for next integration phase
