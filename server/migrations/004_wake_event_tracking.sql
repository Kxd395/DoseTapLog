-- Wake Event Tracking Enhancement
-- Migration: Add wake reason and context fields to event logging
-- Date: November 2, 2025

-- Add wake detail columns to event_log table
-- These columns store additional context for wake events only (NULL for other event types)

ALTER TABLE event_log
  ADD COLUMN wake_reason TEXT
    CHECK (wake_reason IN (
      'natural','alarm','bathroom','dose_recoil','noise',
      'pain','anxiety','nightmare','child_pet','work_shift','other'
    ));

ALTER TABLE event_log
  ADD COLUMN was_alarm_interrupted INTEGER DEFAULT 0 
    CHECK (was_alarm_interrupted IN (0,1));

ALTER TABLE event_log
  ADD COLUMN is_final INTEGER DEFAULT 0 
    CHECK (is_final IN (0,1));

-- Safety trigger: Prevent multiple final wakes per sleep session
-- This ensures data integrity for final wake tracking
CREATE TRIGGER IF NOT EXISTS trg_one_final_wake_per_night
BEFORE INSERT ON event_log
WHEN NEW.event_type = 'final_wake' OR NEW.is_final = 1
BEGIN
  SELECT CASE WHEN EXISTS (
    SELECT 1 FROM event_log
     WHERE sleep_session_id = NEW.sleep_session_id
       AND (event_type = 'final_wake' OR is_final = 1)
  ) THEN RAISE(ABORT, 'final wake already logged for this night') END;
END;

-- Index for fast wake event queries
CREATE INDEX IF NOT EXISTS idx_event_log_wake_events 
  ON event_log(sleep_session_id, is_final, wake_reason) 
  WHERE event_type IN ('alarm_wake', 'final_wake') OR wake_reason IS NOT NULL;

-- View for wake event analysis
CREATE VIEW IF NOT EXISTS v_wake_events AS
SELECT 
  el.sleep_session_id,
  el.event_type,
  el.timestamp_utc,
  el.wake_reason,
  el.was_alarm_interrupted,
  el.is_final,
  el.note,
  dl.night_key,
  dl.dose1_time_utc,
  dl.dose2_time_utc,
  CASE 
    WHEN el.timestamp_utc < dl.dose2_time_utc THEN 'before_dose2'
    WHEN el.timestamp_utc >= dl.dose2_time_utc THEN 'after_dose2'
    ELSE 'no_dose2'
  END AS wake_timing_context
FROM event_log el
JOIN dose_log dl ON el.sleep_session_id = dl.night_key
WHERE el.event_type IN ('alarm_wake', 'final_wake') 
   OR el.wake_reason IS NOT NULL
ORDER BY el.timestamp_utc;

-- Migration metadata
INSERT INTO schema_version (version, description, applied_at)
VALUES (4, 'Add wake event tracking with reasons and context', datetime('now'));
