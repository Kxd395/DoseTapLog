# Complete Settings & UI Components Implementation

**📍 Location:** `docs/ops/COMPLETE_UI_COMPONENTS.md`  
**📚 Breadcrumbs:** `docs/` → `ops/` → **`COMPLETE_UI_COMPONENTS.md`**

**🔗 Related Documentation:**
- Specification: `.specify/memory/spec.md` (UI Component Specifications section)
- Settings SSOT: `ios/AppPreferences.swift`
- Product Description: `docs/PRODUCT_DESCRIPTION.md`
- Logic Flow: `docs/design/DOSE2_LOGIC_FLOW.md`

---

**Date:** November 2, 2025  
**Project:** DoseTrack v1.1.1c  
**Status:** ✅ COMPONENTS READY FOR INTEGRATION

---

## Overview

Complete suite of drop-in SwiftUI components addressing the critical gaps identified in the hyper-critical review:

1. ✅ **AppPreferences.swift** - SSOT for all user settings (@AppStorage)
2. ✅ **CountdownRingView.swift** - Live timer with window status
3. ✅ **EventStripView.swift** - Last 3 events with undo capability
4. ✅ **SafetyBannerView.swift** - Always-visible status chips
5. ✅ **EarlyDoseSheetView.swift** - Early dose confirmation modal

---

## Component Details

### 1. AppPreferences.swift

**File:** `ios/AppPreferences.swift`  
**Lines:** 234  
**Purpose:** Single source of truth for all user settings

**Architecture:**
```swift
@Observable final class AppPreferences {
    // 30+ @AppStorage properties
    // Singleton: AppPreferences.shared
    // Helper methods: calculateDoses(), planViolatesSafety, resetToDefaults()
}
```

**Settings Categories:**

#### Night Plan Defaults (6 settings)
```swift
totalNightGrams: Double = 6.5
splitStrategy: String = "50-50"           // "50-50", "60-40", "40-60", "Custom"
roundingIncrement: Double = 0.25          // 0.25g or 0.5g
windowStartMin: Int = 150
windowEndMin: Int = 240
allowTonightEdit: Bool = true
```

#### Early Dose 2 Policy (4 settings)
```swift
allowEarlyDose: Bool = false
maxEarlyMinutes: Int = 15
earlyRequireReason: Bool = true
earlyTimePriorDefaults: String = "5,10"   // Comma-separated
```

#### Notifications & Live Activity (7 settings)
```swift
liveActivityEnabled: Bool = true
notifyWindowStart: Bool = true
notifyHalfway: Bool = false
notifyWindowEnd: Bool = true
quietHoursStart: String? = nil
quietHoursEnd: String? = nil
hapticsEnabled: Bool = true
```

#### Data Sources (4 settings)
```swift
healthSampleWindowMin: Int = 60
whoopProxyURL: String = ""
whoopAPIKey: String = ""
wakeSourcePreference: String = "Health"   // "Health" or "Manual"
```

#### Exports (5 settings)
```swift
exportIncludeTimezone: Bool = true
exportFilenamePattern: String = "DoseTrack_yyyyMMdd.csv"
exportIncludeNotes: Bool = true
exportIncludeEventLog: Bool = false
exportDefaultEmail: String = ""
```

#### Privacy & Retention (3 settings)
```swift
requireBiometric: Bool = false
maskWidgetDoses: Bool = true
retentionDays: Int = 365
```

#### Debug (1 setting)
```swift
showInternals: Bool = false
```

**Computed Properties:**
- `earlyTimePriorOptions: [Int]` - Parses comma-separated string
- `calculateDoses() -> (dose1: Double, dose2: Double)` - Applies split strategy and rounding
- `planViolatesSafety: Bool` - Validates against guardrails (1.5-4.5g per dose, 3.0-9.0g nightly)

**Usage:**
```swift
let prefs = AppPreferences.shared
let (dose1, dose2) = prefs.calculateDoses()
let windowStart = prefs.windowStartMin
```

---

### 2. CountdownRingView.swift

**File:** `ios/CountdownRingView.swift`  
**Lines:** 178  
**Purpose:** Circular progress indicator with context-aware status text

**Props:**
```swift
struct CountdownRingView: View {
    let dose1Time: Date?
    let windowStartMin: Int
    let windowEndMin: Int
    let disabledReason: String
}
```

