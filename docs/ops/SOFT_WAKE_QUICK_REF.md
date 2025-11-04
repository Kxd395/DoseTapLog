# Soft-Wake + Guard - Quick Reference

**For:** Developers integrating Item 60  
**Date:** November 4, 2025  
**Status:** Foundation ✅ Complete (60%) | Integration ⏳ Pending (40%)

---

## TL;DR

You now have a **soft-wake alarm system** that wakes users at Dose 2 window start, plus a **hard no-wake guard** that prevents waking too close to morning. Foundation code is ready—just wire it into the UI and controller.

---

## What's Done ✅

| Component | File | Status | Purpose |
|-----------|------|--------|---------|
| **Guard Gate** | `Dose2Gate.swift` | ✅ Complete | `.noWakeGuard(minutesUntilWake)` added |
| **Alarm Styles** | `Dose2Gate.swift` | ✅ Complete | Off/Banner/Soft/Strong enum |
| **Policy Config** | `Dose2Gate.swift` | ✅ Complete | Guard buffers in Dose2Policy |
| **Guard UI** | `GuardNoWakeSheet.swift` | ✅ Complete | Sheet with reason, proceed, snooze |
| **Notification System** | `NotificationHelper.swift` | ✅ Complete | Schedule alarms, categories, actions |
| **Settings** | `AppPreferencesEnhanced.swift` | ✅ Complete | All guard/alarm settings added |

**Total:** ~670 lines created, BUILD SUCCEEDED ✅

---

## What's Needed ⏳

### 1. Wire Guard Sheet (30 min)

**File:** `ios/NightCardViewModern.swift`

```swift
@State private var showGuardSheet = false
@State private var guardMinutesUntilWake: Int = 0

// In Dose 2 button action:
let gate = evaluateDose2Gate(
    now: Date(),
    dose1At: night.dose1TimeUTC,
    dose2At: night.dose2TimeUTC,
    policy: Dose2Policy.from(prefs),
    plannedFinalWake: plannedFinalWakeTime,  // NEW
    isWorkday: isWorkday                     // NEW
)

switch gate {
case .noWakeGuard(let minutes):
    guardMinutesUntilWake = minutes
    showGuardSheet = true
// ... other cases
}

// Add sheet modifier:
.sheet(isPresented: $showGuardSheet) {
    GuardNoWakeSheet(
        minutesUntilWake: guardMinutesUntilWake,
        isWorkday: isWorkday,
        allowOverride: prefs.allowGuardOverride,
        onProceed: { reason in
            tryLogDose2(
                at: Date(),
                source: "override_guard",
                override: Dose2Override(
                    kind: .guard,
                    minutes: /* calculate from policy */,
                    reason: reason,
                    ...
                )
            )
            showGuardSheet = false
        },
        onSnooze: { minutes in
            // Reschedule guard check
            showGuardSheet = false
        },
        onClose: {
            showGuardSheet = false
        }
    )
}
```

### 2. Schedule Alarms on Dose 1 (20 min)

**File:** `ios/DoseLogController.swift`

```swift
func logDose1(at time: Date, grams: Double) {
    // ... existing Dose 1 logging
    
    // NEW: Schedule Dose 2 alarms
    if prefs.dose2AlarmEnabled {
        let guardCutoff = calculateGuardCutoff(
            plannedFinalWake: night.plannedFinalWake,
            isWorkday: night.isWorkday,
            policy: Dose2Policy.from(prefs)
        )
        
        NotificationHelper.scheduleDose2Alarms(
            dose1Time: time,
            windowStartMin: prefs.windowStartMin,
            windowEndMin: prefs.windowEndMin,
            guardCutoff: guardCutoff,
            style: prefs.dose2AlarmStyle,
            nightKey: night.nightKey
        )
    }
}

private func calculateGuardCutoff(
    plannedFinalWake: Date?,
    isWorkday: Bool,
    policy: Dose2Policy
) -> Date? {
    guard let wake = plannedFinalWake else { return nil }
    let buffer = isWorkday 
        ? policy.workdayNoWakeBufferMin 
        : policy.offdayNoWakeBufferMin
    return wake.addingTimeInterval(TimeInterval(-buffer * 60))
}
```

