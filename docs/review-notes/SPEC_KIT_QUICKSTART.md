# DoseTrack Spec Kit Quick Start

**🎯 Goal:** Get your first constitution, spec, and plan created in 30 minutes

---

## ✅ Prerequisites Complete

- [x] Spec Kit installed (`specify` v0.0.20)
- [x] Initialized in DoseTrack directory
- [x] Slash commands available in GitHub Copilot Chat

---

## 🚀 Quick Start Commands

### 1. Create Constitution (5 minutes)

Open GitHub Copilot Chat and run:

```
/speckit.constitution Create a DoseTrack constitution with these principles:

SAFETY & MEDICAL COMPLIANCE
- All dose calculations must respect guardrails: 1.5-4.5g per dose, 3.0-9.0g nightly total
- Never provide medical advice; suggestions are planning aids only
- UTC + timezone offset for all timestamps to handle midnight crossings correctly
- Full precision math internally; 0.25g rounding only for display and save

PRIVACY & DATA SOVEREIGNTY
- 100% local-first: no cloud sync, no analytics, no PHI transmission
- HealthKit data used only for final wake autofill with explicit user consent
- WHOOP proxy must gate with API key and enforce rate limiting
- App Group sharing only between main app and widget on the same device

USER EXPERIENCE
- One-tap logging for dose events from app or widget
- Auto-populate dose grams from latest night plan recommendation
- Auto-schedule Dose 2 reminder notification based on window start time
- Autofill final wake from HealthKit or WHOOP API when available
- Validate dose sequences and alert user on impossible timing

CODE QUALITY
- Swift native with SwiftData for local persistence
- Unit tests required for ordering guards, CSV export, and rounding logic
- Type-safe models using @Model and @Attribute(.unique) for nightKey
- Enum-based configuration for all magic numbers and constants

CLINICIAN SUPPORT
- CSV export in HH:mm format keyed to bedtime date (YYYY-MM-DD)
- Include all relevant fields: dose times, grams, bathroom wakes, morning alertness
- Target 80% clinician acceptance rate for exported reports
```

**Check result:** `.specify/memory/constitution.md`

---

### 2. Document Current State (10 minutes)

```
/speckit.specify Create a comprehensive specification for DoseTrack v1.1.1c:

PRODUCT OVERVIEW
DoseTrack is a local-first iOS app for Xywav (twice-nightly GHB medication) tracking. It helps patients log bedtime, two nightly doses, bathroom wakes, and final wake, then exports a clinician-friendly CSV. Includes widget for frictionless one-tap capture and optional WHOOP proxy for sleep data.

USER PERSONAS
- Primary: Adult patient on twice-nightly Xywav prescription
- Secondary: Treating sleep clinician reviewing CSV logs for dosing pattern analysis

CORE WORKFLOWS
1. First-run onboarding: Collect preferred bedtime and total nightly grams
2. Nightly planning: Generate optimal dose split (default 50/50) and timing window (150-240 min)
3. Dose logging: One-tap "Log Dose 1" and "Log Dose 2" from app or widget
4. Final wake capture: Auto-fill from HealthKit Sleep Analysis or manual WHOOP API fetch
5. CSV export: Generate clinician-friendly report with HH:mm times and bedtime date keys

DATA MODEL
DoseLog (SwiftData @Model):
- nightKey: String (YYYY-MM-DD, @Attribute(.unique))
- nightStartUTC: Date (anchor for the night)
- timezoneOffsetMinutes: Int (stored offset for correct HH:mm display)
- bedtimeUTC, dose1TimeUTC, dose2TimeUTC, finalWakeTimeUTC: Date?
- bathroomWakeTimesUTC: [Date]
- dose1Grams, dose2Grams: Double? (0.25g increments)
- morningAlertness: Int? (1-5 scale)
- notes: String?
- finalWakeProvenance: String? (e.g., "AppleHealth", "WHOOP", "Manual")

Ordering validation: dose2 must occur after dose1 and within 150-240 minute window

SAFETY GUARDRAILS
- Per dose bounds: 1.5g minimum, 4.5g maximum
- Total nightly bounds: 3.0g minimum, 9.0g maximum
- Dose 2 window: 150 to 240 minutes after Dose 1
- All calculations use Double precision; 0.25g rounding applied only at display/save

INTEGRATIONS
- HealthKit: Read Sleep Analysis permission for final wake autofill (NSHealthShareUsageDescription required)
- App Groups: group.com.jefferson.dosetrack for widget-to-app communication
- WHOOP proxy: GET /api/sleep/latest and GET /api/aggregates/7days with API_KEY authentication

NIGHT PLAN RECOMMENDER
Algorithm:
1. Split total nightly grams by preferred percentage (default 50%, range 40-60%)
2. If WHOOP recovery score available (0-100), adjust Dose 1 by (score-50)/50 * 0.125g
3. Subtract adjustment from Dose 2 to maintain total
4. Clamp both doses to guardrail bounds (1.5-4.5g each)
5. Return precise values (Double) and display-rounded values (0.25g increments)
6. Window always 150-240 minutes (from Config constants)

SUCCESS METRICS
- 90% capture rate (nights with at least one dose logged)
- 85% completeness (nights with final wake recorded)
- 60% final wake autofilled from HealthKit (vs manual entry)
- 80% clinician CSV acceptance (usable without manual cleanup)

NON-GOALS
- Cloud sync or multi-device support
- Analytics, telemetry, or PHI transmission to any server
- Medication adherence scoring or clinical recommendations
- Dose reminders beyond the single Dose 2 notification
```

