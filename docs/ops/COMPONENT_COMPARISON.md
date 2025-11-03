# Component Comparison: Review Bundle vs. Fresh Implementation

**📍 Location:** `docs/ops/COMPONENT_COMPARISON.md`  
**📚 Breadcrumbs:** `docs/` → `ops/` → **`COMPONENT_COMPARISON.md`**

**Date:** November 2, 2025  
**Comparing:**
- Review bundle: `/review/DoseTrack_Update_111c_UI_Wiring/`
- Fresh implementation: `/ios/` (just created)

---

## Executive Summary

🎯 **Recommendation: COMBINE BOTH APPROACHES**

The review bundle (`DoseTrack_Update_111c_UI_Wiring/`) contains a **complete, integrated implementation** with ViewModel, Controller protocol, and working state machine. Our fresh components are **more detailed and modular** with better previews and documentation.

**Best Strategy:**
1. ✅ Use review bundle's **TodayViewModel** and **DoseLogControllering protocol** (complete state gating)
2. ✅ Use review bundle's **integrated TodayLogView** (already wired with all fixes)
3. ✅ Enhance with our fresh **AppPreferences** (30+ settings vs. their 13)
4. ✅ Replace their compact components with our **detailed components** (better previews, docs)
5. ✅ Add our **comprehensive SettingsView** (7 sections vs. their 4)

---

## Side-by-Side Comparison

### 1. AppPreferences (Settings SSOT)

#### Review Bundle Version
**File:** `TodayViewModel.swift` (lines 113-138)  
**Properties:** 13 settings  
**Storage:** UserDefaults with App Group (`group.com.jefferson.dosetrack`)  
**Pattern:** `Codable` struct with `load()`/`save()` methods

```swift
struct AppPreferences: Codable, Equatable {
    var totalNightG: Double = 6.5
    var split: Split = .fiftyFifty
    var roundingStepG: Double = 0.25
    var windowStartMin: Int = 150
    var windowEndMin: Int = 240
    var allowEarlyDose: Bool = false
    var maxEarlyMinutes: Int = 15
    var requireEarlyReason: Bool = true
    var defaultEarlyButtons: [Int] = [5, 10]
    var liveActivityEnabled: Bool = true
    var notifyAtStart: Bool = true
    var notifyAtHalf: Bool = false
    var notifyAtEnd: Bool = true
    
    // Computed properties
    var planDose1G: Double
    var planDose2G: Double
    
    // Class methods
    static func load() -> AppPreferences
    func save()
}
```

#### Our Fresh Version
**File:** `ios/AppPreferences.swift` (234 lines)  
**Properties:** 30+ settings  
**Storage:** @AppStorage (individual UserDefaults keys)  
**Pattern:** `@Observable` class with singleton

```swift
@Observable final class AppPreferences {
    // Night Plan Defaults (6)
    @AppStorage("plan_total_night_grams") var totalNightGrams: Double = 6.5
    @AppStorage("plan_split_strategy") var splitStrategy: String = "50-50"
    @AppStorage("plan_rounding_increment") var roundingIncrement: Double = 0.25
    @AppStorage("dose2_window_start_min") var windowStartMin: Int = 150
    @AppStorage("dose2_window_end_min") var windowEndMin: Int = 240
    @AppStorage("allow_tonight_only_edit") var allowTonightEdit: Bool = true
    
    // Early Dose 2 Policy (4)
    @AppStorage("allow_early_dose") var allowEarlyDose: Bool = false
    @AppStorage("max_early_minutes") var maxEarlyMinutes: Int = 15
    @AppStorage("early_require_reason") var earlyRequireReason: Bool = true
    @AppStorage("early_time_prior_defaults") var earlyTimePriorDefaults: String = "5,10"
    
    // Notifications & Live Activity (7)
    @AppStorage("notifications_live_activity_enabled") var liveActivityEnabled: Bool = true
    // ... 6 more
    
    // Data Sources (4)
    @AppStorage("whoop_proxy_url") var whoopProxyURL: String = ""
    // ... 3 more
    
    // Exports (5)
    @AppStorage("export_include_timezone") var exportIncludeTimezone: Bool = true
    // ... 4 more
    
    // Privacy & Retention (3)
    @AppStorage("privacy_require_biometric") var requireBiometric: Bool = false
    // ... 2 more
    
    // Debug (1)
    @AppStorage("debug_show_internals") var showInternals: Bool = false
    
    // Helper methods
    func calculateDoses() -> (dose1: Double, dose2: Double)
    var planViolatesSafety: Bool
    func resetToDefaults()
    
    static let shared = AppPreferences()
}
```

