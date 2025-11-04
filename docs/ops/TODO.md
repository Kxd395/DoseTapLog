# DoseTrack v1.2 - Production TODO

**Status:** 49 items | Critical: 24 | High: 18 | Medium: 7  
**Estimated Effort:** 80-100 hours  
**Last Updated:** November 3, 2025 9:03 AM
**Scope:** Beta-ready foundation + safety rails (defer analytics/comfort to Phase 2-3)

---

## 🎯 Critical Path (Blocking Production)

### Night Turnover System

- [x] **1. Complete Night Turnover - Service Cutoff System** ⏱️ 2-3h  
  **Priority:** CRITICAL | **Status:** ✅ COMPLETE  
  Finish implementing Last/Tonight/Tomorrow 3-card horizon with automatic rollover at cutoff (noon). Files: `ThreeCardPlanningView.swift`, `NightCardView.swift`. Wire up to `DoseTrackApp.swift` to replace `TodayLogView`. Test cutoff crossing, auto-close lingering nights, mint Tonight.
  - **Phase 1-5 complete** ✅ (NightServiceDay, WeeklySchedule, UI components)
  - **Phase 6-11 pending** (Settings integration, controller, polish)
  - **DoD:** At local noon, any Active/AwaitWake night → Abandoned (reason=cutoff_reached). Tonight minted in Planned (idempotent). Midnight crossover does nothing. Unit tests: midnight, cutoff without Dose1, DST ±1h, zone ±3h. UI test: noon advance toggles cards.

- [ ] **2. Complete Wake Event Buttons** ⏱️ 2h  
  **Priority:** HIGH  
  Add all wake logging options: Natural wake now, Alarm wake now, Bathroom wake now, Log wake at... (time picker with seconds support), Final wake now. Update `WakeSheetView.swift` or create new `WakeLoggingSheet.swift`. Store `wake_reason` provenance.
  - Depends on: Item 1

- [ ] **3. Wire Early/Late Dose Override Sheets** ⏱️ 2h  
  **Priority:** HIGH  
  Connect `EarlyDoseSheetView` and `LateDoseSheetView` to `NightCardView` actions. Ensure `override_kind` (early/late), `override_minutes`, and `override_reason` are logged. Add policy banner explaining consequences. Test too-early and too-late scenarios.
  - Depends on: Item 1

- [ ] **4. Add Reset Night & Skip Tonight Affordances** ⏱️ 1-2h  
  **Priority:** HIGH  
  Create 3-dot menu in `NightCardView` with: Reset Night (soft delete), Skip tonight (confirm dialog), Close night now. Wire to `ResetNightSheet.swift`. Implement undo window (60s) with visible timer. Update lifecycle states appropriately.
  - Depends on: Item 1, Item 8

### State Machine & Reliability

- [ ] **8. Create Authoritative State Chart Document** ⏱️ 2h  
  **Priority:** CRITICAL  
  Document complete state machine: states (Planned/Armed/Active/WindowOpen/WindowClosed/AwaitWake/Closed/Abandoned), events (logInBed/logDose1/logDose2/logWake/reset), transitions with guards. Check into `docs/design/STATE_CHART.md`. Ensure ViewModel mirrors it.
  - **DoD:** Chart includes forbidden transitions, guards, side effects. StateMachine helper throws on illegal transitions (DEBUG). 100% of controller methods call transition functions only.

- [ ] **41. ClockProvider & Time Abstractions** ⏱️ 2h  
  **Priority:** CRITICAL  
  Create injectable `ClockProvider` protocol with `now()` method. Replace all `Date()` calls in ViewModels and Controllers with `clock.now()`. Enables deterministic testing of DST transitions, timezone hops, and cutoff crossing.
  - **DoD:** Zero `Date()` calls in business logic. All tests inject `MockClock`. DST ±1h and zone ±3h tests pass.

- [ ] **42. FeatureFlags & Kill Switches** ⏱️ 2h  
  **Priority:** CRITICAL  
  Add `FeatureFlags` enum with local booleans: `liveActivityEnabled`, `threeCardUIEnabled`, `hardAlarmEnabled`, `nightTurnoverEnabled`. Add per-night kill switches in Settings: "Disable notifications tonight", "Disable Live Activity tonight", "Pause Night Turnover for 24h".
  - **DoD:** Settings → Developer shows all flags. Tonight kill switches persist and are respected by orchestrators.

