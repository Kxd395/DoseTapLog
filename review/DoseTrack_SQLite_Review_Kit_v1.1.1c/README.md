# DoseTrack SQLite Review Kit v1.1.1c

This is a drop-in review bundle for an agent to analyze the DoseTrack SQLite storage layer.

- Platform: macOS with SQLite 3.x
- Scope: Schema, constraints, triggers, seeds, views, examples, scripts, and agent instructions
- Goal: Allow an agent to lint the schema, run checks, execute examples, and produce findings

## Quickstart

```bash
cd "/mnt/data/DoseTrack_SQLite_Review_Kit_v1.1.1c"
# Create fresh db
sqlite3 dosetrack.db < sql/schema.sql
sqlite3 dosetrack.db < sql/seeds.sql
sqlite3 dosetrack.db < sql/views.sql

# Try examples and see triggers in action
sqlite3 dosetrack.db < sql/examples.sql

# Export the clinician view to CSV
sqlite3 -header -csv dosetrack.db "SELECT * FROM v_clinician_csv" > clinician_export.csv
```

## Contents

- sql/schema.sql - core tables, constraints, and triggers
- sql/seeds.sql - Xywav guardrails and app defaults
- sql/views.sql - flattened export and data quality views
- sql/examples.sql - valid and invalid inserts to test triggers
- migrations/001_initial.sql - initial migration copy
- checklists/QA_Checklist.md - execution steps for quality checks
- checklists/Safety_Checklist.md - safety guardrails to verify
- rubric/EVALUATION_RUBRIC.md - scoring template
- AGENT_INSTRUCTIONS.md - step by step for the reviewing agent
- tasks/TASKS.md - concrete tasks and expected artifacts
- scripts/mac_init.sh - helper to bootstrap on macOS

## Notes

- Foreign keys are on. All datetimes are ISO 8601 UTC strings.
- No em or en dashes are used in this kit.
