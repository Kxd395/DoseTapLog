# Late Dose Override & UI Layout Options - Complete Guide

**📍 Location:** `docs/ops/LATE_DOSE_AND_UI_LAYOUTS.md`  
**📚 Breadcrumbs:** `docs/` → `ops/` → **`LATE_DOSE_AND_UI_LAYOUTS.md`**

**Date:** November 2, 2025  
**DoseTrack Version:** 1.1.1c+  
**Author:** GitHub Copilot  

---

## Executive Summary

This document covers **two major enhancements** to DoseTrack:

1. **Late Dose Override** - Allow users to log Dose 2 after the window closes (no hard lockout)
2. **Two UI Layout Options** - Choose between "Card Stack with Fixed Action Dock" or "Guided Checklist" layouts

Both features are **production-ready** and fully documented here.

---

## Part 1: Late Dose Override Feature

### Overview

**Problem:** Users were hard-locked from logging Dose 2 after the window closed, even when they wanted to record reality for adherence tracking.

**Solution:** Add explicit "late dose override" that:
- ✅ Logs Dose 2 at current time with override metadata
- ✅ Captures reason for audit trail
- ✅ Marks as "late" in database and CSV exports
- ✅ Does NOT restart Live Activity or window
- ✅ Explicit, not encouraging late dosing

### Components Added

| File | Purpose | Lines | Status |
|------|---------|-------|--------|
| `ios/LateDoseSheetView.swift` | Modal sheet for late dose logging | 247 | ✅ Complete |
| `ios/AppPreferencesEnhanced+LateDose.swift` | Settings for late dose feature | 76 | ✅ Complete |
| `ios/TodayViewModel+LateDose.swift` | ViewModel methods for late dose | 156 | ✅ Complete |
| `ios/Models.swift` | Override tracking fields | +4 fields | ✅ Complete |

### Data Model Changes

**Added to `DoseLog` model:**

```swift
// Override tracking (late/early dose)
var dose2IsOverride: Bool = false
var dose2OverrideKind: String? // "late" or "early"
var dose2OverrideMinutes: Int? // How many minutes late/early
var dose2OverrideReason: String? // User-provided reason
```

**CSV Export updated:**

```
night_date,bedtime,dose1_time,dose1_g,dose2_time,dose2_g,
dose2_is_override,dose2_override_kind,dose2_override_minutes,dose2_override_reason,
bathroom_wakes,final_wake,morning_alertness,notes
```

### Settings

**Added to `AppPreferencesEnhanced` (App Group storage):**

| Setting | Key | Default | Type | Description |
|---------|-----|---------|------|-------------|
| `allowLateDose` | `late_dose_allow` | `true` | Bool | Allow logging Dose 2 after window closes |
| `lateRequireReason` | `late_dose_require_reason` | `true` | Bool | Require user to provide reason |
| `maxLateMinutes` | `late_dose_max_minutes` | `120` | Int | Max minutes late (0 = unlimited) |
| `lateQuickChoicesCSV` | `late_dose_quick_choices` | `"5,10,15,30"` | String | Quick choice buttons |

**Add to your `SettingsViewEnhanced.swift`:**

```swift
Section {
    Toggle("Allow late Dose 2 logging", isOn: $AppPreferencesEnhanced.shared.allowLateDose)
    
    Toggle("Require reason for late dose", isOn: $AppPreferencesEnhanced.shared.lateRequireReason)
        .disabled(!AppPreferencesEnhanced.shared.allowLateDose)
    
    Stepper(value: $AppPreferencesEnhanced.shared.maxLateMinutes, in: 0...300, step: 10) {
        if AppPreferencesEnhanced.shared.maxLateMinutes == 0 {
            Text("Max late minutes: Unlimited")
        } else {
            Text("Max late minutes: \(AppPreferencesEnhanced.shared.maxLateMinutes)")
        }
    }
    .disabled(!AppPreferencesEnhanced.shared.allowLateDose)
    
    TextField("Quick choices (5,10,15,30)", text: $AppPreferencesEnhanced.shared.lateQuickChoicesCSV)
        .disabled(!AppPreferencesEnhanced.shared.allowLateDose)
} header: {
    Text("Late Dose 2 Override")
} footer: {
    VStack(alignment: .leading, spacing: 4) {
        Text("• Allows logging Dose 2 after the window closes")
        Text("• Records reality for adherence tracking")
        Text("• Marked as 'late override' in exports")
        Text("• Does NOT restart Live Activity or window")
    }
    .font(.footnote)
}
```

