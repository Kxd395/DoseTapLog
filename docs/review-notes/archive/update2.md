You’re right. The core issue is wake time and guarding against a “too late to dose” situation. Here’s a precise, drop-in plan that makes Dose 2 logic bulletproof, with UI, settings, Swift gating, and SQLite guardrails.

What to protect
	1.	Too early relative to Dose 1.
	2.	After the window closes.
	3.	After Final wake or Alarm wake has been logged.
	4.	Too close to morning wake time (define a safety buffer).
	5.	Optional early override with reason and a small “time prior” choice.

Policy tree the app should enforce

Inputs
	•	dose1TimeUTC
	•	nowUTC
	•	finalWakeTimeUTC or alarmWakeTimeUTC
	•	plannedWakeUTC (optional, from user schedule or Health prediction)
	•	Prefs: windowStartMin (default 150), windowEndMin (default 240), allowEarlyDose, maxEarlyMinutes (default 15), minBufferToWakeMin (default 240), allowLateOverride (default false), maxLateMinutes (default 0)

Outcomes
	•	Disabled with human reason
	•	Early allowed with confirm sheet and “time prior” buttons
	•	Eligible now
	•	Window expired, offer “Log missed dose”
	•	Blocked by wake or safety buffer

Button behavior rules
	•	If Final wake or Alarm wake is present, disable Dose 2. Reason: “Wake already logged.” Action: “Convert to final wake” stays available only on Alarm wake.
	•	If elapsed since Dose 1 < windowStartMin
	•	If allowEarlyDose and minutes early ≤ maxEarlyMinutes then show Early confirmation sheet with “time prior” options.
	•	Else disable with “Dose 2 opens in X min”, optional “Remind me at window start”.
	•	If elapsed is within window and buffer to wake ≥ minBufferToWakeMin, enable Dose 2.
	•	If within window but buffer to wake is smaller than minBufferToWakeMin, disable and show “Too close to wake. Buffer needed: Y min.”
	•	If elapsed > windowEndMin
	•	If allowLateOverride and minutes late ≤ maxLateMinutes, show Late confirmation sheet.
	•	Else convert button to “Log missed dose”.

Settings to add in the gear panel

Night plan
	•	Total night grams
	•	Split strategy: 50-50, 60-40, 40-60, custom
	•	Rounding increment

Window rules
	•	Window start minutes (150)
	•	Window end minutes (240)
	•	Minimum buffer to wake minutes (240)

Early and late policy
	•	Allow early dose 2 (toggle)
	•	Max early minutes (15)
	•	Require early reason (toggle)
	•	Early “time prior” buttons: CSV string “5,10”
	•	Allow late override (toggle, default off)
	•	Max late minutes (0 by default)
	•	Require late reason (toggle)

Wake source and safety
	•	Treat Alarm wake as Final wake until converted (toggle)
	•	Prefer Health for wake when available (toggle)
	•	Planned wake time fallback for buffer checks: manual schedule HH:mm

Notifications
	•	Remind at window start, halfway, end
	•	Live Activity for window timer

Privacy and export
	•	Include override reasons in CSV (toggle)
	•	Include event log tail in CSV (toggle)

Swift gating function you can paste

enum Dose2Gate {
    case disabled(String)                  // reason
    case earlyAllowed(minutesEarly: Int)   // show confirm sheet
    case eligible                          // green light
    case windowExpired(String)             // reason
    case blockedByWake(String)             // reason
}

struct Dose2Policy {
    let windowStartMin: Int
    let windowEndMin: Int
    let allowEarlyDose: Bool
    let maxEarlyMinutes: Int
    let minBufferToWakeMin: Int
    let allowLateOverride: Bool
    let maxLateMinutes: Int
}

func evaluateDose2Gate(
    now: Date,
    dose1: Date?,
    finalWake: Date?,
    alarmWake: Date?,
    plannedWake: Date?,      // optional, for buffer checks
    prefs: Dose2Policy
) -> Dose2Gate {
    // 1. Wake blocks
    if finalWake != nil { return .blockedByWake("Final wake already logged.") }
    if alarmWake != nil { return .blockedByWake("Alarm wake logged. Convert to final wake if intended.") }

    guard let d1 = dose1 else {
        return .disabled("Log Dose 1 first.")
    }

    let elapsedMin = Int(now.timeIntervalSince(d1) / 60)
    let start = prefs.windowStartMin
    let end = prefs.windowEndMin

    // 2. Too early
    if elapsedMin < start {
        let minutesEarly = start - elapsedMin
        if prefs.allowEarlyDose && minutesEarly <= prefs.maxEarlyMinutes {
            return .earlyAllowed(minutesEarly: minutesEarly)
        } else {
            return .disabled("Dose 2 opens in \(minutesEarly) min.")
        }
    }

    // 3. Window open
    if elapsedMin <= end {
        // Buffer to wake check
        if let wake = plannedWake {
            let bufferMin = Int(wake.timeIntervalSince(now) / 60)
            if bufferMin < prefs.minBufferToWakeMin {
                return .disabled("Too close to wake. Need \(prefs.minBufferToWakeMin - bufferMin) more min buffer.")
            }
        }
        return .eligible
    }

    // 4. Window expired
    let minutesLate = elapsedMin - end
    if prefs.allowLateOverride && minutesLate <= prefs.maxLateMinutes {
        return .windowExpired("Window expired \(minutesLate) min ago. Late override allowed.")
    } else {
        return .windowExpired("Window expired \(minutesLate) min ago.")
    }
}

Event logging fields to support analysis

