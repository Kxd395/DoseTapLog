# Device Testing Checklist - DoseTrack v1.1.2

**Build Version:** 1.1.2  
**Branch:** updates  
**Testing Date:** _____________  
**Device:** _____________  
**iOS Version:** _____________  

---

## 📋 Pre-Testing Setup

### 1. Deploy to Device
- [ ] Connect iPhone to Mac via USB
- [ ] Open `DoseTrackNew.xcodeproj` in Xcode
- [ ] Select your iPhone as the build target (top toolbar)
- [ ] Trust the developer certificate on iPhone (Settings → General → Device Management)
- [ ] Build and run (Cmd+R)
- [ ] App launches successfully

### 2. Enable Permissions
- [ ] Grant notification permission when prompted
- [ ] Verify "Notifications Allowed" in Settings → DoseTrack
- [ ] Grant HealthKit permission if prompted

### 3. Create Test Data
- [ ] Set bedtime to ~2 hours ago (for realistic testing)
- [ ] Log Dose 1 at bedtime
- [ ] Note current time for calculating windows

---

## 🧪 Feature Testing

### A. Dose 2 Gate System Testing (CRITICAL)

Test all 5 gate states with real-time scenarios:

#### State 1: `ready` (Within Window)
**Setup:** Wait until Dose 2 window is open (windowStartMin to windowEndMin after Dose 1)

- [ ] **Dose 2 button is ENABLED** (green, no caption)
- [ ] Tap "Dose 2" button
- [ ] Logs dose immediately (no sheet)
- [ ] **Haptic:** Feel `.success` notification feedback (3 distinct pulses)
- [ ] UndoBanner appears with 30s countdown
- [ ] Dose 2 timestamp shows in card
- [ ] Notification cancelled (if scheduled)

**Expected:** ✅ Instant logging, success haptic, undo window starts

---

#### State 2a: `tooEarly` (Within 30-Minute Override Limit)
**Setup:** Immediately after Dose 1 (before windowStartMin)

- [ ] **Dose 2 button is ENABLED** with caption "⚠️ Override early policy"
- [ ] Tap "Dose 2" button
- [ ] **EarlyDose2Sheet appears**
- [ ] Sheet shows:
  - [ ] "Dose 2 Early" title
  - [ ] Minutes early calculated correctly
  - [ ] "Why override early?" dropdown (collapsed)
  - [ ] Reason buttons: Medical Need, Sleep Schedule, Symptom Management, Side Effects, Other
- [ ] Select a reason (e.g., "Medical Need")
- [ ] Enter optional notes if desired
- [ ] Tap "Confirm Dose 2 (X.XX g)"
- [ ] **Haptic:** Feel `.heavy` impact feedback (single strong pulse)
- [ ] Sheet dismisses
- [ ] Dose 2 logged with override metadata
- [ ] UndoBanner appears
- [ ] CSV export includes: dose2IsOverride=true, dose2OverrideKind=early, dose2OverrideMinutes=X, dose2OverrideReason="Medical Need"

**Expected:** ✅ Override sheet, required reason, .heavy haptic on confirm, audit trail

---

#### State 2b: `tooEarly` (Beyond 30-Minute Override Limit)
**Setup:** Immediately after Dose 1, then change `AppPreferences.dose2EarlyLimitMin` to 5 minutes in code (or wait if you logged Dose 1 >30 min ago)

- [ ] **Dose 2 button is DISABLED** (gray, no interactions)
- [ ] Caption shows "🔒 Too early (opens in X min)" with countdown
- [ ] Tap "🔒 Too early" caption
- [ ] **Dose2BlockedSheet appears**
- [ ] Sheet shows:
  - [ ] "Dose 2 Too Early" title
  - [ ] Minutes early exceeds limit
  - [ ] Explanation of policy
  - [ ] "Notify Me at Window Start" button (if notification permission granted)
  - [ ] "Dismiss" button
- [ ] Tap "Notify Me at Window Start"
- [ ] **Haptic:** Feel `.light` impact feedback
- [ ] Notification scheduled confirmation appears
- [ ] Sheet dismisses
- [ ] Dose 2 button remains disabled

**Expected:** ✅ Hard block, no override allowed, notification scheduling works

---

#### State 3a: `tooLate` (Within 30-Minute Override Limit)
**Setup:** Wait until after windowEndMin (but within 30 min of end)

- [ ] **Dose 2 button is ENABLED** with caption "⚠️ Override late policy"
- [ ] Tap "Dose 2" button
- [ ] **LateDose2Sheet appears**
- [ ] Sheet shows:
  - [ ] "Dose 2 Late" title
  - [ ] Minutes late calculated correctly
  - [ ] "Why override late?" dropdown (collapsed)
  - [ ] Reason buttons: Forgot, Fell Asleep, Busy, Felt Fine, Other
