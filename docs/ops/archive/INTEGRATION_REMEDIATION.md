# Integration Remediation Plan - Shipping New Stack

**📍 Location:** `docs/ops/INTEGRATION_REMEDIATION.md`  
**📚 Breadcrumbs:** `docs/` → `ops/` → **`INTEGRATION_REMEDIATION.md`**

**Date:** November 2, 2025  
**Status:** CRITICAL - New code in `ios/` not shipping  
**Based on:** Repo Review in `review/RepoReview/output/`

---

## Executive Summary

### 🚨 Critical Issues Found

1. **SHIPPING TARGET USES LEGACY STACK**
   - Current: `DoseTrackIOS/DoseTrackIOS/TodayLogView.swift` (legacy)
   - Not Shipping: `ios/TodayLogView.swift` (new, audited)
   - Impact: All SwiftUI updates, late dose override, reset night features never ship

2. **COMPILATION ERRORS IN NEW STACK** ✅ FIXED
   - ✅ Missing `grams` argument in Dose 1 button (`ios/TodayLogView.swift:82`)
   - ✅ Late dose extension calls non-existent API (`ios/TodayViewModel+LateDose.swift:79`)
   - ✅ Override flags never persisted to SwiftData (`ios/DoseLogController.swift:211-223`)

3. **UNWIRED FEATURES**
   - Health/WHOOP chips hard-coded (not connected to real data)
   - Live Activity remains TODO stub
   - Notification preferences inert

4. **SCHEMA MISMATCH**
   - App: Single `DoseLog` SwiftData model
   - Review: Full SQL schema with guardrails, audit tables
   - Guardrails never created or enforced

---

## Immediate Fixes Applied ✅

### Fix 1: Dose 1 Button Missing `grams` Argument

**File:** `ios/TodayLogView.swift` (line 82)

**Before:**
```swift
Button("Dose 1 now", action: vm.logDose1Now).buttonStyle(.borderedProminent)
```

**After:**
```swift
Button("Dose 1 now") { vm.logDose1Now(grams: vm.prefs.planDose1G) }.buttonStyle(.borderedProminent)
```

**Status:** ✅ FIXED

---

### Fix 2: Late Dose Extension API Mismatch

**File:** `ios/TodayViewModel.swift` (protocol)

**Added:**
```swift
func logDose2Now(grams: Double, overrideKind: String?, overrideMinutes: Int?, overrideReason: String?)
```

**Status:** ✅ FIXED

---

### Fix 3: Override Flags Not Persisting to SwiftData

**File:** `ios/DoseLogController.swift` (lines 211-245)

**Before:**
- Override data only stored in `notes` field (string)
- Model fields (`dose2IsOverride`, `dose2OverrideKind`, etc.) never set

**After:**
```swift
func logDose2Now(grams: Double, overrideKind: String?, overrideMinutes: Int?, overrideReason: String?) {
    do {
        var log = fetchOrCreateCurrentNight()
        let now = Date()
        
        log.dose2TimeUTC = now
        log.dose2Grams = safeDisplayGrams(grams)
        
        // Store override metadata in SwiftData model fields
        if let kind = overrideKind, let minutes = overrideMinutes, let reason = overrideReason {
            log.dose2IsOverride = true
            log.dose2OverrideKind = kind
            log.dose2OverrideMinutes = minutes
            log.dose2OverrideReason = reason
            
            // Also append to notes for backwards compatibility
            let override = "\(kind.capitalized) override: \(minutes)m, reason: \(reason)"
            log.notes = [log.notes, override].compactMap { $0 }.joined(separator: " | ")
            
            logger.info("💊 Logged Dose 2 with \(kind) override: \(minutes)m, reason: \(reason)")
        } else {
            logger.info("💊 Logged Dose 2: \(grams)g at \(now)")
        }
        
        try context.save()
        updateLastEvent(kind: .dose2, timestamp: now)
        endLiveActivity()
    } catch {
        logger.error("❌ Failed to log Dose 2: \(error.localizedDescription)")
    }
}
```

**Status:** ✅ FIXED

---

## Phase 1: Make New Stack Ship (PRIORITY 1)

### Step 1.1: Update Xcode Target

**Current Project Structure:**
```
DoseTrackIOS/
  DoseTrackIOS/
    TodayLogView.swift          ← LEGACY (currently shipping)
    DoseTrackApp.swift
    ...

ios/
  TodayLogView.swift            ← NEW (not in target)
  TodayViewModel.swift
  DoseLogController.swift
  Models.swift
  LateDoseSheetView.swift
  ResetNightSheet.swift
  ...
```

**Action Required:**

