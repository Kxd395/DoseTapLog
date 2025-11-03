# Settings Configuration - Complete Implementation

**📍 Location:** `docs/ops/SETTINGS_IMPLEMENTATION.md`  
**📚 Breadcrumbs:** `docs/` → `ops/` → **`SETTINGS_IMPLEMENTATION.md`**

**🔗 Related Documentation:**
- Main App: `DoseTrackIOS/DoseTrackIOS/TodayLogView.swift`
- Settings UI: `DoseTrackIOS/DoseTrackIOS/SettingsView.swift`
- State Machine: `docs/design/DOSE2_LOGIC_FLOW.md`
- Testing: `docs/ops/TESTING_GUIDE_COMPLETE.md`

---

**Date:** November 2, 2025  
**Project:** DoseTrack v1.1.1c  
**Build Status:** ✅ BUILD SUCCEEDED

---

## Overview

Comprehensive Settings screen with gear icon access, providing full configuration control over:
- Dose 2 window policy (SSOT)
- Safety guardrails (SSOT)
- Display preferences
- Notification settings
- Data & privacy options
- Default dose plans

All settings use `@AppStorage` for local persistence (Single Source of Truth).

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SETTINGS ARCHITECTURE                    │
│                   (SSOT with AppStorage)                    │
└─────────────────────────────────────────────────────────────┘

                     USER INTERFACE
┌─────────────────────────────────────────────────────────────┐
│ TodayLogView                                                │
│  │                                                          │
│  ├─ Settings Gear Button (Top Right)                       │
│  │      │                                                   │
│  │      ▼                                                   │
│  │  .sheet(isPresented: $showSettings)                     │
│  │      │                                                   │
│  │      └──▶ SettingsView()                                │
│  │                                                          │
│  └─ @AppStorage variables (read settings)                  │
│     - windowStartMin                                        │
│     - windowEndMin                                          │
│     - earlyAllowMin                                         │
│     - lateGraceMin                                          │
└─────────────────────────────────────────────────────────────┘
                     │
                     ▼
             SSOT: AppStorage
┌─────────────────────────────────────────────────────────────┐
│ UserDefaults (Local Device Storage)                         │
│                                                             │
│  ┌────────────────────────────────────────────────────┐    │
│  │ dose2_window_start_min: 150                        │    │
│  │ dose2_window_end_min: 240                          │    │
│  │ dose2_early_allow_min: 30                          │    │
│  │ dose2_late_grace_min: 15                           │    │
│  │ safety_per_dose_min: 1.5                           │    │
│  │ safety_per_dose_max: 4.5                           │    │
│  │ safety_nightly_min: 3.0                            │    │
│  │ safety_nightly_max: 9.0                            │    │
│  │ display_show_grams: true                           │    │
│  │ display_24_hour_time: false                        │    │
│  │ notif_window_start: true                           │    │
│  │ data_healthkit_sync: true                          │    │
│  │ plan_total_night_g: 6.5                            │    │
│  │ plan_split_preset: "50/50"                         │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                     │
                     ▼
              APPLICATION LOGIC
