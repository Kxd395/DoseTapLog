# Dose 2 Override System Implementation Guide

## 🎯 Overview

This document provides the complete implementation guide for the Dose 2 override system with two-tap confirmation for early/late doses, as specified by the user.

## ✅ Completed Steps

### 1. Fixed Settings Binding Issue
**Problem:** Settings pickers/toggles not updating dose amounts
**Root Cause:** `@AppStorage` properties in `@Observable` class conflicted with SwiftUI's observation system
**Solution:** Added `@ObservationIgnored` to all `@AppStorage` properties and used `@Bindable` in Settings View

**Files Modified:**
- `ios/AppPreferences.swift` - Added `@ObservationIgnored` to all 20+ @AppStorage properties
- `ios/SettingsViewEnhanced.swift` - Added `@Bindable var prefs = AppPreferences.shared` and replaced all `$AppPreferencesEnhanced.shared.property` with `$prefs.property`

**Testing:** Open Settings in app, try changing Total Night grams - should now work!

### 2. Added Late Dose Properties
**Added to AppPreferences.swift:**
```swift
// MARK: - Late Dose 2 Policy

@ObservationIgnored
@AppStorage("allow_late_dose")
var allowLateDose: Bool = false

@ObservationIgnored
@AppStorage("max_late_minutes")
var maxLateMinutes: Int = 30

@ObservationIgnored
@AppStorage("late_require_reason")
var lateRequireReason: Bool = true
```

### 3. Created Dose2Gate Model and Logic
**File Created:** `ios/TodayViewModel+Dose2Override.swift`

**Core Components:**
- `enum Dose2OverrideKind` - none, early, late
- `struct Dose2Gate` - evaluation result with enabled status, reason, kind, offset
- `struct Dose2OverrideArmed` - tracks 10-second arming window
- `enum Dose2Override` - early/late with minutes and reason

**Key Method:** `evaluateDose2Gate(now:)` implements all decision rules:
| Case | Condition | Result |
|------|-----------|--------|
| Not ready | dose1 == nil | Block: "Log Dose 1 first" |
| Too early (hard block) | elapsedMin < start - maxEarly OR !allowEarly | Disable: "Window opens in X min" |
| Early within policy | elapsedMin < start AND earlyBy ≤ maxEarly AND allowEarly | Enable: Two-tap required |
| In window | start ≤ elapsedMin ≤ end | Enable: One tap logs |
| Late within policy | end < elapsedMin ≤ end + maxLate AND allowLate | Enable: Two-tap required |
| Too late (missed) | elapsedMin > end + maxLate | Disable: "Window closed X min ago" |

## 📋 Remaining Implementation Steps

### 4. Update DoseLogController
**File:** `ios/DoseLogController.swift`

**Add method signature:**
```swift
func logDose2(
    nightKey: String,
    grams: Double,
    overrideKind: String,         // "none", "early", "late"
    earlyByMin: Int?,
    lateByMin: Int?,
    overrideReason: String?,
    overrideConfirmed: Int        // 0 or 1
)
```

**Implementation:** Execute SQL INSERT with new override columns

### 5. Create Database Migration
**File:** `server/migrations/005_dose2_override_tracking.sql`

```sql
-- Add override columns to event_log
ALTER TABLE event_log
  ADD COLUMN override_kind TEXT
    CHECK (override_kind IN ('none','early','late')) DEFAULT 'none';

ALTER TABLE event_log
  ADD COLUMN early_by_min INTEGER;   -- null unless early

ALTER TABLE event_log
  ADD COLUMN late_by_min INTEGER;    -- null unless late

ALTER TABLE event_log
  ADD COLUMN override_reason TEXT;   -- required if requireEarlyReason or requireLateReason

ALTER TABLE event_log
  ADD COLUMN override_confirmed INTEGER DEFAULT 0 
    CHECK (override_confirmed IN (0,1));

-- Prevent early beyond policy
CREATE TRIGGER IF NOT EXISTS trg_dose2_early_policy
BEFORE INSERT ON event_log
WHEN NEW.event_type = 'dose2'
  AND NEW.override_kind = 'early'
  AND NEW.early_by_min IS NOT NULL
BEGIN
  SELECT CASE
  WHEN (SELECT value FROM app_preferences WHERE key='allow_early_dose') <> 'true'
    THEN RAISE(ABORT,'early dose not allowed')
  WHEN CAST((SELECT value FROM app_preferences WHERE key='max_early_minutes') AS INT) < NEW.early_by_min
    THEN RAISE(ABORT,'exceeds max early minutes')
  END;
END;

-- Prevent late beyond policy
CREATE TRIGGER IF NOT EXISTS trg_dose2_late_policy
BEFORE INSERT ON event_log
WHEN NEW.event_type = 'dose2'
  AND NEW.override_kind = 'late'
  AND NEW.late_by_min IS NOT NULL
BEGIN
  SELECT CASE
  WHEN (SELECT value FROM app_preferences WHERE key='allow_late_dose') <> 'true'
    THEN RAISE(ABORT,'late dose not allowed')
  WHEN CAST((SELECT value FROM app_preferences WHERE key='max_late_minutes') AS INT) < NEW.late_by_min
    THEN RAISE(ABORT,'exceeds max late minutes')
  END;
END;
```

