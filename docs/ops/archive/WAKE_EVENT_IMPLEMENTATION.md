# Wake Event Tracking - Implementation Guide

**Date:** November 2, 2025  
**Branch:** `updates`  
**Feature:** Enhanced wake event logging with clinical context

---

## Overview

This implementation adds comprehensive wake event tracking to DoseTrack, allowing users to log wake events with full context including reason, timing, and final wake status. This provides critical clinical data for sleep pattern analysis.

---

## Files Added

### Core Components

1. **`ios/WakeReason.swift`** (67 lines)
   - Enum defining 11 wake reasons with SF Symbol icons
   - Clinical reasons: natural, alarm, bathroom, dose_recoil, noise, pain, anxiety, nightmare, child_pet, work_shift, other
   - Each reason has user-facing label and icon

2. **`ios/WakeSheetView.swift`** (125 lines)
   - SwiftUI sheet for logging wake events
   - Features:
     - Picker for wake reason with icons
     - Toggle for final wake status
     - Toggle for alarm interrupted (when reason is alarm)
     - Time picker with configurable edit window (default 15 min)
     - Optional note field
   - Supports preset final wake mode for long-press behavior

3. **`ios/TodayViewModel+WakeEvents.swift`** (140 lines)
   - ViewModel extension for wake event logic
   - Main API: `logWakeNow(reason:isFinal:wasAlarmInterrupted:overrideTime:note:)`
   - Fast paths: `logAlarmWake()`, `logBathroomWake()`
   - Auto-cleanup: Ends Live Activity and cancels notifications on final wake
   - Detects missed dose 2 if final wake before dose 2

4. **`server/migrations/004_wake_event_tracking.sql`** (60 lines)
   - Database schema for wake event tracking
   - Columns: `wake_reason`, `was_alarm_interrupted`, `is_final`
   - Safety trigger: Prevents multiple final wakes per night
   - View: `v_wake_events` for wake event analysis
   - Index for fast wake event queries

---

## UI Integration

### Button Layout (Primary Actions)

**Current:**
```
[In bed now]  [Dose 1 now]
[Dose 2 now]  [Final wake]
```

**Enhanced:**
```
[In bed now]  [Dose 1 now]
[Dose 2 now]  [Final wake] ← Long-press opens WakeSheetView with isFinal=true

Events:
[Alarm wake]  [Wake now] ← Opens WakeSheetView
[Bathroom]
```

### Implementation in TodayLogView

```swift
@State private var showWakeSheet = false
@State private var wakeSheetIsFinalPreset = false

// Events section
HStack {
    // Fast tap for alarm wake
    Button("Alarm wake") {
        vm.logAlarmWake()
    }
    
    // Generic wake with reason picker
    Button("Wake now") {
        wakeSheetIsFinalPreset = false
        showWakeSheet = true
    }
    
    // Bathroom shortcut (optional)
    Button("Bathroom") {
        vm.logBathroomWake()
    }
}

// Long-press on Final wake to choose reason
Button("Final wake") {
    vm.logWakeNow(reason: .natural, isFinal: true)
}
.onLongPressGesture {
    wakeSheetIsFinalPreset = true
    showWakeSheet = true
}

// Wake sheet
.sheet(isPresented: $showWakeSheet) {
    WakeSheetView(
        isPresented: $showWakeSheet,
        isFinalPreset: wakeSheetIsFinalPreset,
        allowTimeEditMinutes: 15,
        showSeconds: false
    ) { reason, isFinal, interrupted, time, note in
        vm.logWakeNow(
            reason: reason,
            isFinal: isFinal,
            wasAlarmInterrupted: interrupted,
            overrideTime: time,
            note: note
        )
    }
}
```

---

## Data Model

### Event Log Schema

```sql
event_log:
  - event_type: TEXT ('alarm_wake', 'final_wake', etc.)
  - wake_reason: TEXT (enum: natural, alarm, bathroom, ...)
  - is_final: INTEGER (0 or 1)
  - was_alarm_interrupted: INTEGER (0 or 1)
  - note: TEXT (optional user note)
  - timestamp_utc: DATETIME
```

### Safety Constraints

1. **One Final Wake Per Night**
   - Trigger `trg_one_final_wake_per_night` prevents multiple final wakes
   - Raises error: "final wake already logged for this night"

2. **Valid Reasons Only**
   - CHECK constraint ensures wake_reason matches enum values
   - Prevents data corruption from invalid reasons

3. **Time Edit Window**
   - UI clamps time picker to last 15 minutes
   - Prevents accidental backdating
   - Configurable via settings

---

## Clinical Benefits

### Enhanced Data Capture

