# DoseTrack Repository Architecture Schematic

**Version:** 1.1.2  
**Date:** November 4, 2025  
**Status:** Production Beta with Soft-Wake Guard System

---

## 📐 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DoseTrack v1.1.2                              │
│              Sodium Oxybate (GHB) Dose Timing Manager                │
└─────────────────────────────────────────────────────────────────────┘
                                    │
            ┌───────────────────────┼───────────────────────┐
            │                       │                       │
            ▼                       ▼                       ▼
    ┌──────────────┐       ┌──────────────┐       ┌──────────────┐
    │   iOS App    │       │    Server    │       │     Docs     │
    │  (SwiftUI)   │       │   (Node.js)  │       │ (Markdown)   │
    └──────────────┘       └──────────────┘       └──────────────┘
```

---

## 📁 Repository Structure

```
DoseTrack_v1.1.1c/
│
├── 📱 ios/                          # Core iOS Swift files (canonical source)
│   ├── Models.swift                 # SwiftData models (DoseLog, NightServiceDay)
│   ├── DoseTrackApp.swift          # App entry point
│   ├── AppPreferencesEnhanced.swift # Settings singleton (ObservableObject)
│   │
│   ├── 🎯 State Management
│   │   ├── Dose2Gate.swift         # Gate logic (ready/early/late/guard)
│   │   ├── NightServiceDay.swift   # Turnover logic (cutoff crossing)
│   │   └── WeeklySchedule.swift    # DOW scheduling profiles
│   │
│   ├── 🎨 Views
│   │   ├── ThreeCardPlanningView.swift      # Main UI (Last/Tonight/Tomorrow)
│   │   ├── NightCardViewModern.swift        # Tonight card with actions
│   │   ├── ActionButtons.swift              # In bed, Dose 1/2, Wake buttons
│   │   ├── SettingsViewEnhanced.swift       # Settings with 7 sections
│   │   └── ResetNightSheet.swift            # Reset night flow
│   │
│   ├── 🔔 Notifications & Alarms
│   │   ├── NotificationHelper.swift         # Dose 2 alarm scheduler
│   │   ├── AlarmOrchestrator.swift          # Alarm lifecycle manager
│   │   └── NightAlarmPlan.swift             # Alarm style configs
│   │
│   ├── 🛡️ Safety & Overrides
│   │   ├── GuardNoWakeSheet.swift           # Hard no-wake guard UI
│   │   ├── EarlyDose2Sheet.swift            # Early override sheet
│   │   ├── LateDose2Sheet.swift             # Late override sheet
│   │   └── Dose2OverrideSheet.swift         # Generic override UI
│   │
│   ├── 🔧 Utilities
│   │   ├── CSVExporter.swift                # Data export
│   │   ├── HealthKitManager.swift           # HealthKit integration
│   │   ├── Date+UTC.swift                   # Date helpers
│   │   └── DesignTokens.swift               # Dark mode palette
│   │
│   └── 🧪 Tests/
│       ├── NightLifecycleTests.swift        # State machine tests
│       └── UI/                              # XCTest UI tests
│
├── 📱 DoseTrackNew/                 # Xcode project workspace
│   ├── DoseTrackNew.xcodeproj/     # Xcode project file
│   └── DoseTrackNew/               # Compiled app files (mirrors ios/)
│       ├── (Same structure as ios/)
│       └── Widget/                  # iOS widget extension
│
├── 🌐 server/                       # Backend services (optional)
│   ├── src/
│   │   ├── whoop-proxy.js          # WHOOP OAuth proxy
│   │   ├── analytics.js            # Usage analytics
│   │   └── notifications.js        # Push notification service
│   ├── package.json
│   └── .env.example
│
├── 📚 docs/                         # Documentation
│   ├── README.from_user.md         # Original requirements
│   ├── PRODUCT_DESCRIPTION.md      # Product overview (SSOT narrative)
│   ├── PRD_v1.2.md                 # Product requirements
│   ├── CONTENTS.md                 # Doc index
│   ├── DOCUMENTATION_INDEX.md      # Full doc catalog
│   │
│   ├── design/                     # Design documents
│   │   ├── MAIN_SCREEN_LOGIC_MAP.md
│   │   ├── MAIN_SCREEN_NAVIGATION_MAP.md
│   │   ├── UI_UX_ASCII.md          # ASCII UI mockups
│   │   └── REPO_SCHEMATIC.md       # ← You are here
│   │
│   ├── ops/                        # Operational docs
│   │   ├── TODO.md                 # Master task list (58 items)
│   │   ├── ACTION_CHECKLIST.md     # Daily dev checklist
│   │   ├── START_HERE.md           # Onboarding guide
│   │   ├── DOSE_CALCULATION_FIX.md # ObservableObject fix
│   │   ├── SOFT_WAKE_GUARD_IMPLEMENTATION.md  # Item 60 spec
│   │   └── SOFT_WAKE_QUICK_REF.md  # Guard system quick ref
│   │
│   └── review-notes/               # Code review artifacts
│       └── SPEC_KIT_REVIEW.md
│
├── 📦 examples/
│   └── examples_sample_dosing.csv  # Sample data for testing
│
├── 🔍 review/                       # Review bundles (deliverables)
│   ├── ModernUI.md                 # Dark mode UI spec
│   └── DoseTrack_SpecKit_v1.1.1c/  # Full spec archive
│
├── 🛠️ scripts/                      # Build & automation
│   ├── demo-server.sh              # Start WHOOP proxy
│   ├── quick-test.sh               # Run unit tests
│   └── generate-app-icon.swift     # App icon generator
│
├── 🔐 .specify/                     # Spec Kit (AI-assisted specs)
│   └── memory/
│       ├── constitution.md         # Core principles (Safety First)
│       ├── spec.md                 # Technical spec
│       └── plan.md                 # Development plan
│
├── README.md                        # Main readme (SSOT architecture)
├── Package.swift                    # Swift Package Manager
└── .gitignore
```

---

## 🏗️ iOS App Architecture (MVC + SwiftUI)

```
┌─────────────────────────────────────────────────────────────────────┐
│                          App Entry Point                             │
│                      DoseTrackApp.swift                              │
└────────────────────────┬─────────────────────────────────────────────┘
                         │
                         ├─► SwiftData Container (DoseLog, NightServiceDay)
                         ├─► AppPreferencesEnhanced (Settings Singleton)
                         └─► ThreeCardPlanningView (Main UI)
                                       │
        ┌──────────────────────────────┼──────────────────────────────┐
        │                              │                              │
        ▼                              ▼                              ▼