### 6. Update/Create Dose Sheets

**Update:** `ios/EarlyDoseSheet.swift` or `ios/EarlyDoseSheetView.swift`
```swift
struct EarlyDoseSheet: View {
    @Binding var isPresented: Bool
    let earlyByMinutes: Int
    let requireReason: Bool
    let timePriorOptions: [Int]  // e.g., [5, 10]
    let onConfirm: (String, Int) -> Void  // (reason, timePriorMin)
    
    @State private var selectedTimePrior: Int
    @State private var reason: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Early Dose Information") {
                    Text("Dose 2 is early by \(earlyByMinutes) minutes")
                        .foregroundStyle(.orange)
                }
                
                Section("Time Prior to Window") {
                    Picker("How early?", selection: $selectedTimePrior) {
                        ForEach(timePriorOptions, id: \.self) { min in
                            Text("\(min) min").tag(min)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if requireReason {
                    Section("Reason Required") {
                        TextField("Why taking early?", text: $reason)
                    }
                }
                
                Section {
                    Button("Confirm Early Dose") {
                        onConfirm(reason, selectedTimePrior)
                        isPresented = false
                    }
                    .disabled(requireReason && reason.isEmpty)
                    
                    Button("Cancel", role: .cancel) {
                        isPresented = false
                    }
                }
            }
            .navigationTitle("Early Dose Override")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
```

**Create:** `ios/LateDoseSheetView.swift`
```swift
struct LateDoseSheet: View {
    @Binding var isPresented: Bool
    let lateByMinutes: Int
    let requireReason: Bool
    let onConfirm: (String) -> Void
    
    @State private var reason: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Late Dose Information") {
                    Text("Dose 2 is late by \(lateByMinutes) minutes")
                        .foregroundStyle(.red)
                    
                    Text("Window closed \(formatDuration(lateByMinutes)) ago")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                
                if requireReason {
                    Section("Reason Required") {
                        TextField("Why taking late?", text: $reason)
                        Text("Example: Fell asleep, forgot, felt fine without it")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section {
                    Button("Confirm Late Dose") {
                        onConfirm(reason)
                        isPresented = false
                    }
                    .disabled(requireReason && reason.isEmpty)
                    .foregroundStyle(.red)
                    
                    Button("Cancel", role: .cancel) {
                        isPresented = false
                    }
                }
            }
            .navigationTitle("Late Dose Override")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}
```

### 7. Update TodayLogView UI

**Add to TodayLogView.swift:**
```swift
struct TodayLogView: View {
    // ... existing code ...
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    // ... existing UI ...
                    
                    // Override banner (if armed)
                    if let message = vm.bannerMessage {
                        BannerView(message: message, style: vm.bannerStyle)
                            .transition(.move(edge: .top))
                            .animation(.easeInOut, value: vm.bannerMessage)
                    }
                    
                    // Dose 2 button with two-tap support
                    Button("Dose 2 now") {
                        vm.tryLogDose2Tapped()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!vm.dose2Gate.enabled)
                    .onLongPressGesture {
                        vm.longPressDose2()
                    }
                    
                    // Helper text under button
                    if let gate = vm.currentDose2Gate {
                        Text(gate.reason)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $vm.showEarlyDoseSheet) {
                EarlyDoseSheet(
                    isPresented: $vm.showEarlyDoseSheet,
                    earlyByMinutes: vm.evaluateDose2Gate().minutesOffset,
                    requireReason: vm.prefs.earlyRequireReason,
                    timePriorOptions: vm.prefs.earlyTimePriorOptions,
                    onConfirm: vm.confirmEarlyDose2
                )
            }
            .sheet(isPresented: $vm.showLateDoseSheet) {
                LateDoseSheet(
                    isPresented: $vm.showLateDoseSheet,
                    lateByMinutes: vm.evaluateDose2Gate().minutesOffset,
                    requireReason: vm.prefs.lateRequireReason,
                    onConfirm: vm.confirmLateDose2
                )
            }
        }
    }
}

struct BannerView: View {
    let message: String
    let style: TodayViewModel.BannerStyle
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
            Text(message)
            Spacer()
        }
        .padding()
        .background(backgroundColor)
        .foregroundStyle(.white)
        .cornerRadius(8)
    }
    
    private var iconName: String {
        switch style {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }
}
```

