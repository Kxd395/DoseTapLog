# UI Actions vs App States

| Action | Idle (no night) | Waiting (Dose 1 logged, window not open) | Window Open | Window Expired | Health Denied | WHOOP Offline | Notes |
|--------|-----------------|-------------------------------------------|-------------|----------------|----------------|----------------|-------|
| In bed now | ✅ Enabled (`ios/TodayLogView.swift:81`) | ✅ | ✅ | ✅ | ⚠️ No gating | ⚠️ No gating | Always enabled; health/WHOOP states never alter availability because status chips are hard-coded. |
| Dose 1 now | ⚠️ Compile error (`ios/TodayLogView.swift:82`) | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | Button references `vm.logDose1Now` without arguments, but the method requires `grams: Double`, so the app will not build with the new view. |
| Dose 2 now | ❌ Disabled (`dose2Enabled` false) | ✅ Enabled when early override allowed (sheet) | ✅ | ❌ (no late path) | ⚠️ No gating | ⚠️ No gating | No late override button; expires without fallback. |
| Early override confirm | ❌ Not reachable | ✅ Sheet shown when early eligible (`ios/TodayViewModel.swift:108-119`) | n/a | n/a | ⚠️ No gating | ⚠️ No gating | Controller records only notes; override fields remain unset. |
| Late override confirm | ❌ Missing | ❌ Missing | ❌ Missing | ❌ Missing | ❌ Missing | ❌ Missing | Late override UI is absent; extension relies on unavailable controller API. |
| Final wake | ✅ Enabled (`ios/TodayLogView.swift:86`) | ✅ | ✅ | ✅ | ⚠️ No gating | ⚠️ No gating | Always active; no wake-source state handling. |
| Alarm wake | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | Records note only; chips never reflect alarm provenance. |
| Bathroom | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | Adds to array; undo limited to 60 s. |
| Undo last | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | Enabled regardless of state; controller enforces 60 s window. |
| Edit plan | ✅ (opens Settings) | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | No per-night edit implementation; just toggles sheet. |
| Snooze 5 min | ❌ Not implemented | ❌ | ❌ | ❌ | ❌ | ❌ | Expected by spec but missing entirely. |
| Snooze 10 min | ❌ Not implemented | ❌ | ❌ | ❌ | ❌ | ❌ | Missing. |
| Health autofill wake | ❌ Not exposed | ❌ | ❌ | ❌ | ❌ | ❌ | HealthKit manager exists but there is no button or flow in TodayLogView. |
| Export night | ❌ Not exposed | ❌ | ❌ | ❌ | ❌ | ❌ | CSV exporter not wired to UI. |
| Reset Night | ❌ Hidden (`vm.nightKey == nil`) | ✅ Button visible (`ios/TodayLogView.swift:98-114`) | ✅ | ✅ | ⚠️ | ⚠️ | Availability tied only to `nightKey`; no extra health/state gating. |
| Reset Undo (banner) | ❌ | ⚠️ Only after reset | ⚠️ | ⚠️ | ⚠️ | ⚠️ | Banner shows after soft reset until timer expires; no hooks for health/WHOOP states. |

Legend: ✅ wired and behaves, ⚠️ partial or state missing, ❌ absent.