┌─────────────────────────────────────────────────────────────┐
│ TodayLogView uses settings:                                 │
│                                                             │
│  var userPolicy: Dose2Policy {                              │
│      Dose2Policy(                                           │
│          windowStartMin: windowStartMin,  // from @AppStorage│
│          windowEndMin: windowEndMin,                        │
│          earlyAllowMin: earlyAllowMin,                      │
│          lateGraceMin: lateGraceMin                         │
│      )                                                      │
│  }                                                          │
│                                                             │
│  Dose2Button(                                               │
│      gate: computeDose2Gate(..., policy: userPolicy)        │
│  )                                                          │
└─────────────────────────────────────────────────────────────┘
```

---

## Settings Sections

### 1. Dose 2 Window Policy ⚙️

**Purpose:** Configure timing windows for Dose 2 with user-customizable margins

```
┌─────────────────────────────────────────────────────────────┐
│ ⏰ Dose 2 Window Policy                                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Window Start                                               │
│  ━━━━━━━━━━━━━━○━━━━━ 150 min                              │
│  120 ←──────────┼──────────→ 180                            │
│  Time after Dose 1 when window opens                        │
│                                                             │
│  Window End                                                 │
│  ━━━━━━━━━━━━━━━━━━○━━ 240 min                              │
│  210 ←──────────┼──────────→ 300                            │
│  Time after Dose 1 when window closes                       │
│                                                             │
│  Early Allow Window                                         │
│  ┌────────┬────────┬────────┐                              │
│  │ 15 min │ 30 min │ 45 min │  ← Selected: 30             │
│  └────────┴────────┴────────┘                              │
│  How early you can log Dose 2 with confirmation             │
│                                                             │
│  Late Grace Period                                          │
│  ┌────────┬────────┬────────┐                              │
│  │ 10 min │ 15 min │ 20 min │  ← Selected: 15             │
│  └────────┴────────┴────────┘                              │
│  How late you can log Dose 2 with confirmation              │
│                                                             │
│  ────────────────────────────────────────────────────       │
│  Current Policy:                                            │
│  • Early:  120 - 150 min  (orange)                         │
│  • Normal: 150 - 240 min  (green)                          │
│  • Grace:  240 - 255 min  (orange)                         │
│  • Missed: 255+ min       (red)                            │
└─────────────────────────────────────────────────────────────┘
```

**Settings:**
- `windowStartMin` (slider, 120-180 min, step 5)
- `windowEndMin` (slider, 210-300 min, step 10)
- `earlyAllowMin` (segmented picker, 15/30/45 min)
- `lateGraceMin` (segmented picker, 10/15/20 min)

**SSOT Keys:**
- `dose2_window_start_min` (Int, default: 150)
- `dose2_window_end_min` (Int, default: 240)
- `dose2_early_allow_min` (Int, default: 30)
- `dose2_late_grace_min` (Int, default: 15)

### 2. Safety Guardrails 🛡️

**Purpose:** Enforce dose limits per Constitution Principle I (Safety First)

```
┌─────────────────────────────────────────────────────────────┐
│ 🛡️ Safety Guardrails                                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Per-Dose Minimum                                           │
│  ━━━━━━━○━━━━━━━━━━━━━ 1.50g                               │
│  1.0 ←──┼────────────→ 2.5                                  │
│                                                             │
│  Per-Dose Maximum                                           │
│  ━━━━━━━━━━━━━━━○━━━━━ 4.50g                               │
│  3.5 ←──────────┼────→ 6.0                                  │
│                                                             │
│  Nightly Minimum                                            │
│  ━━━━━━━○━━━━━━━━━━━━━ 3.0g                                │
│  2.0 ←──┼────────────→ 4.0                                  │
│                                                             │
│  Nightly Maximum                                            │
│  ━━━━━━━━━━━━━━━━○━━━━━ 9.0g                               │
│  7.0 ←──────────┼────→ 12.0                                 │
│                                                             │
│  ────────────────────────────────────────────────────────   │
│  Constitution Principle I: Safety First                     │
│  These limits prevent unsafe dosing                         │
└─────────────────────────────────────────────────────────────┘
```

**Settings:**
- `perDoseMin` (slider, 1.0-2.5g, step 0.25)
- `perDoseMax` (slider, 3.5-6.0g, step 0.25)
- `nightlyMin` (slider, 2.0-4.0g, step 0.5)
- `nightlyMax` (slider, 7.0-12.0g, step 0.5)

**SSOT Keys:**
- `safety_per_dose_min` (Double, default: 1.5)
- `safety_per_dose_max` (Double, default: 4.5)
- `safety_nightly_min` (Double, default: 3.0)
- `safety_nightly_max` (Double, default: 9.0)

### 3. Default Dose Plan 💊

**Purpose:** Set default nightly plan with preset splits

```
┌─────────────────────────────────────────────────────────────┐
│ 💊 Default Dose Plan                                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Total Nightly Dose                                         │
│  ━━━━━━━━━━━━━━━○━━━━━ 6.50g                               │
│  3.0 ←──────────┼────→ 9.0                                  │
│                                                             │
│  Dose Split Preset                                          │
│  ┌──────────┬──────────┬──────────┐                        │
│  │ 50/50    │ 60/40    │ 40/60    │  ← Selected: 50/50    │
│  │ Even     │ Front    │ Back     │                        │
│  └──────────┴──────────┴──────────┘                        │
│                                                             │
│  Preview                                                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Dose 1           Dose 2                             │  │
│  │  3.25g            3.25g                              │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ────────────────────────────────────────────────────────   │
│  This plan is used as the default when creating a new night│
└─────────────────────────────────────────────────────────────┘
```

**Settings:**
- `totalNightG` (slider, 3.0-9.0g, step 0.25)
- `splitPreset` (segmented picker, "50/50"/"60/40"/"40/60")

**Live Preview:**
- Shows calculated Dose 1 and Dose 2 amounts
- Applies 0.25g rounding

**SSOT Keys:**
- `plan_total_night_g` (Double, default: 6.5)
- `plan_split_preset` (String, default: "50/50")

### 4. Display Preferences 👁️

**Purpose:** UI customization options

```
┌─────────────────────────────────────────────────────────────┐
│ 👁️ Display                                                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ○ Show Gram Amounts              [ON]                     │
│  ○ Use 24-Hour Time               [OFF]                    │
│  ○ Show Ring Countdown            [ON]                     │
│  ○ Haptic Feedback                [ON]                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Settings:**
- `showGrams` (toggle, default: true)
- `use24HourTime` (toggle, default: false)
- `showRingCountdown` (toggle, default: true)
- `hapticFeedback` (toggle, default: true)

