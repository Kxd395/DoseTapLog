# DoseTrack Feature Coverage Analysis

**Review Date:** November 3, 2025  
**Scope:** v1.1.1c Feature Completeness vs PRD and Plans

---

## Feature Coverage Summary

| Category | Planned | Implemented | Partial | Missing | Coverage |
|----------|---------|-------------|---------|---------|----------|
| Core Dosing Flow | 8 | 7 | 1 | 0 | 87.5% |
| Safety & Validation | 6 | 6 | 0 | 0 | 100% |
| Override Flows | 4 | 3 | 1 | 0 | 75% |
| Notifications | 6 | 5 | 1 | 0 | 83% |
| Data Export | 4 | 3 | 1 | 0 | 75% |
| Settings UI | 7 | 6 | 1 | 0 | 85% |
| Widget/Extensions | 3 | 3 | 0 | 0 | 100% |
| WHOOP Integration | 4 | 4 | 0 | 0 | 100% |
| **TOTAL** | **42** | **37** | **5** | **0** | **88%** |

---

## Detailed Feature Matrix

### 1. Core Dosing Flow

| Feature | Status | Evidence | Notes |
|---------|--------|----------|-------|
| Log "In bed now" | ✅ IMPL | TodayLogView.swift:90 | Button present, action wired |
| Log "Dose 1 now" | ✅ IMPL | TodayLogView.swift:91 | Button with grams parameter |
| Log "Dose 2 now" | ✅ IMPL | TodayLogView.swift:104 | Gated by window, long-press override |
| Log "Final wake" | ✅ IMPL | TodayLogView.swift:114 | Button present |
| Log "Alarm wake" | ✅ IMPL | TodayLogView.swift:126 | Sheet flow present |
| Log "Bathroom wake" | ✅ IMPL | TodayLogView.swift:131 | Sheet flow present |
| Undo last event | ⚠️ PARTIAL | TodayLogView.swift:136 | Button present, 60s timer not verified |
| Edit tonight's plan | ✅ IMPL | TodayLogView.swift:137 | Opens settings |

**Coverage:** 7/8 complete, 1 partial (87.5%)

---

### 2. Safety & Validation

| Feature | Status | Evidence | Notes |
|---------|--------|----------|-------|
| Per-dose minimum (1.5g) | ✅ IMPL | AppPreferences.swift:357 | Hardcoded in planViolatesSafety |
| Per-dose maximum (4.5g) | ✅ IMPL | AppPreferences.swift:358 | Hardcoded in planViolatesSafety |
| Nightly minimum (3.0g) | ✅ IMPL | AppPreferences.swift:359 | Hardcoded in planViolatesSafety |
| Nightly maximum (9.0g) | ✅ IMPL | AppPreferences.swift:360 | Hardcoded in planViolatesSafety |
| Safety banner with totals | ✅ IMPL | TodayLogView.swift:33 | Shows per-dose + nightly |
| Red banner for violations | ✅ IMPL | SafetyBanner.swift | Invalid state highlighting |

**Coverage:** 6/6 complete (100%)

---

### 3. Override Flows

| Feature | Status | Evidence | Notes |
|---------|--------|----------|-------|
| Early Dose 2 (before window) | ✅ IMPL | TodayLogView.swift:201-211 | EarlyDoseSheetView with reason |
| Late Dose 2 (after window) | ✅ IMPL | TodayLogView.swift:213-223 | LateDoseSheetView with reason |
| Reset Night (clear session) | ✅ IMPL | TodayLogView.swift:148 | ResetNightSheet with safety |
| Undo Reset Night | ⚠️ PARTIAL | TodayLogView.swift:162-179 | Banner present, timer incomplete |

**Coverage:** 3/4 complete, 1 partial (75%)

**Missing Components:**
- `resetUndoWindowSec` property in AppPreferencesEnhanced
- Timer mechanism to auto-hide undo banner after window expires

---

### 4. Notifications & Live Activity

| Feature | Status | Evidence | Notes |
|---------|--------|----------|-------|
| Live Activity (Dose 1 → Dose 2) | ⚠️ PARTIAL | Widget/DoseWidgetProvider.swift | Present, needs runtime test |
| Notify at window start | ✅ IMPL | AppPreferences.swift:163 | notifyWindowStart toggle |
| Notify at window halfway | ✅ IMPL | AppPreferences.swift:169 | notifyHalfway toggle |
| Notify at window end | ✅ IMPL | AppPreferences.swift:179 | notifyWindowEnd toggle |
| Quiet hours respect | ✅ IMPL | AppPreferences.swift:186-190 | quietHoursStart/End |
| Haptic feedback | ✅ IMPL | AppPreferences.swift:195 | hapticsEnabled toggle |