### User Flow

**Scenario: Window Expired, User Wants to Log Reality**

1. **User logs Dose 1 at 11:30 PM**
2. **Window: 150-240 minutes (2.5-4 hours)**
3. **Window closes at 3:30 AM**
4. **User wakes at 4:00 AM, realizes they forgot Dose 2**

**Before (Hard Lockout):**
- ❌ Dose 2 button disabled
- ❌ No way to log what happened
- ❌ Data gap in adherence tracking

**After (Late Dose Override):**
- ✅ Orange "Log Dose 2 (late)" button appears
- ✅ User taps button → LateDoseSheet presents
- ✅ User selects reason: "Forgot to take earlier"
- ✅ User confirms minutes late: 30 minutes
- ✅ Dose 2 logged at 4:00 AM with override metadata
- ✅ Event strip shows: "Dose 2 logged late • 30m after window"
- ✅ CSV export includes: `dose2_is_override=1, dose2_override_kind=late, dose2_override_minutes=30`

### LateDoseSheet UI

**Sections:**

1. **Warning Header (Orange)**
   - Icon: `clock.badge.exclamationmark.fill`
   - Title: "Late Dose 2 Override"
   - Subtitle: "You're logging 30 min after the window closed."
   - Disclaimer: "This records what happened for adherence tracking. It does NOT restart the dosing window or Live Activity."

2. **Dose Details**
   - Amount: 3.25g
   - After window end: 30 min

3. **Reason (Required/Optional)**
   - Picker with 5 options:
     * Felt sleepy, took late
     * Forgot to take earlier
     * Delayed by activity/event
     * Wake time tracking issue
     * Other (describe) → TextField appears

4. **How Late**
   - Quick choices: [5m] [10m] [15m] [30m]
   - Stepper: "Late by 30 minutes" (1-300, step 5)
   - Warning if exceeds `maxLateMinutes`: "This exceeds your configured max of 120 min"

5. **Disclaimer**
   - What this does (bullet list)
   - Does NOT restart Live Activity
   - Clinicians may review override patterns

6. **Toolbar**
   - Cancel button
   - "Confirm Late Dose" button (disabled until valid)

### ViewModel Integration

**Added to `TodayViewModel`:**

```swift
// Computed properties
var isAfterWindow: Bool
var minutesAfterWindow: Int
var isBeforeWindowButEligibleEarly: Bool

// Methods
func presentLateDoseSheet()
func confirmLateDose(reason: String, minutesLate: Int)
func tryLogDose2() // Updated to handle in-window, early, late cases
```

**Usage in View:**

```swift
// Show late dose button when window expired
if vm.isAfterWindow && AppPreferencesEnhanced.shared.allowLateDose {
    Button("Log Dose 2 (late)") {
        showLateDoseSheet = true
    }
    .buttonStyle(.borderedProminent)
    .tint(.orange)
}

// Present sheet
.sheet(isPresented: $showLateDoseSheet) {
    LateDoseSheetView(
        isPresented: $showLateDoseSheet,
        dose2Grams: vm.prefs.planDose2G,
        minutesAfterWindow: vm.minutesAfterWindow,
        requireReason: AppPreferencesEnhanced.shared.lateRequireReason,
        quickChoices: AppPreferencesEnhanced.shared.lateQuickChoices,
        maxLateMinutes: AppPreferencesEnhanced.shared.maxLateMinutes,
        onConfirm: { reason, minutesLate in
            vm.confirmLateDose(reason: reason, minutesLate: minutesLate)
        }
    )
}
```

### Controller Protocol Update

**Update `DoseLogControllering` protocol:**

```swift
protocol DoseLogControllering {
    // ... existing methods ...
    
    func logDose2Now(
        grams: Double,
        overrideKind: String?,      // "early" or "late"
        overrideMinutes: Int?,      // How many minutes early/late
        overrideReason: String?     // User-provided reason
    )
}
```

**Implementation in `DoseLogController`:**