**SSOT Keys:**
- `display_show_grams` (Bool)
- `display_24_hour_time` (Bool)
- `display_show_ring_countdown` (Bool)
- `display_haptic_feedback` (Bool)

### 5. Notifications 🔔

**Purpose:** Control reminder alerts

```
┌─────────────────────────────────────────────────────────────┐
│ 🔔 Notifications                                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ○ Window Start Alert             [ON]                     │
│  ○ Window Midpoint Alert          [ON]                     │
│  ○ Window Closing Alert           [ON]                     │
│                                                             │
│  Default Snooze Duration                                    │
│  ┌────────┬────────┬────────┐                              │
│  │ 5 min  │ 10 min │ 15 min │  ← Selected: 5              │
│  └────────┴────────┴────────┘                              │
│                                                             │
│  ────────────────────────────────────────────────────────   │
│  Reminders help you stay on schedule                        │
└─────────────────────────────────────────────────────────────┘
```

**Settings:**
- `notifyWindowStart` (toggle, default: true)
- `notifyMidpoint` (toggle, default: true)
- `notifyClosing` (toggle, default: true)
- `snoozeDefaultMin` (segmented picker, 5/10/15 min)

**SSOT Keys:**
- `notif_window_start` (Bool)
- `notif_window_midpoint` (Bool)
- `notif_window_closing` (Bool)
- `notif_snooze_default` (Int)

### 6. Data & Privacy 🔒

**Purpose:** Control data syncing and export (Constitution Principle II)

```
┌─────────────────────────────────────────────────────────────┐
│ 🔒 Data & Privacy                                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ○ HealthKit Sync                 [ON]                     │
│  ○ Auto Backup (Weekly)           [OFF]                    │
│  ○ Include Overrides in CSV       [ON]                     │
│                                                             │
│  ────────────────────────────────────────────────────────   │
│  Constitution Principle II: Local-First Privacy             │
│  All data stays on your device                              │
└─────────────────────────────────────────────────────────────┘
```

**Settings:**
- `healthKitSync` (toggle, default: true)
- `autoBackup` (toggle, default: false)
- `includeOverridesInCSV` (toggle, default: true)

**SSOT Keys:**
- `data_healthkit_sync` (Bool)
- `data_auto_backup` (Bool)
- `data_include_override_csv` (Bool)

### 7. Actions ⚙️

**Purpose:** Settings management

