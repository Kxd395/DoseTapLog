# DoseTrack Testing Guide

**Last Updated:** November 1, 2025  
**Project:** DoseTrack v1.1.1c

---

## Overview

This guide covers testing for both the **iOS app** and the **WHOOP proxy server** components of DoseTrack.

---

## Prerequisites

### For iOS App Testing

- ✅ **macOS** (Big Sur or later)
- ❌ **Xcode 15.0+** (NOT CURRENTLY INSTALLED - see setup below)
- ✅ **iOS 16.0+ simulator** or physical device
- ✅ **Swift 5.9+**

### For Server Testing

- ✅ **Node.js 18+** (v22.16.0 detected)
- ✅ **npm 10+** (v10.9.2 detected)
- ✅ **WHOOP account** (optional, for real API testing)

---

## Server Testing (Available Now)

### Quick Start

```bash
# 1. Navigate to server directory
cd server

# 2. Install dependencies (already done)
npm install

# 3. Configure environment
cp .env.example .env
# Edit .env and set:
# - API_KEY=your-strong-random-key
# - WHOOP_TOKEN=your-whoop-bearer-token (optional)

# 4. Start server
npm start
```

### Running Tests

**Option 1: Automated Test Suite**

In a new terminal (while server is running):

```bash
cd server
node test-server.js
```

**Option 2: Manual Testing with curl**

```bash
# Health check (no auth required)
curl http://localhost:3000/health

# Latest sleep (requires API key)
curl -H "x-api-key: test-api-key-local-dev-only" \
     http://localhost:3000/api/sleep/latest

# 7-day aggregates (requires API key)
curl -H "x-api-key: test-api-key-local-dev-only" \
     http://localhost:3000/api/aggregates/7days

# Test rate limiting (make 65 requests rapidly)
for i in {1..65}; do
  curl -H "x-api-key: test-api-key-local-dev-only" \
       http://localhost:3000/health
done
```

### Expected Responses

#### Health Check
```json
{
  "status": "ok",
  "timestamp": "2025-11-01T...",
  "service": "dosetrack-whoop-proxy",
  "version": "1.0.0"
}
```

#### Latest Sleep (without WHOOP_TOKEN)
```json
{
  "error": "fetch_failed",
  "detail": "WHOOP_TOKEN not configured"
}
```

#### 401 Unauthorized (wrong API key)
```json
{
  "error": "unauthorized",
  "detail": "Invalid or missing x-api-key header"
}
```

#### 429 Rate Limit Exceeded
```json
{
  "error": "rate_limit_exceeded"
}
```

---

## Server Test Results

### ✅ Tests Completed Successfully

1. **Package Installation** - All dependencies installed without vulnerabilities
2. **Server Startup** - Server runs on http://localhost:3000
3. **Health Check** - Responds with 200 OK
4. **Rate Limiting** - Configured for 60 req/min
5. **API Key Authentication** - Middleware working
6. **Environment Configuration** - .env file loaded

### ⚠️ Tests Requiring WHOOP Token

The following tests require a valid WHOOP_TOKEN in .env:

- `/api/sleep/latest` - Fetch most recent sleep record
- `/api/aggregates/7days` - Calculate 7-day sleep averages

**To enable:** Sign up for WHOOP API access at https://developer.whoop.com

---

## iOS App Testing (Requires Xcode)

### Xcode Setup

Since Xcode is not currently installed, you'll need to:

1. **Install Xcode from App Store** (or download from developer.apple.com)
2. **Accept license**: `sudo xcodebuild -license accept`
3. **Install additional components** when prompted

### Create Xcode Project

```bash
# 1. Open Xcode
# 2. Create New Project
# 3. Select "iOS App"
# 4. Configuration:
#    - Product Name: DoseTrack
#    - Team: Your Apple Developer account
#    - Organization ID: com.jefferson
#    - Bundle ID: com.jefferson.dosetrack
#    - Interface: SwiftUI
#    - Language: Swift
#    - Storage: SwiftData
```

### Add Source Files

```bash
# Copy all Swift files from ios/ directory:
ios/Models.swift
ios/DoseTrackApp.swift
ios/TodayLogView.swift
ios/DoseLogController.swift
ios/HealthKitManager.swift
ios/NightPlanRecommender.swift
ios/CSVExporter.swift
ios/Config.swift
ios/Date+UTC.swift
ios/Rounding+Display.swift
ios/AppGroupStore.swift
ios/AppIntents+DoseLog.swift

# Widget files:
ios/Widget/DoseWidgetProvider.swift
```