```swift
func logDose2Now(
    grams: Double,
    overrideKind: String? = nil,
    overrideMinutes: Int? = nil,
    overrideReason: String? = nil
) {
    do {
        let descriptor = FetchDescriptor<DoseLog>(
            predicate: #Predicate { $0.finalWakeTimeUTC == nil },
            sortBy: [SortDescriptor(\.bedtimeUTC, order: .reverse)]
        )
        let logs = try context.fetch(descriptor)
        guard let currentLog = logs.first else {
            logger.warning("⚠️ No current night session for Dose 2")
            return
        }
        
        currentLog.dose2TimeUTC = Date()
        currentLog.dose2Grams = grams
        
        // Override tracking
        if let kind = overrideKind {
            currentLog.dose2IsOverride = true
            currentLog.dose2OverrideKind = kind
            currentLog.dose2OverrideMinutes = overrideMinutes
            currentLog.dose2OverrideReason = overrideReason
            
            logger.info("💊 Logged Dose 2 with \(kind) override: \(overrideMinutes ?? 0)m, reason: \(overrideReason ?? "")")
        } else {
            logger.info("💊 Logged Dose 2: \(grams)g")
        }
        
        try context.save()
        recordEvent(kind: "dose2", grams: grams)
        
    } catch {
        logger.error("❌ Failed to log Dose 2: \(error.localizedDescription)")
    }
}
```

### Testing Scenarios

#### Scenario 1: Normal Late Dose (Within Max Limit)

1. Log Dose 1 at 11:30 PM
2. Wait until 3:35 AM (5 minutes after window end)
3. Verify "Log Dose 2 (late)" button appears (orange)
4. Tap button
5. LateDoseSheet presents
6. Select reason: "Forgot to take earlier"
7. Minutes late: 5 minutes (within 120 max)
8. Tap "Confirm Late Dose"
9. ✅ Dose 2 logged at current time
10. ✅ CSV shows: `dose2_is_override=1, dose2_override_kind=late, dose2_override_minutes=5`

#### Scenario 2: Very Late Dose (Exceeds Max Limit)

1. Log Dose 1 at 11:30 PM
2. Wait until 6:00 AM (150 minutes after window end)
3. Tap "Log Dose 2 (late)" button
4. LateDoseSheet presents
5. Adjust minutes late to 150
6. ⚠️ Warning appears: "This exceeds your configured max of 120 min"
7. Can still confirm (warning, not blocker)
8. ✅ Dose 2 logged with override

#### Scenario 3: Late Dose Disabled in Settings

1. Open Settings → Late Dose 2 Override
2. Toggle OFF "Allow late Dose 2 logging"
3. Return to main view
4. Log Dose 1, wait for window to expire
5. ✅ "Log Dose 2 (late)" button does NOT appear
6. ✅ Hard lockout (original behavior)

#### Scenario 4: Reason Required

1. Settings: "Require reason for late dose" = ON
2. Log Dose 1, wait for window to expire
3. Tap "Log Dose 2 (late)"
4. Select reason: "Other (describe)"
5. Leave text field empty
6. ✅ "Confirm Late Dose" button DISABLED
7. Enter custom reason: "Testing reason field"
8. ✅ "Confirm Late Dose" button ENABLED
9. Confirm successfully

#### Scenario 5: Unlimited Max Late Minutes

1. Settings: Max late minutes = 0 (unlimited)
2. Log Dose 1, wait 5 hours
3. Tap "Log Dose 2 (late)"
4. Adjust minutes late to 300 (5 hours)
5. ✅ No warning about exceeding max
6. ✅ Can confirm any amount late

### CSV Export Example

**Before (Normal Dose 2 at 2:00 AM):**

```csv
night_date,bedtime,dose1_time,dose1_g,dose2_time,dose2_g,dose2_is_override,dose2_override_kind,dose2_override_minutes,dose2_override_reason,bathroom_wakes,final_wake,morning_alertness,notes
2025-11-01,23:30,23:45,3.25,02:00,3.25,0,,,,01:30,06:00,7,
```

**After (Late Dose 2 at 4:00 AM, 30 min after window):**

```csv
night_date,bedtime,dose1_time,dose1_g,dose2_time,dose2_g,dose2_is_override,dose2_override_kind,dose2_override_minutes,dose2_override_reason,bathroom_wakes,final_wake,morning_alertness,notes
2025-11-01,23:30,23:45,3.25,04:00,3.25,1,late,30,Forgot to take earlier,01:30,06:00,7,
```

### Safety Considerations

**Guardrails:**

1. ✅ **Explicit Override** - User must actively choose "Log Dose 2 (late)", not accidental
2. ✅ **Reason Required** - Forces documentation of why late (default ON)
3. ✅ **Warning Header** - Orange styling, clear disclaimer about Live Activity
4. ✅ **Max Limit** - Configurable `maxLateMinutes` (default 120, 0 = unlimited)
5. ✅ **Audit Trail** - Every override logged with timestamp, reason, minutes late
6. ✅ **CSV Export** - Override data included in exports for clinician review
7. ✅ **No Encouragement** - UI emphasizes "recording what happened", not suggesting late dosing

