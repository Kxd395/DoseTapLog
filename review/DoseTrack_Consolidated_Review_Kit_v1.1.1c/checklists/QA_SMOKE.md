# QA SMOKE - Server and iOS

## Server smoke
1. Environment
   - export API_KEY=your-local-dev-key
   - export WHOOP_TOKEN=not-set-for-smoke
2. Start
   - npm start
   - Expect: listening on 3000
3. Health
   - curl http://localhost:3000/health
   - Expect HTTP 200 and {"status":"ok"...}
4. Auth gate
   - curl http://localhost:3000/api/aggregates/7days
   - Expect HTTP 401
   - curl -H "x-api-key: $API_KEY" http://localhost:3000/api/aggregates/7days
   - Expect HTTP 200 or 500 aggregate_failed if token missing
5. Rate limit
   - loop more than 60 requests per minute, expect HTTP 429

## iOS smoke
1. First run
   - Launch app without settings
   - Expect first run sheet for bedtime and total grams
2. Logging
   - Tap Log Dose 1, confirm reminder scheduled at window start
   - Use widget to Log Dose 2, reopen, confirm consumed
3. HealthKit
   - Tap Auto-fill Wake, accept prompt
   - If sleep exists within tolerance, Final Wake fills with provenance AppleHealth
4. CSV
   - Export CSV and verify HH:mm, one row per night
