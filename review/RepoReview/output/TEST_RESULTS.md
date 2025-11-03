# Test Results

## iOS App

| # | Test | Result | Evidence | Notes |
|---|------|--------|----------|-------|
| 1 | Build compiles on Xcode 15.4 (`xcodebuild -scheme DoseTrack -destination 'platform=iOS Simulator,name=iPhone 15' build`) | ❌ Fail | `review/RepoReview/output/logs/ios_build.log` | iPhone 15 destination not available; building against the available iPhone 17 simulator succeeds, but it links the legacy `DoseTrackIOS` sources, not the new `ios/` module. |
| 2 | Dose 2 window gating logic | ⚪ Not Run | — | Requires functional UI with updated ViewModel; new module does not build, so gating requires manual validation once fixed. |
| 3 | Live Activity start/end | ⚪ Not Run | — | ActivityKit hooks are stubs (`ios/DoseLogController.swift:345-356`); cannot verify until implemented. |
| 4 | Event strip & undo timing | ⚪ Not Run | — | Needs working UI and event log; current implementation synthesises events and lacks coverage. |
| 5 | Reset Night safety flow | ⚪ Not Run | — | Reset sheet logic reviewed statically; full UX test blocked by build gaps. |

## Server

| # | Test | Result | Evidence | Notes |
|---|------|--------|----------|-------|
| 1 | `curl /health` | ✅ Pass | `review/RepoReview/output/logs/server_test.log` | Health check returns `200 OK`. |
| 2 | Auth middleware rejects missing key | ❌ Fail | `review/RepoReview/output/logs/server_test.log` | Endpoint returns `401` as designed, but the harness counts it as a failure; tests need to treat auth denials as expected or mock the WHOOP API. |
| 3 | Rate limiting (`100/min`) | ❌ Fail | `review/RepoReview/output/logs/server_test.log` | Requests terminate with `500` because `WHOOP_TOKEN` is unset; rate limit behaviour not exercised. Configure token or stub WHOOP before rerunning. |

## Database

| # | Test | Result | Evidence | Notes |
|---|------|--------|----------|-------|
| 1 | Per-dose constraints | ⚪ Not Run | — | App does not create the review schema tables/triggers; manual SQL audit required once schema alignment is addressed. |
| 2 | Nightly total guardrail | ⚪ Not Run | — | Same as above. |
| 3 | Dose 2 window trigger | ⚪ Not Run | — | Same as above. |
