# UI Refinement Plan - Modern Night Card Polish

**Date:** November 3, 2025  
**Status:** Ready for implementation  
**Based on:** User feedback from v1.1.2 screenshots

---

## Overview

The Modern UI (NightCardViewModern) has the right direction but needs polish to eliminate rough edges. This plan addresses 8 UI issues and implements proper state-based logic gating.

---

## Issues & Fixes

### ✅ 1. Duplicate Title/Gear (FIXED)
- **Problem:** "DoseTrack" appeared twice, plus duplicate gear icons
- **Status:** Fixed in commit 052a3b9
- **Solution:** Removed header from NightCardViewModern, kept only NavigationStack title

### 2. Status Pill Placement & Meaning
**Problem:** "Waiting for Dose 1" pill floats orphaned below card

**Fix:**
- Move pill **inside** Tonight plan card, under "Window: 210–245 min"
- Update copy based on state:
  - `Planned` → "Waiting for Dose 1 to start the window"
  - `Armed (before open)` → "Window opens in 1h 47m"
  - `Open` → "Window open • ends in 1h 12m"
  - `Closed` → "Window closed 23m ago"

**Implementation:**
```swift
// In planCard(_:) function, add after window row:
WindowPill(
    state: windowState(night),
    opensIn: ...,
    endsIn: ...
)
.padding(.top, 4)
```

### 3. Chips Crowding/Misalignment
**Problem:** Gold "Per dose" chip and grey "Planned" chip don't align, can overflow

**Fix:**
- Use `FlowLayout` (wrapping layout) for chips
- Two chips always visible:
  - Gold: `Per dose 1.50–4.50 g` (safety range)
  - Grey: `Planned 8.50 g` → changes to `Logged X.XX g` after events
- Set `.fixedSize(horizontal: false, vertical: true)`
- Gold chip gets lower `layoutPriority` so it wraps first

**Implementation:**
```swift
FlowLayout(spacing: 8) {
    StatusChip(
        icon: "exclamationmark.triangle.fill",
        label: "Per dose 1.50–4.50 g",
        tone: .warning
    )
    .layoutPriority(0) // Lower priority, wraps first
    
    StatusChip(
        icon: night.hasLoggedEvents ? "book.closed.fill" : "sum",
        label: night.hasLoggedEvents ? "Logged \(loggedTotal(night))" : "Planned \(plannedTotal(night))",
        tone: night.hasLoggedEvents ? .normal : .dim
    )
    .layoutPriority(1)
}
.padding(.top, 6)
```

### 4. Action Button Enablement Hints
**Problem:** Dose 2 disabled reason easy to miss; Final wake enabled early can confuse

**Fix:**
- Add caption under disabled Dose 2: "Log Dose 1 to start the window"
- Add `.accessibilityHint()` with explicit guard text
- Keep Final wake enabled (legitimate use cases exist)

**Implementation:**
```swift
ActionItem(
    title: "Dose 2",
    icon: "pills.circle.fill",
    action: { vm.tryLogDose2() },
    disabled: !dose2Enabled(night),
    caption: dose2Enabled(night) ? nil : "Log Dose 1 to start the window"
)
.accessibilityHint(dose2Enabled(night) ? "" : "Dose two unavailable. Log Dose one first.")
```

### 5. Inconsistent Totals Language
**Problem:** Chip says "Σ Planned 8.50 g" then "Σ Night total 7.50 g" - names jump

**Fix:**
- Always show **two separate chips**:
  1. **Safety chip** (gold): `Per dose 1.50–4.50 g` (constant)
  2. **Totals chip** (grey): `Planned 8.50 g` OR `Logged 4.25 g` (dynamic label)

**Status:** Already implemented in Item 3 (Fix Safety Chips)

### 6. Too Much Vertical Space
**Problem:** Big empty area between plan and actions forces scrolling on small phones

**Fix:**
- Replace big countdown ring with **WindowBar** (compact 8-12pt pill)
- WindowBar shows:
  - Progress bar (fills left→right from window start to end)
  - Timer: `T-1:47:12` (with seconds if `showSeconds` enabled)
- Saves ~200-240pt vertical height

