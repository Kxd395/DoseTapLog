-- Migration: Reset Night feature
PRAGMA foreign_keys = ON;

-- Add reset columns
ALTER TABLE sleep_sessions ADD COLUMN reset_batch_id TEXT;
ALTER TABLE sleep_sessions ADD COLUMN is_closed_by_reset BOOLEAN DEFAULT 0;

ALTER TABLE medication_events ADD COLUMN reset_batch_id TEXT;

-- Helper view: current open session
CREATE VIEW IF NOT EXISTS v_open_session AS
SELECT s.*
FROM sleep_sessions s
LEFT JOIN (
  SELECT sleep_session_id, MAX(event_time_utc) AS last_wake
  FROM event_log
  WHERE event_type IN ('final_wake','alarm_wake')
  GROUP BY sleep_session_id
) w ON w.sleep_session_id = s.id
WHERE s.deleted_at IS NULL
  AND (w.last_wake IS NULL);

-- Guard: prevent Dose 2 insert if session is closed by reset
CREATE TRIGGER IF NOT EXISTS trg_block_inserts_on_reset
BEFORE INSERT ON medication_events
WHEN NEW.sleep_session_id IN (
  SELECT id FROM sleep_sessions WHERE is_closed_by_reset = 1
)
BEGIN
  SELECT RAISE(ABORT, 'session_closed_by_reset');
END;

-- Convenience: materialize reset batch id on related writes if provided
CREATE TRIGGER IF NOT EXISTS trg_propagate_reset_batch_on_med
AFTER INSERT ON medication_events
WHEN NEW.reset_batch_id IS NOT NULL
BEGIN
  UPDATE sleep_sessions
    SET reset_batch_id = COALESCE(reset_batch_id, NEW.reset_batch_id)
  WHERE id = NEW.sleep_session_id;
END;
