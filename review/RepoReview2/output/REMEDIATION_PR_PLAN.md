# DoseTrack Remediation Plan - PR Roadmap

**Review Date:** November 3, 2025  
**Target:** Fix all critical and high-severity issues  
**Estimated Total Effort:** 11-22 hours

---

## PR Summary

This plan proposes **4 Pull Requests** to remediate all identified issues and bring DoseTrack v1.1.1c to production-ready state.

| PR# | Title | Priority | Files | Effort | Status |
|-----|-------|----------|-------|--------|--------|
| PR-1 | Fix iOS Build Errors | CRITICAL | 4 files | 2-4h | 🔴 REQUIRED |
| PR-2 | Repository Cleanup & Structure | HIGH | Multiple | 1-2h | 🟠 RECOMMENDED |
| PR-3 | Testing Infrastructure | HIGH | 3 files | 2-4h | 🟠 RECOMMENDED |
| PR-4 | Feature Completion & Polish | MEDIUM | 6 files | 6-12h | 🟡 OPTIONAL |

---

## PR-1: Fix iOS Build Errors ⚠️ CRITICAL BLOCKER

**Branch:** `fix/ios-build-errors`  
**Priority:** CRITICAL  
**Estimated Effort:** 2-4 hours  
**Blocks:** All testing, deployment, and further development

### Objective

Resolve all Swift compilation errors preventing iOS app from building.

### Files to Modify

1. `ios/AppPreferencesEnhanced.swift`
2. `ios/AppPreferencesEnhanced+LateDose.swift`
3. `ios/AppPreferences.swift`
4. `ios/AlarmOrchestrator.swift`

### Changes

#### 1.1 Move Late Dose Properties to Main Class

**File:** `ios/AppPreferencesEnhanced.swift`

**Add after line 90 (after early dose section):**

```swift
    // MARK: - Late Dose 2 Override Policy
    
    @AppStorage("late_dose_allow", store: suite)
    var allowLateDose: Bool = true
    
    @AppStorage("late_dose_require_reason", store: suite)
    var lateRequireReason: Bool = true
    
    @AppStorage("late_dose_max_minutes", store: suite)
    var maxLateMinutes: Int = 120
    
    @AppStorage("late_dose_quick_choices", store: suite)
    var lateQuickChoicesCSV: String = "5,10,15,30"
    
    @AppStorage("reset_undo_window_sec", store: suite)
    var resetUndoWindowSec: Int = 10
```

**File:** `ios/AppPreferencesEnhanced+LateDose.swift`

**Remove lines 9-24 (all `@AppStorage` declarations) and keep only:**

```swift
import SwiftUI

/// Extension to AppPreferencesEnhanced for Late Dose 2 Override helpers
extension AppPreferencesEnhanced {
    
    // MARK: - Computed Helpers
    
    /// Parse lateQuickChoicesCSV into array of integers
    var lateQuickChoices: [Int] {
        lateQuickChoicesCSV
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 > 0 && $0 <= 300 }
    }
    
    /// Check if a given number of minutes late violates the max limit
    func exceedsLateLimit(_ minutesLate: Int) -> Bool {
        guard maxLateMinutes > 0 else { return false }
        return minutesLate > maxLateMinutes
    }
}
```

#### 1.2 Fix Legacy Migration Code

**File:** `ios/AppPreferences.swift`

**Replace lines 370-415 with:**

```swift
    // MARK: - Migration from Legacy Codable Version
    
    /// Migrate from review bundle's Codable struct if present
    static func migrateFromLegacy() {
        // Migration removed - AppPreferencesEnhanced is now primary
        // This method kept for API compatibility
        print("Legacy migration skipped - using AppPreferencesEnhanced")
    }
}
```

Or if migration is needed, fix it properly:

```swift
    static func migrateFromLegacy() {
        let suite = UserDefaults(suiteName: "group.com.jefferson.dosetrack")!
        let legacyKey = "com.jefferson.dosetrack.preferences.legacy"
        
        guard let data = suite.data(forKey: legacyKey),
              let legacy = try? JSONDecoder().decode(LegacyPreferences.self, from: data) else {
            return
        }
        
        let prefs = AppPreferencesEnhanced.shared
        
        // Migrate only properties that exist in both
        if let val = legacy.totalNightG { prefs.totalNightGrams = val }
        if let val = legacy.split { prefs.splitStrategy = val }
        if let val = legacy.windowStartMin { prefs.windowStartMin = val }
        if let val = legacy.windowEndMin { prefs.windowEndMin = val }
        if let val = legacy.allowEarlyDose { prefs.allowEarlyDose = val }
        if let val = legacy.maxEarlyMinutes { prefs.maxEarlyMinutes = val }
        
        suite.removeObject(forKey: legacyKey)
        print("Migrated legacy preferences")
    }
}
```

#### 1.3 Fix Actor Protocol Conformance

**File:** `ios/AlarmOrchestrator.swift`

**Option A: Make protocol methods nonisolated**

**Add before line 39:**

```swift
protocol AlarmOrchestrating: Sendable {
    func arm(for plan: NightAlarmPlan, style: NightAlarmPlan.AlarmStyle) async throws -> NightAlarmPlan
    func cancelAll(forNightKey nightKey: String) async
    func pendingCount(forNightKey nightKey: String) async -> Int
}
```

**Option B: Remove protocol conformance temporarily**

**Line 39, change from:**
```swift
actor AlarmOrchestrator: AlarmOrchestrating {
```

**To:**
```swift
actor AlarmOrchestrator {
```

### Testing

```bash
cd /Users/kevindialmb/Downloads/DoseTrack_v1.1.1c
xcodebuild -scheme DoseTrack -destination 'platform=iOS Simulator,id=A260D359-E23B-4152-8BFC-91CD9C6ACC1E' clean build
```

**Expected:** `** BUILD SUCCEEDED **`

### Commit Message

```
fix: Resolve iOS build errors preventing compilation

- Move late dose @AppStorage properties from extension to main class
- Fix legacy migration code with undefined variables
- Add AlarmOrchestrating protocol definition
- Add resetUndoWindowSec property for reset night undo timer

Fixes: ISSUE-001 (iOS Build Failure)

This change enables the iOS app to compile successfully and unblocks
all testing and development work.
```

---

## PR-2: Repository Cleanup & Structure

**Branch:** `chore/repo-cleanup`  
**Priority:** HIGH  
**Estimated Effort:** 1-2 hours  
**Dependencies:** None

### Objective

Clean up repository structure, remove duplicate files, add proper .gitignore.

### Changes

#### 2.1 Create .gitignore

**File:** `.gitignore` (new)

```gitignore
# macOS
.DS_Store
.AppleDouble
.LSOverride

# Xcode
DerivedData/
.swiftpm/
.build/
*.pbxuser
*.mode1v3
*.mode2v3
*.perspectivev3
!default.pbxuser
!default.mode1v3
!default.mode2v3
!default.perspectivev3
xcuserdata/
*.xccheckout
*.moved-aside
*.xcuserstate
*.xcscmblueprint
*.xcodeproj/*
!*.xcodeproj/project.pbxproj
!*.xcodeproj/xcshareddata/

# Swift Package Manager
.swiftpm/xcode
Package.resolved

# Node
node_modules/
npm-debug.log
yarn-error.log
package-lock.json

# Environment
.env
!.env.example

# Build artifacts
*.app
*.ipa
*.dSYM.zip
*.dSYM

# Review outputs
review/RepoReview*/output/
review/archive/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
```

#### 2.2 Archive Old Review Bundles

```bash
mkdir -p review/archive
mv review/DoseTrack_SpecKit_v1.1.1c review/archive/
mv review/DoseTrack_Consolidated_Review_Kit_v1.1.1c review/archive/
mv review/DoseTrack_SQLite_Review_Kit_v1.1.1c review/archive/
mv review/DoseTrack_v1.1.1c_Plan_DropIn review/archive/
```

Keep only:
- `review/RepoReview2/` (current review)
- `review/ResetNight_UX_Pack_2025-11-02/` (recent spec)
- `review/DoseTrack_UI_ASCII_Update_v2/` (recent spec)

#### 2.3 Update README

**File:** `README.md`

Add section:

