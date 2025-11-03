# MASTER CHECKLIST - DoseTrack v1.1.1c

Status legend:
- [ ] Not started
- [~] In progress
- [x] Done

## 1. Clinical safety
- [ ] Per dose grams clamped 1.5 to 4.5
- [ ] Total nightly grams clamped 3.0 to 9.0
- [ ] Dose 2 window 150 to 240 minutes enforced
- [ ] Internal math full precision Double
- [ ] Display and save rounding 0.25 g only
- [ ] Ordering guards: Dose 2 after Dose 1 and within window
- [ ] CSV HH:mm using captured timezone offset

## 2. Privacy and data
- [ ] No PHI leaves device
- [ ] SwiftData local store only
- [ ] HealthKit used read only for Sleep Analysis
- [ ] WHOOP proxy gated by API key and rate limited
- [ ] App Group used only between app and widget

## 3. iOS implementation
- [ ] SwiftData @Model DoseLog with nightKey unique
- [ ] All timestamps stored in UTC
- [ ] timezoneOffsetMinutes captured at log creation
- [ ] HealthKitManager authorization prompt text present in Info.plist
- [ ] TodayLogView shows plan and supports one tap logging
- [ ] Reminders schedule at window start after Dose 1
- [ ] CSV export produces one row per night
- [ ] Widget provider returns meaningful default with personal defaults
- [ ] App Intents queue pending actions to App Group
- [ ] App consumes pending actions on activation

## 4. Server proxy
- [ ] express and express-rate-limit configured
- [ ] GET /health returns 200 and json
- [ ] /api routes require x-api-key header
- [ ] WHOOP range endpoints use limit 25 with pagination nextToken
- [ ] /api/aggregates/7days returns averages and nights array
- [ ] No secrets in source control

## 5. Testing
- [ ] Unit test for sequence ordering guard
- [ ] Unit test for CSV header and HH:mm format
- [ ] Unit test for rounding to 0.25 g
- [ ] Manual smoke of widget intents write path
- [ ] Manual HealthKit autofill happy path and no data path

## 6. Documentation and specs
- [ ] PRD v1.2 stored in docs
- [ ] Spec Kit constitution created
- [ ] Spec Kit spec and plan created
- [ ] Spec Kit analyze run clean
- [ ] Safety and QA checklists copied into docs
