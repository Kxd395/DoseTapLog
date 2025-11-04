# 🧪 DoseTrack Testing Quick Start

**Version:** 1.1.1c  
**Status:** Ready for end-to-end testing  
**Date:** November 2, 2025

---

## 🚀 Quick Start (3 Steps)

### 1. Open Project in Xcode

```bash
cd /Users/kevindialmb/Downloads/DoseTrack_v1.1.1c
open -a Xcode DoseTrackIOS/DoseTrackIOS.xcodeproj
```

### 2. Select Simulator

- Target: **iPhone 17 Pro** (or iPhone SE for small device testing)
- iOS Version: **17.0+**

### 3. Build & Run

- Press `⌘R` or click the Play button
- Wait for build to complete
- App launches in simulator

---

## ✅ Testing Checklist (12 Steps)

### Core Flow

1. **Launch app**
   - [ ] TodayLogView appears
   - [ ] No errors in console
   - [ ] Controller injected with ModelContext

2. **Tap "In bed now"**
   - [ ] nightKey minted (YYYY-MM-DD format)
   - [ ] bedtimeUTC stored in DoseLog
   - [ ] EventStrip shows "🛏️ In bed 23:00"
   - [ ] Last event tracked in App Group

3. **Tap "Dose 1 now"**
   - [ ] dose1TimeUTC stored
   - [ ] dose1Grams = planDose1G (default: 3.25g)
   - [ ] EventStrip shows "💊 Dose 1 23:05 • 3.25g"
   - [ ] CountdownRing starts (orange → green at window start)
   - [ ] Undo button enabled

4. **Wait 30 seconds**
   - [ ] TimelineView updates CountdownRing
   - [ ] Status text updates ("Window opens in X h Y m")

5. **Test undo (within 60s)**
   - [ ] Tap "Undo last" button
   - [ ] dose1TimeUTC cleared
   - [ ] EventStrip removes Dose 1 event
   - [ ] Log shows: "✅ Undo complete: dose1"

6. **Re-log Dose 1**
   - [ ] Tap "Dose 1 now" again
   - [ ] Event re-appears in EventStrip

7. **Wait for window** (or simulate time)
   - [ ] Ring turns green
   - [ ] Dose 2 button enabled
   - [ ] Inline reason disappears

8. **Tap "Dose 2 now"**
   - [ ] dose2TimeUTC stored
   - [ ] dose2Grams = planDose2G (default: 3.25g)
   - [ ] EventStrip shows "💊 Dose 2 02:35 • 3.25g"
   - [ ] Live Activity end hook called (log message)

9. **Open Settings**
   - [ ] Tap gear icon (toolbar)
   - [ ] SettingsViewEnhanced sheet presents
   - [ ] 7 sections visible

10. **Change settings**
    - [ ] Modify totalNightGrams (e.g., 7.0g)
    - [ ] Live preview updates (3.5g + 3.5g)
    - [ ] Safety warning appears if bounds violated
    - [ ] Tap "Done"

11. **Kill and relaunch**
    - [ ] Swipe up to close app
    - [ ] Relaunch from home screen
    - [ ] nightKey, doses, times restored
    - [ ] EventStrip shows previous events
    - [ ] Settings retained (totalNightGrams = 7.0g)

12. **Check logs**
    - [ ] Open Console.app
    - [ ] Filter: `subsystem:com.jefferson.dosetrack`
    - [ ] Verify: "✅ Logged Dose 1", "✅ Logged Dose 2", "✅ Undo complete"
    - [ ] No PII in logs

### Device Compatibility

**iPhone SE (Smallest Device):**
- [ ] All content visible (no overflow)
- [ ] ScrollView works
- [ ] All buttons tappable (48pt min height)
- [ ] SafetyBanner chips visible

**iPhone 15 Pro (Largest Device):**
- [ ] All components visible
- [ ] No excessive whitespace
- [ ] Countdown ring proportional

### Error Scenarios

**SwiftData write fails:**
- [ ] Simulate by denying storage access (rare)
- [ ] Retry toast appears
- [ ] Pending action enqueued
- [ ] Log shows: "❌ Failed to log Dose 1: [error]"

**Widget action (future):**
- [ ] Widget writes pending action to App Group
- [ ] App launch → consumePendingFromWidget()
- [ ] Action processed (idempotent check)
- [ ] Queue cleared

---

## 🐛 Debugging Tips

### View Console Logs

```bash
# Real-time log stream
log stream --predicate 'subsystem == "com.jefferson.dosetrack"' --level debug

# Or in Console.app:
# 1. Open Console.app
# 2. Select simulator device
# 3. Filter: subsystem:com.jefferson.dosetrack
```

### Expected Log Messages

**On Launch:**
```
✅ DoseLogController initialized
✅ AppPreferences migration complete (or skipped)
✅ Consumed 0 pending actions from widget
```

