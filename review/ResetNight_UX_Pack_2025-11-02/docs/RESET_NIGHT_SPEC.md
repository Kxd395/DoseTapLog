# Reset Night - Safety Feature
Date: 2025-11-02
Owner: DoseTrack

## Purpose
Provide a safe escape hatch when a night gets into a bad state. The user can start over without corrupting data.

## Modes
1) Soft Reset: closes the current night, archives events with a reset_batch_id, creates a fresh sleep_session with the same night_key suffix "+R1".
2) Hard Reset: closes and hard-deletes the current night content via deleted_at, requires biometric and typed confirmation.

## UX
- Entry points:
  - Settings gear -> "Reset Night"
  - Overflow menu on Today screen
- Confirmation sheet with mode picker and reason
- Undo banner for 30 seconds
- After reset: Live Activity ends, notifications canceled, UI returns to pre-night state

## Safety
- Requires no Final wake for soft reset. If Final wake exists, show "Night already closed" message.
- Hard reset requires biometric if enabled in settings and typed keyword: RESET
- Always writes an audit event: event_type = "reset_night"

## Data Model Additions
event_log.event_type new values:
- reset_night

event_log.payload_json fields:
- {"mode":"soft|hard","reason":"text","reset_batch_id":"uuid","actor":"user|system"}

medication_events new nullable columns:
- reset_batch_id TEXT

sleep_sessions new nullable columns:
- reset_batch_id TEXT
- is_closed_by_reset BOOLEAN DEFAULT 0

## SQL
See sql/migrations/00X_reset_night.sql

## VM API
TodayViewModel:
- func presentResetNight()
- func performResetNight(mode: ResetMode, reason: String)
- func undoResetNight(resetBatchId: String)

## Tests
- No night -> Reset is disabled
- With Dose 1 only -> Soft reset succeeds, undo restores events
- With Final wake -> Soft reset blocked, Hard reset allowed with biometric + keyword
- Live Activity ends on reset
- Notifications canceled and rescheduled only after next Dose 1
