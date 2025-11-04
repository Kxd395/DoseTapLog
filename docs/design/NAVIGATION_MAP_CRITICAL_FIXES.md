# Navigation Map - Critical Fixes & Routing Architecture

**Version:** 1.1  
**Date:** November 4, 2025  
**Addendum to:** `MAIN_SCREEN_NAVIGATION_MAP.md`  
**Status:** 🔴 CRITICAL - Addresses production-blocking risks

---

## 🚨 Critical Issues Addressed

This addendum resolves **8 high-risk architectural issues** identified in code review:

1. ✅ **Boolean-explosion race conditions** → Single routed enum
2. ✅ **Unenforced modal priority** → Priority-based presentation queue
3. ✅ **Missing deep-link routing** → External route handlers
4. ✅ **Gesture conflicts** → Navigation stack constraints
5. ✅ **Natural Wake policy mismatch** → Gate enforcement added
6. ✅ **Tomorrow minting ambiguity** → Idempotent minting spec
7. ✅ **Missing state restoration** → Persistence + restore policy
8. ✅ **Accessibility gaps** → Dynamic Type + VoiceOver fixes

---

## Presentation Router Architecture

### Replace All Boolean Flags

**❌ OLD (Boolean Explosion):**
```swift
@State private var showEarlyDose2Sheet = false
@State private var showLateDose2Sheet = false
@State private var showDose2BlockedSheet = false
@State private var showNeedDose1Sheet = false
@State private var showAlreadyLoggedSheet = false
@State private var showWakeSheet = false
@State private var showResetNightSheet = false
@State private var showSettings = false
```

**✅ NEW (Single Routed Enum):**
```swift
enum SheetRoute: Identifiable, Equatable {
    case settings
    case wake(isFinal: Bool)
    case dose2Early(minutes: Int)
    case dose2Late(minutes: Int)
    case dose2Blocked(reason: String)
    case needDose1
    case dose2AlreadyLogged
    case resetNight
    case timeZoneRebase
    
    var id: String { /* unique ID */ }
}

@StateObject private var presentationQueue = PresentationQueue()
```

**Implementation:** See `PresentationRouter.swift`

---

## Modal Priority Enforcement

### Priority Table

| Priority | Route | Behavior |
|----------|-------|----------|
| **100** | Reset Night | Preempts everything |
| **90** | Dose 2 Blocked | Safety hard stop |
| **80** | Dose 2 Override (Early/Late) | User decision required |
| **70** | Need Dose 1 | Prerequisite action |
| **60** | Already Logged | Edit/undo option |
| **50** | Wake Sheet | Event logging |
| **40** | Settings | Configuration |
| **30** | Timezone Rebase | System notification |

### Preemption Logic

```swift
struct PresentationPolicy {
    static func rank(_ route: SheetRoute) -> Int {
        switch route {
        case .resetNight: return 100
        case .dose2Blocked: return 90
        case .dose2Early, .dose2Late: return 80
        case .needDose1: return 70
        case .dose2AlreadyLogged: return 60
        case .wake: return 50
        case .settings: return 40
        case .timeZoneRebase: return 30
        }
    }
}

final class PresentationQueue: ObservableObject {
    @Published var current: SheetRoute?
    private var pending: [SheetRoute] = []
    
    func present(_ route: SheetRoute) {
        guard let cur = current else { current = route; return }
        
        if PresentationPolicy.rank(route) > PresentationPolicy.rank(cur) {
            // Preempt current with higher priority
            pending.insert(cur, at: 0)
            current = route
        } else {
            // Enqueue for later
            pending.append(route)
        }
    }
    
    func didDismiss() {
        current = pending.sorted { 
            PresentationPolicy.rank($0) > PresentationPolicy.rank($1) 
        }.first
        pending.removeAll()
    }
}
```

**Usage:**
```swift
.sheet(item: $presentationQueue.current) { route in
    switch route {
    case .dose2Early(let minutes):
        EarlyDose2Sheet(...) { 
            confirmEarlyDose2(...)
            presentationQueue.didDismiss()
        }
    case .resetNight:
        ResetNightSheet(...) {
            performReset(...)
            presentationQueue.didDismiss()
        }
    // ... all other routes
    }
}
```

---

## External Routing (Deep Links / Notifications)

### External Entry Points

