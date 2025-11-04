# DoseTrack v1.1.1c

**📍 Location:** `README.md` (Project Root - SSOT)  
**📚 Quick Links:** [Product Description](docs/PRODUCT_DESCRIPTION.md) | [PRD](docs/PRD_v1.2.md) | [TODO](docs/ops/TODO.md) | [Testing Guide](docs/ops/TESTING_GUIDE.md)

---

Single source of truth for the DoseTrack bundle: a local-first iOS sleep dosing app with a companion WHOOP proxy service.

**📊 Status:** ✅ MODERN UI ACTIVE (Nov 3, 2025)  
**🎯 Current Work:** 
- ⭐ Modern Dark Mode UI (Three-card planning view)
- ✅ Night Turnover Integration Complete
- ✅ Dose 2 Gating System (State Machine + Confirmations)
- 🚧 50-item Production Roadmap (see [TODO.md](docs/ops/TODO.md))

**📚 Essential Docs:** 
- **Start Here:** [`docs/ops/START_HERE.md`](docs/ops/START_HERE.md) - Setup & onboarding
- **Product Overview:** [`docs/PRODUCT_DESCRIPTION.md`](docs/PRODUCT_DESCRIPTION.md)
- **Task List:** [`docs/ops/TODO.md`](docs/ops/TODO.md) - 50 items to production
- **Latest Review:** [`docs/review-notes/update3.md`](docs/review-notes/update3.md) - UI/UX feedback

---

## Table of Contents