- [ ] Select a reason (e.g., "Fell Asleep")
- [ ] Tap "Confirm Dose 2 (X.XX g)"
- [ ] **Haptic:** Feel `.heavy` impact feedback
- [ ] Sheet dismisses
- [ ] Dose 2 logged with override metadata
- [ ] UndoBanner appears
- [ ] CSV includes: dose2IsOverride=true, dose2OverrideKind=late, dose2OverrideMinutes=X, dose2OverrideReason="Fell Asleep"

**Expected:** ✅ Late override sheet, required reason, .heavy haptic, audit trail

---

#### State 3b: `tooLate` (Beyond 30-Minute Override Limit)
**Setup:** Wait >30 minutes past windowEndMin

- [ ] **Dose 2 button is DISABLED** (gray)
- [ ] Caption shows "🔒 Window closed (X min ago)"
- [ ] Tap "🔒 Window closed" caption
- [ ] **Dose2BlockedSheet appears** with late policy explanation
- [ ] No override allowed
- [ ] Only "Dismiss" button available
- [ ] Dose 2 button remains disabled

**Expected:** ✅ Hard block, no late override beyond limit

---

#### State 4: `needDose1` (No Dose 1 Logged)
**Setup:** Reset night (clear Dose 1)

- [ ] **Dose 2 button is DISABLED** (gray)
- [ ] Caption shows "Log Dose 1 first"
- [ ] Tap disabled Dose 2 button
- [ ] **NeedDose1Sheet appears**
- [ ] Sheet explains Dose 1 required
- [ ] "Go to Dose 1" button navigates to Dose 1 section
- [ ] Dose 2 remains disabled until Dose 1 logged

**Expected:** ✅ Dose 2 locked without Dose 1

---

#### State 5: `alreadyLogged` (Dose 2 Already Exists)
**Setup:** Log Dose 2, then try to log again

- [ ] **Dose 2 button is DISABLED** (gray)
- [ ] Caption shows "Already logged at HH:MM"
- [ ] Tap disabled button
- [ ] **AlreadyLoggedSheet appears**
- [ ] Sheet shows existing Dose 2 timestamp
- [ ] "View in Recent Events" button (if implemented)
- [ ] No option to log again (safety feature)

**Expected:** ✅ Prevents duplicate Dose 2 logging

---

### B. Undo Window Testing

- [ ] Log Dose 2 (any state)
- [ ] **UndoBanner appears** at bottom of screen
- [ ] Banner shows: "Logged Dose 2 (X.XX g)"
- [ ] Countdown: "Undo available for 30s"
- [ ] Timer counts down: 30 → 29 → 28... in real-time
- [ ] Tap "Undo" button at ~15 seconds
- [ ] **Haptic:** Feel `.light` impact feedback
- [ ] Dose 2 cleared from DoseLog
- [ ] Dose 2 timestamp removed
- [ ] Dose 2 button re-enabled (if in window)
- [ ] Banner disappears
- [ ] Timer stops

**Test Auto-Dismiss:**
- [ ] Log Dose 2 again
- [ ] DO NOT tap Undo
- [ ] Wait full 30 seconds
- [ ] Banner disappears automatically
- [ ] Dose 2 remains logged (permanent)

**Expected:** ✅ 30s countdown, undo restores state, auto-dismiss works

---

### C. Notification Testing

**Setup:** Log Dose 1, ensure time is before window start

- [ ] Open EarlyDose2Sheet (tap Dose 2 when too early)
- [ ] Tap "Notify Me at Window Start" button
- [ ] Confirmation message appears: "Notification scheduled for [time]"
- [ ] Sheet dismisses
- [ ] **Wait until window start time** (or advance system clock)
- [ ] **Notification appears** with:
  - [ ] Title: "Dose 2 Window Open"
  - [ ] Body: "Your Dose 2 window has started"
  - [ ] Sound/banner notification
- [ ] Tap notification → App opens to Tonight card
- [ ] Dose 2 button is now enabled

**Test Cancellation:**
- [ ] Schedule notification again
- [ ] Log Dose 2 BEFORE notification time
- [ ] Wait past scheduled notification time
- [ ] **No notification appears** (cancelled when logged)

**Expected:** ✅ Notification at exact window start, cancels on dose log

---

### D. Recent Events Testing

**Setup:** Create event history (bedtime, dose1, dose2, bathroom, wake)

- [ ] Scroll to "Recent Events" card
- [ ] **Last 5 events displayed** in reverse chronological order
- [ ] Each event shows:
  - [ ] Icon (🛏️ 💊 💊 🚽 ☀️)
  - [ ] Event name ("Bedtime", "Dose 1", "Dose 2", "Bathroom", "Wake")
  - [ ] Timestamp (formatted time)
  - [ ] Color coding (purple, blue, green, orange, yellow)
