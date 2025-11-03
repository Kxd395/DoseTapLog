# DoseTrack PRD v1.2
[trimmed summary for agent review; see main conversation for context]

- Users: Adult patient; clinician
- Guardrails: 1.5–4.5g per dose; 3.0–9.0g total; 150–240 min window
- Data model: DoseLog with UTC times and timezoneOffsetMinutes
- Workflows: Onboarding → Plan → Log Dose 1/2 → Final Wake → CSV
- Integrations: HealthKit (read sleep), App Groups + Widget, WHOOP proxy
- Success: 90% capture, 85% completeness, 60% auto-fill, 80% clinician acceptance