**Visual Design:**
```
┌─────────────────────────────────┐
│                                 │
│        ⭕ Countdown Ring        │
│       ┌─────────────┐           │
│       │             │           │
│       │    2h 15m   │ ← Elapsed time
│       │   elapsed   │           │
│       │             │           │
│       └─────────────┘           │
│                                 │
│   Window closes in 28m          │ ← Status text
│   Dose 2 available at 01:45     │ ← Disabled reason (gray)
│                                 │
└─────────────────────────────────┘
```

**Behavior:**
- Ring fills from 0.0 (at Dose 1) to 1.0 (at windowEnd)
- Updates every 30 seconds via `TimelineView(.periodic(by: 30))`
- Ring color changes based on window state:
  - 🟠 Orange: Before window (< windowStartMin)
  - 🟢 Green: In window (windowStartMin to windowEndMin)
  - 🔴 Red: After window (> windowEndMin)

**Status Text Variants:**
- No Dose 1: "Log Dose 1 to start timer"
- Before window: "Window opens in 1h 45m"
- In window: "Window closes in 28m"
- After window: "Window expired 12m ago"

**4 Preview States:**
- Before Window (1h elapsed, 🟠)
- In Window (3h elapsed, 🟢)
- After Window (4.5h elapsed, 🔴)
- No Dose 1 (empty state)

---

### 3. EventStripView.swift

**File:** `ios/EventStripView.swift`  
**Lines:** 187  
**Purpose:** Compact list of last 3 events with undo capability

**Props:**
```swift
struct EventStripView: View {
    let events: [EventDisplayItem]
    let allowUndo: Bool
    let onUndo: () -> Void
}
```

**Data Model:**
```swift
struct EventDisplayItem: Identifiable {
    let id: UUID
    let description: String    // "Dose 1 23:05 • 3.25g"
    let relativeTime: String   // "2h 15m ago"
    let icon: String           // "moon.fill"
    let color: Color           // .blue
    let timestamp: Date
}
```

**Visual Design:**
```
┌─────────────────────────────────────────────┐
│ RECENT EVENTS              [Undo] (if <60s)│
├─────────────────────────────────────────────┤
│ 🌕 Dose 1 23:05 • 3.25g      2h 15m ago    │ ← First (highlighted)
│ 🛏️ In bed 22:58              2h 22m ago    │
│ 🚶 Bathroom wake 03:30       45m ago       │
└─────────────────────────────────────────────┘
```

**Event Types with Icons:**
- `dose1`: 🌕 moon.fill (blue)
- `dose2`: 😴 moon.zzz.fill (purple)
- `in_bed`: 🛏️ bed.double.fill (green)
- `bathroom`: 🚶 figure.walk (orange)
- `final_wake`: 🌅 sunrise.fill (yellow)

**Features:**
- Shows last 3 events, descending by time
- First event has highlighted background (gray)
- Undo button appears if `allowUndo == true` (< 60s since last event)
- Empty state: "No events logged yet" with calendar icon

**Helper Method:**
```swift
EventDisplayItem.from(eventType: String, grams: Double?, timestamp: Date)
```

**3 Preview States:**
- With Events (3 items, undo enabled)
- Empty State
- No Undo (events older than 60s)

---

### 4. SafetyBannerView.swift

**File:** `ios/SafetyBannerView.swift`  
**Lines:** 232  
**Purpose:** Always-visible status chips for safety, data sources, permissions

**Props:**
```swift
struct SafetyBannerView: View {
    let perDoseMin: Double
    let perDoseMax: Double
    let nightlyTotal: Double
    let dose1: Double
    let dose2: Double
    let wakeSource: WakeSource
    let healthStatus: HealthKitStatus
    let whoopStatus: WHOOPStatus
    let onChangeSource: () -> Void
    let onFixPermissions: () -> Void
    let onTestWHOOP: () -> Void
}
```

**Visual Design:**
```
┌───────────────────────────────────────────────────┐
│ ✅ Per dose 1.5–4.5g    ✅ Night total 6.5g      │
│                                                   │
│ 💙 Wake: Health [Change]  ✅ Health: OK [Fix]    │
│                                                   │
│ 💚 WHOOP: Connected [Test]                        │
└───────────────────────────────────────────────────┘
```

**Chip Types:**

1. **SafetyChip** (validation with ✓/✕)
   - Per dose: Shows range, validates dose1 and dose2 within 1.5-4.5g
   - Night total: Shows total, validates within 3.0-9.0g
   - Green background (✓) or red background (✕)