**Implementation:**
```swift
// Create WindowBar.swift
struct WindowBar: View {
    let start: Date?
    let end: Date?
    let showSeconds: Bool
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let (progress, label) = WindowMath.progressLabel(
                start: start,
                end: end,
                now: now,
                showSeconds: showSeconds
            )
            
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.gray.opacity(0.25))
                    .frame(height: 10)
                
                // Progress fill
                GeometryReader { geo in
                    Capsule()
                        .fill(progressColor)
                        .frame(width: geo.size.width * progress, height: 10)
                }
                .frame(height: 10)
            }
            .overlay(
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8),
                alignment: .bottomLeading
            )
        }
    }
    
    private var progressColor: Color {
        // Green when open, orange when closing soon, red when closed
        // Use Palette.success, Palette.warning, Palette.danger
    }
}
```

### 7. Recent Events Box
**Problem:** Shows "No events yet" but still shows "Undo last" button

**Fix:**
- Hide "Undo last" if undo stack is empty
- When events exist, show last 3 with:
  - Icon + absolute time (HH:MM:SS if `showSeconds` enabled)
  - Relative subtitle ("2 m ago")

**Implementation:**
```swift
@ViewBuilder
private func recentEventsCard(_ night: DoseLog) -> some View {
    if night.recentEvents.isEmpty {
        // Show nothing, or minimal "No events yet" text
        EmptyView()
    } else {
        VStack(alignment: .leading, spacing: 8) {
            Text("Events")
                .font(.headline)
                .foregroundStyle(Palette.text)
            
            ForEach(night.recentEvents.prefix(3)) { event in
                EventRow(
                    event: event,
                    showSeconds: prefs.showSeconds
                )
            }
            
            // Only show Undo if within window
            if canUndo(night) {
                Button("Undo last", action: { vm.undoLast(night) })
                    .buttonStyle(.bordered)
            }
        }
        .cardStyle()
    }
}

struct EventRow: View {
    let event: LoggedEvent
    let showSeconds: Bool
    
    var body: some View {
        HStack {
            Image(systemName: event.icon)
                .foregroundStyle(Palette.accent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.absoluteTime(showSeconds: showSeconds))
                    .font(.body)
                    .foregroundStyle(Palette.text)
                
                Text(event.relativeTime) // "2 m ago"
                    .font(.caption)
                    .foregroundStyle(Palette.dim)
            }
            
            Spacer()
        }
    }
}
```

### 8. Night Navigator Scope
**Problem:** Only Last/Tonight/Tomorrow visible; no way to browse older nights or plan ahead

**Fix:**
- Keep 3-segment control (fast, clear)
- Add chevrons: `‹` and `›` to nudge cursor by one service day
- Long-press opens date picker to jump
- When cursor is not −1/0/+1, replace middle label with date ("Wed • Nov 5")

**Implementation:**
```swift
// In ThreeCardPlanningView
HStack(spacing: 10) {
    // Left chevron
    Button {
        stepCursor(-1)
    } label: {
        Image(systemName: "chevron.left")
            .font(.body.weight(.semibold))
    }
    .disabled(cursor <= -30) // Limit to 30 days back
    
    // Segmented picker (or dynamic label)
    if cursor >= -1 && cursor <= 1 {
        Picker("Horizon", selection: $selectedHorizon) {
            ForEach(PlanningHorizon.allCases, id: \.self) { horizon in
                Text(horizon.displayName).tag(horizon)
            }
        }
        .pickerStyle(.segmented)
    } else {
        Text(cursorDateLabel) // "Wed • Nov 5"
            .font(.headline)
            .frame(maxWidth: .infinity)
    }
    
    // Right chevron
    Button {
        stepCursor(1)
    } label: {
        Image(systemName: "chevron.right")
            .font(.body.weight(.semibold))
    }
    .disabled(cursor >= 30) // Limit to 30 days forward
}
.contextMenu {
    Button("Jump to date…") {
        showDateJumpSheet = true
    }
}
```

---

## State-Based Logic Gates

