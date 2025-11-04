-- SCHEMA AUDIT
PRAGMA foreign_keys=ON;
PRAGMA integrity_check;

-- Example constraint checks (adapt names to your schema)
-- Per-dose bounds
-- Expect this to fail if grams < min or > max
-- INSERT INTO medication_events (..., grams, ...) VALUES (..., 0.5, ...);

-- Nightly total
-- Expect failure when sum exceeds nightly max after triggers fire

-- Window check
-- Expect failure if dose2 earlier than 150 minutes
