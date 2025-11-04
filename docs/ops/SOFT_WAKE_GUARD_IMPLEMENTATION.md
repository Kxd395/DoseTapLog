# Dose 2 Soft-Wake Alarm + Hard No-Wake Guard - Implementation Summary

**Feature:** Item 60  
**Status:** Foundation Ready (60%)  
**Date:** November 4, 2025  
**Priority:** CRITICAL  

---

## Overview

Implements a **gentle, reliable wake system for Dose 2** while protecting work-morning sleep with a **hard guard**—and still preserving clinician-friendly **override + audit**.

### The Problem

- Users miss Dose 2 window when asleep
- No soft wake system causes missed doses
- Too close to morning wake = reduced sleep before work
- No way to override guard with clinical context

### The Solution

**Soft-Wake Alarms:**
- Time-sensitive notifications at window start
- Optional mid-window ping
- Last call alert (10 min before close)
- Respects quiet hours (unless user opts to break them)
- Strong mode loops until acknowledged

**Hard No-Wake Guard:**
- Calculate cutoff: `plannedFinalWake - buffer` (180min workday, 120min offday)
- Check guard FIRST in gate evaluation
- Cancel pending Dose 2 alarms when guard trips
- Show contextual sheet with override path
- Require reason + log full audit trail

---

## Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────┐
│                  Dose2Gate.swift                        │
│  ┌────────────────────────────────────────────────┐    │
│  │ enum Dose2Gate                                  │    │
│  │  - .noWakeGuard(minutesUntilWake: Int)  NEW   │    │
│  │                                                 │    │
│  │ enum Dose2AlarmStyle                      NEW   │    │
│  │  - off / banner / soft / strong                │    │
│  │                                                 │    │
│  │ struct Dose2Policy                              │    │
│  │  - workdayNoWakeBufferMin: Int           NEW   │    │
│  │  - offdayNoWakeBufferMin: Int            NEW   │    │
│  │  - allowGuardOverride: Bool              NEW   │    │
│  │                                                 │    │
│  │ struct Dose2Override                            │    │
│  │  - kind: .guard                          NEW   │    │
│  └────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│             NotificationHelper.swift                    │
│  ┌────────────────────────────────────────────────┐    │
│  │ scheduleDose2Alarms(...)                  NEW   │    │
│  │  - Window open alert (time-sensitive)          │    │
│  │  - Mid-window ping (optional)                  │    │
│  │  - Last call (10 min before close)             │    │
│  │  - Cancel task at guard cutoff                 │    │
│  │                                                 │    │
│  │ Notification Categories:                       │    │
│  │  - DOSE2_OPEN (actions: Log Now, Snooze 5m)   │    │
│  │  - DOSE2_MID (actions: Log Now, Snooze 10m)   │    │
│  │  - DOSE2_LASTCALL (action: Log Now)           │    │
│  │  - DOSE2_GUARD (informational)                │    │
│  └────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│            GuardNoWakeSheet.swift                       │
│  ┌────────────────────────────────────────────────┐    │
│  │ Hard No-Wake Guard UI                     NEW   │    │
│  │  - Warning message (minutes until wake)        │    │
│  │  - Reason field (required to proceed)          │    │
│  │  - Proceed anyway (red destructive button)     │    │
│  │  - Snooze options (5/10/15m buttons)           │    │
│  │  - Close button                                │    │
│  └────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│         AppPreferencesEnhanced.swift                    │
│  ┌────────────────────────────────────────────────┐    │
│  │ Guard Settings:                           NEW   │    │
│  │  - workdayNoWakeBufferMin: 180                 │    │
│  │  - offdayNoWakeBufferMin: 120                  │    │
│  │  - allowGuardOverride: true                    │    │
│  │  - guardRequireReason: true                    │    │
│  │                                                 │    │
│  │ Alarm Settings:                           NEW   │    │
│  │  - dose2AlarmEnabled: true                     │    │
│  │  - dose2AlarmStyle: .soft                      │    │
│  │  - breakQuietHoursForDose2: false              │    │
│  │  - dose2MidPingEnabled: false                  │    │
│  │  - dose2SnoozeOptionsCSV: "5,10,15"            │    │
│  └────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