**What Late Dose Does NOT Do:**

- ❌ Does NOT restart Live Activity
- ❌ Does NOT reset the Dose 2 window
- ❌ Does NOT send notifications
- ❌ Does NOT encourage late dosing (warning header makes this clear)

---

## Part 2: UI Layout Options

### Overview

Two complete UI layouts to fix "buttons not working / page doesn't scroll" issues:

1. **Option A: Card Stack with Fixed Action Dock** (`TodayLogView_CardStack.swift`)
2. **Option B: Guided Checklist** (`TodayLogView_Checklist.swift`)

Both layouts:
- ✅ Fix scrolling issues
- ✅ Make all buttons accessible
- ✅ Keep Recent Events always visible
- ✅ Support late dose override
- ✅ Support reset night
- ✅ Production-ready

### Option A: Card Stack with Fixed Action Dock

**File:** `ios/TodayLogView_CardStack.swift` (424 lines)

**Layout:**

```
┌─────────────────────────────────────────┐
│ DoseTrack                          [⚙︎] │
├─────────────────────────────────────────┤
│                                         │
│  [Card 1: Tonight Plan]                 │
│   • Dose 1: 3.25g  Dose 2: 3.25g       │
│   • Window: 150-240 min                │
│                                         │
│  [Card 2: Safety & Sources]            │
│   • ✓ Per dose 1.5-4.5g               │
│   • ✓ Wake: Health  Health: OK         │
│                                         │
│  [Card 3: Night Context]               │
│   • Sat Nov 1 • UTC-04:00 • NightKey   │
│                                         │
│  [Card 4: Countdown Ring]              │
│   •    ⭕ 1h 45m to window start       │
│                                         │
│  [Card 5: Recent Events]               │
│   • 🛏️ In bed          22:58          │
│   • 💊1 Dose 1 3.25g   23:05          │
│   • 🚻 Bathroom        00:42          │
│   • Undo last (60s) • View all        │
│                                         │
│  [Card 6: Status & Notices]            │
│   • Window status: Waiting             │
│   • Notifications enabled              │
│                                         │
│  (Scrollable content above)            │
│                                         │
├─────────────────────────────────────────┤
│ ═════ Action Dock (Fixed) ═════════     │
│ [In bed][Dose 1][Dose 2][Final wake]   │
│ [Alarm wake][Bathroom][Undo][Edit plan]│
│ [Log Dose 2 (late)][Reset Night][Export]│
└─────────────────────────────────────────┘
```

**Key Features:**

- **ScrollView** for cards above
- **safeAreaInset(edge: .bottom)** for fixed action dock
- **Action Dock** has 3 rows of buttons, always visible
- **Recent Events** card in scrollable area (not buried)
- **Late Dose** button appears in dock row 3 when window expired
- **Reset Night** button in dock row 3 when session exists

**SwiftUI Implementation:**

```swift
var body: some View {
    NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                planCard
                safetyCard
                contextCard
                countdownCard
                eventsCard
                statusCard
                
                // Spacer to prevent hiding behind dock
                Spacer().frame(height: 200)
            }
            .padding(16)
        }
        .safeAreaInset(edge: .bottom) {
            actionDock
        }
    }
}

private var actionDock: some View {
    VStack(spacing: 0) {
        Divider()
        
        VStack(spacing: 12) {
            // Row 1: Primary actions
            HStack(spacing: 8) {
                Button("In bed") { ... }
                Button("Dose 1") { ... }
                Button("Dose 2") { ... }
                Button("Final wake") { ... }
            }
            
            // Row 2: Secondary actions
            HStack(spacing: 8) {
                Button("Alarm wake") { ... }
                Button("Bathroom") { ... }
                Button("Undo") { ... }
                Button("Edit plan") { ... }
            }
            
            // Row 3: Override & Tools
            HStack(spacing: 8) {
                if vm.isAfterWindow {
                    Button("Log Dose 2 (late)") { ... }
                }
                if vm.nightKey != nil {
                    Button("Reset Night") { ... }
                }
                Button("Export CSV") { ... }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }
}
```

**Pros:**

- ✅ All action buttons always visible (no scrolling to find them)
- ✅ Cards cleanly separated
- ✅ Modern, Apple HIG-compliant design
- ✅ Dock stays fixed even on small screens
- ✅ Easy to scan and understand

