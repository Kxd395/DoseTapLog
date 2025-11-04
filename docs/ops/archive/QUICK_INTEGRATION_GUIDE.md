# Quick Integration Guide - DoseTrack v1.1.1c

**Status:** ✅ Project compiles cleanly, ready for feature integration  
**Date:** November 2, 2025

---

## ✅ What's Working Right Now

### Compilation Status: GREEN
- **Zero compilation errors** in DoseTrackIOS project
- All 24 Swift files compile successfully
- NightPlan safety checks functional
- Basic dose tracking operational

### Core Features Active
- ✅ Night session tracking
- ✅ Dose 1 and Dose 2 logging
- ✅ Safety guardrails (1.5-4.5g per dose, 3.0-9.0g total)
- ✅ Window timing (150-240 min after Dose 1)
- ✅ Basic settings panel
- ✅ CSV export
- ✅ HealthKit integration (partial)
- ✅ Live Activity support (basic)
- ✅ App Intents & Widgets

---

## 🚀 Ready-to-Integrate Enhancements

### Option 1: Enhanced Settings (Easiest, High Value)

**Time Estimate:** 2 hours  
**Difficulty:** Easy  
**Value:** Immediate UX improvement

**Files to Add:**
```bash
# Copy from /ios/ to Xcode project:
AppPreferencesEnhanced.swift           # 372 lines, 30+ settings
AppPreferencesEnhanced+LateDose.swift  # Late dose policy extension
SettingsViewEnhanced.swift             # 334 lines, 7-section UI
```

**Steps:**
1. Open `DoseTrackIOS.xcodeproj`
2. Right-click on `DoseTrackIOS` folder → Add Files
3. Select all 3 files from `/ios/` directory
4. Build (⌘B) - should compile with no errors
5. In `DoseTrackApp.swift`, replace:
   ```swift
   // Old:
   .sheet(isPresented: $showSettings) { SettingsView() }
   
   // New:
   .sheet(isPresented: $showSettings) { 
       SettingsViewEnhanced(prefs: AppPreferencesEnhanced.shared)
   }
   ```
6. Test: Open settings, verify all 7 sections appear
7. Verify settings persist across app restarts

**What You Get:**
- 30+ user-configurable preferences
- App Group support for widget/intent sharing
- Health status display
- WHOOP connection tester
- CSV export customization
- Privacy controls
- Debug tools (simulate events)

---

### Option 2: Reset Night Feature (Medium, Safety-Critical)

**Time Estimate:** 4 hours  
**Difficulty:** Medium  
**Value:** Critical safety escape hatch

**Files to Add:**
```bash
# From /review/ResetNight_UX_Pack_2025-11-02/:
ios/ResetNightSheet.swift              # Modal UI with biometric
ios/DoseLogController+Reset.swift      # Controller methods
ios/TodayViewModel+ResetNight.swift    # ViewModel integration
ios/TodayLogView+ResetNight.swift      # View entry points
sql/migrations/00X_reset_night.sql     # DB schema updates
```

**Steps:**
1. **Database Migration:**
   - Review `sql/migrations/00X_reset_night.sql`
   - Add new columns to SwiftData models:
     ```swift
     // Event model additions:
     var resetBatchId: String?
     
     // SleepSession additions:
     var resetBatchId: String?
     var isClosedByReset: Bool = false
     ```
   - Run migration (or let SwiftData auto-migrate)

2. **Add Swift Files:**
   - Copy all 4 `.swift` files to Xcode project
   - Ensure they're in DoseTrackIOS target

3. **Wire Entry Points:**
   - In `TodayLogView`, add toolbar item:
     ```swift
     .toolbar {
         // ... existing gear button
         Menu {
             Button("Reset Night", systemImage: "arrow.clockwise") {
                 showResetSheet = true
             }
         } label: {
             Image(systemName: "ellipsis.circle")
         }
     }
     .sheet(isPresented: $showResetSheet) {
         ResetNightSheet(
             requireBiometric: prefs.requireBiometric,
             onConfirm: { mode, reason in
                 vm.performResetNight(mode: mode, reason: reason)
             }
         )
     }
     ```

4. **Test Both Modes:**
   - Soft reset: Archives data, creates new session with "+R1"
   - Hard reset: Deletes data (requires typing "RESET" + biometric)
   - Verify undo banner appears for 30s
   - Check audit trail in event_log

**What You Get:**
- Safe escape when night gets into bad state
- Soft mode preserves data for analysis
- Hard mode for complete do-over
- Biometric confirmation for destructive action
- Full audit trail

---

### Option 3: Early Dose Override (Medium, Usability)

**Time Estimate:** 3 hours  
**Difficulty:** Medium  
**Value:** Reduces user frustration

**Implementation Notes:**
- Create `EarlyDoseSheet.swift` modal
- Add reason picker and time-prior buttons (5 min, 10 min, custom)
- Update gating logic in `TodayViewModel`:
  ```swift
  var dose2Enabled: Bool {
      guard let d1 = dose1At else { return false }
      let elapsed = Date().timeIntervalSince(d1) / 60.0
      
      if elapsed >= prefs.windowStartMin && elapsed <= prefs.windowEndMin {
          return true // Within window
      }
      
      if prefs.allowEarlyDose && elapsed >= (prefs.windowStartMin - Double(prefs.maxEarlyMinutes)) {
          return true // Eligible for early override
      }
      
      return false
  }
  
  var dose2ReasonText: String {
      guard let d1 = dose1At else { return "Log Dose 1 first" }
      let elapsed = Date().timeIntervalSince(d1) / 60.0
      let remaining = prefs.windowStartMin - elapsed
      
      if remaining > 0 && remaining <= Double(prefs.maxEarlyMinutes) {
          return "Early override available"
      } else if remaining > 0 {
          return "Window opens in \(Int(remaining)) min"
      }
      return "Ready"
  }
  ```