**🔥 Winner: OUR VERSION (Fresh)**
- ✅ More comprehensive (30+ vs. 13 settings)
- ✅ Individual @AppStorage keys (better for SwiftUI bindings)
- ✅ Includes all 7 sections from spec (exports, privacy, debug, data sources)
- ✅ Safety validation built-in
- ⚠️ Need to add App Group support to match review bundle

---

### 2. TodayViewModel

#### Review Bundle Version
**File:** `TodayViewModel.swift` (156 lines)  
**Pattern:** `@MainActor @ObservableObject`  
**Features:**
- ✅ Complete state gating logic
- ✅ `onAppear()` with `consumePendingFromWidget()`
- ✅ Window enablement with early dose support
- ✅ `dose2DisabledReason` computed property
- ✅ Ring progress and status calculation
- ✅ All action methods with controller delegation
- ✅ `ensureNightKeyMintedIfNeeded()` enforced before Dose 1

```swift
@MainActor
final class TodayViewModel: ObservableObject {
    @Published var nightKey: String?
    @Published var dose1TimeUTC: Date?
    @Published var dose2TimeUTC: Date?
    @Published var finalWakeTimeUTC: Date?
    @Published var showEarlyDoseSheet: Bool = false
    @Published var lastEvents: [LoggedEvent] = []
    @Published var prefs = AppPreferences.load()
    
    private let controller: DoseLogControllering
    
    // State gating
    var dose2Enabled: Bool
    var dose2ReasonText: String
    var isWithinWindow: Bool
    var isBeforeWindowButEligibleEarly: Bool
    
    // Actions
    func logInBedNow()
    func logDose1Now(grams: Double)
    func tryLogDose2()
    func confirmEarlyDose2()
    func undoLast()
}
```

#### Our Fresh Version
**Status:** Not created yet  
**Recommendation:** Use review bundle's TodayViewModel

**🔥 Winner: REVIEW BUNDLE**
- ✅ Complete, tested implementation
- ✅ All state gating logic implemented
- ✅ Controller protocol abstraction
- ✅ Ready to use immediately

---

### 3. CountdownRing Component

#### Review Bundle Version
**File:** `SafetyBanner.swift` (lines 50-67)  
**Lines:** 18 lines (compact)  
**Features:**
- Ring with status-based colors
- Center text (Ready/Waiting/Open/Expired)
- Reason text below

```swift
struct CountdownRing: View {
    enum Status { case idle, waiting, open, expired }
    let progress: Double
    let status: Status
    let reasonText: String
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(Color.gray.opacity(0.18), lineWidth: 14)
                Circle().trim(from: 0, to: progress)
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(centerText).font(.title3).bold()
            }.frame(width: 160, height: 160)
            Text(reasonText).font(.footnote).foregroundStyle(.secondary)
        }
    }
}
```

#### Our Fresh Version
**File:** `ios/CountdownRingView.swift`  
**Lines:** 178 lines (comprehensive)  
**Features:**
- ✅ Ring with status-based colors (same as review)
- ✅ **Elapsed time display** (2h 15m) instead of status word
- ✅ **TimelineView integration** built-in (updates every 30s)
- ✅ Context-aware status text (formatDuration helpers)
- ✅ 4 preview states (idle, waiting, open, expired)
- ✅ Empty state handling (No Dose 1 icon)

