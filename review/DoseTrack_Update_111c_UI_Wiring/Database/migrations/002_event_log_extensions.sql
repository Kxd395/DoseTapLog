-- 002_event_log_extensions.sql
-- Extends event_log to capture early overrides and wake classification
ALTER TABLE event_log ADD COLUMN early_override_minutes INTEGER;
ALTER TABLE event_log ADD COLUMN early_override_reason TEXT;
ALTER TABLE event_log ADD COLUMN wake_reason TEXT;
ALTER TABLE event_log ADD COLUMN was_alarm_interrupted BOOLEAN DEFAULT 0;