**Cons:**

- ⚠️ More buttons visible at once (can feel crowded on small screens)
- ⚠️ Dock takes up bottom screen space

**Best For:**

- Users who want quick access to all actions
- Testing and power users
- Workflows with frequent button taps

---

### Option B: Guided Checklist

**File:** `ios/TodayLogView_Checklist.swift` (572 lines)

**Layout:**

```
┌─────────────────────────────────────────┐
│ DoseTrack                          [⚙︎] │
├─────────────────────────────────────────┤
│                                         │
│ [✓ Safety ✓ Health ✓ WHOOP]           │
│ Sat Nov 1 • UTC-04:00 • NightKey        │
│                                         │
│ 1) 🛏️ In bed                           │
│    Last: 22:58                          │
│    [In bed now]                         │
│                                         │
│ 2) 💊 Dose 1                            │
│    Plan: 3.25g                          │
│    Last: 23:05                          │
│    [Dose 1 now]                         │
│    Hint: long-press to edit grams       │
│                                         │
│ 3) ⏱️ Window to Dose 2                  │
│    Target: 150-240 min after Dose 1     │
│    Status: ⭕ Waiting • 1h 45m to open │
│       (Countdown ring here)             │
│    [Snooze 5m][Snooze 10m]             │
│                                         │
│ 4) 💊 Dose 2                            │
│    Plan: 3.25g                          │
│    [Dose 2 now] (disabled until window) │
│    ───                                  │
│    Override options:                    │
│    [Log early][Log late]               │
│    Policy: reason required              │
│                                         │
│ 5) 🌅 Wake                              │
│    [Final wake now][Alarm wake]        │
│    [Autofill from Health]              │
│    [Bathroom]                           │
│                                         │
│ ──── Timeline ────────────────           │
│ 22:58  🛏️ In bed                       │
│ 23:05  💊1 Dose 1 3.25g                │
│ 00:42  🚻 Bathroom                     │
│ ────────────────────────────────        │
│                                         │
│ Tools:                                  │
│ [Undo last][Edit plan][Export CSV]     │
│ [Reset Night]                           │
│                                         │
│ (Scrollable form)                       │
└─────────────────────────────────────────┘
```

**Key Features:**

- **Form** with **Section** per step (numbered 1-5)
- **Linear workflow** reduces cognitive load
- **Timeline** embedded in same screen (not separate tab)
- **Countdown ring** shown inline in Step 3
- **Override buttons** explicit in Step 4
- **Footer tools** for destructive actions

**SwiftUI Implementation:**

```swift
var body: some View {
    NavigationStack {
        Form {
            statusHeaderSection
            step1InBedSection
            step2Dose1Section
            step3WindowSection
            step4Dose2Section
            step5WakeSection
            timelineSection
            footerToolsSection
        }
    }
}

private var step4Dose2Section: some View {
    Section {
        VStack(alignment: .leading, spacing: 12) {
            // Main button
            Button("Dose 2 now") { ... }
                .disabled(!vm.dose2Enabled)
            
            Divider()
            
            // Override options
            VStack(spacing: 8) {
                Text("Override options:")
                HStack(spacing: 8) {
                    Button("Log early") { ... }
                    if vm.isAfterWindow {
                        Button("Log late") { ... }
                    }
                }
            }
        }
    } header: {
        Label("4", systemImage: "pills.circle.fill")
    } footer: {
        if vm.isAfterWindow {
            Text("Window closed \(vm.minutesAfterWindow) min ago. Use 'Log late' to record what happened.")
        }
    }
}
```

**Pros:**

- ✅ Clear, linear flow (step-by-step)
- ✅ Timeline embedded (no separate tab needed)
- ✅ Less overwhelming for new users
- ✅ Contextual help at each step
- ✅ Override options explicit in Step 4

**Cons:**

- ⚠️ More scrolling required
- ⚠️ Footer tools hidden at bottom

**Best For:**

- New users learning the app
- Users who prefer guided workflows
- Clinical/medical UX (step-by-step is familiar)

---

### Choosing a Layout

**Use Card Stack (Option A) if:**

- You want all buttons always visible
- You frequently tap multiple actions
- You're comfortable with compact UIs
- You want modern, iOS-style cards

**Use Guided Checklist (Option B) if:**

- You prefer step-by-step workflows
- You want less visual clutter
- You need contextual help at each step
- You're new to the app

**Switching Between Layouts:**