┌──────────────┐            ┌──────────────┐            ┌──────────────┐
│  Last Night  │            │   Tonight    │            │  Tomorrow    │
│   (Read-Only)│            │  (Active)    │            │  (Planned)   │
└──────────────┘            └──────┬───────┘            └──────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    ▼                             ▼
          ┌──────────────────┐         ┌──────────────────┐
          │ NightCardViewModern│        │  Action Grid     │
          │  - Plan Card       │        │  - In bed        │
          │  - Window Bar      │        │  - Dose 1        │
          │  - Status Chips    │        │  - Dose 2 (gate) │
          │  - Recent Events   │        │  - Final wake    │
          └──────────────────┘         └──────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
┌──────────────┐      ┌──────────────────┐
│ Dose 2 Gate  │      │  Override Sheets │
│ - Ready      │──────►  - Early         │
│ - Too early  │      │  - Late          │
│ - Too late   │      │  - Guard         │
│ - Guard      │      │  - Blocked       │
│ - Need D1    │      └──────────────────┘
│ - Logged     │
└──────────────┘
```

---

## 🔄 Data Flow: Dose Logging Lifecycle

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Night Turnover (Noon Cutoff)                      │
└────────────────────────┬─────────────────────────────────────────────┘
                         │
                         ▼
        ╔════════════════════════════════════════════╗
        ║         Tonight Night Created              ║
        ║  nightKey: "2025-11-04" (YYYY-MM-DD)      ║
        ║  state: .planned                           ║
        ╚════════════════════════════════════════════╝
                         │
                         │ User taps "In bed"
                         ▼
        ╔════════════════════════════════════════════╗
        ║  bedtimeUTC logged                         ║
        ║  state: .planned → .armed                  ║
        ╚════════════════════════════════════════════╝
                         │
                         │ User taps "Dose 1" (tap-now or long-press)
                         ▼
        ╔════════════════════════════════════════════╗
        ║  dose1TimeUTC logged                       ║
        ║  dose1Grams = planDose1G (e.g., 4.5g)     ║
        ║  state: .armed → .active                   ║
        ║  🔔 Schedule Dose 2 alarms:                ║
        ║     - Window open (at windowStart)         ║
        ║     - Mid-ping (optional)                  ║
        ║     - Last call (10m before windowEnd)     ║
        ╚════════════════════════════════════════════╝
                         │
                         │ Window opens (150-240m after Dose 1)
                         ▼
        ╔════════════════════════════════════════════╗
        ║  state: .active → .windowOpen              ║
        ║  🔔 Time-sensitive notification fires      ║
        ╚════════════════════════════════════════════╝
                         │
                         │ User taps "Dose 2"
                         ▼
        ╔════════════════════════════════════════════╗
        ║  evaluateDose2Gate()                       ║
        ║  ┌─────────────────────────────────────┐   ║
        ║  │ 1. Guard check (too close to wake?) │   ║
        ║  │ 2. Need Dose 1?                     │   ║
        ║  │ 3. Already logged?                  │   ║
        ║  │ 4. Too early? (allow override)      │   ║
        ║  │ 5. Too late? (allow override)       │   ║
        ║  │ 6. Ready? → Log immediately         │   ║
        ║  └─────────────────────────────────────┘   ║
        ╚════════════════════════════════════════════╝
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
    ┌────────┐      ┌────────┐      ┌────────┐
    │ Ready  │      │Override│      │ Guard  │
    │ Log    │      │ Sheet  │      │ Sheet  │
    └───┬────┘      └───┬────┘      └───┬────┘
        │               │                │
        │               │ User confirms  │ User overrides
        │               └────────┬───────┘ with reason
        │                        │
        └────────────────────────┼──────────────────────┐
                                 ▼                      │
        ╔════════════════════════════════════════════╗  │
        ║  dose2TimeUTC logged                       ║  │
        ║  dose2Grams = planDose2G (e.g., 4.5g)     ║  │
        ║  dose2IsOverride = true/false              ║  │
        ║  dose2OverrideKind = "early"|"late"|"guard"║  │
        ║  dose2OverrideMinutes = X                  ║  │
        ║  dose2OverrideReason = "user reason"       ║  │
        ║  state: .windowOpen → .awaitWake           ║  │
        ║  🔔 Cancel all Dose 2 alarms               ║  │
        ╚════════════════════════════════════════════╝  │
                         │                              │
                         │ User wakes                   │
                         ▼                              │
        ╔════════════════════════════════════════════╗  │
        ║  finalWakeUTC logged                       ║  │
        ║  wakeReason = natural|alarm|bathroom       ║  │
        ║  state: .awaitWake → .closed               ║  │
        ╚════════════════════════════════════════════╝  │
                         │                              │
                         │ Next noon cutoff             │
                         ▼                              │
        ╔════════════════════════════════════════════╗  │
        ║  Night transitions: Tonight → Last Night   ║  │
        ║  New Tonight created (state: .planned)     ║  │
        ╚════════════════════════════════════════════╝  │
                                                        │
                         ┌──────────────────────────────┘
                         │ Guard Override Path
                         ▼
        ╔════════════════════════════════════════════╗
        ║  GuardNoWakeSheet Displayed                ║
        ║  "It's too close to your wake time"        ║
        ║  - Snooze 5/10/15m                         ║
        ║  - Proceed anyway (requires reason)        ║
        ║  - Close                                   ║
        ╚════════════════════════════════════════════╝
```

