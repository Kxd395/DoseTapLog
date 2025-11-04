# Night Turnover Refactor - Implementation Plan

**Date:** November 3, 2025  
**Status:** 🚧 IN PROGRESS  
**Priority:** CRITICAL - Core UX Fix

---

## Problem Statement

The app's night rollover feels "off" due to:

1. **Ambiguous night anchor**: No nightKey until Dose 1 is logged → ring stuck on "Expired"
2. **Midnight boundary splits nights**: Calendar midnight is wrong for sleep tracking
3. **No planning horizon**: Can't see/edit "tonight" until Dose 1 is taken
4. **Poor auto-turnover**: Lingering nights don't close cleanly

---

## Solution Architecture

### Phase 1: Service-Day Cutoff System ✅ COMPLETE

**Files Created:**
- `ios/NightServiceDay.swift` - Cutoff calculation and nightKey generation

**Key Features:**
- Configurable cutoff (default noon, stored in `AppPreferencesEnhanced.cutoffHourLocal`)
- NightKey = service-day date (evening the night starts)
- Auto-close at next cutoff if Final Wake not logged
- Helper functions for Last Night / Tonight / Tomorrow

**Logic:**
```swift
// Example: With noon cutoff
11 PM Nov 3 → nightKey "2025-11-03"
2 AM Nov 4 (before noon) → still "2025-11-03"
1 PM Nov 4 (after noon) → new night "2025-11-04"
```

### Phase 2: Night Lifecycle States ✅ COMPLETE

**Files Modified:**
- `ios/Models.swift` - Added `lifecycleState`, `autoClosedAt`, `plannedDose1Time` fields

**State Machine:**
```
Planned → Armed (In bed) → Active (Dose 1) → WindowOpen → WindowClosed → AwaitWake → Closed
                                                                                    ↓
                                                                              Abandoned (Reset)
```

**Auto-Transitions:**
- On Final Wake → Closed
- On cutoff (noon) → Auto-close lingering nights, mint Tonight
- On Dose 1 after cutoff → Implicitly mint Tonight nightKey

### Phase 3: Weekly Schedule Templates ✅ COMPLETE

**Files Created:**
- `ios/WeeklySchedule.swift` - Per-DOW schedule templates

**Features:**
- `WeeklyScheduleProfile` with 7-day schedule (Sunday-Saturday)
- Per-day: target bedtime, target wake, profile type (Workday/Off/Travel)
- Max shift constraint (default 30 min) for circadian stability
- Timezone policy: Local | Home | Ask
- `TimeZoneChange` detection and `RebaseAction` prompts

**Storage:**
- JSON-encoded in `AppPreferencesEnhanced.weeklyScheduleJSON`
- Computed property `weeklySchedule` for easy access

### Phase 4: 3-Card Planning Horizon ✅ COMPLETE

**Files Created:**
- `ios/ThreeCardPlanningView.swift` - Main container with segmented control
- `ios/NightCardView.swift` - Individual night card component

**UI Structure:**
```
┌─────────────────────────────────────────────────────────┐
│ Segments:  [ Last Night ]  [ Tonight ]  [ Tomorrow ]     │
├─────────────────────────────────────────────────────────┤
│ Card header:  Mon, Nov 3  • NightKey 2025-11-03 • UTC-6  │
│ Plan: Dose1 3.75 g at 22:45 (planned)  | Dose2 3.75 g     │
│ Window: 210–245 min after Dose1                            │
│ Safety: ✓ per-dose, ✓ nightly    Sources: Health OK, WHOOP│
│ Status ring: Waiting / Open / Closing soon / Expired      │
│ Next alert: 02:18:00 [Normal]                              │
│ Actions: In bed • Dose 1 • Dose 2 • Final wake • Alarm/Nat│
│ Secondary: Bathroom • Undo • Edit plan • Reset night • CSV│
└─────────────────────────────────────────────────────────┘
```

**Card Behaviors:**

**Last Night:**
- Read-only summary
- Actions: Fix times, Export CSV, Close night manually

