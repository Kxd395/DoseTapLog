# Next Steps: Wake Event Integration

## Current State

✅ **Basic wake tracking is already working** in your app:
- "Alarm wake" button logs alarm wake events
- "Bathroom" button logs bathroom events
- Wake status appears in status badges ("Wake: manual")

✅ **Enhanced wake tracking code is committed** (commit adf4cb3):
- `ios/WakeReason.swift` - 11 wake reasons with icons
- `ios/WakeSheetView.swift` - UI sheet for detailed wake logging
- `ios/TodayViewModel+WakeEvents.swift` - Enhanced wake logic
- Database migration for clinical tracking

## What You Need to Do

### 1. Add New Files to Xcode Project

**In Xcode:**
1. Open `DoseTrackNew/DoseTrackNew.xcodeproj`
2. In Project Navigator, right-click on the `DoseTrackNew` folder
3. Select "Add Files to DoseTrackNew..."
4. Navigate to the `ios/` folder
5. Select these 3 files:
   - `WakeReason.swift`
   - `WakeSheetView.swift`
   - `TodayViewModel+WakeEvents.swift`
6. **Important:** Uncheck "Copy items if needed" (files are already in correct location)
7. **Important:** Check "DoseTrackNew" target
8. Click "Add"
9. Build (⌘B) to verify compilation

### 2. Update TodayLogView to Use New Wake Sheet

**Current behavior:**
- "Alarm wake" button → instantly logs alarm wake
- "Bathroom" button → instantly logs bathroom event

**New behavior with wake sheet:**
- "Alarm wake" button → **opens sheet** asking if alarm interrupted sleep, allows marking as final wake
- "Wake now" button (new) → **opens sheet** with all 11 wake reasons
- "Final wake" button (long press) → **opens sheet** with "final wake" pre-selected

**Code changes needed in `ios/TodayLogView.swift`:**

```swift
// Add these @State variables near the top
@State private var showWakeSheet = false
@State private var wakeSheetIsFinalPreset = false
@State private var wakeSheetReasonPreset: WakeReason? = nil

// Update the Events section buttons:
HStack {
    // Keep existing button but open sheet instead
    Button("Alarm wake") {
        wakeSheetReasonPreset = .alarm
        wakeSheetIsFinalPreset = false
        showWakeSheet = true
    }
    .buttonStyle(.bordered)
    
    Button("Bathroom") {
        wakeSheetReasonPreset = .bathroom
        wakeSheetIsFinalPreset = false
        showWakeSheet = true
    }
    .buttonStyle(.bordered)
}

// Add a new "Wake now" button for generic wake tracking
HStack {
    Button("Wake now") {
        wakeSheetReasonPreset = nil  // No preset, user chooses
        wakeSheetIsFinalPreset = false
        showWakeSheet = true
    }
    .buttonStyle(.bordered)
    
    // Add long-press to existing "Final wake" button
    Button("Final wake") {
        wakeSheetReasonPreset = nil
        wakeSheetIsFinalPreset = true
        showWakeSheet = true
    }
    .buttonStyle(.bordered)
    .onLongPressGesture {
        // Long press opens sheet with final wake preset
        wakeSheetReasonPreset = nil
        wakeSheetIsFinalPreset = true
        showWakeSheet = true
    }
}

// Add the sheet at the end of the NavigationStack body
.sheet(isPresented: $showWakeSheet) {
    WakeSheetView(
        isPresented: $showWakeSheet,
        reasonPreset: wakeSheetReasonPreset,
        isFinalPreset: wakeSheetIsFinalPreset
    ) { reason, isFinal, wasAlarmInterrupted, time, note in
        vm.logWakeNow(
            reason: reason,
            isFinal: isFinal,
            wasAlarmInterrupted: wasAlarmInterrupted,
            overrideTime: time,
            note: note
        )
    }
}
```

### 3. Run Database Migration

The new wake tracking needs 3 database columns. Run this SQL migration:

**File:** `server/migrations/004_wake_event_tracking.sql`

**How to run:**
- If you have database migration code in your app, it should auto-run on next launch
- Or manually execute the SQL in your SQLite database

**Columns added:**
- `wake_reason` TEXT - One of 11 clinical reasons
- `was_alarm_interrupted` INTEGER - Did alarm interrupt sleep?
- `is_final` INTEGER - Was this the final wake?

**Safety:** Database trigger prevents logging multiple "final wakes" per night

### 4. Test the New Features

**Test checklist:**

1. **Quick alarm wake:**
   - Tap "Alarm wake" → Sheet opens
   - Toggle "Alarm interrupted" → ON
   - Tap "Confirm" → Wake logged with reason "alarm"

2. **Generic wake with reason:**
   - Tap "Wake now" → Sheet opens
   - Select reason (e.g., "Noise", "Pain", "Dose recoil")
   - Add optional note
   - Tap "Confirm" → Wake logged

3. **Final wake:**
   - Long-press "Final wake" → Sheet opens with "Final wake" toggle ON
   - Select reason (e.g., "Natural")
   - Tap "Confirm" → Wake logged, Live Activity ends, notifications cancelled

4. **Time editing:**
   - Log a wake event
   - Try editing time → Should clamp to last 15 minutes

5. **Duplicate final wake prevention:**
   - Log a final wake
   - Try logging another final wake → Should fail with error

6. **Event strip:**
   - After logging wakes, check event strip shows icons for wake reasons

## Benefits You'll See

### Clinical Insights
- **Track why you wake up** (natural, alarm, bathroom, pain, anxiety, etc.)
- **Correlate wake reasons with dose timing** (was it dose recoil?)
- **Export to CSV** for clinician review

### Better Sleep Analysis
- See patterns: Do you always wake at 3am? Why?
- Track alarm interruptions vs. natural wakes
- Identify problematic wake reasons (pain, anxiety, nightmares)

### Dosing Optimization
- If waking from "dose recoil" → Adjust dose 2 timing
- If waking from "pain" → Dose might be too low
- Track correlation between dose timing and wake quality

## What's Already Working

Your current app already has:
- ✅ Basic wake tracking ("Alarm wake", "Bathroom" buttons)
- ✅ Wake status display ("Wake: manual")
- ✅ TodayViewModel with wake methods

The new code adds:
- 📊 **11 clinical wake reasons** instead of just "alarm" and "bathroom"
- 🎯 **Final wake detection** with automatic cleanup
- 📝 **Optional notes** for each wake event
- 💾 **Database storage** for long-term analysis
- 📈 **CSV export** for clinical review

## Summary

**You're seeing:** Basic wake tracking (already works)  
**We just added:** Enhanced wake tracking with clinical context  
**To activate:** Add 3 files to Xcode, update UI, run migration  

The screenshot you shared shows the app is **working correctly** - those wake buttons are functional! The new code gives you deeper clinical insights into *why* you're waking up.
