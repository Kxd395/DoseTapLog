# DoseTrack Specification v1.1.1c

## Product Overview

**Name:** DoseTrack  
**Version:** 1.1.1c (with v1.2 Phase A roadmap alignment)  
**Platform:** Native iOS (SwiftUI + SwiftData) with WidgetKit, App Intents, and optional WHOOP proxy service  
**Purpose:** Local-first adherence companion for patients on twice-nightly sodium oxybate (Xywav) therapy

### Value Proposition
Ensures both nightly doses are taken within the safe timing window, captures supporting sleep context from HealthKit and WHOOP, and produces clinician-ready CSV exports without cloud storage or PHI transmission.

### Positioning
A privacy-first, safety-critical iOS application that bridges patient dosing adherence with clinical workflow through structured, exportable data.

---

## Users & Personas

### Primary User: Adult Patient on Xywav
- **Demographics:** Adults prescribed twice-nightly Xywav for narcolepsy or idiopathic hypersomnia
- **Goals:**
  - Take both doses at correct times within safe window
  - Record bathroom wakes and final wake time
  - Share accurate dosing records with clinician
- **Pain Points:**
  - Difficulty remembering exact dose times next morning
  - Confusion about safe timing window for second dose
  - Manual logs are error-prone and hard to interpret
- **Technical Comfort:** Moderate; expects iOS app patterns (widgets, health data, share sheets)

### Secondary User: Treating Clinician
- **Role:** Sleep medicine specialist, neurologist, or nurse practitioner managing Xywav therapy
- **Goals:**
  - Review adherence patterns across multiple nights
  - Identify timing drift or missed doses
  - Correlate dosing with sleep quality metrics
- **Pain Points:**
  - Patients provide inconsistent or incomplete logs
  - Time-consuming to parse handwritten or text-based records
  - Need HH:mm times keyed to consistent night identifier
- **Requirements:**
  - CSV format compatible with EMR import or spreadsheet analysis
  - One row per night with clear date/time columns
  - Provenance indicators (HealthKit vs. manual entry)

### Extended User (v1.2 Phase A): Care Team Member
- **Role:** Clinical research coordinator, pharmacist, or case manager
- **Goals:**
  - Track recovery trends (WHOOP-derived scores)
  - Monitor sleep quality alongside dosing adherence
- **Requirements:**
  - Aggregated 7-day metrics
  - Morning survey data (alertness scale, bathroom wake counts)

---

## Core Workflows

### 1. Nightly Plan Review
**Trigger:** User opens app before bedtime  
**Steps:**
1. App displays tonight's plan in GroupBox:
   - Dose 1: X.XX g
   - Dose 2: Y.YY g  
   - Window: 150–240 min after Dose 1
2. Plan computed by `NightPlanRecommender` based on:
   - Total nightly dose (default 6.5 g, user-configurable)
   - Preferred split percentage (default 50%, range 40–60%)
   - Optional WHOOP recovery score (±0.125 g adjustment)
3. Values clamped to safety guardrails and rounded to 0.25 g for display

**Success Criteria:**
- Plan loads in < 500 ms
- Dose values always within safety bounds
- Window times match configured defaults

### 2. One-Tap Dose Logging
**Trigger:** User takes Dose 1 or Dose 2  
**Source:** App button, widget tap target, or Siri shortcut

**App Flow:**
1. User taps "Dose 1 Now" or "Dose 2 Now"
2. `DoseLogController.logDose1(grams:)` or `logDose2(grams:)` called
3. Controller fetches or creates `DoseLog` entry for current night (keyed by derived bedtime date)
4. Timestamp captured in UTC; `timezoneOffsetMinutes` stored
5. Dose value saved (pre-rounded to 0.25 g from plan)
6. SwiftData persists on MainActor
7. Optional: Schedule local notification for Dose 2 window start

**Widget/Intent Flow:**
1. User taps widget or invokes Siri shortcut
2. `AppIntent` writes `PendingAction` to `AppGroupStore`
3. App consumes pending actions on next foreground via `DoseLogController.consumePendingFromWidget()`
4. Same persistence flow as app button

**Success Criteria:**
- Dose logged within 2 seconds of tap
- Timestamp accurate to nearest second
- Widget updates reflect new state within 5 seconds
- No duplicate entries for same dose/night