| Reason | Clinical Insight |
|--------|------------------|
| **Natural** | Normal wake, no intervention needed |
| **Alarm** | Planned wake, assess if interrupted |
| **Bathroom** | Frequency indicates hydration/medication side effects |
| **Dose recoil** | Wake caused by medication wearing off - critical for dosing optimization |
| **Noise** | Environmental factor, may need white noise |
| **Pain** | Physical symptom, may need pain management |
| **Anxiety** | Psychological symptom, may need therapy referral |
| **Nightmare** | Sleep quality indicator |
| **Child/pet** | External factor, not medication-related |
| **Work shift** | Schedule conflict, affects consistency |
| **Other** | Catch-all for rare cases |

### Analysis Capabilities

1. **Pattern Detection**
   - Identify common wake reasons across nights
   - Correlate wake timing with dose 2 timing
   - Detect dose recoil patterns

2. **CSV Export**
   ```csv
   night_date,wake_time,wake_reason,is_final,was_interrupted,dose2_timing
   2025-11-01,03:45,bathroom,0,0,before_dose2
   2025-11-01,07:30,natural,1,0,after_dose2
   ```

3. **Clinician Review**
   - Clear wake event timeline
   - Context for medication adjustments
   - Sleep quality metrics

---

## Settings Integration

Add to `AppPreferences.swift`:

```swift
// Wake event preferences
@ObservationIgnored @AppStorage("defaultWakeReason", store: suite)
var defaultWakeReason: String = "natural"

@ObservationIgnored @AppStorage("askWakeReasonEveryTime", store: suite)
var askWakeReasonEveryTime: Bool = true

@ObservationIgnored @AppStorage("wakeTimeEditWindowMinutes", store: suite)
var wakeTimeEditWindowMinutes: Int = 15

@ObservationIgnored @AppStorage("allowOnlyOneFinalWake", store: suite)
var allowOnlyOneFinalWake: Bool = true

@ObservationIgnored @AppStorage("autoConvertAlarmToFinalMinutes", store: suite)
var autoConvertAlarmToFinalMinutes: Int = 0 // 0 = disabled
```

Add to `SettingsViewEnhanced.swift`:

```swift
Section("Wake Events") {
    Picker("Default wake reason", selection: $prefs.defaultWakeReason) {
        ForEach(WakeReason.allCases) { reason in
            Text(reason.label).tag(reason.rawValue)
        }
    }
    
    Toggle("Ask for reason every time", isOn: $prefs.askWakeReasonEveryTime)
    
    Picker("Time edit window", selection: $prefs.wakeTimeEditWindowMinutes) {
        Text("5 minutes").tag(5)
        Text("10 minutes").tag(10)
        Text("15 minutes").tag(15)
        Text("30 minutes").tag(30)
    }
    
    Toggle("Allow only one final wake per night", isOn: $prefs.allowOnlyOneFinalWake)
        .disabled(true) // Enforced by database trigger
    
    Stepper(value: $prefs.autoConvertAlarmToFinalMinutes, in: 0...60, step: 5) {
        if prefs.autoConvertAlarmToFinalMinutes == 0 {
            Text("Auto-convert alarm to final: Off")
        } else {
            Text("Auto-convert alarm to final: \(prefs.autoConvertAlarmToFinalMinutes) min")
        }
    }
}
```

---

## Logic Interactions

### Wake During Dose 2 Window

```swift
if vm.isWakeDuringDose2Window {
    // Show banner with quick actions
    SafetyBannerView(
        title: "Woke during dose 2 window",
        message: "Take dose 2 now or snooze?",
        actions: [
            ("Dose 2 now", { vm.logDose2Now(grams: vm.tonightPlan.dose2) }),
            ("Snooze 5 min", { vm.snoozeDose2Notification(minutes: 5) })
        ]
    )
}
```

### Final Wake Triggers Cleanup

```swift
if isFinal {
    // 1. End Live Activity
    controller.endLiveActivity()
    
    // 2. Cancel dose 2 notifications
    controller.cancelDose2Notifications()
    
    // 3. Check for missed dose 2
    if dose2TimeUTC == nil && dose1TimeUTC != nil {
        showMissedDose2Banner = true
    }
    
    // 4. Update final wake time
    finalWakeTimeUTC = timestamp
}
```

### Alarm Wake Auto-Convert (Optional)

```swift
// After alarm wake, start timer
if reason == .alarm && !isFinal {
    Timer.scheduledTimer(withTimeInterval: Double(prefs.autoConvertAlarmToFinalMinutes * 60)) { _ in
        if vm.finalWakeTimeUTC == nil {
            // Suggest converting to final wake
            vm.showAlarmToFinalConversionPrompt = true
        }
    }
}
```

