# DoseTrack Repository Issues

**Review Date:** November 3, 2025  
**Reviewed By:** CodeX AI Agent  
**Repository:** DoseTrack v1.1.1c

---

## Critical Issues

### ISSUE-001: iOS Build Failure - Multiple Compilation Errors

**Severity:** CRITICAL  
**Component:** iOS App  
**Files Affected:**
- `ios/AlarmOrchestrator.swift`
- `ios/AppPreferences.swift`
- `ios/AppPreferencesEnhanced+LateDose.swift`

**Description:**  
The iOS app fails to compile with multiple Swift errors preventing build success.

**Errors Found:**

1. **AlarmOrchestrator.swift:39** - Actor conformance to protocol crosses into actor-isolated code
   ```
   error: conformance of 'AlarmOrchestrator' to protocol 'AlarmOrchestrating' crosses into actor-isolated code and can cause data races
   actor AlarmOrchestrator: AlarmOrchestrating {
   ```

2. **AppPreferences.swift:380-412** - Undefined variables in legacy migration code
   ```
   error: cannot find 'suite' in scope
   error: cannot find 'legacyKey' in scope
   error: value of type 'AppPreferences' has no member 'roundingStepG'
   error: value of type 'AppPreferences' has no member 'requireEarlyReason'
   ```

3. **AppPreferencesEnhanced+LateDose.swift:11,15,19,23** - Stored properties in extension
   ```
   error: extensions must not contain stored properties
   var allowLateDose: Bool = true
   var lateRequireReason: Bool = true
   var maxLateMinutes: Int = 120
   var lateQuickChoicesCSV: String = "5,10,15,30"
   ```

4. **SwiftMacro synthesis error** - Invalid redeclaration of synthesized property
   ```
   error: invalid redeclaration of synthesized property '_totalNightGrams'
   ```

**Impact:**  
- iOS app cannot be built or run
- Complete blocker for testing and deployment
- Prevents validation of UI wiring and functionality

**Root Cause:**  
1. Late dose properties incorrectly placed in extension file instead of main class
2. Legacy migration code references non-existent variables
3. Actor isolation not properly handled in protocol conformance

**Reproduction Steps:**
```bash
cd /Users/kevindialmb/Downloads/DoseTrack_v1.1.1c
xcodebuild -scheme DoseTrack -destination 'platform=iOS Simulator,id=A260D359-E23B-4152-8BFC-91CD9C6ACC1E' clean build
```

**Expected:** Clean build with no errors  
**Actual:** Build fails with 15+ compilation errors

**Fix Proposal:**

1. **Move late dose properties from extension to main class**
   - Move all `@AppStorage` properties from `AppPreferencesEnhanced+LateDose.swift` into `AppPreferencesEnhanced.swift`
   - Keep only computed properties and helper methods in the extension

2. **Fix legacy migration code in AppPreferences.swift**
   - Add missing parameter to `migrateFromLegacy()` function
   - Remove or fix references to non-existent properties (`roundingStepG`, `requireEarlyReason`)
   - Define `suite` and `legacyKey` variables

3. **Fix AlarmOrchestrator actor conformance**
   - Mark protocol methods as `nonisolated` where appropriate
   - Or restructure to avoid actor-isolated conformance issues

**Files to Modify:**
- `ios/AppPreferencesEnhanced.swift` (add late dose properties)
- `ios/AppPreferencesEnhanced+LateDose.swift` (remove stored properties)
- `ios/AppPreferences.swift` (fix migration code)
- `ios/AlarmOrchestrator.swift` (fix actor isolation)

---

### ISSUE-002: Duplicate File Structure in Review Folders

**Severity:** HIGH  
**Component:** Project Structure  
**Files Affected:** Multiple files in `review/` subdirectories

**Description:**  
The `review/` directory contains multiple copies of iOS files, server files, and documentation, creating ambiguity about which version is canonical.

**Evidence:**  
Found 134 Swift files across the project, with duplicates in:
- `review/ResetNight_UX_Pack_2025-11-02/ios/`
- `review/DoseTrack_v1.1.1c_Plan_DropIn/ios/`
- `review/DoseTrack_SpecPatch_v1.2_PhaseA/ios/`
- `review/DoseTrack_SpecKit_v1.1.1c/DoseTrack_Agent_Review_Kit_v1.1.1c/ios/`

**Impact:**  
- Confusion about which files are authoritative
- Risk of editing wrong version
- Increased repository size
- Drift between review bundles and actual implementation

**Fix Proposal:**  
1. Archive review bundles that have been integrated
2. Document which files in `ios/` are canonical
3. Add `.gitignore` rules to prevent review bundle duplication
4. Create `review/archive/` for old review kits

---

## High Severity Issues

### ISSUE-003: Server Tests Cannot Run Without Running Server

**Severity:** HIGH  
**Component:** Server Testing  
**File:** `server/test-server.js`

**Description:**  
The test script requires the server to be running, making automated testing difficult.

**Evidence:**
```
❌ Server is not running at http://localhost:3000
Please start the server first:
   cd server
   npm start
Then run this test script again.
```

**Impact:**  
- Cannot run automated CI/CD tests
- Manual test process is error-prone
- Blocks integration testing

**Fix Proposal:**  
1. Refactor tests to use supertest or similar library that doesn't require running server
2. Or make test script start/stop server automatically
3. Add proper test framework (Jest, Mocha) with beforeAll/afterAll hooks

**Example Fix:**
```javascript
const request = require('supertest');
const app = require('./index'); // Export app from index.js

describe('WHOOP Proxy API', () => {
  it('should respond to /health', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
  });
});
```

---