```swift
struct CountdownRingView: View {
    let dose1Time: Date?
    let windowStartMin: Int
    let windowEndMin: Int
    let disabledReason: String
    
    var body: some View {
        TimelineView(.periodic(from: dose1Time ?? Date(), by: 30)) { context in
            VStack(spacing: 12) {
                ZStack {
                    // Ring
                    Circle().trim(from: 0, to: progress)
                    
                    // Center: "2h 15m elapsed" or "No Dose 1" icon
                    if let dose1 = dose1Time {
                        VStack {
                            Text(elapsedText(from: dose1, now: context.date))
                            Text("elapsed")
                        }
                    } else {
                        Image(systemName: "moon.stars")
                    }
                }
                
                // Status: "Window opens in 1h 45m"
                Text(statusText(now: context.date))
                
                // Disabled reason
                if !disabledReason.isEmpty {
                    Text(disabledReason)
                }
            }
        }
    }
}
```

**🔥 Winner: OUR VERSION (Fresh)**
- ✅ More detailed with elapsed time display
- ✅ TimelineView integration built-in
- ✅ Better empty state handling
- ✅ Comprehensive previews
- ⚠️ Review bundle version is more compact (easier to drop in)

**🎯 Recommendation: Use our version, it's more informative**

---

### 4. EventStrip Component

#### Review Bundle Version
**File:** `SafetyBanner.swift` (lines 69-88)  
**Lines:** 20 lines (compact)  
**Features:**
- Shows events with symbols (🛏️, 💊1, 💊2, etc.)
- Relative time ("2h 15m ago")
- Undo button with 60s cooldown

```swift
struct EventStrip: View {
    let events: [LoggedEvent]
    let onUndo: () -> Void
    @State private var canUndo = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent events").font(.subheadline)
            ForEach(events) { e in
                HStack {
                    Text(symbol(for: e.kind))
                    Text(label(for: e)).bold()
                    Spacer()
                    Text(relTime(e.timestampUTC)).foregroundStyle(.secondary)
                }.font(.callout)
            }
            if canUndo {
                Button("Undo last", action: onUndo)
                    .disabled(events.isEmpty)
            }
        }.padding(12).background(Color.gray.opacity(0.08))
    }
}
```

#### Our Fresh Version
**File:** `ios/EventStripView.swift`  
**Lines:** 187 lines (comprehensive)  
**Features:**
- ✅ Shows events with SF Symbols icons (moon.fill, bed.double.fill, etc.)
- ✅ Relative time with "Just now" handling
- ✅ Undo button logic (same as review)
- ✅ **EventDisplayItem data model** (separate from LoggedEvent)
- ✅ **Helper extensions** for formatting
- ✅ 3 preview states (with events, empty, no undo)
- ✅ Empty state UI ("No events logged yet")

```swift
struct EventStripView: View {
    let events: [EventDisplayItem]
    let allowUndo: Bool
    let onUndo: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                Text("Recent Events")
                Spacer()
                if allowUndo && !events.isEmpty {
                    Button("Undo", action: onUndo)
                }
            }
            
            if events.isEmpty {
                // Empty state UI
            } else {
                ForEach(events) { event in
                    EventRow(event: event, isFirst: ...)
                }
            }
        }
    }
}

struct EventDisplayItem: Identifiable {
    let description: String
    let relativeTime: String
    let icon: String
    let color: Color
    let timestamp: Date
    
    static func from(eventType: String, grams: Double?, timestamp: Date)
}
```

**🔥 Winner: SLIGHT EDGE TO REVIEW BUNDLE**
- ✅ Review: More compact, uses emoji symbols (fun!)
- ✅ Ours: More SwiftUI idiomatic with SF Symbols, better empty state
- ⚠️ Both have same core functionality

**🎯 Recommendation: Use review bundle's compact version, it's charming**

---

### 5. SafetyBanner Component

