# Dose 2 Flexible Gating - Implementation Complete ✅

**Status:** ✅ BUILD SUCCEEDED  
**Date:** November 1, 2025  
**Session:** Dose 2 gating enhancement with early/late overrides

---

## Overview

Implemented a sophisticated state machine-based gating system for Dose 2 that replaces hard blocking with flexible windows and confirmation dialogs. Users can now override early/late windows with explicit consent, and all overrides are tracked for audit trails.

### Key Principle

**From User:** "You're right to allow Dose 2 with a guardrail instead of a hard block."

Instead of disabling the Dose 2 button completely, the system now:
- Shows clear state-based messaging
- Allows early/late overrides with confirmation
- Tracks override events in database
- Provides reminder scheduling options

---

## Implementation Summary

### 🎯 What Was Built

1. **Dose2Gate State Machine** (`Dose2Gate.swift`)
   - 6 states: `needDose1`, `waiting`, `early`, `open`, `grace`, `missed`
   - Time-based computation from Dose 1 timestamp
   - Configurable policy (window start/end, early allow, late grace)

2. **Dose2Button Component** (`Dose2Button.swift`)
   - SwiftUI button with state-based UI
   - Confirmation dialogs for early/late overrides
   - Color-coded status labels (gray/orange/green/red)
   - Reminder scheduling integration

3. **Override Tracking** (`EventLog.swift`)
   - New fields: `overrideType`, `overrideMinutes`, `overrideReason`
   - Audit trail for compliance/safety review
   - Database schema updated

4. **Safety Extensions** (`NightPlanExtensions.swift`)
   - Per-dose safety checks (1.5-4.5g)
   - Nightly total safety checks (3.0-9.0g)
   - User-facing safety messages

5. **UI Integration** (`TodayLogView.swift`)
   - Replaced old ActionPill with Dose2Button
   - TimelineView for 30-second gate refresh
   - Reminder scheduling callbacks

---

## State Machine Behavior

### Default Policy (Dose2Policy)

```swift
windowStartMin: 150    // 2.5 hours after Dose 1
windowEndMin: 240      // 4 hours after Dose 1
earlyAllowMin: 30      // Allow override 30 min early
lateGraceMin: 15       // Allow override 15 min late
```

### State Transitions

| Time After Dose 1 | State | Button Status | Behavior |
|-------------------|-------|---------------|----------|
| 0-120 min | `waiting` | Disabled | Shows "Window in X min" |
| 120-150 min | `early` | Enabled* | ⚠️ Requires confirmation |
| 150-240 min | `open` | Enabled | ✅ Normal window |
| 240-255 min | `grace` | Enabled* | ⚠️ Requires confirmation |
| 255+ min | `missed` | Enabled | Button says "Log missed dose" |

\* Enabled but shows confirmation dialog

### Confirmation Dialog Options

**Early State (120-150 min):**
- "Override and log now"
- "Remind me at window start" (schedules notification at 150 min)
- "Snooze 5 min"
- "Snooze 10 min"
- "Cancel"

**Grace State (240-255 min):**
- "Override and log now"
- "Cancel"

---

## Files Modified/Created

### New Files Created ✅

1. **`DoseTrackIOS/DoseTrackIOS/Dose2Gate.swift`** (120 lines)
   - State machine logic
   - `computeDose2Gate()` function
   - `Dose2Policy` struct
   - `OverrideKind` enum

2. **`DoseTrackIOS/DoseTrackIOS/Dose2Button.swift`** (104 lines)
   - SwiftUI button component
   - Confirmation dialogs
   - Status labels with color coding

3. **`DoseTrackIOS/DoseTrackIOS/NightPlanExtensions.swift`** (38 lines)
   - Safety check extensions
   - Per-dose and nightly total validation

### Files Modified ✅

1. **`DoseTrackIOS/DoseTrackIOS/EventLog.swift`**
   - Added: `overrideType: String?`
   - Added: `overrideMinutes: Int?`
   - Added: `overrideReason: String?`
   - Updated: `init()` to accept override parameters

2. **`DoseTrackIOS/DoseTrackIOS/TodayLogView.swift`**
   - Updated: `logDose2()` signature accepts `overrideKind` and `overrideMinutes`
   - Added: `scheduleWindowStartReminder()` method
   - Integrated: Dose2Button with TimelineView (30s refresh)
   - Added: Gate state computation

3. **`DoseTrackIOS/DoseTrackIOS/NightFlowServices.swift`**
   - Added: `scheduleWindowStartReminder(at:)` method

