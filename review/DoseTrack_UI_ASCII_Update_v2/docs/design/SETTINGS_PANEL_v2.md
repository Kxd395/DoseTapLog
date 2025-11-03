
# Settings Panel — Detailed Fields (v2)
Date: 2025-11-03

Night plan defaults
- totalNightGrams: Double = 6.5
- splitStrategy: String = "50-50"
- roundingIncrement: Double = 0.25
- windowStartMin: Int = 150
- windowEndMin: Int = 240
- allowTonightEdit: Bool = true

Early Dose 2 policy
- allowEarlyDose: Bool = false
- maxEarlyMinutes: Int = 15
- earlyRequireReason: Bool = true
- earlyTimePriorDefaults: [Int] = [5,10]

Notifications & Live Activity
- liveActivityEnabled: Bool = true
- notifyAtStart: Bool = true
- notifyAtHalf: Bool = false
- notifyAtEnd: Bool = true
- hapticsStyle: String = "light"
- quietHours: String = "22:00-07:00"

Data sources
- wakeSourcePref: String = "manual"
- whoopProxyURL: String = ""
- whoopAutoTestOnLaunch: Bool = false
- timezoneAuto: Bool = true

Exports
- exportIncludeTimezone: Bool = true
- exportIncludeNotes: Bool = true
- exportIncludeEventLog: Bool = true
- exportFilenamePattern: String = "night_{key}.csv"
- exportDefaultEmail: String = ""

Privacy & retention
- requireBiometric: Bool = false
- maskWidgets: Bool = true
- retentionDays: Int = 365
- purgeNow: Action

Debug & developer
- showInternals: Bool = false
- simulateDose1: Action
- forceWindowOpen: Action
- viewEventLog: Action
- schemaVersionDisplay: String
