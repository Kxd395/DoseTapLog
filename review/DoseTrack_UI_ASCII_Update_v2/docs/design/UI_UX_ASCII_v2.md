
# DoseTrack UX/UI ASCII — Update v2
Date: 2025-11-03
Applies to: v1.1.1c + UI wiring patch

Legend
[Button]  (Chip)  {Field}   ▓ progress   ✓ ok   ! warn   ⌀ empty

============================================================
1) Today Screen — One tap Night Flow
============================================================

Header
┌───────────────────────────────────────────────────────────┐
│ DoseTrack                        ⚙ Settings   ⓘ Help      │
│ Sat Nov 1 • UTC−04:00 • Key 2025-11-01                    │
└───────────────────────────────────────────────────────────┘

Tonight plan
┌───────────────────────────────────────────────────────────┐
│ Plan:  Total 6.5 g   Split 50/50   Round 0.25 g           │
│ Dose 1: 3.25 g     Dose 2: 3.25 g                          │
│ Window: opens +150 min, closes +240 min after Dose 1       │
└───────────────────────────────────────────────────────────┘

Safety and status chips
[ Safety ✓ Per dose 1.5–4.5 g ]  [ Night total 0.00 g ]
[ Wake: Manual | Change ]  [ Health: OK ]  [ WHOOP: Connected ]
[ Permissions: All good ]  [ Timezone: Autodetect ]

Countdown ring + window text
      ┌─────────────── Ring ───────────────┐
      │          ▓▓▓▓▓▓▓▓░░░░░░            │
      │        2 h 15 m elapsed            │
      │   Window opens in 1 h 45 m         │
      │   Window ends in 3 h 15 m          │
      └────────────────────────────────────┘
Disabled reason line when blocked:
  ⌀ Dose 2 disabled: must wait until +150 min after Dose 1

Primary actions
[ In bed now ]  [ Dose 1 now ]  [ Dose 2 now ]  [ Final wake now ]

Secondary actions
[ Alarm wake ]  [ Bathroom ]    [ Undo last ]   [ Edit plan ]

Utility actions
[ Snooze Dose 2 5m ]  [ Snooze Dose 2 10m ]  [ Autofill wake from Health ]
[ Export CSV ]  [ Reset Night ]

Recent event strip
┌───────────────────────────────────────────────────────────┐
│ 🛏 In bed 22:58                    •  7 m ago              │
│ 💊 Dose 1 3.25 g at 23:05         •  Just now             │
└───────────────────────────────────────────────────────────┘

Notifications and Live Activity
• After Dose 1: start Live Activity with countdown and quick actions:
  [ Dose 2 now ]  [ Snooze 5m ]  [ Open app ]
• Local notifications: at window start, halfway (optional), and end.

Edge cases
• Early Dose 2 tap before window → show EarlyDose sheet
• Missed Dose 2 → show "Log missed dose" with reason
• Alarm wake vs Natural wake → set wake_reason, offer convert to Final wake
• Undo → allow within 60 s; show snackbar "Undone" with Redo

============================================================
2) EarlyDose Sheet — Allow with Confirmation
============================================================
┌───────────────────────────────────────────────────────────┐
│ ⚠ Dose 2 Early                                           │
│ You are logging Dose 2 early by 20 minutes.               │
├───────────────────────────────────────────────────────────┤
│ Dose details                                              │
│ • Amount: 3.25 g                                         │
│ • Window start: +150 min  • Now: +130 min                │
│ • Early by: 20 min                                        │
├───────────────────────────────────────────────────────────┤
│ Reason (required)                                         │
│ (•) Woke up earlier than usual                            │
│ ( ) Symptoms escalating                                   │
│ ( ) Schedule constraint                                   │
│ ( ) Other: [________________________ ]                    │
├───────────────────────────────────────────────────────────┤
│ Time prior                                                │
│ [ 5m ]  [ 10m ]  [ 15m ]  [ 20m ]  [ Custom… ]           │
├───────────────────────────────────────────────────────────┤
│ This logs an early override and will be visible in exports│
│ and the event log. This is not medical advice.            │
├───────────────────────────────────────────────────────────┤
│ [ Cancel ]                                  [ Confirm ]   │
└───────────────────────────────────────────────────────────┘