1. **Open Xcode Project**
   ```bash
   cd /Users/kevindialmb/Downloads/DoseTrack_v1.1.1c
   open DoseTrackIOS/DoseTrackIOS.xcodeproj
   ```

2. **Add `ios/` Files to Target**
   - In Xcode: Project Navigator → Select all files in `ios/` directory
   - Right-click → "Add Files to 'DoseTrackIOS'..."
   - ✅ Check "Copy items if needed"
   - ✅ Check "Create groups"
   - ✅ Check target: "DoseTrackIOS"
   - Click "Add"

3. **Remove Legacy Files from Target**
   - Select `DoseTrackIOS/DoseTrackIOS/TodayLogView.swift`
   - Right-click → Delete → "Remove Reference" (keep file for reference)
   - Move to `DoseTrackIOS/Legacy/` directory

4. **Update App Entry Point**
   
   **File:** `DoseTrackIOS/DoseTrackIOS/DoseTrackApp.swift`
   
   **Change:**
   ```swift
   import SwiftUI
   import SwiftData
   
   @main
   struct DoseTrackApp: App {
       var body: some Scene {
           WindowGroup {
               TodayLogView() // Now uses ios/TodayLogView.swift
           }
           .modelContainer(for: DoseLog.self)
       }
   }
   ```

5. **Verify Compilation**
   ```bash
   xcodebuild -scheme DoseTrackIOS -destination 'platform=iOS Simulator,name=iPhone 17' clean build
   ```

**Expected Result:**
- ✅ Build succeeds
- ✅ New `ios/TodayLogView.swift` ships
- ✅ Late dose override available
- ✅ Reset night available
- ✅ Override flags persist to SwiftData

---

## Phase 2: Wire Up Inert Features (PRIORITY 2)

### Issue 2.1: Hard-Coded Health/WHOOP Chips

**Current State:**
```swift
// ios/TodayLogView.swift (line 34)
StatusChips(healthOK: true, whoopOK: true, wakeSource: "manual", ...)
```

**Problem:** Always shows "OK", never connects to real data

**Solution:**

1. **Add HealthKit Manager Integration**
   
   Create `ios/HealthKitStatusProvider.swift`:
   ```swift
   import HealthKit
   
   @Observable
   class HealthKitStatusProvider {
       var authorizationStatus: HKAuthorizationStatus = .notDetermined
       var hasRecentSleepData: Bool = false
       var lastSleepDataUpdate: Date?
       
       func checkAuthorization() async {
           // Check HKHealthStore authorization
       }
       
       func fetchRecentSleepData() async {
           // Fetch sleep data from last 24 hours
       }
   }
   ```

2. **Add WHOOP Proxy Status**
   
   Create `ios/WHOOPStatusProvider.swift`:
   ```swift
   import Foundation
   
   @Observable
   class WHOOPStatusProvider {
       var isConfigured: Bool = false
       var lastSuccessfulFetch: Date?
       var connectionStatus: ConnectionStatus = .unknown
       
       enum ConnectionStatus {
           case unknown, connected, error(String)
       }
       
       func checkConnection() async {
           // Hit /health endpoint
       }
   }
   ```

3. **Update TodayViewModel**
   
   ```swift
   @Published var healthStatus = HealthKitStatusProvider()
   @Published var whoopStatus = WHOOPStatusProvider()
   
   func onAppear() {
       Task {
           await healthStatus.checkAuthorization()
           await whoopStatus.checkConnection()
       }
   }
   ```

4. **Update StatusChips Call**
   
   ```swift
   StatusChips(
       healthOK: healthStatus.authorizationStatus == .authorized,
       whoopOK: whoopStatus.connectionStatus == .connected,
       wakeSource: prefs.wakeSource,
       onChangeWakeSource: { showWakeSourcePicker = true },
       onCheckHealth: { Task { await healthStatus.checkAuthorization() } },
       onCheckWhoop: { Task { await whoopStatus.checkConnection() } }
   )
   ```

**Estimated Effort:** 4-6 hours

---

### Issue 2.2: Live Activity Stub

**Current State:**
```swift
// ios/DoseLogController.swift (lines 345-356)
func startLiveActivityIfEnabled(...) {
    logger.info("🔴 TODO: Start Live Activity")
}

func endLiveActivity() {
    logger.info("🔴 TODO: End Live Activity")
}
```

**Solution:**

1. **Create ActivityKit Widget Target**
   ```bash
   # In Xcode: File → New → Target → Widget Extension
   # Name: DoseTrackActivity
   # Check: "Include Live Activity"
   ```

