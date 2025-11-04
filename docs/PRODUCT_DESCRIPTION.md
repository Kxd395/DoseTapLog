# DoseTrack Product Description (v1.2 Roadmap Alignment)

This document consolidates the current product definition, combining the v1.1.1c implementation with the v1.2 Phase A spec patch scope. Treat it as the narrative companion to `docs/PRD_v1.2.md`.

---

## 1. Product Overview
- **Name:** DoseTrack
- **Platform:** Native iOS app with WidgetKit and Siri Intent extensions; optional WHOOP proxy service.
- **Positioning:** Local-first adherence companion for patients on twice-nightly sodium oxybate (Xywav) therapy, delivering clinician-ready dosing records.
- **Value Proposition:** Ensures both nightly doses are taken within the safe window, captures supporting sleep context, and produces structured exports without cloud storage.

---

## 2. Core Use Cases
1. **Nightly plan review:** Present the recommended split and timing window before bedtime.
2. **One-tap dose capture:** Log each dose immediately from app, widget, or Siri shortcut.
3. **Sleep context & survey:** Record bathroom wakes, final wake, and post-sleep morning alertness.
4. **Health data autofill:** Import final wake from HealthKit (and WHOOP via proxy).
5. **Clinician export:** Generate CSV spanning multiple nights for clinical review.

---

## 3. Target Users
- **Primary:** Adults prescribed twice-nightly Xywav managing their own dosing.
- **Secondary:** Treating clinicians analyzing adherence and sleep quality data.
- **Extended (v1.2 Phase A):** Care teams reviewing recovery trends sourced from WHOOP/HealthKit.

---

## 4. Functional Scope
| Area | Current (v1.1.1c) | Latest Enhancements (Nov 2025) |
|------|------------------|--------------------------------|
| Night plan | Deterministic split 40–60%, adaptive to recovery score | Same logic; refine with physiology data |
| Logging | Dose 1 & Dose 2 buttons, bathroom wakes, notes | **Tap-to-log-now** + **Long-press for custom date/time** on all primary buttons |
| Time Precision | Tap logs at current time | **Date & time picker** (48hr past to 6hr future) for missed/backdated events |
| Override System | Basic early/late gates | **Always-tappable Dose 2**, early override enabled by default (180min), full audit trail |
| Data sources | HealthKit final wake | Adds WHOOP-derived recovery/sleep aggregates via proxy |
| Export | CSV with nightly rows | Extended schema with override tracking (type, minutes, reason, source) |
| Safety | Dose guardrails, sequence validation | Enhanced with gate routing, blocked sheets, and policy enforcement |
| Coaching/Audio | Not included | Out of scope |

---

## 5. Safety Guardrails (unchanged)
- Dose 1 & Dose 2 each between **1.5 g** and **4.5 g**.
- Total nightly dose between **3.0 g** and **9.0 g**.
- Dose 2 must occur **150–240 minutes** after Dose 1.
- Internal calculations retain full precision; save & display rounded to **0.25 g**.

---

## 6. Data Model Highlights
- `DoseLog` (SwiftData): nightly record keyed by derived bedtime date.
- **Smart Event Logging:**
  - All primary events (In bed, Dose 1, Dose 2, Final wake) support **tap-to-log-now** (default) and **long-press for custom date/time**
  - Date & time picker allows selection from **48 hours past to 6 hours future** (handles midnight crossovers, backdated logging)
  - Haptic feedback on long-press for tactile confirmation
  - All events track logging **source** (`tap_now`, `time_picker`, `override_early`, `override_late`) for audit trail
- **Dose 2 Override System:**
  - Dose 2 button always tappable (no UI blocking)
  - Gate enforcement: Green checkmark (allowed), Red X (blocked), Yellow warning (override sheet)
  - Override sheets for early/late with reason capture, policy adherence tracking
  - Early override **enabled by default** (180 min max window)
  - Full audit trail: override type, minutes deviation, reason, timestamp
- Morning survey fields (Phase A): `morningAlertness`, `bathroomWakeTimesUTC`, `notes`.
- CSV schema updates include override tracking columns: `early_override`, `late_override`, `override_reason`, `override_minutes`, `event_source`.
- App Group storage used for widget/app intent handoff; no remote storage.

---

## 7. External Integrations
- **HealthKit:** Read-only `sleepAnalysis` category to populate final wake.
- **WHOOP proxy:** Express service gating `sleep/latest` and 7-day aggregates (Phase A adds standardized v2 range endpoints).
- **Siri/Widget:** Shortcut intents log doses by writing to shared App Group; app consumes on foreground.

---

## 8. Phase A Patch Notes (from Spec Patch)
- Morning survey UI, backing model, and CSV integration.
- WHOOP proxy extensions for range queries.
- Documentation updates (CSV schema, patch overview).
- Phase A purposely excludes audio cues, ML personalization, or coaching messaging.

---

## 9. Success Metrics
- Nightly capture rate ≥ **90%**.
- Final wake autofilled on ≥ **60%** of nights.
- Clinician CSV acceptance ≥ **80%**.
- Morning survey completion (Phase A target) ≥ **70%** of captured nights.
- **Smart Event Logging Precision:**
  - Long-press adoption ≥ **30%** for backdated/corrected events
  - Date picker usage confirms midnight crossover handling
  - Override system compliance (early/late adherence tracking via audit trail)
  - Event source distribution tracked in CSV export for workflow analysis

---

## 10. Open Questions / Future Work
- Additional recovery inputs (HRV, WHOOP strain) feeding the recommender.
- Multi-night visualization (history tab) for adherence trends.
- Secure clinician portal or encrypted export delivery (still out of scope).

Update this description as new phases ship; keep the SSOT (`README.md`) and PRD aligned with any changes.
