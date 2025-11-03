# UI Wiring Audit – DoseTrack v1.1.1c

| # | Requirement | Status | Evidence | Notes |
|---|-------------|--------|----------|-------|
| 1 | Scrollable layout keeps primary actions unobstructed | ◐ Partial | `ios/TodayLogView.swift:16` | The view uses a `ScrollView`, but the action stack is inline with content and there is no `safeAreaInset`/bottom dock. Buttons will scroll off-screen and can still be clipped by the keyboard during sheet entry. |
| 2 | Countdown ring driven by `TimelineView` with 30 s refresh | ✅ Pass | `ios/TodayLogView.swift:36` | Implements `TimelineView(.periodic(from: Date(), by: 30))` to refresh the ring. |
| 3 | Dose 2 enablement bound to 150–240 min window | ◐ Partial | `ios/TodayViewModel.swift:74` · `ios/TodayViewModel+LateDose.swift:94` | The base ViewModel gates Dose 2, but the late-dose extension redefines `tryLogDose2` and expects a different controller signature, creating compile-time conflicts and breaking override logic. |
| 4 | Early dose override sheet with allowed minutes & reason | ◐ Partial | `ios/TodayLogView.swift:144` · `ios/DoseLogController.swift:211` | Sheet presents and logs overrides, yet controller only appends notes and never sets `dose2IsOverride` / `dose2Override*` fields used by exports. |
| 5 | Late override flow surfaced and tagged for exports | ❌ Fail | `ios/TodayLogView.swift:78-110` · `ios/TodayViewModel+LateDose.swift:79` | No late-override button or sheet in the active view. Extension calls `logDose2Now(…, overrideKind:)`, but the protocol and controller lack that signature, so late overrides cannot compile or persist. |
| 6 | Event strip shows last three events with 60 s undo window | ◐ Partial | `ios/TodayViewModel.swift:24` · `ios/DoseLogController.swift:300` | The controller synthesises recent events from `DoseLog` instead of a real event log table, so bath/undo history is incomplete, though undo is time-bound to 60 s. |
| 7 | Safety banner highlights per-dose and nightly violations | ◐ Partial | `ios/SafetyBanner.swift:7-24` | Banner checks planned doses only. It never reflects logged amounts or night totals, and doesn’t read override state to turn violations red. |
| 8 | Permissions chips for Health & WHOOP with quick fixes | ❌ Fail | `ios/TodayLogView.swift:33-35` | Chips are hard-coded (`healthOK: true`) and the tap handlers are empty closures, so there is no runtime wiring to HealthKit or WHOOP actions. |
| 9 | Live Activity starts at Dose 1 and ends at Dose 2/expiry | ❌ Fail | `ios/DoseLogController.swift:345-356` | `startLiveActivityIfEnabled` / `endLiveActivity` are stubs that only log TODO messages; no ActivityKit integration exists. |
|10 | Reset Night confirmation clears state and supports undo | ✅ Pass | `ios/ResetNightSheet.swift:17-113` · `ios/TodayViewModel.swift:133-158` | Sheet enforces guardrails (Face ID, keyword) and the ViewModel clears state, records undo batch, and auto-hides the banner on expiry. |