2. **StatusChip** (data source with action)
   - Wake source: "Wake: Health" with Change button
   - Health permissions: "Health: OK/Denied/Limited" with Fix button
   - WHOOP proxy: "WHOOP: Connected/Offline" with Test button

**Supporting Enums:**
```swift
enum WakeSource: String {
    case health = "Health"
    case manual = "Manual"
}

enum HealthKitStatus {
    case ok, denied, limited, unknown
    var displayName: String
    var color: Color
}

enum WHOOPStatus {
    case connected, offline, testing
    var displayName: String
    var color: Color
}
```

**Conditional Display:**
- WHOOP chip only shows if `AppPreferences.shared.whoopProxyURL` is not empty

**3 Preview States:**
- All Safe (green checks, Health OK, WHOOP connected)
- Safety Violation (red ✕, doses over max, Health denied)
- WHOOP Not Configured (no WHOOP chip)

---

### 5. EarlyDoseSheetView.swift

**File:** `ios/EarlyDoseSheetView.swift`  
**Lines:** 190  
**Purpose:** Confirmation modal for early Dose 2 with override logging

**Props:**
```swift
struct EarlyDoseSheetView: View {
    @Binding var isPresented: Bool
    let minutesEarly: Int
    let dose2Grams: Double
    let requireReason: Bool
    let timePriorOptions: [Int]
    let onConfirm: (_ reason: String, _ timePriorMin: Int) -> Void
}
```

**Visual Design:**
```
┌─────────────────────────────────────────┐
│ ⚠️ Dose 2 Early                [Cancel] │
│                            [Confirm]    │
├─────────────────────────────────────────┤
│                                         │
│ 🕐 You're logging 25 min before the     │
│    window opens                         │
│                                         │
│ DOSE DETAILS                            │
│ Amount:    3.25g                        │
│ Early by:  25 min                       │
│                                         │
│ REASON (REQUIRED)                       │
│ ○ Could not sleep again                 │
│ ○ Shift schedule                        │
│ ○ Forgot earlier dose                   │
│ ● Other                                 │
│   [Describe reason________]             │
│                                         │
│ LOG TIME                                │
│ Log dose as taken:                      │
│ ┌─────┬─────┬─────┬─────┬─────┐       │
│ │ 5m  │ 10m │ 15m │ 20m │ 30m │ ago   │
│ └─────┴─────┴─────┴─────┴─────┘       │
│                                         │
│ ⓘ This will log an early dose          │
│   override with your reason...          │
│                                         │
│ ⚠️ Your clinician may review override  │
│   events during follow-up.              │
└─────────────────────────────────────────┘
```

**Sections:**
1. **Header:** Warning icon, minutes early subtitle
2. **Dose Details:** Amount and early minutes
3. **Reason (Required):** Picker with 4 options + custom text field
4. **Log Time:** Segmented picker for time-prior adjustment
5. **Disclaimer:** Warning about override logging

**Reason Options (Enum):**
```swift
enum EarlyReason: String, CaseIterable {
    case couldNotSleep = "Could not sleep again"
    case shiftSchedule = "Shift schedule"
    case forgotEarlier = "Forgot earlier dose"
    case other = "Other"
}
```

**Validation:**
- Confirm button disabled until reason provided
- If "Other" selected, custom text required (not empty)

**Callback:**
```swift
onConfirm("Could not sleep again", 10)
// Logs override with reason and 10 min time-prior adjustment
```

**2 Preview States:**
- With Reason Required
- No Reason Required

---

## Integration Roadmap

### Phase 1: Add Components to TodayLogView ⏳

**Current State:** TodayLogView has basic dose buttons, no state gating

**Required Changes:**

1. **Import AppPreferences**
   ```swift
   @State private var preferences = AppPreferences.shared
   ```

