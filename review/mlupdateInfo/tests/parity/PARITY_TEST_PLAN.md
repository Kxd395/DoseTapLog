# Service-Day Parity Test Plan (Swift ↔ JS)

## Goal
Prove the Swift `ServiceDayMaxOverlap` algorithm matches the Node.js `serviceDayMaxOverlap.js` implementation across diverse edge cases.

## Cases (min 100)
- Randomized timestamps across multiple timezones
- Cutoff hours in [8, 12, 16]
- DST transitions (spring forward / fall back)
- Cross-midnight sleeps with varying overlaps
- Naps (<2h daytime)
- Travel nights (tz change within 24h)

## Artifacts
- `parity_100_cases.json` — generated inputs/expected keys
- `parity_report.md` — pass/fail summary with any diffs

## Commands (examples)
- Swift: `xcodebuild test -scheme DoseTrackNew -only-testing:ServiceDayMaxOverlapTests`
- Node: `node src/tests/run_parity.js --cases parity_100_cases.json --out parity_report.md`
