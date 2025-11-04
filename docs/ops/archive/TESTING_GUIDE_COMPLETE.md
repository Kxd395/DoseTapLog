# DoseTrack Complete Testing Guide

## Overview
This guide provides comprehensive testing procedures for all DoseTrack features including night flow, EventLog system, safety checks, and Live Activities.

**Last Updated:** November 2, 2025  
**Version:** v1.2.0 (with EventLog integration)

---

## Pre-Test Setup

### 1. Clean Build
```bash
cd /Users/kevindialmb/Downloads/DoseTrack_v1.1.1c/DoseTrackIOS
xcodebuild clean -project DoseTrackIOS.xcodeproj -scheme DoseTrackIOS
xcodebuild -project DoseTrackIOS.xcodeproj -scheme DoseTrackIOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

### 2. Launch App
- Press ⌘R in Xcode
- Wait for app to launch in simulator
- Verify no crash on launch
- Check that TodayLogView displays

### 3. Initial State Verification
- [ ] App launches successfully
- [ ] "DoseTrack" title visible
- [ ] "Tonight plan" card shows default values
- [ ] Safety banner displays (green checkmark or bounds warning)
- [ ] Status chips show: "Health OK", "WHOOP OK", "Wake: Manual"
- [ ] Primary actions visible: "In bed now", "Dose 1 now", "Dose 2 now", "Final wake"
- [ ] Events section visible: "Alarm wake", "Bathroom", "Undo last", "Edit plan"
- [ ] Utilities bar pinned at bottom: "Snooze 5m", "Snooze 10m", "Autofill wake", "Export CSV"

---

## Feature Test Checklist

### A. Basic Night Flow (Core Functionality)

#### Test 1: In Bed Event
- [ ] Tap "In bed now"
- [ ] Verify toast appears (if implemented)
- [ ] Check EventLog: Event should appear in "Tonight's Events" section
- [ ] Verify event type: 🛏️ In Bed
- [ ] Verify timestamp is current time

#### Test 2: Dose 1 Logging
- [ ] Tap "Dose 1 now"
- [ ] Verify haptic feedback (medium impact vibration)
- [ ] Verify countdown ring appears
- [ ] Verify ring shows "Waiting" status with yellow color
- [ ] Check text under ring: "Dose 2 window in XXX m" (should show ~150 minutes)
- [ ] Verify "Dose 2 now" button is disabled (grayed out)
- [ ] Verify EventLog shows 💊 Dose 1 with grams amount
- [ ] Check "Recent Events (Legacy)" shows Dose 1 entry

#### Test 3: Dose 2 Window Gating
- [ ] Immediately after Dose 1, try tapping "Dose 2 now"
- [ ] Verify button is disabled (no action)
- [ ] Verify toast appears: "⚠️ Wait 150m for Dose 2 window"
- [ ] Verify haptic warning (notification warning vibration)

#### Test 4: Dose 2 Window Opens (Simulated Time)
**Option A: Wait 150 minutes (real-time)**
- Not practical for testing

**Option B: Fast-forward simulator time**
1. Open Settings app in simulator
2. Go to General → Date & Time
3. Turn off "Set Automatically"
4. Add 150 minutes to current time
5. Return to DoseTrack

- [ ] Verify countdown ring changes to "Open" status (green)
- [ ] Verify text: "Window ends in XXX m" (should show ~90 minutes)
- [ ] Verify "Dose 2 now" button is enabled (not grayed)
- [ ] Tap "Dose 2 now"
- [ ] Verify haptic success
- [ ] Verify countdown ring disappears (Live Activity ends)
- [ ] Verify EventLog shows 💊💊 Dose 2 with grams
- [ ] Verify toast (if any)

#### Test 5: Final Wake Logging
- [ ] Tap "Final wake"
- [ ] Verify haptic feedback
- [ ] Verify EventLog shows ☀️ Final Wake
- [ ] Verify "Wake: Manual" chip remains
- [ ] Check timestamp

#### Test 6: Alarm Wake
- [ ] Tap "Alarm wake"
- [ ] Verify haptic feedback
- [ ] Verify EventLog shows ⏰ Alarm Wake
- [ ] Verify "Wake" chip changes to "Wake: Alarm"
- [ ] Check timestamp

---

### B. EventLog System

#### Test 7: Bathroom Event Logging
- [ ] Tap "Bathroom"
- [ ] Verify toast: "🚽 Bathroom event logged"
- [ ] Verify haptic success
- [ ] Verify EventLog shows 🚽 Bathroom
- [ ] Event should NOT show grams (gramsIfApplicable = nil)

#### Test 8: Snooze Event Logging
- [ ] Tap "Snooze 5m"
- [ ] Verify toast: "⏰ Reminder in 5 minutes"
- [ ] Verify EventLog shows 😴 Snooze with "5 minute snooze" details
- [ ] Tap "Snooze 10m"
- [ ] Verify EventLog shows second snooze with "10 minute snooze"

#### Test 9: Event Log Full Screen
- [ ] Scroll to "Tonight's Events" section
- [ ] Tap "View All" button
- [ ] Verify EventLogScreen opens in sheet
- [ ] Verify navigation title: "Event Log"
- [ ] Verify "Done" button in top-left
- [ ] Verify trash icon in top-right
- [ ] Verify search bar at top
- [ ] Verify filter chips (event types + night keys)
- [ ] Verify events grouped by hour

#### Test 10: Event Log Search
- [ ] In EventLogScreen, type "Dose" in search bar
- [ ] Verify only Dose 1 and Dose 2 events show
- [ ] Clear search (tap X)
- [ ] Type "Bathroom"
- [ ] Verify only bathroom events show
- [ ] Clear search

#### Test 11: Event Log Filtering
- [ ] Tap "💊 Dose 1" filter chip
- [ ] Verify chip turns blue (selected)
- [ ] Verify only Dose 1 events show
- [ ] Tap chip again to deselect
- [ ] Tap "Night [today's key]" filter chip
- [ ] Verify only tonight's events show
- [ ] Tap "Clear" button
- [ ] Verify all filters cleared

#### Test 12: Event Log Swipe-to-Delete
- [ ] In EventLogScreen, swipe left on any event
- [ ] Verify red "Delete" button appears
- [ ] Tap "Delete"
- [ ] Verify event is removed from list
- [ ] Close sheet and reopen
- [ ] Verify event is still deleted (persisted)

#### Test 13: Event Log Clear All
- [ ] In EventLogScreen, tap trash icon (top-right)
- [ ] All events should be deleted
- [ ] Verify "No Events" placeholder appears
- [ ] Close sheet
- [ ] Verify "Tonight's Events" section disappears from main screen

---

### C. Safety System

#### Test 14: Per-Dose Safety Check
**Setup:** Modify plan to violate bounds
1. Manually set `plan.dose1DisplayG = 5.0` (exceeds 4.5g max)
2. Rebuild and run

- [ ] Verify SafetyBanner shows red warning
- [ ] Text should indicate "Exceeds per-dose max"
- [ ] Verify both per-dose and nightly totals displayed

**Reset:** Set back to `plan.dose1DisplayG = 3.25`

#### Test 15: Nightly Total Safety Check
**Setup:** Modify plan to violate nightly bounds
1. Set `plan.dose1DisplayG = 5.0` and `plan.dose2DisplayG = 5.0` (total 10.0g > 9.0g max)

- [ ] Verify SafetyBanner shows red warning
- [ ] Text should indicate "Exceeds nightly max"
- [ ] Verify total displayed: "10.00g"

**Reset:** Restore defaults

#### Test 16: Safe Range
- [ ] With default plan (3.25g + 3.25g = 6.5g)
- [ ] Verify SafetyBanner shows green checkmark ✓
- [ ] Text: "Within safe range"
- [ ] Totals: "Per dose: 1.5-4.5g, Night: 3.0-9.0g, Planned: 6.50g"

---

### D. UI/UX Features

#### Test 17: Page Scrolling
- [ ] Scroll down to see all sections
- [ ] Verify smooth scrolling
- [ ] Verify utilities bar stays pinned at bottom
- [ ] Scroll to top
- [ ] Verify "DoseTrack" title reappears

#### Test 18: Button Responsiveness
- [ ] Tap each button rapidly 5 times
- [ ] "In bed now" - should work every time
- [ ] "Dose 1 now" - should work every time
- [ ] "Dose 2 now" - should show toast if gated
- [ ] "Final wake" - should work every time
- [ ] All buttons should feel responsive (no lag)

#### Test 19: Toast Messages
- [ ] Trigger multiple toasts in sequence
- [ ] Verify each toast displays for ~2 seconds
- [ ] Verify smooth fade-in/fade-out animation
- [ ] Verify toast is above utilities bar
- [ ] Verify toast doesn't block primary actions

#### Test 20: Status Chips Tap Actions
- [ ] Tap "Health OK" chip
- [ ] Verify toast: "ℹ️ HealthKit permissions configured"
- [ ] Tap "WHOOP OK" chip
- [ ] Verify toast: "ℹ️ Backend proxy operational"
- [ ] Tap "Wake: Manual" chip
- [ ] Verify toast shows wake source

---

### E. Utilities & Integrations

#### Test 21: Undo Functionality
**Setup:** Log any event (e.g., "In bed now")

- [ ] Within 60 seconds, tap "Undo last"
- [ ] Verify haptic success
- [ ] Verify toast: "↶ Last event undone"
- [ ] Wait 61 seconds after an event
- [ ] Tap "Undo last"
- [ ] Verify button is disabled (no action)
- [ ] Verify toast: "⚠️ Nothing to undo"

#### Test 22: Snooze Notifications
**Setup:** Enable notifications in iOS Settings

- [ ] Tap "Snooze 5m"
- [ ] Verify toast: "⏰ Reminder in 5 minutes"
- [ ] Wait 5 minutes (or fast-forward time)
- [ ] Verify local notification appears: "Dose 2 Reminder"
- [ ] Tap notification → app should open

**Repeat for "Snooze 10m"**

#### Test 23: HealthKit Autofill
**Setup:** Grant HealthKit permissions

- [ ] Add fake sleep data in Health app (or use sleep schedule)
- [ ] Tap "Autofill wake"
- [ ] If data found: Toast "✅ Wake from Health: [time]"
- [ ] If no data: Toast "⚠️ No sleep data found"
- [ ] Verify wake time populated in EventLog

#### Test 24: CSV Export
- [ ] Log at least 3 events (Dose 1, Dose 2, Wake)
- [ ] Tap "Export CSV"
- [ ] Verify toast: "✅ CSV ready"
- [ ] Verify share sheet appears
- [ ] Select "Save to Files" or "AirDrop"
- [ ] Open CSV file
- [ ] Verify columns: nightKey, dose1TimeUTC, dose1Grams, dose2TimeUTC, dose2Grams, finalWakeTimeUTC, finalWakeProvenance
- [ ] Verify data is correctly formatted

---

### F. Live Activities (Requires Widget Extension)

⚠️ **Note:** Live Activities require Widget Extension target (see WIDGET_EXTENSION_SETUP.md)

#### Test 25: Live Activity Launch
**Setup:** Widget Extension must be configured

- [ ] Tap "Dose 1 now"
- [ ] Lock device (⌘L in simulator)
- [ ] Verify Live Activity appears on Lock Screen
- [ ] Verify countdown ring displayed
- [ ] Verify "Dose 2" label and grams amount
- [ ] Verify time remaining text

#### Test 26: Live Activity Updates
- [ ] While Live Activity is showing, unlock device
- [ ] Fast-forward time by 10 minutes
- [ ] Lock device again
- [ ] Verify time remaining decremented
- [ ] Verify ring progress increased

#### Test 27: Live Activity Deep Links
- [ ] On Lock Screen with Live Activity visible
- [ ] Tap "Log Dose 2" button (if displayed)
- [ ] App should open and log Dose 2
- [ ] Tap "Snooze 5m" button
- [ ] Notification should schedule
- [ ] Live Activity should end

#### Test 28: Live Activity End
- [ ] Log Dose 2 in app
- [ ] Lock device
- [ ] Verify Live Activity disappears from Lock Screen
- [ ] Unlock and verify app state is correct

---

### G. Edge Cases & Error Handling

#### Test 29: Rapid Tap Protection
- [ ] Tap "Dose 1 now" 10 times rapidly
- [ ] Verify only ONE Dose 1 event logged
- [ ] Check EventLog for duplicates (should be none)

#### Test 30: Out-of-Order Events
- [ ] Log "Final wake" BEFORE Dose 1
- [ ] Verify event is logged
- [ ] Verify no crash
- [ ] Log Dose 1
- [ ] Verify countdown starts normally

#### Test 31: Same Event Multiple Times
- [ ] Tap "Bathroom" 5 times
- [ ] Verify 5 separate bathroom events in EventLog
- [ ] All should have different timestamps (1-2 seconds apart)

#### Test 32: Window Edge Cases
- [ ] Log Dose 1
- [ ] Fast-forward to EXACTLY 150 minutes
- [ ] Verify "Dose 2 now" is enabled
- [ ] Fast-forward to EXACTLY 240 minutes
- [ ] Verify countdown ring shows "Ended" (red)
- [ ] Verify "Dose 2 now" button behavior (should still work or show warning)

#### Test 33: Empty State
- [ ] Fresh app install (or clear all data)
- [ ] Verify no EventLog section visible
- [ ] Verify "View All" button not shown
- [ ] Log one event
- [ ] Verify section appears

---

### H. Performance & Stability

#### Test 34: Memory Leaks
- [ ] Run app for 5 minutes
- [ ] Perform 20+ actions (log events, scroll, open sheets)
- [ ] Check Instruments → Leaks
- [ ] Verify no memory leaks detected

#### Test 35: High Event Volume
- [ ] Log 100+ events (use loop if needed)
- [ ] Open EventLogScreen
- [ ] Verify smooth scrolling
- [ ] Verify search is fast (<1 second)
- [ ] Verify filtering is fast

#### Test 36: Background/Foreground
- [ ] Log Dose 1
- [ ] Background app (⌘H)
- [ ] Wait 2 minutes
- [ ] Foreground app
- [ ] Verify countdown ring updates correctly
- [ ] Verify time remaining is accurate

#### Test 37: App Restart Persistence
- [ ] Log 3 events (Dose 1, Bathroom, Dose 2)
- [ ] Force quit app (⌘Q)
- [ ] Relaunch app (⌘R)
- [ ] Verify all 3 events still in EventLog
- [ ] Verify dose times restored
- [ ] Verify countdown ring state correct

---

## Test Results Template

### Test Summary
```
Date: November 2, 2025
Tester: [Your Name]
Build: DoseTrack v1.2.0
Device: iPhone 17 Pro Simulator (iOS 26.0)