**Check result:** `.specify/memory/spec.md`

---

### 3. Document Technical Architecture (10 minutes)

```
/speckit.plan Create technical implementation plan for DoseTrack:

TECHNOLOGY STACK
- Platform: iOS 16.0+, iPadOS 16.0+ (primary target: iPhone)
- Language: Swift 5.9+
- UI: SwiftUI with @main app entry point
- Persistence: SwiftData (@Model, @Query, ModelContainer)
- Health: HealthKit framework (HKHealthStore, HKCategorySample queries)
- Widgets: WidgetKit with App Intents for background actions
- Server: Node.js 18+ with Express for WHOOP proxy (localhost during pilot)

ARCHITECTURE OVERVIEW
SwiftUI app with local-first architecture:
- DoseTrackApp: @main entry with .modelContainer(for: DoseLog.self)
- TodayLogView: Main logging UI with dose buttons, autofill, and night plan display
- DoseLogController: Business logic for CRUD operations on DoseLog records
- HealthKitManager: Singleton for HK authorization and sleep sample queries
- NightPlanRecommender: Pure functions for dose split calculations
- CSVExporter: Enum with static methods for CSV generation
- Config: Centralized enum with all guardrails and magic numbers

MODELS & DATA
DoseLog (@Model):
- Primary key: nightKey (String, YYYY-MM-DD format)
- All timestamps stored as UTC Date values
- timezoneOffsetMinutes stored per record (handles DST transitions)
- Validation method: isValidSequence(windowStartMin:windowEndMin:) -> (Bool, String?)

NightPlan (struct):
- dose1GramsPrecise, dose2GramsPrecise: Double (full precision)
- dose1DisplayG, dose2DisplayG: computed properties with 0.25g rounding
- windowStartMinAfterDose1, windowEndMinAfterDose1: Int (always 150, 240)
- rationale: String (explains how split was calculated)

AppGroupStore:
- UserDefaults wrapper for App Group container
- PendingAction: Codable struct with Kind enum (dose1Now, dose2Now)
- Used by widget App Intents to queue actions for main app processing

VIEWS & UI
TodayLogView (primary interface):
- Displays tonight's NightPlan with recommended doses
- "Log Dose 1" and "Log Dose 2" buttons (green when ready, gray when logged)
- HealthKit "Auto-fill Wake" button (fetches latest sleep end)
- Bathroom wakes entry (tap to add timestamps)
- Morning alertness slider (1-5 scale)
- Notes text field
- CSV export button (generates and shares file)

Widget (WidgetKit):
- Timeline provider: DoseWidgetProvider
- Shows tonight's recommended doses and window
- Button intents: LogDose1Intent, LogDose2Intent
- Writes pending action to App Group, app processes on next launch/foreground

DATA FLOW
Logging flow:
1. User taps "Log Dose 1" in widget → LogDose1Intent.perform()
2. Intent writes { kind: "dose1Now", timestamp: Date() } to App Group UserDefaults
3. Main app enters foreground → reads pending actions
4. DoseLogController.processPendingAction() → creates/updates DoseLog for tonight
5. If Dose 1 logged and window known → schedule Dose 2 reminder notification
6. UI updates via @Query to reflect new state

HealthKit autofill flow:
1. User taps "Auto-fill Wake" → HealthKitManager.fetchLatestFinalWake()
2. Query Sleep Analysis samples from (nightAnchor - 1 hour) to now
3. Filter for accepted sleep states (REM, Core, Deep, Unspecified, InBed)
4. Find first sample ending after nightAnchor
5. If end time within tolerance (60 min default) → populate finalWakeTimeUTC
6. Set finalWakeProvenance = "AppleHealth"
7. Update DoseLog and refresh UI

CSV export flow:
1. Fetch all DoseLog records, sort by nightKey ascending
2. Generate header: DoseLog.csvHeader()
3. For each log: append log.csvRow() with HH:mm formatting using stored timezone offset
4. Write to temporary file, present UIActivityViewController for sharing

VALIDATION & TESTING
Unit tests (DoseLogTests.swift):
- Sequence validation: dose2 < dose1 detected and rejected
- Window validation: dose2 outside 150-240 min range detected
- CSV formatting: nightKey, HH:mm times, grams with correct precision
- Rounding: safeDisplayGrams() always returns 0.25g increments
- Recommender: split percentages, guardrail clamping, recovery adjustments

Manual testing:
- 14-day internal pilot with nightly logging
- CSV review with treating clinician for format acceptance
- HealthKit autofill across different sleep patterns
- Widget background actions with app terminated

CAPABILITIES & ENTITLEMENTS
Required in Xcode project:
- HealthKit: com.apple.developer.healthkit (read: Sleep Analysis)
- App Groups: group.com.jefferson.dosetrack
- Background Modes: Not required (no background fetch/processing)
- Push Notifications: Local notifications only (Dose 2 reminder)

Info.plist keys:
- NSHealthShareUsageDescription: "Sleep data is used to automatically fill your final wake time"

DEPENDENCIES
iOS (none - all native):
- SwiftUI, SwiftData, HealthKit, WidgetKit, UserNotifications

Server (package.json):
- express: ^4.18.0
- express-rate-limit: ^6.7.0
- dotenv: ^16.0.0

DEPLOYMENT
Development:
- Xcode 15.0+ with iOS 16.0+ simulator/device
- Bundle ID: com.jefferson.dosetrack
- Widget bundle ID: com.jefferson.dosetrack.widget
- WHOOP proxy on localhost:3000 (not exposed externally)

Pilot:
- TestFlight distribution to internal testers
- 14-day logging period with CSV export review
- No analytics or crash reporting (respects privacy)
```