---

## 🎯 State Machine: Night Lifecycle States

```
┌─────────────────────────────────────────────────────────────────────┐
│                       DoseLog.LifecycleState                         │
└─────────────────────────────────────────────────────────────────────┘

    .planned
       │
       │ logInBed()
       ▼
    .armed
       │
       │ logDose1()
       ▼
    .active
       │
       │ Dose1 + windowStartMin elapsed
       ▼
    .windowOpen  ◄──────┐
       │                │ logDose2()
       │ Window closes  │ (within window)
       ▼                │
    .windowClosed ──────┘
       │
       │ logDose2() (override)
       ▼
    .awaitWake
       │
       │ logFinalWake()
       ▼
    .closed
       │
       │ Noon cutoff
       ▼
    .abandoned (if incomplete)

Special Transitions:
- Any state → .abandoned (noon cutoff, Reset Night)
- .awaitWake → .closed (only via logFinalWake)
```

---

## 🛡️ Safety Guardrails (Constitution Principle I)

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Safety First Philosophy                         │
└─────────────────────────────────────────────────────────────────────┘

1. Dose Amount Validation
   ┌───────────────────────────────────────────────┐
   │ Per-dose: 1.0g - 6.0g                        │
   │ Total night: ≤ 8.0g                          │
   │ Rounding step: 0.25g                         │
   └───────────────────────────────────────────────┘