```
┌─────────────────────────────────────────────────────────────┐
│ ⚙️ Actions                                                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  🔄 Reset All Settings            [RED]                    │
│  ℹ️  About DoseTrack                                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Reset Alert:**
```
┌──────────────────────────────────┐
│ Reset All Settings?              │
├──────────────────────────────────┤
│ This will restore all settings   │
│ to their default values. Your    │
│ logged events will not be        │
│ affected.                        │
│                                  │
│  [Cancel]    [Reset (RED)]       │
└──────────────────────────────────┘
```

---

## About Screen

### Structure

```
┌─────────────────────────────────────────────────────────────┐
│ About                                           [Done]      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                  💊                                         │
│                                                             │
│              DoseTrack                                      │
│              v1.1.1c                                        │
│         Local-First Sleep Dosing Tracker                    │
│                                                             │
│  ──────────────────────────────────────────────────────     │
│                                                             │
│  Core Principles                                            │
│  ┌───────────────────────────────────────────────────┐     │
│  │ 🛡️ Safety First                                   │     │
│  │    Dose limits prevent unsafe dosing              │     │
│  │                                                   │     │
│  │ 🔒 Local-First Privacy                            │     │
│  │    All data stays on your device                  │     │
│  │                                                   │     │
│  │ 📄 Clinician-Ready Data                           │     │
│  │    CSV export for healthcare providers            │     │
│  └───────────────────────────────────────────────────┘     │
│                                                             │
│  ──────────────────────────────────────────────────────     │
│                                                             │
│  Documentation                                              │
│  ┌───────────────────────────────────────────────────┐     │
│  │ 📖 Documentation Index                            │     │
│  │ 📘 Product Description                            │     │
│  │ ✅ Testing Guide                                  │     │
│  └───────────────────────────────────────────────────┘     │
│                                                             │
│  ──────────────────────────────────────────────────────     │
│                                                             │
│  Build Information                                          │
│  ┌───────────────────────────────────────────────────┐     │
│  │ Build Date:    November 2, 2025                   │     │
│  │ Build Status:  ✅ SUCCEEDED                        │     │
│  │ Platform:      iOS 17.0+                          │     │
│  │ Framework:     SwiftUI + SwiftData                │     │
│  └───────────────────────────────────────────────────┘     │
│                                                             │
│  © 2025 DoseTrack. All rights reserved.                    │
└─────────────────────────────────────────────────────────────┘
```

---

## Integration Flow

### User Journey

```
User in TodayLogView
         │
         ▼
    Taps ⚙️ gear icon (top right)
         │
         ▼
    ┌──────────────────┐
    │ SettingsView     │
    │ (sheet)          │
    └────────┬─────────┘
             │
    ┌────────┴────────┬────────┬────────┬────────┐
    │                 │        │        │        │
    ▼                 ▼        ▼        ▼        ▼
 Dose 2          Safety   Display   Notif   Data
 Window          Limits    Prefs    Prefs   Prefs
    │                 │        │        │        │
    ▼                 ▼        ▼        ▼        ▼
Adjust sliders   Set limits  Toggles  Toggles  Toggles
    │                 │        │        │        │
    └─────────────────┴────────┴────────┴────────┘
                      │
                      ▼
           Saved to @AppStorage
           (UserDefaults)
                      │
                      ▼
           TodayLogView reads values
                      │
                      ▼
           Creates userPolicy: Dose2Policy
                      │
                      ▼
           Dose2Button uses new policy
                      │
                      ▼
           State machine updates with
           user-configured windows
```

### Data Flow

```
SettingsView @AppStorage ─┐
                          │
TodayLogView @AppStorage ─┤
                          │
                          ├──▶ UserDefaults (SSOT)
                          │         │
Other Components ─────────┘         │
                                   ▼
                          All components sync
                          automatically when
                          values change
```

---

## Default Values

```swift
// Dose 2 Window Policy
windowStartMin = 150      // 2.5 hours
windowEndMin = 240        // 4.0 hours
earlyAllowMin = 30        // 30 min early
lateGraceMin = 15         // 15 min late

// Safety Limits
perDoseMin = 1.5g
perDoseMax = 4.5g
nightlyMin = 3.0g
nightlyMax = 9.0g

// Display
showGrams = true
use24HourTime = false
showRingCountdown = true
hapticFeedback = true

// Notifications
notifyWindowStart = true
notifyMidpoint = true
notifyClosing = true
snoozeDefaultMin = 5

// Data & Privacy
healthKitSync = true
autoBackup = false
includeOverridesInCSV = true