### Configure Capabilities

In Xcode project settings → Signing & Capabilities:

1. **HealthKit**
   - Add capability
   - Enable: Read Sleep Analysis

2. **App Groups**
   - Add capability
   - Create group: `group.com.jefferson.dosetrack`

3. **Push Notifications**
   - Add capability (for Dose 2 reminders)

### Configure Info.plist

Add required keys:

```xml
<key>NSHealthShareUsageDescription</key>
<string>Sleep data is used to automatically fill your final wake time</string>
```

### Add Widget Extension

```bash
# 1. File → New → Target → Widget Extension
# 2. Product Name: DoseTrackWidget
# 3. Bundle ID: com.jefferson.dosetrack.widget
# 4. Add DoseWidgetProvider.swift to the widget target
```

### Run Unit Tests

```bash
# In Xcode:
# 1. Add DoseLogTests.swift to test target
# 2. Product → Test (Cmd+U)

# Or via command line:
xcodebuild test \
  -scheme DoseTrack \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Expected Test Coverage

The `DoseLogTests.swift` should validate:

- ✅ Dose ordering (dose2 > dose1)
- ✅ Window validation (150-240 minutes)
- ✅ CSV formatting with timezone offsets
- ✅ Display rounding to 0.25g increments
- ✅ Guardrail clamping (1.5-4.5g per dose)
- ✅ Night plan recommender calculations

---

## Swift Code Validation (Without Xcode)

You can validate Swift syntax using swiftc:

```bash
# Check if Swift compiler is available
swift --version

# Validate a Swift file
swiftc -typecheck ios/Models.swift

# Validate all Swift files
find ios -name "*.swift" -exec swiftc -typecheck {} \;
```

**Note:** This only checks syntax, not full compilation with frameworks.

---

## Integration Testing

### Manual Testing Flow

Once Xcode project is set up:

1. **First Launch**
   - App should show onboarding
   - Request HealthKit permissions
   - Collect bedtime and total nightly grams

2. **Log Dose 1**
   - Tap "Log Dose 1" button
   - Verify timestamp recorded
   - Verify grams auto-populated from recommendation
   - Check that Dose 2 reminder scheduled

3. **Log Dose 2**
   - Wait 150+ minutes or manually tap "Log Dose 2"
   - Verify timing validation (should be 150-240 min window)
   - Try logging before 150 min → should show error

4. **Auto-fill Final Wake**
   - Tap "Auto-fill Wake" button
   - If HealthKit has sleep data → should populate
   - Check provenance = "AppleHealth"

5. **CSV Export**
   - Tap export button
   - Verify HH:mm times with correct timezone
   - Verify nightKey matches bedtime date

6. **Widget Testing**
   - Add widget to home screen
   - Verify tonight's plan displays
   - Tap dose buttons from widget
   - Return to app → verify doses logged

### Automated UI Tests

Create XCUITests for critical flows:

```swift
func testDoseLoggingFlow() {
    let app = XCUIApplication()
    app.launch()
    
    // Complete onboarding
    app.buttons["Get Started"].tap()
    
    // Log Dose 1
    app.buttons["Log Dose 1"].tap()
    XCTAssertTrue(app.staticTexts["Dose 1 Logged"].exists)
    
    // Attempt Dose 2 too early (should fail)
    app.buttons["Log Dose 2"].tap()
    XCTAssertTrue(app.alerts["Window Violation"].exists)
}
```

---

## Test Environments

### Development
- **iOS Simulator**: iPhone 15, iOS 17.0+
- **Server**: localhost:3000
- **HealthKit**: Simulated data
- **WHOOP**: Mock responses (no token)

### Staging
- **TestFlight**: Internal testers
- **Server**: localhost:3000 (not exposed)
- **HealthKit**: Real user data
- **WHOOP**: Real API with token

### Production
- **App Store**: Public release
- **Server**: Not included (local-first design)
- **HealthKit**: Real user data
- **WHOOP**: User's own API token

---

## Pilot Testing (14-Day Validation)

### Recruitment
- 5-10 internal testers
- Must be Xywav patients or simulate dosing

### Data Collection
1. **Daily**: Log at least one dose
2. **Weekly**: Export CSV and share
3. **End of pilot**: Complete survey

### Success Criteria

| Metric | Target | Measurement |
|--------|--------|-------------|
| Capture rate | 90% | Nights with ≥1 dose / 14 |
| Completeness | 85% | Nights with final wake / total |
| Autofill rate | 60% | Provenance="AppleHealth" / total |
| CSV acceptance | 80% | Clinician feedback survey |

### Pilot Checklist

- [ ] Recruit 5-10 testers
- [ ] Distribute via TestFlight
- [ ] Provide testing instructions
- [ ] Collect daily logs
- [ ] Weekly CSV exports
- [ ] Survey at end
- [ ] Analyze metrics
- [ ] Gather clinician feedback
- [ ] Document bugs and enhancement requests

---

## Known Limitations

### Current State

1. **No Xcode project file** - Must be created manually per README
2. **WHOOP_TOKEN not configured** - Server will fail API calls without it
3. **Unit tests exist but not runnable** - Requires Xcode project setup
4. **No CI/CD** - Manual testing only
5. **No analytics** - Success metrics not automatically tracked

### Future Improvements

1. **Pre-configured Xcode project** - Commit .xcodeproj to repo
2. **Mock WHOOP API** - Test server without real token
3. **GitHub Actions** - Automated CI for Swift tests
4. **Local analytics** - Track capture rate, completeness automatically
5. **Snapshot tests** - UI regression testing

---

## Troubleshooting

### Server Issues

**"API_KEY not configured"**
```bash
# Edit server/.env and set:
API_KEY=your-strong-random-key-here
```

**"WHOOP API error: 401"**
```bash
# Check that WHOOP_TOKEN is valid:
curl -H "Authorization: Bearer $WHOOP_TOKEN" \
     https://api.prod.whoop.com/developer/v1/user/profile/basic