### 3. Sleep Context Capture
**Trigger:** User wakes during night or in morning

**Bathroom Wakes (Manual):**
- User taps "Add Bathroom Wake" (future feature)
- Timestamp captured and appended to array
- Displayed in morning survey or log detail

**Final Wake Autofill (HealthKit):**
1. User taps "Autofill Wake" button
2. App requests HealthKit authorization if needed (permission prompt with `NSHealthShareUsageDescription`)
3. `HealthKitManager.fetchLatestFinalWake()` queries Sleep Analysis samples:
   - Start: 1 hour before derived bedtime
   - End: now
   - Filter: `.inBed`, `.asleepCore`, `.asleepDeep`, `.asleepREM` states
4. Returns most recent sample end time if within tolerance (180 min)
5. `DoseLogController.setFinalWake(date:provenance:)` updates entry with provenance "AppleHealth"
6. SwiftData saves; view refreshes

**WHOOP Autofill (v1.2 Phase A):**
- Similar flow using `/api/sleep/latest` endpoint from proxy
- Provenance set to "WHOOP"

**Success Criteria:**
- HealthKit permission granted on first request
- Autofill completes in < 3 seconds
- Provenance accurately reflects data source
- No autofill if sample outside tolerance window

### 4. Morning Survey (v1.2 Phase A)
**Trigger:** User opens app after final wake

**Steps:**
1. Present survey sheet (dismissible):
   - "How alert did you feel?" (1–5 scale)
   - "Bathroom wakes?" (stepper or list entry)
   - "Notes" (free text)
2. Data stored in `DoseLog` fields: `morningAlertness`, `bathroomWakeTimesUTC[]`, `notes`
3. Survey marked complete; button text changes to "Edit Survey"

**Success Criteria:**
- Survey completion rate ≥ 70% of captured nights
- Data persists with dose log entry
- Included in CSV export

### 5. Clinician Export
**Trigger:** User taps "Export CSV" button

**Steps:**
1. `CSVExporter.exportToCSV()` fetches all `DoseLog` entries (ascending by `nightStartUTC`)
2. For each entry, generate row with:
   - Night date (YYYY-MM-DD from derived bedtime)
   - Dose 1 time (HH:mm using `timezoneOffsetMinutes`)
   - Dose 1 grams (0.25 g rounded)
   - Dose 2 time (HH:mm)
   - Dose 2 grams
   - Final wake time (HH:mm)
   - Final wake provenance
   - Morning alertness (1–5 or blank)
   - Bathroom wakes count
   - Notes (escaped for CSV)
3. Prepend header row
4. Write to temporary file in `FileManager.default.temporaryDirectory`
5. Present `UIActivityViewController` (share sheet)
6. User shares via AirDrop, email, Files app, etc.

**Success Criteria:**
- CSV format parseable by Excel/Numbers
- Times in HH:mm format (no date prefix)
- One row per night, chronological order
- No PHI leakage (file stays local until user shares)

---

## Data Model

### DoseLog (@Model)
Primary SwiftData entity representing one night's dosing record.

```swift
@Model
final class DoseLog {
    // Unique identifier (derived bedtime date as YYYY-MM-DD string)
    @Attribute(.unique) var nightKey: String
    
    // Derived bedtime anchor (UTC)
    var nightStartUTC: Date
    
    // Timezone offset at logging time (minutes from UTC)
    var timezoneOffsetMinutes: Int
    
    // Dose 1
    var dose1TimeUTC: Date?
    var dose1Grams: Double?  // 0.25 g rounded
    
    // Dose 2
    var dose2TimeUTC: Date?
    var dose2Grams: Double?  // 0.25 g rounded
    
    // Sleep context
    var finalWakeTimeUTC: Date?
    var finalWakeProvenance: String?  // "AppleHealth", "WHOOP", "Manual"
    var bathroomWakeTimesUTC: [Date]?  // v1.2 Phase A
    
    // Morning survey (v1.2 Phase A)
    var morningAlertness: Int?  // 1–5 scale
    var notes: String?
    
    // Validation
    func isValidSequence(windowStartMin: Int, windowEndMin: Int) -> (Bool, String?)
    
    // CSV export
    func csvRow() -> String
}
```

