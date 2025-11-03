-- Data quality view
CREATE VIEW IF NOT EXISTS v_sleep_data_quality AS
SELECT
  s.id AS sleep_session_id,
  s.user_in_bed_time_utc,
  s.user_final_wake_time_utc,
  s.data_quality_score,
  CASE
    WHEN p.healthkit_avg_hr IS NULL AND p.whoop_avg_hr IS NULL THEN 'Missing physiology'
    WHEN es.survey_abandoned = 1 THEN 'Survey incomplete'
    ELSE 'Good'
  END AS data_issues
FROM sleep_sessions s
LEFT JOIN physiological_data p ON p.sleep_session_id = s.id
LEFT JOIN environmental_survey_data es ON es.sleep_session_id = s.id
WHERE s.deleted_at IS NULL;

-- Flattened clinician export view - one row per session
CREATE VIEW IF NOT EXISTS v_clinician_csv AS
WITH dose_times AS (
  SELECT
    sleep_session_id,
    MIN(CASE WHEN event_type='dose1' THEN event_time_utc END) AS dose1_time_utc,
    MIN(CASE WHEN event_type='dose2' THEN event_time_utc END) AS dose2_time_utc,
    MIN(CASE WHEN event_type='final_wake' THEN event_time_utc END) AS final_wake_time_utc
  FROM event_log
  GROUP BY sleep_session_id
),
xywav_nightly AS (
  SELECT
    e.sleep_session_id,
    SUM(CASE WHEN e.medication_name_hash = (SELECT value FROM app_preferences WHERE key='xywav_hash') THEN e.grams ELSE 0 END) AS xywav_total_grams
  FROM medication_events e
  WHERE e.deleted_at IS NULL
  GROUP BY e.sleep_session_id
)
SELECT
  s.id AS sleep_session_id,
  s.night_key,
  s.user_in_bed_time_utc,
  COALESCE(dt.final_wake_time_utc, s.user_final_wake_time_utc) AS final_wake_time_utc,
  dt.dose1_time_utc,
  dt.dose2_time_utc,
  xn.xywav_total_grams,
  p.whoop_recovery_score,
  p.healthkit_sdnn,
  p.whoop_rmssd,
  es.alcohol_units,
  es.stress_rating,
  es.noise_mean_db,
  es.noise_max_db,
  s.data_quality_score
FROM sleep_sessions s
LEFT JOIN dose_times dt ON dt.sleep_session_id = s.id
LEFT JOIN xywav_nightly xn ON xn.sleep_session_id = s.id
LEFT JOIN physiological_data p ON p.sleep_session_id = s.id
LEFT JOIN environmental_survey_data es ON es.sleep_session_id = s.id
WHERE s.deleted_at IS NULL;