### 8. Add Late Dose Settings UI

**Update SettingsViewEnhanced.swift:** (after Early Dose 2 Policy section)
```swift
// MARK: - Section 4: Late Dose 2 Policy
Section("Late dose 2 policy") {
    Toggle("Allow late Dose 2", isOn: $prefs.allowLateDose)
    
    if prefs.allowLateDose {
        Stepper(value: $prefs.maxLateMinutes, in: 0...90, step: 5) {
            Text("Max late: \(prefs.maxLateMinutes) minutes")
        }
        
        Toggle("Require reason for late dose", isOn: $prefs.lateRequireReason)
    }
}
```

### 9. Update CSV Export

**Modify CSVExporter.swift:**
```swift
// Add to CSV header
let header = "night_key,event_type,timestamp,...,override_kind,early_by_min,late_by_min,override_reason"

// Add to row export
let overrideKind = event.overrideKind ?? "none"
let earlyBy = event.earlyByMin.map(String.init) ?? ""
let lateBy = event.lateByMin.map(String.init) ?? ""
let overrideReason = event.overrideReason ?? ""

row += ",\(overrideKind),\(earlyBy),\(lateBy),\"\(overrideReason)\""
```

## 🧪 Test Matrix

### Test 1: Too Early (Hard Block)
- **Setup:** Dose 1 at t0, allowEarlyDose = false
- **Action:** Tap Dose 2 at t0+140m
- **Expected:** Button disabled, banner "Window opens in 10 min", no sheet

### Test 2: Early with Override
- **Setup:** Dose 1 at t0, allowEarlyDose = true, maxEarlyMinutes = 15
- **Action:** Tap Dose 2 at t0+140m (10 min early)
- **Expected:**
  1. First tap: Yellow banner "Early by 10 min. Tap again to request override"
  2. Second tap within 10 sec: EarlyDoseSheet opens
  3. Select reason, time-prior = 10
  4. Confirm: Logs with override_kind='early', early_by_min=10

### Test 3: In Window (Normal)
- **Setup:** Dose 1 at t0
- **Action:** Tap Dose 2 at t0+180m
- **Expected:** One tap logs immediately, override_kind='none'

### Test 4: Late with Override
- **Setup:** Dose 1 at t0, allowLateDose = true, maxLateMinutes = 30
- **Action:** Tap Dose 2 at t0+250m (10 min late)
- **Expected:**
  1. First tap: Yellow banner "Late by 10 min. Tap again to request override"
  2. Second tap within 10 sec: LateDoseSheet opens
  3. Enter reason
  4. Confirm: Logs with override_kind='late', late_by_min=10

### Test 5: Missed Dose
- **Setup:** Dose 1 at t0, maxLateMinutes = 30
- **Action:** Tap Dose 2 at t0+280m (40 min late)
- **Expected:** Button disabled, banner "Window closed 40 min ago"

### Test 6: CSV Export
- **Action:** Export data after logging overrides
- **Expected:** CSV includes columns: override_kind, early_by_min, late_by_min, override_reason

## 📦 Files Summary

**Created:**
- `ios/TodayViewModel+Dose2Override.swift` (367 lines) - Core override logic
- `ios/LateDoseSheetView.swift` - Late dose confirmation sheet
- `server/migrations/005_dose2_override_tracking.sql` - Database schema

**Modified:**
- `ios/AppPreferences.swift` - Added @ObservationIgnored + late dose properties
- `ios/SettingsViewEnhanced.swift` - Fixed bindings, added late dose section
- `ios/TodayLogView.swift` - Wire up two-tap UI and sheets
- `ios/DoseLogController.swift` - Add logDose2() with override parameters
- `ios/CSVExporter.swift` - Add override columns to export
- Update existing `ios/EarlyDoseSheet.swift` - Add time-prior picker

## 🚀 Next Steps

1. **Add files to Xcode project:**
   - TodayViewModel+Dose2Override.swift
   - LateDoseSheetView.swift
   
2. **Run database migration:**
   - Execute 005_dose2_override_tracking.sql

3. **Update DoseLogController:**
   - Add logDose2() method with override parameters

4. **Wire up UI:**
   - Update TodayLogView with banner and sheets
   - Update SettingsViewEnhanced with late dose section

5. **Test all 6 scenarios**

6. **Commit to git:**
   ```bash
   git add ios/TodayViewModel+Dose2Override.swift ios/LateDoseSheetView.swift
   git add ios/AppPreferences.swift ios/SettingsViewEnhanced.swift
   git add server/migrations/005_dose2_override_tracking.sql
   git commit -m "✨ Implement comprehensive Dose 2 override system with two-tap confirmation"
   ```

---

**Status:** Settings binding FIXED ✅, Core override logic CREATED ✅, Remaining work documented above