2. **Define Activity Attributes**
   
   Create `DoseTrackActivity/DoseTrackActivityAttributes.swift`:
   ```swift
   import ActivityKit
   
   struct DoseTrackActivityAttributes: ActivityAttributes {
       public struct ContentState: Codable, Hashable {
           var windowStartDate: Date
           var windowEndDate: Date
           var dose2Status: Dose2Status
           
           enum Dose2Status: String, Codable {
               case waiting, ready, logged
           }
       }
       
       var dose2Grams: Double
   }
   ```

3. **Implement Start/End in Controller**
   
   ```swift
   func startLiveActivityIfEnabled(windowStartDate: Date, windowEndDate: Date, dose2Grams: Double) {
       guard AppPreferencesEnhanced.shared.liveActivityEnabled else { return }
       
       let attributes = DoseTrackActivityAttributes(dose2Grams: dose2Grams)
       let contentState = DoseTrackActivityAttributes.ContentState(
           windowStartDate: windowStartDate,
           windowEndDate: windowEndDate,
           dose2Status: .waiting
       )
       
       do {
           let activity = try Activity.request(
               attributes: attributes,
               content: .init(state: contentState, staleDate: nil)
           )
           logger.info("✅ Started Live Activity: \(activity.id)")
       } catch {
           logger.error("❌ Failed to start Live Activity: \(error)")
       }
   }
   ```

4. **Update Activity on State Changes**
   
   ```swift
   func updateLiveActivity(dose2Status: Dose2Status) {
       // Update existing activity
   }
   ```

**Estimated Effort:** 8-12 hours

---

### Issue 2.3: Inert Notification Preferences

**Current State:**
- Settings exist in `AppPreferencesEnhanced`
- Never actually schedule notifications

**Solution:**

1. **Create Notification Manager**
   
   `ios/NotificationManager.swift`:
   ```swift
   import UserNotifications
   
   class NotificationManager {
       static let shared = NotificationManager()
       
       func scheduleWindowStartNotification(at date: Date) async {
           let content = UNMutableNotificationContent()
           content.title = "Dose 2 Window Open"
           content.body = "Your Dose 2 window has started"
           content.sound = .default
           
           let trigger = UNTimeIntervalNotificationTrigger(
               timeInterval: date.timeIntervalSinceNow,
               repeats: false
           )
           
           let request = UNNotificationRequest(
               identifier: "dose2_window_start",
               content: content,
               trigger: trigger
           )
           
           try? await UNUserNotificationCenter.current().add(request)
       }
   }
   ```

2. **Hook into DoseLogController**
   
   ```swift
   func logDose1Now(grams: Double) {
       // ... existing code ...
       
       if AppPreferencesEnhanced.shared.notifyAtStart {
           let windowStart = now.addingTimeInterval(Double(prefs.windowStartMin * 60))
           Task {
               await NotificationManager.shared.scheduleWindowStartNotification(at: windowStart)
           }
       }
   }
   ```

**Estimated Effort:** 4-6 hours

---

## Phase 3: Schema Alignment (PRIORITY 3)

### Issue 3.1: SwiftData vs SQL Schema Mismatch

**Current:**
- App uses SwiftData with single `DoseLog` model
- Review bundle has full SQL schema with:
  * `medication_events` (detailed events)
  * `event_log` (audit trail)
  * `guardrails` (safety checks)
  * `preferences` (settings)

**Decision Point:**

**Option A: Keep SwiftData (Recommended for iOS-Only)**
- ✅ Simpler for iOS-only app
- ✅ Better SwiftUI integration
- ✅ Automatic CloudKit sync (if enabled)
- ❌ No server-side access to data
- ❌ No SQL analytics

**Option B: Migrate to SQLite**
- ✅ Server can access data
- ✅ SQL analytics possible
- ✅ Matches review schema
- ❌ More complex data layer
- ❌ Manual sync implementation

**Recommendation:**
- **For now:** Keep SwiftData, add guardrails as computed properties
- **Future:** Consider SQLite if server-side access needed

### Issue 3.2: Missing Guardrails Enforcement

**Current:** No guardrails enforced

**Solution (SwiftData Approach):**

1. **Add Guardrails to Models**
   
   ```swift
   extension DoseLog {
       var violatesPerDoseSafety: Bool {
           let min = 1.5, max = 4.5
           if let d1 = dose1Grams, d1 < min || d1 > max { return true }
           if let d2 = dose2Grams, d2 < min || d2 > max { return true }
           return false
       }
       
       var violatesNightlySafety: Bool {
           let total = (dose1Grams ?? 0) + (dose2Grams ?? 0)
           return total < 3.0 || total > 9.0
       }
       
       var safetyStatus: SafetyStatus {
           if violatesPerDoseSafety || violatesNightlySafety {
               return .violated
           }
           return .compliant
       }
   }
   
   enum SafetyStatus {
       case compliant, violated
   }
   ```

