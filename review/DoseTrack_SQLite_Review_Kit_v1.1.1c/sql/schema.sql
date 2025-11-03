PRAGMA foreign_keys = ON;

-- Core sessions
CREATE TABLE IF NOT EXISTS sleep_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  night_key TEXT UNIQUE,
  user_in_bed_time_utc TEXT NOT NULL,
  user_final_wake_time_utc TEXT NOT NULL,
  data_source_conflict INTEGER DEFAULT 0,
  sleep_window_source TEXT CHECK(sleep_window_source IN ('user','healthkit','whoop','auto')),
  has_physio_data INTEGER DEFAULT 0,
  has_survey_data INTEGER DEFAULT 0,
  has_environment_data INTEGER DEFAULT 0,
  data_quality_score INTEGER DEFAULT 100,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now')),
  deleted_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_sleep_sessions_timing
ON sleep_sessions(user_in_bed_time_utc, user_final_wake_time_utc);

-- Medication catalog - privacy oriented
CREATE TABLE IF NOT EXISTS medication_catalog (
  name_hash TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  enforce_bounds INTEGER DEFAULT 1,
  min_grams REAL,
  max_grams REAL,
  min_total_grams REAL,
  max_total_grams REAL,
  is_active INTEGER DEFAULT 1,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);

-- Medication events - any medication
CREATE TABLE IF NOT EXISTS medication_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sleep_session_id INTEGER REFERENCES sleep_sessions(id) ON DELETE CASCADE,
  medication_name_hash TEXT NOT NULL REFERENCES medication_catalog(name_hash),
  grams REAL,
  units TEXT, -- "g", "mg"
  scheduled_time_utc TEXT NOT NULL,
  actual_time_utc TEXT NOT NULL,
  timing_compliance_minutes INTEGER,
  notes TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now')),
  deleted_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_medication_events_timing
ON medication_events(actual_time_utc);

-- Event log for keypad style events
CREATE TABLE IF NOT EXISTS event_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sleep_session_id INTEGER NOT NULL REFERENCES sleep_sessions(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL CHECK(event_type IN ('in_bed','dose1','bathroom','dose2','alarm_wake','final_wake')),
  event_time_utc TEXT NOT NULL,
  payload_json TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);