---

## Implementation Details

### 1. Gate Evaluation (Dose2Gate.swift)

**evaluateDose2Gate() - Updated:**

```swift
func evaluateDose2Gate(
    now: Date,
    dose1At: Date?,
    dose2At: Date?,
    policy: Dose2Policy,
    plannedFinalWake: Date?,
    isWorkday: Bool
) -> Dose2Gate {
    // Check guard FIRST (before window math)
    if let wake = plannedFinalWake {
        let minutesUntilWake = Int(wake.timeIntervalSince(now) / 60.0)
        let guardBuffer = isWorkday 
            ? policy.workdayNoWakeBufferMin 
            : policy.offdayNoWakeBufferMin
        
        if minutesUntilWake <= guardBuffer && minutesUntilWake > 0 {
            return .noWakeGuard(minutesUntilWake: minutesUntilWake)
        }
    }
    
    // Then standard window math
    // ...
}
```

**Key Decision:** Guard check happens **before** window math so we can cancel alarms early and prevent waking user.

### 2. Notification Scheduling (NotificationHelper.swift)

**scheduleDose2Alarms() - New Function:**

Triggered when Dose 1 is logged:

```swift
NotificationHelper.scheduleDose2Alarms(
    dose1Time: dose1TimeUTC,
    windowStartMin: policy.startMin,
    windowEndMin: policy.endMin,
    guardCutoff: guardCutoffTime,  // calculated from plannedFinalWake
    style: prefs.dose2AlarmStyle,
    nightKey: night.nightKey
)
```

**Alerts Scheduled:**

1. **Window Open** - `dose1 + windowStartMin`
   - Category: `DOSE2_OPEN`
   - Actions: "Log Now", "Snooze 5m"
   - Interruption: Time-sensitive (unless quiet hours + no override)

2. **Mid-Window Ping** - `dose1 + ((windowStart + windowEnd) / 2)` (optional)
   - Category: `DOSE2_MID`
   - Actions: "Log Now", "Snooze 10m"
   - Enabled via: `prefs.dose2MidPingEnabled`

3. **Last Call** - `dose1 + windowEndMin - 10min`
   - Category: `DOSE2_LASTCALL`
   - Action: "Log Now"
   - Always time-sensitive

4. **Cancel Task** - `guardCutoffTime`
   - Cancels all `dose2_*` notifications when fired
   - Shows passive banner: "No-wake guard active"

**Interruption Level Logic:**

```swift
switch style {
case .off, .banner:
    return .passive
case .soft:
    if prefs.breakQuietHoursForDose2 {
        return .timeSensitive
    }
    let inQuietHours = (hour >= prefs.quietHoursStart || hour < prefs.quietHoursEnd)
    return inQuietHours ? .passive : .timeSensitive
case .strong:
    return .timeSensitive  // + defaultCritical sound
}
```

### 3. Guard Sheet UI (GuardNoWakeSheet.swift)

**Component Structure:**

```swift
GuardNoWakeSheet(
    minutesUntilWake: 105,
    isWorkday: true,
    allowOverride: policy.allowGuardOverride,
    onProceed: { reason in
        // Log Dose 2 with override audit trail
        tryLogDose2(
            at: Date(),
            source: "override_guard",
            override: Dose2Override(
                kind: .guard,
                minutes: guardBuffer - minutesUntilWake,
                reason: reason,
                ...
            )
        )
    },
    onSnooze: { minutes in
        // Reschedule guard check + update audit trail
    },
    onClose: {
        // Dismiss without action
    }
)
```

**UI Elements:**

