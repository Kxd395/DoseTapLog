# Feature Coverage Snapshot

## iOS App
- ❌ New SwiftUI module under `ios/` is not part of the shipped `DoseTrackIOS` Xcode target; the build succeeds using legacy views (`DoseTrackIOS/TodayLogView.swift`), so the reviewed components never ship.
- ⚠️ TodayLogView in `ios/` wires the countdown and reset flows, but the Dose 1 button cannot compile (`ios/TodayLogView.swift:82`) and late override UI/logic is absent (`ios/TodayViewModel+LateDose.swift:79`).
- ❌ Live Activity integration is still TODO (`ios/DoseLogController.swift:345-356`); notification preferences have no effect.
- ⚠️ Early dose overrides surface, yet override metadata is only appended to notes and does not fill the dedicated SwiftData fields (`ios/DoseLogController.swift:211-224`).
- ❌ Health/WHOOP status chips are placeholders with `true` constants and empty callbacks (`ios/TodayLogView.swift:33-35`); wake-source preference is ignored.
- ⚠️ SettingsViewEnhanced exposes seven sections, but many toggles are not read anywhere at runtime (see `SETTINGS_GAPS.md`).
- ❌ Snooze actions, Health autofill, CSV export entry points, and WHOOP quick test buttons are unimplemented.
- ⚠️ Event history shows three synthetic records from `DoseLog`, but there is no dedicated `event_log` store and undo is limited to the last entry only.

## Server (WHOOP Proxy)
- ✅ Express app exposes `/health`, `/api/sleep/latest`, and `/api/aggregates/7days` with rate limiting and API key middleware (`server/index.js:8-104`).
- ⚠️ Automated tests fail—WHOOP calls return `401` without `WHOOP_TOKEN`, and auth-negative cases are treated as failures in `test-server.js` (see `review/RepoReview/output/logs/server_test.log`).
- ⚠️ Error responses for missing API key surface `500 server_config_error`; the review plan expects request failures to be counted as pass/fail with clear guidance.
- ❌ Settings for proxy URL/API key in the app are not consumed; there is no mobile client wiring to this service.

## Data & Persistence
- ❌ SwiftData model `DoseLog` (fields only for single-night flow) diverges drastically from the review schema requiring `sleep_sessions`, `medication_events`, triggers, and audit tables (`ios/Models.swift:4-72` vs `review/DoseTrack_SQLite_Review_Kit_v1.1.1c/sql/schema.sql`).
- ⚠️ SCHEMA_AUDIT.sql passes when run against the review schema snapshot, but the app never creates or enforces those tables/triggers (`review/RepoReview/output/logs/schema_audit.log`).
- ❌ CSV export ignores many preferences (timezone mask, event log toggle) and always emits a new temp file with fixed columns (`ios/CSVExporter.swift`).

## Documentation & Drift
- ❌ `docs/ops/INTEGRATION_COMPLETE.md` claims “components ready for integration,” yet Xcode still targets the legacy folder and critical compile issues remain in `ios/`.
- ⚠️ Review bundle (`review/DoseTrack_Update_111c_UI_Wiring/Sources`) contains updated files that diverge from `ios/`. No sync strategy or comparison has been executed; drift is growing.