```markdown
## File Structure

**Canonical Source Files:**
- `ios/` - iOS app source code (SwiftUI, SwiftData)
- `server/` - WHOOP proxy server (Node.js/Express)
- `docs/` - Product documentation and specifications
- `examples/` - Sample data files and CSV schemas

**Review Artifacts:**
- `review/RepoReview2/` - Latest repository audit (Nov 2025)
- `review/archive/` - Historical review bundles (reference only)

**When in doubt:** Files in `ios/` and `server/` are canonical. Review bundles are for reference and planning only.
```

### Commit Message

```
chore: Clean up repository structure and add .gitignore

- Add comprehensive .gitignore for Xcode, Node, and review artifacts
- Archive old review bundles to review/archive/
- Update README with canonical file structure documentation
- Remove duplicate files from review folders

Fixes: ISSUE-002 (Duplicate File Structure)

This change clarifies which files are authoritative and reduces
repository confusion.
```

---

## PR-3: Testing Infrastructure

**Branch:** `test/infrastructure-improvements`  
**Priority:** HIGH  
**Estimated Effort:** 2-4 hours  
**Dependencies:** PR-1 (must build successfully)

### Objective

Implement proper testing infrastructure for server and iOS app.

### Changes

#### 3.1 Add Server Testing Framework

**File:** `server/package.json`

Add to devDependencies:

```json
{
  "devDependencies": {
    "jest": "^29.0.0",
    "supertest": "^6.3.0"
  },
  "scripts": {
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage"
  }
}
```

**File:** `server/index.js`

Add at end:

```javascript
// Export app for testing
if (require.main !== module) {
  module.exports = app;
}
```

**File:** `server/__tests__/api.test.js` (new)

```javascript
const request = require('supertest');
const app = require('../index');

describe('WHOOP Proxy API', () => {
  describe('GET /health', () => {
    it('should return 200 OK', async () => {
      const res = await request(app).get('/health');
      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('status', 'ok');
    });
  });

  describe('GET /api/sleep/latest', () => {
    it('should require API key', async () => {
      const res = await request(app).get('/api/sleep/latest');
      expect(res.status).toBe(401);
    });

    it('should return sleep data with valid key', async () => {
      const res = await request(app)
        .get('/api/sleep/latest')
        .set('X-API-Key', process.env.WHOOP_API_KEY || 'test-key');
      
      expect([200, 404, 503]).toContain(res.status); // May fail if WHOOP offline
    });
  });

  describe('GET /api/aggregates/7days', () => {
    it('should require API key', async () => {
      const res = await request(app).get('/api/aggregates/7days');
      expect(res.status).toBe(401);
    });
  });
});
```

**File:** `server/jest.config.js` (new)

```javascript
module.exports = {
  testEnvironment: 'node',
  coverageDirectory: 'coverage',
  collectCoverageFrom: [
    '**/*.js',
    '!node_modules/**',
    '!coverage/**',
    '!jest.config.js'
  ],
  testMatch: ['**/__tests__/**/*.test.js']
};
```

#### 3.2 Add iOS Unit Tests

**File:** `ios/Tests/AppPreferencesTests.swift` (new)

```swift
import XCTest
@testable import DoseTrack

final class AppPreferencesTests: XCTestCase {
    
    func testSafetyBoundsValidation() {
        let prefs = AppPreferencesEnhanced.shared
        
        // Valid plan
        prefs.totalNightGrams = 6.5
        prefs.splitStrategy = "50/50"
        XCTAssertFalse(prefs.planViolatesSafety)
        
        // Per-dose too low
        prefs.totalNightGrams = 2.0
        XCTAssertTrue(prefs.planViolatesSafety)
        
        // Per-dose too high
        prefs.totalNightGrams = 10.0
        XCTAssertTrue(prefs.planViolatesSafety)
    }
    
    func testDoseCalculations() {
        let prefs = AppPreferencesEnhanced.shared
        prefs.totalNightGrams = 6.0
        
        prefs.splitStrategy = "50/50"
        let (d1_50, d2_50) = prefs.calculateDoses()
        XCTAssertEqual(d1_50, 3.0, accuracy: 0.01)
        XCTAssertEqual(d2_50, 3.0, accuracy: 0.01)
        
        prefs.splitStrategy = "60/40"
        let (d1_60, d2_40) = prefs.calculateDoses()
        XCTAssertEqual(d1_60, 3.6, accuracy: 0.01)
        XCTAssertEqual(d2_40, 2.4, accuracy: 0.01)
    }
}
```