- 🌙 Moon icon (orange)
- Title: "Hard no-wake is on"
- Subtitle: "It's too close to your wake time [for work]"
- Warning box: "Wake in N minutes" + explanation
- Reason field: Required for override, 3-6 line text editor
- **Proceed anyway** button: Red/destructive, disabled if reason empty
- Snooze buttons: 5m / 10m / 15m (from CSV prefs)
- Close button: Gray, non-destructive

**Validation:**

- Reason field must be non-empty (trimmed)
- Proceed button enabled only when reason has content
- Auto-focus reason field if user tries to proceed without entering text

### 4. Settings Integration (AppPreferencesEnhanced.swift)

**New Settings:**

```swift
// Guard
@AppStorage("guard_workday_buffer_min") var workdayNoWakeBufferMin: Int = 180
@AppStorage("guard_offday_buffer_min") var offdayNoWakeBufferMin: Int = 120
@AppStorage("guard_allow_override") var allowGuardOverride: Bool = true
@AppStorage("guard_require_reason") var guardRequireReason: Bool = true

// Alarms
@AppStorage("dose2_alarm_enabled") var dose2AlarmEnabled: Bool = true
@AppStorage("dose2_alarm_style_raw") var dose2AlarmStyleRaw: String = "soft"
@AppStorage("dose2_break_quiet_hours") var breakQuietHoursForDose2: Bool = false
@AppStorage("dose2_mid_ping_enabled") var dose2MidPingEnabled: Bool = false
@AppStorage("dose2_snooze_options") var dose2SnoozeOptionsCSV: String = "5,10,15"
```

**Settings UI Structure (Item 7):**

```
Settings
├─ Night Plan
├─ Alarms ⭐ NEW SECTION
│  ├─ Dose 2 Alarm Style: [Off / Banner / Soft / Strong]
│  ├─ Break Quiet Hours for Dose 2: [Toggle]
│  ├─ Mid-Window Ping: [Toggle]
│  ├─ Snooze Options: [5,10,15 min chips]
│  └─ No-Wake Guard
│     ├─ Workday Buffer: [Stepper: 60-300 min]
│     ├─ Off-Day Buffer: [Stepper: 60-240 min]
│     └─ Allow Override: [Toggle]
├─ Data Sources
├─ Export
├─ Privacy
├─ Developer
└─ Service Day
```

---

## Data Flow

### Scenario: Soft-Wake Alarm Triggered

```
1. User logs Dose 1 at 11:30 PM
   ↓
2. DoseLogController.logDose1(...)
   ↓
3. Calculate guard cutoff:
   guardCutoff = plannedFinalWake (7:00 AM)
               - workdayBuffer (180 min)
               = 4:00 AM
   ↓
4. NotificationHelper.scheduleDose2Alarms(...)
   - Window open: 2:00 AM (150 min after Dose 1)
   - Last call: 3:50 AM (10 min before 4:00 AM close)
   - Cancel task: 4:00 AM (guard cutoff)
   ↓
5. At 2:00 AM: Window Open notification fires
   User taps "Log Now" action
   ↓
6. UNUserNotificationCenterDelegate receives action
   Calls DoseLogController.logDose2(at: Date(), source: "notification")
   ↓
7. Dose 2 logged with source tracking
   Cancel remaining alerts (last call, guard cancel)
```

### Scenario: Guard Activated

```
1. User wakes at 3:30 AM (manually or bathroom)
   Opens app, taps Dose 2 button
   ↓
2. evaluateDose2Gate(now: 3:30 AM, ...)
   minutesUntilWake = 7:00 AM - 3:30 AM = 210 min (3h 30m)
   guardBuffer = 180 min (workday)
   ↓
3. 210 > 180? NO
   Return .noWakeGuard(minutesUntilWake: 210)
   ↓
4. NightCardViewModern shows GuardNoWakeSheet
   - "Wake in 210 minutes"
   - "Proceeding may reduce sleep before work"
   ↓
5. User enters reason: "Woke early, can't get back to sleep"
   Taps "Proceed anyway"
   ↓
6. onProceed() callback:
   tryLogDose2(
       at: 3:30 AM,
       source: "override_guard",
       override: Dose2Override(
           kind: .guard,
           minutes: 180 - 210 = -30  // (inside buffer by 30 min)
           reason: "Woke early, can't get back to sleep"
       )
   )
   ↓
7. DoseLog updated:
   dose2IsOverride = true
   dose2OverrideKind = "guard"
   dose2OverrideMinutes = -30
   dose2OverrideReason = "Woke early, can't get back to sleep"
   ↓
8. CSV Export includes audit trail for physician review
```