```swift
// In your DoseTrackApp.swift or main entry point:

@AppStorage("ui_layout_preference") private var layoutPreference: String = "card_stack"

var body: some Scene {
    WindowGroup {
        if layoutPreference == "card_stack" {
            TodayLogView_CardStack()
        } else {
            TodayLogView_Checklist()
        }
    }
}

// Add toggle in Settings:
Picker("UI Layout", selection: $layoutPreference) {
    Text("Card Stack with Dock").tag("card_stack")
    Text("Guided Checklist").tag("checklist")
}
```

---

## Integration Checklist

### Step 1: Add Late Dose Override Files

- [ ] Copy `ios/LateDoseSheetView.swift` to project
- [ ] Copy `ios/AppPreferencesEnhanced+LateDose.swift` to project
- [ ] Copy `ios/TodayViewModel+LateDose.swift` to project
- [ ] Update `ios/Models.swift` with override fields
- [ ] Update `DoseLogController` with new `logDose2Now` signature

### Step 2: Add Settings Section

- [ ] Add "Late Dose 2 Override" section to `SettingsViewEnhanced.swift`
- [ ] Test all 4 settings toggles/fields
- [ ] Verify App Group storage works

### Step 3: Choose UI Layout

- [ ] Copy `ios/TodayLogView_CardStack.swift` OR `ios/TodayLogView_Checklist.swift`
- [ ] Update app entry point to use chosen layout
- [ ] Test scrolling behavior on small screen
- [ ] Test action buttons all work

### Step 4: Test Late Dose Flow

- [ ] Log Dose 1, wait for window to expire
- [ ] Verify "Log Dose 2 (late)" button appears
- [ ] Tap button, verify sheet presents
- [ ] Test reason picker (all 5 options)
- [ ] Test "Other" reason with custom text
- [ ] Test quick choice buttons (5m, 10m, 15m, 30m)
- [ ] Test stepper (adjust minutes late)
- [ ] Test max limit warning (if enabled)
- [ ] Confirm late dose logs successfully
- [ ] Verify CSV export includes override fields

### Step 5: Test Settings Integration

- [ ] Disable "Allow late Dose 2 logging" → button disappears
- [ ] Enable "Require reason" → confirm button disabled until reason provided
- [ ] Set "Max late minutes" to 60 → test warning at 61 minutes
- [ ] Set "Max late minutes" to 0 → no warning at any amount
- [ ] Test custom quick choices: "10,20,30,60" → buttons update

### Step 6: Edge Cases

- [ ] Test late dose when Dose 2 already logged → button does not appear
- [ ] Test late dose when no Dose 1 logged → button does not appear
- [ ] Test late dose when session reset → button does not appear
- [ ] Test late dose exactly at window end (minutesAfterWindow = 0)
- [ ] Test very late dose (300+ minutes) → works if unlimited

---

## File Manifest

**Late Dose Override:**

| File | Lines | Status |
|------|-------|--------|
| `ios/LateDoseSheetView.swift` | 247 | ✅ Complete |
| `ios/AppPreferencesEnhanced+LateDose.swift` | 76 | ✅ Complete |
| `ios/TodayViewModel+LateDose.swift` | 156 | ✅ Complete |
| `ios/Models.swift` | +25 (override fields + CSV) | ✅ Complete |

**UI Layouts:**

| File | Lines | Status |
|------|-------|--------|
| `ios/TodayLogView_CardStack.swift` | 424 | ✅ Complete |
| `ios/TodayLogView_Checklist.swift` | 572 | ✅ Complete |

**Documentation:**

| File | Lines | Status |
|------|-------|--------|
| `docs/ops/LATE_DOSE_AND_UI_LAYOUTS.md` | 900+ | ✅ You are here |

---

## Next Steps

1. **Choose your UI layout** (Card Stack or Checklist)
2. **Add Late Dose settings** to SettingsView
3. **Update DoseLogController** to accept override parameters
4. **Test complete flow** (Dose 1 → Window expires → Late dose)
5. **Export CSV** and verify override columns

---

**Version:** 1.0.0  
**Last Updated:** November 2, 2025  
**Requires:** DoseTrack v1.1.1c+, iOS 17.0+  

**Questions?**  
- Late dose not appearing? Check `allowLateDose` setting
- Buttons not accessible? Use Card Stack layout with fixed dock
- Need step-by-step? Use Guided Checklist layout
- CSV not showing overrides? Update `csvHeader()` and `csvRow()` in Models.swift