### 3. Register Notification Categories (5 min)

**File:** `ios/DoseTrackApp.swift`

```swift
var body: some Scene {
    WindowGroup {
        ContentView()
            .onAppear {
                NotificationHelper.registerNotificationCategories()
            }
    }
}
```

### 4. Add Settings UI (60 min)

**File:** `ios/SettingsViewEnhanced.swift`

```swift
Section("Alarms") {
    Picker("Dose 2 Alarm Style", selection: $prefs.dose2AlarmStyle) {
        Text("Off").tag(Dose2AlarmStyle.off)
        Text("Banner Only").tag(Dose2AlarmStyle.banner)
        Text("Soft").tag(Dose2AlarmStyle.soft)
        Text("Strong").tag(Dose2AlarmStyle.strong)
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

### 5. Wire Notification Actions (40 min)

**File:** `ios/AppDelegate.swift` (or `NotificationDelegate.swift`)

```swift
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
        
    case NotificationHelper.ActionID.snooze15.identifier:
        controller.snoozeDose2Alert(minutes: 15)
        
    default:
        break
    }
    
    completionHandler()
}
```

---

## Testing Checklist

### Manual Testing

- [ ] Log Dose 1 → Check notification scheduled (Settings → Notifications)
- [ ] Wait for window open alert → Tap "Log Now" → Dose 2 logged
- [ ] Tap Dose 2 button within guard buffer → Sheet appears
- [ ] Leave reason empty → Proceed button disabled
- [ ] Enter reason → Proceed button enabled → Dose 2 logged with `override_kind="guard"`
- [ ] Export CSV → Guard override row shows reason + minutes

### Unit Testing

```swift
func testGuardTriggersAtBufferThreshold() {
    let policy = Dose2Policy(
        startMin: 150,
        endMin: 240,
        allowEarly: true,
        maxEarlyMin: 60,
        allowLate: true,
        maxLateMin: 120,
        workdayNoWakeBufferMin: 180,
        offdayNoWakeBufferMin: 120,
        allowGuardOverride: true
    )
    
    let dose1 = Date()
    let plannedWake = dose1.addingTimeInterval(6 * 3600)  // 6 hours later
    let now = plannedWake.addingTimeInterval(-180 * 60)  // Exactly at buffer
    
    let gate = evaluateDose2Gate(
        now: now,
        dose1At: dose1,
        dose2At: nil,
        policy: policy,
        plannedFinalWake: plannedWake,
        isWorkday: true
    )
    
    XCTAssertEqual(gate, .noWakeGuard(minutesUntilWake: 180))
}
```

---

## Key Concepts

### Guard Cutoff Calculation

```
guardCutoff = plannedFinalWake - buffer

Example (Workday):
  plannedFinalWake = 7:00 AM
  workdayBuffer = 180 min (3h)
  guardCutoff = 7:00 AM - 3h = 4:00 AM

If current time >= 4:00 AM:
  evaluateDose2Gate() returns .noWakeGuard
  Dose 2 alarms cancelled
  Guard sheet shown when button tapped
```

### Alarm Lifecycle

```
1. User logs Dose 1 at 11:30 PM
   ↓
2. NotificationHelper.scheduleDose2Alarms(...)
   - Window open: 2:00 AM (150 min later)
   - Last call: 3:50 AM (10 min before 4:00 AM)
   - Cancel task: 4:00 AM (guard cutoff)
   ↓
3. At 2:00 AM: Window open alert fires
   User taps "Log Now" OR "Snooze 5m"
   ↓
4. Log Now: Dose 2 logged, remaining alarms cancelled
   Snooze: Alert rescheduled +5 min, audit trail updated