---

## CSV Export Example

```csv
night_date,dose1_time,dose2_time,dose2_is_override,dose2_override_kind,dose2_override_minutes,dose2_override_reason
2025-11-01,23:30,02:00,0,,,
2025-11-02,23:45,03:30,1,guard,-30,"Woke early, can't get back to sleep"
2025-11-03,23:20,01:55,1,early,5,"Forgot alarm earlier"
2025-11-04,23:50,05:15,1,late,35,"Alarm didn't go off"
```

**Physician Insights:**

- **Nov 2:** Patient overrode guard (woke 30 min into buffer). Reason: insomnia.
- **Nov 3:** Early override (5 min before window). Reason: user error.
- **Nov 4:** Late override (35 min after window). Reason: alarm failure.

**Pattern Recognition:** Repeated guard overrides = adjust wake time? Alarm failures = suggest stronger alarm style?

---

## User Experience

### Button States

**Dose 2 Button Caption (when guard active):**

```swift
// Before guard:
"Dose 2"  // Ready to log

// During guard:
"Guard: 1h 45m to wake (Workday)"  // Locked visual, still tappable
```

**Bell Chip Display:**

```swift
// Normal state:
🔔 Next: 02:00 (Soft)

// Guard active:
🔕 Guard @ 04:00 (dimmed bell icon)
```

### Notification Copy

**Window Open Alert:**

```
Title: Dose 2 Window Open
Body: 🔔 Soft-Wake: Dose 2 window is open. Tap to log now.
Actions: [Log Now] [Snooze 5m]
```

**Mid-Window Ping:**

```
Title: Dose 2 Reminder
Body: Window is open. Take Dose 2 when ready.
Actions: [Log Now] [Snooze 10m]
```

**Last Call:**

```
Title: Dose 2 Window Closing Soon
Body: Window closes in 10 minutes
Actions: [Log Now]
```

**Guard Cancel (Passive):**

```
Title: No-Wake Guard Active
Body: Dose 2 alarms cancelled: too close to morning wake
Actions: (none)
```

### Guard Sheet Copy