2. Timing Constraints
   ┌───────────────────────────────────────────────┐
   │ Window: 150-240 min after Dose 1 (default)   │
   │ Early override: ≤180 min before window       │
   │ Late override: ≤120 min after window         │
   │ No-wake guard: 180m (workday) / 120m (offday)│
   └───────────────────────────────────────────────┘

3. State Enforcement
   ┌───────────────────────────────────────────────┐
   │ Can't log Dose 2 before Dose 1               │
   │ Can't log same event twice (idempotent)      │
   │ Can't close night without Final Wake         │
   │ Illegal transitions throw in DEBUG           │
   └───────────────────────────────────────────────┘

4. Override Audit Trail
   ┌───────────────────────────────────────────────┐
   │ Every override requires:                     │
   │  - Kind (early/late/guard)                   │
   │  - Minutes (how far from policy)             │
   │  - Reason (user-provided text)               │
   │  - Source (tap_now/time_picker/notification) │
   └───────────────────────────────────────────────┘

5. Data Integrity
   ┌───────────────────────────────────────────────┐
   │ All times stored in UTC                      │
   │ Local timezone offset preserved              │
   │ 60-second undo window with soft delete       │
   │ NSFileProtectionComplete on database         │
   └───────────────────────────────────────────────┘
```

---

## 🔔 Notification & Alarm System

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Dose 2 Soft-Wake Alarm System                     │
└─────────────────────────────────────────────────────────────────────┘

Trigger: When Dose 1 logged
    │
    ▼
┌────────────────────────────────────────────────────────────────────┐
│ NotificationHelper.scheduleDose2Alarms()                           │
│                                                                    │
│  1. Window Open Alert (time-sensitive)                            │
│     ├─ Time: Dose1 + windowStartMin (e.g., +150m)                │
│     ├─ Style: Soft (respects quiet hours) / Strong (loops)       │
│     └─ Actions: "Log Now", "Snooze 5m", "Snooze 10m"            │
│                                                                    │
│  2. Mid-Window Ping (optional)                                    │
│     ├─ Time: Dose1 + ((windowStart + windowEnd) / 2)            │
│     ├─ Enabled: dose2MidPingEnabled = true                       │
│     └─ Actions: "Log Now", "Dismiss"                             │
│                                                                    │
│  3. Last Call Alert                                               │
│     ├─ Time: Dose1 + windowEndMin - 10m (e.g., +230m)           │
│     ├─ Style: Strong (always loops)                              │
│     └─ Actions: "Log Now", "Mark Missed"                         │
└────────────────────────────────────────────────────────────────────┘
    │
    ├─► If guard cutoff reached:
    │   ├─ Cancel all pending dose2_* notifications
    │   └─ Show silent banner: "No-wake guard active"
    │
    └─► If Dose 2 logged:
        └─ Cancel all pending dose2_* notifications

Alarm Styles:
  • Off: No notifications
  • Banner: Silent notification only
  • Soft: Time-sensitive, respects quiet hours (23:00-07:00)
  • Strong: Loops until acknowledged, breaks quiet hours
```

---

## 🗂️ Data Models (SwiftData)