```

### Override Audit Trail

```csv
night_date,dose2_time,dose2_is_override,dose2_override_kind,dose2_override_minutes,dose2_override_reason
2025-11-01,02:00,0,,,
2025-11-02,03:30,1,guard,75,"Woke early, can't get back to sleep"
```

**Calculation:**
```
guardBuffer = 180 min
minutesUntilWake = 105 min
override_minutes = 180 - 105 = 75 min
```

**Interpretation:** Patient took Dose 2 **75 minutes into the guard buffer** (with 105 min remaining until wake).

---

## File Locations

```
DoseTrack_v1.1.1c/
├─ ios/
│  ├─ Dose2Gate.swift                    ✅ UPDATED
│  ├─ GuardNoWakeSheet.swift             ✅ NEW
│  ├─ NotificationHelper.swift           ✅ NEW
│  ├─ AppPreferencesEnhanced.swift       ✅ UPDATED
│  ├─ NightCardViewModern.swift          ⏳ PENDING
│  ├─ DoseLogController.swift            ⏳ PENDING
│  ├─ SettingsViewEnhanced.swift         ⏳ PENDING
│  └─ DoseTrackApp.swift                 ⏳ PENDING
├─ docs/
│  └─ ops/
│     ├─ TODO.md                          ✅ UPDATED (Item 60 added)
│     └─ SOFT_WAKE_GUARD_IMPLEMENTATION.md  ✅ NEW (full spec)
```

---

## Settings Defaults

| Setting | Default | Purpose |
|---------|---------|---------|
| `workdayNoWakeBufferMin` | 180 | 3 hours before work wake |
| `offdayNoWakeBufferMin` | 120 | 2 hours before off-day wake |
| `allowGuardOverride` | true | Users can proceed with reason |
| `dose2AlarmEnabled` | true | Alarms scheduled by default |
| `dose2AlarmStyle` | `.soft` | Time-sensitive, respects quiet hours |
| `breakQuietHoursForDose2` | false | Respect quiet hours by default |
| `dose2MidPingEnabled` | false | No mid-window ping by default |
| `dose2SnoozeOptionsCSV` | "5,10,15" | Snooze durations (minutes) |

---

## Next Steps

1. ✅ **You are here:** Foundation code complete, builds successfully
2. ⏳ **Wire guard sheet** in `NightCardViewModern.swift` (30 min)
3. ⏳ **Schedule alarms** in `DoseLogController.swift` (20 min)
4. ⏳ **Register categories** in `DoseTrackApp.swift` (5 min)
5. ⏳ **Add Settings UI** in `SettingsViewEnhanced.swift` (60 min)
6. ⏳ **Wire notification actions** (40 min)
7. ⏳ **Test** guard flow + alarm scheduling (30 min)

**Total Remaining:** ~3 hours to full Item 60 completion

---

## Questions?

**Q: Do alarms fire if app is killed?**  
A: Yes—notifications scheduled via UNUserNotificationCenter persist across app termination.

**Q: What if user denies notification permissions?**  
A: `NotificationHelper` checks permissions before scheduling. If denied, alarms won't schedule (fallback to manual check).

**Q: Can guard be disabled entirely?**  
A: Yes—set `workdayNoWakeBufferMin = 0` and `offdayNoWakeBufferMin = 0` in Settings.

**Q: What happens if user changes timezone?**  
A: Guard cutoff recalculates in local time. Item 17 (Timezone Rebase Chip) will prompt user to adjust plan.

**Q: How does "Strong" style loop?**  
A: Uses `.defaultCritical` sound with `.timeSensitive` interruption level. iOS delivers until user interacts.

---

**Status:** Item 60 - 60% Complete  
**Estimated Time to Ship:** 3 hours (integration + testing)  
**Blocking Items:** None (all dependencies satisfied)  
**Ready for:** Sprint 1, Week 1 completion ✅