#### Review Bundle Version
**File:** `SafetyBanner.swift` (lines 1-26)  
**Lines:** 26 lines (compact)  
**Features:**
- Safety validation (1.5-4.5g per dose, 3.0-9.0g nightly)
- Single chip with checkmark/warning icon
- Night total display

```swift
struct SafetyBanner: View {
    let perDoseMinG: Double = 1.5
    let perDoseMaxG: Double = 4.5
    let nightTotalG: Double
    let planDose1G: Double
    let planDose2G: Double
    
    var planWithinBounds: Bool {
        planDose1G >= perDoseMinG && planDose1G <= perDoseMaxG &&
        planDose2G >= perDoseMinG && planDose2G <= perDoseMaxG &&
        nightTotalG >= 3.0 && nightTotalG <= 9.0
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Label("Per dose \(perDoseMinG.formatG) to \(perDoseMaxG.formatG)",
                  systemImage: planWithinBounds ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .background(planWithinBounds ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
            
            Text("Night total \(nightTotalG.formatG)")
                .background(Color.gray.opacity(0.12))
        }
    }
}
```

#### Our Fresh Version
**File:** `ios/SafetyBannerView.swift`  
**Lines:** 232 lines (comprehensive)  
**Features:**
- ✅ Safety chips (per dose, nightly) with ✓/✕
- ✅ **Status chips** for Wake source, Health permissions, WHOOP
- ✅ **Action buttons** (Change, Fix, Test)
- ✅ Separate chip components (SafetyChip, StatusChip)
- ✅ Supporting enums (WakeSource, HealthKitStatus, WHOOPStatus)
- ✅ 3 preview states

```swift
struct SafetyBannerView: View {
    let perDoseMin: Double
    let perDoseMax: Double
    let nightlyTotal: Double
    let dose1: Double
    let dose2: Double
    let wakeSource: WakeSource
    let healthStatus: HealthKitStatus
    let whoopStatus: WHOOPStatus
    let onChangeSource: () -> Void
    let onFixPermissions: () -> Void
    let onTestWHOOP: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Row 1: Safety chips
            HStack {
                SafetyChip(title: "Per dose", value: "...", isValid: ...)
                SafetyChip(title: "Night total", value: "...", isValid: ...)
            }
            
            // Row 2: Data sources
            HStack {
                StatusChip(title: "Wake", value: wakeSource.displayName, ...)
                StatusChip(title: "Health", value: healthStatus.displayName, ...)
            }
            
            // Row 3: WHOOP (conditional)
            if !whoopURL.isEmpty {
                StatusChip(title: "WHOOP", value: whoopStatus.displayName, ...)
            }
        }
    }
}
```

**🔥 Winner: OUR VERSION (Fresh)**
- ✅ Much more comprehensive (safety + data sources + permissions)
- ✅ Actionable chips (Fix, Test, Change buttons)
- ✅ Review bundle has basic safety only

**🎯 Recommendation: Use our version for completeness**

---

### 6. EarlyDoseSheet Component

#### Review Bundle Version
**File:** `EarlyDoseSheet.swift` (lines 1-30)  
**Lines:** 30 lines (compact)  
**Features:**
- Reason picker (3 options)
- Quick choice buttons (5m, 10m, etc.)
- Stepper for custom minutes
- Confirm/Cancel

```swift
struct EarlyDoseSheet: View {
    @Binding var minutes: Int
    @Binding var reason: EarlyReason
    let allowed: ClosedRange<Int>
    let quickChoices: [Int]
    let requireReason: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Why early") {
                    Picker("Reason", selection: $reason) {
                        ForEach(EarlyReason.allCases) { ... }
                    }
                }
                Section("How early") {
                    HStack {
                        ForEach(quickChoices) { m in
                            Button("\(m)m") { minutes = m }
                        }
                    }
                    Stepper("Early by \(minutes) minutes", ...)
                }
                Section {
                    Button("Confirm early Dose 2", action: onConfirm)
                    Button("Cancel", role: .cancel, action: onCancel)
                }
            }
        }
    }
}
```

