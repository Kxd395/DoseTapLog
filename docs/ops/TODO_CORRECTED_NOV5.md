# DoseTrack v1.2 - Production TODO (CORRECTED - Nov 5 Audit)

**Status:** 80 items | ✅ 8 truly complete | ⚠️ 6 partial | 🔄 66 pending  
**Estimated Effort:** 180-240 hours (revised realistic estimate)  
**Last Updated:** November 5, 2025 (post-audit corrections)  
**Target Ship:** 8-10 weeks (4 weeks with descoping to Phase 2)

**⚠️ AUDIT CORRECTIONS APPLIED:**
- Removed misleading "COMPLETE" markers where DoD not met
- Reordered: Critical infrastructure items moved to Week 1
- Revised estimates with 1.5× buffer on complex items
- Added production-blocking requirements
- Deferred non-critical polish to Phase 2

---

## 🚨 NO-SHIP UNLESS (Enforced Quality Gates)

These **10 items** are BLOCKING:

1. ✅ **41 + 54** landed: ClockProvider + TimeMath; zero `Date()` in business logic
2. 🔄 **51** frozen notification categories/actions; automated CI check
3. 🔄 **52 + 52a** file protection Complete + BG write mode CompleteUntilFirstUserAuth
4. 🔄 **60** soft-wake: schedules, guard, audit trail wired; NO "looping" semantics
5. 🔄 **26** audit trail = source of truth for "next alert"; Bell chip reads it
6. 🔄 **9 + 10** unit tests ≥80% on time math + gating + turnover (named suites)
7. 🔄 **25** BGTask runs with ±1-3h jitter; App Health shows last run + next planned
8. 🔄 **70 + 70a** WHOOP proxy deployed prod, tokens persisted encrypted; health check
9. 🔄 **29** Health disclaimer prominent at first run (legal requirement)
10. 🔄 **21 + 57** accessibility: VO labels, 44×44 targets, focus order verified

**Shipping with incomplete gates = App Review rejection risk + user harm**

---

## 🎯 Week 1: Critical Infrastructure (MUST GO FIRST)

These items underpin everything else. Ship nothing until these are solid.

### Time & State Foundations

- [ ] **41. ClockProvider Abstraction** ⏱️ 2-3h  
  **Priority:** 🚨 CRITICAL (Week 1, Day 1)  
  **Status:** NOT STARTED  
  Create injectable time source to eliminate `Date()` from business logic:
  ```swift
  protocol ClockProvider {
      func now() -> Date
      func nowUTC() -> Date
      func localOffset() -> Int  // minutes from UTC
  }
  
  class SystemClock: ClockProvider { /* real */ }
  class TestClock: ClockProvider { /* mocked for tests */ }
  ```
  - **DoD:**
    - [x] Protocol defined with 3 methods
    - [ ] SystemClock implementation (production)
    - [ ] TestClock implementation (unit tests can set time)
    - [ ] All controllers accept `clock: ClockProvider` in init
    - [ ] Zero `Date()` calls in Models.swift, DoseLogController.swift, TodayViewModel.swift
    - [ ] Unit tests: DST ±1h, timezone ±3h, cross-midnight
  - **Why First:** Every time-dependent test depends on this
  - Files: NEW `ios/ClockProvider.swift`
  - **Reference:** Auditor Red Flag #11

- [ ] **54. TimeMath Utility Module** ⏱️ 2-3h  
  **Priority:** 🚨 CRITICAL (Week 1, Day 1)  
  **Status:** NOT STARTED  
  Centralize all date/time calculations to reduce bugs:
  ```swift
  enum TimeMath {
      static func minutesBetween(_ start: Date, _ end: Date) -> Int
      static func isWithinWindow(_ time: Date, start: Date, windowMin: Int, windowMax: Int) -> Bool
      static func nextCutoff(from now: Date, cutoffHour: Int, tz: TimeZone) -> Date
      static func serviceDayKey(for time: Date, cutoffHour: Int, tz: TimeZone) -> String
  }
  ```
  - **DoD:**
    - [ ] All time math moved from views → TimeMath module
    - [ ] Unit tests: DST spring/fall ±1h
    - [ ] Unit tests: timezone PST/EST/UTC (±3h)
    - [ ] Unit tests: midnight crossing (11:59pm → 12:01am)
    - [ ] Unit tests: cutoff crossing (11:59am → 12:01pm)
    - [ ] 100% code coverage on time logic
  - **Depends on:** Item 41 (ClockProvider)
  - Files: NEW `ios/TimeMath.swift`
  - **Reference:** Auditor Red Flag #11