1. [Product Overview](#1-product-overview)
2. [Architecture Snapshot](#2-architecture-snapshot)
3. [Repository Layout](#3-repository-layout)
4. [Local Setup](#4-local-setup)
5. [Secrets & Configuration](#5-secrets--configuration)
6. [Key Features](#6-key-features) ⭐ NEW
7. [Documentation Map](#7-documentation-map) ⭐ NEW
8. [Development Workflow](#8-development-workflow)

---

## 1. Product Overview

- **Goal:** Help clinicians and patients plan and log two-phase sleep dosing with on-device storage and export-ready records.
- **Platforms:** Native iOS app (SwiftUI + SwiftData) with Widget and Siri Shortcuts support; optional Node.js proxy to reach the WHOOP developer API.
- **Data ownership:** All patient data remains on-device. The proxy only relays WHOOP responses and enforces API usage policy.
- **Key Workflows:** nightly plan recommendation, quick dosing capture (app, widget, intents), HealthKit wake import, CSV export for clinicians.

### Core Principles (Constitution)

From [`.specify/memory/constitution.md`](.specify/memory/constitution.md):

1. **Safety First** - Dose limits (1.5-4.5g per dose, 3.0-9.0g nightly)
2. **Local-First Privacy** - All data on-device, no cloud sync
3. **Clinician-Ready Data** - CSV export with full audit trail

---

## 2. Architecture Snapshot

### System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      DOSETRACK SYSTEM                       │
│                    Complete Architecture                    │
└─────────────────────────────────────────────────────────────┘

                         iOS APP
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ TodayLogView │  │ EventLogView │  │ WidgetKit    │     │
│  │ (Main UI)    │  │ (History)    │  │ (Home Screen)│     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                 │                  │             │
│         └─────────────────┼──────────────────┘             │
│                           ▼                                │
│                 ┌──────────────────┐                       │
│                 │ TodayViewModel   │                       │
│                 │ (@Observable)    │                       │
│                 └────────┬─────────┘                       │
│                          │                                 │
│         ┌────────────────┼────────────────┐               │
│         ▼                ▼                ▼               │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐         │
│  │ Dose2Gate  │  │ NightFlow  │  │ EventLog   │         │
│  │ (State)    │  │ Services   │  │ (SwiftData)│         │
│  └────────────┘  └────────────┘  └────────────┘         │
│                                                           │
└───────────────────────────────────────────────────────────┘
                          │
                          ▼
                  ┌──────────────┐
                  │ HealthKit    │
                  │ Notifications│
                  └──────────────┘

                    NODE.JS PROXY
┌─────────────────────────────────────────────────────────────┐
│  Express Server (server/index.js)                          │
│                                                             │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐          │
│  │ CORS       │  │ Rate Limit │  │ API Routes │          │
│  │ Middleware │  │ (100/15min)│  │ /sleep     │          │
│  └────────────┘  └────────────┘  └────────────┘          │
│                                           │                │
│                                           ▼                │
│                                   ┌──────────────┐        │
│                                   │ WHOOP API    │        │
│                                   │ (External)   │        │
│                                   └──────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

### iOS client

- **`SwiftUI`** front end with `TodayLogView` (main screen) and `EventLogView` (history)
- **`SwiftData`** model `EventLog` with override tracking (type, minutes, reason)
- **`DoseLogController`** encapsulates persistence; view model handles UI logic
- **`NightPlanRecommender`** computes dose split with clamped guardrails and 0.25g rounding
- **`HealthKitManager`** wraps sleep analysis reads to autofill wake time
- **`CSVExporter`** emits device-local CSV files for sharing
- **`WidgetKit`** target surfaces tonight's plan on the home screen
- **`Dose2Gate`** ⭐ NEW - State machine for Dose 2 timing (6 states)
- **`Dose2Button`** ⭐ NEW - UI component with confirmation dialogs
- **`NightFlowServices`** - Window calculations and notification scheduling

### WHOOP proxy service

- Express app (`server/index.js`) with CORS, API key enforcement, rate limiting (100/15min)
- Provides `/api/sleep/latest` and `/api/aggregates/7days`
- Pagination helper for WHOOP sleep records
- Future work: TypeScript typings, improved pagination safety, configuration validation

### Documents & assets

- **`docs/`** - Product docs, PRD, design specs, operational guides
  - `docs/design/` - Logic maps and UI specs
  - `docs/ops/` - Testing, setup, completion reports
  - `docs/review-notes/` - Analysis and reviews
- **`review/`** - Vendor review kits for reference
- **`scripts/`** - Helper tooling (`demo-server.sh`, `quick-test.sh`)
- **`.specify/memory/`** - Spec Kit documents (constitution, spec, plan)

---

## 3. Repository Layout

```
DoseTrack_v1.1.1c/
│
├─ README.md ........................ This file (architecture overview)
│
├─ ios/ ............................. Original Swift files (legacy)
│  ├─ AppGroupStore.swift
│  ├─ DoseLogController.swift
│  ├─ Models.swift
│  ├─ NightPlanRecommender.swift
│  ├─ TodayLogView.swift
│  └─ Tests/DoseLogTests.swift
│
├─ DoseTrackNew/ .................... Active Xcode project ⭐ CURRENT
│  ├─ DoseTrackNew.xcodeproj
│  └─ DoseTrackNew/
│     ├─ DoseTrackApp.swift ......... App entry point
│     ├─ ThreeCardPlanningView.swift  Main screen (Last/Tonight/Tomorrow)
│     ├─ NightCardViewModern.swift .. Modern dark UI card (NEW)
│     ├─ TodayViewModel.swift ....... Business logic
│     ├─ Models.swift ............... SwiftData models
│     ├─ DoseLogController.swift .... Persistence + lifecycle
│     ├─ NightPlanRecommender.swift . Dose split logic
│     ├─ DesignTokens.swift ......... Dark mode palette (NEW)
│     ├─ WindowBar.swift ............ Compact progress bar (NEW)
│     ├─ StatusChip.swift ........... Modern status indicators (NEW)
│     ├─ ActionButtons.swift ........ Primary/secondary buttons (NEW)
│     ├─ AppPreferencesEnhanced.swift Settings + observations
│     ├─ NightAlarmPlan.swift ....... Notification scheduling
│     ├─ NightServiceDay.swift ...... Day turnover logic
│     └─ Widget/ .................... Widget extension
│
├─ server/ .......................... Node.js WHOOP proxy
│  ├─ index.js ...................... Express server
│  ├─ package.json .................. Dependencies
│  ├─ .env.example .................. Config template
│  └─ README_server.md .............. Server setup guide
│
├─ docs/ ............................ Documentation
│  ├─ PRODUCT_DESCRIPTION.md ........ Product narrative (SSOT)
│  ├─ PRD_v1.2.md ................... Requirements (SSOT)
│  ├─ SECRETS.md .................... API keys & config (private, never commit)
│  ├─ CONTENTS.md ................... Documentation index
│  ├─ design/
│  │  ├─ ModernUI.md ................ Design system spec (NEW)
│  │  ├─ LOGIC_MAP.md ............... System logic flows
│  │  └─ UI_UX_ASCII.md ............. UI specifications
│  ├─ ops/ ⭐ OPERATIONAL DOCS (4 active files)
│  │  ├─ TODO.md .................... 50-item production roadmap (SSOT)
│  │  ├─ START_HERE.md .............. Setup & onboarding guide
│  │  ├─ TESTING_GUIDE.md ........... Test procedures
│  │  ├─ VERIFICATION_CHECKLIST.md .. Release checklist
│  │  └─ archive/ ................... Historical docs (85+ files)
│  └─ review-notes/
│     ├─ update3.md ................. Latest UI/UX review (Nov 3, 2025)
│     ├─ SPEC_KIT_REVIEW.md ......... Spec Kit analysis
│     └─ archive/ ................... Older reviews
│
├─ examples/ ........................ Sample data
│  └─ examples_sample_dosing.csv .... CSV schema example
│
├─ scripts/ ......................... Helper scripts
│  ├─ demo-server.sh ................ Start demo server
│  └─ quick-test.sh ................. Quick smoke tests
│
└─ .specify/ ........................ Spec Kit integration
   └─ memory/
      ├─ constitution.md ............ Core principles
      ├─ spec.md .................... Technical specification
      └─ plan.md .................... Project plan
```

---

## 4. Local Setup

### Prerequisites

- **macOS** with Xcode 15+ and command line tools
- **Node.js** 18+ with npm or pnpm
- **WHOOP Developer** sandbox credentials (token) for proxy testing
- **HealthKit-enabled iPhone** for end-to-end validation

### iOS app

1. **Open project:**
   ```bash
   cd DoseTrackNew
   open DoseTrackNew.xcodeproj
   ```

2. **Set bundle IDs:**
   - App: `com.jefferson.dosetrack`
   - Widget: `com.jefferson.dosetrack.widget`
   - App Group: `group.com.jefferson.dosetrack`

3. **Enable capabilities:**
   - HealthKit (read Sleep Analysis)
   - App Groups
   - Push Notifications

4. **Configure Info.plist:**
   - `NSHealthShareUsageDescription` - "Track sleep wake times"
   - `NSHealthUpdateUsageDescription` - "Log dose events"

5. **Build and run:**
   ```bash
   # From command line
   cd DoseTrackNew
   xcodebuild build -scheme DoseTrackNew -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
   
   # Or use Xcode: Product > Run (⌘R)
   ```

6. **Run tests:**
   ```bash
   xcodebuild test -scheme DoseTrackNew -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
   ```

**See also:** [`docs/ops/START_HERE.md`](docs/ops/START_HERE.md) for detailed setup

### WHOOP proxy

```bash
cd server
npm install
cp .env.example .env        # fill in secrets per docs/SECRETS.md
npm start                   # serves http://localhost:3000
```

**Test endpoints:**
```bash
curl http://localhost:3000/health
curl -H "X-API-Key: your-key" http://localhost:3000/api/sleep/latest
```

Use `curl` or the quick test script to hit `/health` and authenticated endpoints. The service should stay local during pilot phases.

---

## 5. Secrets & Configuration

---

## 1. Product Overview
- **Goal:** Help clinicians and patients plan and log two-phase sleep dosing with on-device storage and export-ready records.
- **Platforms:** Native iOS app (SwiftUI + SwiftData) with Widget and Siri Shortcuts support; optional Node.js proxy to reach the WHOOP developer API.
- **Data ownership:** All patient data remains on-device. The proxy only relays WHOOP responses and enforces API usage policy.
- **Key Workflows:** nightly plan recommendation, quick dosing capture (app, widget, intents), HealthKit wake import, CSV export for clinicians.

---

## 2. Architecture Snapshot
### iOS client
- `SwiftUI` front end currently driven by a `TodayLogView` screen.
- `SwiftData` model `DoseLog` keyed by derived night identifier.
- `DoseLogController` encapsulates persistence; upcoming refactor will push logic into a view model and make the controller main-actor safe.
- `NightPlanRecommender` computes dose split with clamped guardrails and 0.25 g display rounding.
- `HealthKitManager` wraps sleep analysis reads to autofill wake time.
- `CSVExporter` emits device-local CSV files for sharing.
- `WidgetKit` target surfaces tonight’s plan on the home screen; Siri intents enqueue quick actions through the shared app group.

### WHOOP proxy service
- Express app (`server/index.js`) with CORS, API key enforcement, rate limiting, and pagination helper for WHOOP sleep records.
- Provides `/api/sleep/latest` and `/api/aggregates/7days`.
- Future work: split into modules, add TypeScript typings, improve pagination safety, and centralize configuration validation.

### Documents & assets
- `docs/` holds the PRD, secrets guide, and operational docs (`docs/ops/`, `docs/review-notes/`).
- `review/` retains vendor review kits for reference.
- `scripts/` contains helper tooling such as `demo-server.sh`, `quick-test.sh`, and installation checks.

---

## 3. Repository Layout
```
ios/                Swift app, widget, tests
ios/Tests/          XCTest bundle (expand with new coverage)
server/             Express proxy (Node 18+)
docs/               Product docs, PRD, secrets guide
examples/           Sample CSVs or data artifacts
review/             Historical review kits (read-only)
scripts/            Helper shell scripts (if added)
```

---

## 4. Local Setup
### Prerequisites
- macOS with Xcode 15+ and command line tools
- Node.js 18+ with npm or pnpm
- WHOOP Developer sandbox credentials (token) for proxy testing
- HealthKit-enabled iPhone for end-to-end validation

### iOS app
1. Open the project in Xcode (or add files to an existing workspace).
2. Set bundle IDs:
   - App: `com.jefferson.dosetrack`
   - Widget: `com.jefferson.dosetrack.widget`
   - App Group: `group.com.jefferson.dosetrack`
3. Enable capabilities: HealthKit (read Sleep Analysis), App Groups, Push Notifications (alerts).
4. Configure required Info.plist strings (e.g., `NSHealthShareUsageDescription`).
5. Run `Product > Test` with an in-memory SwiftData container (tests to be expanded).

### WHOOP proxy
```bash
cd server
npm install
cp .env.example .env        # fill in secrets per docs/SECRETS.md
npm start                   # serves http://localhost:3000
```
Use `curl` or the quick test script to hit `/health` and authenticated endpoints. The service should stay local during pilot phases.

---

## 5. Secrets & Configuration
Sensitive configuration is documented in `docs/SECRETS.md`. Highlights:
- `server/.env` – API gateway key, WHOOP auth token, rate limit tuning.
- iOS – bundle identifiers, app group identifiers, widget identifiers, optional remote config seed.
- Storage guidance covers Git hygiene, macOS keychain, and rotation strategy.

Follow that document before committing or distributing builds.

## 6. Key Features ⭐ v1.1.1c

### Modern UI (November 2025)
- **Dark Mode First** - Custom palette (#0F1117 background)
- **Three-Card Planning** - Last Night / Tonight / Tomorrow navigation
- **Compact WindowBar** - Replaces large countdown ring
- **Status Chips** - Modern rounded indicators for safety bounds and totals
- **Build 1.1.2** - Visible version indicator

### Night Turnover System
- **Service Cutoff** - Automatic day rollover at local noon
- **Lifecycle States** - Planned → Active → AwaitWake → Closed/Abandoned
- **Timezone Safety** - DST and travel detection

### Dose 2 Gating
- **Window Enforcement** - 210-245 min after Dose 1 (configurable)
- **Early/Late Overrides** - Require reason + minutes with validation
- **State Machine** - 6 states (WaitD1, BeforeWindow, InWindow, AfterWindow, Late, Logged)

### Data & Export
- **SwiftData Models** - On-device storage with lifecycle tracking
- **CSV Export** - Clinician-ready format with timestamps
- **Audit Trail** - Override tracking (type, minutes, reason)

### Integrations
- **HealthKit** - Auto-import sleep wake times
- **Widgets** - Home screen tonight's plan
- **Live Activities** - Dynamic Island support (planned)
- **WHOOP Proxy** - Optional Node.js service for sleep data

---

## 7. Documentation Map

### For New Developers
1. **Start:** [`docs/ops/START_HERE.md`](docs/ops/START_HERE.md)
2. **Architecture:** This README (you are here)
3. **Setup:** Section 4 above + START_HERE.md
4. **Testing:** [`docs/ops/TESTING_GUIDE.md`](docs/ops/TESTING_GUIDE.md)

### For Product/Clinical
1. **Overview:** [`docs/PRODUCT_DESCRIPTION.md`](docs/PRODUCT_DESCRIPTION.md)
2. **Requirements:** [`docs/PRD_v1.2.md`](docs/PRD_v1.2.md)
3. **UI Specs:** [`docs/design/UI_UX_ASCII.md`](docs/design/UI_UX_ASCII.md)
4. **Latest Review:** [`docs/review-notes/update3.md`](docs/review-notes/update3.md)

### For Active Development
1. **Task List:** [`docs/ops/TODO.md`](docs/ops/TODO.md) - 50 items
2. **Design System:** [`docs/design/ModernUI.md`](docs/design/ModernUI.md)
3. **Secrets:** [`docs/SECRETS.md`](docs/SECRETS.md) (never commit!)
4. **Release Checklist:** [`docs/ops/VERIFICATION_CHECKLIST.md`](docs/ops/VERIFICATION_CHECKLIST.md)

### Constitutional Principles
See [`.specify/memory/constitution.md`](.specify/memory/constitution.md):
1. **Safety First** - Dose limits enforced
2. **Local-First Privacy** - No cloud sync
3. **Clinician-Ready Data** - Export with full audit trail

---

## 8. Development Workflow

| Task | Command |
|------|---------|
| Open project | `cd DoseTrackNew && open DoseTrackNew.xcodeproj` |
| Build | `⌘R` in Xcode or `xcodebuild build -scheme DoseTrackNew` |
| Run tests | `⌘U` in Xcode or `xcodebuild test -scheme DoseTrackNew` |
| Run proxy | `cd server && npm start` |
| Quick test | `./scripts/quick-test.sh` |
| View TODO | `cat docs/ops/TODO.md` |

### Active Work (November 2025)

**Current Sprint:** UI Polish & Foundations
- ✅ Modern UI integrated (dark mode, three-card view)
- 🚧 Window status pill + next alert chip (Item 1)
- 🚧 Dose 2 disabled reason caption (Item 2)
- 🚧 Safety chips - planned vs logged (Item 3)

**Next Sprint:** State Machine & Testing
- ClockProvider & time abstractions (Item 27)
- Authoritative state chart (Item 26)
- Unit tests - state transitions (Item 37)

**See:** [`docs/ops/TODO.md`](docs/ops/TODO.md) for complete 50-item roadmap

---

## 9. Current Gaps & Roadmap

### High Priority (1-2 weeks)
- **Window Status Indicators** - Live countdown pills (HH:MM:SS)
- **Disabled Button Explanations** - "Opens in 17m" captions
- **Data Source Chips** - Health/WHOOP/Notifications status
- **Time Abstractions** - ClockProvider for testable time logic

### Medium Priority (2-4 weeks)
- **Settings Enhancements** - Split options, derived times, alarm styles
- **Wake Event Sheets** - Log wake at… with seconds precision
- **Haptics & Polish** - Feedback on actions, long-press edits
- **Accessibility** - VoiceOver, Dynamic Type XXL support

### Foundation Work (Ongoing)
- **State Chart Documentation** - Lifecycle transitions + guards
- **Feature Flags** - Kill switches for Tonight features
- **Audit Trail** - Soft delete + edit provenance
- **Background Tasks** - Service cutoff rollover at noon

### Testing & Quality
- **Unit Tests** - ≥80% coverage target
- **UI Tests** - Critical user flows
- **DST/Timezone Tests** - ±1h and ±3h edge cases
- **Performance** - <400ms cold start, <16ms render

**See:** [`docs/ops/TODO.md`](docs/ops/TODO.md) for complete breakdown

---

## 10. Document Index

### Essential (SSOT)
- **README.md** (this file) - Architecture & setup
- `docs/PRODUCT_DESCRIPTION.md` - Product narrative
- `docs/PRD_v1.2.md` - Requirements
- `docs/ops/TODO.md` - 50-item task list
- `docs/SECRETS.md` - Configuration (never commit!)

### Operational
- `docs/ops/START_HERE.md` - New developer onboarding
- `docs/ops/TESTING_GUIDE.md` - QA procedures
- `docs/ops/VERIFICATION_CHECKLIST.md` - Release gates
- `docs/ops/archive/` - Historical docs (85+ files)

### Design & Specs
- `docs/design/ModernUI.md` - Design system
- `docs/design/UI_UX_ASCII.md` - UI schematics
- `docs/design/LOGIC_MAP.md` - System flows
- `.specify/memory/constitution.md` - Core principles
- `.specify/memory/spec.md` - Technical spec

### Reviews & Analysis
- `docs/review-notes/update3.md` - Latest UI review (Nov 3, 2025)
- `docs/review-notes/SPEC_KIT_REVIEW.md` - Spec Kit analysis
- `docs/review-notes/archive/` - Older reviews

---

**Treat this README as the authoritative source for architecture and setup. Update it whenever implementation details change.**

**Last Updated:** November 3, 2025  
**Version:** 1.1.1c (Build 1.1.2)  
**Active Project:** DoseTrackNew/DoseTrackNew.xcodeproj