```swift
@Model
class DoseLog {
    // Identity
    var nightKey: String              // "YYYY-MM-DD" (service day date)
    var createdAtUTC: Date
    
    // Lifecycle
    var currentLifecycleState: LifecycleState  // .planned → .closed
    
    // Events
    var bedtimeUTC: Date?
    var dose1TimeUTC: Date?
    var dose1Grams: Double?
    var dose2TimeUTC: Date?
    var dose2Grams: Double?
    var finalWakeUTC: Date?
    
    // Override Metadata
    var dose2IsOverride: Bool
    var dose2OverrideKind: String?    // "early" | "late" | "guard"
    var dose2OverrideMinutes: Int?
    var dose2OverrideReason: String?
    
    // Wake Events
    var wakeReason: WakeReason?       // .natural | .alarm | .bathroom
    var wakeEvents: [WakeEvent]       // Multiple wakes per night
    
    // Planned Values
    var planDose1G: Double?
    var planDose2G: Double?
    
    enum LifecycleState: String, Codable {
        case planned, armed, active, windowOpen, windowClosed, 
             awaitWake, closed, abandoned
    }
}

@Model
class NightServiceDay {
    var nightKey: String              // "YYYY-MM-DD"
    var cutoffHourLocal: Int          // Default: 12 (noon)
    var createdAtUTC: Date
}

struct Dose2Policy {
    let startMin: Int                 // 150
    let endMin: Int                   // 240
    let allowEarly: Bool              // true
    let maxEarlyMin: Int              // 180
    let allowLate: Bool               // true
    let maxLateMin: Int               // 120
    let workdayNoWakeBufferMin: Int   // 180
    let offdayNoWakeBufferMin: Int    // 120
    let allowGuardOverride: Bool      // true
}
```

---

## 🎨 UI/UX Design Pattern

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Modern Dark-First Design                        │
└─────────────────────────────────────────────────────────────────────┘

Color Palette (Palette.swift)
  • bg: .black (pure black for OLED)
  • surface: gray 900 (cards)
  • text: white
  • dim: gray 400 (secondary text)
  • dose1: cyan (neon accent)
  • dose2: purple (neon accent)
  • warning: orange
  • danger: red

Typography (DesignTokens.DT)
  • pad: 16pt (card padding)
  • gap: 12pt (vertical spacing)
  • corner: 12pt (rounded corners)
  • sm/md/lg: spacing scale

Interaction Patterns
  • Tap-to-log-now: Immediate action (< 100ms)
  • Long-press (0.5s): Opens date+time picker
  • Haptic feedback: Light (success), Medium (warning), Heavy (critical)

Accessibility
  • VoiceOver: All controls labeled with gate status
  • Dynamic Type: Scales to XXL
  • Reduce Motion: Disables animations
  • 44×44pt tap targets minimum
```

---

## 🔐 Privacy & Data Security (Constitution Principle II)

```
┌─────────────────────────────────────────────────────────────────────┐
│                       Local-First Privacy                            │
└─────────────────────────────────────────────────────────────────────┘

1. Storage
   ┌───────────────────────────────────────────────┐
   │ SwiftData SQLite database                    │
   │ Location: App Container (sandboxed)          │
   │ Encryption: NSFileProtectionComplete         │
   │ Backup: iCloud (encrypted, user-controlled)  │
   └───────────────────────────────────────────────┘

2. Data Flow
   ┌───────────────────────────────────────────────┐
   │ Input → Local DB → HealthKit (optional)      │
   │ No cloud sync (except iCloud backup)         │
   │ No analytics unless user opts in             │
   └───────────────────────────────────────────────┘

3. Export Controls
   ┌───────────────────────────────────────────────┐
   │ CSV export with anonymization option         │
   │ Redact dates/times if anonymize=true         │
   │ Share via iOS share sheet only               │
   └───────────────────────────────────────────────┘

4. Permissions
   ┌───────────────────────────────────────────────┐
   │ Notifications: Required for alarms           │
   │ HealthKit: Optional (write sleep samples)    │
   │ WHOOP: Optional (OAuth proxy)                │
   └───────────────────────────────────────────────┘