**nightKey Logic:**
- Derived from user's configured bedtime (e.g., 22:00)
- If current time < bedtime, use previous calendar day
- If current time ≥ bedtime, use current calendar day
- Ensures doses logged post-midnight associate with correct night

**Sequence Validation:**
- Returns `(false, "Dose 2 precedes Dose 1")` if dose2 < dose1
- Returns `(false, "Dose 2 too soon")` if dose2 < dose1 + windowStartMin
- Returns `(false, "Dose 2 too late")` if dose2 > dose1 + windowEndMin
- Returns `(true, nil)` if valid

### NightPlan (Struct)
Computed recommendation for tonight's dosing, not persisted.

```swift
struct NightPlan {
    let dose1PreciseG: Double        // Full precision
    let dose2PreciseG: Double
    let dose1DisplayG: Double        // 0.25 g rounded
    let dose2DisplayG: Double
    let windowStartMinAfterDose1: Int
    let windowEndMinAfterDose1: Int
    let rationale: String?           // Optional explanation
}
```

**Computation (`NightPlanRecommender`):**
1. Input: `totalNightG`, `splitFirstPct`, optional `recoveryScore0to100`
2. Clamp split percentage to 40–60%
3. Calculate raw d1 = totalNightG × splitFirst
4. Adjust d1 by recovery score (±0.125 g per 10% deviation from 50% score)
5. Clamp d1 to per-dose bounds (1.5–4.5 g)
6. Calculate d2 = totalNightG - d1
7. Clamp d2 to per-dose bounds
8. Verify total still within nightly bounds (3.0–9.0 g)
9. Round display values to 0.25 g; retain precise values for internal use

### AppGroupStore (Shared Container)
Facilitates widget/intent → app communication.

```swift
struct PendingAction: Codable {
    let id: UUID
    let type: ActionType  // .logDose1, .logDose2
    let timestamp: Date
    let doseGrams: Double?
}
```

Stored in `UserDefaults(suiteName: "group.com.jefferson.dosetrack")`

---

## Safety Guardrails

### Per-Dose Bounds
- **Minimum:** 1.5 g
- **Maximum:** 4.5 g
- Enforced in `Config.swift` constants
- Applied in `NightPlanRecommender.clamp()` and UI validation

### Total Nightly Bounds
- **Minimum:** 3.0 g
- **Maximum:** 9.0 g
- Verified after d1 + d2 calculation
- User cannot configure total outside this range

### Timing Window
- **Window Start:** 150 minutes after Dose 1
- **Window End:** 240 minutes after Dose 1
- Enforced in `DoseLog.isValidSequence()`
- Optional: Local notification scheduled at window start

### Precision Policy
- **Internal calculations:** Full `Double` precision (e.g., 3.2375 g)
- **Display & Save:** Rounded to 0.25 g using `Rounding+Display.roundToQuarter()`
- Prevents accumulation of rounding errors across computations

### Sequence Validation
- Dose 2 must occur after Dose 1
- Dose 2 must be within timing window
- Validation runs before save; prevents invalid records

---

## External Integrations

### HealthKit
**Capability:** Read-only access to Sleep Analysis  
**Permission:** `NSHealthShareUsageDescription` in Info.plist  
**Query Details:**
- Category: `HKCategoryTypeIdentifier.sleepAnalysis`
- States: `.inBed`, `.asleepCore`, `.asleepDeep`, `.asleepREM`
- Predicate: Start 1 hour before bedtime, end now
- Sort: Most recent first
- Limit: 1 sample

**Provenance:**
- Set to "AppleHealth" when autofilled from HKSample
- Never write to HealthKit; read-only integration

**Error Handling:**
- Authorization denied → Graceful message, manual entry option
- No samples found → "No sleep data available" alert
- Sample outside tolerance → Ignore, manual entry option

### WHOOP Proxy
**Architecture:** Separate Express.js service on `http://localhost:3000` (local development) or configured endpoint  
**Authentication:** `x-api-key` header required for `/api/*` endpoints  
**Rate Limiting:** 60 requests per minute (enforced by `express-rate-limit`)

**Endpoints:**
1. **GET `/health`**
   - Returns: `{ "status": "ok", "timestamp": "...", "service": "dosetrack-whoop-proxy", "version": "1.0.0" }`
   - No auth required