- [ ] **8. State Machine Enforcement** ⏱️ 3-4h  
  **Priority:** 🚨 CRITICAL (Week 1, Day 2)  
  **Status:** PARTIAL (doc exists, no enforcement)  
  Create StateMachine module to guard illegal transitions:
  ```swift
  enum StateMachine {
      static func transition(_ night: DoseLog, to newState: NightLifecycleState) throws
      // Throws InvalidTransition in DEBUG; logs error in RELEASE
  }
  
  // Allowed transitions (enforced):
  // Planned → Active (Dose1 logged)
  // Active → AwaitWake (Dose2 logged)
  // AwaitWake → Closed (Final wake logged)
  // Any → Abandoned (cutoff reached, reset night)
  ```
  - **DoD:**
    - [ ] StateMachine module with transition() method
    - [ ] DEBUG: `fatalError()` on illegal transition
    - [ ] RELEASE: Log error, allow (graceful degradation)
    - [ ] All controllers call StateMachine.transition() (not direct assignment)
    - [ ] Unit tests: all 12 legal transitions pass
    - [ ] Unit tests: all illegal transitions throw/log
    - [ ] Audit of existing code: zero direct `lifecycleState =` assignments
  - **Depends on:** None (foundational)
  - Files: NEW `ios/StateMachine.swift`, modify all controllers
  - **Reference:** Auditor Red Flag #10

- [ ] **24. Idempotent State Writes** ⏱️ 2-3h  
  **Priority:** 🚨 CRITICAL (Week 1, Day 2)  
  **Status:** NOT STARTED  
  Ensure repeated calls to logDose1/logDose2 don't duplicate or corrupt:
  ```swift
  func logDose1(...) {
      guard night.dose1TimeUTC == nil else {
          logger.warning("Dose 1 already logged, ignoring duplicate")
          return  // Idempotent: no-op on 2nd call
      }
      // ... normal logic
  }
  ```
  - **DoD:**
    - [ ] logDose1/logDose2 check existing value before overwrite
    - [ ] Widget actions deduplicated (if queued twice within 500ms)
    - [ ] Unit tests: call logDose1 twice → only 1 row written
    - [ ] Unit tests: concurrent widget + app tap → Item 44 (conflict resolver)
    - [ ] Audit log: record duplicate_attempt with conflict_with field
  - **Depends on:** Item 8 (StateMachine)
  - Files: Modify `ios/DoseLogController.swift`
  - **Reference:** Auditor Red Flag #12

---

### Notification & Storage Hardening

- [ ] **51. Freeze Notification IDs** ⏱️ 0.5-1h  
  **Priority:** 🚨 CRITICAL (Week 1, Day 1)  
  **Status:** NOT STARTED  
  Lock down `UNNotificationCategory` and action IDs to prevent breaking changes:
  ```swift
  // ios/NotificationHelper.swift
  enum NotificationID {
      static let dose2Window = "dose2_window"  // FROZEN
      static let softWake = "soft_wake"        // FROZEN
      // Add new IDs here, never rename existing
  }
  
  enum NotificationAction {
      static let dose2Now = "dose2_now"        // FROZEN
      static let snooze15 = "snooze_15"        // FROZEN
  }
  ```
  - **DoD:**
    - [ ] All notification strings in NotificationID enum
    - [ ] CI check: fail if any ID renamed (string literal search)
    - [ ] Documentation: "Never rename IDs; add new ones only"
    - [ ] Existing notifications migrated to enum
  - **Depends on:** Items 26, 27 (notification audit/soft-wake design)
  - Files: Modify `ios/NotificationHelper.swift`
  - **Reference:** Auditor Red Flag #9