---

## Technical Details

### State Machine Algorithm

```swift
func computeDose2Gate(dose1TimeUTC: Date?, now: Date, policy: Dose2Policy) -> Dose2Gate {
    guard let d1 = dose1TimeUTC else { return .needDose1 }
    let elapsed = Int(now.timeIntervalSince(d1) / 60)
    let earlyBandStart = policy.windowStartMin - policy.earlyAllowMin
    
    if elapsed < earlyBandStart {
        return .waiting(minutesToStart: policy.windowStartMin - elapsed)
    } else if elapsed < policy.windowStartMin {
        return .early(minutesEarly: policy.windowStartMin - elapsed)
    } else if elapsed <= policy.windowEndMin {
        return .open(minutesLeft: policy.windowEndMin - elapsed)
    } else if elapsed <= policy.windowEndMin + policy.lateGraceMin {
        return .grace(minutesOver: elapsed - policy.windowEndMin)
    } else {
        return .missed
    }
}
```

### Override Tracking Schema

**EventLog Database Fields:**
```swift
overrideType: String?      // "early" or "late"
overrideMinutes: Int?      // absolute value of minutes off schedule
overrideReason: String?    // "user_override" or custom reason
```

**Example Records:**
```
Dose 2 at 130 min (early):
  overrideType: "early"
  overrideMinutes: 20
  overrideReason: "user_override"

Dose 2 at 250 min (late):
  overrideType: "late"
  overrideMinutes: 10
  overrideReason: "user_override"
```

### UI Refresh Strategy

**TimelineView Pattern:**
```swift
TimelineView(.periodic(from: Date(), by: 30.0)) { _ in
    Dose2Button(
        gate: computeDose2Gate(dose1TimeUTC: model.dose1At, now: Date()),
        ...
    )
}
```

- Recomputes gate state every 30 seconds
- Automatic UI updates as time progresses
- No manual timer management needed

---

## Safety Features

### 1. Dose Limits (NightPlanExtensions)

**Per-Dose Limits:**
- Minimum: 1.5g
- Maximum: 4.5g

**Nightly Total Limits:**
- Minimum: 3.0g (dose1 + dose2)
- Maximum: 9.0g (dose1 + dose2)

**Safety Messages:**
```swift
plan.safetyMessage
// Returns:
// "✓ Within safe range"
// "⚠️ Dose exceeds per-dose limits (1.5-4.5g)"
// "⚠️ Total exceeds nightly limits (3.0-9.0g)"
```

### 2. Confirmation Required

Early/late overrides CANNOT be logged without user confirmation:

```swift
// In Dose2Button:
.confirmationDialog("Dose 2 Early", isPresented: $showingEarlyConfirm) {
    Button("Override and log now") { handleEarlyOverride() }
    Button("Remind me at window start") { scheduleWindowStart() }
    Button("Snooze 5 min") { scheduleSnooze5() }
    Button("Snooze 10 min") { scheduleSnooze10() }
    Button("Cancel", role: .cancel) { }
}
```

### 3. Haptic Warnings

Override logs trigger warning haptics:
```swift
if overrideKind != nil {
    hapticWarn()  // Distinct haptic pattern for overrides
}
```

### 4. Toast Messages

Visual feedback on override:
```swift
toast = overrideKind == .early 
    ? "⚠️ Dose 2 logged early" 
    : "⚠️ Dose 2 logged late"
```

---

## Testing Checklist

### Manual Testing (Simulator)

- [ ] **Waiting State (0-120 min)**
  - Log Dose 1
  - Verify Dose 2 button disabled
  - Check status shows "Dose 2 in X min"

- [ ] **Early State (120-150 min)**
  - Fast-forward to 130 min after Dose 1
  - Verify button enabled
  - Verify status shows "⚠️ 20 min early"
  - Tap button → confirmation dialog appears
  - Select "Override and log now"
  - Check EventLog: `overrideType="early"`, `overrideMinutes=20`

- [ ] **Open State (150-240 min)**
  - Fast-forward to 180 min after Dose 1
  - Verify button enabled
  - Verify status shows "✓ 60 min left"
  - Tap button → NO confirmation, logs immediately

- [ ] **Grace State (240-255 min)**
  - Fast-forward to 245 min after Dose 1
  - Verify button enabled
  - Verify status shows "⚠️ 5 min over"
  - Tap button → confirmation dialog appears
  - Check EventLog: `overrideType="late"`, `overrideMinutes=5`