2. **GET `/api/sleep/latest`**
   - Returns: Most recent WHOOP sleep record (v2 sleep endpoint)
   - Requires: `x-api-key`, valid `WHOOP_TOKEN` in `.env`
   - Response: `{ "id": "...", "end": "...", "score": {...} }` or error object

3. **GET `/api/aggregates/7days`**
   - Returns: 7-day aggregated sleep and recovery metrics
   - Requires: `x-api-key`, valid `WHOOP_TOKEN`
   - Response: `{ "avgRecovery": 65.3, "avgSleepMinutes": 412, "nights": [...] }`

**Error Handling:**
- `401 Unauthorized` if `x-api-key` missing/invalid
- `500 Internal Server Error` if WHOOP API call fails
- `429 Too Many Requests` if rate limit exceeded

**Pagination:**
- WHOOP range queries use `limit=25` with `nextToken` cursor
- Proxy helper `getJsonWithPagination()` handles iteration

**Configuration (`.env`):**
```
API_KEY=test-api-key-local-dev-only
WHOOP_TOKEN=your-whoop-token-here
PORT=3000
```

### Widget & App Intents
**Widget Types:**
- Small: Tonight's plan summary
- Medium: Plan + tap targets for Dose 1/2
- Large: Plan + recent log entries

**App Intents:**
- `LogDose1Intent`: Enqueues Dose 1 pending action
- `LogDose2Intent`: Enqueues Dose 2 pending action
- Both write to `AppGroupStore`, app consumes on foreground

**Timeline Update:**
- Widget refreshes on plan change or dose logged
- Timeline policy: `.atEnd` with 24-hour interval

---

## Success Metrics

### Primary Metrics
1. **Nightly Capture Rate:** ≥ 90%
   - Calculation: (Nights with both doses logged) / (Total nights in pilot period)
   - Target: 90% over 14-day pilot

2. **Completeness Rate:** ≥ 85%
   - Calculation: (Nights with Dose 1 + Dose 2 + Final Wake) / (Total nights captured)
   - Target: 85% over 14-day pilot

3. **Clinician CSV Acceptance:** ≥ 80%
   - Method: Clinician review survey post-pilot
   - Criteria: "CSV format is useful for clinical review" (agree/strongly agree)

### Secondary Metrics (v1.2 Phase A)
4. **Final Wake Autofill Rate:** ≥ 60%
   - Calculation: (Nights with autofilled wake) / (Total nights captured)
   - Sources: HealthKit or WHOOP

5. **Morning Survey Completion:** ≥ 70%
   - Calculation: (Nights with survey completed) / (Total nights captured)
   - Requires: Alertness scale, bathroom wake count, or notes

### Operational Metrics
- App crash rate < 1%
- Widget update latency < 5 seconds
- CSV export time < 3 seconds for 30 nights

---

## Non-Goals (Explicitly Out of Scope)

### Data Sync & Cloud Storage
- No iCloud sync of dose logs
- No remote database or analytics
- All data stays local until user-initiated export

### Audio Cues & Reminders
- No audio playback for dose timing
- No custom alarm sounds
- System notifications only (local notifications for window start)

### ML Personalization
- No machine learning models for dose adjustment
- Recommender uses deterministic algorithm only
- Phase A does not include HRV or strain-based personalization

### Coaching & Messaging
- No in-app coaching messages or tips
- No motivational content or adherence gamification
- Clinical tool, not wellness app

### Multi-User or Caregiver Access
- Single-user app (patient only)
- No caregiver dashboard or remote monitoring
- Clinician access via CSV export only

### Secure Portal or EMR Integration
- No direct EMR upload
- No encrypted delivery to clinician portal
- CSV export to Files app or email (user discretion)

---

## Open Questions & Future Work

### Phase A Follow-On (v1.2+)
- Add HRV and WHOOP strain inputs to recommender
- Multi-night visualization (history tab with charts)
- Export format options (JSON, PDF summary)

### Clinical Workflow Integration
- Explore encrypted export delivery (e.g., S/MIME email)
- Investigate FHIR Observation bundle export
- Partner with EMR vendors for import templates