| State | In bed | Dose 1 | Dose 2 | Final wake | Notes |
|-------|--------|--------|--------|------------|-------|
| **Planned** (no Dose 1) | ✅ Enabled | ✅ Enabled | ❌ Disabled | ✅ Enabled | Dose 2 caption: "Log Dose 1 to start the window" |
| **Armed** (Dose 1 logged, before open) | ✅ Enabled | ✅ Enabled (edit/overwrite) | ⚠️ Disabled (unless early allowed) | ✅ Enabled | Early allowed → show Early Override sheet |
| **Open** (within window) | ✅ Enabled | ✅ Enabled | ✅ Enabled | ✅ Enabled | WindowBar shows "ends in …" |
| **Closed** (after end) | ✅ Enabled | ✅ Enabled | ⚠️ Disabled (unless late allowed) | ✅ Enabled | Late allowed → show Late Override sheet |
| **Await Wake** (Dose 2 done) | ✅ Enabled | ✅ Enabled | ✅ Enabled (edit within X min) | ⭐ Highlighted | Wake actions elevated |
| **Closed night** | ❌ All write actions disabled | | | | Banner: "Night closed • Use History to edit" |

**Override Requirements:**
- Must write: `override_kind` (early/late), `override_minutes`, `reason`, `confirmed_at`
- Show sheet with reason text field + confirmation

---

## Micro-Polish Checklist

### Typography
- [ ] Use lowercase "g" with thin space: `4.25 g` (not `4.25g`)
- [ ] Consistent SF Symbols:
  - `moon.zzz` (In bed)
  - `pills.fill` (Dose 1/2)
  - `sun.and.horizon` (Final wake)
  - `alarm` (Alarm wake)
  - `bed.double` (Bed icon)
  - `figure.walk` (Natural wake)

### Haptics
- [ ] `.light` on success (dose logged)
- [ ] `.warning` on blocked action (disabled button tapped)
- [ ] `.medium` on window state change (opens/closes)

### Accessibility
- [ ] `accessibilityLabel` for each action: "Dose two now"
- [ ] `accessibilityHint` for disabled controls: "Available in 1 hour 47 minutes"
- [ ] Test with VoiceOver: should read full state + time remaining

### Seconds Toggle
- [ ] Honor `showSeconds` in WindowBar timer
- [ ] Honor `showSeconds` in Live Activity
- [ ] Honor `showSeconds` in notifications
- [ ] Honor `showSeconds` in event rows

### Debug
- [ ] Remove "Build 1.1.2" from main UI in production builds
- [ ] Add to Settings → Developer → About instead

---

## Implementation Order

### Phase 1: Layout Fixes (High Impact)
1. **Issue 2** - Move WindowPill inside plan card
2. **Issue 6** - Create WindowBar component (replace big ring)
3. **Issue 3** - Implement FlowLayout for chips

### Phase 2: Content/Logic Polish
4. **Issue 4** - Add Dose 2 disabled caption + accessibility
5. **Issue 7** - Fix Recent events (hide Undo when empty)
6. **Issue 8** - Add navigator chevrons + date jump

### Phase 3: Micro-Polish
7. Typography fixes (thin space in grams)
8. SF Symbols consistency
9. Haptics implementation
10. Accessibility audit

---

## Files to Create/Modify

### New Files
- `WindowBar.swift` - Compact progress bar with timer
- `FlowLayout.swift` - Wrapping horizontal layout (or use existing)
- `EventRow.swift` - Event display with icon + time
- `WindowMath.swift` - Helper for progress calculation

### Modified Files
- `NightCardViewModern.swift` - All layout updates
- `ActionButtons.swift` - Add caption support (already done)
- `TodayViewModel.swift` - Add state helpers (`canUndo()`, `windowState()`)
- `ThreeCardPlanningView.swift` - Navigator chevrons

---

## QA Checklist

Before marking complete:
- [ ] Dose 2 stays disabled until Dose 1; caption present
- [ ] WindowBar shows "opens in … / ends in … / closed … ago"
- [ ] "Planned → Logged" chip swaps label on first event
- [ ] Undo button hidden when stack empty; shows countdown when available
- [ ] One and only one gear (in nav)
- [ ] Scrolling works on SE-class devices
- [ ] No clipped content at XXL Dynamic Type
- [ ] VoiceOver: "Dose two disabled. Window opens in 1 hour 47 minutes"

---

## Next Steps

After this refinement is complete:
- Sketch History screen (7-day list + detail)
- Compact Live Activity layout matching WindowBar
- Settings enhancements (Items 17-24 from TODO)
