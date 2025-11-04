# DoseTrack v1.2 PRD

## Executive summary
DoseTrack is a local-first iOS app plus a small WHOOP proxy that helps a patient on Xywav plan and log bedtime, two nightly doses, bathroom wakes, and final wake, then exports a clinician-friendly CSV. The v1.2 mandate focuses on a data-driven night plan and frictionless capture.

## Problem
Patients struggle to adhere to the second dose window and to recall times accurately the next day. Clinicians receive messy logs.

## Goals
- Capture rate target 90 percent of nights
- Completeness target 85 percent including Final Wake
- Clinician-ready CSV in HH:mm keyed to bedtime date
- **Precision event logging** with tap-now speed + long-press date/time selection
- **Dose 2 override transparency** with full audit trail for early/late adherence tracking

## Users
- Primary: Adult patient on twice-nightly Xywav
- Secondary: Treating clinician reviewing CSV with override audit data

## Scope
- iOS app with SwiftData storage and Widget
- WHOOP proxy for sleep and aggregates
- HealthKit final wake autofill
- CSV export

## Non goals
- No cloud sync
- No analytics or PHI transmission

## Safety guardrails
- Per dose 1.5 g to 4.5 g
- Total nightly 3.0 g to 9.0 g
- Second dose window 150 to 240 minutes
- Internal math keeps full precision. 0.25 g rounding only for display and save.

## Success metrics
- Capture rate 90 percent
- Final wake autofilled on 60 percent of nights
- Clinician CSV acceptance 80 percent

## Workflows
- **Smart Event Logging:**
  - **Tap-to-log-now:** Single tap logs event at current time (default, fast path)
  - **Long-press for precision:** 0.5s long-press opens date & time picker sheet
  - **Date & time picker:** Wheel-style picker with 48 hours past to 6 hours future range
  - **All primary buttons support both modes:** In bed, Dose 1, Dose 2, Final wake
  - **Haptic feedback:** Medium impact on long-press for tactile confirmation
- **Dose 2 Override System:**
  - **Always-tappable button:** Dose 2 never visually disabled, policy gates show status via icons
  - **Gate routing:** Green checkmark (allowed) → direct log, Red X (blocked) → sheet explaining policy, Yellow warning (needs override) → override sheet
  - **Override capture:** Early/late override sheets with reason input, policy adherence tracking
  - **Policy defaults:** Early override **enabled by default** (180 min max), late override configurable
  - **Audit trail:** Override type, minutes deviation, reason, timestamp, source tracking
- Autofill final wake from WHOOP or Health

## Architecture
- Local SwiftData store with UTC timestamps and stored timezone offset per night
- WHOOP proxy with API key and rate limit
- **Event logging infrastructure:**
  - `PrimaryButton` component with `longPressAction` parameter for dual-mode interaction
  - `LongPressGesture(minimumDuration: 0.5)` with simultaneous gesture support
  - DatePicker sheets with `displayedComponents: [.date, .hourAndMinute]` and wheel style
  - Time range: `Date.now.addingTimeInterval(-48*3600)...Date.now.addingTimeInterval(6*3600)`
  - Source tracking: `tap_now`, `time_picker`, `override_early`, `override_late`
- **Policy enforcement:**
  - `Dose2Policy` struct with allowEarly/allowLate flags and max minute windows
  - `AppPreferencesEnhanced` singleton for app-wide defaults (stored in App Group UserDefaults)
  - Gate evaluation returns `.allowed`, `.denied`, or `.needsOverride` with contextual sheets

## Validation plan
- 14 day internal pilot with CSV review
- Unit tests for ordering guards and CSV
- **Smart logging validation:**
  - Verify tap-now logs at current time (< 1 second delay)
  - Verify long-press triggers haptic feedback and opens picker
  - Test date picker range (48h past to 6h future)
  - Test midnight crossover scenarios (yesterday's event logged today)
  - Verify all 4 buttons support both modes
- **Override system validation:**
  - Test gate routing (green/red/yellow icons)
  - Verify override sheets capture reason and track policy deviation
  - Validate early override default (180 min, enabled)
  - Test CSV export includes override columns
  - Verify audit trail completeness (type, minutes, reason, source)