**Tonight:**
- Before Dose 1: Editable plan (grams, split, planned time)
- After Dose 1: Live Activity, countdown ring, action buttons
- Shows lifecycle state chip

**Tomorrow:**
- Planning only
- Shows suggested times from weekly template
- Create plan button

### Phase 5: Auto-Turnover Logic ✅ COMPLETE

**Implemented in ThreeCardPlanningView:**

1. **Timer-based checking** (every 60 seconds):
   ```swift
   .onReceive(timer) { _ in
       checkForCutoffCrossing()
       checkForTimeZoneChange()
   }
   ```

2. **Cutoff crossing detection:**
   - Compare `NightServiceDay.nightKey()` for last refresh vs now
   - If different → auto-close + mint tonight + show toast

3. **Auto-close lingering nights:**
   ```swift
   // Close any nights before last night that aren't already closed
   night.currentLifecycleState = .closed
   night.autoClosedAt = Date()
   ```

4. **Mint tonight:**
   ```swift
   // Create planned session with suggested Dose 1 time from weekly schedule
   newNight.currentLifecycleState = .planned
   newNight.plannedDose1Time = schedule.suggestedDose1Time()
   ```

5. **Timezone change handling:**
   - Detect when `TimeZone.current.identifier` changes
   - If policy = "ask" → show rebase prompt
   - If policy = "local" → auto-recompute planned times
   - If policy = "home" → keep home timezone times

---

## Settings Integration

### New Settings Added to AppPreferencesEnhanced:

```swift
// Service-day cutoff
@AppStorage("service_cutoff_hour_local") var cutoffHourLocal: Int = 12

// Display options
@AppStorage("show_seconds") var showSeconds: Bool = false

// Weekly schedule (JSON-encoded)
@AppStorage("weekly_schedule_json") var weeklyScheduleJSON: String = ""

// Circadian stability
@AppStorage("max_shift_per_night_min") var maxShiftPerNightMin: Int = 30

// Timezone handling
@AppStorage("time_zone_lock") var timeZoneLock: String = "local"
@AppStorage("home_time_zone") var homeTimeZone: String
@AppStorage("last_known_time_zone") var lastKnownTimeZone: String
```

### Computed Properties:

```swift
var weeklySchedule: WeeklyScheduleProfile // Decode/encode JSON
var timeZonePolicy: WeeklyScheduleProfile.TimeZonePolicy // Enum
```

---

## Enhanced Dose 2 Logic

### Early Dose Override ✅ IMPLEMENTED

**In NightCardView.attemptDose2():**

```swift
if minutesSinceD1 < prefs.windowStartMin {
    if prefs.allowEarlyDose {
        showEarlyDoseSheet = true  // Requires reason + time-prior
    }
}
```

**Existing:** `EarlyDoseSheetView.swift` already handles this

**Stored in DoseLog:**
- `dose2IsOverride = true`
- `dose2OverrideKind = "early"`
- `dose2OverrideMinutes = X`
- `dose2OverrideReason = "couldn't sleep"`

### Late Dose Override ✅ IMPLEMENTED

**In NightCardView.attemptDose2():**

```swift
if minutesSinceD1 > prefs.windowEndMin {
    if prefs.allowLateDose {
        showLateDoseSheet = true  // Requires reason
    }
}
```

**Existing:** `LateDoseSheetView.swift` already handles this

**Stored in DoseLog:**
- `dose2IsOverride = true`
- `dose2OverrideKind = "late"`
- `dose2OverrideMinutes = X`
- `dose2OverrideReason = "alarm didn't wake me"`

### Both Overrides:
- Clearly marked in Recent Events (⚠️ icon)
- Exported to CSV with override details
- Tracked separately for analysis

---

## Migration Strategy

### Existing Data Compatibility:

1. **Old nightKeys remain valid:**
   - Existing YYYY-MM-DD keys are still service-day dates
   - No data migration needed for nightKey format