```swift
enum ExternalRoute {
    case dose2Now           // "Log Dose 2 now" notification action
    case snooze5m           // "Snooze 5 minutes" action
    case logMissedDose2     // "Log as missed" action
    case openWake(final: Bool)  // Open wake sheet
    case openSettings       // Deep link to settings
    case resetNight         // Deep link to reset
}
```

### Handler Implementation

```swift
extension PresentationQueue {
    func handleExternal(
        _ route: ExternalRoute, 
        onSwitchToTonight: @escaping () -> Void,
        controller: DoseLogControllering,
        onOverlay: @escaping (OverlayRoute) -> Void
    ) {
        // CRITICAL: Always route to Tonight first
        onSwitchToTonight()
        
        switch route {
        case .dose2Now:
            // Evaluate gate and show appropriate sheet
            // Handled by tryLogDose2() in NightCardViewModern
            break
            
        case .snooze5m:
            controller.snoozeDose2Notification()
            onOverlay(.toast("Snoozed 5 minutes"))
            
        case .logMissedDose2:
            controller.logMissedDose2()
            onOverlay(.toast("Logged missed Dose 2"))
            
        case .openWake(let final):
            present(.wake(isFinal: final))
            
        case .openSettings:
            present(.settings)
            
        case .resetNight:
            present(.resetNight)
        }
    }
}
```

### Integration Point

```swift
// In DoseTrackApp.swift or ThreeCardPlanningView
.onOpenURL { url in
    if let route = ExternalRoute.from(url) {
        presentationQueue.handleExternal(
            route,
            onSwitchToTonight: { selectedHorizon = .tonight },
            controller: controller,
            onOverlay: { overlayRoute = $0 }
        )
    }
}
.onReceive(NotificationCenter.default.publisher(for: .userNotificationAction)) { notification in
    if let route = ExternalRoute.from(notification) {
        presentationQueue.handleExternal(...)
    }
}
```

---

## Always-Tappable Dose 2 Button

### Interaction Spec

**CRITICAL CHANGE:** Dose 2 button is **always tappable**, never disabled.

- **Visual state:** Shows "locked" appearance when not ready (grayed out)
- **Tap behavior:** Routes to appropriate sheet based on gate state
- **VoiceOver:** Announces lock reason in accessibility hint

### Implementation

```swift
// In NightCardViewModern
ActionButton(
    title: "Dose 2",
    icon: "pills.circle.fill",
    style: .primary(locked: dose2IsLocked(night)),
    caption: dose2StatusCaption(night)
) {
    tryLogDose2(night)
}
.accessibilityHint(dose2StatusCaption(night))

private func dose2IsLocked(_ night: DoseLog) -> Bool {
    switch evaluateDose2Gate(...) {
    case .ready: return false  // Unlocked
    default: return true       // Locked visually, still tappable
    }
}

private func dose2StatusCaption(_ night: DoseLog) -> String {
    switch evaluateDose2Gate(...) {
    case .ready: return "Within window"
    case .needDose1: return "Log Dose 1 first"
    case .alreadyLogged: return "Already logged"
    case .tooEarly(let m): return "Opens in \(m)m"
    case .tooLate(let m): return "Closed \(m)m ago"
    }
}
```

### Routing Logic

```swift
func tryLogDose2(_ night: DoseLog) {
    let policy = Dose2Policy.from(prefs)
    let gate = evaluateDose2Gate(...)
    
    switch gate {
    case .ready:
        logDose2Now(night)
        
    case .needDose1:
        presentationQueue.present(.needDose1)
        
    case .alreadyLogged:
        presentationQueue.present(.dose2AlreadyLogged)
        
    case .tooEarly(let minutes):
        if minutes <= policy.earlyMaxOverrideMin {
            presentationQueue.present(.dose2Early(minutes: minutes))
        } else {
            presentationQueue.present(.dose2Blocked(
                reason: "Too early by \(minutes)m"
            ))
        }
        
    case .tooLate(let minutes):
        if minutes <= policy.lateMaxOverrideMin {
            presentationQueue.present(.dose2Late(minutes: minutes))
        } else {
            presentationQueue.present(.dose2Blocked(
                reason: "Too late by \(minutes)m"
            ))
        }
    }
}
```

**Implementation:** See `Dose2ButtonRouted.swift`

---

## Override Data Writes

### Required Fields (All Overrides)

When confirming an early/late override, write:

```swift
night.dose2TimeUTC = Date()
night.dose2Grams = prefs.planDose2G
night.dose2IsOverride = true
night.dose2OverrideKind = "early" | "late"
night.dose2OverrideMinutes = ±minutes
night.dose2OverrideReason = userText
night.lifecycleState = NightLifecycleState.awaitWake.rawValue
```