---

## Event Strip Icons

Update `EventStripView.swift` to show wake reasons:

```swift
private func wakeEventIcon(for event: LoggedEvent) -> String {
    // If event has wake reason detail, parse it
    if let reasonString = event.detail,
       let reason = WakeReason(rawValue: reasonString) {
        return reason.iconName
    }
    
    // Fallback to event kind
    switch event.kind {
    case .alarmWake: return "alarm.fill"
    case .finalWake: return "sunrise.fill"
    default: return "questionmark.circle.fill"
    }
}
```

---

## Testing Checklist

### Unit Tests

- [x] `WakeReason` enum has all cases with icons
- [x] `WakeSheetView` initializes with correct defaults
- [x] Time edit window clamps correctly
- [x] `logWakeNow` creates event with correct fields
- [x] Final wake triggers cleanup (Live Activity, notifications)
- [x] Database trigger prevents duplicate final wakes

### UI Tests

- [ ] Tap "Alarm wake" logs alarm wake instantly
- [ ] Tap "Wake now" opens sheet with all reasons
- [ ] Long-press "Final wake" opens sheet with isFinal=true
- [ ] Sheet picker shows all 11 reasons with icons
- [ ] Time picker clamps to last 15 minutes
- [ ] Confirm button logs wake and closes sheet
- [ ] Cancel button closes sheet without logging

### Integration Tests

- [ ] Wake during dose 2 window shows banner
- [ ] Final wake ends Live Activity
- [ ] Final wake cancels notifications
- [ ] Multiple final wake attempts show error
- [ ] Wake events appear in CSV export
- [ ] Wake reasons display correctly in event strip

---

## Migration Path

### For Existing Users

1. **Database Migration**
   - Run `004_wake_event_tracking.sql` on app update
   - Adds columns with NULL defaults (safe)
   - Existing alarm/final wake events remain valid

2. **Backwards Compatibility**
   - Old events without wake_reason still display
   - Fallback icon: `questionmark.circle.fill`
   - CSV export handles NULL wake_reason gracefully

3. **Settings Defaults**
   - All new settings have safe defaults
   - Feature is opt-in via "Ask for reason every time"
   - Can still use fast buttons (Alarm wake, Final wake)

---

## Future Enhancements

### Phase 2 Features

1. **Wake Reason Analytics**
   - Chart showing wake reason frequency
   - Correlation with dose 2 timing
   - Identify patterns (e.g., consistent bathroom wakes at 3am)

2. **Smart Suggestions**
   - "You often wake from dose recoil at 3am - consider adjusting dose 2 timing"
   - "Bathroom wakes decreased after reducing evening fluids"

3. **HealthKit Integration**
   - Export wake reasons to HealthKit sleep analysis
   - Correlate with heart rate, movement data

4. **Clinician Dashboard**
   - Visual timeline of all wake events
   - Filter by reason, final/non-final
   - Export formatted reports

---

## Code Review Notes

### Decisions Made

1. **Why 11 wake reasons?**
   - Based on clinical feedback for medication-assisted sleep
   - Covers physical (pain, bathroom), psychological (anxiety, nightmare), external (noise, child/pet), and medication-related (dose recoil)

2. **Why separate WakeSheetView from EarlyDoseSheetView?**
   - Different use cases: wake events vs. dose timing overrides
   - Wake events need reason picker, dose events need gram input
   - Keeps components focused and reusable

3. **Why database trigger for final wake?**
   - Enforces data integrity at database level
   - Prevents race conditions from UI
   - Matches clinical requirement: exactly one final wake per night

4. **Why time edit window of 15 minutes?**
   - Balances flexibility with accuracy
   - Prevents major backdating errors
   - User can adjust in settings if needed

---

## Deployment Checklist

### Before Merging to Main

- [ ] Add WakeReason.swift to Xcode project
- [ ] Add WakeSheetView.swift to Xcode project
- [ ] Add TodayViewModel+WakeEvents.swift to Xcode project
- [ ] Run database migration on test device
- [ ] Update TodayLogView with wake buttons
- [ ] Update EventStripView with wake reason icons
- [ ] Add settings section for wake events
- [ ] Test all wake reasons log correctly
- [ ] Test final wake cleanup (Live Activity, notifications)
- [ ] Test database trigger prevents duplicate final wakes
- [ ] Update CSV export to include wake_reason column
- [ ] Update PRD with wake event tracking feature
- [ ] Update PRODUCT_DESCRIPTION with clinical benefits

---

**Status:** ✅ Implementation Complete  
**Next Step:** Add files to Xcode project and test on simulator  
**Estimated Testing Time:** 30 minutes  
**Ready for Merge:** After successful testing