Total Tests: 37
Passed: ___
Failed: ___
Skipped: ___

Pass Rate: ____%
```

### Failed Tests (if any)
```
Test #: [Number]
Test Name: [Name]
Expected: [What should happen]
Actual: [What actually happened]
Steps to Reproduce:
1. 
2. 
3. 

Screenshot/Log: [Attach if available]
Priority: High/Medium/Low
```

---

## Automated Testing (Future)

### Unit Tests to Add
```swift
// DoseWindowServiceTests.swift
func testWindowCalculation() {
    let dose1 = Date()
    let window = DoseWindowService.shared.windowOpenClose(dose1At: dose1)
    XCTAssertEqual(window.open, dose1.addingTimeInterval(150*60))
    XCTAssertEqual(window.close, dose1.addingTimeInterval(240*60))
}

func testDose2Gating() {
    let dose1 = Date()
    let tooEarly = dose1.addingTimeInterval(100*60)
    let result = DoseWindowService.shared.canLogDose2(now: tooEarly, dose1At: dose1)
    XCTAssertFalse(result.ok)
    XCTAssertNotNil(result.reason)
}

// EventLogTests.swift
func testEventLogCreation() {
    let event = EventLog(
        nightKey: "2025-11-02",
        eventType: .dose1,
        timestamp: Date(),
        gramsIfApplicable: 3.25
    )
    XCTAssertEqual(event.type, .dose1)
    XCTAssertEqual(event.gramsIfApplicable, 3.25)
}