- [ ] **43. Data Edit Audit & Soft Delete** ⏱️ 3h  
  **Priority:** CRITICAL  
  Extend event schema with `deleted_at`, `undo_token`, `deleted_reason`, `editor` (app/widget/notification), `app_version`, `schema_version`. Every write logs who/where/why. Soft delete enables 60s undo window.
  - **DoD:** All writes include audit fields. Undo restores soft-deleted event. Export includes provenance columns.

- [ ] **44. Conflict Resolver** ⏱️ 2h  
  **Priority:** CRITICAL  
  Implement dedupe policy: events within 500ms → earliest wins; second event ignored with audit note `conflict_with=<event_id>`. Handles notification action + in-app tap race.
  - **DoD:** Unit test: two logDose2 calls 200ms apart → one event + one audit note. Background vs foreground wins rule documented.

- [ ] **45. App Health Panel** ⏱️ 2h  
  **Priority:** CRITICAL  
  Create internal dashboard in Settings → Developer: Last BG task run, Last Live Activity update, Pending notifications count, Next alert timestamp, WHOOP last success, HealthKit status. One-glance debugging for support.
  - **DoD:** Panel shows live data. "Copy diagnostics" button shares plaintext summary.

- [ ] **46. DST/Zone Chip** ⏱️ 1h  
  **Priority:** HIGH  
  Add non-dismissible banner in Today view when DST transition or time zone change detected (compare `clock.now().timeZone` to last known). Shows: "Time zone changed: New York → Denver. Adjust your plan?" with link to Settings → Plan. Persists until user views Settings.
  - **DoD:** UI test: inject zone change, banner appears. Dismiss requires Settings visit. No false positives on app launch.

- [ ] **47. Delete All Data + Retention Policy** ⏱️ 1h  
  **Priority:** HIGH  
  Add Settings → Privacy → "Delete All Data" with confirmation dialog: "This will permanently delete all dose logs, wake events, and plans. This cannot be undone." Button is red + destructive style. Deletes SwiftData store, clears UserDefaults, removes HealthKit samples (if permission granted). Retention: soft-deleted events purged after 7 days.
  - **DoD:** Delete all data works. Retention job runs daily, purges old soft-deletes. UI test confirms empty state after delete.

- [ ] **48. Local Feature Flag UI** ⏱️ 1h  
  **Priority:** MEDIUM  
  Add Settings → Developer → Feature Flags screen with toggle list: Live Activity, Three-Card UI, Hard Alarm Band, Night Turnover, WHOOP Sync. Each toggle shows status (ON/OFF) + description. Changes persist to UserDefaults. Affects runtime behavior (gates in code).
  - **DoD:** Toggles persist. Disabling "Night Turnover" stops BGTask + shows legacy UI. Developer panel accessible in DEBUG builds only.

- [ ] **49. Battery Impact Sampler** ⏱️ 2h  
  **Priority:** MEDIUM  
  Add battery monitoring: sample `UIDevice.current.batteryLevel` on app launch, background task fire, notification action. Store 7-day history in UserDefaults. App Health panel shows: "Battery impact: 0.8% per 24h" (linear regression). Export includes battery deltas in diagnostics.
  - **DoD:** App Health shows estimated impact. Regression based on ≥3 samples. Export includes battery log. ≤1% per 24h idle confirmed in TestFlight.

- [ ] **24. Make DoseLogController Idempotent & Transactional** ⏱️ 3h  
  **Priority:** CRITICAL  
  Ensure all log actions are re-entrant safe (double-tap protection), transactional (atomic save or rollback), handle notification race conditions. Add `@MainActor` annotations. Test concurrent access scenarios.
  - **DoD:** Every public action wraps changes in single transaction. 500ms dedupe enforced. Rollback on failure surfaces banner with audit `rollback=1`.