- Log override events with metadata:
  ```swift
  Event(
      kind: .dose2,
      overrideEarlyMinutes: minutesEarly,
      overrideReason: reason,
      ...
  )
  ```

**What You Get:**
- Users can dose slightly early with justification
- Reduces "missed window" frustration
- Full audit trail of overrides
- Configurable policy (max early minutes, require reason)

---

## 📋 Pre-Integration Checklist

Before integrating ANY new feature:

### 1. Backup Current State
```bash
cd /Users/kevindialmb/Downloads/DoseTrack_v1.1.1c
git add .
git commit -m "Clean compile state before integration"
git tag v1.1.1c-clean
```

### 2. Review File Organization
Per `.github/copilot-instructions.md`:
- ✅ Product docs go in `/docs/`
- ✅ Operational guides go in `/docs/ops/`
- ✅ Design docs go in `/docs/design/`
- ✅ Swift source files go in `/ios/` or `/DoseTrackIOS/DoseTrackIOS/`
- ❌ NEVER create documents in project root

### 3. Check Dependencies
```swift
// Required frameworks:
import SwiftUI
import SwiftData
import HealthKit        // If using health features
import LocalAuthentication  // If using biometric
import ActivityKit      // If using Live Activities
```

### 4. Verify App Group
If using enhanced settings or widget sharing:
```swift
// In DoseTrackIOS.entitlements, ensure:
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.jefferson.dosetrack</string>
</array>
```

### 5. Test Compilation
```bash
# Build in Xcode:
⌘B (Build)

# Or from command line:
xcodebuild -project DoseTrackIOS/DoseTrackIOS.xcodeproj \
           -scheme DoseTrackIOS \
           -destination 'platform=iOS Simulator,name=iPhone 15' \
           clean build
```

---

## 🔍 Integration Testing Matrix

After integrating each feature:

### Basic Smoke Tests
- [ ] App launches without crash
- [ ] Main view displays correctly
- [ ] Settings panel opens
- [ ] No console errors

### Feature-Specific Tests
**Enhanced Settings:**
- [ ] All 7 sections visible
- [ ] Settings persist across app restart
- [ ] Default values match spec
- [ ] Night plan preview updates live

**Reset Night:**
- [ ] Soft reset creates new session
- [ ] Hard reset requires typed confirmation
- [ ] Biometric prompt appears (if enabled)
- [ ] Undo banner shows for 30s
- [ ] Event log contains reset audit trail

**Early Dose:**
- [ ] Sheet appears when eligible
- [ ] Reason required (if policy enabled)
- [ ] Time-prior buttons work
- [ ] Override logged with metadata

### iPhone SE Tests (Scroll/Layout)
- [ ] Settings panel scrolls smoothly
- [ ] All buttons have 48pt min height
- [ ] No content clipped at bottom
- [ ] Tap targets don't overlap

---

## 🆘 Troubleshooting Common Issues

### Issue: "Cannot find type AppPreferencesEnhanced"
**Fix:** Ensure file is added to DoseTrackIOS target (not just project)
1. Select file in Xcode
2. Open File Inspector (⌥⌘1)
3. Check "Target Membership" → DoseTrackIOS

### Issue: "App Group not accessible"
**Fix:** Update entitlements and provisioning
1. Verify `DoseTrackIOS.entitlements` has correct group
2. Regenerate provisioning profile in Apple Developer Portal
3. Clean build folder (⇧⌘K)

### Issue: SwiftData migration fails
**Fix:** Delete app and reinstall (dev only)
```bash
# Simulator:
xcrun simctl uninstall booted com.jefferson.dosetrack

# Physical device:
# Settings → General → iPhone Storage → DoseTrack → Delete App
```

### Issue: Settings don't persist
**Fix:** Check UserDefaults suite name
```swift
// Correct:
UserDefaults(suiteName: "group.com.jefferson.dosetrack")

// Incorrect:
UserDefaults.standard  // Won't share with widgets
```

---

## 📞 Next Steps & Support

### Recommended Integration Order
1. **Start with Enhanced Settings** (easiest, immediate value)
2. **Add Reset Night** (safety-critical)
3. **Implement Early Dose** (usability)
4. **Polish Live Activity** (nice-to-have)

### Documentation References
- Full status review: `/docs/ops/REPOSITORY_STATUS_REVIEW.md`
- Implementation guides: `/review/updates.md`, `/review/update2.md`
- Reset Night spec: `/review/ResetNight_UX_Pack_2025-11-02/docs/RESET_NIGHT_SPEC.md`
- Constitution principles: `.specify/memory/constitution.md`

### Getting Help
- Review `/review/updates.md` for super-critical product fixes
- Check `/review/update2.md` for Dose 2 gating policy
- Consult `/docs/PRD_v1.2.md` for requirements
- All code examples in review files are copy-paste ready

---

**Last Updated:** November 2, 2025  
**Status:** ✅ Ready for integration  
**Next Milestone:** Enhanced Settings integration