### User Experience Enhancements
- Dark mode custom palette (currently uses system defaults)
- Accessibility audit (VoiceOver, Dynamic Type)
- Onboarding flow with setup wizard

### Technical Debt
- Migrate `DoseLogController` to MainActor-safe design
- Extract view logic into view models (`@Observable`)
- Add TypeScript types to WHOOP proxy
- Expand XCTest coverage to ≥ 80%

---

## UI Component Specifications

### State Gating Requirements

**Critical:** Enforce proper state flow to prevent broken calculations and unsafe behavior.

1. **"In bed now" anchor REQUIRED before Dose 1**
   - User must tap "In bed now" to mint nightKey before any dose logging
   - nightKey must never be "unknown" during active dosing session
   - This establishes consistent night context for all calculations

2. **Consume pending actions on appear**
   - `onAppear`: Call `controller.consumePendingFromWidget()`
   - Ensures widget/intent actions update view state immediately
   - Prevents stale dose1TimeUTC causing broken enablement

3. **UTC date math everywhere**
   - Always compute intervals with UTC timestamps
   - Apply timezone offset only for display formatting
   - Prevents negative intervals around DST transitions

4. **MainActor consistency**
   - All window calculations on MainActor
   - Debounce updates to prevent race conditions
   - Avoid stale state rendering

### Dose 2 Enablement Logic

```swift
// Required checks (all must pass):
let hasDose1 = dose1TimeUTC != nil
let hasNightKey = nightKey != "unknown"
let elapsed = dose1TimeUTC.map { Date.now.timeIntervalSince($0) / 60 }
let windowStart = settings.dose2WindowStartMin // from AppPreferences
let windowEnd = settings.dose2WindowEndMin

// Base enablement
let inWindow = elapsed != nil && elapsed! >= windowStart && elapsed! <= windowEnd

// Early dose extension (if enabled in settings)
let earlyAllowed = settings.allowEarlyDose && 
                   elapsed != nil && 
                   elapsed! >= (windowStart - settings.maxEarlyMinutes) && 
                   elapsed! < windowStart

let canDose2 = hasDose1 && hasNightKey && (inWindow || earlyAllowed)

// Disabled reason (always show inline)
var disabledReason: String {
    if !hasDose1 { return "Log Dose 1 first" }
    if !hasNightKey { return "Tap 'In bed now' to start" }
    if let e = elapsed, e < (windowStart - settings.maxEarlyMinutes) {
        let opensAt = dose1TimeUTC! + TimeInterval(windowStart * 60)
        return "Window opens at \(format(opensAt))"
    }
    if let e = elapsed, e > windowEnd {
        return "Window expired \(Int(e - windowEnd)) min ago"
    }
    return ""
}
```

### CountdownRing Component

**File:** `CountdownRingView.swift`

**Purpose:** Always-visible circular progress indicator with status text

**Behavior:**
- Outer ring fills from 0.0 (at Dose 1) to 1.0 (at 240 min after Dose 1)
- Updates every 30 seconds via `TimelineView`
- Shows context-aware text below ring:
  - Before window: "Window opens in 1h 45m"
  - During window: "Window closes in 28m"
  - After window: "Window expired 12m ago"
  - When Dose 2 disabled: Small gray text with reason

**Props:**
```swift
struct CountdownRingView: View {
    let dose1Time: Date?
    let windowStartMin: Int
    let windowEndMin: Int
    let disabledReason: String
    
    var body: some View { ... }
}
```

### EventStrip Component

**File:** `EventStripView.swift`

**Purpose:** Compact list of last 3 events with undo capability

**Layout:**
- Pinned under countdown ring
- Shows most recent 3 events from event_log
- Format: "Dose 1 23:05 • 3.25g", "In bed 22:58"
- First item tappable for 60 seconds after logging → shows "Undo last"
- Long-press on Dose buttons → "Edit grams for tonight only" sheet

**Props:**
```swift
struct EventStripView: View {
    let events: [EventLog] // last 3, descending
    let onUndo: () -> Void
    let allowUndo: Bool // true if < 60s since last event
    
    var body: some View { ... }
}
```

### SafetyBanner Component

**File:** `SafetyBannerView.swift`

**Purpose:** Always-visible status chips for safety, data sources, permissions