2. **Wrap in ScrollView with Sticky Header**
   ```swift
   var body: some View {
       NavigationStack {
           ScrollView {
               VStack(alignment: .leading, spacing: 16) {
                   // Sticky header section
                   Section {
                       CountdownRingView(
                           dose1Time: model.dose1At,
                           windowStartMin: preferences.windowStartMin,
                           windowEndMin: preferences.windowEndMin,
                           disabledReason: dose2DisabledReason
                       )
                       
                       SafetyBannerView(
                           perDoseMin: 1.5,
                           perDoseMax: 4.5,
                           nightlyTotal: preferences.totalNightGrams,
                           dose1: dose1Amount,
                           dose2: dose2Amount,
                           wakeSource: .health,
                           healthStatus: .ok,
                           whoopStatus: .offline,
                           onChangeSource: { /* ... */ },
                           onFixPermissions: { /* ... */ },
                           onTestWHOOP: { /* ... */ }
                       )
                   } header: {
                       Text("Tonight's Status")
                   }
                   .headerProminence(.increased)
                   
                   EventStripView(
                       events: recentEvents,
                       allowUndo: canUndo,
                       onUndo: undoLastEvent
                   )
                   
                   // Existing plan, dose buttons, etc.
               }
               .padding()
           }
           .safeAreaInset(edge: .bottom) {
               actionButtons()
                   .padding()
                   .background(.ultraThinMaterial)
           }
       }
   }
   ```

3. **State Gating: Require "In bed now" before Dose 1**
   ```swift
   var canLogDose1: Bool {
       model.nightKey != "unknown"
   }
   
   Button("Dose 1 Now") {
       if canLogDose1 {
           model.logDose1(grams: dose1Amount)
       } else {
           showInBedPrompt = true
       }
   }
   .disabled(!canLogDose1)
   ```

4. **Consume AppGroupStore on Appear**
   ```swift
   .onAppear {
       controller.consumePendingFromWidget()
       refreshViewModel()
   }
   ```

5. **Fix Dose 2 Enablement Logic**
   ```swift
   var canLogDose2: Bool {
       guard let dose1Time = model.dose1At,
             model.nightKey != "unknown" else {
           return false
       }
       
       let elapsed = Date().timeIntervalSince(dose1Time) / 60.0 // minutes
       let inWindow = elapsed >= Double(preferences.windowStartMin) &&
                      elapsed <= Double(preferences.windowEndMin)
       
       if preferences.allowEarlyDose {
           let earlyThreshold = Double(preferences.windowStartMin - preferences.maxEarlyMinutes)
           let inEarlyWindow = elapsed >= earlyThreshold && elapsed < Double(preferences.windowStartMin)
           return inWindow || inEarlyWindow
       }
       
       return inWindow
   }
   
   var dose2DisabledReason: String {
       guard let dose1Time = model.dose1At else {
           return "Log Dose 1 first"
       }
       guard model.nightKey != "unknown" else {
           return "Tap 'In bed now' to start"
       }
       
       let elapsed = Date().timeIntervalSince(dose1Time) / 60.0
       
       if elapsed < Double(preferences.windowStartMin - preferences.maxEarlyMinutes) {
           let opensAt = dose1Time.addingTimeInterval(TimeInterval(preferences.windowStartMin * 60))
           return "Window opens at \(formatTime(opensAt))"
       }
       if elapsed > Double(preferences.windowEndMin) {
           let overdue = Int(elapsed - Double(preferences.windowEndMin))
           return "Window expired \(overdue) min ago"
       }
       
       return ""
   }
   ```

6. **Show Early Dose Sheet When Appropriate**
   ```swift
   @State private var showEarlyDoseSheet = false
   @State private var earlyDoseMinutes = 0
   
   Button("Dose 2 Now") {
       if shouldShowEarlyConfirmation {
           earlyDoseMinutes = calculateMinutesEarly()
           showEarlyDoseSheet = true
       } else {
           model.logDose2(grams: dose2Amount)
       }
   }
   .sheet(isPresented: $showEarlyDoseSheet) {
       EarlyDoseSheetView(
           isPresented: $showEarlyDoseSheet,
           minutesEarly: earlyDoseMinutes,
           dose2Grams: dose2Amount,
           requireReason: preferences.earlyRequireReason,
           timePriorOptions: preferences.earlyTimePriorOptions,
           onConfirm: { reason, timePrior in
               model.logDose2(
                   grams: dose2Amount,
                   override: true,
                   earlyMinutes: earlyDoseMinutes,
                   reason: reason,
                   timePriorMin: timePrior
               )
           }
       )
   }
   
   var shouldShowEarlyConfirmation: Bool {
       guard let dose1Time = model.dose1At,
             preferences.allowEarlyDose else {
           return false
       }
       
       let elapsed = Date().timeIntervalSince(dose1Time) / 60.0
       return elapsed < Double(preferences.windowStartMin) &&
              elapsed >= Double(preferences.windowStartMin - preferences.maxEarlyMinutes)
   }
   ```

---

### Phase 2: Complete SettingsView (Spec-Aligned) 📋

**File:** `ios/SettingsView.swift`  
**Status:** Needs complete rebuild with 7 sections