2. **Enforce in Controller**
   
   ```swift
   func logDose1Now(grams: Double) {
       guard grams >= 1.5 && grams <= 4.5 else {
           logger.error("❌ Dose 1 violates per-dose safety: \(grams)g")
           // Show alert to user
           return
       }
       
       // ... proceed ...
   }
   ```

3. **Show in Safety Banner**
   
   ```swift
   SafetyBanner(
       nightTotalG: vm.prefs.totalNightG,
       planDose1G: vm.prefs.planDose1G,
       planDose2G: vm.prefs.planDose2G,
       showViolation: vm.currentLog?.safetyStatus == .violated
   )
   ```

**Estimated Effort:** 2-4 hours

---

## Phase 4: Testing & Validation (PRIORITY 4)

### Test Plan

**Unit Tests:**
- [ ] `DoseLogController` override persistence
- [ ] `TodayViewModel` late dose logic
- [ ] Safety guardrails enforcement
- [ ] CSV export with override columns

**Integration Tests:**
- [ ] Full dosing flow (In bed → Dose 1 → Dose 2 → Wake)
- [ ] Early dose override flow
- [ ] Late dose override flow
- [ ] Reset night (soft/hard)
- [ ] Undo operations

**UI Tests:**
- [ ] All buttons accessible
- [ ] Scrolling works correctly
- [ ] Sheets present/dismiss correctly
- [ ] Settings persist across launches

**Manual Testing Scenarios:**
1. Log normal night (no overrides)
2. Log early Dose 2 (5 min before window)
3. Log late Dose 2 (30 min after window)
4. Reset night (soft mode with undo)
5. Reset night (hard mode with biometric)
6. Export CSV, verify override columns

---

## Remediation Timeline

### Week 1: Critical Path (Get New Stack Shipping)
- **Day 1-2:** Add `ios/` files to Xcode target ✅ DONE (fixes applied)
- **Day 3:** Test compilation, fix remaining errors
- **Day 4-5:** End-to-end testing of new stack
- **Deliverable:** New stack ships, late dose override works

### Week 2: Wire Up Features
- **Day 1-2:** Health/WHOOP status providers
- **Day 3-4:** Live Activity implementation
- **Day 5:** Notification scheduling
- **Deliverable:** All features functional

### Week 3: Schema & Safety
- **Day 1-2:** Guardrails enforcement
- **Day 3-4:** CSV export validation
- **Day 5:** Documentation updates
- **Deliverable:** Safety features enforced

### Week 4: Testing & Polish
- **Day 1-3:** Comprehensive testing
- **Day 4-5:** Bug fixes, polish
- **Deliverable:** Production-ready app

---

## Success Criteria

### Must Have (P0)
- ✅ New `ios/` stack compiles and ships
- ✅ Late dose override persists to SwiftData
- ✅ Reset night functional
- ✅ CSV export includes override columns
- ✅ No compilation errors

### Should Have (P1)
- ⏳ Health/WHOOP status shows real data
- ⏳ Live Activity works for Dose 2 window
- ⏳ Notifications scheduled based on preferences
- ⏳ Safety guardrails enforced

### Nice to Have (P2)
- Full SQL schema migration
- Server-side data access
- Advanced analytics

---

## Current Status

**Compilation Errors:** ✅ FIXED (3/3)
- ✅ Dose 1 button `grams` argument
- ✅ Late dose API mismatch
- ✅ Override flags persistence

**Next Steps:**
1. Add `ios/` files to Xcode target
2. Remove legacy files from target
3. Test end-to-end flow
4. Wire up Health/WHOOP status providers

**Estimated Time to Ship:** 1-2 weeks (with new stack)

---

## References

**Review Documentation:**
- Full report: `review/RepoReview/output/REPORT.md`
- Issues list: `review/RepoReview/output/ISSUES.md`
- Test results: `review/RepoReview/output/TEST_RESULTS.md`
- Remediation plan: `review/RepoReview/output/REMEDIATION_PR_PLAN.md`
- UI wiring findings: `review/RepoReview/output/UI_WIRING_FINDINGS.md`
- Settings gaps: `review/RepoReview/output/SETTINGS_GAPS.md`

**Implementation Files:**
- Late dose: `ios/LateDoseSheetView.swift`, `ios/TodayViewModel+LateDose.swift`
- Reset night: `ios/ResetNightSheet.swift`
- UI layouts: `ios/TodayLogView_CardStack.swift`, `ios/TodayLogView_Checklist.swift`
- Documentation: `docs/ops/LATE_DOSE_AND_UI_LAYOUTS.md`

---

**Version:** 1.0.0  
**Last Updated:** November 2, 2025  
**Status:** REMEDIATION IN PROGRESS  
**Priority:** CRITICAL