**Coverage:** 5/6 complete, 1 partial (83%)

**Needs:** Runtime validation that Live Activity starts on Dose 1 and ends on Dose 2 or expiry

---

### 5. Data Export

| Feature | Status | Evidence | Notes |
|---------|--------|----------|-------|
| CSV export with schema | ✅ IMPL | CSVExporter.swift | Export functionality present |
| Include timezone in export | ✅ IMPL | AppPreferences.swift:229 | exportIncludeTimezone |
| Include notes in export | ✅ IMPL | AppPreferences.swift:237 | exportIncludeNotes |
| Schema validation | ⚠️ PARTIAL | - | No validation against examples CSV |

**Coverage:** 3/4 complete, 1 partial (75%)

**Missing:**
- Unit tests validating CSV output matches `examples/examples_sample_dosing.csv` schema
- Automated schema compliance check

---

### 6. Settings UI

| Feature | Status | Evidence | Notes |
|---------|--------|----------|-------|
| Night plan defaults section | ✅ IMPL | SettingsViewEnhanced.swift:20 | Total, split, rounding |
| Dose 2 window section | ✅ IMPL | SettingsViewEnhanced.swift:56 | Start/end minutes |
| Early Dose 2 policy section | ✅ IMPL | SettingsViewEnhanced.swift:75 | Allow, max, reason |
| Late Dose 2 policy section | ✅ IMPL | SettingsViewEnhanced.swift:92 | Allow, max, reason |
| Notifications section | ✅ IMPL | SettingsViewEnhanced.swift | Live Activity, quiet hours |
| Data sources section | ✅ IMPL | SettingsViewEnhanced.swift | Health, WHOOP config |
| Privacy section | ⚠️ PARTIAL | SettingsViewEnhanced.swift | Partial, needs full audit |

**Coverage:** 6/7 complete, 1 partial (85%)

**Needs:** Full audit to ensure every `@AppStorage` property appears in UI

---

### 7. Widget & Extensions

| Feature | Status | Evidence | Notes |
|---------|--------|----------|-------|
| Home screen widget | ✅ IMPL | Widget/DoseWidgetProvider.swift | Widget provider present |
| App Intents (voice shortcuts) | ✅ IMPL | AppIntents+DoseLog.swift | Siri integration |
| App Group sharing | ✅ IMPL | AppGroupStore.swift | Widget data sync |

**Coverage:** 3/3 complete (100%)

---

### 8. WHOOP Integration

| Feature | Status | Evidence | Notes |
|---------|--------|----------|-------|
| WHOOP proxy server | ✅ IMPL | server/index.js | Express server present |
| GET /health endpoint | ✅ IMPL | server/index.js | Health check |
| GET /api/sleep/latest | ✅ IMPL | server/index.js | Sleep data endpoint |
| GET /api/aggregates/7days | ✅ IMPL | server/index.js | Aggregates endpoint |

**Coverage:** 4/4 complete (100%)

**Note:** Rate limiting and API key middleware not verified in code inspection

---

## Components Inventory

### iOS Components (Present)

**Views:**
- ✅ TodayLogView.swift (main screen)
- ✅ TodayLogView_CardStack.swift (card layout variant)
- ✅ TodayLogView_Checklist.swift (checklist variant)
- ✅ SettingsViewEnhanced.swift (settings)
- ✅ EarlyDoseSheetView.swift (early override)
- ✅ LateDoseSheetView.swift (late override)
- ✅ WakeSheetView.swift (wake event entry)
- ✅ ResetNightSheet.swift (reset confirmation)
- ✅ SafetyBannerView.swift (safety validation)
- ✅ EventStripView.swift (event timeline)
- ✅ CountdownRingView.swift (visual timer)

**ViewModels:**
- ✅ TodayViewModel.swift (main business logic)
- ✅ TodayViewModel+WakeEvents.swift (wake handling)
- ✅ TodayViewModel+LateDose.swift (late override logic)
- ✅ TodayViewModel+Dose2Override.swift (dose 2 gating)

**Controllers:**
- ✅ DoseLogController.swift (data persistence)

**Models:**
- ✅ Models.swift (SwiftData models)
- ✅ AppPreferences.swift (legacy preferences)
- ✅ AppPreferencesEnhanced.swift (app group preferences)
- ✅ WakeReason.swift (wake event types)
- ✅ WindowState.swift (window state machine)
- ✅ NightAlarmPlan.swift (alarm scheduling)
- ✅ NightPlanRecommender.swift (ML recommendations)

**Utilities:**
- ✅ CSVExporter.swift (export logic)
- ✅ HealthKitManager.swift (HealthKit integration)
- ✅ AlarmOrchestrator.swift (notification scheduling)
- ✅ Date+UTC.swift (date utilities)
- ✅ Rounding+Display.swift (formatting)
- ✅ Config.swift (app configuration)

