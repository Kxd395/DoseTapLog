-- Seeds for catalog and preferences
INSERT OR IGNORE INTO medication_catalog
(name_hash, display_name, enforce_bounds, min_grams, max_grams, min_total_grams, max_total_grams)
VALUES
('587df9fd5aea72146e002b2fb1614d1e81504bf6c374e537ad47f9715d93d2f1', 'Xywav', 1, 1.5, 4.5, 3.0, 9.0);

-- App defaults
INSERT OR REPLACE INTO app_preferences(key, value) VALUES
('csv_timezone', 'UTC'),
('xywav_hash', '587df9fd5aea72146e002b2fb1614d1e81504bf6c374e537ad47f9715d93d2f1'),
('dose2_window_start_min', '150'),
('dose2_window_end_min', '240');
