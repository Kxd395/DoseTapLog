# DoseTrack Consolidated Review Kit v1.1.1c

Date: 2025-11-01

This kit merges the Agent Review Kit checklists with the current v1.1.1c implementation so you can validate quickly and hand it to your agent or a reviewer.

Contents:
- docs/README_CONSOLIDATED.md - this file
- checklists/MASTER_CHECKLIST.md - one list to rule them all
- checklists/CLINICAL_SAFETY.md - focused on dose and timing guardrails
- checklists/QA_SMOKE.md - quick smoke steps for server and iOS
- forms/AcceptanceCriteria.json - machine readable criteria for agents
- scripts/smoke_server.sh - curl based checks for the local proxy
- scripts/spec_kit_sync_commands.txt - ready to paste Spec Kit commands

Assumptions:
- Local only pilot
- WHOOP proxy on http://localhost:3000
- x-api-key header required for /api endpoints