- [ ] **52. Storage Hardening (NSFileProtectionComplete)** ⏱️ 1-2h  
  **Priority:** 🚨 CRITICAL (Week 1, Day 3)  
  **Status:** NOT STARTED  
  Set file protection level to `Complete` for SQLite + exports:
  ```swift
  // DoseTrackApp.swift
  let container = try ModelContainer(
      for: [DoseLog.self, NightFeatures.self],
      configurations: ModelConfiguration(
          isStoredInMemoryOnly: false,
          allowsSave: true,
          cloudKitDatabase: .none,
          fileProtection: .complete  // ← Strongest encryption
      )
  )
  ```
  - **DoD:**
    - [ ] SwiftData container uses .complete protection
    - [ ] Exports (CSV/JSONL) written with .complete
    - [ ] Test: device locked before first unlock → write fails gracefully
    - [ ] Test: device unlocked → writes succeed
  - **Depends on:** None
  - Files: Modify `ios/DoseTrackApp.swift`, `ios/DoseLogExporter.swift`
  - **Reference:** Auditor Red Flag #8

- [ ] **52a. Background Write Protection Mode** ⏱️ 1-2h  
  **Priority:** 🚨 CRITICAL (Week 1, Day 3)  
  **Status:** NOT STARTED (NEW ITEM per audit)  
  Use `CompleteUntilFirstUserAuthentication` for background task writes:
  ```swift
  // Background task handler
  let bgContainer = try ModelContainer(
      for: [DoseLog.self],
      configurations: ModelConfiguration(
          fileProtection: .completeUntilFirstUserAuthentication  // ← BG-safe
      )
  )
  ```
  - **DoD:**
    - [ ] BGTask writes use .completeUntilFirstUserAuthentication
    - [ ] Foreground writes still use .complete (strongest)
    - [ ] Test: BG task at 3am (locked device) → write succeeds
    - [ ] Documentation: explain dual protection levels
  - **Depends on:** Item 52
  - Files: Modify `ios/DoseTrackApp.swift` (background task handler)
  - **Reference:** Auditor Red Flag #8, new requirement

- [ ] **26. Notification Audit Trail** ⏱️ 2-3h  
  **Priority:** 🚨 CRITICAL (Week 1, Day 4)  
  **Status:** NOT STARTED  
  Create single source of truth for "what alert is next":
  ```swift
  struct NotificationAudit: Codable {
      let id: UUID
      let type: String  // "dose2_window", "soft_wake", etc.
      let scheduledFor: Date
      let deliveredAt: Date?
      let actionTaken: String?  // "dose2_now", "snooze_15", "dismiss"
      let source: String  // "tap", "notification_action", "background"
  }
  ```
  - **DoD:**
    - [ ] All scheduled notifications logged to audit trail
    - [ ] Delivered notifications marked with deliveredAt timestamp
    - [ ] User actions logged (dose2_now, snooze, dismiss)
    - [ ] Bell chip in UI reads from audit trail (not UNUserNotificationCenter)
    - [ ] Export to JSONL for debugging
    - [ ] Unit tests: schedule → deliver → action flow
  - **Depends on:** Items 51 (frozen IDs)
  - Files: NEW `ios/NotificationAudit.swift`, modify `ios/NotificationHelper.swift`
  - **Reference:** Auditor Red Flag #5 (no-ship item 5)

---

## 🎯 Week 2: Core Features (After Infrastructure)

### Night Turnover & Gating