```
┌─────────────────────────────────────────┐
│  🌙                                     │
│                                         │
│  Hard no-wake is on                     │
│                                         │
│  It's too close to your wake time       │
│  for work                               │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ ⚠️ Wake in 105 minutes            │ │
│  │                                   │ │
│  │ Proceeding may reduce sleep       │ │
│  │ before work and hurt tomorrow's   │ │
│  │ schedule.                         │ │
│  └───────────────────────────────────┘ │
│                                         │
│  Reason (required to proceed)           │
│  ┌───────────────────────────────────┐ │
│  │ Why are you taking Dose 2 now?    │ │
│  │                                   │ │
│  │                                   │ │
│  └───────────────────────────────────┘ │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │      Proceed anyway               │ │ (Red)
│  └───────────────────────────────────┘ │
│                                         │
│  ┌─────┐  ┌─────┐  ┌─────┐            │
│  │Snooze│  │Snooze│  │Snooze│           │ (Blue)
│  │ 5m  │  │ 10m │  │ 15m │            │
│  └─────┘  └─────┘  └─────┘            │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │         Close                     │ │ (Gray)
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

---

## Testing Strategy

### Unit Tests

**Guard Logic:**
- [ ] Guard triggers at exactly buffer threshold (workday 180min)
- [ ] Guard triggers at exactly buffer threshold (offday 120min)
- [ ] Guard does NOT trigger at buffer + 1 min
- [ ] Guard disabled when plannedFinalWake is nil
- [ ] Guard respects isWorkday flag (correct buffer applied)
- [ ] Override minutes calculated correctly: `guardBuffer - minutesUntilWake`
- [ ] Override allowed when `allowGuardOverride = true`
- [ ] Override blocked when `allowGuardOverride = false`

**Alarm Scheduling:**
- [ ] Window open alert scheduled at `dose1 + windowStartMin`
- [ ] Last call scheduled at `dose1 + windowEndMin - 10min`
- [ ] Mid-ping scheduled only when `dose2MidPingEnabled = true`
- [ ] Cancel task scheduled at guard cutoff time
- [ ] All alarms cancelled when `scheduleDose2Alarms()` called with `style = .off`
- [ ] Interruption level = `.passive` during quiet hours (unless override)
- [ ] Interruption level = `.timeSensitive` when `breakQuietHoursForDose2 = true`
- [ ] Strong style uses `.defaultCritical` sound

**Notification Actions:**
- [ ] "Log Now" action triggers `logDose2(source: "notification")`
- [ ] "Snooze 5m" action reschedules alert +5 min, writes audit trail
- [ ] Snooze writes `notification_snoozed=1`, `snooze_minutes=5`
- [ ] Duplicate actions within 500ms deduped (conflict resolver)

### UI Tests

**Happy Path:**
- [ ] Log Dose 1 → Alarms scheduled → Bell chip shows "Next: 02:00 (Soft)"
- [ ] Window open notification appears at scheduled time
- [ ] Tap "Log Now" → Dose 2 logged, remaining alarms cancelled
- [ ] Bell chip updates to show no pending alerts

**Guard Path:**
- [ ] Approach guard cutoff → evaluateDose2Gate returns `.noWakeGuard`
- [ ] Tap Dose 2 button → GuardNoWakeSheet appears
- [ ] Sheet shows correct minutes until wake
- [ ] Proceed button disabled when reason empty
- [ ] Enter reason → Proceed button enabled
- [ ] Tap Proceed → Dose 2 logged with `override_kind="guard"`
- [ ] CSV export includes guard override with reason

**Settings:**
- [ ] Change alarm style → NotificationHelper uses new style
- [ ] Toggle "Break quiet hours" → Quiet hours respected/ignored
- [ ] Adjust guard buffers → Guard triggers at new thresholds
- [ ] Disable guard override → Proceed button hidden in sheet

### Edge Cases

- [ ] Guard cutoff exactly at midnight (date rollover)
- [ ] Guard cutoff during DST transition (spring forward/fall back)
- [ ] Multiple snoozes in sequence (audit trail shows all)
- [ ] User logs Dose 2 manually before window open alert → Alarms cancelled
- [ ] App backgrounded when guard trips → Cancel task still fires
- [ ] Notification permission denied → Fallback UI shown, alarms not scheduled

---

## Integration Points

### Item 6: Bell Chip

**Guard State Display:**

```swift
// In BellChip component:
if guardActive {
    HStack {
        Image(systemName: "moon.zzz.fill")
            .foregroundColor(.orange)
            .opacity(0.5)  // Dimmed
        Text("Guard @ \(guardCutoffTime.formatted(date: .omitted, time: .shortened))")
            .font(.caption)
    }
} else if let nextAlert = nextAlertTime {
    HStack {
        Image(systemName: "bell.fill")
        Text("Next: \(nextAlert.formatted(date: .omitted, time: .shortened)) (\(alarmStyle.displayName))")
            .font(.caption)
    }
}
```

### Item 7: Settings UI

**Alarms Section:**

```swift
Section("Alarms") {
    Picker("Dose 2 Alarm Style", selection: $prefs.dose2AlarmStyle) {
        ForEach(Dose2AlarmStyle.allCases, id: \.self) { style in
            Text(style.displayName).tag(style)
        }
    }
    
    Toggle("Break Quiet Hours for Dose 2", isOn: $prefs.breakQuietHoursForDose2)
    Toggle("Mid-Window Ping", isOn: $prefs.dose2MidPingEnabled)
    
    Section("No-Wake Guard") {
        Stepper("Workday Buffer: \(prefs.workdayNoWakeBufferMin) min", 
                value: $prefs.workdayNoWakeBufferMin, 
                in: 60...300, 
                step: 15)
        Stepper("Off-Day Buffer: \(prefs.offdayNoWakeBufferMin) min", 
                value: $prefs.offdayNoWakeBufferMin, 
                in: 60...240, 
                step: 15)
        Toggle("Allow Override", isOn: $prefs.allowGuardOverride)
    }
}
```

### Item 26: Notification Audit Trail

**Track Dose 2 Alarms:**

```swift
struct NotificationAudit {
    var id: UUID
    var notificationID: String       // "dose2_open_2025-11-01"
    var category: String             // "DOSE2_OPEN"
    var scheduledAt: Date
    var targetTime: Date
    var cancelledAt: Date?
    var cancelledReason: String?     // "guard_triggered", "dose2_logged", "user_cancelled"
    var snoozedCount: Int = 0
    var lastSnoozeAt: Date?
}
```

### Item 27: Notification Actions

**Wire to DoseLogController:**

```swift
extension UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case NotificationHelper.ActionID.logNow.identifier:
            controller.logDose2(at: Date(), source: "notification")
            
        case NotificationHelper.ActionID.snooze5.identifier:
            controller.snoozeDose2Alert(minutes: 5)
            
        case NotificationHelper.ActionID.snooze10.identifier:
            controller.snoozeDose2Alert(minutes: 10)
            
        // ...
        }
        completionHandler()
    }
}
```

---

## Files Created

| File | Status | Lines | Purpose |
|------|--------|-------|---------|
| `ios/Dose2Gate.swift` | ✅ Updated | ~150 | Added `.noWakeGuard` gate, `Dose2AlarmStyle` enum, enhanced `Dose2Policy` |
| `ios/GuardNoWakeSheet.swift` | ✅ Created | ~180 | Hard no-wake guard UI with override path |
| `ios/NotificationHelper.swift` | ✅ Created | ~300 | Centralized Dose 2 alarm scheduling, categories, actions |
| `ios/AppPreferencesEnhanced.swift` | ✅ Updated | ~40 added | Guard settings, alarm settings, style enum |

---

## Files Pending Update

| File | Update Required | Estimated Lines |
|------|-----------------|-----------------|
| `ios/NightCardViewModern.swift` | Wire `GuardNoWakeSheet` to Dose 2 button tap | ~50 |
| `ios/DoseLogController.swift` | Call `NotificationHelper.scheduleDose2Alarms()` on Dose 1 log | ~30 |
| `ios/DoseLogController.swift` | Implement `snoozeDose2Alert(minutes:)` | ~20 |
| `ios/TodayViewModel.swift` | Update `evaluateDose2Gate()` calls with new params | ~10 |
| `ios/SettingsViewEnhanced.swift` | Add Alarms section with guard controls | ~100 |
| `ios/DoseTrackApp.swift` | Register notification categories on launch | ~5 |

**Total Pending:** ~215 lines across 6 files

---

## Next Steps (Implementation Order)

### Phase 1: Core Integration (2-3h)

1. **Update NightCardViewModern.swift:**
   - Add `@State var showGuardSheet = false`
   - Wire Dose 2 button to check for `.noWakeGuard` gate
   - Present `GuardNoWakeSheet` when guard active
   - Pass `onProceed`, `onSnooze`, `onClose` callbacks

2. **Update DoseLogController.swift:**
   - Add `scheduleDose2AlarmsIfNeeded()` helper
   - Call from `logDose1(...)` after successful save
   - Calculate `guardCutoff` from `plannedFinalWake` and `isWorkday` profile
   - Pass to `NotificationHelper.scheduleDose2Alarms(...)`

3. **Update DoseTrackApp.swift:**
   - Call `NotificationHelper.registerNotificationCategories()` in `.onAppear`
   - Register `UNUserNotificationCenterDelegate` for action handling

### Phase 2: Action Wiring (1-2h)

4. **Implement Notification Delegate:**
   - Create `NotificationDelegate.swift` (or extend existing)
   - Wire `LOG_NOW` action → `controller.logDose2(source: "notification")`
   - Wire `SNOOZE_N` actions → `controller.snoozeDose2Alert(minutes: N)`
   - Update `NotificationAudit` with snooze tracking

5. **Update TodayViewModel.swift:**
   - Add `plannedFinalWake` and `isWorkday` to `evaluateDose2Gate()` calls
   - Pass from `WeeklyScheduleProfile` or `AppPreferences`

### Phase 3: Settings UI (1-2h)

6. **Update SettingsViewEnhanced.swift:**
   - Add "Alarms" section below "Night Plan"
   - Add Dose 2 alarm style picker (Off/Banner/Soft/Strong)
   - Add "Break Quiet Hours" toggle
   - Add "No-Wake Guard" subsection with buffer steppers
   - Add info (ⓘ) buttons with explanations

7. **Add Bell Chip Updates:**
   - Query `NotificationHelper.getNextDose2Alert()` for display
   - Show guard cutoff time when active
   - Dim bell icon during guard state

### Phase 4: Testing (1-2h)

8. **Unit Tests:**
   - Test guard gate evaluation (workday/offday buffers)
   - Test alarm scheduling logic (window open, mid, last call, cancel)
   - Test override minutes calculation
   - Test quiet hours logic

9. **UI Tests:**
   - Test guard sheet appears when within buffer
   - Test proceed requires reason
   - Test snooze reschedules alert
   - Test alarms cancelled when Dose 2 logged

10. **Integration Tests:**
    - Test notification action triggers controller
    - Test guard cancels pending alarms
    - Test CSV export includes guard overrides

---

## Success Criteria (DoD Verification)

### ✅ Completed (Foundation)

- [x] Dose2Gate.swift updated with `.noWakeGuard` gate
- [x] Dose2AlarmStyle enum created (Off/Banner/Soft/Strong)
- [x] Dose2Policy enhanced with guard buffer settings
- [x] Dose2Override.kind includes `.guard` case
- [x] GuardNoWakeSheet.swift created with full UI
- [x] NotificationHelper.swift created with scheduling logic
- [x] AppPreferencesEnhanced.swift updated with all settings
- [x] Notification categories defined (DOSE2_OPEN, MID, LASTCALL, GUARD)
- [x] Notification actions defined (LOG_NOW, SNOOZE_5, SNOOZE_10, SNOOZE_15)

### ⏳ Pending (Integration)

- [ ] NightCardViewModern wires guard sheet to Dose 2 button
- [ ] DoseLogController schedules alarms on Dose 1 log
- [ ] DoseLogController cancels alarms when guard trips
- [ ] Notification delegate wires actions to controller
- [ ] Settings UI includes Alarms section
- [ ] Bell chip shows next alert / guard cutoff
- [ ] TodayViewModel passes plannedFinalWake to gate evaluation
- [ ] Unit tests pass for guard logic
- [ ] UI tests pass for guard sheet flow
- [ ] CSV export includes guard override audit trail

### 🎯 Target Metrics

- Guard triggers correctly: ✅ **100%** of buffer threshold tests pass
- Alarm scheduling: ✅ **100%** of time calculations accurate
- Override audit: ✅ **100%** of guard overrides include reason + minutes
- Quiet hours: ✅ **95%+** respect quiet hours (unless override enabled)
- Strong style: ✅ Loops until acknowledged (manual test)
- Snooze: ✅ Reschedules correctly with audit trail

---

## Documentation Updates

### README.md - Key Features

Add to Smart Event Logging section:

```markdown
### Dose 2 Soft-Wake Alarms