### Audit Logging (TODO)

```swift
audit.log(.dose2Logged(
    override: "early" | "late",
    minutes: minutes,
    reason: reason,
    source: "app",
    nightKey: night.nightKey
))
```

---

## Natural Wake Policy Fix

### ❌ OLD (Policy Mismatch)

Natural Wake button bypassed state machine and closed immediately, even if Dose 2 missing.

### ✅ NEW (Enforced Gate)

**Option A: Force Wake Sheet with Warning (RECOMMENDED)**

```swift
Button("Natural wake") {
    // Always show wake sheet, preset to final
    wakeSheetIsFinal = true
    
    // Show warning if Dose 2 missing
    if night.dose2TimeUTC == nil {
        wakeSheetShowsDose2Warning = true
    }
    
    presentationQueue.present(.wake(isFinal: true))
}
```

**Wake Sheet Implementation:**
```swift
struct WakeSheetView: View {
    @Binding var showsDose2Warning: Bool
    
    var body: some View {
        VStack {
            if showsDose2Warning {
                // Warning banner
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Dose 2 was not logged")
                        .font(.subheadline.weight(.semibold))
                }
                .padding()
                .background(Color.orange.opacity(0.15))
                .cornerRadius(8)
                
                Text("Confirm you want to close without Dose 2")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Rest of wake sheet UI
        }
    }
}
```

**Option B: Allow Closing, Record Missing Flag**

```swift
Button("Natural wake") {
    night.finalWakeTimeUTC = Date()
    night.finalWakeProvenance = "natural"
    night.currentLifecycleState = .closed
    
    // Record if Dose 2 missing
    if night.dose2TimeUTC == nil {
        night.notes = (night.notes ?? "") + " [Dose 2 not taken]"
        // TODO: Set dose2_missing flag when added to model
    }
    
    try? modelContext.save()
}
```

**DECISION:** Use **Option A** (Wake Sheet with warning) for safety.

---

## Tomorrow Minting Policy

### Specification

**Tapping "Create Plan from Template":**

1. **Mints night immediately** (creates DoseLog with `nightKey = tomorrow's date`)
2. **Sets `plannedDose1Time`** from weekly schedule
3. **Is idempotent** - tapping again updates template, doesn't create duplicate
4. **Tomorrow remains read-only** until it becomes Tonight at cutoff

### Implementation

```swift
private func createPlanFromTemplate() {
    // Get or create night for tomorrow
    let tomorrowKey = PlanningHorizon.tomorrow.nightKey(
        cutoffHour: prefs.cutoffHourLocal
    )
    
    let night: DoseLog
    if let existing = allNights.first(where: { $0.nightKey == tomorrowKey }) {
        // Idempotent: update existing
        night = existing
    } else {
        // Mint new night
        night = DoseLog(
            nightKey: tomorrowKey,
            nightStartUTC: ...,
            timezoneOffsetMinutes: TimeZone.current.secondsFromGMT() / 60
        )
        modelContext.insert(night)
    }
    
    // Apply template
    let schedule = prefs.weeklySchedule
    night.plannedDose1Time = schedule.suggestedDose1Time(...)
    
    try? modelContext.save()
}
```

---

## State Restoration

### Persistence

```swift
struct PresentationState: Codable {
    var selectedHorizon: String // "lastNight", "tonight", "tomorrow"
    var pendingRoute: String?   // Only if shouldRestore() = true
}

extension PresentationState {
    static func load() -> PresentationState? {
        guard let data = UserDefaults.standard.data(forKey: "PresentationState"),
              let state = try? JSONDecoder().decode(Self.self, from: data) else {
            return nil
        }
        return state
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "PresentationState")
        }
    }
}
```

### Restore Policy

**On App Launch:**

```swift
.onAppear {
    // Restore horizon selection
    if let state = PresentationState.load() {
        selectedHorizon = PlanningHorizon(rawValue: state.selectedHorizon) ?? .tonight
        
        // Restore only blocking modals
        if let routeID = state.pendingRoute,
           let route = SheetRoute.from(routeID),
           PresentationPolicy.shouldRestore(route) {
            
            // Verify guard still holds
            if routeGuardHolds(route) {
                presentationQueue.present(route)
            }
        }
    }
}

.onChange(of: selectedHorizon) { _, new in
    PresentationState(selectedHorizon: new.rawValue, pendingRoute: nil).save()
}

.onChange(of: presentationQueue.current) { _, new in
    let routeID = new?.id
    PresentationState(selectedHorizon: selectedHorizon.rawValue, pendingRoute: routeID).save()
}
```