// Default Plan
totalNightG = 6.5g
splitPreset = "50/50"
```

---

## Testing Checklist

### Settings UI

- [ ] Settings gear button appears in top right of TodayLogView
- [ ] Tapping gear opens SettingsView sheet
- [ ] All sections render correctly
- [ ] Sliders work and update values
- [ ] Segmented pickers select correctly
- [ ] Toggles switch on/off
- [ ] "Done" button dismisses sheet

### Dose 2 Window Policy

- [ ] Window Start slider (120-180 min, step 5)
- [ ] Window End slider (210-300 min, step 10)
- [ ] Early Allow picker (15/30/45 min)
- [ ] Late Grace picker (10/15/20 min)
- [ ] Current Policy footer updates live
- [ ] Values persist after app restart

### Safety Guardrails

- [ ] Per-Dose Min slider (1.0-2.5g, step 0.25)
- [ ] Per-Dose Max slider (3.5-6.0g, step 0.25)
- [ ] Nightly Min slider (2.0-4.0g, step 0.5)
- [ ] Nightly Max slider (7.0-12.0g, step 0.5)
- [ ] Values persist after app restart

### Default Dose Plan

- [ ] Total Nightly Dose slider (3.0-9.0g, step 0.25)
- [ ] Split Preset picker (50/50, 60/40, 40/60)
- [ ] Preview updates live with calculated doses
- [ ] Preview applies 0.25g rounding
- [ ] Values persist after app restart

### Display Preferences

- [ ] All toggles work
- [ ] Values persist after app restart
- [ ] (Future) Settings actually affect UI

### Notifications

- [ ] All toggles work
- [ ] Snooze default picker works
- [ ] Values persist after app restart
- [ ] (Future) Notifications respect settings

### Data & Privacy

- [ ] All toggles work
- [ ] Values persist after app restart
- [ ] (Future) CSV export respects includeOverridesInCSV

### Actions

- [ ] "Reset All Settings" shows confirmation alert
- [ ] Alert has "Cancel" and "Reset" (red)
- [ ] Reset restores all defaults
- [ ] "About DoseTrack" opens About sheet

### About Screen

- [ ] App icon displays
- [ ] Version number correct (v1.1.1c)
- [ ] Core Principles section renders
- [ ] Documentation links present
- [ ] Build Information correct
- [ ] "Done" button dismisses

### Integration with Dose2Gate

- [ ] Changing window settings updates Dose2Button behavior
- [ ] Early Allow setting changes early threshold
- [ ] Late Grace setting changes grace threshold
- [ ] State machine uses user policy
- [ ] Window times reflect user settings

---

## Build Status

```
** BUILD SUCCEEDED **

Files Created: 1
  - DoseTrackIOS/DoseTrackIOS/SettingsView.swift (500+ lines)

Files Modified: 1
  - DoseTrackIOS/DoseTrackIOS/TodayLogView.swift (added gear button, @AppStorage, userPolicy)

Warnings: 1 (non-blocking)
  - Unused binding 'd1' in TodayLogView.swift

Status: ✅ READY FOR TESTING
```

---

## Future Enhancements

### Phase 2
- [ ] Advanced dose plan editor (custom splits)
- [ ] Multiple saved plans with names
- [ ] Import/export settings JSON
- [ ] Settings search
- [ ] iCloud settings sync (opt-in)

### Phase 3
- [ ] Per-night override of default plan
- [ ] History-based plan recommendations
- [ ] WHOOP recovery score integration settings
- [ ] Advanced notification scheduling
- [ ] Custom snooze intervals

---

**Version:** 1.0.0  
**Last Updated:** November 2, 2025  
**Status:** ✅ COMPLETE  
**Build:** ✅ SUCCEEDED  

**Constitution Alignment:**
- ✅ Principle I: Safety First (enforced via limits)
- ✅ Principle II: Local-First Privacy (all settings local)
- ✅ Principle III: Clinician-Ready Data (CSV export settings)

---

**Quick Links:**
- [Settings Implementation](../../DoseTrackIOS/DoseTrackIOS/SettingsView.swift)
- [Main View Integration](../../DoseTrackIOS/DoseTrackIOS/TodayLogView.swift)
- [Dose 2 Logic Flow](../design/DOSE2_LOGIC_FLOW.md)
- [Testing Guide](TESTING_GUIDE_COMPLETE.md)