**All 7 Sections from Spec:**
1. Night Plan Defaults (6 controls)
2. Early Dose 2 Policy (4 controls)
3. Notifications & Live Activity (6 controls)
4. Data Sources (6 controls)
5. Exports (5 controls)
6. Privacy & Retention (4 controls)
7. Debug & Developer (5 controls)

See `.specify/memory/spec.md` (Settings Panel Complete Specification) for exact controls and defaults.

---

### Phase 3: Live Activity Integration 📲

**File:** `ios/DoseLiveActivity.swift` (new)

**Requirements:**
- Start at Dose 1 with `ActivityKit.request()`
- Content: Countdown to window start/end, elapsed time
- Quick actions: "Dose 2 now", "Snooze 10m", "Open app"
- End when Dose 2 logged or window expired

**Implementation:**
```swift
import ActivityKit

struct DoseLiveActivity: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var dose1Time: Date
        var windowStartMin: Int
        var windowEndMin: Int
        var dose2Logged: Bool
    }
    
    var nightKey: String
}

func startLiveActivity(nightKey: String, dose1Time: Date) async {
    let attributes = DoseLiveActivity(nightKey: nightKey)
    let initialState = DoseLiveActivity.ContentState(
        dose1Time: dose1Time,
        windowStartMin: AppPreferences.shared.windowStartMin,
        windowEndMin: AppPreferences.shared.windowEndMin,
        dose2Logged: false
    )
    
    do {
        let activity = try Activity.request(
            attributes: attributes,
            contentState: initialState,
            pushType: nil
        )
        print("Live Activity started: \(activity.id)")
    } catch {
        print("Failed to start Live Activity: \(error)")
    }
}
```

---

### Phase 4: Notification Scheduling 🔔

**File:** `ios/NotificationManager.swift` (new)

**Requirements:**
- Schedule at window start (if `notifyWindowStart`)
- Schedule at halfway (if `notifyHalfway`)
- Schedule at window end (if `notifyWindowEnd`)
- Respect quiet hours
- Use `UNUserNotificationCenter`

**Implementation:**
```swift
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    func scheduleWindowNotifications(dose1Time: Date) async {
        let prefs = AppPreferences.shared
        let center = UNUserNotificationCenter.current()
        
        // Request authorization
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted == true else { return }
        
        // Cancel existing
        center.removeAllPendingNotificationRequests()
        
        // Window start
        if prefs.notifyWindowStart {
            let startTime = dose1Time.addingTimeInterval(TimeInterval(prefs.windowStartMin * 60))
            scheduleNotification(
                id: "window_start",
                title: "Dose 2 Window Open",
                body: "You can now take your second dose",
                time: startTime
            )
        }
        
        // Halfway
        if prefs.notifyHalfway {
            let midpoint = (prefs.windowStartMin + prefs.windowEndMin) / 2
            let halfwayTime = dose1Time.addingTimeInterval(TimeInterval(midpoint * 60))
            scheduleNotification(
                id: "window_halfway",
                title: "Dose 2 Reminder",
                body: "Midpoint of your dosing window",
                time: halfwayTime
            )
        }
        
        // Window end
        if prefs.notifyWindowEnd {
            let endTime = dose1Time.addingTimeInterval(TimeInterval(prefs.windowEndMin * 60))
            scheduleNotification(
                id: "window_end",
                title: "Dose 2 Window Closing",
                body: "Take your second dose soon",
                time: endTime
            )
        }
    }
    
    private func scheduleNotification(id: String, title: String, body: String, time: Date) {
        // UNNotificationRequest implementation
    }
}
```

---

## Testing Checklist

### Component Isolation Tests

- [ ] **AppPreferences**
  - [ ] All 30+ properties persist across app launches
  - [ ] `calculateDoses()` returns correct splits for all strategies
  - [ ] `planViolatesSafety` catches all violations
  - [ ] `resetToDefaults()` restores all values

- [ ] **CountdownRingView**
  - [ ] Ring fills correctly based on elapsed time
  - [ ] Colors change at window boundaries (orange → green → red)
  - [ ] Status text updates every 30 seconds
  - [ ] "No Dose 1" state shows placeholder

- [ ] **EventStripView**
  - [ ] Shows last 3 events, descending by time
  - [ ] Undo button appears only when `allowUndo == true`
  - [ ] Empty state displays when no events
  - [ ] Relative time strings update ("Just now", "2h 15m ago")