**Chips:**
1. **Safety chip:** "Per dose 1.5–4.5g" with ✓ (green) or ✕ (red)
2. **Night total chip:** "Night total 6.5g" with status
3. **Wake source chip:** "Wake: Health" with Change link
4. **Permissions chip:** "Health OK" or "Health denied" (tap to fix)
5. **WHOOP chip:** "Proxy connected" or "Offline" (tap to test)

**Props:**
```swift
struct SafetyBannerView: View {
    let perDoseMin: Double
    let perDoseMax: Double
    let nightlyTotal: Double
    let wakeSource: WakeSource
    let healthStatus: HealthKitStatus
    let whoopStatus: WHOOPStatus
    let onChangeSource: () -> Void
    let onFixPermissions: () -> Void
    let onTestWHOOP: () -> Void
    
    var body: some View { ... }
}
```

### EarlyDoseSheet Component

**File:** `EarlyDoseSheetView.swift`

**Purpose:** Confirmation modal for early Dose 2 with override logging

**Trigger:** User taps Dose 2 button when `elapsed < windowStart` and `allowEarlyDose == true`

**UI:**
- Title: "Dose 2 early"
- Reason picker (required if `requireReason == true`):
  - "Could not sleep again"
  - "Shift schedule"
  - "Other"
- Time-prior choices: 5m, 10m, 15m, 20m, 30m (segmented picker)
- Confirm button (requires reason selection)
- Cancel button

**Data capture:**
- Logs to `event_log` with `override = true`
- Stores `earlyMinutes` (how many minutes before window)
- Stores `reason` text
- Timestamp when confirmed

**Props:**
```swift
struct EarlyDoseSheetView: View {
    @Binding var isPresented: Bool
    let minutesEarly: Int
    let onConfirm: (String, Int) -> Void // (reason, timePriorMin)
    
    var body: some View { ... }
}
```

### ScrollView Layout Requirements

**Problem:** Screen overflows on smaller devices (iPhone SE, iPhone 13 mini)

**Solution:**
```swift
var body: some View {
    NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Sticky header section
                Section {
                    CountdownRingView(...)
                    SafetyBannerView(...)
                } header: {
                    Text("Tonight's Status")
                }
                .headerProminence(.increased)
                
                EventStripView(...)
                
                // Plan, dose buttons, etc.
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            // Action bar stays reachable
            actionButtons()
                .padding()
                .background(.ultraThinMaterial)
        }
    }
}
```

### Live Activity Specification

**File:** `DoseLiveActivity.swift` (ActivityKit integration)

**Start trigger:** Dose 1 logged

**Content:**
- Countdown to window start (if before 150 min)
- Countdown to window end (if during window)
- Current elapsed time

**Quick actions:**
1. "Dose 2 now" → Logs Dose 2 immediately (if in window)
2. "Snooze 10m" → Schedules reminder notification
3. "Open app" → Deep link to TodayLogView

**End trigger:**
- Dose 2 logged, OR
- Window expired (240+ min after Dose 1)

**Implementation:**
```swift
struct DoseLiveActivity: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var dose1Time: Date
        var windowStartMin: Int
        var windowEndMin: Int
        var dose2Logged: Bool
    }
    
    var nightKey: String
}
```

---

## Settings Panel Complete Specification

**File:** `SettingsView.swift`  
**SSOT Store:** `AppPreferences.swift` (@Observable with @AppStorage)

### Section 1: Night Plan Defaults

**Controls:**
1. **Total night grams**
   - Type: Picker
   - Options: [3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0]
   - Default: 6.5
   - Key: `plan_total_night_grams`

2. **Split strategy**
   - Type: Segmented Picker
   - Options: ["50-50", "60-40", "40-60", "Custom"]
   - Default: "50-50"
   - Key: `plan_split_strategy`

3. **Per-dose rounding**
   - Type: Segmented Picker
   - Options: ["0.25 g", "0.5 g"]
   - Default: "0.25 g"
   - Key: `plan_rounding_increment`

4. **Window start**
   - Type: Stepper
   - Range: 120–300 min
   - Step: 5 min
   - Default: 150
   - Key: `dose2_window_start_min`

5. **Window end**
   - Type: Stepper
   - Range: 120–300 min
   - Step: 5 min
   - Default: 240
   - Key: `dose2_window_end_min`

