# Repo Review Bundle

Location: `review/RepoReview/`
Generated: 2025-11-02

This bundle contains a complete prompt and scaffolding for a CodeX-style agent to review the DoseTrack repository,
validate architecture, run checks, and produce a written report with issues, tests, and remediation steps.

## Files

- `AGENT_PROMPT.md` - The master prompt for the agent with objectives, tasks, checks, and deliverables.
- `REVIEW_PLAN.md` - Step-by-step plan the agent should follow with milestones.
- `TEST_MATRIX.md` - Test plan with pass-fail criteria for iOS, server, and database.
- `ISSUE_CHECKLIST.md` - Opinionated checklist to catch common mistakes quickly.
- `BREADCRUMBS.md` - Expected file map and cross-links the agent should verify.
- `UI_WIRING_AUDIT.md` - Specific wiring audit for TodayLogView, ViewModel, and controller.
- `SETTINGS_COVERAGE.md` - Ensures every setting appears in UI and is persisted and read at runtime.
- `iOS_BUILD_CHECKLIST.md` - Mac build steps for iOS app with smoke tests.
- `SERVER_CHECKLIST.md` - Node server checks with curl examples.
- `SCHEMA_AUDIT.sql` - SQL validations for SQLite schema, constraints, and triggers.
- `RUN_REPO_REVIEW.sh` - Script that runs the checks locally on macOS where possible.

## How to use

1. Give `AGENT_PROMPT.md` to your agent as the task.
2. The agent should write all outputs to `review/RepoReview/output/` keeping the structure described in the prompt.
3. Optionally run `bash review/RepoReview/RUN_REPO_REVIEW.sh` on macOS to automate the checks.