**On "Dose 1 now":**
```
✅ Logged Dose 1: 3.25g at 2025-11-02 23:05:00
```

**On Undo:**
```
✅ Undo complete: dose1
```

**On Error:**
```
❌ Failed to log Dose 1: [error description]
📦 Enqueued pending action: dose1Now(grams: 3.25)
```

### Check App Group UserDefaults

```swift
// In Xcode debug console (lldb):
po UserDefaults(suiteName: "group.com.jefferson.dosetrack")!.dictionaryRepresentation()

// Expected keys:
// - totalNightGrams: 6.5
// - splitStrategy: "equal"
// - allowEarlyDose: true
// - lastEventKind: "dose1"
// - lastEventTime: Date(...)
```

### Check SwiftData

```swift
// In Xcode View Hierarchy Debugger:
// Menu: Debug → View Debugging → Capture View Hierarchy

// Or in lldb:
po context.fetch(FetchDescriptor<DoseLog>())
```

---

## 📊 Expected Test Results

### After Complete Flow

**DoseLog in SwiftData:**
```swift
nightKey: "2025-11-02"
bedtimeUTC: 2025-11-02 23:00:00 +0000
dose1TimeUTC: 2025-11-02 23:05:00 +0000
dose1Grams: 3.25
dose2TimeUTC: 2025-11-03 02:35:00 +0000
dose2Grams: 3.25
finalWakeTimeUTC: nil
timezoneOffsetMinutes: -300 (EST)
bathroomWakeTimesUTC: []
notes: ""
```

**App Group UserDefaults:**
```json
{
  "totalNightGrams": 6.5,
  "splitStrategy": "equal",
  "allowEarlyDose": true,
  "maxEarlyMinutes": 30,
  "windowStartMin": 180,
  "windowEndMin": 240,
  "lastEventKind": "dose2",
  "lastEventTime": "2025-11-03T02:35:00Z"
}
```

**EventStrip UI:**
```
🛏️ In bed 23:00
💊 Dose 1 23:05 • 3.25g
💊 Dose 2 02:35 • 3.25g
```

---

## 🚨 Common Issues

### Issue: "No such module 'os'"

**Solution:** Ensure deployment target is iOS 17.0+
```swift
// In DoseTrackIOS.xcodeproj settings:
iOS Deployment Target: 17.0
```

### Issue: "Cannot find 'DoseLog' in scope"

**Solution:** Ensure Models.swift is in target
```
1. Select Models.swift in Project Navigator
2. File Inspector → Target Membership → Check DoseTrackIOS
```

### Issue: "App crashes on launch"

**Solution:** Check for SwiftData initialization errors
```swift
// In DoseTrackApp.swift:
.modelContainer(for: [DoseLog.self])
```

### Issue: "Settings don't persist"

**Solution:** Verify App Group entitlement
```
1. Select DoseTrackIOS target
2. Signing & Capabilities → + Capability → App Groups
3. Add: group.com.jefferson.dosetrack
```

---

## 🎯 Success Criteria

**All tests pass if:**
- ✅ Complete flow works (In bed → Dose 1 → Dose 2)
- ✅ EventStrip shows all 3 events
- ✅ Undo works within 60s
- ✅ Settings persist across app restarts
- ✅ No crashes or errors
- ✅ Logs show ✅ for all operations
- ✅ No PII in logs

**Ready for Live Activity if:**
- ✅ All above tests pass
- ✅ Hooks called (log messages visible)
- ✅ App Group preferences accessible

---

## 📋 Next Steps After Testing

### If All Tests Pass:

1. **Implement Live Activity** (2-3 hours)
   - Create `ios/DoseLiveActivity.swift`
   - Update `startLiveActivityIfEnabled()` and `endLiveActivity()`

2. **Add Notification Scheduling** (1-2 hours)
   - Create `ios/NotificationManager.swift`
   - Schedule at window start/half/end

3. **Physical Device Testing**
   - Test on iPhone SE (smallest)
   - Test on iPhone 15 Pro (largest)
   - Test Live Activity on Lock Screen

4. **TestFlight Beta**
   - Archive build
   - Upload to App Store Connect
   - Invite beta testers

### If Tests Fail:

1. **Check Console Logs**
   - Look for ❌ error messages
   - Note exact error description

2. **Check Xcode Issues**
   - Build errors
   - Runtime warnings

3. **File Bug Report**
   - Include: Steps to reproduce, expected vs. actual, logs
   - Location: `docs/ops/BUG_REPORT_[DATE].md`

---

**Version:** 1.1.1c  
**Last Updated:** November 2, 2025  
**Authority:** Constitution Principle I (Safety First)

**Quick Command:** `open -a Xcode DoseTrackIOS/DoseTrackIOS.xcodeproj`