**Routes that Restore:**
- ✅ `resetNight` - User was mid-reset
- ✅ `dose2Blocked` - Hard stop still applies
- ❌ All others - Reopen only if condition still holds

---

## Gesture Conflict Prevention

### Issue

NavigationStack back-swipe + TabView page swipe = accidental tab changes.

### Solution: Disable TabView Swipe

```swift
TabView(selection: $selectedHorizon) {
    ForEach(PlanningHorizon.allCases, id: \.self) { horizon in
        NightCardViewModern(...)
            .tag(horizon)
    }
}
.tabViewStyle(.page(indexDisplayMode: .never))
.gesture(DragGesture(), including: .subviews)  // Disable horizontal swipe
```

**Navigation:** Use segmented control only, not swipe.

---

## Accessibility Enhancements

### VoiceOver Hints

```swift
Button("Dose 2") { ... }
    .accessibilityLabel("Dose 2")
    .accessibilityHint(dose2StatusCaption(night))
    // Announces: "Dose 2. Opens in 17 minutes."
```

### Dynamic Type Support

**Pills Row (Fix Overflow):**
```swift
LazyVGrid(
    columns: [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ],
    spacing: 12
) {
    // Pills wrap to multiple rows at XXL
}
```

**Button Captions (No Layout Push):**
```swift
// ❌ OLD: Separate Text() below button
Button(...) { }
Text("Log Dose 1 first")  // Pushes layout

// ✅ NEW: Inline caption in ActionButton
ActionButton(..., caption: "Log Dose 1 first")
// Caption is part of button frame, no push
```

**Monospaced Digits:**
```swift
Text("Opens in \(minutes)m")
    .monospacedDigit()  // Prevents jitter when values change
```

---

## UI Test Cases

### Critical Tests

1. **Preemption Test**
   ```swift
   func testModalPreemption() {
       // Open Early Override sheet
       app.buttons["Dose 2"].tap()
       XCTAssertTrue(app.sheets["Early Override"].exists)
       
       // Trigger Reset Night (higher priority)
       app.buttons["Reset Night"].tap()
       
       // Reset sheet must replace Early sheet
       XCTAssertFalse(app.sheets["Early Override"].exists)
       XCTAssertTrue(app.sheets["Reset Night"].exists)
   }
   ```

2. **Deep Link Restore**
   ```swift
   func testDeepLinkFromNotification() {
       // Cold start from "Dose 2 now" notification
       app.activate()
       
       // Must land on Tonight tab
       XCTAssertEqual(app.segmentedControls.firstMatch.selectedSegmentIndex, 1)
       
       // Must show appropriate sheet (Early/Late/Ready)
       XCTAssertTrue(app.sheets.firstMatch.exists)
   }
   ```

3. **Swipe Conflict**
   ```swift
   func testNoAccidentalTabSwipe() {
       // Navigate into Settings (NavigationStack push)
       app.buttons["Settings"].tap()
       app.buttons["Dosing Plan"].tap()
       
       // Swipe back (NavigationStack pop)
       app.swipeRight()
       
       // Must NOT change horizon tab
       XCTAssertEqual(app.segmentedControls.firstMatch.selectedSegmentIndex, 1)
   }
   ```

4. **Dynamic Type XXL**
   ```swift
   func testDynamicTypeXXL() {
       app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXL"]
       app.launch()
       
       // Pills must not truncate
       let pill = app.staticTexts["Window"]
       XCTAssertTrue(pill.isFullyVisible)
       
       // Dose 2 caption must remain visible
       let caption = app.staticTexts.matching(identifier: "dose2_caption").firstMatch
       XCTAssertTrue(caption.exists)
   }
   ```

5. **Rotation / Compact Width**
   ```swift
   func testCompactWidthLayout() {
       XCUIDevice.shared.orientation = .portrait
       
       // Grid should collapse to 1 column on iPhone SE
       let buttons = app.buttons.matching(identifier: "action_button")
       let firstFrame = buttons.element(boundBy: 0).frame
       let secondFrame = buttons.element(boundBy: 1).frame
       
       // Vertical stacking (no horizontal alignment)
       XCTAssertNotEqual(firstFrame.minY, secondFrame.minY)
   }
   ```

---

## Sheet Presentation Modifiers

