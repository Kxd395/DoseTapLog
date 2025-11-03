# DoseTrack Logic & Data Flow Map

ASCII map of key data pathways across the DoseTrack ecosystem (iOS client, widget, intents, WHOOP proxy, and external services).

---

## 1. High-Level System Flow

```
┌────────────┐        ┌─────────────────┐        ┌───────────────┐
│   Widget   │────┐   │    App Group    │   ┌───▶│ DoseLogController │
└────────────┘    │   └─────────────────┘   │    └──────┬────────┘
                  │                          │           │
┌────────────┐    │   ┌──────────────┐       │           │ saves SwiftData
│ App Intents│────┤   │ DoseTrack App │◀─────┘           │
└────────────┘    │   └──────┬───────┘                   │
                  │          │                           │
                  │          ▼                           │
                  │   ┌──────────────┐                   │
                  │   │ SwiftData     │◀── CSVExporter ──┘
                  │   └──────────────┘
                  │          ▲
                  │          │
                  │   ┌──────────────┐
                  └──▶│ HealthKitMgr │
                      └──────────────┘
```

---

## 2. Dose Logging Sequence

```
[User taps Dose 1 button]
      │
      ▼
┌──────────────┐
│ TodayLogView │
└──────┬───────┘
       │ logDose1(plan.dose1DisplayG)
       ▼
┌──────────────┐
│ DoseLogCtrl  │
├──────────────┤
│ fetchOrCreate │
│  night entry  │
│  via SwiftData│
└──────┬───────┘
       │ update fields (dose1TimeUTC, dose1Grams)
       ▼
┌──────────────┐
│ SwiftData     │
└──────┬───────┘
       │ persist (MainActor)
       ▼
┌──────────────┐
│ CSV exporter │ (later)
└──────────────┘
```

Widget/App Intent follow the same flow: they enqueue a `PendingAction` in `AppGroupStore`, and `TodayLogView` consumes it via `DoseLogController.consumePendingFromWidget()`.

---

## 3. HealthKit Final Wake Autofill

```
┌──────────────────────────────┐
│ TodayLogView - "Autofill" tap│
└───────────────┬──────────────┘
                │ requestAuthorizationIfNeeded { ok }
                ▼
┌──────────────────────────────┐
│ HealthKitManager             │
│ - requestAuthorization       │
│ - fetchLatestFinalWake(...)  │
└───────────────┬──────────────┘
                │ completion(Date?, provenance)
                ▼
┌──────────────────────────────┐
│ DoseLogController.setFinalWake│
└───────────────┬──────────────┘
                │ save to SwiftData (MainActor)
                ▼
┌──────────────────────────────┐
│ DoseLog entry updated         │
└──────────────────────────────┘
```

HealthKit query window: 1 hour before derived bedtime anchor until now. Only accepts samples whose end time falls within tolerance (default 180 minutes).

---

## 4. Night Plan Recommendation

```
Inputs:
  - totalNightG (default 6.5)
  - preferredSplitFirstPct (default 50)
  - historyDose2ToWakeMinAvg (optional)
  - recoveryScore0to100 (optional WHOOP metric)

Processing:
  splitFirst = clamp(preferredSplit, 40-60)
  d1 = clamp(totalNightG * splitFirst, perDoseMin, perDoseMax)
  adjust for recoveryScore (±0.125g)
  d2 = clamp(totalNightG - d1, perDoseMin, perDoseMax)
  window = 150–240 min

Outputs:
  NightPlan { dose1Precise, dose2Precise, windowStartMin, windowEndMin, rationale }
```

The plan is generated on app launch and cached in the view model; future iterations may re-run when recovery data updates.

---

## 5. CSV Export Path

```
┌──────────────┐
│ CSVExporter  │
└──────┬───────┘
       │ fetch all DoseLog entries (ascending nightStartUTC)
       ▼
┌──────────────┐
│ DoseLog.csvRow│
└──────┬───────┘
       │ join header + rows
       ▼
┌──────────────┐
│ temp file in │
│ FileManager  │
└──────┬───────┘
       │ returns URL
       ▼
┌──────────────┐
│ UIActivityVC │ (Share sheet)
└──────────────┘
```

All timestamps formatted via `Date.hhmm(withUTCOffsetMinutes:)`.

---

## 6. WHOOP Proxy Interaction

```
┌──────────────┐        ┌──────────────────────────┐
│ DoseTrack App│───HTTP▶│ WHOOP Proxy (Express)    │
└──────┬───────┘        └─────────┬────────────────┘
       │                           │
       │ JSON w/ x-api-key header  │
       │                           ▼
       │                    ┌──────────────┐
       │                    │ getJsonWith  │
       │                    │ Pagination   │
       │                    └──────┬───────┘
       │                           │ fetch WHOOP API with Bearer token
       ▼                           ▼
┌──────────────┐              ┌──────────────┐
│ NightPlan VM │◀──────────── │ WHOOP API    │
└──────────────┘              └──────────────┘
```

Proxy endpoints:
- `GET /api/sleep/latest`
- `GET /api/aggregates/7days`

Both require `x-api-key` header; rate limited to 60 requests/min by default.

---

## 7. Data Entities

```
DoseLog
  nightKey: String (unique)
  nightStartUTC: Date
  timezoneOffsetMinutes: Int
  bedtimeUTC?: Date
  dose1TimeUTC?: Date
  dose2TimeUTC?: Date
  finalWakeTimeUTC?: Date
  bathroomWakeTimesUTC: [Date]
  dose1Grams?: Double
  dose2Grams?: Double
  morningAlertness?: Int
  notes?: String
  finalWakeProvenance?: String
```

CSV header: `night_date,bedtime,dose1_time,dose1_g,dose2_time,dose2_g,bathroom_wakes,final_wake,morning_alertness,notes`

---

Keep this logic map synchronized with system changes. Update diagrams when endpoints, data models, or workflows evolve.
