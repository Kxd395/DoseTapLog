# Agent Instructions - DoseTrack SQLite Review Kit v1.1.1c

Objective: Review the schema for safety, correctness, maintainability, and suitability for iOS SwiftData mapping and on-device analytics.

## Steps

1. Setup
   - Confirm SQLite version with `sqlite3 -version`.
   - Create a fresh database using schema, seeds, and views as shown in README.

2. Static Review
   - Parse and lint sql/schema.sql for foreign keys, CHECK constraints, and enum patterns.
   - Verify triggers enforce per dose bounds, nightly totals, and dose window rules.
   - Validate indexes support the common queries.

3. Execute Examples
   - Run sql/examples.sql end to end.
   - Confirm that invalid inserts fail with clear error messages.
   - Confirm v_clinician_csv returns a single row per session with sane values.

4. Safety and Privacy
   - Map each Safety_Checklist item to the schema or trigger that enforces it.
   - Verify hashing of medication names via seeds and ensure no plaintext meds in events.
   - Confirm no raw audio storage fields exist and only features are persisted.

5. Performance and Data Quality
   - Validate that the core tables have the right indexes.
   - Review v_sleep_data_quality logic and propose improvements if needed.
   - Inspect potential query plans for typical export and dashboard queries.

6. Deliverables
   - A JSON report named `agent_report.json` with:
     - schema_findings: list of issues with severity and remediation
     - trigger_results: pass or fail with evidence
     - safety_alignment: mapping of checklist items to enforcement
     - export_sample_metrics: row counts and sample values
     - recommendations: prioritized actions for v1.2
   - A Markdown summary named `agent_summary.md` with top 10 insights.

## Commands to run

```bash
sqlite3 dosetrack.db < sql/schema.sql
sqlite3 dosetrack.db < sql/seeds.sql
sqlite3 dosetrack.db < sql/views.sql
sqlite3 dosetrack.db < sql/examples.sql

# Export clinician csv
sqlite3 -header -csv dosetrack.db "SELECT * FROM v_clinician_csv" > clinician_export.csv
```

## Acceptance Criteria

- All triggers fire for invalid data with useful messages.
- QA and Safety checklists are completely addressable by the schema and triggers.
- v_clinician_csv returns correct and normalized rows for the included examples.
- The agent provides a structured JSON and a concise Markdown summary.
