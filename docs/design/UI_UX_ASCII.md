# DoseTrack UI & UX ASCII Layouts

These ASCII schematics document the primary user-facing surfaces in DoseTrack v1.1.1c. They are intended as a lightweight reference for designers and engineers while the full visual design system is developed.

---

## 1. Today Log Screen (Main App)

```
┌────────────────────────────────────────────────────────────┐
│ NAVIGATION BAR: "DoseTrack"                                │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  ┌─────────────────────────── GroupBox ─────────────────┐  │
│  │ Tonight plan                                          │
│  │ ──────────────────────────────────────────────────── │  │
│  │  Dose 1: 3.25 g                                       │  │
│  │  Dose 2: 3.25 g                                       │  │
│  │  Window: 150 – 240 min after Dose 1 (caption)         │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌───────────────┐  ┌───────────────┐                     │
│  │ Dose 1 now    │  │ Dose 2 now    │  <-- Primary actions│
│  │ [prominent]   │  │ [secondary]   │                     │
│  └───────────────┘  └───────────────┘                     │
│                                                            │
│  ┌───────────────────────┐  ┌───────────────────────────┐ │
│  │ Autofill wake         │  │ Export CSV                │ │
│  │ (Health button)       │  │ (shared sheet trigger)    │ │
│  └───────────────────────┘  └───────────────────────────┘ │
│                                                            │
│  Spacer (flex to push content upward)                      │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

**UX cues**
- Tonight plan box leads the eye with current recommended doses and timing window.
- Primary actions (Dose 1 / Dose 2) are aligned horizontally for quick repeat use.
- HealthKit and CSV utilities grouped beneath, visually secondary.
- Screen loads into `NavigationStack` (future refactor) and pre-seeded plan.

---

## 2. Today Log View Model Interaction Flow

```
┌─────────────┐
│ View Model  │
└─────┬───────┘
      │ onAppear()
      ▼
┌─────────────┐     ┌────────────────┐
│ Plan Cache  │◀────│ NightPlanRec.  │
└─────────────┘     └────────────────┘
      │
      │ logDose1() / logDose2()
      ▼
┌─────────────┐
│ DoseLogCtrl │─── saves via SwiftData
└─────────────┘
      │
      ├── consumePendingFromWidget()
      │       ▲
      │       └── AppGroupStore (widget/intents)
      │
      └── setFinalWake(date, provenance)
              ▲
              └── HealthKitManager.fetchLatestFinalWake(...)
```

---

## 3. Today Widget (Medium size)

```
┌─────────────────────────────────────────────┐
│ DoseTrack (Widget)                          │
│ ──────────────────────────────────────────  │
│ Tonight plan                                │
│ Dose 1: 3.25 g                              │
│ Dose 2: 3.25 g                              │
│ Window: 01:30 – 02:30                       │
│ (Tap targets: intents for Dose 1 / Dose 2)  │
└─────────────────────────────────────────────┘
```

Widget entries display the current plan with precomputed window start/end using the default bedtime. Widget tap targets map to App Intents which enqueue pending actions in the shared App Group.

---

## 4. Morning Survey (Spec Patch v1.2 - Phase A)

*From `review/DoseTrack_SpecPatch_v1.2_PhaseA`*

```
┌───────────────────────────────┐
│ Morning Check-In              │
├───────────────────────────────┤
│ How alert were you? [1..5]    │
│ Bathroom wakes? [Stepper/List]│
│ Notes [TextEditor]            │
│                               │
│  [ Save Survey ]              │
└───────────────────────────────┘
```

Survey data appends to the nightly log entry and appears in CSV export columns: `morning_alertness`, `bathroom_wakes`, `notes`.

---

## 5. Navigation Overview (Planned)

```
┌────────────────────────────────────────────┐
│ Tab 0: Today (log + plan)                  │
│ Tab 1: History (list of nights)            │
│ Tab 2: Settings (bedtime defaults, export) │
└────────────────────────────────────────────┘
```

Current build ships with a single-screen experience; the above navigation is proposed for future releases.

---

## 6. Color / Interaction Notes (textual)
- Primary buttons: bordered prominent (`.borderedProminent`)
- Secondary buttons: bordered neutral
- Group boxes and labels follow native system colors for accessibility.
- Dark mode inherits SwiftUI defaults; ensure contrast when adding custom palettes.

Maintain this file as the quick ASCII reference; update diagrams whenever layout shifts significantly.