When Dose 2 is logged, store on the medication event:
	•	dose_order = 2
	•	override_kind one of { none, early, late }
	•	override_minutes signed int (+late, −early)
	•	override_reason short text
	•	buffer_to_wake_min_at_dose int or null
	•	gate_state_snapshot string like “eligible”, “too_early”, “too_close_to_wake”, “expired”

SQLite guardrails

Use triggers to hard-stop unsafe writes and to label overrides.

Early and window end checks need the Dose 1 timestamp. This trigger assumes two rows in medication_events for the same session with dose_order 1 and 2.

-- Window enforcement for Dose 2
CREATE TRIGGER IF NOT EXISTS trg_dose2_window
BEFORE INSERT ON medication_events
WHEN NEW.dose_order = 2
BEGIN
  -- pull policy
  SELECT
    CASE
      WHEN (
        SELECT CAST(value AS INTEGER)
        FROM app_preferences
        WHERE key = 'dose2_window_start_min'
      ) IS NULL THEN RAISE(ABORT, 'policy_missing')
  END;

  -- get Dose 1 time
  SELECT
    CASE
      WHEN (
        SELECT actual_time_utc
        FROM medication_events
        WHERE sleep_session_id = NEW.sleep_session_id
          AND dose_order = 1
          AND deleted_at IS NULL
        ORDER BY id DESC
        LIMIT 1
      ) IS NULL THEN RAISE(ABORT, 'dose1_missing')
  END;

  -- too early without override flag
  SELECT
    CASE
      WHEN (
        (strftime('%s', NEW.actual_time_utc) -
         strftime('%s', (SELECT actual_time_utc FROM medication_events
                         WHERE sleep_session_id = NEW.sleep_session_id AND dose_order = 1
                         AND deleted_at IS NULL ORDER BY id DESC LIMIT 1)
        )) / 60
        <
        (SELECT CAST(value AS INTEGER) FROM app_preferences WHERE key='dose2_window_start_min')
      )
      AND COALESCE(NEW.override_kind, '') <> 'early'
      THEN RAISE(ABORT, 'dose2_too_early')
    END;

  -- too late without override flag
  SELECT
    CASE
      WHEN (
        (strftime('%s', NEW.actual_time_utc) -
         strftime('%s', (SELECT actual_time_utc FROM medication_events
                         WHERE sleep_session_id = NEW.sleep_session_id AND dose_order = 1
                         AND deleted_at IS NULL ORDER BY id DESC LIMIT 1)
        )) / 60
        >
        (SELECT CAST(value AS INTEGER) FROM app_preferences WHERE key='dose2_window_end_min')
      )
      AND COALESCE(NEW.override_kind, '') <> 'late'
      THEN RAISE(ABORT, 'dose2_window_expired')
    END;

  -- block if final wake exists
  SELECT
    CASE
      WHEN EXISTS (
        SELECT 1 FROM event_log
        WHERE sleep_session_id = NEW.sleep_session_id
          AND event_type IN ('final_wake','alarm_wake')
          AND deleted_at IS NULL
      ) THEN RAISE(ABORT, 'wake_already_logged')
    END;
END;

Optional buffer guard at write time if you want it hard-blocked rather than just disabled in UI:

CREATE TRIGGER IF NOT EXISTS trg_dose2_buffer_to_wake
BEFORE INSERT ON medication_events
WHEN NEW.dose_order = 2 AND NEW.buffer_to_wake_min_at_dose IS NOT NULL
BEGIN
  SELECT CASE
    WHEN NEW.buffer_to_wake_min_at_dose <
         (SELECT CAST(value AS INTEGER) FROM app_preferences WHERE key='min_buffer_to_wake_min')
    THEN RAISE(ABORT, 'dose2_too_close_to_wake')
  END;
END;

UI copy so users understand
	•	Before window: “Dose 2 opens in 17 min. Set a reminder or choose an early override.”
	•	At window open: “Dose 2 window is open for 90 min.”
	•	Near end: “Window closes in 10 min.”
	•	After end: “Window expired 12 min ago. Log missed dose.”
	•	After wake: “Wake already logged. Dose 2 is disabled.”
	•	Buffer block: “Too close to morning. Need 45 more minutes of buffer to log Dose 2 safely.”

Early confirmation sheet
	•	Reason picker: “Woke early”, “Bathroom and cannot sleep”, “Travel or schedule constraint”, “Other” with free text
	•	Time prior segmented control: 5, 10, 15 min
	•	Show calculated early_by minutes and planned grams
	•	Clear disclaimer that overrides are for clinician-approved exceptions

Late confirmation sheet
	•	Only present if you enable late override. Defaults should keep this off. Same reason picker. Very small max window like 5 min if you allow it at all.

Tests you should add
	•	Dose 1 at 23:00, now 00:50. Start 150 min. Expected: disabled, opens in 40 min.
	•	Same, allow early, max 15. Now 01:40. Early 10 allowed.
	•	Same, now 02:40. Eligible.
	•	Same, now 03:45. Window expired 15. Late override off yields “missed dose”.
	•	Final wake at 02:10. Any time after that, blocked by wake.
	•	Planned wake at 06:30, min buffer 240. At 03:00, buffer 210, blocked with buffer reason.
	•	Alarm wake logged, then converted to final wake, Dose 2 stays blocked.

Why this matters

This closes the real safety gap you noticed: patients sometimes try to take Dose 2 after an awakening that is essentially the morning wake. With a hard buffer and a wake block, you avoid residual sedation and next-day safety problems.

If you want, I can package the Swift gating, two sheets, settings additions, and the SQL triggers into an update zip that drops into ios/ and docs/. Just say the word.