- [ ] Events are in correct order (newest first)

**Test Undo Last:**
- [ ] Tap "Undo Last" button
- [ ] **If recent event exists:**
  - [ ] Confirmation sheet appears: "Undo [event]?"
  - [ ] Tap "Confirm Undo"
  - [ ] Last event removed from log
  - [ ] Event disappears from Recent Events list
  - [ ] UndoBanner appears (30s to re-undo)
- [ ] **If no events:**
  - [ ] Button is disabled
  - [ ] Caption: "No events to undo"

**Test with Active Undo Window:**
- [ ] Log Dose 2 (starts undo window)
- [ ] "Undo Last" button becomes disabled
- [ ] Caption: "Wait for undo window to close"
- [ ] After 30s, button re-enables

**Expected:** ✅ Real data display, undo last works, disabled during active undo

---

### E. Accessibility Testing (VoiceOver)

**Enable VoiceOver:**
- [ ] Triple-click side button (or Settings → Accessibility → VoiceOver)
- [ ] VoiceOver announces: "VoiceOver on"

**Navigate Tonight Card:**
- [ ] Swipe right through elements
- [ ] **Dose 2 Button:**
  - [ ] Enabled: Reads "Dose 2. Button. Tap to dose 2."
  - [ ] Disabled (too early): Reads "Dose 2. Button. Currently disabled. Opens in 38 minutes."
  - [ ] Disabled (already logged): Reads "Dose 2. Button. Already logged at 2:30 AM."
- [ ] **Secondary Buttons:**
  - [ ] "Reset Night. Button. Tap to reset night."
  - [ ] "Undo Last. Button. Tap to undo last."
- [ ] **UndoBanner (when active):**
  - [ ] Reads: "Logged Dose 2 (4.25 g). Undo available for 15 seconds."
  - [ ] Undo button: "Undo. Button. Tap to undo the last action."

**Sheet Navigation:**
- [ ] Open EarlyDose2Sheet
- [ ] VoiceOver reads sheet title: "Dose 2 Early"
- [ ] Navigate through reason buttons
- [ ] Each button announces clearly: "Medical Need. Button."
- [ ] Confirm button: "Confirm Dose 2 (4.25 g). Button. Tap to confirm dose 2."

**Expected:** ✅ All elements have clear labels, hints explain actions, navigation is logical

---

### F. Dynamic Type Testing

- [ ] Settings → Display & Brightness → Text Size
- [ ] Move slider to **XXL (largest size)**
- [ ] Open DoseTrack app
- [ ] **Tonight Card:**
  - [ ] All text scales up (titles, chips, button labels)
  - [ ] Buttons remain tappable (56pt height maintained)
  - [ ] Text wraps to multiple lines if needed
  - [ ] No text truncated with "..."
  - [ ] Layout adapts (VStacks expand vertically)
- [ ] **Sheets:**
  - [ ] Sheet content scales
  - [ ] Reason buttons remain readable
  - [ ] Confirm button text doesn't overflow

**Expected:** ✅ App remains usable at XXL text size, no truncation

---

## 📊 Test Results Summary

### Critical Issues Found
_Record any blocking bugs or safety issues:_

1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

### Minor Issues Found
_Record UI glitches or non-critical bugs:_

1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

### Features Working Correctly
- [ ] Dose 2 gate system (all 5 states)
- [ ] Haptic feedback (heavy/success/light)
- [ ] Notification scheduling
- [ ] Undo window (30s countdown)
- [ ] Recent Events display
- [ ] VoiceOver accessibility
- [ ] Dynamic Type scaling

### Test Coverage
- **Gate States Tested:** _____ of 5 (100% required)
- **Haptics Verified:** _____ of 3 types
- **Notifications Working:** Yes ☐ No ☐
- **Accessibility Passed:** Yes ☐ No ☐

---

## ✅ Sign-Off

**Tested By:** _____________  
**Date:** _____________  
**Ready for Production:** Yes ☐ No ☐  
**Notes:** _______________________________________________

---

## 🚀 Next Steps After Testing

If all tests pass:
- [ ] Merge `updates` branch to `main`
- [ ] Tag release: `git tag v1.1.2`
- [ ] Push to remote: `git push origin main --tags`
- [ ] Archive build for App Store/TestFlight
- [ ] Update `docs/CHANGELOG.md` with v1.1.2 features

If issues found:
- [ ] Document bugs in GitHub Issues
- [ ] Fix critical bugs on `updates` branch
- [ ] Re-test after fixes
- [ ] Repeat sign-off process
