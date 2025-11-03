# Issues (DoseTrack v1.1.1c)

1. **[Critical] New SwiftUI module not part of the shipping build**  
   - **Evidence:** `DoseTrackIOS/DoseTrackIOS/TodayLogView.swift:1` is the view referenced by the Xcode target; the new implementation lives in `ios/TodayLogView.swift` but is absent from `DoseTrackIOS.xcodeproj`. `xcodebuild` completes successfully while compiling only the legacy files (`review/RepoReview/output/logs/ios_build.log`).  
   - **Repro:** Open the project and run `xcodebuild -scheme DoseTrackIOS`. Observe the legacy UI at runtime; none of the new `ios/` components are linked.  
   - **Expected:** The updated `ios/` sources should replace the legacy target so the review bundle code ships.  
   - **Actual:** Builds still use the older `DoseTrackIOS/*` views, so all new wiring, settings, and guardrails are effectively dead code.  
   - **Fix proposal:** Update the project file (or create an SPM module) so `ios/*.swift` becomes the active target, remove the stale duplicates under `DoseTrackIOS/`, and re-run the build.

2. **[Critical] Dose 1 button fails to compile in new TodayLogView**  
   - **Evidence:** `ios/TodayLogView.swift:82` passes `vm.logDose1Now` (no arguments) into a `Button`, but `TodayViewModel.logDose1Now` requires a `grams: Double` parameter (`ios/TodayViewModel.swift:102-110`).  
   - **Repro:** Attempt to build the new `ios/` module; Swift emits “Cannot convert value of type…”.  
   - **Expected:** The button should call `vm.logDose1Now(grams: vm.prefs.planDose1G)` like the review bundle.  
   - **Actual:** The closure signature mismatch prevents compilation.  
   - **Fix proposal:** Update the button action to supply grams (or add a helper wrapper) and verify via build.

3. **[Critical] Late-dose extension conflicts with controller contract**  
   - **Evidence:** `ios/TodayViewModel+LateDose.swift:29-143` redeclares `isBeforeWindowButEligibleEarly` and `tryLogDose2`, and calls `controller.logDose2Now(… overrideKind:overrideMinutes:overrideReason:)` (`ios/TodayViewModel+LateDose.swift:79-114`). The `DoseLogControllering` protocol still exposes `logDose2Now(grams:overrideEarlyMinutes:overrideReason:)` (`ios/TodayViewModel.swift:186-204`), and the concrete controller implements the old signature (`ios/DoseLogController.swift:211-236`).  
   - **Repro:** Compile with the extension enabled; Swift reports duplicate declarations and “no member” errors.  
   - **Expected:** Late overrides should extend the existing method or introduce a new API that the controller implements.  
   - **Actual:** The extension does not compile and the controller cannot record late overrides.  
   - **Fix proposal:** Consolidate to one `tryLogDose2`, extend the protocol/controller to accept override metadata, and cover with unit tests.

4. **[High] Late-dose UI absent and override metadata never persisted**  
   - **Evidence:** The active TodayLogView shows only early override sheets (`ios/TodayLogView.swift:144-158`); there is no late-dose button. Even if invoked, `DoseLogController.logDose2Now` only appends a note string (`ios/DoseLogController.swift:219-223`) and never toggles `DoseLog.dose2IsOverride` or related fields (`ios/Models.swift:24-28`).  
   - **Repro:** Let the window expire, tap Dose 2 — there is no late override affordance. Inspect saved `DoseLog` rows; override flags remain zero.  
   - **Expected:** Late overrides should surface a confirmation sheet and populate the override columns for CSV/export.  
   - **Actual:** No UI exists and metadata is silently dropped.  
   - **Fix proposal:** Re-enable the late override sheet, wire it to a controller method that fills `dose2IsOverride`, `dose2OverrideKind`, `dose2OverrideMinutes`, `dose2OverrideReason`, and add regression tests.

5. **[High] Health/WHOOP/notification preferences have no runtime effect**  
   - **Evidence:** Status chips pass constant `true` flags and empty callbacks (`ios/TodayLogView.swift:33-35`). Notification toggles are read nowhere; `cancelDose2Notifications` and Live Activity handlers are TODOs (`ios/DoseLogController.swift:335-356`). `wakeSourcePreference` is never consumed.  
   - **Repro:** Toggle any permission/notification preference in Settings; app behaviour is unchanged.  
   - **Expected:** Chips should reflect actual state, tapping should prompt for permissions or WHOOP tests, and notification toggles should control scheduling.  
   - **Actual:** UI is static and preferences are inert.  
   - **Fix proposal:** Implement real HealthKit/WHOOP state checks, wire callbacks to `HealthKitManager` and the proxy client, and honor notification toggles in the scheduler.

6. **[Critical] SwiftData model diverges from required SQLite schema**  
   - **Evidence:** `ios/Models.swift:4-72` defines a single `DoseLog` entity. The review schema (`review/DoseTrack_SQLite_Review_Kit_v1.1.1c/sql/schema.sql:4-200`) expects `sleep_sessions`, `medication_events`, `event_log`, physiological data tables, and guardrail triggers. `DoseLogController.fetchRecentEvents` still notes “TODO: Implement event_log table” (`ios/DoseLogController.swift:92-96`).  
   - **Repro:** Compare SwiftData model with SQL bundle; run migrations—trigger enforcement and per-dose guardrails are absent.  
   - **Expected:** App models should mirror the schema so guardrails fire and exports match spec.  
   - **Actual:** App persists a simplified record, so SQL audits and triggers never run.  
   - **Fix proposal:** Align SwiftData entities with the schema (or adopt SQLite directly), create migrations, and ensure controller writes through the real tables.

7. **[Medium] CSV export ignores configuration toggles**  
   - **Evidence:** `ios/CSVExporter.swift:5-12` always writes `dosetrack_export_<UUID>.csv` with a fixed header; it never reads `exportIncludeTimezone`, `exportIncludeNotes`, `exportIncludeEventLog`, or `exportFilenamePattern` (`review/RepoReview/output/SETTINGS_GAPS.md`).  
   - **Repro:** Change export preferences, invoke export—output file and columns remain unchanged.  
   - **Expected:** Export should respect filename pattern and column toggles.  
   - **Actual:** Preferences are ignored.  
   - **Fix proposal:** Inject `AppPreferencesEnhanced` into the exporter, branch columns/filename accordingly, add a regression test.

8. **[Medium] WHOOP proxy tests fail by default**  
   - **Evidence:** `review/RepoReview/output/logs/server_test.log` shows `/api/sleep/latest` and `/api/aggregates/7days` returning `401`/`500` because `WHOOP_TOKEN` is unset; the test harness counts these as failures.  
   - **Repro:** Run `npm test` without credentials (as in CI); tests fail despite middleware working.  
   - **Expected:** Tests should either mock WHOOP or skip when token missing, with clear setup instructions.  
   - **Actual:** Default run fails, obscuring real regressions.  
   - **Fix proposal:** Guard tests behind env checks or mock responses, and document required env vars in `server/README_server.md`.
