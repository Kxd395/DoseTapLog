# DoseTrack Main Screen - Logic & Mapping Documentation

**Version:** 1.1.1c  
**Last Updated:** November 4, 2025  
**Document Type:** Technical Reference - Logic Flow & UI Mapping

---

## Table of Contents

1. [Overview](#overview)
2. [Screen Architecture](#screen-architecture)
3. [Navigation Hierarchy](#navigation-hierarchy)
4. [Data Flow](#data-flow)
5. [UI Component Breakdown](#ui-component-breakdown)
6. [Action Button Logic](#action-button-logic)
7. [State Management](#state-management)
8. [Sheet Presentations](#sheet-presentations)
9. [Business Rules](#business-rules)
10. [Edge Cases & Error Handling](#edge-cases--error-handling)
11. [Interaction Policies (Tap Behavior)](#11-interaction-policies-tap-behavior)

---

## Overview

### Purpose
The main screen (`ThreeCardPlanningView`) is a **three-horizon planning interface** that allows users to view and manage sleep dosing plans across three time periods:
- **Last Night** (historical review)
- **Tonight** (active session)
- **Tomorrow** (future planning)

### Core Responsibilities
1. **Session Management** - Track current night's dosing cycle
2. **Data Logging** - Record bedtime, doses, wake events
3. **Safety Enforcement** - Validate timing windows and dosage limits
4. **Planning** - Create and adjust dosing schedules
5. **Turnover** - Auto-close completed sessions, mint new nights

### Entry Point
```swift
@main
struct DoseTrackApp: App {
    var body: some Scene {
        WindowGroup {
            ThreeCardPlanningView()  // ← Main screen entry
        }
        .modelContainer(for: [DoseLog.self])
    }
}
```

---

## Screen Architecture

### Component Hierarchy

```
ThreeCardPlanningView (Root)
├── NavigationStack
│   ├── Title Row ("DoseTrack" + Settings Gear)
│   ├── Segmented Control (Last Night / Tonight / Tomorrow)
│   └── TabView (Swipeable Cards)
│       ├── NightCardViewModern (Last Night)
│       ├── NightCardViewModern (Tonight) ← Active session
│       └── NightCardViewModern (Tomorrow)
└── Sheets (Modal Overlays)
    ├── SettingsViewEnhanced
    ├── Time Zone Rebase Alert
    └── Auto-Turnover Toast
```

### File Structure

| File | Purpose | Lines |
|------|---------|-------|
| `ThreeCardPlanningView.swift` | Root container, horizon selection | 249 |
| `NightCardViewModern.swift` | Individual night card UI/logic | 993 |
| `TodayViewModel.swift` | Business logic for Tonight | ~500 |
| `DoseLogController.swift` | Persistence layer | ~400 |
| `Models.swift` | DoseLog data model | ~150 |

---

## Navigation Hierarchy

### Horizon Navigation

**Segmented Control:**
```
┌─────────────────────────────────────────┐
│  Last Night  │  Tonight  │  Tomorrow    │
└─────────────────────────────────────────┘
```

**Planning Horizon Enum:**
```swift
enum PlanningHorizon: String, CaseIterable {
    case lastNight   // Yesterday's completed session
    case tonight     // Current active session
    case tomorrow    // Future planning
    
    var displayName: String {
        switch self {
        case .lastNight: return "Last Night"
        case .tonight: return "Tonight"
        case .tomorrow: return "Tomorrow"
        }
    }
    
    func nightKey(cutoffHour: Int) -> String {
        // Returns "YYYY-MM-DD" based on horizon and cutoff
        // Example: If it's Nov 4, 2025 at 2:00 AM (before 12:00 cutoff)
        //   - lastNight = "2025-11-02"
        //   - tonight   = "2025-11-03"
        //   - tomorrow  = "2025-11-04"
    }
}
```

### Modal Navigation

**Sheets Triggered by Actions:**
1. **Settings** - Gear icon (top-right)
2. **Early Dose 2** - Override sheet when logging Dose 2 too early
3. **Late Dose 2** - Override sheet when logging Dose 2 too late
4. **Dose 2 Blocked** - Hard stop when outside policy limits
5. **Need Dose 1** - Prompt to log Dose 1 first
6. **Already Logged** - Edit/undo when Dose 2 already recorded
7. **Wake Sheet** - Log wake events (alarm/bathroom/final)
8. **Reset Night** - Archive or delete current session

---

## Data Flow

### Data Model: `DoseLog`

```swift
@Model
final class DoseLog {
    // Identity
    @Attribute(.unique) var nightKey: String           // "YYYY-MM-DD"
    var nightStartUTC: Date                            // Midnight UTC
    var timezoneOffsetMinutes: Int                     // Local offset
    
    // Timeline Events (all UTC)
    var bedtimeUTC: Date?                              // "In bed" timestamp
    var dose1TimeUTC: Date?                            // Dose 1 logged
    var dose2TimeUTC: Date?                            // Dose 2 logged
    var finalWakeTimeUTC: Date?                        // Final wake
    var bathroomWakeTimesUTC: [Date]                   // Bathroom events
    
    // Dosage Amounts
    var dose1Grams: Double?                            // Dose 1 amount (g)
    var dose2Grams: Double?                            // Dose 2 amount (g)
    
    // Override Tracking
    var dose2IsOverride: Bool = false                  // Was Dose 2 early/late?
    var dose2OverrideKind: String?                     // "early" or "late"
    var dose2OverrideMinutes: Int?                     // Deviation from window
    var dose2OverrideReason: String?                   // User explanation
    
    // Lifecycle State
    var lifecycleState: String = "planned"             // NightLifecycleState
    var autoClosedAt: Date?                            // Auto-close timestamp
    var isClosedByReset: Bool = false                  // Manual reset flag
    
    // Planning (Future/Template)
    var plannedDose1Time: Date?                        // Suggested Dose 1 time
    var plannedDose1Grams: Double?                     // Planned amount
    var plannedDose2Grams: Double?                     // Planned amount
    var plannedDose2Time: Date?                        // Calculated Dose 2 time
    var plannedFinalWakeTime: Date?                    // Calculated wake time
    
    // Metadata
    var morningAlertness: Int?                         // 1-10 rating
    var notes: String?                                 // Free text
    var finalWakeProvenance: String?                   // "natural"/"alarm"/"bathroom"
    var resetBatchId: String?                          // Undo token for resets
}
```

### Lifecycle States

```swift
enum NightLifecycleState: String {
    case planned     // Created, no events logged yet
    case armed       // Bedtime logged, ready for Dose 1
    case active      // Dose 1 logged, window open
    case awaitWake   // Dose 2 logged, waiting for final wake
    case closed      // Final wake logged, session complete
    case abandoned   // Reset/cancelled by user
}
```

**State Transitions:**
```
planned → armed → active → awaitWake → closed
            ↓                            ↓
          abandoned ← ← ← ← ← ← ← ← ← ←┘
          (Reset Night)
```

---

## UI Component Breakdown

### NightCardViewModern Structure

```
┌────────────────────────────────────────────────┐
│ HEADER                                         │
│ ┌────────────────────────────────────────────┐ │
│ │ 🌙 Tonight • 2025-11-04           [⚙️ Gear]│ │
│ └────────────────────────────────────────────┘ │
├────────────────────────────────────────────────┤
│ PLAN CARD                                      │
│ ┌────────────────────────────────────────────┐ │
│ │ Planned Schedule                           │ │
│ │ Dose 1: 2.5g @ 10:30 PM                   │ │
│ │ Dose 2: 2.5g @ 2:30 AM                    │ │
│ │ Wake:        @ 6:30 AM                    │ │
│ │ Total: 5.0g                                │ │
│ └────────────────────────────────────────────┘ │
├────────────────────────────────────────────────┤
│ WINDOW PILLS                                   │
│ ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│ │ Window   │ │ Logged   │ │ Total    │        │
│ │ 3:30-4:30│ │ 4.5g     │ │ 8h total │        │
│ └──────────┘ └──────────┘ └──────────┘        │
├────────────────────────────────────────────────┤
│ STATUS CHIPS                                   │
│ ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│ │ ✓ Per dose│ │ ✓ Σ Plan │ │ ✓ Health │        │
│ │   1-6g   │ │   5.0g   │ │   OK     │        │
│ └──────────┘ └──────────┘ └──────────┘        │
├────────────────────────────────────────────────┤
│ WINDOW BAR (when active)                       │
│ ┌────────────────────────────────────────────┐ │
│ │ ════════════════════════════════           │ │
│ │ 85% • 2h 15m remaining                     │ │
│ └────────────────────────────────────────────┘ │
├────────────────────────────────────────────────┤
│ PRIMARY ACTIONS (4 main buttons)               │
│ ┌────────────┐ ┌────────────┐                 │
│ │ 🌙 In bed  │ │ 💊 Dose 1  │                 │
│ └────────────┘ └────────────┘                 │
│ ┌────────────┐ ┌────────────┐                 │
│ │ 💊 Dose 2  │ │ ☀️ Final   │                 │
│ │ (disabled) │ │    wake    │                 │
│ └────────────┘ └────────────┘                 │
├────────────────────────────────────────────────┤
│ SECONDARY ACTIONS (4 event buttons)           │
│ ┌────────────┐ ┌────────────┐                 │
│ │ ⏰ Alarm   │ │ 🚿 Natural │                 │
│ │    wake    │ │    wake    │                 │
│ └────────────┘ └────────────┘                 │
│ ┌────────────┐ ┌────────────┐                 │
│ │ 🚽 Bathroom│ │ 🔄 Reset   │                 │
│ │            │ │    night   │                 │
│ └────────────┘ └────────────┘                 │
├────────────────────────────────────────────────┤
│ RECENT EVENTS (tonight/last night only)        │
│ ┌────────────────────────────────────────────┐ │
│ │ • 10:32 PM - In bed                        │ │
│ │ • 10:35 PM - Dose 1 (2.5g)                 │ │
│ │ •  2:47 AM - Bathroom wake                 │ │
│ └────────────────────────────────────────────┘ │
└────────────────────────────────────────────────┘
```

### Component Details

#### 1. Header Row
```swift
private var headerRow: some View {
    HStack {
        Image(systemName: horizon.icon)  // 🌙 moon / ☀️ sun
        Text(horizon.displayName)
            .font(.title2.bold())
        Spacer()
        if let night = night {
            Text(night.nightKey)
                .font(.caption)
                .foregroundStyle(Palette.dim)
        }
    }
}
```

#### 2. Plan Card
**Displays:**
- Planned Dose 1 time & amount
- Planned Dose 2 time & amount (calculated from Dose 1 + interval)
- Planned wake time (calculated from Dose 1 + total sleep hours)
- Total planned dosage
- Color-coded status (green = on track, orange = deviation)

**States:**
- **Empty** - No plan yet → Shows "Create Plan from Template" button
- **Planned** - Template applied, not started
- **Active** - Doses being logged, shows actual vs planned

#### 3. Window Pills Row
**Three Pills:**
1. **Window Status** - "Open", "2h 30m remaining", "Closed"
2. **Logged Total** - Sum of actual doses logged
3. **Sleep Duration** - Total hours from bedtime to wake

**Logic:**
```swift
private func windowStatus(_ night: DoseLog) -> String {
    guard let d1 = night.dose1TimeUTC else { return "Waiting" }
    
    let now = Date()
    let elapsed = now.timeIntervalSince(d1) / 60.0  // minutes
    
    let windowStart = prefs.dose2WindowStartMin
    let windowEnd = prefs.dose2WindowEndMin
    
    if elapsed < Double(windowStart) {
        let waitMin = Int(Double(windowStart) - elapsed)
        return "Opens in \(waitMin)m"
    } else if elapsed > Double(windowEnd) {
        return "Closed"
    } else {
        let remainMin = Int(Double(windowEnd) - elapsed)
        return "\(remainMin)m remaining"
    }
}
```

#### 4. Status Chips Row
**Six Status Indicators:**

| Chip | Icon | Check | Display |
|------|------|-------|---------|
| **Per Dose** | `checkmark.seal.fill` | Each dose 1-6g | "✓ 1-6g" or "⚠️ Out of range" |
| **Σ Planned** | `function` | Total < 8g | "✓ 5.0g" or "⚠️ 8.2g" |
| **Logged** | `book.closed` | Actual logged | "📒 4.5g" |
| **Health** | `heart.fill` | HealthKit OK | "✓ Health OK" or "⚠️ Check" |
| **WHOOP** | `bolt.fill` | WHOOP API OK | "✓ WHOOP OK" or "⚠️ Sync" |
| **Time Arc** | `clock` | Window visual | Circle fill % |

**Color Coding:**
- `Palette.ok` (green) - Within limits
- `Palette.warn` (orange) - Approaching limits
- `Palette.danger` (red) - Exceeded limits

#### 5. Window Bar
**Compact Progress Indicator:**
```swift
struct WindowBar: View {
    let progress: Double       // 0.0 - 1.0
    let timeRemaining: String  // "2h 15m"
    let statusText: String     // "Within window" / "Too late"
    
    var body: some View {
        VStack(spacing: 4) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Palette.dim.opacity(0.2))
                    
                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 8)
            
            // Status text
            HStack {
                Text(statusText)
                    .font(.caption)
                Spacer()
                Text(timeRemaining)
                    .font(.caption.monospacedDigit())
            }
            .foregroundStyle(Palette.dim)
        }
    }
    
    private var progressColor: Color {
        if progress < 0.5 {
            return Palette.ok      // Green (early in window)
        } else if progress < 0.9 {
            return Palette.warn    // Orange (approaching end)
        } else {
            return Palette.danger  // Red (window closing)
        }
    }
}
```

---

## Action Button Logic

### Primary Actions (4 Buttons)

#### 1. In Bed 🌙
**Button:**
```swift
.init(
    title: "In bed",
    icon: "moon.fill",
    action: { logInBed(night) }
)
```

**Logic:**
```swift
private func logInBed(_ night: DoseLog) {
    print("🔵 logInBed called - NEW VERSION")
    
    // Set bedtime to current time
    night.bedtimeUTC = Date()
    
    // Update lifecycle state
    night.currentLifecycleState = .armed
    
    // Save to database
    do {
        try modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        print("✅ Logged in bed at \(night.bedtimeUTC!)")
    } catch {
        print("❌ Failed to log bedtime: \(error)")
    }
}
```

**Enabled When:**
- Always available (even if already logged - updates timestamp)

**Side Effects:**
- Sets `bedtimeUTC` to current time
- Transitions state: `planned` → `armed`
- Haptic feedback (success)

---

#### 2. Dose 1 💊
**Button:**
```swift
.init(
    title: "Dose 1",
    icon: "pills.fill",
    action: { logDose1(night) }
)
```

**Logic:**
```swift
private func logDose1(_ night: DoseLog) {
    print("🔵 logDose1 called - NEW VERSION")
    
    // Log timestamp and amount
    night.dose1TimeUTC = Date()
    night.dose1Grams = prefs.planDose1G  // From settings (default 2.5g)
    
    // Update lifecycle state
    night.currentLifecycleState = .active
    
    // Schedule Dose 2 window notifications
    let windowStartMin = prefs.dose2WindowStartMin
    let windowEndMin = prefs.dose2WindowEndMin
    NotificationHelper.shared.scheduleDose2Notifications(
        dose1Time: night.dose1TimeUTC!,
        windowStart: windowStartMin,
        windowEnd: windowEndMin
    )
    
    // Save
    do {
        try modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        print("✅ Logged Dose 1: \(night.dose1Grams ?? 0)g")
    } catch {
        print("❌ Failed to log Dose 1: \(error)")
    }
}
```

**Enabled When:**
- Always available (can update if already logged)

**Side Effects:**
- Sets `dose1TimeUTC` to current time
- Sets `dose1Grams` from preferences
- Transitions state: `armed` → `active`
- Schedules 2 notifications:
  - "Window opening" (at `dose1Time + windowStartMin`)
  - "Window closing soon" (at `dose1Time + windowEndMin - 15min`)
- Haptic feedback (success)

---

#### 3. Dose 2 💊💊
**Button:**
```swift
.init(
    title: "Dose 2",
    icon: "pills.circle.fill",
    action: { tryLogDose2(night) },
    disabled: !dose2Enabled(night),
    caption: dose2DisabledCaption(night)
)
```

**Gate System:**
```swift
private func tryLogDose2(_ night: DoseLog) {
    print("🔵 tryLogDose2 called - NEW VERSION")
    
    let policy = Dose2Policy.from(prefs)
    let gate = evaluateDose2Gate(
        now: Date(),
        dose1At: night.dose1TimeUTC,
        dose2At: night.dose2TimeUTC,
        policy: policy
    )
    
    switch gate {
    case .ready:
        // ✅ Within window - log immediately
        logDose2Now(night)
        
    case .needDose1:
        // ❌ No Dose 1 logged yet
        showNeedDose1Sheet = true
        
    case .alreadyLogged:
        // ⚠️ Dose 2 already recorded
        showAlreadyLoggedSheet = true
        
    case .tooEarly(let minutes):
        if isOverrideAllowed(gate: gate, policy: policy) {
            // ⏰ Early override allowed
            showEarlyDose2Sheet = true
        } else {
            // 🚫 Too early - hard block
            showDose2BlockedSheet = true
        }
        
    case .tooLate(let minutes):
        if isOverrideAllowed(gate: gate, policy: policy) {
            // ⏰ Late override allowed
            showLateDose2Sheet = true
        } else {
            // 🚫 Too late - hard block
            showDose2BlockedSheet = true
        }
    }
}
```

**Dose 2 Gate Evaluation:**
```swift
enum Dose2Gate {
    case ready                      // ✅ Within window
    case needDose1                  // ❌ No Dose 1 logged
    case alreadyLogged              // ⚠️ Already recorded
    case tooEarly(minutes: Int)     // ⏰ Before window start
    case tooLate(minutes: Int)      // ⏰ After window end
}

private func evaluateDose2Gate(
    now: Date,
    dose1At: Date?,
    dose2At: Date?,
    policy: Dose2Policy
) -> Dose2Gate {
    // Check 1: Dose 1 required
    guard let d1 = dose1At else {
        return .needDose1
    }
    
    // Check 2: Already logged
    if let _ = dose2At {
        return .alreadyLogged
    }
    
    // Check 3: Timing vs window
    let elapsed = now.timeIntervalSince(d1) / 60.0  // minutes since Dose 1
    
    let windowStart = Double(policy.windowStartMin)
    let windowEnd = Double(policy.windowEndMin)
    
    if elapsed < windowStart {
        let minutesEarly = Int(windowStart - elapsed)
        return .tooEarly(minutes: minutesEarly)
    }
    
    if elapsed > windowEnd {
        let minutesLate = Int(elapsed - windowEnd)
        return .tooLate(minutes: minutesLate)
    }
    
    // ✅ Within window
    return .ready
}
```

**Override Policy:**
```swift
struct Dose2Policy {
    let windowStartMin: Int         // Default: 210 (3.5h)
    let windowEndMin: Int           // Default: 270 (4.5h)
    let earlyMaxOverrideMin: Int    // Default: 30 (can log 30min early)
    let lateMaxOverrideMin: Int     // Default: 60 (can log 1h late)
    
    static func from(_ prefs: AppPreferencesEnhanced) -> Dose2Policy {
        Dose2Policy(
            windowStartMin: prefs.dose2WindowStartMin,
            windowEndMin: prefs.dose2WindowEndMin,
            earlyMaxOverrideMin: prefs.earlyMaxOverrideMin,
            lateMaxOverrideMin: prefs.lateMaxOverrideMin
        )
    }
}

private func isOverrideAllowed(gate: Dose2Gate, policy: Dose2Policy) -> Bool {
    switch gate {
    case .tooEarly(let minutes):
        return minutes <= policy.earlyMaxOverrideMin
    case .tooLate(let minutes):
        return minutes <= policy.lateMaxOverrideMin
    default:
        return false
    }
}
```

**Enabled When:**
- Dose 1 logged
- NOT already logged
- Within override limits (if outside window)

**Disabled Caption Examples:**
- "Log Dose 1 first"
- "Opens in 45 minutes"
- "Already logged at 2:47 AM"
- "Window closed 2 hours ago"

---

#### 4. Final Wake ☀️
**Button:**
```swift
.init(
    title: "Final wake",
    icon: "sunrise.fill",
    action: { logFinalWake(night) }
)
```

**Logic:**
```swift
private func logFinalWake(_ night: DoseLog) {
    print("🔵 logFinalWake called - NEW VERSION")
    
    // Show sheet with isFinal preset to true
    wakeSheetIsFinal = true
    showWakeSheet = true
}
```

**Sheet Flow:**
1. User selects wake reason (natural/alarm/bathroom)
2. User confirms final wake toggle (preset to ON)
3. User optionally edits timestamp (±15 minutes)
4. User optionally adds notes
5. On confirm:
   ```swift
   night.finalWakeTimeUTC = selectedTime
   night.finalWakeProvenance = reason.rawValue  // "natural"/"alarm"
   night.currentLifecycleState = .closed
   ```

**Enabled When:**
- Always available (even if already logged - can update)

---

### Secondary Actions (4 Event Buttons)

#### 5. Alarm Wake ⏰
**Button:**
```swift
.init(
    title: "Alarm wake",
    icon: "alarm.fill",
    action: { logAlarmWake(night) },
    tone: .dim
)
```

**Logic:**
```swift
private func logAlarmWake(_ night: DoseLog) {
    print("🔵 logAlarmWake called - NEW VERSION")
    
    // Show wake sheet with isFinal preset to false
    wakeSheetIsFinal = false
    showWakeSheet = true
}
```

**Use Case:**
- Alarm went off but user went back to sleep
- Records event but doesn't close the night
- Can later log final wake when actually getting up

---

#### 6. Natural Wake 🌅
**Button:**
```swift
.init(
    title: "Natural wake",
    icon: "bed.double.fill",
    action: { logNaturalWake(night) },
    tone: .dim
)
```

**Logic:**
```swift
private func logNaturalWake(_ night: DoseLog) {
    print("🔵 logNaturalWake called - NEW VERSION")
    
    // Direct log without sheet (assumes natural = final)
    night.finalWakeTimeUTC = Date()
    night.finalWakeProvenance = "natural"
    night.currentLifecycleState = .closed
    
    do {
        try modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        print("✅ Logged natural wake")
    } catch {
        print("❌ Failed to log wake: \(error)")
    }
}
```

**Use Case:**
- Woke up naturally (no alarm)
- Quick-log final wake without opening sheet

---

#### 7. Bathroom 🚽
**Button:**
```swift
.init(
    title: "Bathroom",
    icon: "toilet.fill",
    action: { logBathroom(night) },
    tone: .dim
)
```

**Logic:**
```swift
private func logBathroom(_ night: DoseLog) {
    print("🔵 logBathroom called - NEW VERSION")
    
    // Add timestamp to bathroom wakes array
    night.bathroomWakeTimesUTC.append(Date())
    
    // Haptic feedback only (light impact)
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    
    // TODO: Add to events array when implemented
    print("✅ Logged bathroom wake")
}
```

**Use Case:**
- Woke up for bathroom during the night
- Doesn't affect dosing logic
- Tracked for sleep quality analysis

---

#### 8. Reset Night 🔄
**Button:**
```swift
.init(
    title: "Reset night",
    icon: "arrow.counterclockwise",
    action: { resetNight(night) },
    tone: .danger
)
```

**Logic:**
```swift
private func resetNight(_ night: DoseLog) {
    print("🔵 resetNight called - NEW VERSION")
    showResetNightSheet = true
}
```

**Sheet Flow:**
```swift
ResetNightSheet(
    requireBiometric: true,           // Face ID / Touch ID
    allowHardReset: true,             // Show "Hard Delete" option
    reasonRequired: true,             // Must explain why
    hasFinalWake: night.finalWakeTimeUTC != nil,
    onConfirm: { mode, reason in
        if mode == .soft {
            // Soft reset - archive with reason
            night.currentLifecycleState = .abandoned
            night.notes = (night.notes ?? "") + " [Reset: \(reason)]"
            night.resetBatchId = UUID().uuidString
            night.isClosedByReset = true
        } else {
            // Hard reset - delete from database
            modelContext.delete(night)
        }
        
        try? modelContext.save()
        showResetNightSheet = false
    }
)
```

**Reset Modes:**

| Mode | Effect | Data Retention | Undo |
|------|--------|----------------|------|
| **Soft** | Archives session | ✅ Kept in DB, marked abandoned | ✅ 60s undo window |
| **Hard** | Deletes session | ❌ Permanently removed | ❌ No undo |

**Enabled When:**
- Always available (safety escape hatch)

**Use Cases:**
- Logged wrong data
- Need to start over
- Abandoned dosing plan mid-session

---

## State Management

### State Variables (in NightCardViewModern)

```swift
// Sheet presentation states
@State private var showPlanEditor = false
@State private var showEarlyDose2Sheet = false
@State private var showLateDose2Sheet = false
@State private var showDose2BlockedSheet = false
@State private var showNeedDose1Sheet = false
@State private var showAlreadyLoggedSheet = false
@State private var showWakeSheet = false
@State private var showResetNightSheet = false
@State private var wakeSheetIsFinal = false

// Preferences (singleton)
private let prefs = AppPreferencesEnhanced.shared
```

### Persistent State (in DoseLog)

All state stored in SwiftData model:
- Timeline events (bedtime, doses, wakes)
- Dosage amounts
- Override tracking
- Lifecycle state
- Planning data

**Persistence Flow:**
```
User Action → Update DoseLog → modelContext.save() → SQLite
                                         ↓
                                  UI Auto-Refreshes
```

---

## Sheet Presentations

### 1. Early Dose 2 Sheet
**Triggered When:**
- User taps Dose 2
- Current time is before window start
- Within early override limit (e.g., ≤30 minutes early)

**UI:**
```
┌──────────────────────────────────────┐
│ Dose 2 Early                         │
├──────────────────────────────────────┤
│ You're logging 23 minutes early.     │
│                                      │
│ [Reason (optional)]                  │
│ ┌──────────────────────────────────┐ │
│ │ Traveling early tomorrow         │ │
│ └──────────────────────────────────┘ │
│                                      │
│ Time prior options:                  │
│ ○ None                               │
│ ● 30 minutes                         │
│ ○ 60 minutes                         │
│                                      │
│ [Cancel]           [Confirm: 2.5g]   │
└──────────────────────────────────────┘
```

**Confirmation:**
```swift
onConfirm: { reason, timePrior in
    night.dose2TimeUTC = Date()
    night.dose2Grams = prefs.planDose2G
    night.dose2IsOverride = true
    night.dose2OverrideKind = "early"
    night.dose2OverrideMinutes = minutesEarly
    night.dose2OverrideReason = reason
    night.currentLifecycleState = .awaitWake
    
    try? modelContext.save()
}
```

---

### 2. Late Dose 2 Sheet
**Triggered When:**
- User taps Dose 2
- Current time is after window end
- Within late override limit (e.g., ≤60 minutes late)

**UI:**
```
┌──────────────────────────────────────┐
│ Dose 2 Late                          │
├──────────────────────────────────────┤
│ You're logging 45 minutes late.      │
│                                      │
│ [Reason (required)]                  │
│ ┌──────────────────────────────────┐ │
│ │ Had to finish work call          │ │
│ └──────────────────────────────────┘ │
│                                      │
│ Log as:                              │
│ ● Taken now                          │
│ ○ Missed dose                        │
│                                      │
│ [Cancel]           [Confirm: 2.5g]   │
└──────────────────────────────────────┘
```

---

### 3. Wake Sheet
**Triggered By:**
- "Final wake" button
- "Alarm wake" button

**UI:**
```
┌──────────────────────────────────────┐
│ Log Wake Event                       │
├──────────────────────────────────────┤
│ Reason:                              │
│ ● Natural wake                       │
│ ○ Alarm                              │
│ ○ Bathroom                           │
│                                      │
│ ☑ This is my final wake             │
│ ☐ Alarm was interrupted              │
│                                      │
│ Time: [6:32 AM] ±15min               │
│                                      │
│ Notes (optional):                    │
│ ┌──────────────────────────────────┐ │
│ │ Felt well-rested                 │ │
│ └──────────────────────────────────┘ │
│                                      │
│ [Cancel]              [Save]         │
└──────────────────────────────────────┘
```

**Logic:**
```swift
onConfirm: { reason, isFinal, wasInterrupted, time, note in
    if isFinal {
        night.finalWakeTimeUTC = time
        night.finalWakeProvenance = reason.rawValue
        night.currentLifecycleState = .closed
    }
    // TODO: Add to events array
    try? modelContext.save()
}
```

---

### 4. Reset Night Sheet
**UI:**
```
┌──────────────────────────────────────┐
│ ⚠️ Reset This Night?                 │
├──────────────────────────────────────┤
│ This will archive the current        │
│ session. You cannot undo this.       │
│                                      │
│ [Reason (required)]                  │
│ ┌──────────────────────────────────┐ │
│ │ Logged wrong time by mistake     │ │
│ └──────────────────────────────────┘ │
│                                      │
│ 🔐 Face ID Required                  │
│                                      │
│ Reset mode:                          │
│ ● Soft (archive data)                │
│ ○ Hard (delete permanently)          │
│                                      │
│ [Cancel]        [Reset Night]        │
└──────────────────────────────────────┘
```

---

## Business Rules

### Safety Constraints

#### 1. Per-Dose Limits
```swift
let perDoseMinG = 1.0  // Minimum safe dose
let perDoseMaxG = 6.0  // Maximum safe dose

func validateDose(_ grams: Double) -> Bool {
    return grams >= perDoseMinG && grams <= perDoseMaxG
}
```

**Enforcement:**
- Settings UI prevents entering values outside range
- Status chip shows warning if planned dose out of range

---

#### 2. Total Night Limits
```swift
let maxTotalNightG = 8.0  // Total dosage ceiling

func validateTotal(dose1: Double, dose2: Double) -> Bool {
    return (dose1 + dose2) <= maxTotalNightG
}
```

**Enforcement:**
- Safety banner shows warning if planned total > 8g
- Cannot save settings with total > 8g

---

#### 3. Dose 2 Window
```swift
struct Dose2Window {
    let startMin: Int  // Default: 210 (3.5 hours)
    let endMin: Int    // Default: 270 (4.5 hours)
    
    var duration: Int {
        endMin - startMin  // Default: 60 minutes
    }
}
```

**Override Limits:**
```swift
struct OverrideLimits {
    let earlyMaxMin: Int  // Default: 30 (can log 30min early)
    let lateMaxMin: Int   // Default: 60 (can log 1h late)
}
```

**Hard Limits:**
- Cannot log Dose 2 > 30 minutes before window start
- Cannot log Dose 2 > 60 minutes after window end
- Blocked sheet shown if outside limits

---

### Sequence Validation

**Required Order:**
```
(In bed) → Dose 1 → Dose 2 → Final wake
  ↓         ↓         ↓         ↓
Optional   Required  Required  Required
```

**Validation:**
```swift
func isValidSequence(windowStartMin: Int, windowEndMin: Int) -> (ok: Bool, msg: String?) {
    // Rule 1: If Dose 1 logged, check Dose 2 timing
    guard let d1 = dose1TimeUTC else { return (true, nil) }
    
    if let d2 = dose2TimeUTC {
        // Rule 2: Dose 2 must be after Dose 1
        if d2 <= d1 {
            return (false, "Dose 2 cannot be before or equal to Dose 1.")
        }
        
        // Rule 3: Dose 2 must be within window
        let minutes = Int(d2.timeIntervalSince(d1) / 60.0)
        if minutes < windowStartMin {
            return (false, "Dose 2 is earlier than the allowed window start.")
        }
        if minutes > windowEndMin {
            return (false, "Dose 2 is later than the allowed window end.")
        }
    }
    
    return (true, nil)
}
```

---

### Template Planning

**Weekly Schedule:**
```swift
struct WeeklyScheduleProfile {
    struct DaySchedule {
        var targetBedtime: String    // "22:30"
        var targetWake: String        // "06:30"
        var profileType: ProfileType  // .workday / .offDay / .travel
    }
    
    var days: [DaySchedule]          // 7 days (Sun-Sat)
    var maxShiftPerNightMin: Int     // Circadian stability limit
    var timeZonePolicy: TimeZonePolicy
    var homeTimeZone: String
}
```

**Template Application:**
```swift
func createPlanFromTemplate() {
    let schedule = prefs.weeklySchedule
    
    // Get suggested Dose 1 time based on day of week
    night.plannedDose1Time = schedule.suggestedDose1Time(
        for: Date(),
        cutoffHour: prefs.cutoffHourLocal,
        in: TimeZone.current
    )
    
    // Calculate Dose 2 and wake times
    let dose2Interval = TimeInterval(prefs.dose2IntervalHours * 3600)
    night.plannedDose2Time = night.plannedDose1Time! + dose2Interval
    
    let totalSleep = TimeInterval(prefs.totalSleepHours * 3600)
    night.plannedFinalWakeTime = night.plannedDose1Time! + totalSleep
    
    // Set planned amounts
    night.plannedDose1Grams = prefs.planDose1G
    night.plannedDose2Grams = prefs.planDose2G
    
    try? modelContext.save()
}
```

---

## Edge Cases & Error Handling

### 1. Night Turnover Mid-Session

**Scenario:** User has active session at 11:45 PM, cutoff is 12:00 noon.

**Behavior:**
- At 12:00 PM next day, auto-close triggers
- Current active night transitions to `closed` (or `abandoned` if incomplete)
- New "Tonight" minted for next service day
- User sees toast: "Previous night auto-closed"

**Implementation:**
```swift
private func checkForCutoffCrossing() {
    let hasCrossed = NightServiceDay.hasCrossedCutoff(
        since: lastRefreshDate,
        cutoffHour: prefs.cutoffHourLocal
    )
    
    guard hasCrossed else { return }
    
    autoCloseLingeringNights()
    mintTonightIfNeeded()
    
    lastRefreshDate = Date()
}
```

---

### 2. Timezone Changes

**Scenario:** User travels from EST (UTC-5) to PST (UTC-8), 3-hour shift.

**Detection:**
```swift
private func checkForTimeZoneChange() {
    let currentTZ = TimeZone.current
    
    guard let lastTZ = prefs.lastKnownTimeZone,
          lastTZ != currentTZ.identifier else { return }
    
    let change = TimeZoneChange(from: TimeZone(identifier: lastTZ)!, to: currentTZ)
    
    if change.shouldPromptRebase {
        showTimeZoneRebasePrompt = true
    }
    
    prefs.lastKnownTimeZone = currentTZ.identifier
}
```

**Prompt:**
```
┌──────────────────────────────────────┐
│ Time Zone Changed                    │
├──────────────────────────────────────┤
│ Your time zone shifted 3 hours west. │
│                                      │
│ How should we adjust your plan?      │
│                                      │
│ • Use Local Time                     │
│   (Recompute plan in PST)            │
│                                      │
│ • Keep Home Time                     │
│   (Continue using EST times)         │
│                                      │
│ • Adjust Manually                    │
│                                      │
│ [Use Local]         [Keep Home]      │
└──────────────────────────────────────┘
```

---

### 3. Missed Window

**Scenario:** User logged Dose 1 at 10:30 PM, window is 2:00-3:00 AM. User tries to log at 4:30 AM (90 minutes late).

**Gate Result:**
```swift
.tooLate(minutes: 90)  // 90 > lateMaxOverrideMin (60)
```

**Behavior:**
- Dose 2 button disabled
- Caption: "Window closed 1h 30m ago"
- Tapping shows blocked sheet:
  ```
  ┌──────────────────────────────────────┐
  │ ⛔️ Dose 2 Unavailable                │
  ├──────────────────────────────────────┤
  │ The window closed 1h 30m ago.        │
  │                                      │
  │ You can:                             │
  │ • Set reminder for next window       │
  │ • Reset this night to start over     │
  │                                      │
  │ [Remind Me]         [Reset Night]    │
  └──────────────────────────────────────┘
  ```

---

### 4. Duplicate Logs

**Scenario:** User taps "Dose 1" twice quickly.

**Behavior:**
- First tap: Logs timestamp and amount
- Second tap: Updates timestamp (overwrites previous)
- No error shown (idempotent operation)

**Rationale:**
- Allows correcting accidental mistimed logs
- User can tap again to update timestamp

---

### 5. Empty State (Tomorrow)

**Scenario:** User swipes to "Tomorrow" tab before tomorrow's night is minted.

**Behavior:**
```
┌──────────────────────────────────────┐
│ 🌙 Tomorrow • 2025-11-05             │
├──────────────────────────────────────┤
│ No plan yet for Tomorrow             │
│                                      │
│ [Create Plan from Template]          │
└──────────────────────────────────────┘
```

**Action:**
- Button triggers `createPlanFromTemplate()`
- Mints new night with `nightKey = "2025-11-05"`
- Populates planned times from weekly schedule

---

### 6. Offline Mode

**Scenario:** No network connection.

**Behavior:**
- All core functionality works offline (local SQLite database)
- HealthKit/WHOOP status chips show "⚠️ Offline" or "⚠️ Sync failed"
- Notifications still delivered (local notifications)
- No impact on dosing logic

---

### 7. Background App Refresh

**Scenario:** App suspended, BGTaskScheduler runs turnover at 12:00 noon.

**Implementation:**
```swift
// In AppDelegate or App struct
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.dosetrack.nightturnover",
    using: nil
) { task in
    let controller = NightTurnoverController(modelContext)
    
    Task {
        await controller.performTurnover()
        task.setTaskCompleted(success: true)
    }
}
```

**User Experience:**
- User opens app → sees "Previous night auto-closed" toast
- "Tonight" already minted and ready
- Seamless transition even if app wasn't open

---

## 11. Interaction Policies (Tap Behavior)

### Overview
Users can configure how action buttons respond to taps:
- **Quick Log** - Single tap logs event immediately (at "now")
- **Confirm Sheet** - Single tap opens time picker sheet for adjustment
- **Smart** - Single tap logs now if recent activity (within N seconds), else opens sheet

**Long-press always opens "Log at..." sheet** regardless of mode.

### Policy Structure

```swift
enum TapBehavior {
    case quickLog
    case confirmSheet
    case smart(thresholdSec: Int)
}

struct TapPolicy {
    var global: TapBehavior               // Default for all actions
    var smartThresholdSec: Int            // Default: 90 seconds
    
    // Per-action overrides (nil = use global)
    var overrideInBed: TapBehavior?
    var overrideDose1: TapBehavior?
    var overrideDose2: TapBehavior?       // CRITICAL: min .confirmSheet
    var overrideFinalWake: TapBehavior?   // CRITICAL: min .confirmSheet
    var overrideAlarmWake: TapBehavior?
    var overrideNaturalWake: TapBehavior?
    var overrideBathroom: TapBehavior?
    
    var showSeconds: Bool                  // Time picker precision
    var showQuickPresets: Bool             // Show ±10m, ±5m, ±1m chips
}
```

### Recommended Defaults

| Action | Default Behavior | Rationale |
|--------|------------------|-----------|
| **In Bed** | Quick Log | Simple timestamp, no safety concern |
| **Dose 1** | Smart (90s) | Usually "now", but allow time adjustment |
| **Dose 2** | **Confirm Sheet** | **CRITICAL: Gate enforcement required** |
| **Final Wake** | **Confirm Sheet** | **CRITICAL: Closes night, must confirm** |
| **Alarm Wake** | Smart (90s) | Typically recent, allow adjustment |
| **Natural Wake** | Smart (90s) | Typically recent, allow adjustment |
| **Bathroom** | Quick Log | Simple interim event |

### Safety Enforcement

**CRITICAL RULES:**
1. **Dose 2 NEVER bypasses gate** - Even in Quick Log mode, must route through evaluateDose2Gate()
2. **Final Wake NEVER logs silently** - Quick mode shows mini-confirm sheet
3. **Dose 2/Final Wake CANNOT be set to quickLog** - Settings UI enforces minimum .confirmSheet

### Tap Handler Logic

```swift
func handleTap(action: NightAction, now: Date, eventRecentTs: Date?) {
    let behavior = prefs.tapPolicy.behavior(for: action)
    
    switch behavior {
    case .quickLog:
        routeQuickOrGated(action, night)
        
    case .confirmSheet:
        presentLogTimeSheet(for: action)
        
    case .smart(let threshold):
        if let ts = eventRecentTs, abs(now.timeIntervalSince(ts)) <= Double(threshold) {
            routeQuickOrGated(action, night)
        } else {
            presentLogTimeSheet(for: action)
        }
    }
}

private func routeQuickOrGated(_ action: NightAction, _ night: DoseLog) {
    switch action {
    case .dose2:
        // CRITICAL: Always run gate, even in quick mode
        tryLogDose2ViaGate(night)
        
    case .finalWake:
        // CRITICAL: Show mini-confirm sheet
        presentMiniConfirmCloseNight(night)
        
    case .inBed:
        logInBedNow(night)
        showUndoToast(60) // 60s undo window
        
    case .dose1:
        logDose1Now(night)
        showUndoToast(60)
        
    case .alarmWake, .naturalWake, .bathroom:
        logWakeEvent(action, at: Date(), night)
        showUndoToast(60)
    }
}
```

### Long-Press Gesture

**ALL buttons support long-press:**

```swift
ActionButton(title: "Dose 1", icon: "pills.fill") {
    handleTap(.dose1, now: Date(), eventRecentTs: timestampTracker.lastTimestamp(for: .dose1))
}
.simultaneousGesture(
    LongPressGesture(minimumDuration: 0.5)
        .onEnded { _ in
            presentLogTimeSheet(for: .dose1)
        }
)
.accessibilityHint(prefs.tapPolicy.behavior(for: .dose1).voiceOverHint(action: .dose1))
```

### LogTimeSheet Component

**Universal time picker sheet:**

```swift
struct LogTimeSheet: View {
    let action: NightAction
    let policy: TapPolicy
    let onLog: (Date) -> Void
    
    var body: some View {
        VStack {
            // Header: Icon + title
            Image(systemName: action.icon)
            Text(action.displayName)
            
            // Window status (for Dose 2)
            if action == .dose2, let status = windowStatus {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(status) // "Opens in 12m" / "Closed 1h 03m ago"
                }
            }
            
            // Time selection
            if policy.showQuickPresets {
                // "Now" chip + presets (−10m, −5m, −1m, +1m, +5m)
                ScrollView(.horizontal) {
                    HStack {
                        TimeChip("Now", selected: useNow) { ... }
                        TimeChip("−10m") { ... }
                        TimeChip("−5m") { ... }
                        TimeChip("−1m") { ... }
                        TimeChip("+1m") { ... }
                        TimeChip("+5m") { ... }
                    }
                }
            }
            
            // Wheel picker (hours:minutes:seconds or hours:minutes)
            DatePicker("Time", selection: $selectedTime,
                displayedComponents: policy.showSeconds ? [.hourMinuteAndSecond] : [.hourAndMinute])
                .datePickerStyle(.wheel)
            
            // Action buttons
            Button("Log \(action.displayName)") {
                onLog(selectedTime)
            }
            .buttonStyle(.borderedProminent)
            
            Button("Cancel") { ... }
        }
    }
}
```

### Settings UI

**Settings → Interaction & Tap Behavior:**

```
┌─────────────────────────────────────────┐
│ Interaction & Tap Behavior              │
├─────────────────────────────────────────┤
│                                         │
│ Global Tap Behavior                     │
│ ┌───────────────────────────────────┐   │
│ │ Quick Log                          │   │
│ │ Confirm Sheet                      │ ← │
│ │ Smart                              │   │
│ └───────────────────────────────────┘   │
│                                         │
│ Smart Threshold                         │
│ ┌───────────────────────────────────┐   │
│ │ 90 seconds         ◀──────▶        │   │
│ └───────────────────────────────────┘   │
│                                         │
│ Per-Action Overrides                    │
│ ┌───────────────────────────────────┐   │
│ │ In Bed          Quick Log         │   │
│ │ Dose 1          Use Global        │   │
│ │ Dose 2          Confirm Sheet 🔒  │   │ ← Locked minimum
│ │ Final Wake      Confirm Sheet 🔒  │   │ ← Locked minimum
│ │ Alarm Wake      Use Global        │   │
│ │ Natural Wake    Use Global        │   │
│ │ Bathroom        Quick Log         │   │
│ └───────────────────────────────────┘   │
│                                         │
│ ☑ Show seconds in time pickers          │
│ ☑ Show quick presets (−10m, −5m, etc.) │
│                                         │
└─────────────────────────────────────────┘
```

### Undo Toast

**After any quick log:**

```swift
func showUndoToast(_ durationSec: Int) {
    @State var countdown = durationSec
    
    // Show toast at bottom
    VStack {
        Spacer()
        HStack {
            Text("Logged")
            Spacer()
            Button("Undo \(String(format: "%02d:%02d", countdown / 60, countdown % 60))") {
                undoLastEvent()
            }
        }
        .padding()
        .background(Palette.surfaceHi)
        .cornerRadius(12)
    }
    
    // Live countdown
    Timer.publish(every: 1.0, on: .main, in: .common)
        .autoconnect()
        .sink { _ in
            countdown -= 1
            if countdown == 0 {
                dismissToast()
            }
        }
}
```

### VoiceOver Hints

**Action button accessibility:**

```swift
ActionButton("Dose 2", icon: "pills.circle.fill") { ... }
    .accessibilityHint(
        prefs.tapPolicy.behavior(for: .dose2).voiceOverHint(action: .dose2)
    )
    .accessibilityValue(
        dose2AccessibilityHint(gate: evaluateDose2Gate(...))
    )

// Examples:
// "Double-tap to log Dose 2 now. Long-press to set a time."
// "Locked: wait 17 minutes"
```

### Test Cases

**Interaction policy tests:**

```swift
// Smart mode: within threshold
func testSmartMode_WithinThreshold() {
    policy.global = .smart(thresholdSec: 90)
    timestampTracker.record(.dose1, at: Date().addingTimeInterval(-60)) // 60s ago
    
    handleTap(.dose1, now: Date(), eventRecentTs: timestampTracker.lastTimestamp(for: .dose1))
    
    // Should log immediately (within 90s threshold)
    XCTAssertNotNil(night.dose1TimeUTC)
}

// Smart mode: outside threshold
func testSmartMode_OutsideThreshold() {
    policy.global = .smart(thresholdSec: 90)
    timestampTracker.record(.dose1, at: Date().addingTimeInterval(-120)) // 120s ago
    
    handleTap(.dose1, now: Date(), eventRecentTs: timestampTracker.lastTimestamp(for: .dose1))
    
    // Should open sheet (outside 90s threshold)
    XCTAssertTrue(showLogTimeSheet)
}

// Dose 2 gate enforcement (even in Quick mode)
func testDose2_AlwaysRoutesViaGate() {
    policy.overrideDose2 = .quickLog // User tries to set quick
    
    // System enforces minimum .confirmSheet
    XCTAssertEqual(policy.behavior(for: .dose2), .confirmSheet)
    
    // Even if we force quick, gate is always called
    handleTap(.dose2, now: Date(), eventRecentTs: nil)
    
    XCTAssertTrue(evaluateDose2GateCalled)
}

// Final wake never silent
func testFinalWake_NeverQuick() {
    policy.overrideFinalWake = .quickLog
    
    // System enforces minimum .confirmSheet
    XCTAssertEqual(policy.behavior(for: .finalWake), .confirmSheet)
}

// Undo within 60s
func testUndo_Within60Seconds() {
    logDose1Now(night)
    XCTAssertNotNil(night.dose1TimeUTC)
    
    // Wait 30s
    wait(30)
    
    // Undo
    undoLastEvent()
    
    // Dose 1 cleared
    XCTAssertNil(night.dose1TimeUTC)
}

// Undo after 60s fails
func testUndo_After60Seconds() {
    logDose1Now(night)
    
    // Wait 65s
    wait(65)
    
    // Undo button gone
    XCTAssertFalse(showUndoButton)
}
```

---

## Summary: Main Screen Flow

### Happy Path (Typical Night)

```
1. 10:00 PM - User opens app
   ↓
2. "Tonight" card shows empty plan
   ↓
3. User taps "Create Plan from Template"
   → Planned times appear (10:30 PM, 2:30 AM, 6:30 AM)
   ↓
4. 10:28 PM - User taps "In bed"
   → (Tap behavior: Quick Log mode)
   → Bedtime logged immediately, state → armed
   → Undo toast shown (60s countdown)
   ↓
5. 10:32 PM - User taps "Dose 1"
   → (Tap behavior: Smart mode, within 90s threshold)
   → Dose 1 logged (2.5g), state → active
   → Window notifications scheduled
   → Undo toast shown
   ↓
6. 2:00 AM - Notification: "Dose 2 window is now open"
   ↓
7. 2:47 AM - User wakes, opens app
   ↓
8. Window bar shows "47 min remaining"
   ↓
9. User taps "Dose 2"
   → (Tap behavior: Confirm Sheet mode)
   → LogTimeSheet opens
   → User selects "Now"
   → Gate returns .ready (within window)
   → Dose 2 logged (2.5g), state → awaitWake
   → Undo toast shown
   ↓
10. User goes back to sleep
    ↓
11. 6:38 AM - User wakes naturally
    ↓
12. User taps "Natural wake"
    → (Tap behavior: Smart mode, first tap of day)
    → LogTimeSheet opens (no recent timestamp)
    → User selects "Now"
    → Final wake logged, state → closed
    → Night complete ✅
```

### Override Path (Early Dose 2)

```
1-5. (Same as happy path)
   ↓
6. 1:45 AM - User wakes early, needs Dose 2
   ↓
7. Opens app, window bar shows "Opens in 15 min"
   ↓
8. User taps "Dose 2"
   → LogTimeSheet opens (confirm sheet mode)
   → Window status shows "Opens in 15m" (orange warning)
   → User selects "Now"
   → Gate returns .tooEarly(minutes: 15)
   → "Override Window" button appears
   ↓
9. User taps "Override Window"
   → Early override sheet appears
   → User enters reason: "Traveling early tomorrow"
   ↓
10. User taps "Confirm: 2.5g"
    → Dose 2 logged with override flag
    → dose2IsOverride = true, dose2OverrideKind = "early"
    → State → awaitWake
    ↓
11. (Continue to final wake)
```

### Emergency Path (Reset Night)

```
1-7. (User has logged Dose 1, realizes mistake)
   ↓
8. User taps "Reset Night"
   → Reset sheet appears
   ↓
9. User enters reason: "Logged wrong time by mistake"
   ↓
10. User authenticates with Face ID
    ↓
11. User selects "Soft (archive data)"
    ↓
12. User taps "Reset Night"
    → Night marked as abandoned
    → Notes field: "[Reset: Logged wrong time by mistake]"
    → State → abandoned
    ↓
13. User can start fresh or plan for tomorrow
```

---

## Document Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-04 | Initial comprehensive logic map created |

---

**End of Document**