- [ ] **SafetyBannerView**
  - [ ] Safety chips show ✓ when valid, ✕ when violated
  - [ ] Health status colors correct (green/red/orange/gray)
  - [ ] Action buttons trigger callbacks
  - [ ] WHOOP chip hides when URL empty

- [ ] **EarlyDoseSheetView**
  - [ ] Confirm disabled until reason provided
  - [ ] Custom text field appears when "Other" selected
  - [ ] Time-prior picker shows correct options
  - [ ] Callback returns reason and timePrior correctly

### Integration Tests

- [ ] **State Gating**
  - [ ] Cannot log Dose 1 without "In bed now" anchor
  - [ ] nightKey never "unknown" during active session
  - [ ] AppGroupStore consumed on appear

- [ ] **Dose 2 Enablement**
  - [ ] Disabled before early window
  - [ ] Enabled in early window (if policy allows)
  - [ ] Enabled in normal window
  - [ ] Disabled after grace period
  - [ ] Inline reason shows correct message

- [ ] **Early Dose Flow**
  - [ ] Sheet presents when logging early
  - [ ] Override logged with reason and timePrior
  - [ ] event_log contains override=true

- [ ] **ScrollView Layout**
  - [ ] Sticky header visible while scrolling
  - [ ] Action buttons reachable on small devices
  - [ ] Safe area inset applied correctly

### End-to-End Flow

- [ ] Tap "In bed now" → nightKey minted
- [ ] Log Dose 1 → Live Activity starts (if enabled)
- [ ] Countdown ring shows orange, "Window opens in..."
- [ ] Event strip shows "Dose 1 23:05 • 3.25g"
- [ ] Wait for window → ring turns green
- [ ] Dose 2 button enabled, no disabled reason
- [ ] Log Dose 2 → event strip updates
- [ ] Live Activity ends
- [ ] Open Settings → all preferences persist
- [ ] Export CSV → includes override events (if opted in)

---

## File Locations Summary

| Component | File Path | Lines | Status |
|-----------|-----------|-------|--------|
| AppPreferences | `ios/AppPreferences.swift` | 234 | ✅ Ready |
| CountdownRingView | `ios/CountdownRingView.swift` | 178 | ✅ Ready |
| EventStripView | `ios/EventStripView.swift` | 187 | ✅ Ready |
| SafetyBannerView | `ios/SafetyBannerView.swift` | 232 | ✅ Ready |
| EarlyDoseSheetView | `ios/EarlyDoseSheetView.swift` | 190 | ✅ Ready |
| SettingsView | `ios/SettingsView.swift` | N/A | ⏳ Needs rebuild |
| TodayLogView | `ios/TodayLogView.swift` | ~600 | ⏳ Needs integration |
| DoseLiveActivity | `ios/DoseLiveActivity.swift` | N/A | 🔲 Not started |
| NotificationManager | `ios/NotificationManager.swift` | N/A | 🔲 Not started |

**Total Lines Delivered:** 1,021  
**Components Ready:** 5/9  
**Next:** Integrate into TodayLogView, rebuild SettingsView

---

## Constitution Alignment

✅ **Principle I: Safety First**
- SafetyBannerView enforces guardrails visibly
- EarlyDoseSheetView requires reason for overrides
- AppPreferences validates plans against limits

✅ **Principle II: Local-First Privacy**
- All settings in AppPreferences use @AppStorage (UserDefaults)
- No cloud sync
- Data never leaves device except user-initiated export

✅ **Principle III: Clinician-Ready Data**
- EventStripView shows audit trail
- Early dose overrides logged with reason
- CSV export includes override events (opt-in)

---

**Version:** 1.0.0  
**Last Updated:** November 2, 2025  
**Status:** ✅ DROP-IN COMPONENTS READY  

**Next Steps:**
1. Integrate components into TodayLogView with state gating
2. Rebuild SettingsView with 7 sections from spec
3. Add Live Activity support (ActivityKit)
4. Add notification scheduling (UNUserNotificationCenter)
5. Test complete flow: In bed → Dose 1 → Live Activity → Window opens → Dose 2 → CSV export

---

**Quick Links:**
- [Specification](../../.specify/memory/spec.md)
- [AppPreferences SSOT](../../ios/AppPreferences.swift)
- [Logic Flow Diagrams](../design/DOSE2_LOGIC_FLOW.md)
- [Settings Implementation](SETTINGS_IMPLEMENTATION.md)
