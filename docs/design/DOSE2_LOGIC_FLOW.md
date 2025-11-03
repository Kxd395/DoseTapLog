# Dose 2 Gating Logic Flow - Detailed Documentation

**📍 Location:** `docs/design/DOSE2_LOGIC_FLOW.md`  
**🔗 Related Files:**
- Implementation: `DoseTrackIOS/DoseTrackIOS/Dose2Gate.swift`
- UI Component: `DoseTrackIOS/DoseTrackIOS/Dose2Button.swift`
- Integration: `DoseTrackIOS/DoseTrackIOS/TodayLogView.swift`
- Database: `DoseTrackIOS/DoseTrackIOS/EventLog.swift`

**📚 Breadcrumbs:**  
`docs/` → `design/` → **`DOSE2_LOGIC_FLOW.md`**

---

## Table of Contents

1. [Overview](#overview)
2. [State Machine Architecture](#state-machine-architecture)
3. [Time-Based State Transitions](#time-based-state-transitions)
4. [Confirmation Dialog Logic](#confirmation-dialog-logic)
5. [Override Tracking](#override-tracking)
6. [UI Integration Flow](#ui-integration-flow)
7. [Safety Guardrails](#safety-guardrails)
8. [ASCII Diagrams](#ascii-diagrams)

---

## Overview

The Dose 2 gating system uses a **state machine** to determine button behavior based on elapsed time since Dose 1. Instead of hard-blocking the button, it provides flexible windows with confirmation dialogs for early/late logging.

### Design Principle

**"Guardrail, not a hard block"** - Users can override timing windows with explicit consent, and all overrides are tracked for audit trails.

### Key Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Dose 2 Gating System                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │ Dose2Gate   │───▶│ Dose2Button  │───▶│  EventLog    │  │
│  │ (Logic)     │    │ (UI)         │    │  (Storage)   │  │
│  └─────────────┘    └──────────────┘    └──────────────┘  │
│        ▲                    │                    │          │
│        │                    ▼                    ▼          │
│  ┌─────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │ Dose2Policy │    │ Confirmation │    │  Override    │  │
│  │ (Config)    │    │  Dialogs     │    │  Tracking    │  │
│  └─────────────┘    └──────────────┘    └──────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## State Machine Architecture

### State Definition

```swift
enum Dose2Gate {
    case needDose1                      // No Dose 1 logged yet
    case waiting(minutesToStart: Int)   // Before early allow window
    case early(minutesEarly: Int)       // Can override with confirmation
    case open(minutesLeft: Int)         // Normal window, no confirmation
    case grace(minutesOver: Int)        // Can override with confirmation
    case missed                         // Past grace period
}
```

### State Properties

Each state has computed properties:

| Property | Type | Purpose |
|----------|------|---------|
| `statusLabel` | String | User-facing status text |
| `isButtonEnabled` | Bool | Whether button is tappable |
| `needsConfirmation` | Bool | Whether to show dialog |
| `statusColor` | Color | Visual indicator color |

### Policy Configuration

```swift
struct Dose2Policy {
    let windowStartMin: Int       // 150 (2.5 hours)
    let windowEndMin: Int         // 240 (4 hours)
    let earlyAllowMin: Int        // 30 (allow 30 min early)
    let lateGraceMin: Int         // 15 (allow 15 min late)
}
```

---

## Time-Based State Transitions

### ASCII Timeline

```
Dose 1 Logged
    │
    │   0 min ─────────────────────────────────────────────────
    │          ║ needDose1 → waiting                    ║
    │          ║ Button: DISABLED                        ║
    │          ║ Status: "Dose 2 in X min"               ║
    │          ╚═════════════════════════════════════════╝
    │
    ├─ 120 min ─────────────────────────────────────────────────
    │          ╔═════════════════════════════════════════╗
    │          ║ EARLY ALLOW WINDOW (120-150 min)       ║
    │          ║ State: early(minutesEarly)              ║
    │          ║ Button: ENABLED                         ║
    │          ║ Status: "⚠️ X min early"                ║
    │          ║ Requires: CONFIRMATION DIALOG           ║
    │          ╚═════════════════════════════════════════╝
    │
    ├─ 150 min ─────────────────────────────────────────────────
    │          ╔═════════════════════════════════════════╗
    │          ║ NORMAL WINDOW (150-240 min)             ║
    │          ║ State: open(minutesLeft)                ║
    │          ║ Button: ENABLED                         ║
    │          ║ Status: "✓ X min left"                  ║
    │          ║ Requires: NO CONFIRMATION               ║
    │          ╚═════════════════════════════════════════╝
    │
    ├─ 240 min ─────────────────────────────────────────────────
    │          ╔═════════════════════════════════════════╗
    │          ║ GRACE PERIOD (240-255 min)              ║
    │          ║ State: grace(minutesOver)               ║
    │          ║ Button: ENABLED                         ║
    │          ║ Status: "⚠️ X min over"                 ║
    │          ║ Requires: CONFIRMATION DIALOG           ║
    │          ╚═════════════════════════════════════════╝
    │
    └─ 255 min ─────────────────────────────────────────────────
               ║ State: missed                           ║
               ║ Button: ENABLED                         ║
               ║ Status: "Missed window"                 ║
               ║ Button Text: "Log missed dose"         ║
               ╚═════════════════════════════════════════╝
```

### State Computation Algorithm

```
┌─────────────────────────────────────────────────────────────┐
│ computeDose2Gate(dose1TimeUTC, now, policy)                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  INPUT: dose1TimeUTC (Date?), now (Date), policy (Policy)  │
│                                                             │
│  ┌───────────────────────────────────────┐                 │
│  │ dose1TimeUTC == nil?                  │                 │
│  └──────────┬────────────────────────────┘                 │
│             │ YES                                           │
│             ▼                                               │
│      ┌─────────────┐                                        │
│      │ needDose1   │ RETURN                                 │
│      └─────────────┘                                        │
│             │ NO                                            │
│             ▼                                               │
│  ┌─────────────────────────────────────┐                   │
│  │ elapsed = (now - dose1) / 60 sec    │                   │
│  │ earlyBandStart = 150 - 30 = 120     │                   │
│  └──────────┬──────────────────────────┘                   │
│             ▼                                               │
│  ┌─────────────────────────────────────┐                   │
│  │ elapsed < 120?                      │                   │
│  └──────────┬──────────────────────────┘                   │
│             │ YES                                           │
│             ▼                                               │
│      ┌─────────────────────────────┐                        │
│      │ waiting(150 - elapsed)      │ RETURN                 │
│      └─────────────────────────────┘                        │
│             │ NO                                            │
│             ▼                                               │
│  ┌─────────────────────────────────────┐                   │
│  │ elapsed < 150?                      │                   │
│  └──────────┬──────────────────────────┘                   │
│             │ YES                                           │
│             ▼                                               │
│      ┌─────────────────────────────┐                        │
│      │ early(150 - elapsed)        │ RETURN                 │
│      └─────────────────────────────┘                        │
│             │ NO                                            │
│             ▼                                               │
│  ┌─────────────────────────────────────┐                   │
│  │ elapsed <= 240?                     │                   │
│  └──────────┬──────────────────────────┘                   │
│             │ YES                                           │
│             ▼                                               │
│      ┌─────────────────────────────┐                        │
│      │ open(240 - elapsed)         │ RETURN                 │
│      └─────────────────────────────┘                        │
│             │ NO                                            │
│             ▼                                               │
│  ┌─────────────────────────────────────┐                   │
│  │ elapsed <= 255?                     │                   │
│  └──────────┬──────────────────────────┘                   │
│             │ YES                                           │
│             ▼                                               │
│      ┌─────────────────────────────┐                        │
│      │ grace(elapsed - 240)        │ RETURN                 │
│      └─────────────────────────────┘                        │
│             │ NO                                            │
│             ▼                                               │
│      ┌─────────────────────────────┐                        │
│      │ missed                      │ RETURN                 │
│      └─────────────────────────────┘                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Confirmation Dialog Logic

### Decision Tree

```
User Taps Dose 2 Button
         │
         ▼
    ┌────────────────────┐
    │ What is the gate   │
    │ state?             │
    └─────────┬──────────┘
              │
     ┌────────┼────────┬────────┬────────┐
     │        │        │        │        │
     ▼        ▼        ▼        ▼        ▼
  needDose1  waiting  early   open    grace   missed
     │        │        │        │        │        │
     ▼        ▼        ▼        ▼        ▼        ▼
  [BLOCK]  [BLOCK]  [DIALOG] [LOG]   [DIALOG]  [LOG]
                       │                │
                       ▼                ▼
            ┌──────────────────┐  ┌────────────┐
            │ Early Dialog:    │  │ Late Dialog│
            │ - Override now   │  │ - Override │
            │ - Remind window  │  │ - Cancel   │
            │ - Snooze 5 min   │  └────────────┘
            │ - Snooze 10 min  │
            │ - Cancel         │
            └──────────────────┘
```

### Early State Dialog Flow

```
┌─────────────────────────────────────────────────────────────┐
│ User in EARLY state (120-150 min after Dose 1)             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Tap "Dose 2 now" Button                                   │
│         │                                                   │
│         ▼                                                   │
│  ┌──────────────────────────────────────┐                  │
│  │ Show Confirmation Dialog:            │                  │
│  │                                       │                  │
│  │ "Taking Dose 2 early"                │                  │
│  │ "You're X minutes early."            │                  │
│  │                                       │                  │
│  │ [Override and log now]               │◀─┐              │
│  │ [Remind me at window start]          │  │              │
│  │ [Snooze 5 min]                       │  │              │
│  │ [Snooze 10 min]                      │  │              │
│  │ [Cancel]                             │  │              │
│  └───┬──────┬──────┬──────┬─────────┬───┘  │              │
│      │      │      │      │         │      │              │
│      ▼      ▼      ▼      ▼         ▼      │              │
│   Override Remind Snooze Snooze  Cancel    │              │
│   & Log    Window  5min  10min             │              │
│      │      │      │      │         │      │              │
│      ▼      ▼      ▼      ▼         ▼      │              │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐   ┌─────┐   │              │
│  │Log │ │Sched│ │Sched│ │Sched│   │Close│   │              │
│  │Dose│ │Notif│ │Notif│ │Notif│   │     │   │              │
│  │ +  │ │@150m│ │+5min│ │+10m │   │     │   │              │
│  │Over│ │     │ │     │ │     │   │     │   │              │
│  │ride│ │     │ │     │ │     │   │     │   │              │
│  └──┬─┘ └──┬──┘ └──┬──┘ └──┬──┘   └─────┘   │              │
│     │      │       │       │                 │              │
│     ▼      ▼       ▼       ▼                 │              │
│  ┌─────────────────────────────┐             │              │
│  │ Update UI:                  │             │              │
│  │ - Haptic warning            │             │              │
│  │ - Toast: "⚠️ Logged early"  │             │              │
│  │ - Refresh timeline          │             │              │
│  └─────────────────────────────┘             │              │
│                                               │              │
│  ┌─────────────────────────────┐             │              │
│  │ Save to EventLog:           │             │              │
│  │ - overrideType: "early"     │─────────────┘              │
│  │ - overrideMinutes: X        │                            │
│  │ - overrideReason: "user_..."│                            │
│  └─────────────────────────────┘                            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Grace State Dialog Flow

```
┌─────────────────────────────────────────────────────────────┐
│ User in GRACE state (240-255 min after Dose 1)             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Tap "Dose 2 now" Button                                   │
│         │                                                   │
│         ▼                                                   │
│  ┌──────────────────────────────────────┐                  │
│  │ Show Confirmation Dialog:            │                  │
│  │                                       │                  │
│  │ "Taking Dose 2 late"                 │                  │
│  │ "You're X minutes past the window."  │                  │
│  │                                       │                  │
│  │ [Override and log now]               │                  │
│  │ [Cancel]                             │                  │
│  └───┬──────────────────────┬───────────┘                  │
│      │                      │                              │
│      ▼                      ▼                              │
│   Override                Cancel                           │
│   & Log                                                    │
│      │                      │                              │
│      ▼                      ▼                              │
│  ┌────────┐            ┌─────┐                            │
│  │Log Dose│            │Close│                            │
│  │   +    │            │     │                            │
│  │Override│            │     │                            │
│  └───┬────┘            └─────┘                            │
│      │                                                     │
│      ▼                                                     │
│  ┌─────────────────────────────┐                          │
│  │ Update UI:                  │                          │
│  │ - Haptic warning            │                          │
│  │ - Toast: "⚠️ Logged late"   │                          │
│  │ - Refresh timeline          │                          │
│  └─────────────────────────────┘                          │
│                                                            │
│  ┌─────────────────────────────┐                          │
│  │ Save to EventLog:           │                          │
│  │ - overrideType: "late"      │                          │
│  │ - overrideMinutes: X        │                          │
│  │ - overrideReason: "user_..."│                          │
│  └─────────────────────────────┘                          │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## Override Tracking

### Database Schema

```
EventLog (SwiftData @Model)
├─ id: UUID
├─ timestamp: Date
├─ eventType: String ("dose2")
├─ gramsValue: Double?
├─ NEW: overrideType: String?      ┐
├─ NEW: overrideMinutes: Int?      │ Added for Dose 2 gating
└─ NEW: overrideReason: String?    ┘
```

### Override Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                   Override Logging Flow                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  User Confirms Override                                     │
│         │                                                   │
│         ▼                                                   │
│  ┌──────────────────────────────────┐                      │
│  │ Dose2Button callback:            │                      │
│  │ onLog(overrideKind, minutes)     │                      │
│  └───┬──────────────────────────────┘                      │
│      │                                                      │
│      ▼                                                      │
│  ┌──────────────────────────────────┐                      │
│  │ TodayViewModel.logDose2(         │                      │
│  │   overrideKind: .early/.late,    │                      │
│  │   overrideMinutes: Int           │                      │
│  │ )                                │                      │
│  └───┬──────────────────────────────┘                      │
│      │                                                      │
│      ▼                                                      │
│  ┌──────────────────────────────────┐                      │
│  │ Validate override:               │                      │
│  │ - Check current gate state       │                      │
│  │ - Allow if override provided     │                      │
│  │   OR gate.isButtonEnabled        │                      │
│  └───┬──────────────────────────────┘                      │
│      │                                                      │
│      ▼                                                      │
│  ┌──────────────────────────────────┐                      │
│  │ Haptic warning if override       │                      │
│  └───┬──────────────────────────────┘                      │
│      │                                                      │
│      ▼                                                      │
│  ┌──────────────────────────────────┐                      │
│  │ Create EventLog entry:           │                      │
│  │                                  │                      │
│  │ EventLog(                        │                      │
│  │   timestamp: Date(),             │                      │
│  │   eventType: "dose2",            │                      │
│  │   gramsValue: dose2G,            │                      │
│  │   overrideType: "early"/"late",  │◀── NEW             │
│  │   overrideMinutes: X,            │◀── NEW             │
│  │   overrideReason: "user_override"│◀── NEW             │
│  │ )                                │                      │
│  └───┬──────────────────────────────┘                      │
│      │                                                      │
│      ▼                                                      │
│  ┌──────────────────────────────────┐                      │
│  │ SwiftData saves to disk          │                      │
│  └───┬──────────────────────────────┘                      │
│      │                                                      │
│      ▼                                                      │
│  ┌──────────────────────────────────┐                      │
│  │ UI Updates:                      │                      │
│  │ - Toast message                  │                      │
│  │ - Timeline refresh               │                      │
│  │ - EventLog list update           │                      │
│  └──────────────────────────────────┘                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Example Override Records

```
┌────────────────────────────────────────────────────────────┐
│ EventLog Record - Early Override                          │
├────────────────────────────────────────────────────────────┤
│ id:               uuid-1234-...                            │
│ timestamp:        2025-11-02 00:30:00 UTC                  │
│ eventType:        "dose2"                                  │
│ gramsValue:       3.25                                     │
│ overrideType:     "early"          ┐                       │
│ overrideMinutes:  20               │ Override tracking     │
│ overrideReason:   "user_override"  ┘                       │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│ EventLog Record - Late Override                           │
├────────────────────────────────────────────────────────────┤
│ id:               uuid-5678-...                            │
│ timestamp:        2025-11-02 02:05:00 UTC                  │
│ eventType:        "dose2"                                  │
│ gramsValue:       3.25                                     │
│ overrideType:     "late"           ┐                       │
│ overrideMinutes:  5                │ Override tracking     │
│ overrideReason:   "user_override"  ┘                       │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│ EventLog Record - Normal Window (No Override)             │
├────────────────────────────────────────────────────────────┤
│ id:               uuid-9abc-...                            │
│ timestamp:        2025-11-02 01:00:00 UTC                  │
│ eventType:        "dose2"                                  │
│ gramsValue:       3.25                                     │
│ overrideType:     nil              ┐                       │
│ overrideMinutes:  nil              │ No override needed    │
│ overrideReason:   nil              ┘                       │
└────────────────────────────────────────────────────────────┘
```

---

## UI Integration Flow

### TimelineView Auto-Refresh

```
┌─────────────────────────────────────────────────────────────┐
│ TodayLogView.swift - Dose 2 Section                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  SwiftUI Body                                               │
│      │                                                      │
│      ▼                                                      │
│  ┌──────────────────────────────────────┐                  │
│  │ TimelineView(                        │                  │
│  │   .periodic(from: Date(), by: 30.0)  │◀── Refresh 30s  │
│  │ ) { context in                       │                  │
│  │   ...                                │                  │
│  │ }                                    │                  │
│  └───┬──────────────────────────────────┘                  │
│      │                                                      │
│      ▼ [Every 30 seconds]                                  │
│  ┌──────────────────────────────────────┐                  │
│  │ Recompute gate state:                │                  │
│  │                                      │                  │
│  │ let gate = computeDose2Gate(         │                  │
│  │   dose1TimeUTC: model.dose1At,       │                  │
│  │   now: context.date,                 │◀── Current time │
│  │   policy: defaultPolicy              │                  │
│  │ )                                    │                  │
│  └───┬──────────────────────────────────┘                  │
│      │                                                      │
│      ▼                                                      │
│  ┌──────────────────────────────────────┐                  │
│  │ Dose2Button(                         │                  │
│  │   gate: gate,                        │◀── Fresh state  │
│  │   plannedDoseG: ...,                 │                  │
│  │   onLog: { ... },                    │                  │
│  │   scheduleWindowStart: { ... },      │                  │
│  │   scheduleSnooze5: { ... },          │                  │
│  │   scheduleSnooze10: { ... }          │                  │
│  │ )                                    │                  │
│  └───┬──────────────────────────────────┘                  │
│      │                                                      │
│      ▼                                                      │
│  ┌──────────────────────────────────────┐                  │
│  │ Button renders with:                 │                  │
│  │ - Current state label                │                  │
│  │ - Appropriate color                  │                  │
│  │ - Enable/disable status              │                  │
│  └──────────────────────────────────────┘                  │
│                                                             │
│  ┌──────────────────────────────────────┐                  │
│  │ Automatic UI updates:                │                  │
│  │                                      │                  │
│  │ T+0s   → "Dose 2 in 150 min"        │                  │
│  │ T+30s  → "Dose 2 in 149 min"        │                  │
│  │ T+60s  → "Dose 2 in 148 min"        │                  │
│  │ ...                                  │                  │
│  │ T+120m → "⚠️ 30 min early"          │                  │
│  │ T+150m → "✓ 90 min left"            │                  │
│  │ T+240m → "⚠️ 5 min over"            │                  │
│  └──────────────────────────────────────┘                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Component Hierarchy

```
TodayLogView
    │
    ├─ ScrollView
    │   │
    │   ├─ NightRing (visual indicator)
    │   │
    │   ├─ SectionHeader("Primary Actions")
    │   │
    │   └─ ActionGrid
    │       │
    │       ├─ ActionPill("In bed now")
    │       │
    │       ├─ ActionPill("Dose 1 now")
    │       │
    │       ├─ TimelineView(.periodic)
    │       │   │
    │       │   └─ Dose2Button
    │       │       │
    │       │       ├─ Button (main)
    │       │       │   ├─ VStack
    │       │       │   │   ├─ Text (button title)
    │       │       │   │   └─ Text (status label)
    │       │       │   └─ .confirmationDialog
    │       │       │       │
    │       │       │       ├─ "Override and log now"
    │       │       │       ├─ "Remind me at window start"
    │       │       │       ├─ "Snooze 5 min"
    │       │       │       ├─ "Snooze 10 min"
    │       │       │       └─ "Cancel"
    │       │       │
    │       │       └─ @State vars (showingEarlyConfirm, etc.)
    │       │
    │       └─ ActionPill("Final wake")
    │
    └─ EventLogView (recent events)
```

---

## Safety Guardrails

### Per-Dose Limits

```
┌─────────────────────────────────────────────────────────────┐
│ NightPlan Safety Checks (NightPlanExtensions.swift)         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  extension NightPlan {                                      │
│                                                             │
│      static let perDoseMin: Double = 1.5                    │
│      static let perDoseMax: Double = 4.5                    │
│      static let nightlyMin: Double = 3.0                    │
│      static let nightlyMax: Double = 9.0                    │
│                                                             │
│      var perDoseSafe: Bool {                                │
│          dose1DisplayG >= 1.5 && dose1DisplayG <= 4.5 &&    │
│          dose2DisplayG >= 1.5 && dose2DisplayG <= 4.5       │
│      }                                                      │
│                                                             │
│      var nightlyTotalSafe: Bool {                           │
│          let total = dose1DisplayG + dose2DisplayG          │
│          return total >= 3.0 && total <= 9.0                │
│      }                                                      │
│                                                             │
│      var isSafe: Bool {                                     │
│          perDoseSafe && nightlyTotalSafe                    │
│      }                                                      │
│                                                             │
│      var safetyMessage: String {                            │
│          if isSafe {                                        │
│              return "✓ Within safe range"                   │
│          } else if !perDoseSafe {                           │
│              return "⚠️ Dose exceeds limits (1.5-4.5g)"    │
│          } else {                                           │
│              return "⚠️ Total exceeds limits (3.0-9.0g)"   │
│          }                                                  │
│      }                                                      │
│  }                                                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Safety Check Flow

```
User Attempts to Log Dose 2
         │
         ▼
    ┌────────────────────┐
    │ Check gate state   │
    └─────────┬──────────┘
              │
              ▼
    ┌────────────────────┐
    │ Gate allows?       │
    │ (enabled OR        │
    │  override provided)│
    └─────────┬──────────┘
              │ YES
              ▼
    ┌────────────────────┐
    │ Check dose amount  │
    │ plan.dose2DisplayG │
    └─────────┬──────────┘
              │
              ▼
    ┌────────────────────┐
    │ 1.5g ≤ dose ≤ 4.5g?│
    └─────────┬──────────┘
              │ YES
              ▼
    ┌────────────────────┐
    │ Check nightly total│
    │ dose1 + dose2      │
    └─────────┬──────────┘
              │
              ▼
    ┌────────────────────┐
    │ 3.0g ≤ total ≤ 9.0g?│
    └─────────┬──────────┘
              │ YES
              ▼
    ┌────────────────────┐
    │ ✓ SAFE TO LOG      │
    │ Proceed with save  │
    └────────────────────┘
              │ NO (any check)
              ▼
    ┌────────────────────┐
    │ ⚠️ SHOW WARNING    │
    │ Block logging      │
    │ Display message    │
    └────────────────────┘
```

---

## ASCII Diagrams

### Complete System Overview

```
┌───────────────────────────────────────────────────────────────────────────┐
│                        DOSE 2 GATING SYSTEM                               │
│                         Complete Data Flow                                │
└───────────────────────────────────────────────────────────────────────────┘

                                USER INTERFACE
┌───────────────────────────────────────────────────────────────────────────┐
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────┐         │
│  │ TodayLogView (Main Screen)                                  │         │
│  │                                                             │         │
│  │  ┌────────────┐   ┌────────────┐   ┌────────────┐         │         │
│  │  │ In Bed Now │   │ Dose 1 Now │   │ [DOSE 2]   │         │         │
│  │  └────────────┘   └────────────┘   └─────┬──────┘         │         │
│  │                                           │                │         │
│  │                    TimelineView (.periodic 30s)            │         │
│  │                           │                                │         │
│  └───────────────────────────┼────────────────────────────────┘         │
│                              │                                           │
└──────────────────────────────┼───────────────────────────────────────────┘
                               ▼
                    ┌──────────────────────┐
                    │  Dose2Button.swift   │
                    │  (SwiftUI Component) │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │ INPUT: Dose2Gate     │
                    │ (current state)      │
                    └──────────┬───────────┘
                               │
                ┌──────────────┼──────────────┐
                │              │              │
                ▼              ▼              ▼
         ┌──────────┐   ┌──────────┐   ┌──────────┐
         │ Button   │   │ Status   │   │ Dialog   │
         │ Title    │   │ Label    │   │ Trigger  │
         └──────────┘   └──────────┘   └─────┬────┘
                                              │
                                              ▼
                               CONFIRMATION DIALOG
┌───────────────────────────────────────────────────────────────────────────┐
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────┐         │
│  │ "Taking Dose 2 early/late"                                  │         │
│  │ "You're X minutes early/over."                              │         │
│  │                                                             │         │
│  │  [Override and log now]  [Remind at window]  [Cancel]      │         │
│  │  [Snooze 5 min]          [Snooze 10 min]                   │         │
│  └───────────┬─────────────────┬───────────┬───────────────────┘         │
│              │                 │           │                             │
└──────────────┼─────────────────┼───────────┼─────────────────────────────┘
               │                 │           │
               ▼                 ▼           ▼
        ┌──────────┐      ┌──────────┐  ┌────────┐
        │ Override │      │ Schedule │  │ Cancel │
        │ & Log    │      │ Reminder │  └────────┘
        └─────┬────┘      └──────────┘
              │
              ▼
                            STATE MACHINE
┌───────────────────────────────────────────────────────────────────────────┐
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────┐         │
│  │ Dose2Gate.swift - computeDose2Gate()                        │         │
│  │                                                             │         │
│  │  INPUT:  dose1TimeUTC, now, policy                          │         │
│  │  OUTPUT: Dose2Gate enum case                                │         │
│  │                                                             │         │
│  │  ┌──────────┐    ┌─────────┐    ┌───────┐    ┌──────┐     │         │
│  │  │needDose1 │───▶│ waiting │───▶│ early │───▶│ open │─┐   │         │
│  │  └──────────┘    └─────────┘    └───────┘    └──────┘ │   │         │
│  │                                                         │   │         │
│  │                   ┌───────┐    ┌────────┐              │   │         │
│  │              ┌────│ grace │◀───│ missed │◀─────────────┘   │         │
│  │              │    └───┬───┘    └────────┘                  │         │
│  │              │        │                                     │         │
│  │              ▼        ▼                                     │         │
│  │         [Confirm]  [Confirm]                               │         │
│  │         Required   Required                                │         │
│  └─────────────────────────────────────────────────────────────┘         │
│                                                                           │
└───────────────────────────────────────┬───────────────────────────────────┘
                                        ▼
                            VIEW MODEL LOGIC
┌───────────────────────────────────────────────────────────────────────────┐
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────┐         │
│  │ TodayViewModel.logDose2()                                   │         │
│  │                                                             │         │
│  │  1. Validate gate state or override                         │         │
│  │  2. Trigger haptic warning (if override)                    │         │
│  │  3. Create EventLog entry                                   │         │
│  │  4. Update UI (toast, refresh)                              │         │
│  └──────────────────────────┬──────────────────────────────────┘         │
│                             │                                             │
└─────────────────────────────┼─────────────────────────────────────────────┘
                              ▼
                        DATA PERSISTENCE
┌───────────────────────────────────────────────────────────────────────────┐
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────┐         │
│  │ EventLog.swift (SwiftData @Model)                           │         │
│  │                                                             │         │
│  │  ┌──────────────────────────────────────────────┐           │         │
│  │  │ id: UUID                                     │           │         │
│  │  │ timestamp: Date                              │           │         │
│  │  │ eventType: "dose2"                           │           │         │
│  │  │ gramsValue: 3.25                             │           │         │
│  │  │ overrideType: "early" / "late" / nil         │◀─ NEW    │         │
│  │  │ overrideMinutes: 20 / nil                    │◀─ NEW    │         │
│  │  │ overrideReason: "user_override" / nil        │◀─ NEW    │         │
│  │  └──────────────────────────────────────────────┘           │         │
│  │                                                             │         │
│  │  SwiftData → SQLite → App Sandbox                           │         │
│  └─────────────────────────────────────────────────────────────┘         │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘

                        REMINDER SCHEDULING
┌───────────────────────────────────────────────────────────────────────────┐
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────┐         │
│  │ NudgeScheduler (NightFlowServices.swift)                    │         │
│  │                                                             │         │
│  │  scheduleWindowStartReminder(at: Date)                      │         │
│  │  scheduleSnooze(minutes: Int)                               │         │
│  │                                                             │         │
│  │  UNUserNotificationCenter → iOS Notification System        │         │
│  └─────────────────────────────────────────────────────────────┘         │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
```

### State Transition Diagram (Detailed)

```
                     DOSE 2 STATE TRANSITIONS
                    (Time flows downward →)

    ┌───────────────────────────────────────────────────────┐
    │                   APP LAUNCH                          │
    └─────────────────────────┬─────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────────┐
                    │   Is Dose 1 logged? │
                    └──────────┬──────────┘
                               │
                    ┌──────────┴──────────┐
                    │                     │
                   NO                    YES
                    │                     │
                    ▼                     ▼
         ┌──────────────────┐   ┌────────────────────┐
         │  STATE:          │   │ Calculate elapsed: │
         │  needDose1       │   │ (now - dose1) / 60 │
         │                  │   └─────────┬──────────┘
         │ Button: DISABLED │             │
         │ Label: "Need D1" │             ▼
         └──────────────────┘   ┌────────────────────┐
                                │ elapsed < 120 min? │
                                └─────────┬──────────┘
                                          │
                                ┌─────────┴─────────┐
                               YES                 NO
                                │                   │
                                ▼                   ▼
                     ┌──────────────────┐ ┌────────────────────┐
                     │  STATE:          │ │ elapsed < 150 min? │
                     │  waiting         │ └─────────┬──────────┘
                     │                  │           │
                     │ Button: DISABLED │  ┌────────┴────────┐
                     │ Label: "X min"   │ YES               NO
                     └────────┬─────────┘  │                 │
                              │            ▼                 ▼
                              │  ┌──────────────────┐ ┌────────────────────┐
                              │  │  STATE:          │ │ elapsed <= 240 min?│
                              │  │  early           │ └─────────┬──────────┘
                              │  │                  │           │
                              │  │ Button: ENABLED  │  ┌────────┴────────┐
                              │  │ Label: "⚠️ early"│ YES               NO
                              │  │ Confirm: YES     │  │                 │
                              │  └────────┬─────────┘  ▼                 ▼
                              │           │  ┌──────────────────┐ ┌────────────────────┐
                              │           │  │  STATE:          │ │ elapsed <= 255 min?│
                              │           │  │  open            │ └─────────┬──────────┘
                              │           │  │                  │           │
                              │           │  │ Button: ENABLED  │  ┌────────┴────────┐
                              │           │  │ Label: "✓ left"  │ YES               NO
                              │           │  │ Confirm: NO      │  │                 │
                              │           │  └────────┬─────────┘  ▼                 ▼
                              │           │           │  ┌──────────────────┐ ┌──────────────────┐
                              │           │           │  │  STATE:          │ │  STATE:          │
                              │           │           │  │  grace           │ │  missed          │
                              │           │           │  │                  │ │                  │
                              │           │           │  │ Button: ENABLED  │ │ Button: ENABLED  │
                              │           │           │  │ Label: "⚠️ over" │ │ Label: "Missed"  │
                              │           │           │  │ Confirm: YES     │ │ Button: "Log     │
                              │           │           │  └────────┬─────────┘ │  missed dose"    │
                              │           │           │           │           └────────┬─────────┘
                              │           │           │           │                    │
                              └───────────┴───────────┴───────────┴────────────────────┘
                                          │
                                          ▼
                              ┌──────────────────────┐
                              │ User taps button     │
                              └───────────┬──────────┘
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    │                     │                     │
              needDose1/waiting      early/grace              open/missed
                    │                     │                     │
                    ▼                     ▼                     ▼
            ┌─────────────┐    ┌──────────────────┐    ┌─────────────┐
            │ Do nothing  │    │ Show confirmation│    │ Log         │
            │ (disabled)  │    │ dialog           │    │ immediately │
            └─────────────┘    └────────┬─────────┘    └─────────────┘
                                        │
                          ┌─────────────┼─────────────┐
                          │             │             │
                       Override      Snooze        Cancel
                          │             │             │
                          ▼             ▼             ▼
                  ┌─────────────┐ ┌─────────┐  ┌─────────┐
                  │ Log with    │ │Schedule │  │ Close   │
                  │ override    │ │reminder │  │ dialog  │
                  │ tracking    │ └─────────┘  └─────────┘
                  └─────────────┘
```

---

## Implementation Checklist

### Files Modified ✅

- [x] `Dose2Gate.swift` - State machine
- [x] `Dose2Button.swift` - UI component
- [x] `NightPlanExtensions.swift` - Safety checks
- [x] `EventLog.swift` - Override tracking schema
- [x] `TodayLogView.swift` - UI integration
- [x] `NightFlowServices.swift` - Reminder scheduling

### Features Implemented ✅

- [x] 6-state gate system
- [x] Configurable policy (window timing)
- [x] Early allow window (120-150 min)
- [x] Normal window (150-240 min)
- [x] Grace period (240-255 min)
- [x] Missed dose logging (255+ min)
- [x] Confirmation dialogs (early/late)
- [x] Override tracking in database
- [x] TimelineView auto-refresh (30s)
- [x] Window start reminders
- [x] Snooze functionality (5/10 min)
- [x] Haptic warnings
- [x] Toast messages
- [x] Per-dose safety limits
- [x] Nightly total safety limits

### Testing Coverage 📋

See `docs/ops/DOSE2_GATING_COMPLETE.md` for complete testing checklist.

---

**Document Version:** 1.0.0  
**Last Updated:** November 2, 2025  
**Status:** ✅ Implementation Complete  
**Build Status:** ✅ BUILD SUCCEEDED

**Related Documentation:**
- `docs/ops/DOSE2_GATING_COMPLETE.md` - Implementation summary
- `docs/ops/TESTING_GUIDE_COMPLETE.md` - Testing procedures
- `docs/design/UI_UX_ASCII.md` - UI specifications
- `docs/PRD_v1.2.md` - Product requirements