```

**"Rate limit exceeded"**
```bash
# Wait 60 seconds or restart server to reset counter
```

### iOS App Issues

**"Xcode not found"**
```bash
# Install Xcode from App Store, then:
sudo xcode-select --switch /Applications/Xcode.app
```

**"HealthKit not available"**
```bash
# HealthKit only works on physical devices, not all simulators
# Use iPhone simulator (not iPad) and iOS 16.0+
```

**"Widget not updating"**
```bash
# Delete and re-add widget to home screen
# Verify App Group ID matches in both targets
```

---

## Test Artifacts

### Generated During Testing

- `server/node_modules/` - Dependencies (gitignored)
- `server/.env` - Local config (gitignored)
- `DerivedData/` - Xcode build cache (auto-generated)
- `*.csv` - Exported logs for validation

### Test Reports

After testing, create:
- `test-results-server.md` - Server endpoint results
- `test-results-ios.md` - Unit test results
- `pilot-report.md` - 14-day pilot findings
- `bugs.md` - Issues discovered during testing

---

## Next Steps

### Immediate (Today)

1. ✅ Server dependencies installed
2. ✅ Server code created and tested
3. ⏭️ Install Xcode (if needed for iOS testing)
4. ⏭️ Create Xcode project
5. ⏭️ Run unit tests

### Short-term (This Week)

1. Configure HealthKit permissions
2. Set up widget extension
3. Run manual testing flows
4. Document any bugs
5. Validate CSV export format

### Medium-term (Next 2 Weeks)

1. Recruit pilot testers
2. Distribute via TestFlight
3. Collect 14 days of data
4. Analyze success metrics
5. Gather clinician feedback

---

## Summary

**✅ Server Testing: READY**
- Dependencies installed
- Server code created
- Basic functionality verified
- Health check passing
- Rate limiting configured
- API key authentication working

**⏭️ iOS Testing: REQUIRES XCODE**
- Swift files ready
- Test files exist
- Xcode project needs creation
- Capabilities need configuration
- Unit tests ready to run

**📊 Status: 50% Complete**
- Backend ready for testing
- Frontend requires Xcode setup
- Documentation complete
- Pilot plan defined

---

**For immediate testing:** Use the server test suite  
**For full app testing:** Follow Xcode setup instructions above  
**For pilot validation:** Use 14-day testing protocol
