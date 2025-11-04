# DoseTrack Main Screen - Navigation Breadcrumbs & UI Map

**Version:** 1.1.1c  
**Last Updated:** November 4, 2025  
**Document Type:** Visual Navigation Reference

---

## Table of Contents

1. [Screen Hierarchy Map](#screen-hierarchy-map)
2. [Navigation Paths](#navigation-paths)
3. [Modal Stack](#modal-stack)
4. [Component Tree](#component-tree)
5. [Action Routing](#action-routing)
6. [Quick Reference](#quick-reference)

---

## Screen Hierarchy Map

### Visual Tree Structure

```
App Root
│
└─ DoseTrackApp (@main)
   │
   └─ ThreeCardPlanningView ─────────────────────┐
      │                                           │
      ├─ NavigationStack                         │
      │  │                                        │
      │  ├─ Title Row                            │
      │  │  ├─ "DoseTrack" (Large Title)         │
      │  │  └─ Settings Gear Icon ────────┐      │
      │  │                                 │      │
      │  ├─ Segmented Control              │      │
      │  │  ├─ "Last Night" ────────┐      │      │
      │  │  ├─ "Tonight" ────────┐   │      │      │
      │  │  └─ "Tomorrow" ───┐    │   │      │      │
      │  │                   │    │   │      │      │
      │  └─ TabView           │    │   │      │      │
      │     │                 │    │   │      │      │
      │     ├─ NightCardView ←┘    │   │      │      │
      │     │  (Tomorrow)          │   │      │      │
      │     │  │                   │   │      │      │
      │     │  ├─ Empty State      │   │      │      │
      │     │  └─ "Create Plan" Button  │      │      │
      │     │                       │   │      │      │
      │     ├─ NightCardView ←──────┘   │      │      │
      │     │  (Tonight) ★ PRIMARY      │      │      │
      │     │  │                        │      │      │
      │     │  ├─ Header                │      │      │
      │     │  ├─ Plan Card             │      │      │
      │     │  ├─ Window Pills           │      │      │
      │     │  ├─ Status Chips           │      │      │
      │     │  ├─ Window Bar             │      │      │
      │     │  ├─ Primary Actions ───────┼──────┼──┐   │
      │     │  │  ├─ In Bed              │      │  │   │
      │     │  │  ├─ Dose 1              │      │  │   │
      │     │  │  ├─ Dose 2 ─────────────┼──────┼──┼───┼─► Dose 2 Gate System
      │     │  │  └─ Final Wake ─────────┼──────┼──┼───┼─► Wake Sheet
      │     │  │                         │      │  │   │
      │     │  ├─ Secondary Actions ─────┼──────┼──┼───┼─► Event Logging
      │     │  │  ├─ Alarm Wake          │      │  │   │
      │     │  │  ├─ Natural Wake        │      │  │   │
      │     │  │  ├─ Bathroom            │      │  │   │
      │     │  │  └─ Reset Night ────────┼──────┼──┼───┼─► Reset Sheet
      │     │  │                         │      │  │   │
      │     │  └─ Recent Events          │      │  │   │
      │     │                            │      │  │   │
      │     └─ NightCardView ←────────────┘      │  │   │
      │        (Last Night)                      │  │   │
      │        │                                 │  │   │
      │        ├─ Completed Session View        │  │   │
      │        └─ CSV Export Option             │  │   │
      │                                          │  │   │
      └─ Sheet Presentations                    │  │   │
         │                                       │  │   │
         ├─ SettingsViewEnhanced ←──────────────┘  │   │
         │  └─ (See Settings Navigation Map)       │   │
         │                                          │   │
         ├─ Dose 2 Gate Sheets ←────────────────────┘   │
         │  ├─ EarlyDose2Sheet                          │
         │  ├─ LateDose2Sheet                           │
         │  ├─ Dose2BlockedSheet                        │
         │  ├─ NeedDose1Sheet                           │
         │  └─ Dose2AlreadyLoggedSheet                  │
         │                                              │
         ├─ WakeSheetView ←────────────────────────────┘
         │  └─ (Reason, Time, Notes)
         │
         ├─ ResetNightSheet
         │  └─ (Soft/Hard, Reason, Biometric)
         │
         └─ TimeZoneRebaseAlert
            └─ (Local/Home/Manual)
```

---

## Navigation Paths

### Path Notation

- `>` = Tap/button press
- `→` = Navigate to
- `↓` = Presents sheet
- `⤴` = Dismisses sheet
- `⟲` = Returns to previous screen

---

### Primary User Journeys

#### Journey 1: Quick Log Dose 1

```
App Launch
  → ThreeCardPlanningView (Tonight selected by default)
     → NightCardViewModern
        > Tap "Dose 1" button
           → logDose1() executes
              → Haptic feedback ✓
              → Console: "✅ Logged Dose 1: 2.5g"
              → UI auto-updates (bedtime shown)
              → State changes: planned → active
              → Window notifications scheduled
```

**Breadcrumb:**
```
Home > Tonight > [Dose 1 Button]
```

---

#### Journey 2: Log Dose 2 (Within Window)

```
App Open (Tonight tab)
  → NightCardViewModern (Dose 1 already logged)
     → Window bar shows "45m remaining" (green)
        > Tap "Dose 2" button
           → tryLogDose2() executes
              → evaluateDose2Gate() returns .ready
                 → logDose2Now() executes
                    → Haptic feedback ✓
                    → Console: "✅ Logged Dose 2: 2.5g"
                    → UI auto-updates
                    → State: active → awaitWake
```

**Breadcrumb:**
```
Home > Tonight > [Dose 2 Button] → Immediate Log
```

---

#### Journey 3: Early Dose 2 Override

```
App Open (Tonight tab)
  → Window bar shows "Opens in 18 minutes" (orange)
     > Tap "Dose 2" button
        → tryLogDose2() executes
           → evaluateDose2Gate() returns .tooEarly(minutes: 18)
              → isOverrideAllowed() returns true (18 < 30)
                 ↓ Presents EarlyDose2Sheet
                    > User enters reason: "Traveling early"
                       > Tap "Confirm: 2.5g"
                          → logDose2WithOverride() executes
                             → dose2IsOverride = true
                             → dose2OverrideKind = "early"
                             → dose2OverrideMinutes = 18
                             → Haptic feedback ✓
                             ⤴ Dismisses sheet
                                → UI shows dose logged with orange badge
```

**Breadcrumb:**
```
Home > Tonight > [Dose 2 Button] > Early Override Sheet > Confirm
```

---

#### Journey 4: Reset Night (Soft)

```
App Open (Tonight tab)
  → Scroll to bottom
     > Tap "Reset Night" button (red)
        ↓ Presents ResetNightSheet
           > User enters reason: "Logged wrong time"
              > Face ID authenticates
                 > Select "Soft (archive data)"
                    > Tap "Reset Night"
                       → resetNight(mode: .soft) executes
                          → night.currentLifecycleState = .abandoned
                          → notes += "[Reset: Logged wrong time]"
                          → Haptic feedback (heavy) ✓
                          ⤴ Dismisses sheet
                             → UI shows empty state
                             → "Create Plan from Template" button appears
```

**Breadcrumb:**
```
Home > Tonight > [Reset Night Button] > Reset Sheet > [Soft] > Confirm
```

---

#### Journey 5: Navigate to Settings

```
App Open (any tab)
  → Top-right corner
     > Tap Settings Gear icon ⚙️
        ↓ Presents SettingsViewEnhanced (full-screen sheet)
           → Scrollable settings sections:
              - Profile & Safety
              - Dosing Plan
              - Dose 2 Window
              - Notifications
              - Advanced
              - Data Export
           > User adjusts settings
              > Tap "X" or swipe down
                 ⤴ Dismisses sheet
                    → Returns to previous tab
                    → Settings auto-saved
```

**Breadcrumb:**
```
Home > [Settings Gear] > Settings View > [Close]
```

---

#### Journey 6: Switch Between Horizons

```
App Open (Tonight tab selected)
  > Tap "Last Night" in segmented control
     → TabView animates to Last Night card
        → Shows completed session data
           - Final timeline (bedtime → D1 → D2 → wake)
           - CSV export option
           - Alertness rating (if logged)
     > Swipe left OR tap "Tomorrow"
        → TabView animates to Tomorrow card
           → Shows empty state or future plan
              - "Create Plan from Template" if empty
              - Planned times if template applied
```

**Breadcrumb:**
```
Home > Last Night   (viewing historical)
Home > Tonight      (active session)
Home > Tomorrow     (future planning)
```

---

## Modal Stack

### Sheet Presentation Order

When multiple sheets are queued, they present in this priority:

```
┌─────────────────────────────────────┐
│ MODAL STACK (Top = Highest Priority)│
├─────────────────────────────────────┤
│ 1. ResetNightSheet                  │ ← User-critical action
│ 2. Dose2BlockedSheet                │ ← Safety hard stop
│ 3. EarlyDose2Sheet / LateDose2Sheet │ ← Override decision
│ 4. NeedDose1Sheet                   │ ← Prerequisite action
│ 5. Dose2AlreadyLoggedSheet          │ ← Edit/undo option
│ 6. WakeSheetView                    │ ← Event logging
│ 7. SettingsViewEnhanced             │ ← Configuration
│ 8. TimeZoneRebaseAlert              │ ← System notification
└─────────────────────────────────────┘
```

**Example:** If user taps "Reset Night" while another sheet is open, the reset sheet will dismiss the current sheet and present on top.

---

### Sheet Dismissal Behavior

**Dismiss Triggers:**
1. **Cancel Button** - Tapped explicitly
2. **Swipe Down** - Interactive dismiss gesture
3. **Background Tap** - If `.interactiveDismissDisabled(false)`
4. **Confirmation** - Action completed, programmatic dismiss

**Post-Dismissal:**
- Returns to calling NightCardView
- UI refreshes if data changed
- Focus remains on same horizon tab

---

## Component Tree

### Tonight Card Breakdown (Detailed)

```
NightCardViewModern(horizon: .tonight)
├─ ScrollView
│  └─ VStack(spacing: 16)
│     │
│     ├─ [HEADER ROW] ──────────────────────────────────
│     │  HStack
│     │  ├─ Image(systemName: "moon.fill")
│     │  ├─ Text("Tonight").font(.title2.bold())
│     │  ├─ Spacer()
│     │  └─ Text("2025-11-04").font(.caption).dim
│     │
│     ├─ [PLAN CARD] ───────────────────────────────────
│     │  GroupBox("Planned Schedule")
│     │  ├─ HStack
│     │  │  ├─ VStack(left)
│     │  │  │  ├─ "Dose 1: 2.5g @ 10:30 PM"
│     │  │  │  └─ "Dose 2: 2.5g @ 2:30 AM"
│     │  │  └─ VStack(right)
│     │  │     └─ "Wake: 6:30 AM"
│     │  └─ Divider
│     │     └─ "Total: 5.0g"
│     │
│     ├─ [WINDOW PILLS] ────────────────────────────────
│     │  HStack(spacing: 12)
│     │  ├─ Pill("Window", "2h 15m left", .ok)
│     │  ├─ Pill("Logged", "4.5g", .text)
│     │  └─ Pill("Sleep", "8h total", .text)
│     │
│     ├─ [STATUS CHIPS] ────────────────────────────────
│     │  LazyVGrid(columns: 3)
│     │  ├─ Chip("✓ 1-6g", "checkmark.seal.fill", .ok)
│     │  ├─ Chip("✓ 5.0g", "function", .ok)
│     │  ├─ Chip("📒 4.5g", "book.closed", .text)
│     │  ├─ Chip("✓ Health", "heart.fill", .ok)
│     │  ├─ Chip("✓ WHOOP", "bolt.fill", .ok)
│     │  └─ Chip("85%", "clock", .ok)
│     │
│     ├─ [WINDOW BAR] ──────────────────────────────────
│     │  (only if lifecycleState == .active)
│     │  WindowBar
│     │  ├─ Progress bar (green → orange → red)
│     │  ├─ "Within window" / "Window closing"
│     │  └─ "2h 15m remaining"
│     │
│     ├─ [PRIMARY ACTIONS] ───────────────────────────────
│     │  ActionGrid(primaryActions: [...])
│     │  ├─ Row 1
│     │  │  ├─ Button("In bed", "moon.fill")
│     │  │  └─ Button("Dose 1", "pills.fill")
│     │  └─ Row 2
│     │     ├─ Button("Dose 2", "pills.circle.fill")
│     │     │  ├─ [Disabled if gate not .ready]
│     │     │  └─ Caption: "Opens in 45m" / "Log Dose 1 first"
│     │     └─ Button("Final wake", "sunrise.fill")
│     │
│     ├─ [SECONDARY ACTIONS] ─────────────────────────────
│     │  ActionGrid(secondaryActions: [...])
│     │  ├─ Row 1
│     │  │  ├─ Button("Alarm wake", "alarm.fill")
│     │  │  └─ Button("Natural wake", "bed.double.fill")
│     │  └─ Row 2
│     │     ├─ Button("Bathroom", "toilet.fill")
│     │     └─ Button("Reset night", "arrow.counterclockwise")
│     │        └─ [Red color, destructive role]
│     │
│     └─ [RECENT EVENTS] ────────────────────────────────
│        (only for tonight/lastNight)
│        GroupBox("Recent Events")
│        └─ VStack(alignment: .leading)
│           ├─ "• 10:32 PM - In bed"
│           ├─ "• 10:35 PM - Dose 1 (2.5g)"
│           └─ "•  2:47 AM - Bathroom wake"
│
└─ [SHEET MODIFIERS] ──────────────────────────────────────
   ├─ .sheet(isPresented: $showEarlyDose2Sheet) { ... }
   ├─ .sheet(isPresented: $showLateDose2Sheet) { ... }
   ├─ .sheet(isPresented: $showDose2BlockedSheet) { ... }
   ├─ .sheet(isPresented: $showNeedDose1Sheet) { ... }
   ├─ .sheet(isPresented: $showAlreadyLoggedSheet) { ... }
   ├─ .sheet(isPresented: $showWakeSheet) { ... }
   └─ .sheet(isPresented: $showResetNightSheet) { ... }
```

---

## Action Routing

### Button → Function → Sheet Flowchart

```
┌─────────────────────────────────────────────────────────────────┐
│                    PRIMARY ACTIONS                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [In Bed] ────► logInBed()                                      │
│                   └─► night.bedtimeUTC = Date()                 │
│                        └─► Save & Haptic ✓                      │
│                                                                 │
│  [Dose 1] ────► logDose1()                                      │
│                   └─► night.dose1TimeUTC = Date()               │
│                        └─► Schedule notifications               │
│                             └─► Save & Haptic ✓                 │
│                                                                 │
│  [Dose 2] ────► tryLogDose2()                                   │
│                   └─► evaluateDose2Gate()                       │
│                        ├─► .ready ────────────► logDose2Now()   │
│                        │                         └─► Haptic ✓   │
│                        │                                        │
│                        ├─► .needDose1 ────────► showNeedDose1Sheet │
│                        │                                        │
│                        ├─► .alreadyLogged ────► showAlreadyLoggedSheet │
│                        │                                        │
│                        ├─► .tooEarly(min) ───► isOverrideAllowed? │
│                        │                          ├─► YES: showEarlyDose2Sheet │
│                        │                          └─► NO:  showDose2BlockedSheet │
│                        │                                        │
│                        └─► .tooLate(min) ────► isOverrideAllowed? │
│                                                   ├─► YES: showLateDose2Sheet │
│                                                   └─► NO:  showDose2BlockedSheet │
│                                                                 │
│  [Final Wake] ► logFinalWake()                                  │
│                   └─► wakeSheetIsFinal = true                   │
│                        └─► showWakeSheet = true                 │
│                             └─► WakeSheetView appears           │
│                                  └─► User confirms              │
│                                       └─► night.finalWakeTimeUTC = time │
│                                            └─► State → closed   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                   SECONDARY ACTIONS                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [Alarm Wake] ► logAlarmWake()                                  │
│                   └─► wakeSheetIsFinal = false                  │
│                        └─► showWakeSheet = true                 │
│                             └─► WakeSheetView (non-final)       │
│                                                                 │
│  [Natural Wake] ► logNaturalWake()                              │
│                     └─► night.finalWakeTimeUTC = Date()         │
│                          └─► night.finalWakeProvenance = "natural" │
│                               └─► State → closed                │
│                                    └─► Haptic ✓                 │
│                                                                 │
│  [Bathroom] ───► logBathroom()                                  │
│                    └─► night.bathroomWakeTimesUTC.append(Date())│
│                         └─► Haptic (light) ✓                    │
│                                                                 │
│  [Reset Night] ► resetNight()                                   │
│                    └─► showResetNightSheet = true               │
│                         └─► ResetNightSheet appears             │
│                              └─► User authenticates (Face ID)   │
│                                   └─► User selects mode         │
│                                        └─► Soft/Hard reset      │
│                                             └─► Haptic (heavy) ✓│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    EMPTY STATE ACTIONS                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [Create Plan from Template] ► createPlanFromTemplate()         │
│                                  └─► weeklySchedule.suggestedDose1Time() │
│                                       └─► night.plannedDose1Time = ... │
│                                            └─► Calculate D2 & wake times │
│                                                 └─► Save & Haptic ✓ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Quick Reference

### Tap Targets & Actions

| Element | Location | Action | Result |
|---------|----------|--------|--------|
| **Settings Gear** | Top-right corner | Tap | Opens SettingsViewEnhanced |
| **Segmented Control** | Below title | Tap segment | Switches horizon tab |
| **Swipe Card** | Center area | Swipe left/right | Changes horizon |
| **In Bed** | Primary row 1, left | Tap | Logs bedtime → armed state |
| **Dose 1** | Primary row 1, right | Tap | Logs Dose 1 → active state |
| **Dose 2** | Primary row 2, left | Tap | Gate check → immediate or sheet |
| **Final Wake** | Primary row 2, right | Tap | Opens WakeSheetView (final) |
| **Alarm Wake** | Secondary row 1, left | Tap | Opens WakeSheetView (non-final) |
| **Natural Wake** | Secondary row 1, right | Tap | Logs final wake immediately |
| **Bathroom** | Secondary row 2, left | Tap | Logs bathroom event |
| **Reset Night** | Secondary row 2, right | Tap | Opens ResetNightSheet |
| **Create Plan** | Empty state center | Tap | Applies weekly schedule template |
| **Window Bar** | Below status chips | Visual only | Shows progress (no tap) |
| **Status Chip** | Grid below pills | Tap (future) | Opens detail view |
| **Recent Event** | Bottom card | Tap (future) | Edit/undo event |

---

### Keyboard Shortcuts (Future)

```
⌘1  = Last Night tab
⌘2  = Tonight tab
⌘3  = Tomorrow tab
⌘,  = Settings
⌘B  = Log In Bed
⌘D  = Log Dose 1
⌘⇧D = Try Log Dose 2
⌘W  = Log Final Wake
⌘R  = Reset Night
```

---

### State-Dependent Visibility

| Component | Visible When | Hidden When |
|-----------|--------------|-------------|
| **Plan Card** | Night exists | No night (empty state) |
| **Window Pills** | Night exists | No night |
| **Status Chips** | Night exists | No night |
| **Window Bar** | lifecycleState == .active | Any other state |
| **Primary Actions** | Always | Never |
| **Secondary Actions** | Always | Never |
| **Recent Events** | horizon == .tonight OR .lastNight | horizon == .tomorrow |
| **Empty State Card** | night == nil | Night exists |
| **Create Plan Button** | night == nil OR no plan | Plan already exists |

---

### Color Legend

**Palette Colors Used:**

| Color | Hex | Usage |
|-------|-----|-------|
| `Palette.bg` | `#000000` | Background (pure black) |
| `Palette.surface` | `#1C1C1E` | Card backgrounds |
| `Palette.text` | `#FFFFFF` | Primary text |
| `Palette.dim` | `#8E8E93` | Secondary text, captions |
| `Palette.ok` | `#34C759` | Green - safe, within limits |
| `Palette.warn` | `#FF9500` | Orange - approaching limits |
| `Palette.danger` | `#FF3B30` | Red - exceeded limits |
| `Palette.accent` | `#007AFF` | Blue - interactive elements |

---

### Navigation State Persistence

**Remembered Across Sessions:**
- ✅ Last selected horizon (Tonight/Last Night/Tomorrow)
- ✅ Scroll position in settings
- ✅ Expanded/collapsed sections in settings

**Not Persisted:**
- ❌ Sheet presentation states (all reset on app launch)
- ❌ Temporary UI states (banners, toasts)

---

### Accessibility Labels

**VoiceOver Announcements:**

| Element | Label | Hint |
|---------|-------|------|
| In Bed | "In bed" | "Logs your bedtime for tonight" |
| Dose 1 | "Dose one" | "Logs Dose 1 at 2.5 grams" |
| Dose 2 | "Dose two" | "Logs Dose 2 if within window" |
| Final Wake | "Final wake" | "Logs your final wake time" |
| Alarm Wake | "Alarm wake" | "Records alarm wake event" |
| Natural Wake | "Natural wake" | "Logs natural wake as final" |
| Bathroom | "Bathroom" | "Records bathroom wake event" |
| Reset Night | "Reset night" | "Resets current night session" |
| Settings Gear | "Settings" | "Opens app settings" |

---

## Document Version

**Version:** 1.0  
**Created:** November 4, 2025  
**Companion Document:** `MAIN_SCREEN_LOGIC_MAP.md`

---

**End of Navigation Map**