- **Gentle Wake System:** Time-sensitive notifications at window start
- **Alarm Styles:** Off / Banner / Soft (default) / Strong (loops)
- **Mid-Window Ping:** Optional reminder at halfway point
- **Last Call Alert:** 10 minutes before window closes
- **Quiet Hours:** Respects quiet hours unless user opts to break them
- **Notification Actions:** "Log Now" and "Snooze N min" buttons

### Hard No-Wake Guard

- **Workday Protection:** 3-hour buffer before morning wake (default)
- **Off-Day Protection:** 2-hour buffer (default, configurable)
- **Smart Cancellation:** Automatically cancels Dose 2 alarms when too close to wake
- **Override Path:** Users can proceed with required reason for clinical audit
- **Guard Sheet:** Warning message, snooze options, or close
- **Audit Trail:** Captures override_kind="guard", minutes deviation, reason
```

### PRD_v1.2.md - Workflows

Add to Dose 2 section:

```markdown
**Soft-Wake Alarm System:**
- Schedule time-sensitive alerts when Dose 1 logged
- Window open alert at `dose1 + windowStartMin`
- Optional mid-window ping at halfway point
- Last call alert 10 minutes before window close
- Respects quiet hours (configurable override)
- Strong mode loops until user acknowledges

**Hard No-Wake Guard:**
- Calculate cutoff: `plannedFinalWake - buffer` (180min workday, 120min offday)
- Check guard FIRST in gate evaluation (before window math)
- Cancel pending Dose 2 alarms when guard trips
- Show contextual sheet: warning message, reason field, override option
- Proceed anyway requires reason, logs `override_kind="guard"`
- Snooze options: 5/10/15 minutes (reschedules guard check)
```

---

## Known Limitations

1. **Guard Cutoff Precision:** Uses minute-level granularity (not seconds)
2. **Notification Reliability:** Dependent on iOS delivering time-sensitive notifications
3. **Strong Style Loop:** Requires user interaction; no auto-dismiss after N repeats
4. **Snooze Limit:** No maximum snooze count (could be extended indefinitely)
5. **Timezone:** Guard cutoff recalculated when timezone changes (tested in Item 17)

---

## Future Enhancements (Post-v1.2)

1. **Smart Snooze:** Auto-calculate snooze duration based on time until window close
2. **Guard Learning:** Adjust buffer based on historical wake time variance
3. **Wake Prediction:** Use WHOOP/Health data to predict early wake, adjust guard
4. **Multi-Alert Chain:** Escalating alarm intensity (soft → medium → strong)
5. **Haptic Wake:** Gentle vibration pattern for silent wake option
6. **Guardian Mode:** Partner/caregiver remote alarm override via shared link

---

**Status:** Foundation 60% Complete | Integration Pending  
**Estimated Completion:** 2-3 hours (core integration) + 1-2 hours (testing)  
**Target:** Item 60 ✅ COMPLETE by end of Sprint 1, Week 1

---

**Files:**
- ✅ `ios/Dose2Gate.swift` (updated)
- ✅ `ios/GuardNoWakeSheet.swift` (created)
- ✅ `ios/NotificationHelper.swift` (created)
- ✅ `ios/AppPreferencesEnhanced.swift` (updated)
- ⏳ `ios/NightCardViewModern.swift` (pending)
- ⏳ `ios/DoseLogController.swift` (pending)
- ⏳ `ios/SettingsViewEnhanced.swift` (pending)
- ⏳ `ios/DoseTrackApp.swift` (pending)

**Total Lines:** ~670 created, ~215 pending (885 total)