```

---

## 🧪 Testing Strategy

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Test Coverage                                │
└─────────────────────────────────────────────────────────────────────┘

Unit Tests (80%+ coverage goal)
  ├── NightLifecycleTests.swift
  │   ├── State transitions (planned → closed)
  │   ├── Illegal transitions throw in DEBUG
  │   └── Idempotent operations (double-tap protection)
  │
  ├── Dose2GateTests.swift
  │   ├── Ready (within window)
  │   ├── Too early (allow/deny based on policy)
  │   ├── Too late (allow/deny based on policy)
  │   ├── Guard (workday/offday buffers)
  │   └── Need Dose 1, Already logged
  │
  ├── WindowMathTests.swift
  │   ├── Midnight crossover (no cutoff)
  │   ├── Noon cutoff (transitions nights)
  │   ├── DST spring forward (+1h)
  │   ├── DST fall back (-1h)
  │   └── Timezone changes (±3h)
  │
  └── OverrideTests.swift
      ├── Early override (within maxEarlyMin)
      ├── Late override (within maxLateMin)
      ├── Guard override (with reason required)
      └── Audit trail completeness

UI Tests (XCTest)
  ├── Happy path: In bed → D1 → D2 → Wake → Close
  ├── Early override flow (sheet → reason → confirm)
  ├── Late override flow (sheet → reason → log)
  ├── Guard override flow (sheet → reason → proceed)
  ├── Double-tap protection (dedupe within 500ms)
  └── Cutoff crossing (noon → cards advance)

Performance Tests
  ├── Cold app start < 400ms
  ├── Frame rate ≥60fps (16ms budget)
  ├── Battery usage ≤1%/24h idle
  └── BG task ≤0.1% per fire
```

---

## 🚀 Deployment & CI/CD

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Build & Release Pipeline                        │
└─────────────────────────────────────────────────────────────────────┘

Development
  ├── Git branch: updates
  ├── Local Xcode builds
  └── Manual testing on device

CI Pipeline (GitHub Actions - Pending Item 53)
  ├── Build (xcodebuild)
  ├── Unit tests (XCTest)
  ├── UI tests (XCTest UITesting)
  ├── SwiftLint (code quality)
  ├── Snapshot tests (UI regression)
  └── Coverage badge generation

TestFlight Beta
  ├── Upload to App Store Connect
  ├── Internal testing (≥10 users, ≥7 days)
  ├── Feedback collection
  └── Crash analytics (≥95% crash-free)

App Store Production
  ├── Privacy policy published
  ├── Screenshots finalized
  ├── App Review submission
  └── Phased rollout (10% → 100%)
```

---

## 📊 Key Metrics & Monitoring

```
App Health Panel (Item 45 - Pending)
  ├── Last BG task run: [timestamp]
  ├── Last Live Activity update: [timestamp]
  ├── Pending notifications: [count]
  ├── Next alert: [timestamp]
  ├── WHOOP last success: [timestamp]
  ├── HealthKit status: [authorized/denied]
  └── Battery impact: [0.8% per 24h]

Performance Budgets
  ├── App start: < 400ms
  ├── Frame time: < 16ms (60fps)
  ├── Battery: ≤ 1% per 24h idle
  ├── BG task: ≤ 0.1% per fire
  └── Memory: < 50MB peak

Quality Gates (No Ship Unless)
  ├── All CRITICAL items complete (30/30)
  ├── Unit tests ≥80% coverage
  ├── UI tests pass (happy + edge cases)
  ├── Accessibility verified (VoiceOver, Dynamic Type)
  ├── Battery ≤1% per 24h
  └── No P0 crashes (≥95% crash-free)
```

---

## 🛠️ Developer Workflow

```
Daily Development Loop
  1. Review TODO.md (58 items, 30 CRITICAL)
  2. Pull latest from updates branch
  3. Run unit tests (quick-test.sh)
  4. Implement next critical item
  5. Update TODO.md status
  6. Commit with conventional commits
  7. Push to GitHub
  8. (Future) CI runs automatically

Feature Development
  1. Create feature branch (e.g., feat/item-60-guard)
  2. Implement in ios/ folder (canonical source)
  3. Copy to DoseTrackNew/DoseTrackNew/
  4. Add files to Xcode project
  5. Build & test
  6. Update docs (PRODUCT_DESCRIPTION, PRD, TODO)
  7. Create PR (when CI ready)
  8. Merge to updates