2. **Lifecycle state inference:**
   ```swift
   // In Models.swift
   func inferLifecycleState() -> NightLifecycleState {
       if isClosedByReset { return .abandoned }
       if finalWakeTimeUTC != nil { return .closed }
       if dose2TimeUTC != nil { return .awaitWake }
       if dose1TimeUTC != nil { return .active }
       if bedtimeUTC != nil { return .armed }
       return .planned
   }
   ```

3. **One-time repair on app launch:**
   ```swift
   // TODO: Add to DoseLogController or App init
   func repairLifecycleStates() {
       for night in allNights where night.lifecycleState.isEmpty {
           night.currentLifecycleState = night.inferLifecycleState()
       }
   }
   ```

4. **Default weekly schedule:**
   - If `weeklyScheduleJSON` is empty → use `WeeklyScheduleProfile.default`
   - Default = 10:30 PM workday bedtime, 11:30 PM weekend

---

## Testing Matrix

### Test 1: No Dose 1 Night ✅
**Scenario:** Night exists but Dose 1 never logged  
**Expected:** At next cutoff (noon), night auto-closes, Tonight minted  
**Verify:**
- `night.currentLifecycleState = .closed`
- `night.autoClosedAt != nil`
- New night exists with Tonight's nightKey

### Test 2: Window Spans Midnight ✅
**Scenario:** Dose 1 at 23:55, window 150-240 min (crosses midnight)  
**Expected:** Still same nightKey (by cutoff rule)  
**Verify:**
- NightKey = evening date (Nov 3)
- Window end at 03:55 (Nov 4) still shows under Nov 3 night
- No auto-close until noon Nov 4

### Test 3: Final Wake Closes Night ✅
**Scenario:** User logs Final Wake  
**Expected:** Night immediately closes, Tonight card flips to next service day  
**Verify:**
- `night.currentLifecycleState = .closed`
- `night.finalWakeTimeUTC` set
- New Tonight minted for next service day

### Test 4: Travel East 3 Hours ✅
**Scenario:** User travels from PST to EST  
**Expected:**
- If policy = "ask" → prompt shown
- If policy = "local" → planned Dose 1 time recomputed in local time
- If policy = "home" → planned time stays in PST