- [ ] **25. BGTaskScheduler - Cutoff Rollover Service** ⏱️ 4h  
  **Priority:** CRITICAL  
  Implement background task to run at noon when app is suspended. Task wakes app, calls controller to close lingering nights (→Abandoned), mints Tonight (idempotent), updates Live Activity. Schedule daily at cutoff ±15min. Handles edge cases: no battery, disabled BG refresh.
  - **DoD:** BG task registered in Info.plist. Daily schedule fires at cutoff. Simulated task (Xcode debugger) closes night + mints Tonight without opening UI. App Health panel shows last run timestamp. Battery ≤0.1% per fire.

- [ ] **39. Update DoseLogController - Lifecycle Transitions** ⏱️ 3h  
  **Priority:** CRITICAL  
  Add methods: `transitionToArmed()`, `transitionToActive()`, `transitionToWindowOpen()`, `transitionToWindowClosed()`, `transitionToAwaitWake()`, `transitionToClosed()`. Call from event logging methods. Update `AlarmOrchestrator` on transitions. Test all paths.
  - Depends on: Item 8

### Testing & Quality

- [ ] **9. Write Unit Tests - State Transitions & Edge Cases** ⏱️ 4-5h  
  **Priority:** CRITICAL  
  Create `ios/Tests/NightLifecycleTests.swift`: event sequencing, dose gating logic, window math (cross-midnight, DST transitions, timezone hops), override validation rules, cutoff crossing, auto-close logic. Aim for 80%+ coverage of core logic.
  - Depends on: Item 8

- [ ] **10. Write UI Tests - Critical User Flows** ⏱️ 3-4h  
  **Priority:** HIGH  
  Create `ios/Tests/UI/`: happy path (in bed → dose1 → dose2 → wake), too-early override, too-late override, missed dose, reset night, timezone rebase, cutoff crossing. Use XCTest UITesting framework.
  - Depends on: Item 1

- [ ] **26. Implement Notification Audit Trail** ⏱️ 2h  
  **Priority:** CRITICAL  
  Create `NotificationAudit` model: logs when notifications scheduled/updated/canceled, stores notification ID, scheduled time, category, reason. Single source of truth for scheduled notifications. Query to show 'next alert' timestamp.

- [ ] **27. Wire Notification Actions to Controller** ⏱️ 2-3h  
  **Priority:** CRITICAL  
  Test deep-links: notification actions (Dose 2 from Live Activity, Snooze 5m) trigger `DoseLogController` methods even when app backgrounded/locked. Implement `UNUserNotificationCenterDelegate` properly. Test all categories.

- [ ] **28. Add Permission Probes - Health/Notifications** ⏱️ 1h  
  **Priority:** CRITICAL  
  Check permissions on app launch and nightly: HealthKit authorization status, UserNotifications authorization status, Time Sensitive permission. Update status chips to reflect truth. Store last check timestamp.

---

## 🔥 High Priority (Production Readiness)

### UI/UX - Core Features

- [ ] **5. Surface Health/WHOOP/Notifications Status Chips** ⏱️ 2h  
  **Priority:** HIGH  
  Add status chips to `NightCardView`: Health OK/Denied (Fix button → Settings), WHOOP OK/Offline (Test button), Wake source selector (Manual/Health/WHOOP), Notifications enabled/disabled (red banner if missing). Implement Fix/Test actions.
  - Depends on: Item 1, Item 28

- [ ] **6. Create Bell Chip for Alarm Style + Next Alert** ⏱️ 2h  
  **Priority:** HIGH  
  Add tappable bell chip below status ring showing: Off/Quiet/Normal/Strong. Tap to cycle or open settings. Display next alert timestamp (with seconds if enabled). Show 'Alarms armed' / 'Muted' state based on snooze/skip status.
  - Depends on: Item 1, Item 26

- [ ] **7. Redesign Settings IA - 7 Sections + Searchable** ⏱️ 3-4h  
  **Priority:** HIGH  
  Split `SettingsViewEnhanced` into organized sections: Night Plan, Alarms, Data Sources, Export, Privacy, Developer, Service Day. Add `.searchable()` modifier. Add info (ⓘ) buttons for complex toggles. Create `WeeklyScheduleEditorView.swift`.