- [~] **1. Complete Night Turnover - Service Cutoff System** ⏱️ 4-6h (revised from 2-3h)  
  **Priority:** CRITICAL  
  **Status:** ⚠️ PARTIAL (Phases 1-5 complete, 6-11 pending, tests missing)  
  **Completed:**
  - ✅ NightServiceDay logic (noon cutoff, service day keys)
  - ✅ WeeklySchedule UI components
  - ✅ ThreeCardPlanningView basic structure
  
  **Remaining Work:**
  - [ ] Settings integration (cutoff hour picker)
  - [ ] NightTurnoverController with StateMachine integration
  - [ ] Auto-close at cutoff (Active/AwaitWake → Abandoned)
  - [ ] Tonight minting (idempotent)
  - [ ] Unit tests: cutoff crossing (11:59am → 12:01pm)
  - [ ] Unit tests: midnight crossing (no change)
  - [ ] Unit tests: DST spring/fall ±1h
  - [ ] Unit tests: timezone changes ±3h
  - [ ] UI test: noon advance toggles cards
  
  - **DoD (CORRECTED):**
    - [ ] At local noon, Active/AwaitWake → Abandoned (reason=cutoff_reached)
    - [ ] Tonight minted in Planned (idempotent)
    - [ ] Midnight crossing = no-op
    - [ ] Unit tests: 8 named test cases (DST, TZ, cutoff, midnight)
    - [ ] UI test: simulate noon crossing → cards update
  - **Depends on:** Items 41, 54, 8 ← BLOCKING
  - Files: `ThreeCardPlanningView.swift`, `NightTurnoverController.swift`, `SettingsViewEnhanced.swift`

- [~] **3. Wire Dose 2 Override (Always-tappable button)** ⏱️ 3-4h (revised from 2h)  
  **Priority:** CRITICAL  
  **Status:** ⚠️ PARTIAL (UI wired, tests missing)  
  **Completed:**
  - ✅ Dose 2 always tappable (routes to gate/override sheets)
  - ✅ Early/late override sheets connected
  - ✅ Policy defaults: allowEarlyDose=true, maxEarlyMinutes=180
  
  **Remaining Work:**
  - [ ] Unit tests: early dose logging (override_kind="early")
  - [ ] Unit tests: late dose logging (override_kind="late")
  - [ ] Unit tests: guard no-wake (Dose2 blocked if no wake events)
  - [ ] UI tests: tap Dose 2 in each state → correct sheet appears
  - [ ] VoiceOver labels for override sheets
  
  - **DoD (CORRECTED):**
    - [ ] All taps routed correctly (tested in all states)
    - [ ] override_kind, override_minutes, override_reason logged
    - [ ] Unit tests: 6 named test cases (early/late/guard scenarios)
    - [ ] UI tests: tap flow verified
    - [ ] VoiceOver: hints for each button state
  - **Depends on:** Item 1, Items 41/54/8
  - Files: `NightCardViewModern.swift`, `EarlyDoseSheetView.swift`, `LateDoseSheetView.swift`

---

### Testing & QA (CANNOT SKIP)

- [ ] **9. Unit Tests (Time, Gating, Turnover)** ⏱️ 10-12h (revised from 4-5h)  
  **Priority:** 🚨 CRITICAL (NO-SHIP item 6)  
  **Status:** NOT STARTED  
  **Target:** ≥80% coverage on time-critical logic  
  
  **Test Suites Required:**
  1. **TimeMathTests** (20 tests)
     - DST spring forward (+1h): cutoff still triggers
     - DST fall back (-1h): no duplicate cutoff
     - Timezone PST → EST (+3h): service day correct
     - Midnight crossing: no state change
     - Noon cutoff: state transitions
  
  2. **DoseGatingTests** (15 tests)
     - Dose 2 window: 150-240 min validation
     - Early dose: ≤180 min override allowed
     - Late dose: >240 min override with reason
     - Guard no-wake: Dose 2 blocked if no wake events
  
  3. **TurnoverTests** (12 tests)
     - Cutoff crossing: Active → Abandoned
     - Cutoff crossing: AwaitWake → Abandoned
     - Tonight minting: idempotent (2nd call no-op)
     - BGTask jitter: ±15 min tolerance
  
  4. **StateMachineTests** (10 tests)
     - All legal transitions pass
     - All illegal transitions throw
  
  - **DoD:**
    - [ ] 57 named unit tests (above suites)
    - [ ] ≥80% code coverage on Models, Controllers, TimeMath
    - [ ] CI: tests run on every commit
    - [ ] CI: fail if coverage drops below 75%
  - **Depends on:** Items 41, 54, 8, 24
  - **Reference:** Auditor Red Flag #18