#### Our Fresh Version
**File:** `ios/EarlyDoseSheetView.swift`  
**Lines:** 190 lines (comprehensive)  
**Features:**
- ✅ Same core functionality as review
- ✅ **Header with warning icon and subtitle**
- ✅ **Dose details section** (amount, early by)
- ✅ 4 reason options vs. 3 (added "Forgot earlier dose")
- ✅ Custom text field when "Other" selected
- ✅ **Disclaimer section** with clinician warning
- ✅ Validation (disabled until reason provided)
- ✅ 2 preview states

```swift
struct EarlyDoseSheetView: View {
    @Binding var isPresented: Bool
    let minutesEarly: Int
    let dose2Grams: Double
    let requireReason: Bool
    let timePriorOptions: [Int]
    let onConfirm: (_ reason: String, _ timePriorMin: Int) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                // Header with icon
                Section {
                    HStack {
                        Image(systemName: "clock.badge.exclamationmark")
                        VStack {
                            Text("Dose 2 Early")
                            Text("You're logging \(minutesEarly) min before...")
                        }
                    }
                }
                
                // Dose Details
                Section("Dose Details") {
                    LabeledContent("Amount", value: "\(dose2Grams)g")
                    LabeledContent("Early by", value: "\(minutesEarly) min")
                }
                
                // Reason
                Section("Reason (Required)") {
                    Picker("Reason", selection: $selectedReason) { ... }
                    if selectedReason == .other {
                        TextField("Describe reason", text: $customReason)
                    }
                }
                
                // Time-prior picker (segmented)
                Section("Log Time") {
                    Picker("Time Prior", selection: $selectedTimePrior) {
                        ForEach(timePriorOptions) { ... }
                    }.pickerStyle(.segmented)
                }
                
                // Disclaimer
                Section {
                    Text("This will log an early dose override...")
                    Text("Your clinician may review override events...")
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") { confirmEarlyDose() }
                        .disabled(!canConfirm)
                }
            }
        }
    }
}
```

**🔥 Winner: OUR VERSION (Fresh)**
- ✅ More informative (header, dose details, disclaimer)
- ✅ Better validation (custom text required for "Other")
- ✅ 4 reason options vs. 3
- ✅ Segmented picker for time-prior (cleaner UX)
- ⚠️ Review version is more compact

**🎯 Recommendation: Use our version for better UX**

---

### 7. SettingsView Component

#### Review Bundle Version
**File:** `EarlyDoseSheet.swift` (lines 32-86)  
**Lines:** 55 lines (compact)  
**Sections:** 4 sections
1. Night plan defaults (total, split, rounding)
2. Dose 2 window (start, end steppers)
3. Early dose policy (allow, max minutes, require reason, quick choices)
4. Notifications and Live Activity (4 toggles)

```swift
struct SettingsView: View {
    @State var prefs = AppPreferences.load()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Night plan defaults") {
                    Picker("Total night (g)", selection: $prefs.totalNightG) { ... }
                    Picker("Split", selection: $prefs.split) { ... }
                    Picker("Rounding step", selection: $prefs.roundingStepG) { ... }
                }
                
                Section("Dose 2 window") {
                    Stepper("Start \(prefs.windowStartMin) min", ...)
                    Stepper("End \(prefs.windowEndMin) min", ...)
                }
                
                Section("Early dose policy") {
                    Toggle("Allow early dose", ...)
                    Stepper("Max early \(prefs.maxEarlyMinutes) min", ...)
                    Toggle("Require reason", ...)
                    NavigationLink("Default quick choices") { ... }
                }
                
                Section("Notifications and Live Activity") {
                    Toggle("Live Activity for Dose 2", ...)
                    Toggle("Notify at window start", ...)
                    Toggle("Notify at halfway", ...)
                    Toggle("Notify at window end", ...)
                }
            }
            .toolbar {
                ToolbarItem {
                    Button("Save") {
                        prefs.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
```