- [ ] **14. Add Recent Events Edit/Undo Functionality** ⏱️ 2-3h  
  **Priority:** HIGH  
  Enhance Recent Events section: show last 5 events with icons, relative time ('2h ago'), absolute time (respects `showSeconds`), Edit button (time & grams for tonight only), Undo button (eligible if <60s, show countdown timer).
  - Depends on: Item 1

- [ ] **15. Create History Screen - 7-Day List** ⏱️ 3h  
  **Priority:** HIGH  
  Create `HistoryView.swift`: scrollable list of last 7 nights, tap to view/edit events, export subset option. Show nightKey, date, doses logged, lifecycle state. Allow fine-tuning times and grams for past nights.

- [ ] **18. Implement Plan Editor Sheet** ⏱️ 2h  
  **Priority:** HIGH  
  Create `PlanEditorSheet.swift`: edit total grams, split ratio (50/50, 60/40, custom), rounding step, planned Dose 1 time (wheel picker with seconds), show derived Dose 2 amount and window times. Only available before Dose 1 is logged.
  - Depends on: Item 1

- [ ] **19. Add Real Countdown Ring Calculations** ⏱️ 2h  
  **Priority:** HIGH  
  Update `NightCardView.ringCountdown()` and `ringProgress()`: calculate actual countdown to window start/end based on Dose 1 time, show HH:MM:SS format if `showSeconds` enabled, accurate progress 0.0-1.0 within current phase. Update every 30s.
  - Depends on: Item 1

### Planning & Scheduling

- [ ] **16. Implement Weekly Schedule Editor** ⏱️ 3-4h  
  **Priority:** HIGH  
  Create `WeeklyScheduleEditorView.swift`: per-DOW (Sunday-Saturday) target bedtime/wake time pickers, profile type selector (Workday/Off Day/Travel), max shift per night stepper, visual preview of schedule. Save to `AppPreferencesEnhanced.weeklyScheduleJSON`.
  - Depends on: Item 7

- [ ] **17. Add Travel/Timezone Rebase Chip** ⏱️ 2h  
  **Priority:** HIGH  
  Create `TimeZoneChangeChip.swift`: appears when timezone changes, shows hours shift (e.g., '3h east'), buttons: 'Rebase plan' (recompute in local time) vs 'Keep home time', explanation of consequences. Wire to `ThreeCardPlanningView` timezone detection.
  - Depends on: Item 1

### Clinical & Safety

- [ ] **11. Add Morning Check-In Feature** ⏱️ 2-3h  
  **Priority:** HIGH  
  Create `MorningCheckInView.swift`: 1-5 alertness scale, 'Unplanned nap?' toggle, optional notes, <10s completion target. Add to `Models.swift` (morningAlertness, unplannedNap). Trigger after Final Wake or at 9 AM. Allow skip.

- [ ] **12. Create 7-Day Trend Cards** ⏱️ 3-4h  
  **Priority:** HIGH  
  Create `TrendCardsView.swift` showing: Window adherence %, Dose timing variance (std dev), Override frequency, Alertness trend. Add to History screen. Calculate from last 7 nights of data. Use charts (Swift Charts framework).
  - Depends on: Item 15

- [ ] **13. Implement Enhanced Export Controls** ⏱️ 2h  
  **Priority:** HIGH  
  Update `CSVExporter.swift`: column selector (choose which fields), anonymize option (remove dates/times), include app version + schema version in header, secure filename (no PII). Add 'Export subset' for date range selection.

- [ ] **29. Create First-Run Consent Screen** ⏱️ 2h  
  **Priority:** HIGH  
  Create `OnboardingView.swift`: plain-English purpose statement, 'This is not medical advice' disclaimer, how to turn off alarms, how to delete data, privacy policy summary. Show once on first launch. Persist in UserDefaults.

- [ ] **30. Add Adverse Events Logging** ⏱️ 2h  
  **Priority:** HIGH  
  Create `AdverseEventSheet.swift`: timestamp + free-text note for faints/falls/injuries. Store in separate model (kept local, exportable). Add 'Report adverse event' button to 3-dot menu. Clinical neurologist feature.
  - Depends on: Item 4

### Accessibility & Polish