- [ ] **10. UI Tests (Critical Paths)** ⏱️ 4-6h (revised from 3-4h)  
  **Priority:** HIGH (NO-SHIP item 6)  
  **Status:** NOT STARTED  
  
  **Test Scenarios:**
  1. **Happy Path** (5 tests)
     - Log Dose 1 → Dose 2 window opens → Log Dose 2 → Final wake
  
  2. **Override Flows** (4 tests)
     - Tap Dose 2 before window → Early override sheet → Confirm
     - Tap Dose 2 after window → Late override sheet → Confirm
  
  3. **Cutoff Crossing** (2 tests)
     - Simulate noon crossing → Tonight card appears
  
  4. **Error Handling** (2 tests)
     - Try to log Dose 1 twice → See "already logged" message
  
  - **DoD:**
    - [ ] 13 UI tests (XCTest or Appium)
    - [ ] CI: UI tests run nightly
    - [ ] Video recordings of failures saved as artifacts
  - **Depends on:** Items 1, 3, 41, 54
  - **Reference:** Auditor Red Flag #18

---

## 🎯 Week 3-4: Alarms & Notifications

### Soft-Wake Alarms (HIGH RISK - Platform Compliance)

- [ ] **60. Soft-Wake Alarm Implementation** ⏱️ 8-10h (revised from 4-5h)  
  **Priority:** 🚨 CRITICAL (NO-SHIP item 4)  
  **Status:** NOT STARTED  
  **Platform Risk:** "Looping" alarms violate iOS policies  
  
  **Auditor's Red Flag #4:**
  > "iOS doesn't allow 'looping until acknowledged' without Critical Alerts entitlement (rarely granted)."
  
  **CORRECTED Implementation:**
  ```swift
  // NotificationHelper.swift
  func scheduleRepeatedReminders(
      maxRepeats: Int = 3,  // ← CAP at 3, not infinite
      interval: TimeInterval = 5 * 60,  // 5 min
      isTimeSensitive: Bool = false  // ← User must enable in Settings
  )
  ```
  
  - **DoD (CORRECTED):**
    - [ ] Schedule up to 3 reminders (not infinite loop)
    - [ ] Interval: 5 min (configurable in Settings)
    - [ ] Mark as Time Sensitive (if user opted in)
    - [ ] Setting: "Allow Time Sensitive alerts" with explainer
    - [ ] Explainer: "Enable in iOS Settings → DoseTrack → Notifications"
    - [ ] NO language about "breaking quiet hours" (not guaranteed)
    - [ ] Unit tests: 3 notifications scheduled, not 4
    - [ ] Unit tests: user dismisses → remaining canceled
    - [ ] BGTask schedules next wake alarm at cutoff
    - [ ] Audit trail: all scheduled/delivered/dismissed logged
  - **Depends on:** Items 26 (audit trail), 51 (frozen IDs)
  - **Reference:** Auditor Red Flags #4, #5 (NO-SHIP item 4)

---

## 🎯 WHOOP Integration (Items 69-80)

### Production-Grade Requirements

- [~] **70. OAuth Proxy Backend** ⏱️ 10-14h (revised from 4-6h)  
  **Priority:** HIGH  
  **Status:** 🔴 DEV-ONLY (NOT PRODUCTION-READY)  
  
  **Completed:**
  - ✅ OAuth code exchange endpoint
  - ✅ Recovery/sleep data proxying
  - ✅ Token encryption (in-memory only)
  - ✅ Revoke endpoint
  - ✅ Local testing (curl /health)
  
  **Production Blockers:**
  - [ ] Replace Map() with PostgreSQL/Firestore/Redis
  - [ ] Encrypt tokens at rest (AES-256-GCM on disk)
  - [ ] Implement key rotation (30-day cycle)
  - [ ] Add /health endpoint (liveness + readiness)
  - [ ] Test 401→refresh flow with expired tokens
  - [ ] Deploy to Railway/GCP with TLS
  - [ ] Load test: 100 concurrent users
  - [ ] Request logging + rate limit tracking
  - [ ] Backup/restore procedure documented
  
  - **DoD (CORRECTED for Production):**
    - [ ] Tokens persisted in encrypted DB (not Map())
    - [ ] /health endpoint: {"status":"ok", "db":"connected"}
    - [ ] 401 response triggers automatic token refresh
    - [ ] Load test: 100 users, 1000 requests, <500ms p99
    - [ ] Deployed to production URL (not localhost:3000)
    - [ ] TLS certificate valid
    - [ ] Rate limit: 100 req/hr per user (logged)
  - **Depends on:** Item 69
  - **Reference:** Auditor Red Flags #19 (NO-SHIP item 8)

