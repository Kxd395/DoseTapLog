# DoseTrack v1.1.1c

**📍 Location:** `README.md` (Project Root)  
**📚 Quick Links:** [Documentation Index](docs/DOCUMENTATION_INDEX.md) | [Product Description](docs/PRODUCT_DESCRIPTION.md) | [PRD](docs/PRD_v1.2.md) | [Testing Guide](docs/ops/TESTING_GUIDE_COMPLETE.md)

---

Single source of truth for the DoseTrack bundle: a local-first iOS sleep dosing app with a companion WHOOP proxy service.

**📊 Status:** ✅ BUILD SUCCEEDED (Nov 2, 2025)  
**🎯 Latest Features:** 
- ⭐ Dose 2 Flexible Gating System (State Machine + Confirmations)
- ✅ Night Flow Integration (Widgets + Services + Live Activities)
- ✅ EventLog System (Search, Filter, Export)
- ✅ Widget Extension Support

**📚 Documentation:** 
- **Product Overview:** [`docs/PRODUCT_DESCRIPTION.md`](docs/PRODUCT_DESCRIPTION.md)
- **Technical Spec:** [`.specify/memory/spec.md`](.specify/memory/spec.md)
- **Complete Index:** [`docs/DOCUMENTATION_INDEX.md`](docs/DOCUMENTATION_INDEX.md)

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
├─ DoseTrackIOS/ .................... Active Xcode project ⭐
│  ├─ DoseTrackIOS.xcodeproj
│  └─ DoseTrackIOS/
│     ├─ DoseTrackApp.swift ......... App entry point
│     ├─ TodayLogView.swift ......... Main screen (ViewModel pattern)
│     ├─ EventLogView.swift ......... Event history UI
│     ├─ Dose2Gate.swift ............ State machine (NEW)
│     ├─ Dose2Button.swift .......... Gating UI component (NEW)
│     ├─ TodayWidgets.swift ......... UI components (rings, banners)
│     ├─ NightFlowServices.swift .... Window + notification logic
│     ├─ DoseWindowActivity.swift ... Live Activity support
│     ├─ AppIntents+*.swift ......... Siri shortcuts
│     ├─ EventLog.swift ............. SwiftData model
│     ├─ DoseLogController.swift .... Persistence layer
│     └─ Widget/ .................... Widget extension
│
├─ server/ .......................... Node.js WHOOP proxy
│  ├─ index.js ...................... Express server
│  ├─ package.json .................. Dependencies
│  ├─ .env.example .................. Config template
│  └─ README_server.md .............. Server setup guide
│
├─ docs/ ............................ Documentation
│  ├─ DOCUMENTATION_INDEX.md ........ Complete doc index (NEW)
│  ├─ PRODUCT_DESCRIPTION.md ........ Product narrative
│  ├─ PRD_v1.2.md ................... Requirements
│  ├─ SECRETS.md .................... API keys & config (private)
│  ├─ design/
│  │  ├─ DOSE2_LOGIC_FLOW.md ........ Dose 2 logic diagrams (NEW)
│  │  ├─ LOGIC_MAP.md ............... System logic flows
│  │  └─ UI_UX_ASCII.md ............. UI specifications
│  └─ ops/
│     ├─ START_HERE.md .............. Setup guide
│     ├─ TESTING_GUIDE_COMPLETE.md .. Test procedures
│     ├─ DOSE2_GATING_COMPLETE.md ... Dose 2 implementation (NEW)
│     └─ NIGHT_FLOW_INTEGRATION_COMPLETE.md .. Night flow features
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
   cd DoseTrackIOS
   open DoseTrackIOS.xcodeproj
   ```

2. **Set bundle IDs:**
   - App: `AxxessPhilly.DoseTrackIOS`
   - Widget: `AxxessPhilly.DoseTrackIOS.DoseWidgetExtension`
   - App Group: `group.AxxessPhilly.DoseTrackIOS`

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
   xcodebuild build -scheme DoseTrackIOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
   
   # Or use Xcode: Product > Run (⌘R)
   ```

6. **Run tests:**
   ```bash
   xcodebuild test -scheme DoseTrackIOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
   ```

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

---

## 6. Development Workflow
| Task | Command |
|------|---------|
| Run proxy | `npm start` (inside `server/`) |
| Proxy tests | `npm test` (add integration mocks) |
| iOS unit tests | `xcodebuild test -scheme DoseTrack -destination "platform=iOS Simulator,name=iPhone 15"` |
| Lint (planned) | `swift-format`, `swiftlint`, `eslint`/`biome` (see TODO) |
| Regenerate CSV export sample | `swift Run` helper (to be added) |

Planned improvements include continuous integration, automated linting, and SwiftFormat onboarding. Track open tasks in `docs/ops/ACTION_CHECKLIST.md`.

---

## 7. Current Gaps & Roadmap
- **SwiftUI architecture:** introduce a `TodayLogViewModel`, main-actor guarantees, and robust error surfacing for HealthKit + persistence.
- **Night anchoring logic:** fix current off-by-one behavior after midnight and add regression tests.
- **Proxy hardening:** modularize the code, validate config on boot, add pagination guards and request metrics.
- **Secrets management:** adopt 1Password/Bitwarden vault for WHOOP credentials, encode API key rotation playbook.
- **Testing:** build out XCTest coverage (recommender, CSV exporter, controller) and HTTP contract tests with mocked WHOOP responses.

---

## 8. Document Index
- `docs/SECRETS.md` – secret and configuration management (new SSOT companion).
- `docs/PRODUCT_DESCRIPTION.md` – consolidated narrative for v1.2 scope.
- `docs/design/UI_UX_ASCII.md` – ASCII schematics of key UI surfaces.
- `docs/design/LOGIC_MAP.md` – system logic and data flow diagrams.
- `docs/ops/START_HERE.md` – quickstart orientation pointing back to this README.
- `docs/ops/ACTION_CHECKLIST.md` – prioritized engineering tasks aligned with the roadmap.
- `docs/ops/EVERYTHING_WORKING.md` – verification log template; run tests and update before releases.
- `docs/PRD_v1.2.md` – product requirements.
- `docs/v1.1.1b.md` – historical release notes.

Treat this README as the authoritative source for architecture and setup. Update it whenever implementation details change.