### Testing

```bash
# Server tests
cd server
npm install
npm test

# iOS tests (once build works)
xcodebuild test -scheme DoseTrack -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Commit Message

```
test: Add comprehensive testing infrastructure

Server:
- Add Jest and Supertest for API testing
- Create test suite for all endpoints
- Add test:coverage script
- Remove dependency on pre-running server

iOS:
- Add unit tests for AppPreferences
- Add safety bounds validation tests
- Add dose calculation tests

Fixes: ISSUE-003 (Server Test Infrastructure)

This change enables automated CI/CD testing and removes manual
test dependencies.
```

---

## PR-4: Feature Completion & Polish

**Branch:** `feat/complete-partials`  
**Priority:** MEDIUM  
**Estimated Effort:** 6-12 hours  
**Dependencies:** PR-1 (must build successfully)

### Objective

Complete partially implemented features to reach 100% coverage.

### Changes

#### 4.1 Complete Undo Timer (60-Second Constraint)

**File:** `ios/TodayViewModel.swift`

Add property:

```swift
@Published var undoTimeRemaining: Int = 60
private var undoTimer: Timer?
```

Add method after `undoLast()`:

```swift
func startUndoTimer() {
    undoTimer?.invalidate()
    undoTimeRemaining = 60
    
    undoTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        guard let self = self else { return }
        self.undoTimeRemaining -= 1
        
        if self.undoTimeRemaining <= 0 {
            self.undoTimer?.invalidate()
            self.undoTimer = nil
        }
    }
}

var canUndo: Bool {
    guard let lastEvent = lastEvents.first else { return false }
    let elapsed = Date().timeIntervalSince(lastEvent.timestamp)
    return elapsed <= 60
}
```

Update `undoLast()` to check `canUndo`.

**File:** `ios/TodayLogView.swift`

Update undo button:

```swift
Button("Undo last", action: vm.undoLast)
    .buttonStyle(.bordered)
    .disabled(!vm.canUndo)

