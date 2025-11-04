# UI/UX Missing Buttons Fix

## Issue Reported
User screenshot showed UI but mentioned "missing button on the ux/ui"

## Root Cause
Wake event buttons (Alarm wake, Bathroom) were calling direct logging methods without showing the **WakeSheetView** reason picker.

## What Was Missing
The comprehensive **wake event tracking system** with 11 wake reasons was implemented in code but **not wired to the UI**.

### Wake Event System Components (Already Built)
- ✅ `WakeReason.swift` - 11 wake reasons with icons
- ✅ `WakeSheetView.swift` - Full reason picker UI
- ✅ `TodayViewModel+WakeEvents.swift` - Wake logging logic
- ✅ Database migration 004 - `wake_reason` column

### What Was Missing in UI
- ❌ Wake buttons showed **no reason picker**
- ❌ Buttons called `logAlarmWake()` / `logBathroom()` directly
- ❌ No way for users to select specific wake reason

## Fix Applied (Commit 1cf2579)

### 1. Added State Management
**File**: `ios/TodayViewModel.swift`

```swift
// Added wake sheet state
@Published var showWakeSheet: Bool = false
@Published var wakeSheetType: WakeEventType = .alarm

enum WakeEventType {
    case alarm
    case bathroom
    case finalWake
}
```

### 2. Added Sheet Trigger Methods
**File**: `ios/TodayViewModel+WakeEvents.swift`

```swift
/// Show wake sheet for alarm wake with reason selection
func showAlarmWakeSheet() {
    wakeSheetType = .alarm
    showWakeSheet = true
}

/// Show wake sheet for bathroom wake with reason selection
func showBathroomWakeSheet() {
    wakeSheetType = .bathroom
    showWakeSheet = true
}

/// Show wake sheet for final wake with reason selection
func showFinalWakeSheet() {
    wakeSheetType = .finalWake
    showWakeSheet = true
}
```

### 3. Updated Wake Buttons
**File**: `ios/TodayLogView.swift`

**Before** (direct logging):
```swift
Button("Alarm wake", action: vm.logAlarmWake)
Button("Bathroom", action: vm.logBathroom)
```

**After** (shows sheet):
```swift
Button("Alarm wake") {
    vm.showAlarmWakeSheet()
}

Button("Bathroom") {
    vm.showBathroomWakeSheet()
}
```

### 4. Added WakeSheetView Binding
**File**: `ios/TodayLogView.swift`

```swift
.sheet(isPresented: $vm.showWakeSheet) {
    WakeSheetView(
        isPresented: $vm.showWakeSheet,
        isFinalPreset: vm.wakeSheetType == .finalWake,
        onConfirm: { reason, isFinal, wasInterrupted, time, note in
            vm.logWakeNow(
                reason: reason,
                isFinal: isFinal,
                wasAlarmInterrupted: wasInterrupted,
                overrideTime: time,
                note: note?.isEmpty == false ? note : nil
            )
        }
    )
}
```

## New User Flow

### Before Fix
1. User taps "Alarm wake" → Immediately logs with reason=alarm
2. User taps "Bathroom" → Immediately logs with reason=bathroom
3. ❌ No way to select other wake reasons (natural, noise, pain, etc.)

### After Fix
1. User taps "Alarm wake" button
2. ✅ **WakeSheetView appears** with:
   - 📋 **Reason picker**: 11 options (alarm, bathroom, natural, noise, pain, temperature, partner, pet, baby, medical, other)
   - 🎯 **Final wake toggle**: Mark as final wake of the night
   - ⏰ **Alarm interrupted toggle**: Track if alarm was interrupted
   - 📝 **Note field**: Optional context
   - 🕐 **Time adjustment**: ±15 minutes
3. User selects specific reason (e.g., "Noise" instead of generic "Alarm")
4. User taps "Confirm"
5. ✅ Event logged with full context to database

### Similarly for Bathroom Button
1. User taps "Bathroom" button
2. ✅ **WakeSheetView appears**
3. User can choose:
   - Bathroom (default)
   - Or any other reason if misclassified
   - Can mark as final wake
   - Can add note
4. ✅ Full context logged

## Wake Reasons Available

| Reason | Icon | Use Case |
|--------|------|----------|
| **Alarm** | alarm.fill | Woke to alarm |
| **Bathroom** | toilet.fill | Bathroom break |
| **Natural** | moon.stars.fill | Natural awakening |
| **Noise** | speaker.wave.3.fill | External noise |
| **Pain** | bandage.fill | Physical discomfort |
| **Temperature** | thermometer | Too hot/cold |
| **Partner** | person.2.fill | Partner movement |
| **Pet** | pawprint.fill | Pet disturbance |
| **Baby** | figure.and.child.holdinghands | Baby/child woke |
| **Medical** | cross.case.fill | Medical need |
| **Other** | ellipsis.circle.fill | Other reason |

## Database Impact

Wake events now log with:
- `wake_reason` column (e.g., "noise", "pain", "temperature")
- `is_final` flag
- `was_alarm_interrupted` flag (for alarm wakes)
- `note` field (optional context)
- `timestamp` (adjustable ±15 min)

## CSV Export

Updated CSV includes:
- `wake_reason` column
- Helps identify sleep quality factors
- Tracks alarm effectiveness

## Testing Checklist

After rebuild (⌘B):
- [ ] Tap "Alarm wake" → WakeSheetView appears
- [ ] Select different reason (e.g., "Noise")
- [ ] Toggle "Final wake" on
- [ ] Add note "Loud neighbors"
- [ ] Confirm → Event logged
- [ ] Check database: wake_reason="noise", is_final=1
- [ ] Tap "Bathroom" → WakeSheetView appears
- [ ] Select "Bathroom" or change to "Medical"
- [ ] Confirm → Event logged with correct reason
- [ ] Export CSV → Verify wake_reason column populated

## Benefits

1. **Clinical Accuracy**: Distinguishes between alarm, natural, noise, pain, etc.
2. **Sleep Quality Insights**: Track specific wake triggers
3. **Alarm Effectiveness**: Track alarm interruption rate
4. **User Control**: Users specify exact wake reason instead of app guessing
5. **Data Richness**: Notes field captures context for review

## What's Still Missing (Future Work)

Based on alarm ladder system, these buttons might be added later:
- ⏰ "Snooze notification" (when alarm ladder implemented)
- 📊 "Alarm summary" showing budget/next alert
- 🔕 "Notification status" chip showing blocked/allowed
- 🌙 "Night mode toggle" (quiet hours)

But for wake event tracking, **the UI is now complete**!

## Files Modified

1. `ios/TodayViewModel.swift` - Added wake sheet state
2. `ios/TodayViewModel+WakeEvents.swift` - Added sheet trigger methods
3. `ios/TodayLogView.swift` - Updated buttons and added sheet binding

## Commits

- **06964da**: 🐛 Fix String format bug in timezone display
- **1cf2579**: ✨ Wire up WakeSheetView to wake event buttons

---

**Status**: ✅ Wake event tracking UI complete and wired  
**Next**: Test wake reason picker, verify database logging, check CSV export