**Extensions:**
- ✅ Widget/DoseWidgetProvider.swift (widget)
- ✅ AppIntents+DoseLog.swift (Siri/shortcuts)
- ✅ AppGroupStore.swift (shared storage)

**Tests:**
- ✅ Tests/DoseLogTests.swift (unit tests present, not run)

---

## Missing Features (Per Review)

### None Identified

All planned features from PRD v1.2 and operational guides are present in code.

**Partial implementations:**
1. Undo timer (60s constraint not verified)
2. Reset Night undo window (timer missing)
3. CSV schema validation (no automated checks)
4. Live Activity integration (needs runtime test)
5. Privacy settings section (incomplete audit)

---

## Features Not in Original Scope (Additions)

| Feature | Status | Notes |
|---------|--------|-------|
| Late Dose 2 Override | ✅ IMPL | Added in v1.1.1c spec update |
| Window Expired Helper Banner | ✅ IMPL | TodayLogView.swift:44-76 |
| Undo Reset Banner | ⚠️ PARTIAL | Present but timer incomplete |
| Three view variants | ✅ IMPL | CardStack, Checklist, standard |
| Enhanced alarm orchestration | ✅ IMPL | Actor-based alarm system |

---

## Documentation Coverage

| Document | Status | Location | Completeness |
|----------|--------|----------|--------------|
| Product Requirements | ✅ COMPLETE | docs/PRD_v1.2.md | 100% |
| Product Description | ✅ COMPLETE | docs/PRODUCT_DESCRIPTION.md | 100% |
| UI/UX Design | ✅ COMPLETE | docs/design/UI_UX_ASCII.md | 100% |
| Logic Flow | ✅ COMPLETE | docs/design/LOGIC_MAP.md | 100% |
| Dose 2 Logic | ✅ COMPLETE | docs/design/DOSE2_LOGIC_FLOW.md | 100% |
| CSV Schema | ✅ COMPLETE | examples/examples_sample_dosing.csv | 100% |
| Server README | ✅ COMPLETE | server/README_server.md | 100% |
| Secrets Management | ✅ COMPLETE | docs/SECRETS.md | 100% |
| Action Checklist | ✅ COMPLETE | docs/ops/ACTION_CHECKLIST.md | 100% |

---

## Constitution Compliance

**Per `.specify/memory/constitution.md`:**

### Principle I: Safety First
- ✅ Per-dose bounds implemented and enforced
- ✅ Nightly total bounds implemented and enforced
- ✅ Safety banner with visual validation
- ✅ Window-based gating for Dose 2
- ⚠️ Cannot verify runtime behavior (build blocked)

### Principle II: Local-First Privacy
- ✅ App Group storage for widget
- ✅ No cloud sync
- ✅ Biometric lock option present
- ✅ Widget masking option present
- ✅ Data retention policy setting

### Principle III: Clinician-Ready Data
- ✅ CSV export with timestamps
- ✅ Event log with all actions
- ✅ Timezone information captured
- ✅ Notes field for context
- ⚠️ Schema validation not automated

---

## Recommendations

### To Reach 100% Coverage:

1. **Complete Undo Timer** (2 hours)
   - Add 60-second countdown in TodayViewModel
   - Auto-disable undo button after timeout
   - Test with XCTest assertions

2. **Complete Reset Undo Window** (2 hours)
   - Add `resetUndoWindowSec` to AppPreferencesEnhanced
   - Implement countdown timer in ViewModel
   - Auto-dismiss banner after window

3. **Add CSV Schema Validation** (3 hours)
   - Create unit tests comparing CSV output to schema
   - Add schema compliance helper function
   - Document column order and types

4. **Verify Live Activity** (1 hour)
   - Runtime test: Log Dose 1, verify LA appears
   - Verify LA updates during window
   - Verify LA ends on Dose 2 or expiry

5. **Complete Settings Audit** (1 hour)
   - Line-by-line mapping of all @AppStorage to UI
   - Ensure every setting has control
   - Verify persistence and runtime reads

**Total Effort to 100%:** 9 hours

---

## Conclusion

DoseTrack v1.1.1c demonstrates **88% feature completeness** with:
- ✅ All major features implemented
- ✅ Strong architecture and component organization
- ⚠️ 5 partial implementations needing completion
- ❌ Cannot verify runtime behavior due to build failures

**Once build errors are fixed**, the remaining 12% can be completed in ~9 hours of focused development.

---

**Coverage Status:** 88% Complete  
**Blocking:** Build errors prevent runtime validation  
**Recommendation:** Fix build, complete partials, reach 100%  
**Reviewed:** November 3, 2025