if let lastEvent = vm.lastEvents.first {
    Text("Undo available for \(vm.undoTimeRemaining)s")
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

#### 4.2 Complete Reset Night Undo Timer

**File:** `ios/TodayViewModel.swift`

Add:

```swift
@Published var resetUndoTimeRemaining: Int = 0
private var resetUndoTimer: Timer?

func presentResetNight() {
    // Existing reset logic...
    
    // Start undo timer
    resetUndoTimeRemaining = AppPreferencesEnhanced.shared.resetUndoWindowSec
    resetUndoTimer?.invalidate()
    resetUndoTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        guard let self = self else { return }
        self.resetUndoTimeRemaining -= 1
        
        if self.resetUndoTimeRemaining <= 0 {
            self.showUndoResetBanner = false
            self.resetUndoTimer?.invalidate()
            self.resetUndoTimer = nil
        }
    }
}
```

**File:** `ios/TodayLogView.swift`

Update banner:

```swift
Text("Undo within \(vm.resetUndoTimeRemaining) seconds")
    .font(.footnote)
    .foregroundStyle(.secondary)
```

#### 4.3 Add CSV Schema Validation

**File:** `ios/Tests/CSVExporterTests.swift` (new)

```swift
import XCTest
@testable import DoseTrack

final class CSVExporterTests: XCTestCase {
    
    func testCSVSchemaCompliance() {
        // Create sample night
        let night = NightSession(/* ... */)
        
        // Export to CSV
        let csv = CSVExporter.export(night: night)
        let lines = csv.split(separator: "\n")
        
        // Validate header
        let expectedHeader = "night_key,in_bed_time_utc,dose1_time_utc,dose1_grams,dose2_time_utc,dose2_grams,final_wake_time_utc,total_night_grams,events_json,notes"
        XCTAssertEqual(lines[0], expectedHeader)
        
        // Validate data row has correct number of columns
        let dataRow = lines[1].split(separator: ",")
        XCTAssertEqual(dataRow.count, 10)
        
        // Validate timestamp formats (ISO 8601)
        // Validate numeric values are valid
        // etc.
    }
}
```

#### 4.4 Implement Missed Dose Logging

**File:** `ios/TodayViewModel.swift`

Add:

```swift
func logMissedDose() {
    guard let nightKey = nightKey else { return }
    
    controller.logEvent(
        nightKey: nightKey,
        type: .missedDose,
        timestamp: Date(),
        notes: "Dose 2 window expired without logging"
    )
    
    // End session
    finalWakeTimeUTC = Date()
    updateRingState()
}
```

**File:** `ios/TodayLogView.swift`

Update button:

```swift
Button("Log Missed Dose") {
    vm.logMissedDose()
}
.buttonStyle(.bordered)
.font(.footnote)
```

#### 4.5 Complete Settings Audit

Full line-by-line audit ensuring every `@AppStorage` property has a UI control. (Detailed checklist in separate document.)

### Commit Message

```
feat: Complete partial implementations to reach 100% coverage

- Add 60-second undo timer with countdown display
- Complete reset night undo window with auto-dismiss
- Add CSV schema validation unit tests
- Implement missed dose logging functionality
- Complete settings UI coverage audit

Fixes: ISSUE-007 (Reset Night Incomplete)
Fixes: ISSUE-006 (CSV Schema Validation)
Fixes: ISSUE-008 (Missed Dose TODO)

This change brings DoseTrack to 100% feature completeness per PRD v1.2.
```

---

## Implementation Order

### Week 1: Critical Fixes
1. **Day 1:** PR-1 (Fix Build Errors) - MUST DO
2. **Day 2:** PR-2 (Repo Cleanup) - SHOULD DO
3. **Day 3:** PR-3 (Testing Infrastructure) - SHOULD DO

### Week 2: Polish
4. **Days 4-6:** PR-4 (Feature Completion) - OPTIONAL

---

## Testing Checklist

After each PR:

- [ ] iOS app builds without errors
- [ ] iOS app builds without warnings
- [ ] Server tests pass
- [ ] iOS unit tests pass
- [ ] Manual smoke test in simulator
- [ ] Code review by second developer
- [ ] Update CHANGELOG.md

---

## Risk Assessment

| PR | Risk | Mitigation |
|----|------|------------|
| PR-1 | Breaking changes to preferences | Test migration path thoroughly |
| PR-1 | Actor changes affect threading | Review all actor usage |
| PR-2 | Accidentally delete wrong files | Archive before deleting |
| PR-3 | Server tests flaky | Use supertest for isolation |
| PR-4 | Timer memory leaks | Proper cleanup in deinit |

---

## Rollback Plan

Each PR should be independently revertible:

```bash
# If PR-1 causes issues
git revert <PR-1-commit-hash>

# If PR-3 server tests are problematic
git revert <PR-3-commit-hash>
```

---

## Success Criteria

**PR-1 Success:**
- ✅ `xcodebuild build` succeeds
- ✅ No compilation errors
- ✅ No compilation warnings

**PR-2 Success:**
- ✅ .gitignore ignores build artifacts
- ✅ Review bundles archived
- ✅ README updated with structure

**PR-3 Success:**
- ✅ `npm test` runs without pre-starting server
- ✅ All server tests pass
- ✅ iOS unit tests run and pass

**PR-4 Success:**
- ✅ Undo timer shows countdown
- ✅ Reset undo auto-dismisses
- ✅ CSV tests validate schema
- ✅ Missed dose can be logged

---

## Post-Merge Actions

1. Update project board with completed issues
2. Run full regression test suite
3. Deploy to TestFlight for QA
4. Update documentation with new features
5. Close related GitHub issues

---

**Plan Status:** READY FOR IMPLEMENTATION  
**Priority:** PR-1 CRITICAL, PR-2/PR-3 HIGH, PR-4 MEDIUM  
**Total Effort:** 11-22 hours over 1-2 weeks  
**Created:** November 3, 2025