### ISSUE-004: Missing Protocol Definition for AlarmOrchestrating

**Severity:** HIGH  
**Component:** iOS - Alarm System  
**File:** `ios/AlarmOrchestrator.swift`

**Description:**  
The protocol `AlarmOrchestrating` is referenced but not defined in the codebase.

**Impact:**  
- Build errors
- Cannot create mock objects for testing
- Unclear interface contract

**Fix Proposal:**  
Define the protocol before the actor:

```swift
protocol AlarmOrchestrating {
    func arm(for plan: NightAlarmPlan, style: NightAlarmPlan.AlarmStyle) async throws -> NightAlarmPlan
    func cancelAll(forNightKey nightKey: String) async
    func pendingCount(forNightKey nightKey: String) async -> Int
    // Add other required methods
}
```

---

## Medium Severity Issues

### ISSUE-005: AppPreferences Has Two Implementations

**Severity:** MEDIUM  
**Component:** iOS - Preferences  
**Files:** `ios/AppPreferences.swift`, `ios/AppPreferencesEnhanced.swift`

**Description:**  
There are two separate preference classes with overlapping functionality.

**Evidence:**
- `AppPreferences.swift` - Legacy `@Observable` implementation with 30+ properties
- `AppPreferencesEnhanced.swift` - New `@Observable` implementation using App Group

**Impact:**  
- Confusion about which to use
- Potential for state inconsistency
- Duplicate code maintenance

**Fix Proposal:**  
1. Deprecate `AppPreferences.swift` with migration path
2. Update all references to use `AppPreferencesEnhanced`
3. Or clearly document that AppPreferences is for single-app, AppPreferencesEnhanced is for app+widget

---

### ISSUE-006: Incomplete CSV Schema Validation

**Severity:** MEDIUM  
**Component:** iOS - CSV Export  
**File:** `ios/CSVExporter.swift`

**Description:**  
The CSV export functionality exists but there's no validation against the schema defined in `examples/examples_sample_dosing.csv`.

**Fix Proposal:**  
1. Add unit tests that validate CSV output matches schema
2. Create schema validation helper function
3. Document CSV column order and format in code comments

---

### ISSUE-007: Reset Night Feature Incomplete

**Severity:** MEDIUM  
**Component:** iOS - Reset Night  
**Files:** `ios/ResetNightSheet.swift`, `ios/TodayViewModel.swift`

**Description:**  
Reset Night feature is implemented but undo functionality may not be fully wired.

**Evidence from TodayLogView.swift:162-179:**
```swift
// Undo Reset Banner (shows after soft reset)
if vm.showUndoResetBanner {
    HStack {
        VStack(alignment: .leading, spacing: 4) {
            Text("Night Reset").font(.headline).bold()
            Text("Undo within \(AppPreferencesEnhanced.shared.resetUndoWindowSec) seconds")
        }
        Button("Undo") {
            vm.undoResetNight()
        }
    }
}
```

**Missing:**  
- `resetUndoWindowSec` property not found in AppPreferencesEnhanced
- Timer mechanism to auto-dismiss undo banner

**Fix Proposal:**  
1. Add `resetUndoWindowSec` to AppPreferencesEnhanced
2. Implement timer in TodayViewModel to track undo window
3. Add tests for reset/undo flow

---

## Low Severity Issues

### ISSUE-008: TODO Comment in Window Expired Logic

**Severity:** LOW  
**Component:** iOS - UI  
**File:** `ios/TodayLogView.swift:67`

**Description:**  
Placeholder TODO for missed dose logging functionality.

**Evidence:**
```swift
Button("Log Missed Dose") {
    // TODO: Implement missed dose logging
}
```

**Fix Proposal:**  
Implement missed dose logging or remove button if not in scope for v1.1.1c.

---

### ISSUE-009: Hardcoded Safety Limits Not Configurable

**Severity:** LOW  
**Component:** iOS - Safety  
**File:** `ios/AppPreferences.swift:357-365`

**Description:**  
Safety limits are hardcoded in `planViolatesSafety` computed property.

```swift
let perDoseMin = 1.5
let perDoseMax = 4.5
let nightlyMin = 3.0
let nightlyMax = 9.0
```

**Recommendation:**  
Extract to constants or make configurable (if clinical guidance allows).

---

### ISSUE-010: No .gitignore for Build Artifacts

**Severity:** LOW  
**Component:** Project Structure

**Description:**  
No evidence of `.gitignore` rules for Xcode build artifacts, DerivedData, or node_modules.

**Fix Proposal:**  
Add comprehensive `.gitignore`:
```
# Xcode
.DS_Store
DerivedData/
*.xcworkspace
!default.xcworkspace
.swiftpm/
.build/
*.pbxuser
*.mode1v3
*.mode2v3
*.perspectivev3

# Node
node_modules/
npm-debug.log

# Environment
.env
!.env.example

# Reviews
review/RepoReview*/output/
```

---

## Summary

| Severity | Count | Blocking Build |
|----------|-------|----------------|
| Critical | 2     | Yes            |
| High     | 3     | Partial        |
| Medium   | 4     | No             |
| Low      | 3     | No             |
| **Total**| **12**| **1**          |

**Next Steps:**
1. Fix ISSUE-001 (build errors) - CRITICAL BLOCKER
2. Clean up duplicate review files (ISSUE-002)
3. Fix server test infrastructure (ISSUE-003)
4. Address actor protocol issues (ISSUE-004)
5. Consolidate preference implementations (ISSUE-005)

---

**Log Entry:** All issues catalogued with file paths, line numbers, reproduction steps, and fix proposals. See `REMEDIATION_PR_PLAN.md` for implementation roadmap.
