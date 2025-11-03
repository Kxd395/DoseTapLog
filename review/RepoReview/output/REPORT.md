# DoseTrack Repo Review – REPORT.md (v1.1.1c)

## Executive Summary
DoseTrack’s new SwiftUI module, settings overhaul, and persistence upgrades are present in the repository but are not actually shipping. The Xcode target still builds the legacy `DoseTrackIOS` sources, while the new `ios/` module contains compile-breaking regressions (Dose 1 action, late-dose overrides) and unimplemented wiring (Health/WHOOP state, Live Activity). Server automation runs, yet the WHOOP proxy tests fail out of the box, and the persistence layer diverges from the agreed schema, so guardrails and audit triggers never fire. Immediate remediation is required before the v1.1.1c update can be considered production-ready.

## Key Risks
- **Critical drift between code and build artefacts** – the shipping target ignores the updated SwiftUI implementation, so none of the audited fixes land in the app (Issue 1).
- **Dose 1 / Dose 2 flows broken in new module** – compile failures and missing late override hooks block the primary medication workflow (Issues 2–4).
- **Preference debt** – Health/WHOOP chips, notification toggles, snooze/export features, and override metadata do not execute at runtime, leaving critical UX gaps (Issues 5 & 7).
- **Data integrity gap** – SwiftData models bear little resemblance to the reviewed SQLite schema; guardrails, event logs, and triggers remain “TODO” (Issue 6).
- **Automation friction** – WHOOP proxy tests fail by default, masking regressions (Issue 8).

## Findings Overview
- `ios/` vs `DoseTrackIOS/` duplication: the new module is unreferenced, and the legacy target remains active. Build output confirms only the old code ships.
- `TodayLogView` regression: the Dose 1 button passes a closure with the wrong signature, preventing compilation when the new module is linked.
- Late-dose override implementation is split across incompatible files; persistence still only writes overrides into notes.
- Health/WHOOP state chips use constant values and empty callbacks; notification preferences feed into stub methods, so end users see no effect.
- Settings View exposes the promised 30+ toggles, but many are unused—CSV export, snooze, wake source, and Live Activity are all disconnected (`SETTINGS_GAPS.md`).
- SwiftData layer is a simplified `DoseLog`; review schema calls for normalized tables and guardrail triggers. The controller still references a future `event_log` table.
- WHOOP proxy server passes health checks but fails auth/rate-limit tests when credentials are absent; documentation doesn’t explain required setup.

## Test Status
- iOS build: Fails to meet requirement because iPhone 15 destination is missing and the legacy target builds instead of the new module. Functional tests for dosing and Live Activity are blocked.
- Server: Health endpoint passes; auth and rate-limit flows fail because the test harness expects live WHOOP credentials (`server_test.log`).
- Database: Schema audit succeeds against the review bundle SQL snapshot, but the app never creates those tables—feature work is required before database tests are meaningful.

## Recommended Next Steps
1. Integrate the `ios/` module into the shipping target and remove redundant sources (Remediation PR #1).
2. Fix the TodayLogView/Dose2 pipeline (compile error, late overrides, override persistence) and add tests (PR #2).
3. Wire HealthKit, WHOOP state, and notification toggles to real behaviour (PR #3).
4. Align the persistence layer with the review schema and implement the event log/guardrails (PR #4).
5. Close the preference gaps (export, snooze, wake source, Live Activity) and add coverage (PR #5).
6. Stabilise WHOOP proxy automation with env-aware tests and documentation (PR #6).