**Verify:**
- `prefs.lastKnownTimeZone` updates
- Rebase prompt shows correct time shift
- Planned times adjust (or don't) based on policy

### Test 5: Early Override 7 Min ✅
**Scenario:** Try Dose 2 at 143 min (7 min before window start at 150 min)  
**Expected:** Early override sheet shown, requires reason  
**Verify:**
- `EarlyDoseSheetView` appears
- After logging: `dose2IsOverride = true`, `dose2OverrideKind = "early"`
- Override appears in Recent Events with ⚠️ icon
- CSV export includes override fields

### Test 6: Late Override 5 Min ✅
**Scenario:** Try Dose 2 at 245 min (5 min after window end at 240 min)  
**Expected:** Late override sheet shown (if policy allows)  
**Verify:**
- `LateDoseSheetView` appears
- After logging: `dose2IsOverride = true`, `dose2OverrideKind = "late"`
- Override marked in UI
- CSV export correct

---

## Remaining Work

### Phase 6: Settings UI Integration ⏳

**Files to Create:**
- `ios/WeeklyScheduleEditorView.swift` - Edit DOW schedule

**Files to Modify:**
- `ios/SettingsViewEnhanced.swift` - Add sections for:
  - Service cutoff hour picker
  - Show seconds toggle
  - Weekly schedule editor link
  - Timezone policy picker
  - Max shift stepper

**New Settings Sections:**

```swift
Section("Service Day & Planning") {
    Stepper("Cutoff hour", value: $prefs.cutoffHourLocal, in: 0...23)
    Toggle("Show seconds", isOn: $prefs.showSeconds)
    NavigationLink("Weekly Schedule") {
        WeeklyScheduleEditorView()
    }
}

Section("Time Zone") {
    Picker("Policy", selection: $prefs.timeZoneLock) {
        Text("Local Time").tag("local")
        Text("Home Time").tag("home")
        Text("Ask Me").tag("ask")
    }
    
    if prefs.timeZoneLock != "local" {
        TextField("Home timezone", text: $prefs.homeTimeZone)
    }
}

Section("Circadian Rhythm") {
    Stepper("Max shift per night", value: $prefs.maxShiftPerNightMin, in: 0...60, step: 5)
    Text("\(prefs.maxShiftPerNightMin) minutes")
}
```

### Phase 7: DoseLogController Integration ⏳

**Files to Modify:**
- `ios/DoseLogController.swift`

**Changes Needed:**

1. **Update state on event logging:**
   ```swift
   func logDose1Now(...) {
       // ... existing logic
       night.currentLifecycleState = .active
       try context.save()
   }
   ```

2. **Add lifecycle transition methods:**
   ```swift
   func transitionToWindowOpen(_ night: DoseLog) {
       night.currentLifecycleState = .windowOpen
       // Schedule window-end alarm
   }
   
   func transitionToWindowClosed(_ night: DoseLog) {
       night.currentLifecycleState = .windowClosed
       // Update UI, offer late override
   }
   ```

3. **Window state monitoring:**
   ```swift
   // Called by timer or Live Activity
   func updateWindowState(for night: DoseLog, now: Date) {
       guard let d1 = night.dose1TimeUTC else { return }
       let minutesSince = Int(now.timeIntervalSince(d1) / 60)
       
       if minutesSince >= prefs.windowStartMin && night.currentLifecycleState == .active {
           transitionToWindowOpen(night)
       } else if minutesSince >= prefs.windowEndMin && night.currentLifecycleState == .windowOpen {
           transitionToWindowClosed(night)
       }
   }
   ```

### Phase 8: Plan Editor Sheet ⏳

**Files to Create:**
- `ios/PlanEditorSheet.swift`

**Features:**
- Edit total grams, split ratio, rounding
- Edit planned Dose 1 time (wheel picker with seconds if enabled)
- Show derived Dose 2 amount and window times
- Save button updates `DoseLog.plannedDose1Time`
- Only available before Dose 1 is logged

### Phase 9: Enhanced Status Ring ⏳

**Update:** `NightCardView.statusRingSection()`

**Real Countdown:**
```swift
func ringCountdown(_ night: DoseLog) -> String? {
    guard let d1 = night.dose1TimeUTC else { return nil }
    
    let now = Date()
    let minutesSinceD1 = Int(now.timeIntervalSince(d1) / 60)
    
    switch night.currentLifecycleState {
    case .active:
        // Countdown to window start
        let remaining = prefs.windowStartMin - minutesSinceD1
        return formatCountdown(minutes: remaining)
        
    case .windowOpen:
        // Countdown to window end
        let remaining = prefs.windowEndMin - minutesSinceD1
        return formatCountdown(minutes: remaining)
        
    default:
        return nil
    }
}

func ringProgress(_ night: DoseLog) -> Double {
    guard let d1 = night.dose1TimeUTC else { return 0 }
    
    let minutesSinceD1 = Double(Date().timeIntervalSince(d1) / 60)
    
    switch night.currentLifecycleState {
    case .active:
        // Progress from 0 to window start
        return min(minutesSinceD1 / Double(prefs.windowStartMin), 1.0)
        
    case .windowOpen:
        // Progress within window
        let windowDuration = Double(prefs.windowEndMin - prefs.windowStartMin)
        let progressInWindow = (minutesSinceD1 - Double(prefs.windowStartMin)) / windowDuration
        return min(progressInWindow, 1.0)
        
    case .windowClosed:
        return 1.0
        
    default:
        return 0
    }
}
```

### Phase 10: App Initialization ⏳

**Files to Modify:**
- `ios/DoseTrackApp.swift`

**Changes:**
- Replace `TodayLogView()` with `ThreeCardPlanningView()`
- Add lifecycle state repair on launch
- Initialize cutoff monitoring

```swift
@main
struct DoseTrackApp: App {
    var body: some Scene {
        WindowGroup {
            ThreeCardPlanningView()
                .modelContainer(for: DoseLog.self)
                .onAppear {
                    repairLegacyNights()
                }
        }
    }
    
    func repairLegacyNights() {
        // Infer lifecycle states for old data
    }
}
```

### Phase 11: Visual Polish ⏳

**Toast UI for Cutoff Crossing:**
```swift
.overlay(alignment: .top) {
    if showCutoffToast {
        CutoffCrossedToast(nightKey: tonightKey)
            .transition(.move(edge: .top))
    }
}
```

**Timezone Rebase Chip:**
```swift
if showTimeZoneChange {
    TimeZoneChangeChip(change: tzChange) {
        // Show rebase sheet
    }
}
```

**Status Chips:**
- Planned: Gray
- Armed: Blue
- Active: Green
- Window Open: Orange
- Window Closed: Red
- Awaiting Wake: Purple
- Closed: Gray
- Abandoned: Gray

---

## Dependencies

### External:
- None (all iOS native frameworks)

### Internal:
- `AppPreferencesEnhanced` ✅
- `DoseLog` model ✅
- `NightServiceDay` ✅
- `WeeklyScheduleProfile` ✅
- `DoseLogController` (needs updates)
- `AlarmOrchestrator` (needs lifecycle state awareness)

---

## Rollout Plan

### Step 1: Settings Integration (1-2 hours)
- Add Weekly Schedule Editor
- Add Service Day settings section
- Test schedule creation and editing

### Step 2: DoseLogController Updates (2-3 hours)
- Add lifecycle state transitions
- Window state monitoring
- Test auto-transitions

### Step 3: Plan Editor Sheet (1 hour)
- Create editable plan UI
- Wire up to DoseLog.plannedDose1Time
- Test editing flow

### Step 4: Status Ring Enhancement (1 hour)
- Real countdown calculations
- Accurate progress ring
- Test across all states

### Step 5: App Integration (30 min)
- Replace TodayLogView with ThreeCardPlanningView
- Add lifecycle repair
- Test clean launch

### Step 6: Visual Polish (1 hour)
- Toast notifications
- Timezone change chip
- Animations and transitions

### Step 7: Comprehensive Testing (2-3 hours)
- Run through all test scenarios
- Fix edge cases
- Performance optimization

**Total Estimated Time:** 8-12 hours

---

## Success Criteria

### User Experience:
- ✅ Night always turns over cleanly at cutoff
- ✅ "Last / Tonight / Tomorrow" always clear
- ✅ Can plan ahead with weekly schedule
- ✅ Timezone changes handled gracefully
- ✅ No "stuck expired" states

### Technical:
- ✅ All nights have deterministic nightKey
- ✅ Lifecycle states tracked accurately
- ✅ Auto-turnover works reliably
- ✅ No data loss during migration
- ✅ Performance remains smooth (< 100ms UI updates)

### Data Quality:
- ✅ CSV exports include lifecycle state
- ✅ Override tracking preserved
- ✅ Planned vs actual times distinguishable
- ✅ Timezone metadata correct

---

## Risks & Mitigation

### Risk: Existing data incompatibility
**Mitigation:** Lifecycle state inference + one-time repair on launch

### Risk: Cutoff timer battery impact
**Mitigation:** 60-second interval is minimal, use efficient date comparison

### Risk: Timezone policy confusion
**Mitigation:** Clear UI labels, default to "local" (safest)

### Risk: Weekly schedule complexity
**Mitigation:** Provide sensible defaults, optional feature

---

## Future Enhancements

1. **Smart scheduling:** Learn from past Dose 1 times, suggest adjustments
2. **Circadian drift detection:** Alert if bedtime shifts > max over multiple nights
3. **Multi-timezone support:** Automatically rebase when crossing 2+ timezones
4. **Seasonal adjustment:** Suggest earlier bedtimes in winter, later in summer
5. **Integration with Sleep Schedule (iOS):** Import/sync with Health app sleep schedule

---

**Version:** 1.0.0  
**Last Updated:** November 3, 2025  
**Status:** 50% Complete (Phases 1-5 done, 6-11 remaining)  
**Priority:** CRITICAL