- [ ] **70a. WHOOP Backend Production Hardening** ⏱️ 6-8h  
  **Priority:** 🚨 CRITICAL (NEW ITEM per audit)  
  **Status:** NOT STARTED  
  
  **Requirements:**
  1. **Persistent Storage**
     - PostgreSQL table: `whoop_sessions` (session_id, user_id, access_token_enc, refresh_token_enc, expires_at)
     - AES-256-GCM encryption for tokens
     - Connection pooling (pg-pool)
  
  2. **Key Rotation**
     - Rotate encryption key every 30 days
     - Re-encrypt all tokens with new key
     - Old key kept for 7 days (grace period)
  
  3. **Health Endpoint**
     - GET /health → {"status":"ok", "db":"connected", "uptime": 12345}
     - Liveness: responds within 500ms
     - Readiness: DB connection verified
  
  4. **Token Refresh Flow**
     - 401 response → try refresh_token
     - Success → update session, retry original request
     - Failure → return 401, client must re-authenticate
     - Test: manually expire token, verify auto-refresh
  
  - **DoD:**
    - [ ] PostgreSQL schema created + migration script
    - [ ] All tokens stored encrypted on disk
    - [ ] Key rotation script tested (re-encrypt all tokens)
    - [ ] /health endpoint live (test with curl)
    - [ ] 401→refresh flow tested with real expired tokens
    - [ ] Load test: 100 concurrent users, no errors
    - [ ] Deployed to production (Railway/GCP)
  - **Depends on:** Item 70
  - Files: NEW `server/whoop-oauth-proxy/db.js`, `server/whoop-oauth-proxy/migrations/`
  - **Reference:** Auditor Red Flag #19, NO-SHIP item 8

- [~] **71-75. WHOOP iOS Integration** (see corrected DoD in Part 1)  
  All items moved from ✅ COMPLETE to ⚠️ PARTIAL (missing tests, a11y, health checks)

---

## 🎯 Deferred to Phase 2 (Per Audit Recommendation)

These are **descoped** from v1.2 to meet 4-week beta target:

- **12. Trend Cards** → Phase 2 (needs stable data first)
- **20. Modern UI Overhaul** → Phase 2 (keep targeted polish only)
- **37. Snapshot Tests** → Phase 2 (after unit/UI tests solid)
- **49. Battery Regression Math** → Phase 2 (ship minimal diagnostics now)
- **58. Full RTL Support** → Phase 2 (keep basic locale/time formatting)

---

## 📊 Revised Estimates Summary

| Category | Original Est. | Revised Est. | Delta |
|----------|--------------|--------------|-------|
| Week 1 Infrastructure | 12-15h | 18-24h | +50% |
| Core Features (Items 1-3) | 6-9h | 12-16h | +100% |
| Testing (Items 9-10) | 7-9h | 14-18h | +100% |
| WHOOP (Items 69-75) | 12-17h | 30-40h | +150% |
| Soft-Wake Alarms (Item 60) | 4-5h | 8-10h | +100% |
| **TOTAL (Critical Path)** | **122.5-166.5h** | **180-240h** | **+47%** |

**Rationale for increases:**
- Original estimates assumed happy-path only
- Missing: tests, accessibility, error handling, production hardening
- Auditor's 1.5× buffer for safety-critical features