============================================================
3) Reset Night — Safety Dialog
============================================================
┌───────────────────────────────────────────────────────────┐
│ Reset Night                                               │
│ This will archive the current night and start a new one.  │
│ Nothing is deleted. You can still export both.            │
├───────────────────────────────────────────────────────────┤
│ Options                                                   │
│ (•) Archive and start over now                            │
│ ( ) Keep events, reset timers                             │
│ ( ) Soft reset: keep Dose 1, clear Dose 2 only            │
├───────────────────────────────────────────────────────────┤
│ [ Cancel ]                           [ Reset Night ]      │
└───────────────────────────────────────────────────────────┘

============================================================
4) Settings Panel — 7 sections
============================================================
A) Night plan defaults
  • Total night grams {6.5}  • Split {50/50 | 60/40 | 40/60 | Custom}
  • Rounding {0.25 g}        • Dose 2 window {150..240}
  • Allow tonight only edits {On}

B) Early Dose 2 policy
  • Allow early dose {On}    • Max early minutes {15}
  • Require reason {On}      • Default time prior {5,10}

C) Notifications & Live Activity
  • Live Activity {On}       • Notify at start {On}
  • Notify at halfway {Off}  • Notify at end {On}
  • Haptics {Light}          • Quiet hours {22:00..07:00}

D) Data sources
  • Wake source {Manual | Health}
  • Health permissions {Open Fix}   • WHOOP proxy URL {…}
  • WHOOP status {Test}             • Timezone {Auto}

E) Exports
  • Include timezone {On}   • Include notes {On}
  • Include event log {On}  • Filename pattern {key_yyyy-MM-dd.csv}
  • Default email {clinician@host}

F) Privacy & retention
  • Biometric lock {Off}    • Mask widgets {On}
  • Retention days {365}    • Purge now {Action}

G) Debug & developer
  • Show internals {Off}    • Simulate Dose 1 {Action}
  • Force window open {Action}  • View event log {Action}
  • Schema version {display}

============================================================
5) Night Log — Phone first
============================================================
Header row with filters
[ Last 7 ] [ 30 ] [ All ]   [ Search 🔎 ]   [ Export ]
Row
┌───────────────────────────────────────────────────────────┐
│ 2025-11-01  Night total 6.50 g  ✓ Safety OK               │
│ 🛏 22:58  💊1 23:05 3.25 g  🚻 01:10  💊2 02:45 3.25 g     │
│ ⏰ Alarm 07:00  ☀ Final wake 07:22  Source: Health        │
└───────────────────────────────────────────────────────────┘
Tap row → detail with Edit, Undo, Export

============================================================
6) Empty / Error States
============================================================
Empty night
  ⌀ No events yet. Tap "In bed now" to start tonight.
Health denied
  ! Health permissions denied. Tap to fix in Settings.
WHOOP offline
  ! WHOOP proxy unreachable. Check URL and retry.
Undo snackbar
  ✓ Last event undone.  [ Redo ]

============================================================
7) Mapping to Actions and State
============================================================
Actions → ViewModel methods
[ In bed now ]           → logInBedNow()
[ Dose 1 now ]           → logDose1Now(grams)
[ Dose 2 now ]           → tryLogDose2()  → early sheet if blocked
[ Final wake now ]       → logFinalWakeNow()
[ Alarm wake ]           → logAlarmWakeNow()
[ Bathroom ]             → logBathroom()
[ Undo last ]            → undoLast()
[ Edit plan ]            → open Settings
[ Snooze 5m/10m ]        → scheduleDose2Reminder(minutes)
[ Autofill wake ]        → autofillWakeFromHealth()
[ Export CSV ]           → exportCSV(nightKey)
[ Reset Night ]          → resetNight(mode)

State flags
dose1TimeUTC, dose2TimeUTC, finalWakeTimeUTC
windowStartMin, windowEndMin, allowEarlyDose, maxEarlyMinutes
whoopStatus, healthStatus, wakeSource, dataQualityScore

============================================================
8) Accessibility notes
============================================================
• All primary actions min target 48x48 pt
• Dynamic type supported up to AX5
• VoiceOver labels include gram amounts and eligibility
• High contrast color pairs for ring and chips
