-- Example workflow with one session
PRAGMA foreign_keys = ON;

-- 1. Session
INSERT INTO sleep_sessions(night_key, user_in_bed_time_utc, user_final_wake_time_utc, sleep_window_source)
VALUES ('2025-11-01', '2025-11-01T23:10:00Z', '2025-11-02T07:15:00Z', 'user');

SELECT * FROM sleep_sessions;

-- 2. Log dose1 and dose2 events - valid window 180 min
INSERT INTO event_log(sleep_session_id, event_type, event_time_utc) VALUES
(1, 'in_bed', '2025-11-01T23:12:00Z'),
(1, 'dose1', '2025-11-01T23:15:00Z'),
(1, 'dose2', '2025-11-02T02:15:00Z'),
(1, 'final_wake', '2025-11-02T07:15:00Z');

-- 3. Catalog already seeded for Xywav: 587df9fd5aea72146e002b2fb1614d1e81504bf6c374e537ad47f9715d93d2f1
SELECT 'xywav_hash' AS pref_key, value FROM app_preferences WHERE key='xywav_hash';

-- 4. Valid medication events - within per dose and nightly total
INSERT INTO medication_events(sleep_session_id, medication_name_hash, grams, units, scheduled_time_utc, actual_time_utc)
VALUES
(1, '587df9fd5aea72146e002b2fb1614d1e81504bf6c374e537ad47f9715d93d2f1', 3.0, 'g', '2025-11-01T23:00:00Z', '2025-11-01T23:15:00Z'),
(1, '587df9fd5aea72146e002b2fb1614d1e81504bf6c374e537ad47f9715d93d2f1', 3.0, 'g', '2025-11-02T02:00:00Z', '2025-11-02T02:15:00Z');

-- 5. Physio and survey
INSERT INTO physiological_data(sleep_session_id, whoop_recovery_score, healthkit_sdnn, whoop_rmssd, healthkit_resting_hr, whoop_resting_hr, healthkit_data_quality, whoop_data_quality)
VALUES (1, 64, 65.0, 48.0, 58.0, 55.0, 'full', 'partial');

INSERT INTO environmental_survey_data(sleep_session_id, alcohol_units, stress_rating, room_light_level, noise_mean_db, noise_max_db)
VALUES (1, 1.0, 3, 'dark', 32.0, 53.0);

-- 6. Export view
SELECT * FROM v_clinician_csv;

-- 7. Negative tests
-- 7a. Per dose out of range
BEGIN;
INSERT INTO medication_events(sleep_session_id, medication_name_hash, grams, units, scheduled_time_utc, actual_time_utc)
VALUES (1, '587df9fd5aea72146e002b2fb1614d1e81504bf6c374e537ad47f9715d93d2f1', 5.5, 'g', '2025-11-02T23:00:00Z', '2025-11-02T23:05:00Z');
ROLLBACK;

-- 7b. Nightly total exceeded
BEGIN;
INSERT INTO medication_events(sleep_session_id, medication_name_hash, grams, units, scheduled_time_utc, actual_time_utc)
VALUES (1, '587df9fd5aea72146e002b2fb1614d1e81504bf6c374e537ad47f9715d93d2f1', 4.5, 'g', '2025-11-02T23:10:00Z', '2025-11-02T23:15:00Z');
INSERT INTO medication_events(sleep_session_id, medication_name_hash, grams, units, scheduled_time_utc, actual_time_utc)
VALUES (1, '587df9fd5aea72146e002b2fb1614d1e81504bf6c374e537ad47f9715d93d2f1', 4.6, 'g', '2025-11-02T23:20:00Z', '2025-11-02T23:25:00Z');
ROLLBACK;

-- 7c. Dose2 window violation - should fail
BEGIN;
INSERT INTO event_log(sleep_session_id, event_type, event_time_utc) VALUES
(1, 'dose2', '2025-11-01T23:16:00Z');
ROLLBACK;