#### Our Fresh Version (Spec-Based)
**File:** `ios/SettingsView.swift` (needs rebuild)  
**Spec:** `.specify/memory/spec.md` (Settings Panel Complete Specification)  
**Sections:** 7 sections (from spec)
1. Night plan defaults (6 controls)
2. Early Dose 2 policy (4 controls)
3. Notifications & Live Activity (6 controls)
4. Data sources (6 controls) ← **NEW**
5. Exports (5 controls) ← **NEW**
6. Privacy & retention (4 controls) ← **NEW**
7. Debug & developer (5 controls) ← **NEW**

**Missing from review bundle:**
- Data sources section (Health window, WHOOP config, wake source preference)
- Exports section (timezone, filename pattern, include notes, event log, default email)
- Privacy section (biometric, widget masking, retention days, purge)
- Debug section (show internals, simulate dose, force window, view event log, schema version)

**🔥 Winner: OUR SPEC (Fresh)**
- ✅ Review bundle has 4 sections, our spec has 7 sections
- ✅ Our spec covers all requirements from hyper-critical review
- ✅ Review bundle is good starting point, needs expansion

**🎯 Recommendation: Use review bundle as base, add our 3 missing sections**

---

### 8. TodayLogView Integration

#### Review Bundle Version
**File:** `TodayLogView.swift` (77 lines)  
**Features:**
- ✅ **ScrollView wrapper** (fixes overflow)
- ✅ **StateObject with TodayViewModel**
- ✅ **TimelineView** for countdown ring
- ✅ Night context line (date, timezone, nightKey)
- ✅ Settings gear button
- ✅ All action buttons wired
- ✅ EarlyDoseSheet presentation
- ✅ `onAppear(perform: vm.onAppear)`

```swift
struct TodayLogView: View {
    @StateObject private var vm = TodayViewModel(controller: RealDoseLogController())
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Plan GroupBox
                    GroupBox { ... }
                    
                    // Safety Banner
                    SafetyBanner(...)
                    
                    // Status Chips
                    StatusChips(...)
                    
                    // Night context line
                    Text(nightContextLine)
                    
                    // Countdown Ring (with TimelineView)
                    TimelineView(.periodic(from: Date(), by: 30)) { _ in
                        CountdownRing(
                            progress: vm.ringProgress,
                            status: vm.ringStatus,
                            reasonText: vm.dose2ReasonText
                        )
                    }
                    
                    // Action buttons
                    VStack(spacing: 10) {
                        HStack {
                            Button("In bed now", action: vm.logInBedNow)
                            Button("Dose 1 now", action: vm.logDose1Now)
                        }
                        HStack {
                            Button("Dose 2 now", action: vm.tryLogDose2)
                                .disabled(!vm.dose2Enabled)
                            Button("Final wake", action: vm.logFinalWake)
                        }
                        HStack {
                            Button("Alarm wake", action: vm.logAlarmWake)
                            Button("Bathroom", action: vm.logBathroom)
                        }
                        HStack {
                            Button("Undo last", action: vm.undoLast)
                            Button("Edit plan") { showSettings = true }
                        }
                    }
                    
                    // Event Strip
                    EventStrip(events: vm.lastEvents, onUndo: vm.undoLast)
                }
                .padding(16)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $vm.showEarlyDoseSheet) {
                EarlyDoseSheet(...)
            }
            .onAppear(perform: vm.onAppear)
        }
    }
}
```

#### Our Fresh Version
**Status:** Not yet integrated (we have components, need integration)

**🔥 Winner: REVIEW BUNDLE (Complete Integration)**
- ✅ Fully wired and ready to use
- ✅ All state gating implemented
- ✅ ScrollView wrapper in place
- ✅ TimelineView for live updates
- ✅ All fixes from hyper-critical review already applied

**🎯 Recommendation: USE REVIEW BUNDLE'S TodayLogView as-is**

---

## Integration Strategy

### Phase 1: Adopt Review Bundle Core ✅

