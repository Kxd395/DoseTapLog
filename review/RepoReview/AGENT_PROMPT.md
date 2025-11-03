# CodeX Agent Task - Full Repository Review and Scaffolding Validation

## Objective
Review the DoseTrack repository end-to-end, find conflicts or logical issues, confirm breadcrumbs and file mappings, identify missing components, actions, and states, and run build and data checks. Produce a clear, actionable report with reproducible commands and remediation PR suggestions.

## Scope
- iOS app in `ios/` using SwiftUI, SwiftData, HealthKit, WidgetKit, App Intents.
- WHOOP proxy service in `server/` using Node.js and Express.
- SQLite schema and migrations in `docs/` and SQL files.
- Documentation in `docs/` including PRD and ops notes.
- Review bundle in `review/DoseTrack_Update_111c_UI_Wiring/` if present.
- Our new components and settings as referenced in recent plans.

## Deliverables
Write all outputs to `review/RepoReview/output/` with these files:
- `REPORT.md` - Executive summary, key risks, and detailed findings.
- `ISSUES.md` - Numbered issues with severity, repro steps, expected vs actual, and fix proposals.
- `TEST_RESULTS.md` - Logs and pass-fail results for all tests in TEST_MATRIX.md.
- `FILEMAP.json` - A JSON graph of files, imports, and cross-references.
- `COVERAGE.md` - Which planned features exist, which are missing, and partials.
- `ACTIONS_STATES.md` - Table of UI actions and app states with coverage and gaps.
- `REMediation_PR_PLAN.md` - Proposed PRs with file diffs and commit messages.
- `RUN_LOG.md` - Timestamped log of everything you did.

Create subfolders if needed, for example `output/logs/` for raw command outputs.

## High-level tasks
1. Map the repo
   - Build a file map of `ios/`, `server/`, and `docs/`. Create `FILEMAP.json`.
   - Confirm presence of key files: TodayLogView.swift, TodayViewModel.swift, DoseLogController.swift, AppPreferences.swift, EarlyDoseSheet, SafetyBanner or SafetyBannerView, CountdownRing or CountdownRingView, AppIntents, Widget provider, HealthKit manager, CSV exporter, schema SQL files.
   - Identify duplicates or drift between `review/DoseTrack_Update_111c_UI_Wiring/` and `ios/`.

2. Static analysis and build smoke tests
   - On macOS: run `xcodebuild -list` then `xcodebuild -scheme DoseTrack -destination 'platform=iOS Simulator,name=iPhone 15' build`.
   - Collect warnings and errors into `output/logs/ios_build.log`.
   - For server: run `npm ci && npm test` if `server/` exists, capture output to `output/logs/server_test.log`.
   - If SwiftLint or SwiftFormat are present, run them and capture results.

3. UI wiring audit
   - Verify TodayLogView has a ScrollView or safeAreaInset dock to avoid clipped buttons.
   - Verify it uses a ViewModel with window gating for Dose 2 and presents early or late override flows.
   - Check that EventStrip renders last 3 events and Undo is limited time.
   - Confirm Live Activity starts at Dose 1 and ends at Dose 2 or expiry.
   - Confirm Safety Banner shows per-dose and nightly totals and turns invalid states red.
   - Output a table in `UI_WIRING_FINDINGS.md` with each requirement and status.

4. Settings coverage
   - Compare our 30+ AppPreferences keys with the Settings UI. Ensure every preference appears in settings, is persisted, and is read for behavior at runtime.
   - Output a checklist in `SETTINGS_GAPS.md`.

5. Data and persistence checks
   - Confirm SwiftData models match the SQLite schema intent.
   - Validate SQL in `SCHEMA_AUDIT.sql` against an initialized database if possible.
   - Confirm triggers for per-dose bounds, nightly totals, and the 150 to 240 minute window exist or are implemented in logic.

6. WHOOP proxy checks
   - Validate presence of `GET /health`, `/api/sleep/latest`, `/api/aggregates/7days` or the standardized routes.
   - Confirm rate limiting and API key middleware exist.
   - Curl each route and log to `output/logs/whoop_proxy.log` if server is available.

7. Actions vs states inventory
   - List all UI actions: In bed, Dose 1 now, Dose 2 now, Final wake, Alarm wake, Bathroom, Undo, Edit plan, Snooze 5m, Snooze 10m, Health autofill, Export, Reset Night, Late override, Early override.
   - List states: Idle, Waiting, Window open, Expired, Health OK or denied, WHOOP connected or offline, Wake source set.
   - Cross-map actions to the states in which they must be enabled or disabled.
   - Produce `ACTIONS_STATES.md`.

8. Testing
   - Use `TEST_MATRIX.md` for pass-fail. Where the environment is not available, mark as Not Run and describe how to run locally.
   - Provide reproducible commands per test and collect logs.

## Evidence policy
- For every finding, attach a pointer: a file path and line numbers or a log snippet. Use small snippets, not full file dumps.

## Output quality bar
- All lists numbered and cross-linked.
- Clear pass-fail for each test.
- Risk severity: critical, high, medium, low.
- Fix proposals include file names and example code diffs or pseudocode.