Release Preparation
  1. Complete all CRITICAL items
  2. Run full test suite
  3. Performance profiling (Instruments)
  4. Accessibility audit
  5. Update version (Info.plist)
  6. Generate release notes
  7. Archive & upload to TestFlight
  8. Beta testing period
  9. Submit to App Review
```

---

## 📝 Documentation Standards

```
SSOT (Single Source of Truth)
  ├── Architecture: README.md
  ├── Narrative: PRODUCT_DESCRIPTION.md
  ├── Requirements: PRD_v1.2.md
  ├── Principles: .specify/memory/constitution.md
  └── Tasks: docs/ops/TODO.md

File Organization (CRITICAL - see copilot-instructions.md)
  ├── Product docs → docs/
  ├── Operational guides → docs/ops/
  ├── Design docs → docs/design/
  ├── Review notes → docs/review-notes/
  ├── Spec Kit memory → .specify/memory/
  └── NEVER create files in project root

Naming Conventions
  ├── Files: UPPER_SNAKE_CASE.md for ops guides
  ├── Files: PascalCase.swift for Swift files
  ├── Commits: conventional commits (feat:, fix:, docs:)
  └── Branches: type/description (feat/item-60-guard)
```

---

## 🎯 Current Status (as of Nov 4, 2025)

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Version 1.1.2 Progress                          │
└─────────────────────────────────────────────────────────────────────┘

Completed ✅
  ├── Item 1: Night Turnover System (95%)
  ├── Item 2: Wake Event Buttons (100%)
  ├── Item 3: Dose 2 Override (100%)
  ├── Item 50: Dose 2 Always-Tappable (100%)
  ├── Item 59: Tap-Now + Long-Press Pattern (100%)
  └── ObservableObject Fix: Dose calculation reactivity (100%)

In Progress ⏳
  └── Item 60: Soft-Wake + Guard (75%)
      ├── ✅ Guard gate logic (Dose2Gate.swift)
      ├── ✅ Guard sheet UI (GuardNoWakeSheet.swift)
      ├── ✅ Sheet integration (NightCardViewModern)
      ├── ✅ Override logging (audit trail)
      ├── ✅ All settings properties (AppPreferencesEnhanced)
      ├── ⏳ Add files to Xcode project (manual)
      ├── ⏳ Settings UI (Alarms section)
      ├── ⏳ DoseLogController (alarm scheduling)
      └── ⏳ Bell Chip (guard indicator)

Pending 📋
  ├── 29 CRITICAL items (Items 4-60 various)
  ├── 20 HIGH items (UI/UX polish)
  └── 8 MEDIUM items (operations)

Target Ship: Mid-late December 2025 (~7-8 weeks)
```

---

## 🔗 Key Documents Reference

| Document | Purpose | Location |
|----------|---------|----------|
| **README.md** | Architecture SSOT | `/README.md` |
| **PRODUCT_DESCRIPTION.md** | Product narrative | `/docs/PRODUCT_DESCRIPTION.md` |
| **PRD_v1.2.md** | Requirements | `/docs/PRD_v1.2.md` |
| **TODO.md** | Task list (58 items) | `/docs/ops/TODO.md` |
| **Constitution** | Core principles | `/.specify/memory/constitution.md` |
| **REPO_SCHEMATIC.md** | This document | `/docs/design/REPO_SCHEMATIC.md` |
| **SOFT_WAKE_GUARD_IMPLEMENTATION.md** | Item 60 spec | `/docs/ops/SOFT_WAKE_GUARD_IMPLEMENTATION.md` |
| **DOSE_CALCULATION_FIX.md** | ObservableObject fix | `/docs/ops/DOSE_CALCULATION_FIX.md` |

---

**Legend:**
- ✅ Complete
- ⏳ In progress
- 📋 Pending
- 🔴 Blocked
- ⚠️ Warning/Issue

**Last Updated:** November 4, 2025  
**Version:** 1.1.2  
**Status:** Beta with guard system integration