-- Physiological data
CREATE TABLE IF NOT EXISTS physiological_data (
  sleep_session_id INTEGER PRIMARY KEY REFERENCES sleep_sessions(id) ON DELETE CASCADE,
  -- HealthKit
  healthkit_avg_hr REAL,
  healthkit_min_hr REAL,
  healthkit_avg_resp_rate REAL,
  healthkit_sdnn REAL,
  healthkit_resting_hr REAL,
  -- WHOOP
  whoop_avg_hr REAL,
  whoop_min_hr REAL,
  whoop_avg_resp_rate REAL,
  whoop_rmssd REAL,
  whoop_resting_hr REAL,
  whoop_recovery_score INTEGER,
  -- Sleep architecture
  sleep_stage_min_light INTEGER,
  sleep_stage_min_deep INTEGER,
  sleep_stage_min_rem INTEGER,
  sleep_disturbances_count INTEGER,
  -- Data quality
  healthkit_data_quality TEXT CHECK(healthkit_data_quality IN ('full','partial','missing','denied')),
  whoop_data_quality TEXT CHECK(whoop_data_quality IN ('full','partial','missing','error')),
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now')),
  deleted_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_physio_quality
ON physiological_data(healthkit_data_quality, whoop_data_quality);

-- Environmental survey
CREATE TABLE IF NOT EXISTS environmental_survey_data (
  sleep_session_id INTEGER PRIMARY KEY REFERENCES sleep_sessions(id) ON DELETE CASCADE,
  alcohol_units REAL CHECK(alcohol_units >= 0 AND alcohol_units <= 6),
  alcohol_time_utc TEXT,
  stress_rating INTEGER CHECK(stress_rating >= 1 AND stress_rating <= 5),
  room_light_level TEXT CHECK(room_light_level IN ('dark','dim','bright')),
  screen_last_off_utc TEXT,
  screen_time_source TEXT CHECK(screen_time_source IN ('shortcuts','manual','estimated')),
  alarm_used INTEGER DEFAULT 0,
  alarm_time_utc TEXT,
  noise_mean_db REAL CHECK(noise_mean_db >= 0 AND noise_mean_db <= 120),
  noise_max_db REAL,
  noise_snore_events INTEGER,
  noise_cough_events INTEGER,
  noise_recording_enabled INTEGER DEFAULT 0,
  ambient_light_lux REAL,
  light_source TEXT CHECK(light_source IN ('sensor','manual','homekit')),
  user_notes TEXT,
  survey_completion_seconds INTEGER,
  survey_abandoned INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now')),
  deleted_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_survey_completion
ON environmental_survey_data(survey_abandoned, created_at);

-- ML training data
CREATE TABLE IF NOT EXISTS ml_training_data (
  sleep_session_id INTEGER PRIMARY KEY REFERENCES sleep_sessions(id) ON DELETE CASCADE,
  feature_vector_json TEXT,
  next_day_alertness INTEGER CHECK(next_day_alertness BETWEEN 1 AND 5),
  morning_sleep_quality INTEGER CHECK(morning_sleep_quality BETWEEN 1 AND 5),
  unplanned_nap_occurred INTEGER,
  model_version TEXT,
  prediction_confidence REAL,
  used_in_training INTEGER DEFAULT 0,
  imputation_method TEXT,
  bias_check_score REAL,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now')),
  deleted_at TEXT
);

-- Models registry
CREATE TABLE IF NOT EXISTS ml_models (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  model_name TEXT NOT NULL,
  model_type TEXT NOT NULL,
  model_version TEXT NOT NULL,
  coefficients_json TEXT,
  feature_names_json TEXT,
  intercept REAL,
  training_start_date TEXT,
  training_end_date TEXT,
  nights_used_in_training INTEGER,
  model_accuracy REAL,
  is_active INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now'))
);

-- App preferences
CREATE TABLE IF NOT EXISTS app_preferences (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT DEFAULT (datetime('now'))
);

-- Triggers - per dose bounds using medication_catalog
CREATE TRIGGER IF NOT EXISTS trg_med_event_bounds_ins
BEFORE INSERT ON medication_events
WHEN NEW.grams IS NOT NULL
AND EXISTS (
  SELECT 1 FROM medication_catalog c
  WHERE c.name_hash = NEW.medication_name_hash
    AND c.enforce_bounds = 1
    AND (NEW.grams < c.min_grams OR NEW.grams > c.max_grams)
)
BEGIN
  SELECT RAISE(ABORT, 'per dose out of range');
END;

CREATE TRIGGER IF NOT EXISTS trg_med_event_bounds_upd
BEFORE UPDATE ON medication_events
WHEN NEW.grams IS NOT NULL
AND EXISTS (
  SELECT 1 FROM medication_catalog c
  WHERE c.name_hash = NEW.medication_name_hash
    AND c.enforce_bounds = 1
    AND (NEW.grams < c.min_grams OR NEW.grams > c.max_grams)
)
BEGIN
  SELECT RAISE(ABORT, 'per dose out of range');
END;

-- Nightly total max by medication
CREATE TRIGGER IF NOT EXISTS trg_med_event_total_max_ins
AFTER INSERT ON medication_events
WHEN EXISTS (
  SELECT 1 FROM medication_catalog c
  WHERE c.name_hash = NEW.medication_name_hash
    AND c.enforce_bounds = 1
    AND c.max_total_grams IS NOT NULL
)
BEGIN
  SELECT CASE
    WHEN (
      SELECT IFNULL(SUM(e.grams),0)
      FROM medication_events e
      WHERE e.deleted_at IS NULL
        AND e.sleep_session_id = NEW.sleep_session_id
        AND e.medication_name_hash = NEW.medication_name_hash
    ) > (
      SELECT c.max_total_grams FROM medication_catalog c
      WHERE c.name_hash = NEW.medication_name_hash
    )
    THEN RAISE(ABORT, 'nightly total exceeded')
  END;
END;

CREATE TRIGGER IF NOT EXISTS trg_med_event_total_max_upd
AFTER UPDATE ON medication_events
WHEN EXISTS (
  SELECT 1 FROM medication_catalog c
  WHERE c.name_hash = NEW.medication_name_hash
    AND c.enforce_bounds = 1
    AND c.max_total_grams IS NOT NULL
)
BEGIN
  SELECT CASE
    WHEN (
      SELECT IFNULL(SUM(e.grams),0)
      FROM medication_events e
      WHERE e.deleted_at IS NULL
        AND e.sleep_session_id = NEW.sleep_session_id
        AND e.medication_name_hash = NEW.medication_name_hash
    ) > (
      SELECT c.max_total_grams FROM medication_catalog c
      WHERE c.name_hash = NEW.medication_name_hash
    )
    THEN RAISE(ABORT, 'nightly total exceeded')
  END;
END;

-- Dose 2 window enforcement using event_log times
CREATE TRIGGER IF NOT EXISTS trg_event_log_dose2_window
BEFORE INSERT ON event_log
WHEN NEW.event_type = 'dose2'
BEGIN
  SELECT CASE
    WHEN NOT EXISTS (
      SELECT 1 FROM event_log e1
      WHERE e1.sleep_session_id = NEW.sleep_session_id
        AND e1.event_type = 'dose1'
        AND (strftime('%s', NEW.event_time_utc) - strftime('%s', e1.event_time_utc)) BETWEEN 150*60 AND 240*60
    )
    THEN RAISE(ABORT, 'dose2 window violation')
  END;
END;