---

## 🚀 Recommended Commit Order (First 10)

Per auditor's "pragmatic first 5 commits" + extensions:

1. **core(time):** ClockProvider + TimeMath (Items 41, 54)
2. **core(state):** StateMachine with guards (Item 8)
3. **sec(notifications):** Freeze categories/actions + CI check (Item 51)
4. **sec(storage):** File protection + BG write mode (Items 52, 52a)
5. **ops(audit):** NotificationAudit as single source (Item 26)
6. **core(idempotent):** Idempotent state writes (Item 24)
7. **tests(time):** TimeMath unit tests (part of Item 9)
8. **tests(state):** StateMachine unit tests (part of Item 9)
9. **feat(turnover):** Complete Item 1 with tests
10. **feat(gating):** Complete Item 3 with tests

**After these 10:** Soft-wake alarms, WHOOP production, accessibility, exports

---

## 📋 Compliance & Legal (CRITICAL)

**Auditor's Finding:**
> "Privacy: add App Privacy section in docs; Health disclaimers must be prominent at first run (Item 29 → CRITICAL)."

- [ ] **29. Health Data Disclaimer** ⏱️ 0.5h  
  **Priority:** 🚨 CRITICAL (was HIGH, now BLOCKING)  
  **Status:** NOT STARTED  
  Show disclaimer on **first app launch** (not buried in Settings):
  
  ```
  ⚠️ IMPORTANT
  
  DoseTrack is a personal sleep journal. 
  
  NOT MEDICAL ADVICE. Always consult your 
  doctor before changing sleep medications.
  
  By continuing, you agree to use this app 
  at your own risk.
  
  [I Understand] [Learn More]
  ```
  
  - **DoD:**
    - [ ] Disclaimer shown on first launch (before main screen)
    - [ ] User must tap "I Understand" to proceed
    - [ ] Flag saved: UserDefaults "disclaimer_accepted" = true
    - [ ] "Learn More" links to full terms
    - [ ] Prominent text (≥17pt, bold)
  - Files: NEW `ios/DisclaimerView.swift`, modify `DoseTrackApp.swift`

- [ ] **Privacy Disclosures** ⏱️ 2h  
  **Priority:** HIGH (App Store requirement)  
  **Status:** NOT STARTED  
  
  Create `docs/PRIVACY.md` with:
  - Data collected: dose times, grams, wake times, WHOOP recovery (if connected)
  - Storage: local SQLite, HealthKit (if authorized), WHOOP API (if connected)
  - Sharing: NONE (no analytics, no third parties except WHOOP API)
  - Retention: user controls via Delete All Data
  - User rights: export CSV/JSONL, delete data
  
  Update `Info.plist` purpose strings:
  - NSHealthShareUsageDescription: "Read sleep data to auto-fill wake times"
  - NSHealthUpdateUsageDescription: "Save dose logs to HealthKit for analysis"
  
  - **DoD:**
    - [ ] docs/PRIVACY.md complete (plain English)
    - [ ] Info.plist purpose strings updated
    - [ ] App Store privacy labels ready (data types documented)
  - Files: NEW `docs/PRIVACY.md`, modify `Info.plist`

---

## 🔧 Action Items for Project Owner

**Immediate (this week):**
1. Review this corrected TODO and approve/reject changes
2. Decide: 4-week beta (with descoping) or 8-week full release?
3. If 4-week: approve Phase 2 deferments
4. Start Week 1 infrastructure (Items 41, 54, 8, 51, 52)

**Before continuing WHOOP work:**
1. Deploy Item 70a (production backend) - BLOCKING
2. Add health checks to Item 72 (iOS UI) - BLOCKING
3. Write unit tests for Items 71-75 - BLOCKING

**Before shipping:**
1. Complete all 10 NO-SHIP quality gates
2. Pass App Review compliance checklist
3. Legal review of disclaimer + privacy docs

---

**Document Status:** DRAFT - awaiting project owner approval  
**Last Updated:** November 5, 2025 (post-audit)  
**Next Review:** After Week 1 infrastructure lands
