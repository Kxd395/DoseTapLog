-- Migration 005: Dose 2 Override Tracking
-- Adds comprehensive override columns and safety triggers for early/late dose tracking

-- Add override tracking columns to event_log
ALTER TABLE event_log
  ADD COLUMN override_kind TEXT
    CHECK (override_kind IN ('none','early','late')) DEFAULT 'none';

ALTER TABLE event_log
  ADD COLUMN early_by_min INTEGER;   -- null unless override_kind='early'

ALTER TABLE event_log
  ADD COLUMN late_by_min INTEGER;    -- null unless override_kind='late'

ALTER TABLE event_log
  ADD COLUMN override_reason TEXT;   -- required if requireEarlyReason or requireLateReason

ALTER TABLE event_log
  ADD COLUMN override_confirmed INTEGER DEFAULT 0 
    CHECK (override_confirmed IN (0,1));

-- Index for querying overrides
CREATE INDEX IF NOT EXISTS idx_event_log_overrides
  ON event_log(night_key, event_type, override_kind)
  WHERE override_kind IN ('early', 'late');

-- View for override analysis
CREATE VIEW IF NOT EXISTS v_dose2_overrides AS
SELECT
  e.night_key,
  e.timestamp,
  e.event_type,
  e.override_kind,
  e.early_by_min,
  e.late_by_min,
  e.override_reason,
  e.override_confirmed,
  d.dose1_time_utc,
  d.dose2_time_utc,
  CAST((julianday(e.timestamp) - julianday(d.dose1_time_utc)) * 1440 AS INTEGER) as actual_elapsed_min
FROM event_log e
LEFT JOIN dose_log d ON e.night_key = d.night_key
WHERE e.event_type = 'dose2' AND e.override_kind != 'none';

-- Safety trigger: Prevent early dose beyond policy
CREATE TRIGGER IF NOT EXISTS trg_dose2_early_policy
BEFORE INSERT ON event_log
WHEN NEW.event_type = 'dose2'
  AND NEW.override_kind = 'early'
  AND NEW.early_by_min IS NOT NULL
BEGIN
  -- Note: App-level validation is primary; this is a safety backstop
  -- In production, you might want to query app_preferences table or remove this
  SELECT CASE
  WHEN NEW.early_by_min > 60  -- Hard limit: never allow >60 min early
    THEN RAISE(ABORT, 'early dose exceeds absolute safety limit (60 min)')
  END;
END;

-- Safety trigger: Prevent late dose beyond policy
CREATE TRIGGER IF NOT EXISTS trg_dose2_late_policy
BEFORE INSERT ON event_log
WHEN NEW.event_type = 'dose2'
  AND NEW.override_kind = 'late'
  AND NEW.late_by_min IS NOT NULL
BEGIN
  -- Hard limit: never allow >120 min late (would be missed dose)
  SELECT CASE
  WHEN NEW.late_by_min > 120
    THEN RAISE(ABORT, 'late dose exceeds absolute safety limit (120 min)')
  END;
END;

-- Trigger: Ensure override_confirmed=1 when override_kind is not 'none'
CREATE TRIGGER IF NOT EXISTS trg_dose2_override_confirmed
BEFORE INSERT ON event_log
WHEN NEW.event_type = 'dose2'
  AND NEW.override_kind IN ('early', 'late')
  AND NEW.override_confirmed = 0
BEGIN
  SELECT RAISE(ABORT, 'override must be confirmed before logging');
END;

-- Backfill existing dose2 events with default 'none' override
UPDATE event_log
SET override_kind = 'none',
    override_confirmed = 0
WHERE event_type = 'dose2'
  AND override_kind IS NULL;

-- Migration complete
SELECT 'Migration 005 complete: Dose 2 override tracking enabled' as status;