**Check result:** `.specify/memory/plan.md`

---

### 4. Validate Consistency (5 minutes)

```
/speckit.analyze
```

**What it does:** Checks that constitution, spec, and plan are aligned

**Review:** Fix any reported inconsistencies

---

## 📁 What You'll Have

After running these commands:

```
.specify/
├── memory/
│   ├── constitution.md    ← Governance principles
│   ├── spec.md           ← Product requirements
│   └── plan.md           ← Technical architecture
├── templates/             ← Spec Kit document templates
└── scripts/              ← Helper automation
```

---

## 🔄 Next Steps

### Option A: Document a New Feature

```
/speckit.specify Add feature: Apple Watch complications showing tonight's doses and window timing
/speckit.plan Implement using WatchOS 10+ and Watch Connectivity framework
/speckit.tasks
/speckit.implement
```

### Option B: Update for Recent Changes

```
/speckit.specify Update spec to reflect recent HealthKit autofill implementation
```

### Option C: Generate Quality Checklist

```
/speckit.checklist Create validation checklist for dose calculation safety
```

---

## 💡 Tips

1. **Keep specs updated:** When you change code, update the spec in the same PR
2. **Use /speckit.clarify:** Ask structured questions before implementing unclear features
3. **Run /speckit.analyze periodically:** Catch spec drift early
4. **Version your specs:** Copy `.specify/memory/spec.md` to `docs/specs/v1.1.1c-spec.md` at releases

---

## 🆘 Troubleshooting

**"Slash command not found"**
- Check `.vscode/settings.json` exists with `chat.promptFilesRecommendations`
- Reload VS Code window (Cmd+Shift+P → "Developer: Reload Window")

**"Constitution too generic"**
- Add more DoseTrack-specific principles (e.g., medication safety, dose guardrails)
- Reference specific compliance requirements (HIPAA, medical device guidelines if applicable)

**"Spec missing technical details"**
- That's okay! Spec focuses on *what* and *why*
- Technical *how* belongs in `/speckit.plan`

---

## 📚 Reference

- Full recommendations: `SPEC_KIT_RECOMMENDATIONS.md`
- Spec Kit docs: https://github.com/github/spec-kit
- Methodology guide: https://github.com/github/spec-kit/blob/main/spec-driven.md

---

**Ready to start? Open GitHub Copilot Chat and run Step 1! ⚡**
