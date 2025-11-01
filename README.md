# DoseTrack v1.1.1c bundle

Local-first iOS app with widget and WHOOP proxy add-ons. Stores all data on device. CSV export for clinician use.

## What is included
- iOS app source
  - SwiftData model keyed by bedtime date
  - HealthKit sleep read for Final Wake autofill
  - Night plan recommender with full precision and late rounding
  - Widget with tonight plan
  - CSV export
- WHOOP proxy add-ons
  - Pagination helper
  - 7 day aggregates
  - Rate limit and API key gate
- PRD v1.2 and contents list

## iOS setup
1. Create Xcode project with bundle id com.jefferson.dosetrack
2. Add files from ios/ and ios/Widget/
3. Capabilities
   - HealthKit read: Sleep Analysis
   - App Groups: group.com.jefferson.dosetrack
   - Notifications: Alerts
4. Info.plist
   - NSHealthShareUsageDescription: Sleep data used to autofill final wake
5. Build and run on iPhone

## Server add-ons
- Integrate server/index.additions.js into your existing Express index.js
- Use .env.example to set API_KEY and WHOOP_TOKEN for local testing
- Keep server on localhost only during pilot

## Form values you may need
- Product name: DoseTrack
- App bundle ID: com.jefferson.dosetrack
- Widget bundle ID: com.jefferson.dosetrack.widget
- App Group ID: group.com.jefferson.dosetrack

## Rounding and time
- Internal calculations keep full precision
- 0.25 g rounding only for display and save
- All Date values stored in UTC with per night timezone offset recorded
