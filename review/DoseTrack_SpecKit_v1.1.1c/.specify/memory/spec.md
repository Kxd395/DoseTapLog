# DoseTrack Specification - v1.1.1c Baseline
Date: 2025-11-01

## Product Overview
DoseTrack is a local first iOS app that helps adult patients on twice nightly Xywav plan and record bedtime, Dose 1, Dose 2, bathroom wakes, and Final Wake. It produces a clinician friendly CSV and offers a widget with one tap logging. A localhost WHOOP proxy can provide sleep aggregates when available.

## Personas
- Primary: Adult patient taking Xywav twice nightly.
- Secondary: Treating clinician who reviews the CSV export.

## Core Workflows
1. First run onboarding collects bedtime preference and total nightly grams.
2. Night plan generation computes a split and window with safety guardrails.
3. Dose logging uses one tap buttons in app or App Intents from the widget.
4. Final Wake capture auto fills from HealthKit when recent. Manual WHOOP fetch is optional.
5. CSV export creates one row per night keyed to bedtime date with HH:mm times.

## Data Model
- DoseLog: @Model keyed by nightKey "YYYY-MM-DD". All timestamps stored in UTC. timezoneOffsetMinutes recorded when the night is created.
- Fields: nightStartUTC, timezoneOffsetMinutes, bedtimeUTC, dose1TimeUTC, dose2TimeUTC, finalWakeTimeUTC, bathroomWakeTimesUTC[], dose1Grams, dose2Grams, morningAlertness, notes, finalWakeProvenance.
- Validation: dose2TimeUTC must be after dose1TimeUTC and within 150 to 240 minutes of Dose 1.

## Safety Guardrails
- Per dose min 1.5 g and max 4.5 g.
- Total nightly min 3.0 g and max 9.0 g.
- Dose 2 window 150 to 240 minutes after Dose 1.
- Internal math full precision. 0.25 g rounding only for display and saved values.

## Integrations
- HealthKit read Sleep Analysis to infer Final Wake end time with user consent.
- App Groups "group.com.jefferson.dosetrack" for widget App Intent writes.
- WHOOP localhost proxy supports /api/sleep/latest and /api/aggregates/7days with x-api-key.

## Night Plan Recommender
- Start from preferred split percent, default 50.
- Adjust Dose 1 by plus or minus 0.125 g based on WHOOP recovery 0 to 100 when available.
- Clamp each dose to guardrails. Return precise grams for internal use and 0.25 g rounded values for UI.

## Success Metrics
- Capture rate 90 percent nights logged.
- Completeness 85 percent include Final Wake.
- 60 percent of Final Wake auto filled from HealthKit.
- 80 percent clinician acceptance of CSV.

## Non Goals
- No cloud sync or multi device support in pilot.
- No analytics or telemetry.
- No medication reminder beyond the Dose 2 window prompt.