6. **Tonight-only edit allowed**
   - Type: Toggle
   - Default: true
   - Key: `allow_tonight_only_edit`

### Section 2: Early Dose 2 Policy

**Controls:**
1. **Allow early dose**
   - Type: Toggle
   - Default: false
   - Key: `allow_early_dose`

2. **Max early minutes**
   - Type: Stepper
   - Range: 0–30 min
   - Step: 5 min
   - Default: 15
   - Key: `max_early_minutes`

3. **Require reason**
   - Type: Toggle
   - Default: true
   - Key: `early_require_reason`

4. **Default time-prior quick actions**
   - Type: Multi-select (CheckboxGroup)
   - Options: [5, 10, 15, 20, 30]
   - Default: [5, 10]
   - Key: `early_time_prior_defaults` (stored as comma-separated string)

### Section 3: Notifications and Live Activity

**Controls:**
1. **Live Activity for Dose 2**
   - Type: Toggle
   - Default: true
   - Key: `notifications_live_activity_enabled`

2. **Notify at window start**
   - Type: Toggle
   - Default: true
   - Key: `notifications_window_start`

3. **Notify at halfway**
   - Type: Toggle
   - Default: false
   - Key: `notifications_halfway`

4. **Notify at window end**
   - Type: Toggle
   - Default: true
   - Key: `notifications_window_end`

5. **Quiet hours**
   - Type: Time range picker (start, end)
   - Default: none
   - Keys: `notifications_quiet_start`, `notifications_quiet_end`

6. **Haptics**
   - Type: Toggle
   - Default: true
   - Key: `notifications_haptics_enabled`

### Section 4: Data Sources

**Controls:**
1. **Health permissions status**
   - Type: Read-only badge (OK / Denied / Limited)
   - Button: "Recheck" → requests authorization

2. **Health sample window**
   - Type: Stepper
   - Range: 60–300 min before bedtime
   - Step: 15 min
   - Default: 60
   - Key: `health_sample_window_min`

3. **WHOOP proxy URL**
   - Type: TextField
   - Default: "" (blank)
   - Key: `whoop_proxy_url`
   - Placeholder: "http://localhost:3000"

4. **WHOOP API key**
   - Type: SecureField
   - Default: ""
   - Key: `whoop_api_key`

5. **Test WHOOP connection**
   - Type: Button
   - Action: Pings proxy `/sleep` endpoint
   - Shows: "Proxy connected" (green) or "Offline" (red) chip

6. **Prefer wake source**
   - Type: Picker
   - Options: ["Health", "Manual"]
   - Default: "Health"
   - Key: `wake_source_preference`

### Section 5: Exports

**Controls:**
1. **Time zone in CSV**
   - Type: Toggle
   - Default: true
   - Key: `export_include_timezone`

2. **Filename pattern**
   - Type: TextField
   - Default: "DoseTrack_yyyyMMdd.csv"
   - Key: `export_filename_pattern`

3. **Include notes**
   - Type: Toggle
   - Default: true
   - Key: `export_include_notes`

4. **Include raw event log**
   - Type: Toggle
   - Default: false
   - Key: `export_include_event_log`

5. **Default share target**
   - Type: TextField (email address)
   - Default: ""
   - Key: `export_default_email`
   - Optional

### Section 6: Privacy and Retention

**Controls:**
1. **Require Face ID to open**
   - Type: Toggle
   - Default: false
   - Key: `privacy_require_biometric`

2. **Mask dose amounts on widgets**
   - Type: Toggle
   - Default: true
   - Key: `privacy_mask_widget_doses`

3. **Data retention days**
   - Type: Stepper
   - Range: 30–3650 days
   - Step: 30 days
   - Default: 365
   - Key: `privacy_retention_days`

4. **Purge now**
   - Type: Destructive button
   - Action: Shows confirm sheet → deletes logs older than retention period

### Section 7: Debug and Developer

**Controls:**
1. **Show nightKey and offsets**
   - Type: Toggle
   - Default: false
   - Key: `debug_show_internals`

2. **Simulate Dose 1 now**
   - Type: Button
   - Action: Logs test Dose 1 with current timestamp

3. **Force window open**
   - Type: Button
   - Action: Overrides window calculation to always return true

