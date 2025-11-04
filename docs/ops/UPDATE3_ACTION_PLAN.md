# Update3 Review - Action Plan
**Generated:** November 3, 2025  
**Source:** `/review/update3.md`  
**Status:** App running successfully with dark mode UI

## 🎉 Current State (From Screenshot)

✅ **WORKING:**
- Dark mode UI active (#0F1117 background)
- Three-card planning view (Last Night / Tonight / Tomorrow)
- "Build 1.1.2" visible
- Tonight plan card showing Dose 1 & Dose 2 (4.25g each)
- Window info: "210–245 min after Dose 1"
- Safety chips: "Per dose 1.5–4.5 g" and "Night total 0.00 g"
- Action buttons: In bed, Dose 1, Dose 2, Final wake (proper styling)
- Event buttons: Alarm wake, Natural wake, Bathroom, Reset night
- "Recent" section with "Undo last" link

## 📋 Priority Implementation Queue

### 🔴 CRITICAL (1-2 hours each) - Immediate UX Impact

#### 1. Window Status Pill + Next Alert Chip
**Problem:** No visible indicator of window state or next alarm  
**Solution:** Add compact status pills under plan card

**Files to create/modify:**
- Create: `ios/Components/WindowPill.swift` (drop-in from review)
- Create: `ios/Components/NextAlertChip.swift`
- Modify: `NightCardViewModern.swift` (add to layout)

**Code (ready to paste):**
```swift
// WindowPill.swift - Shows HH:MM:SS countdown
struct WindowPill: View {
  @Binding var now: Date
  let dose1At: Date?
  let start: Int
  let end: Int
  let showSeconds: Bool

  var body: some View {
    TimelineView(.periodic(from: now, by: 1)) { ctx in
      let (label, style) = status(at: ctx.date)
      Label(label, systemImage: style.symbol)
        .font(.caption)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(style.bg).clipShape(Capsule())
    }
  }

  private func status(at t: Date) -> (String, Style) {
    guard let d1 = dose1At else { return ("Waiting for Dose 1", .neutral) }
    let open = d1.addingTimeInterval(Double(start)*60)
    let close = d1.addingTimeInterval(Double(end)*60)
    if t < open { return ("Opens in \(fmt(open.timeIntervalSince(t)))", .neutral) }
    if t <= close { return ("Ends in \(fmt(close.timeIntervalSince(t)))", .good) }
    return ("Expired \(fmt(t.timeIntervalSince(close)))", .bad)
  }

  private func fmt(_ interval: TimeInterval) -> String {
    let s = Int(interval)
    let h = s/3600, m = (s%3600)/60, sec = s%60
    return showSeconds ? String(format:"%d:%02d:%02d",h,m,sec)
                       : String(format:"%d:%02d",h,m)
  }

  struct Style { 
    let symbol: String
    let bg: Color
    static let neutral = Style(symbol: "clock", bg: .gray.opacity(0.2))
    static let good    = Style(symbol: "clock.badge.checkmark", bg: .green.opacity(0.2))
    static let bad     = Style(symbol: "clock.badge.exclamationmark", bg: .red.opacity(0.2))
  }
}
```

**Layout in NightCardViewModern:**
```swift
// After "Tonight plan" card
HStack(spacing: 8) {
  WindowPill(
    now: .constant(Date()),
    dose1At: viewModel.dose1Time,
    start: 210,
    end: 245,
    showSeconds: true
  )
  
  if let nextAlert = viewModel.nextScheduledAlert {
    NextAlertChip(time: nextAlert, style: viewModel.alarmStyle)
  }
}
.padding(.horizontal)
```

---

#### 2. Dose 2 Disabled Reason Caption
**Problem:** Dose 2 button is grayed out with no explanation  
**Solution:** Add subtitle under disabled button

**Modify:** `NightCardViewModern.swift`

```swift
VStack(spacing: 4) {
  Button("Dose 2", action: { viewModel.logDose2Now() })
    .buttonStyle(PrimaryActionButton())
    .disabled(!viewModel.dose2Enabled)
  
  if !viewModel.dose2Enabled, let reason = viewModel.dose2DisabledReason {
    Text(reason)
      .font(.footnote)
      .foregroundStyle(.secondary)
      .accessibilityHint(reason)
  }
}
```

**Add to TodayViewModel:**
```swift
var dose2DisabledReason: String? {
  guard let d1 = dose1Time else { return nil }
  let now = Date()
  let windowOpen = d1.addingTimeInterval(Double(prefs.windowStartMin) * 60)
  
  if now < windowOpen {
    let remaining = windowOpen.timeIntervalSince(now)
    let h = Int(remaining / 3600)
    let m = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
    return "Opens in \(h)h \(m)m (210–245 min after Dose 1)"
  }
  
  return nil
}
```

---

#### 3. Fix Safety Chips Ambiguity
**Problem:** "Night total 0.00 g" looks like a bug when plan shows 8.50g  
**Solution:** Split into "Planned" vs "Logged" chips

**Modify:** `NightCardViewModern.swift`

```swift
HStack(spacing: 8) {
  // Safety bounds chip (unchanged)
  StatusChip(
    icon: "checkmark.circle.fill",
    text: "Per dose 1.5–4.5 g",
    tone: .good
  )
  
  // Planned total
  StatusChip(
    icon: "calculator",
    text: "Σ Planned \(String(format: "%.2f", plannedTotal)) g",
    tone: .neutral
  )
  
  // Logged total
  StatusChip(
    icon: "book.closed",
    text: "📒 Logged \(String(format: "%.2f", loggedTotal)) g",
    tone: loggedTotal > 0 ? .neutral : .muted
  )
}
```

---

#### 4. Add "Log Wake At…" Sheet
**Problem:** No way to backfill exact wake time with seconds  
**Solution:** Add time picker sheet

**Create:** `ios/Sheets/LogWakeAtSheet.swift`

```swift
import SwiftUI

struct LogWakeAtSheet: View {
  @Environment(\.dismiss) var dismiss
  @State private var selectedTime = Date()
  @State private var reason = ""
  let onSave: (Date, String) -> Void
  
  var body: some View {
    NavigationStack {
      Form {
        Section("Wake Time") {
          DatePicker(
            "Exact time",
            selection: $selectedTime,
            displayedComponents: [.date, .hourAndMinute]
          )
          
          // Optional: Add seconds picker if needed
          Text("Seconds: \(Calendar.current.component(.second, from: selectedTime))")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        
        Section("Reason") {
          TextField("Wake reason (optional)", text: $reason)
        }
      }
      .navigationTitle("Log Wake Time")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            onSave(selectedTime, reason.isEmpty ? "Manual" : reason)
            dismiss()
          }
        }
      }
    }
  }
}
```

**Add to Events section:**
```swift
Button("Log wake at…") {
  showLogWakeSheet = true
}
.sheet(isPresented: $showLogWakeSheet) {
  LogWakeAtSheet { time, reason in
    viewModel.logWakeAt(time: time, reason: reason)
  }
}
```

---

### 🟡 HIGH PRIORITY (2-3 hours each) - Polish & Trust

#### 5. Data Source Status Chips
**Files:** `NightCardViewModern.swift`

```swift
HStack(spacing: 8) {
  StatusChip(
    icon: "heart.fill",
    text: viewModel.healthKitStatus == .authorized ? "Health OK" : "Health Denied",
    tone: viewModel.healthKitStatus == .authorized ? .good : .bad
  )
  
  StatusChip(
    icon: "w.circle.fill",
    text: viewModel.whoopStatus == .connected ? "WHOOP OK" : "WHOOP Offline",
    tone: viewModel.whoopStatus == .connected ? .good : .neutral
  )
  
  StatusChip(
    icon: "bell.fill",
    text: viewModel.notificationsEnabled ? "Notifications: On" : "Notifications: Off",
    tone: viewModel.notificationsEnabled ? .good : .warning
  )
  .onTapGesture {
    if !viewModel.notificationsEnabled {
      // Deep link to Settings
      UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }
  }
}
```

#### 6. Undo Countdown Timer
**Problem:** No visible countdown, users don't trust the 60s window  
**Solution:** Show live countdown

**Modify:** "Undo last" UI:
```swift
if let lastEvent = viewModel.lastEvent {
  Button {
    viewModel.undoLastEvent()
  } label: {
    if let countdown = viewModel.undoSecondsRemaining {
      Text("Undo last (\(countdown)s)")
    } else {
      Text("Undo last")
    }
  }
  .disabled(viewModel.undoSecondsRemaining == nil)
}
```

**Add to TodayViewModel:**
```swift
@Published var undoSecondsRemaining: Int?

private var undoTimer: Timer?

func startUndoTimer(from eventTime: Date) {
  let elapsed = Date().timeIntervalSince(eventTime)
  guard elapsed < 60 else { 
    undoSecondsRemaining = nil
    return 
  }
  
  undoSecondsRemaining = 60 - Int(elapsed)
  
  undoTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
    guard let self = self else { return }
    if let remaining = self.undoSecondsRemaining {
      if remaining > 0 {
        self.undoSecondsRemaining = remaining - 1
      } else {
        self.undoSecondsRemaining = nil
        self.undoTimer?.invalidate()
      }
    }
  }
}
```

#### 7. Edit Plan Affordance
**Problem:** No way to edit tonight's plan  
**Solution:** Add pencil icon on plan card

```swift
HStack {
  Text("Tonight plan")
    .font(.headline)
  
  Spacer()
  
  Button {
    showEditPlanSheet = true
  } label: {
    Image(systemName: "pencil.circle")
      .foregroundStyle(.secondary)
  }
}
.sheet(isPresented: $showEditPlanSheet) {
  EditTonightPlanSheet(viewModel: viewModel)
}
```

---

### 🟢 MEDIUM PRIORITY (3-4 hours) - Nice to Have

#### 8. Move Build Label to Settings
**Action:** Remove "Build 1.1.2" from main view, add to Settings → About

#### 9. Context Chips (Date/Timezone)
**Add under "Tonight plan":**
```swift
Text("Sun, Nov 3 · UTC−06:00 · NightKey 2025-11-03 · Service cutoff 12:00")
  .font(.caption2)
  .foregroundStyle(.tertiary)
```

#### 10. Haptics on Events
**Add to log functions:**
```swift
import UIKit

func logDose1Now() {
  // ... existing code ...
  UIImpactFeedbackGenerator(style: .light).impactOccurred()
}

func windowOpened() {
  UIImpactFeedbackGenerator(style: .medium).impactOccurred()
}

func windowExpired() {
  UINotificationFeedbackGenerator().notificationOccurred(.warning)
}
```

#### 11. Long-Press Grams Edit
**Add to Dose buttons:**
```swift
Button("Dose 1") { viewModel.logDose1Now() }
  .simultaneousGesture(
    LongPressGesture().onEnded { _ in
      showQuickGramsEdit = true
    }
  )
```

#### 12. Reset Night Confirm + Undo
Already implemented per previous update - verify it works

---

## 📊 Settings Enhancements (From Review)

### Night Plan Defaults
- [ ] Add quick split options (50/50, 60/40, 40/60, Custom)
- [ ] Add per-dose guard text under live preview
- [ ] Clarify "Allow tonight-only override" with footnote

### Dose 2 Window
- [ ] Show derived absolute times (e.g., "If Dose 1 at 22:45 → opens 02:55")
- [ ] Validate end ≥ start + 30m with inline error

### Early Dose Policy
- [ ] Add "Max early minutes" (default 15)
- [ ] Add "Require reason" toggle
- [ ] Add quick choices (5m · 10m segmented control)

### Notifications & Live Activity
- [ ] Add "Pre-window nudge" (default 10m before open)
- [ ] Add alarm style segmented: Quiet · Normal · Strong
- [ ] Add "Respect Focus / DND" toggle
- [ ] Clarify Quiet hours semantics with sub-label

### Data Sources
- [ ] Add "Last Health sync" timestamp
- [ ] Add "Test WHOOP" button
- [ ] Add help row for "Prefer wake source"

### Exports
- [ ] Add live filename preview
- [ ] Add "Include app & schema version" toggle
- [ ] Add "Default share email" field
- [ ] Add warning for "Include raw event log"

### Privacy & Retention
- [ ] Add "Delete all data…" with row count preview
- [ ] Add "Mask doses on widgets" toggle

### Debug & Developer
- [ ] Add "Send test notifications"
- [ ] Add "Show App Health" (next alert, BG task, permissions)
- [ ] Add "Clock drift" readout

---

## 🎯 Microcopy (Paste-Ready)

```swift
// Dose 2 disabled hint
"Dose 2 opens in {timeRemaining}. Early override requires a reason."

// Late override sheet header
"Window ended {minutesLate} ago. If you and your clinician decided to proceed, log with a reason."

// Reset confirmation (soft)
"Start tonight over? You can undo for {undoSeconds}s."

// Reset confirmation (hard)
"Permanently delete tonight's data? This can't be undone."

// Pre-window nudge
"Dose 2 window opens soon."

// Window open
"Dose 2 window now open. Ends at {endTime}."

// Window end
"Dose 2 window ended."
```

---

## 🧪 QA Checklist

- [ ] Dose 2 button explains why it's disabled
- [ ] Window pill shows correct countdown to the second
- [ ] "Night total planned vs logged" labels are unambiguous
- [ ] "Log wake at…" supports seconds and writes wake_reason
- [ ] Undo shows countdown and restores state
- [ ] Status chips reflect real permissions within 1s
- [ ] All actions have ≥44×44 targets
- [ ] VoiceOver reads "Dose two disabled. Wait 17 minutes."
- [ ] Change split to 60/40 → preview updates both doses
- [ ] Edit window → shows derived open/end times
- [ ] Toggle early Off → early sheet never appears
- [ ] Quiet hours + Quiet style → no sound but Time-Sensitive allowed
- [ ] WHOOP empty → Test button disabled, chip shows "Offline"
- [ ] Export filename preview reflects tokens
- [ ] Reset soft → Undo countdown appears
- [ ] Reset hard → Face ID challenge, data gone, no Undo

---

## 🚀 Implementation Strategy

**Recommended Order:**
1. WindowPill + NextAlertChip (biggest UX win)
2. Dose 2 disabled reason (clarity)
3. Safety chips split (trust)
4. Log wake at sheet (retro logging)
5. Undo countdown (trust)
6. Status chips (data sources)
7. Edit plan affordance (tonight override)
8. Settings enhancements (batch)
9. Polish (haptics, long-press, etc.)

**Total Estimated Time:** 15-20 hours for all critical + high priority items

---

**Next Action:** Implement WindowPill.swift and wire it into NightCardViewModern.swift