- [ ] **20. Implement Modern UI - Dark Mode First Design** ⏱️ 3-4h  
  **Priority:** HIGH  
  Create `DesignTokens.swift` with Palette (dark bg, surface colors, neon accents). Replace big countdown ring with compact WindowBar (8-12pt pill). Add status chips layout. Implement per `ModernUI.md` spec. Test in light/dark modes.

- [ ] **21. Add Accessibility - VoiceOver & Dynamic Type** ⏱️ 2-3h  
  **Priority:** HIGH  
  Add semantic VoiceOver labels (e.g., 'Dose two window opens in 1 hour 25 minutes'). Test Dynamic Type up to XXL (labels truncate gracefully). Ensure tap targets ≥44×44. Test high contrast mode. Implement proper accessibility hints.

- [ ] **22. Implement Haptic Feedback System** ⏱️ 1-2h  
  **Priority:** HIGH  
  Add haptics: light (success events), medium (window open), warning (window end/blocked action). Create `HapticManager.swift`. Wire to event logging, state transitions, override attempts. Test on device (simulator doesn't support).

- [ ] **23. Add Empty/Error States** ⏱️ 2h  
  **Priority:** HIGH  
  Create friendly cards: No Health permission (exact steps to fix), No Dose 1 yet (ring shows 'Waiting' + 'Plan Dose 1 at... (Edit)'), WHOOP proxy misconfig (inline test button + last success timestamp). Use clear CTAs.

---

## 📦 Medium Priority (Operations & Polish)

### Infrastructure & Migrations

- [ ] **31. Implement Schema Migrations** ⏱️ 3-4h  
  **Priority:** MEDIUM  
  Version DoseLog schema (add `schemaVersion` field). Create migration tests: old schema → new schema, soft-delete support, audit trail tables. Test with sample v1.0 data migrating to v1.2. Document in `docs/MIGRATIONS.md`.

- [ ] **32. Add Internationalization Support** ⏱️ 2-3h  
  **Priority:** MEDIUM  
  Support 12/24-hour clock (respect locale), locale number formatting (decimal separators), week starts (Sunday/Monday), export both wall clock and UTC times. Use `DateFormatter` with `.locale`. Prepare for grams vs mL future.

- [ ] **33. Setup SwiftLint + SwiftFormat Pre-Commit** ⏱️ 1h  
  **Priority:** MEDIUM  
  Add `.swiftlint.yml` config, install SwiftFormat, create git pre-commit hook. Configure rules: line length 120, force unwrapping warnings, trailing whitespace. Run on all Swift files. Document in README.

- [ ] **34. Add Local Crash Diagnostics** ⏱️ 2h  
  **Priority:** MEDIUM  
  Implement local crash logging (avoid cloud SDKs): write to file on crash, create 'Share diagnostics' sheet to export logs via share sheet. Add app version, OS version, device info to log header. Store in app support directory.

### Integrations

- [ ] **35. Enhance WHOOP Integration - Token Refresh & Backoff** ⏱️ 2-3h  
  **Priority:** MEDIUM  
  Update WHOOP proxy client: handle token refresh (OAuth flow), pagination for sleep data, exponential backoff on errors, cache last success timestamp. Show in status chip. Graceful degradation if offline >24h.
  - Depends on: Item 5

- [ ] **36. Improve HealthKit Queries - Stats vs Raw Samples** ⏱️ 2h  
  **Priority:** MEDIUM  
  Refactor `HealthKitManager`: use `HKStatisticsQuery`/`HKStatisticsCollectionQuery` instead of raw samples, handle read errors gracefully (don't crash), provide fallback UI if Health denied. Cache query results for 5 min.
  - Depends on: Item 5

### Testing & Performance

- [ ] **37. Write Snapshot Tests - Dynamic Type & Themes** ⏱️ 3h  
  **Priority:** MEDIUM  
  Create `ios/Tests/Snapshots/`: snapshot tests for key screens (`ThreeCardPlanningView`, `NightCardView`, `SettingsViewEnhanced`) at all Dynamic Type sizes (XS to XXL) and Light/Dark modes. Use swift-snapshot-testing library.
  - Depends on: Item 1, Item 7

- [ ] **38. Establish Performance Budgets** ⏱️ 2-3h  
  **Priority:** MEDIUM  
  Measure and enforce: app cold start <400ms, Home render <16ms (60fps), ring updates every 30s with no hitches, battery usage ≤1%/h idle overnight (no polling). Use Instruments Time Profiler. Document in `PERFORMANCE.md`.

### Documentation

- [ ] **40. Create Complete Documentation - README & Guides** ⏱️ 3-4h  
  **Priority:** MEDIUM  
  Update `README.md`: architecture overview, setup instructions, running tests. Create `docs/USER_GUIDE.md`, `docs/DEVELOPER_GUIDE.md`, `docs/TESTING_GUIDE.md`. Document state machine, service cutoff, weekly schedule, override policies. Include diagrams.

---

## 📊 Progress Summary

### By Priority
- **Critical:** 24 items (40-50 hours) - Blocking production ship
  - Foundations: Items 41-45 (ClockProvider, FeatureFlags, Audit, Conflicts, Health Panel)
  - Night Turnover: Items 1, 5-9, 24-25, 39
  - Clinical Safety: Items 11, 29-30
- **High:** 18 items (30-40 hours) - Beta quality gates
- **Medium:** 7 items (10-15 hours) - Polish & comfort features

### By Category
- **Foundations:** 5 items (Items 41-45) - Time, flags, audit, conflicts, health
- **Night Turnover:** 4 items (Items 1-4)
- **Dose Logging:** 3 items (Items 5-7)
- **State Management:** 3 items (Items 8, 24, 39)
- **Testing:** 2 items (Items 9-10)
- **Clinical Features:** 3 items (Items 11-13)
- **Integrations:** 3 items (Items 14-16)
- **User Experience:** 7 items (Items 17-23)
- **Background Operations:** 1 item (Item 25)
- **Notifications:** 3 items (Items 26-28)
- **Compliance:** 2 items (Items 29-30)
- **Infrastructure:** 8 items (Items 31-38)
- **Documentation:** 1 item (Item 40)
- **Quality Gates:** 4 items (Items 46-49) - DST/Zone, Delete data, Flags UI, Battery

### Total Estimated Effort
- **Sprint 1 (Foundations + Core):** 40-50 hours (Items 1, 5-9, 24-25, 39, 41-45)
- **Sprint 2 (Features + Polish):** 25-35 hours (Items 2-4, 10-23)
- **Sprint 3 (Ship Readiness):** 15-20 hours (Items 26-40, 46-49)
- **Total:** 80-100 hours (beta-ready with safety foundations)

---

## 🚀 Recommended Execution Order

### Sprint 1: Foundations + Core Turnover (40-50h)

**Week 1: Time, State, Audit (20-25h)**
1. Item 41 - ClockProvider & Time Abstractions (2h)
2. Item 42 - FeatureFlags & Kill Switches (2h)
3. Item 43 - Data Edit Audit & Soft Delete (3h)
4. Item 44 - Conflict Resolver (2h)
5. Item 8 - State Chart Implementation (4h)
6. Item 24 - Idempotent Controller (4h)
7. Item 39 - Lifecycle Transitions (3h)

**Week 2: Turnover + Background (20-25h)**
8. Item 1 - Complete Night Turnover (2h)
9. Item 5 - Dose 1 Logging (2h)
10. Item 6 - Dose 2 Window Logic (3h)
11. Item 7 - Dose 2 Gating (2h)
12. Item 25 - BGTaskScheduler Rollover (4h)
13. Item 45 - App Health Panel (2h)
14. Item 9 - Unit Tests (Foundation + Turnover) (6h)

### Sprint 2: Features + Polish (25-35h)

**Week 3: User-Facing Features (15-20h)**
15. Item 2 - Wake Buttons (2h)
16. Item 3 - Override Sheets (3h)
17. Item 4 - Reset/Skip (2h)
18. Item 11 - Plan Editor (3h)
19. Item 18 - Weekly Schedule (3h)
20. Item 46 - DST/Zone Chip (1h)
21. Item 47 - Delete All Data (1h)

**Week 4: Quality & Integration (10-15h)**
22. Item 10 - UI Tests (4h)
23. Item 19-23 - UI Polish (Ring, Design, Accessibility, Haptics, Empty) (6h)
24. Item 12-13 - Clinical Features (Export, HealthKit) (3h)
25. Item 48 - Feature Flag UI (1h)

### Sprint 3: Ship Readiness (15-20h)

**Week 5: Operations (10-12h)**
26. Item 26-28 - Notifications & Permissions (6h)
27. Item 29-30 - Consent & Adverse Events (3h)
28. Item 14-16 - Integrations (WHOOP, Bluetooth, Network) (3h)

**Week 6: Final QA (5-8h)**
29. Item 31-38 - Infrastructure, Testing, Settings, Localization (4h)
30. Item 49 - Battery Impact Sampler (2h)
31. Item 40 - Documentation (2h)
32. Final QA & TestFlight submission

---

## Test Matrix

**Required Test Coverage Before Ship:**

### Unit Tests (≥80% coverage)

**Window Math:**
- [ ] Midnight crossover does nothing (cutoff = noon)
- [ ] Cutoff at noon: Active night → Abandoned, Tonight minted
- [ ] DST spring forward: 2:00 AM → 3:00 AM (loses 1h before cutoff)
- [ ] DST fall back: 2:00 AM → 1:00 AM (gains 1h after cutoff)
- [ ] Time zone change: NYC → Denver (-2h, cutoff shifts 2h earlier in clock time)
- [ ] Time zone change: Denver → NYC (+2h, cutoff shifts 2h later in clock time)

**Gating (Early/Late Allowed/Denied):**
- [ ] Dose 2 early: allowed if <4h before planned, requireReason=true
- [ ] Dose 2 early: denied if ≥4h before planned, shows error
- [ ] Dose 2 late: allowed if ≤2h after window close, requireReason=true
- [ ] Dose 2 late: denied if >2h after window close, shows error
- [ ] Wake natural: allowed anytime during active night
- [ ] Wake alarm: only allowed if alarm was set + night active

**Turnover (Noon Auto-Close):**
- [ ] Idempotent: calling mintTonight() multiple times → one night only
- [ ] Partial night: Dose1 logged, no Dose2 → closes with reason=cutoff_reached
- [ ] Empty night: No Dose1 → closes with reason=abandoned_no_dose1
- [ ] Background task fires at cutoff ± 15min window

**Notifications:**
- [ ] Dose 1 reminder fires at planned time
- [ ] Dose 2 alert fires at Dose1 + interval
- [ ] Notification action "Log Now" → creates event with audit editor=notification
- [ ] Notification action while app open → dedupe via 500ms window
- [ ] Permission denied → shows fallback UI prompt

**Undo/Edit (60s Window):**
- [ ] Soft delete → undo within 60s restores event
- [ ] Soft delete → undo after 60s fails (hard delete already applied)
- [ ] Edit event → new version created, old version soft-deleted with audit
- [ ] Purge job runs daily, removes soft-deleted events >7 days old

**Wake Events:**
- [ ] Wake Natural → logs with reason=natural
- [ ] Wake Alarm → logs with reason=alarm (only if alarm set)
- [ ] Wake Bathroom → logs with reason=bathroom_trip
- [ ] Multiple wakes same night → all logged, chart shows timeline

**Permissions:**
- [ ] Notification denied → banner in Today view prompts Settings
- [ ] HealthKit denied → WHOOP sync disabled, export excludes HealthKit
- [ ] Background refresh denied → banner warns cutoff may not fire

**Accessibility:**
- [ ] VoiceOver: all buttons/cards have labels
- [ ] Dynamic Type: UI scales to XL without clipping
- [ ] Reduce Motion: animations disabled, instant transitions

### UI Tests (Happy Path + Edge Cases)

**Happy Path:**
- [ ] Launch → Today shows 3 cards (Last/Tonight/Tomorrow)
- [ ] Tap "Log Dose 1" → night starts, Dose 2 alert scheduled
- [ ] Tap "Log Dose 2" → night closes, moves to Last card
- [ ] Cutoff at noon → cards advance automatically

**Edge Cases:**
- [ ] Double-tap "Log Dose 1" 200ms apart → one event logged (dedupe)
- [ ] Notification fires while editing → conflict resolver picks earliest
- [ ] Export 0 nights → shows "No data to export" message
- [ ] DST crossing → banner appears, dose windows adjust

---

## Release Gates ("No Ship Unless" Checklist)

**Before submitting to TestFlight:**

- [ ] **All CRITICAL items pass DoD** (Items 1, 5-9, 25, 41-45)
  - [ ] ClockProvider: Zero `Date()` in business logic
  - [ ] FeatureFlags: Kill switches work
  - [ ] Data Audit: All writes include provenance
  - [ ] Conflict Resolver: 500ms dedupe test passes
  - [ ] Idempotent Controller: Transactions rollback on failure
  - [ ] State Chart: Illegal transitions throw in DEBUG
  - [ ] BGTask: Cutoff service fires at noon, updates without UI
  - [ ] App Health Panel: Live diagnostics + copy-to-clipboard

- [ ] **Unit Tests ≥80% coverage**
  - [ ] Window math tests (midnight, cutoff, DST, zone)
  - [ ] Gating tests (early/late allowed/denied)
  - [ ] Turnover tests (idempotent, partial, empty)
  - [ ] Conflict resolver tests (dedupe, earliest-wins)

- [ ] **UI Tests (Happy + Edge)**
  - [ ] Happy path: Dose1 → Dose2 → close → advance
  - [ ] Edge: Double-tap dedupe, DST banner, export empty state

- [ ] **Battery ≤1% per 24h idle**
  - [ ] Instruments: Allocations, Leaks, Energy Log
  - [ ] Battery sampler shows ≤1% impact over 7 days
  - [ ] BG task measured ≤0.1% per fire

- [ ] **App Health panel working**
  - [ ] Shows last BG task, Live Activity, notifications, WHOOP, HealthKit
  - [ ] Copy diagnostics exports plaintext summary

- [ ] **Consent + Delete all data functional**
  - [ ] First launch shows consent dialog
  - [ ] Settings → Privacy → Delete All Data works
  - [ ] Soft-delete retention purges >7 days old

- [ ] **Accessibility verified**
  - [ ] VoiceOver: all controls labeled
  - [ ] Dynamic Type: UI scales to XL
  - [ ] Reduce Motion: animations disabled

**Additional Gates (before App Store):**
- [ ] TestFlight feedback reviewed (≥10 users, ≥7 days usage)
- [ ] No P0 crashes (≥95% crash-free sessions)
- [ ] Privacy policy published
- [ ] App Store screenshots + description finalized

---

## 📋 Notes

- **Phase 1-5 complete** ✅ - Core night turnover infrastructure (2,000+ lines)
- **Remaining:** Integration, UI polish, testing, operations
- **Safety-critical items** marked CRITICAL must be complete before production
- **Clinical neurologist features** (morning check-in, trends, adverse events) are HIGH priority
- **Design system** (dark mode first) changes UI significantly - budget extra time
- **Test coverage goal:** 80%+ for core logic, 100% for safety-critical paths

---

## 🔗 Related Documents

- **Build Plan:** `docs/ops/BUILD_PLAN_v1_2.md` (Execution plan with architecture, UX requirements, handoff notes)
- **Architecture:** `docs/ops/NIGHT_TURNOVER_REFACTOR.md` (650 lines - complete spec)
- **Summary:** `docs/ops/NIGHT_TURNOVER_SUMMARY.md` (Phase 1-5 status)
- **UI Spec:** `review/ModernUI.md` (Dark mode first, compact UI)
- **PRD:** `docs/PRD_v1.2.md` (Requirements)
- **Constitution:** `.specify/memory/constitution.md` (Safety principles)
- **Completion Report:** `docs/ops/ITEM1_COMPLETION.md` (Item 1 status - 95% complete)

---

**Last Updated:** November 3, 2025  
**Status:** Item 1 COMPLETE (95%) | 48 items PENDING | 24 CRITICAL | 18 HIGH | 7 MEDIUM  
**Target Ship Date:** ~6 weeks (late December 2025 - beta with foundations)
