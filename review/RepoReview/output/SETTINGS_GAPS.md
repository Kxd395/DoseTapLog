# Settings Coverage Checklist

| Category | Preference Key | UI Surface | Runtime Usage | Notes |
|----------|----------------|-----------|---------------|-------|
| Night Plan | `totalNightGrams` | ✅ SettingsViewEnhanced (`Picker`) | ✅ `LegacyAppPreferences.planDose1G/planDose2G` | Correctly drives dosing amounts. |
| Night Plan | `splitStrategy` | ✅ | ✅ | Split impacts computed doses. |
| Night Plan | `roundingStepG` | ✅ | ✅ | Applies via `AppPreferencesEnhanced.round`. |
| Night Plan | `allowTonightEdit` | ✅ | ❌ | No code reads this flag; tonight editing remains hard-coded. |
| Window | `windowStartMin` / `windowEndMin` | ✅ | ✅ | Used by `TodayViewModel` gating and countdown. |
| Early Override | `allowEarlyDose` / `maxEarlyMinutes` / `requireEarlyReason` / `earlyTimePriorDefaults` | ✅ | ◐ Partial | ViewModel respects these, but controller only stores override metadata in notes and never populates override fields on `DoseLog`. |
| Notifications | `liveActivityEnabled` | ✅ | ◐ Partial | Flag is checked before calling `startLiveActivityIfEnabled`, but that method is a stub, so preference has no effect. |
| Notifications | `notifyAtStart` / `notifyAtHalf` / `notifyAtEnd` | ✅ | ❌ | No scheduler uses these toggles; notification hooks are TODOs. |
| Notifications | `quietHoursStart` / `quietHoursEnd` | ✅ | ❌ | Never read when scheduling reminders. |
| Notifications | `hapticsEnabled` | ✅ | ❌ | No haptic feedback toggled on the new UI path. |
| Data Sources | `healthSampleWindowMin` | ✅ | ❌ | `HealthKitManager` ignores this window; fetch uses hard-coded tolerance. |
| Data Sources | `whoopProxyURL` / `whoopAPIKey` | ✅ | ❌ | Only stored; TodayLogView status chips are hard-coded and server client never consumes these values. |
| Data Sources | `wakeSourcePreference` | ✅ | ❌ | `TodayViewModel` keeps wake source string literal `"manual"`; preference is unused. |
| Exports | `exportIncludeTimezone` / `exportFilenamePattern` / `exportIncludeNotes` / `exportIncludeEventLog` / `exportDefaultEmail` | ✅ | ❌ | `CSVExporter` always outputs a fixed filename and columns; preferences never referenced. |
| Privacy | `requireBiometric` | ✅ | ❌ | App launch does not enforce biometrics. |
| Privacy | `maskWidgetDoses` | ✅ | ❌ | Widget provider ignores masking flag. |
| Retention | `retentionDays` | ✅ | ❌ | No purge job uses this value; purge button is a TODO. |
| Reset Night | `resetAllowHard` / `resetRequireBiometricHard` / `resetReasonRequired` / `resetUndoWindowSec` | ✅ | ✅ | Used by `ResetNightSheet` and undo logic. |
| Debug | `showInternals` | ✅ | ❌ | No view reads the toggle to expose debug data. |
| Late Override | `allowLateDose` / `lateRequireReason` / `maxLateMinutes` / `lateQuickChoicesCSV` | ❌ | ❌ | Preferences defined in `AppPreferencesEnhanced+LateDose.swift`, but no UI section exposes them and the active view never reads them. |

Legend: ✅ = complete, ◐ = partial coverage, ❌ = missing.