- [ ] **Missed State (255+ min)**
  - Fast-forward to 260 min after Dose 1
  - Verify button says "Log missed dose"
  - Tap button → logs as missed

### Reminder Testing

- [ ] **Window Start Reminder**
  - In early state, tap "Remind me at window start"
  - Verify notification scheduled for windowStartMin (150 min)

- [ ] **Snooze Reminders**
  - Tap "Snooze 5 min" → notification in 5 min
  - Tap "Snooze 10 min" → notification in 10 min

### UI Refresh Testing

- [ ] **TimelineView Auto-Update**
  - Log Dose 1
  - Watch Dose 2 button status update every 30 seconds
  - Verify state transitions happen automatically
  - Check "X min left" countdown updates

### Database Audit Testing

- [ ] **Override Tracking**
  - Log early override
  - Check EventLog view shows override badge
  - Verify CSV export includes override columns
  - Confirm override_type, override_minutes, override_reason populated

---

## Known Issues / Future Enhancements

### Resolved Issues ✅

1. ~~NightPlan struct conflict~~ → Fixed by converting to extension-only approach
2. ~~Build errors on preset creation~~ → Removed incompatible preset code
3. ~~Dose 2 button not responsive~~ → Replaced with state machine

### Potential Enhancements

1. **User Preference for Early Allow Window**
   - Add Settings option for 15/30/45 min early allow
   - Currently hardcoded to 30 min

2. **Dose Plan Presets UI**
   - Add preset selector: 50/50, 60/40, 40/60, custom
   - Would require adapting to existing NightPlan struct

3. **Override Analytics**
   - Dashboard showing override frequency
   - Patterns of early/late dosing
   - Compliance metrics

4. **Advanced Snooze Options**
   - Custom snooze intervals
   - Repeated reminders until logged

---

## Example User Flow

### Scenario: User takes Dose 1 at 10:00 PM

**10:00 PM** - Log Dose 1  
→ Dose 2 button: Disabled, "Dose 2 in 150 min"

**11:30 PM** (90 min elapsed)  
→ Dose 2 button: Disabled, "Dose 2 in 60 min"

**12:00 AM** (120 min elapsed)  
→ Dose 2 button: Enabled, "⚠️ 30 min early"  
→ User taps button → Confirmation dialog:
  - "Override and log now"
  - "Remind me at window start" (schedules 12:30 AM notification)
  - "Snooze 5 min"
  - "Snooze 10 min"
  - "Cancel"

**12:30 AM** (150 min elapsed)  
→ Dose 2 button: Enabled, "✓ 90 min left"  
→ User taps button → Logs immediately, no confirmation

**2:00 AM** (240 min elapsed)  
→ Dose 2 button: Enabled, "✓ Window ends now"

**2:05 AM** (245 min elapsed)  
→ Dose 2 button: Enabled, "⚠️ 5 min over"  
→ User taps button → Confirmation dialog:
  - "Override and log now"
  - "Cancel"

**2:20 AM** (260 min elapsed)  
→ Dose 2 button: Enabled, "Log missed dose"  
→ User taps → Logs as missed dose

---

## Code Snippets

### Using Dose2Button in Your View

```swift
TimelineView(.periodic(from: Date(), by: 30.0)) { _ in
    Dose2Button(
        gate: computeDose2Gate(
            dose1TimeUTC: viewModel.dose1At, 
            now: Date()
        ),
        plannedDoseG: nightPlan.dose2DisplayG,
        onLog: { overrideKind, overrideMinutes in
            viewModel.logDose2(
                overrideKind: overrideKind, 
                overrideMinutes: overrideMinutes
            )
        },
        scheduleWindowStart: {
            viewModel.scheduleWindowStartReminder()
        },
        scheduleSnooze5: {
            viewModel.snooze(5)
        },
        scheduleSnooze10: {
            viewModel.snooze(10)
        }
    )
}
```

### Computing Gate State

```swift
let policy = Dose2Policy(
    windowStartMin: 150,
    windowEndMin: 240,
    earlyAllowMin: 30,
    lateGraceMin: 15
)

let gate = computeDose2Gate(
    dose1TimeUTC: dose1Timestamp,
    now: Date(),
    policy: policy
)

switch gate {
case .needDose1:
    print("No Dose 1 logged yet")
case .waiting(let mins):
    print("Wait \(mins) more minutes")
case .early(let mins):
    print("Early by \(mins) min - needs confirmation")
case .open(let mins):
    print("\(mins) min left in window")
case .grace(let mins):
    print("Late by \(mins) min - needs confirmation")
case .missed:
    print("Window missed, can log as missed dose")
}
```