**Use these files from review bundle:**
1. ✅ `TodayViewModel.swift` (complete state machine)
2. ✅ `TodayLogView.swift` (fully integrated)
3. ✅ `SafetyBanner.swift` (compact CountdownRing, EventStrip)
4. ✅ `EarlyDoseSheet.swift` (compact, functional)

**Copy to main project:**
```bash
cp review/DoseTrack_Update_111c_UI_Wiring/Sources/DoseTrack/TodayViewModel.swift ios/
cp review/DoseTrack_Update_111c_UI_Wiring/Sources/DoseTrack/TodayLogView.swift ios/
cp review/DoseTrack_Update_111c_UI_Wiring/Sources/DoseTrack/SafetyBanner.swift ios/
cp review/DoseTrack_Update_111c_UI_Wiring/Sources/DoseTrack/EarlyDoseSheet.swift ios/
```

### Phase 2: Enhance with Our Components 🔧

**Replace/Enhance:**
1. ✅ Replace `AppPreferences` struct with our `@Observable` class (30+ settings)
2. ✅ Replace compact `SafetyBanner` with our comprehensive `SafetyBannerView`
3. ✅ Optionally replace `CountdownRing` with our `CountdownRingView` (more detailed)
4. ✅ Optionally replace `EarlyDoseSheet` with our `EarlyDoseSheetView` (better UX)

### Phase 3: Expand SettingsView 📋

**Use review bundle's SettingsView as base, add our 3 missing sections:**
1. ✅ Keep: Night plan defaults, Dose 2 window, Early dose policy, Notifications
2. ✅ Add: Data sources section (Health, WHOOP, wake source)
3. ✅ Add: Exports section (CSV options)
4. ✅ Add: Privacy & retention section
5. ✅ Add: Debug & developer section

### Phase 4: Update AppPreferences Storage 🔄

**Migrate from Codable struct to @Observable class:**

```swift
// Review bundle approach (keep for compatibility)
struct AppPreferences: Codable {
    static func load() -> AppPreferences
    func save()
}

// Enhanced with @Observable for SwiftUI bindings
@Observable final class AppPreferences {
    // Add all 30+ @AppStorage properties
    // Keep backward compatibility with review bundle keys
    
    // Migration helper
    static func migrateFromLegacy() {
        if let legacy = LegacyAppPreferences.load() {
            shared.totalNightGrams = legacy.totalNightG
            shared.windowStartMin = legacy.windowStartMin
            // ... migrate all fields
        }
    }
}
```

### Phase 5: Connect Real Controller 🔌

**Replace stub with actual DoseLogController:**

```swift
// Review bundle has protocol:
protocol DoseLogControllering {
    func consumePendingFromWidget()
    func fetchOpenNight() -> (nightKey: String, dose1TimeUTC: Date?, ...)
    func logDose1Now(grams: Double)
    func logDose2Now(grams: Double, overrideEarlyMinutes: Int?, overrideReason: String?)
    func startLiveActivityIfEnabled(...)
    func endLiveActivity()
    // ... more methods
}

// Your existing DoseLogController should implement this protocol
extension DoseLogController: DoseLogControllering {
    // Implement all protocol methods
}

// Then inject into TodayViewModel
@StateObject private var vm = TodayViewModel(controller: DoseLogController.shared)
```

---

## Files to Keep vs. Replace

### ✅ KEEP from Review Bundle

| File | Reason | Status |
|------|--------|--------|
| `TodayViewModel.swift` | Complete state machine, all fixes | ✅ Use as-is |
| `TodayLogView.swift` | Fully integrated, ScrollView, state gating | ✅ Use as-is |
| `EarlyDoseSheet.swift` | Compact, functional | ✅ Use as-is or replace with our detailed version |
| `SafetyBanner.swift` (CountdownRing, EventStrip) | Compact, functional | ⚠️ Consider replacing with our detailed versions |

### 🔄 REPLACE from Review Bundle with Ours