### Settings (Dismissable)

```swift
.sheet(item: $presentationQueue.current) { route in
    switch route {
    case .settings:
        SettingsViewEnhanced()
            .presentationDetents([.large])
            .interactiveDismissDisabled(false)
    }
}
```

### Reset / Blocked (Non-Dismissable)

```swift
case .resetNight:
    ResetNightSheet(...)
        .interactiveDismissDisabled(true)  // Must confirm or cancel

case .dose2Blocked:
    Dose2BlockedSheet(...)
        .interactiveDismissDisabled(true)
```

---

## Migration Path

### Step 1: Add PresentationRouter.swift

Copy `PresentationRouter.swift` to project.

### Step 2: Replace Booleans in NightCardViewModern

```swift
// Remove all @State showX booleans
// Add:
@StateObject private var presentationQueue = PresentationQueue()
```

### Step 3: Update Action Buttons

```swift
// OLD:
Button("Dose 2") { 
    if gate == .ready {
        logDose2Now()
    } else {
        showEarlyDose2Sheet = true
    }
}
.disabled(!gate.enabled)

// NEW:
ActionButton("Dose 2", ..., locked: dose2IsLocked(night)) {
    tryLogDose2(night)
}
```

### Step 4: Consolidate Sheet Presentation

```swift
// Replace 7 individual .sheet modifiers with:
.sheet(item: $presentationQueue.current) { route in
    switch route {
    case .dose2Early(let m): EarlyDose2Sheet(...)
    case .dose2Late(let m): LateDose2Sheet(...)
    case .dose2Blocked(let r): Dose2BlockedSheet(...)
    case .needDose1: NeedDose1Sheet(...)
    case .dose2AlreadyLogged: Dose2AlreadyLoggedSheet(...)
    case .wake(let isFinal): WakeSheetView(...)
    case .resetNight: ResetNightSheet(...)
    case .settings: SettingsViewEnhanced()
    case .timeZoneRebase: TimeZoneRebaseAlert(...)
    }
}
```

### Step 5: Wire Deep Links

```swift
// In ThreeCardPlanningView or DoseTrackApp
.onOpenURL { url in
    if let route = ExternalRoute.from(url) {
        presentationQueue.handleExternal(...)
    }
}
```

---

## Acceptance Criteria

✅ **Zero boolean `showX` flags** - All replaced with `SheetRoute` enum  
✅ **Preemption works** - Reset always replaces Early Override  
✅ **Deep links route correctly** - Notification → Tonight tab + correct sheet  
✅ **No gesture conflicts** - NavigationStack back-swipe doesn't change tabs  
✅ **Natural Wake gated** - Shows warning if Dose 2 missing  
✅ **Tomorrow minting** - Idempotent, creates `nightKey` immediately  
✅ **State restoration** - Restores `selectedHorizon` + blocking modals only  
✅ **Dynamic Type XXL** - Pills wrap, captions visible, no truncation  
✅ **Accessibility** - VoiceOver hints announce gate status  

---

## Document Updates Required

### MAIN_SCREEN_NAVIGATION_MAP.md

**Section "Modal Stack" → Rename to:**
```markdown
## Presentation Policy & Enforcement

(Insert PresentationPolicy + PresentationQueue code)
```

**Section "Action Routing" → Update all examples:**
```markdown
# OLD:
showEarlyDose2Sheet = true

# NEW:
presentationQueue.present(.dose2Early(minutes: minutes))
```

**Add New Section:**
```markdown
## External Sources → Routing Map

(Insert ExternalRoute enum + handleExternal() flow)
```

**Add New Section:**
```markdown
## State Restoration

- Persists: selectedHorizon
- Restores: resetNight, dose2Blocked (if guard still holds)
- Ignores: All other stale routes
```

**Section "Accessibility" → Add:**
```markdown
- Button hints use accessibilityHint with gate status
- All time values use monospacedDigit()
- Pills use LazyVGrid with wrapping at XXL
```

---

## Files Created

1. ✅ **`PresentationRouter.swift`** - Central routing + queue
2. ✅ **`Dose2ButtonRouted.swift`** - Always-tappable Dose 2 implementation
3. ✅ **`NAVIGATION_MAP_CRITICAL_FIXES.md`** - This document

---

**Version:** 1.0  
**Status:** 🔴 CRITICAL - Ready for implementation  
**Estimated LOC Changes:** ~400 lines (mostly deletions of boolean flags)

---

**End of Critical Fixes**
