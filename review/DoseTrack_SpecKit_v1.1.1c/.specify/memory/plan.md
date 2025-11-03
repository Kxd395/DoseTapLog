# DoseTrack Technical Plan - v1.1.1c
Date: 2025-11-01

## Technology Stack
- iOS 16 or later. Swift 5.9 or later. SwiftUI and SwiftData.
- HealthKit for Sleep Analysis read.
- WidgetKit with App Intents and App Groups for one tap logging.
- Node.js Express proxy on localhost for WHOOP integration during pilot.

## Architecture
- App entry with @main DoseTrackApp.
- SwiftData ModelContainer includes DoseLog schema.
- DoseLogController encapsulates CRUD and business rules.
- HealthKitManager wraps authorization and Final Wake queries.
- NightPlanRecommender produces precise doses and window. UI calls safe rounding only when showing or saving.
- CSVExporter renders header and rows with HH:mm using the stored offset.

## Models
- DoseLog with unique nightKey and UTC timestamps. timezoneOffsetMinutes stored per night.
- NightPlan returns precise grams and window bounds plus user facing rounded grams.
- AppGroupStore persists pending actions to UserDefaults in the shared suite.

## Views
- TodayLogView provides Now buttons for bedtime, Dose 1, Dose 2, bathroom wakes, Final Wake, and CSV export.
- Widget provider shows tonight plan and supports intents to queue logging actions.

## Data Flow
1. Widget intent writes a PendingAction JSON to the App Group suite.
2. App activation consumes pending actions and updates the current DoseLog, then schedules the Dose 2 reminder.
3. HealthKit fetch reads sleep segments after the night anchor and sets Final Wake if recent, with provenance AppleHealth.
4. CSV export iterates nights sorted by nightKey and writes HH:mm strings using the recorded offset.

## Validation
- Dose sequence and window guards must pass before save. Error messages use plain language.
- Unit tests cover ordering, CSV header and row, and 0.25 g rounding.
- Manual QA uses a 14 day internal pilot with at least 85 percent capture and completeness.

## Capabilities
- HealthKit read Sleep Analysis.
- App Groups group.com.jefferson.dosetrack.
- Local notifications for the Dose 2 window start reminder.

## Dependencies
- iOS: native frameworks only.
- Server: express and express rate limit. No persistence.

## Deployment
- Bundle IDs: com.jefferson.dosetrack and com.jefferson.dosetrack.widget.
- App Group: group.com.jefferson.dosetrack.
- WHOOP proxy runs on localhost during pilot with x-api-key.