### Logging with Override Tracking

```swift
func logDose2(overrideKind: OverrideKind? = nil, overrideMinutes: Int? = nil) {
    let currentGate = computeDose2Gate(dose1TimeUTC: dose1At, now: Date())
    
    guard overrideKind != nil || currentGate.isButtonEnabled else {
        toast = "❌ Dose 2 window not ready"
        return
    }
    
    if overrideKind != nil {
        hapticWarn()  // Warning haptic for overrides
    }
    
    logEvent(
        .dose2,
        gramsValue: dose2G,
        overrideType: overrideKind?.rawValue,
        overrideMinutes: overrideMinutes,
        overrideReason: "user_override"
    )
    
    toast = overrideKind == .early 
        ? "⚠️ Dose 2 logged early" 
        : overrideKind == .late 
            ? "⚠️ Dose 2 logged late" 
            : "✓ Dose 2 logged"
    
    dose2At = Date()
}
```

---

## Architecture Notes

### Why State Machine Over Boolean Flags?

**Old Approach (❌ Fragile):**
```swift
let windowOpen = elapsed >= 150 && elapsed <= 240
let disabled = !windowOpen

ActionPill("Dose 2 now") { logDose2() }
    .disabled(disabled)
```

**Problems:**
- No visibility into WHY button is disabled
- Can't distinguish between "too early" vs "too late"
- No way to override with consent
- Poor user experience

**New Approach (✅ Robust):**
```swift
enum Dose2Gate {
    case needDose1
    case waiting(minutesToStart: Int)
    case early(minutesEarly: Int)      // Allows override
    case open(minutesLeft: Int)
    case grace(minutesOver: Int)       // Allows override
    case missed
}
```

**Benefits:**
- Clear state messaging
- Flexible override policy
- Audit trail for compliance
- Better user experience
- Easier to debug

### Why TimelineView?

**Problem:**
- Gate state changes over time
- Manual timer management is error-prone
- Need UI to stay current

**Solution:**
```swift
TimelineView(.periodic(from: Date(), by: 30.0)) { _ in
    Dose2Button(gate: computeDose2Gate(...))
}
```

**Benefits:**
- Automatic 30-second refresh
- SwiftUI native pattern
- No timer cleanup needed
- Efficient resource usage

---

## Build Status

```
** BUILD SUCCEEDED **

Warnings (non-blocking):
- DoseWindowActivity.swift:40: Deprecated API (iOS 16.2+)
- TodayLogView.swift:285: Unused binding 'd1'

Files Added: 3
Files Modified: 3
Total Lines Added: ~350
```

---

## Session Timeline

1. **User Request:** "You're right to allow Dose 2 with a guardrail instead of a hard block"
2. **Created:** Dose2Gate state machine (6 states)
3. **Created:** Dose2Button SwiftUI component
4. **Created:** NightPlanExtensions for safety checks
5. **Updated:** EventLog with override tracking
6. **Updated:** TodayViewModel.logDose2() for overrides
7. **Updated:** NightFlowServices with reminder scheduling
8. **Integrated:** Dose2Button into TodayLogView with TimelineView
9. **Fixed:** NightPlan struct conflict (removed incompatible presets)
10. **Build:** ✅ SUCCESS

---

## Next Steps

### Recommended Testing Flow

1. Run app in simulator
2. Log Dose 1 at 10:00 PM (or adjust time)
3. Fast-forward device clock to test state transitions:
   - 11:30 PM (waiting state)
   - 12:00 AM (early state - test confirmation)
   - 12:30 AM (open state - test immediate log)
   - 2:05 AM (grace state - test confirmation)
   - 2:20 AM (missed state)
4. Check EventLog for override records
5. Export CSV to verify override columns

### Documentation Updates

- [ ] Update `TESTING_GUIDE_COMPLETE.md` with override test cases
- [ ] Update `NIGHT_FLOW_INTEGRATION_COMPLETE.md` with new gating behavior
- [ ] Add troubleshooting section: "Why is Dose 2 disabled?"

### Future Considerations

- Add user preference for early allow window (15/30/45 min)
- Implement dose plan presets (50/50, 60/40, 40/60)
- Create override analytics dashboard
- Add custom snooze intervals

---

**✅ Dose 2 Flexible Gating - COMPLETE**  
**Ready for Testing**