func testEventLogFiltering() {
    // Create 10 events of different types
    // Filter by type
    // Verify count matches
}
```

---

## Success Criteria

### Minimum Viable (MVP)
- ✅ All Basic Night Flow tests pass (Tests 1-6)
- ✅ EventLog creation works (Tests 7-13)
- ✅ Safety system functions (Tests 14-16)
- ✅ UI is responsive and scrollable (Tests 17-19)
- ✅ No crashes on common user flows

### Production Ready
- ✅ All MVP criteria met
- ✅ All utilities work (Tests 21-24)
- ✅ Live Activities functional (Tests 25-28) OR documented as Phase 2
- ✅ Edge cases handled gracefully (Tests 29-33)
- ✅ Performance acceptable (Tests 34-37)
- ✅ Pass rate > 95%

### App Store Ready
- ✅ All Production Ready criteria met
- ✅ Unit test coverage > 80%
- ✅ No memory leaks
- ✅ All user flows tested on physical device
- ✅ Privacy policy updated for HealthKit
- ✅ App Store screenshots prepared
- ✅ TestFlight beta testing completed

---

## Quick Smoke Test (5 minutes)

For rapid verification after changes:

1. ✅ Launch app (no crash)
2. ✅ Tap "In bed now" → Event logged
3. ✅ Tap "Dose 1 now" → Countdown appears, event logged
4. ✅ Tap "Dose 2 now" → Toast warning (gated)
5. ✅ Tap "Bathroom" → Event logged
6. ✅ Tap "View All" → EventLogScreen opens
7. ✅ Search "Dose" → Filters work
8. ✅ Swipe delete event → Persists
9. ✅ Tap "Done" → Returns to main
10. ✅ Scroll page → Smooth, utilities pinned

**All 10 passed? Ship it!** 🚀

---

## Contact & Support

**Questions?** Review:
- `/docs/PRD_v1.2.md` - Product requirements
- `/docs/ops/NIGHT_FLOW_INTEGRATION_COMPLETE.md` - Implementation details
- `/docs/ops/WIDGET_EXTENSION_SETUP.md` - Live Activity setup
- `.specify/memory/constitution.md` - Safety principles

**Found a bug?** Document using Failed Tests template above.

**Need help?** Check existing tests first, then review code comments.
