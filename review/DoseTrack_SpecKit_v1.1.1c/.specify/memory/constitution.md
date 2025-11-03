# DoseTrack Constitution
Version: 1.0
Adopted: 2025-11-01

## Safety and Medical Compliance
- All dose calculations must respect guardrails: 1.5 to 4.5 g per dose, 3.0 to 9.0 g total nightly.
- The app provides planning aids only. It does not provide medical advice.
- All timestamps are stored in UTC. Also record timezoneOffsetMinutes at Log Night creation for travel context.
- Calculations use full precision internally. Round to 0.25 g only at display and save.

## Privacy and Data Sovereignty
- Local first. No PHI leaves the device during the pilot. No analytics.
- HealthKit data is read only for Final Wake autofill with explicit user consent. No HealthKit data is persisted beyond the minimum fields saved in DoseLog.
- WHOOP proxy usage must require an x-api-key header and have rate limiting.
- App Group sharing is allowed only between the app and its widget on the same device.

## User Experience
- One tap logging for bedtime, Dose 1, Dose 2, bathroom wakes, and Final Wake.
- Auto populate grams from tonight's NightPlan.
- Auto schedule a local notification for Dose 2 at the window start.
- Autofill Final Wake from HealthKit. WHOOP fetch is optional as a manual action.
- Validate sequences. Alert when Dose 2 precedes Dose 1 or falls outside the window.

## Code Quality
- Swift, SwiftUI, SwiftData. Typed models with @Model. Unique nightKey per Log Night.
- Unit tests cover ordering guards, CSV export, rounding to 0.25 g, and window validation.
- Magic numbers live in Config.swift with clear names and comments.
- No hardcoded secrets. WHOOP tokens via environment or iOS Keychain only.

## Clinician Support
- CSV export in HH:mm format keyed by bedtime date. Uses stored timezone offset.
- Columns include doses, times, bathroom wakes, Final Wake, morning alertness, notes, and provenance for autofills.
- Target at least 80 percent clinician acceptance in pilot feedback.

## Governance
- Any change to guardrails or privacy must amend this constitution with an incremented version and date.
- Specs must be updated in the same pull request that changes behavior.