4. **View event log**
   - Type: NavigationLink
   - Destination: Read-only list of all event_log entries

5. **Schema version**
   - Type: Read-only label
   - Value: Current SwiftData schema version

---

## AppPreferences Store Specification

**File:** `AppPreferences.swift`

**Purpose:** Single source of truth for all user settings using @AppStorage

**Implementation:**
```swift
import SwiftUI
import Observation

@Observable
final class AppPreferences {
    // Night Plan Defaults
    @AppStorage("plan_total_night_grams") var totalNightGrams: Double = 6.5
    @AppStorage("plan_split_strategy") var splitStrategy: String = "50-50"
    @AppStorage("plan_rounding_increment") var roundingIncrement: Double = 0.25
    @AppStorage("dose2_window_start_min") var windowStartMin: Int = 150
    @AppStorage("dose2_window_end_min") var windowEndMin: Int = 240
    @AppStorage("allow_tonight_only_edit") var allowTonightEdit: Bool = true
    
    // Early Dose 2 Policy
    @AppStorage("allow_early_dose") var allowEarlyDose: Bool = false
    @AppStorage("max_early_minutes") var maxEarlyMinutes: Int = 15
    @AppStorage("early_require_reason") var earlyRequireReason: Bool = true
    @AppStorage("early_time_prior_defaults") var earlyTimePriorDefaults: String = "5,10"
    
    // Notifications & Live Activity
    @AppStorage("notifications_live_activity_enabled") var liveActivityEnabled: Bool = true
    @AppStorage("notifications_window_start") var notifyWindowStart: Bool = true
    @AppStorage("notifications_halfway") var notifyHalfway: Bool = false
    @AppStorage("notifications_window_end") var notifyWindowEnd: Bool = true
    @AppStorage("notifications_quiet_start") var quietHoursStart: String? = nil
    @AppStorage("notifications_quiet_end") var quietHoursEnd: String? = nil
    @AppStorage("notifications_haptics_enabled") var hapticsEnabled: Bool = true
    
    // Data Sources
    @AppStorage("health_sample_window_min") var healthSampleWindowMin: Int = 60
    @AppStorage("whoop_proxy_url") var whoopProxyURL: String = ""
    @AppStorage("whoop_api_key") var whoopAPIKey: String = ""
    @AppStorage("wake_source_preference") var wakeSourcePreference: String = "Health"
    
    // Exports
    @AppStorage("export_include_timezone") var exportIncludeTimezone: Bool = true
    @AppStorage("export_filename_pattern") var exportFilenamePattern: String = "DoseTrack_yyyyMMdd.csv"
    @AppStorage("export_include_notes") var exportIncludeNotes: Bool = true
    @AppStorage("export_include_event_log") var exportIncludeEventLog: Bool = false
    @AppStorage("export_default_email") var exportDefaultEmail: String = ""
    
    // Privacy & Retention
    @AppStorage("privacy_require_biometric") var requireBiometric: Bool = false
    @AppStorage("privacy_mask_widget_doses") var maskWidgetDoses: Bool = true
    @AppStorage("privacy_retention_days") var retentionDays: Int = 365
    
    // Debug
    @AppStorage("debug_show_internals") var showInternals: Bool = false
    
    static let shared = AppPreferences()
}
```

---

## Appendices

### A. CSV Schema (Current)
```
night,dose1_time,dose1_grams,dose2_time,dose2_grams,final_wake_time,final_wake_provenance,notes
2025-11-01,22:15,3.25,01:30,3.25,07:45,AppleHealth,""
```

### B. CSV Schema (v1.2 Phase A)
Adds columns: `morning_alertness`, `bathroom_wakes`

### C. Glossary
- **Derived bedtime:** Calculated night identifier based on user's configured bedtime hour
- **nightKey:** YYYY-MM-DD string used as unique identifier for `DoseLog` entry
- **Provenance:** Source attribution for autofilled data (e.g., "AppleHealth", "WHOOP", "Manual")
- **UTC + offset pattern:** Store all timestamps in UTC, save timezone offset at logging time, display in local time using offset

---

**Specification Version:** 1.0.0  
**Aligned with:** DoseTrack v1.1.1c, PRD v1.2, Constitution v1.0.0  
**Last Updated:** November 1, 2025