| Component | Review Bundle | Our Version | Reason |
|-----------|---------------|-------------|--------|
| AppPreferences | 13 settings, Codable | 30+ settings, @Observable | ✅ More comprehensive |
| SafetyBanner | Basic safety only | Safety + Data sources + Permissions | ✅ More informative |
| SettingsView | 4 sections | 7 sections (from spec) | ✅ Complete requirements |

### ➕ ADD from Our Implementation

| Component | Status | Reason |
|-----------|--------|--------|
| AppPreferences.swift | ✅ Add | 30+ settings, safety validation |
| SafetyBannerView.swift | ✅ Add | Comprehensive status chips |
| CountdownRingView.swift | ⚠️ Optional | More detailed than review bundle |
| EarlyDoseSheetView.swift | ⚠️ Optional | Better UX than review bundle |
| Complete SettingsView | ✅ Add | Expand review bundle's 4 sections to 7 |

---

## Migration Checklist

### Step 1: Copy Review Bundle Files
- [ ] Copy `TodayViewModel.swift` to `ios/`
- [ ] Copy `TodayLogView.swift` to `ios/`
- [ ] Copy `SafetyBanner.swift` to `ios/`
- [ ] Copy `EarlyDoseSheet.swift` to `ios/`

### Step 2: Integrate Our Enhancements
- [ ] Add `AppPreferences.swift` (our @Observable version)
- [ ] Add `SafetyBannerView.swift` (comprehensive)
- [ ] Optionally add `CountdownRingView.swift` (detailed)
- [ ] Optionally add `EarlyDoseSheetView.swift` (better UX)

### Step 3: Update TodayLogView
- [ ] Replace `AppPreferences.load()` with `AppPreferences.shared`
- [ ] Replace `SafetyBanner` with `SafetyBannerView` (if using our version)
- [ ] Replace `CountdownRing` with `CountdownRingView` (if using our version)

### Step 4: Expand SettingsView
- [ ] Add Data sources section (6 controls)
- [ ] Add Exports section (5 controls)
- [ ] Add Privacy & retention section (4 controls)
- [ ] Add Debug & developer section (5 controls)
- [ ] Bind to `AppPreferences.shared` instead of `@State var prefs`

### Step 5: Connect Real Controller
- [ ] Implement `DoseLogControllering` protocol in your `DoseLogController`
- [ ] Replace `RealDoseLogController()` stub with real controller
- [ ] Test `consumePendingFromWidget()` with actual AppGroupStore

### Step 6: Test Complete Flow
- [ ] In bed now → nightKey minted
- [ ] Dose 1 → Live Activity starts
- [ ] Countdown ring updates every 30s
- [ ] Event strip shows events
- [ ] Window opens → Dose 2 enabled
- [ ] Early dose → EarlyDoseSheet presents
- [ ] Settings persist across launches
- [ ] CSV export includes overrides

---

## Conclusion

**🎯 Best of Both Worlds:**

1. **Review Bundle Strengths:**
   - ✅ Complete, tested TodayViewModel
   - ✅ Fully integrated TodayLogView
   - ✅ Compact, functional components
   - ✅ All hyper-critical review fixes already implemented

2. **Our Strengths:**
   - ✅ Comprehensive AppPreferences (30+ settings)
   - ✅ Detailed components with previews
   - ✅ Complete 7-section SettingsView spec
   - ✅ Better UX (disclaimers, validation, empty states)

**Recommended Approach:**
1. Start with review bundle's core (TodayViewModel, TodayLogView)
2. Enhance with our AppPreferences (30+ settings)
3. Expand SettingsView with our 3 missing sections
4. Optionally upgrade components for better UX

**Result:** Production-ready app with complete state gating, comprehensive settings, and polished UX! 🚀

---

**Version:** 1.0.0  
**Last Updated:** November 2, 2025  

**Next Steps:**
1. Copy review bundle files to `ios/`
2. Add our `AppPreferences.swift`
3. Expand `SettingsView` with missing sections
4. Connect real `DoseLogController`
5. Test complete flow
