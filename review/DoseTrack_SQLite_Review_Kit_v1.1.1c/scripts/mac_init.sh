#!/usr/bin/env bash
set -euo pipefail

echo "DoseTrack SQLite Review Kit bootstrap"
command -v sqlite3 >/dev/null || { echo "Please install sqlite3 first. On macOS: brew install sqlite3"; exit 1; }

cd "$(dirname "$0")/.."

sqlite3 dosetrack.db < sql/schema.sql
sqlite3 dosetrack.db < sql/seeds.sql
sqlite3 dosetrack.db < sql/views.sql
sqlite3 dosetrack.db < sql/examples.sql

sqlite3 -header -csv dosetrack.db "SELECT * FROM v_clinician_csv" > clinician_export.csv
echo "Completed. Open clinician_export.csv in Numbers or Excel."
