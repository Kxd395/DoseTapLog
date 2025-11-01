# DoseTrack v1.2 PRD

## Executive summary
DoseTrack is a local-first iOS app plus a small WHOOP proxy that helps a patient on Xywav plan and log bedtime, two nightly doses, bathroom wakes, and final wake, then exports a clinician-friendly CSV. The v1.2 mandate focuses on a data-driven night plan and frictionless capture.

## Problem
Patients struggle to adhere to the second dose window and to recall times accurately the next day. Clinicians receive messy logs.

## Goals
- Capture rate target 90 percent of nights
- Completeness target 85 percent including Final Wake
- Clinician-ready CSV in HH:mm keyed to bedtime date

## Users
- Primary: Adult patient on twice-nightly Xywav
- Secondary: Treating clinician reviewing CSV

## Scope
- iOS app with SwiftData storage and Widget
- WHOOP proxy for sleep and aggregates
- HealthKit final wake autofill
- CSV export

## Non goals
- No cloud sync
- No analytics or PHI transmission

## Safety guardrails
- Per dose 1.5 g to 4.5 g
- Total nightly 3.0 g to 9.0 g
- Second dose window 150 to 240 minutes
- Internal math keeps full precision. 0.25 g rounding only for display and save.

## Success metrics
- Capture rate 90 percent
- Final wake autofilled on 60 percent of nights
- Clinician CSV acceptance 80 percent

## Workflows
- One tap log for Dose 1 and Dose 2 from app or widget
- Autofill final wake from WHOOP or Health

## Architecture
- Local SwiftData store with UTC timestamps and stored timezone offset per night
- WHOOP proxy with API key and rate limit

## Validation plan
- 14 day internal pilot with CSV review
- Unit tests for ordering guards and CSV
