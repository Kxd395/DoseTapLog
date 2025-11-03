# Alarm Ladder System Implementation

## Overview

This document describes the robust notification/alarm ladder system for DoseTrack, implementing best practices for:
- Notification reliability across Focus modes, Low Power, and system throttling
- Clear state machine for window timing
- Budget-limited alerts to prevent alarm fatigue
- Time Sensitive notification opt-in
- Override policy with severity levels
- Idempotent notification scheduling with identifier discipline
- DST and time zone handling
- Telemetry for adherence tracking

## Core Components

### 1. WindowState (`ios/WindowState.swift`)

**Purpose**: Single source of truth for Dose 2 window state.

**States**:
- `noDose1` - No Dose 1 logged yet
- `waiting(start: Date)` - Before window opens
- `open(start: Date, end: Date)` - Window is open
- `grace(end: Date, graceEnd: Date)` - Late grace period (default 15 min after end)
- `closed(end: Date)` - Beyond grace period

**Key Method**:
```swift
static func compute(
    now: Date,
    dose1: Date?,
    startMin: Int,
    endMin: Int,
    lateGraceMin: Int = 15,
    calendar: Calendar = .current
) -> WindowState
```

**Features**:
- Pure function (no side effects, easy to test)
- Uses `Calendar.date(byAdding:)` for DST safety
- Provides override gates (early/late with severity)
- Time zone rebase detection and UI helper

### 2. NightAlarmPlan (`ios/NightAlarmPlan.swift`)

**Purpose**: Bundles all scheduled notifications for one night with budget tracking.

**Properties**:
- `nightKey: String` - Night identifier (YYYY-MM-DD)
- `start/end/graceEnd: Date` - Window boundaries
- `identifiers: [String]` - All scheduled notification IDs
- `budgetConsumed/budgetLimit: Int` - Alert budget (default 3)
- `plannedTimeZone: TimeZone` - For DST/travel detection

**Identifier Pattern**: `{nightKey}.dose2.{purpose}`
Examples:
- `2025-11-02.dose2.open`
- `2025-11-02.dose2.closing`
- `2025-11-02.dose2.end`
- `2025-11-02.dose2.hard.1`

**Alarm Types**:
- `preWindow` - Pre-window nudge (optional, collapsed if within 10 min of open)
- `open` - Window opened
- `closing` - Window closing soon (last 30 min)
- `end` - Window ended
- `hard1/hard2/hard3` - Hard alarm repeats (opt-in only)

**Alarm Styles**:
- `quiet` - 1 alert (window open only)
- `normal` - 3 alerts (open, closing, end)
- `strong` - 5 alerts (normal + hard repeats, requires explicit consent)

**Telemetry**:
Tracks `scheduled`, `delivered`, `acted`, `snoozed`, `canceled`, `suppressed` events per alarm with device type (phone/watch).

### 3. AlarmOrchestrator (`ios/AlarmOrchestrator.swift`)

**Purpose**: Manages all notification lifecycle.

**Protocol**:
```swift
protocol AlarmOrchestrating {
    func arm(for plan: NightAlarmPlan, style: AlarmStyle) async throws -> NightAlarmPlan
    func cancelAll(forNightKey: String) async
    func snooze(forNightKey: String, minutes: Int) async throws
    func markDelivered(identifier: String, nightKey: String) async
    func recordInteraction(nightKey: String)
    func pendingCount(forNightKey: String) async -> Int
}
```

**Features**:
- **Idempotent arming**: Cancels existing alarms before scheduling new ones
- **Budget enforcement**: Stops scheduling when limit reached
- **Identifier discipline**: All IDs follow `{nightKey}.dose2.{purpose}` pattern
- **Cancel by prefix**: `cancelAll` removes all alarms for a night
- **Snooze replaces next**: Snooze reschedules next alarm, never stacks
- **Interaction suppression**: If user interacts within 5 min of alert, suppress next scheduled alert
- **Time Sensitive opt-in**: Respects `respectDND` policy (off/timeSensitive/ask)
- **Telemetry logging**: Tracks all alarm events for analysis

**Budget Behavior**:
```swift
switch style {
case .quiet:
    // Schedule: open (1 alert)
case .normal:
    // Schedule: open, closing, end (up to 3 alerts)
case .strong:
    // Schedule: open, closing, end, hard1, hard2, hard3 (up to 5 alerts)
}
```

**Pre-window Collapse**:
If `preWindowLeadMinutes` is within 10 minutes of window open, pre-window nudge is skipped to avoid spam.

### 4. AppPreferences Updates

**New Settings**:

#### Alarm Ladder Policy
```swift
var alarmStyle: AlarmStyle              // quiet/normal/strong
var alarmBudgetPerNight: Int            // Default 3
var preWindowLeadMinutes: Int           // 0 = disabled
var hardAfterEndEnabled: Bool           // Allow hard repeats
var hardRepeatMinutes: Int              // Interval between repeats (default 15)
var hardMaxRepeats: Int                 // Max 3
var respectDND: DNDPolicy               // off/timeSensitive/ask
var timeSensitiveConsent: Bool          // User agreed to Time Sensitive
var strongAlarmConsent: Bool            // User agreed to Strong style
```

#### Late Dose Policy
```swift
var lateGraceMinutes: Int               // Grace period after end (default 15)
```

**DNDPolicy Enum**:
- `off` - Always interrupt (ignore Focus)
- `timeSensitive` - Use Time Sensitive interruption (requires permission)
- `ask` - Ask user on first alarm

## Override Policy Gates

### Early Override
**Allowed if**: `now < windowStart && minutesEarly <= maxEarlyMinutes`

**Severity**:
- `normal` - Within policy limit (e.g., ≤60 min early)
- `critical` - Beyond limit, requires double confirm + free text reason

**UI Flow**:
1. User taps "Dose 2 now" before window
2. First tap: Show banner "Early by X minutes. Tap again to confirm."
3. Second tap (within 10 sec): Open `EarlyDoseSheetView`
4. Sheet shows: Warning, dose details, reason picker (if required), time-prior options
5. Confirm: Log with `override_kind='early'`, `early_by_min=X`, `override_reason`, `override_confirmed=1`

### Late Override
**Allowed if**: `now > windowEnd`

**Severity**:
- `normal` - Within grace period (≤15 min after end) OR within maxLateMinutes (e.g., ≤30 min)
- `critical` - Beyond maxLateMinutes, requires double confirm + free text

**Grace Period**: First 15 minutes after window end. Late doses in grace are `normal` severity (reason optional).

**UI Flow**:
1. User taps "Dose 2 now" after window
2. First tap: Show banner "Late by X minutes. Tap again to confirm."
3. Second tap (within 10 sec): Open `LateDoseSheetView`
4. Sheet shows: Warning, late info, reason picker (required if policy says so), custom text field
5. Confirm: Log with `override_kind='late'`, `late_by_min=X`, `override_reason`, `override_confirmed=1`

**Critical Late**: If beyond grace + maxLate, require:
- Reason (mandatory)
- Second confirmation: "I took it anyway" checkbox
- Tag with `override_severity=critical`

## Database Schema

### event_log Columns (Migration 005)
```sql
ALTER TABLE event_log ADD COLUMN override_kind TEXT CHECK (override_kind IN ('none','early','late'));
ALTER TABLE event_log ADD COLUMN early_by_min INTEGER;
ALTER TABLE event_log ADD COLUMN late_by_min INTEGER;
ALTER TABLE event_log ADD COLUMN override_reason TEXT;
ALTER TABLE event_log ADD COLUMN override_confirmed INTEGER CHECK (override_confirmed IN (0,1));
```

### Safety Triggers
```sql
-- Prevent early >60 min (absolute hard limit)
CREATE TRIGGER trg_dose2_early_policy
BEFORE INSERT ON event_log
WHEN NEW.override_kind = 'early' AND NEW.early_by_min > 60
BEGIN
    SELECT RAISE(ABORT, 'Early override exceeds 60-minute hard limit');
END;

-- Prevent late >120 min (would be missed dose)
CREATE TRIGGER trg_dose2_late_policy
BEFORE INSERT ON event_log
WHEN NEW.override_kind = 'late' AND NEW.late_by_min > 120
BEGIN
    SELECT RAISE(ABORT, 'Late override exceeds 120-minute hard limit');
END;

-- Ensure override_confirmed=1 when override is used
CREATE TRIGGER trg_dose2_override_confirmed
BEFORE INSERT ON event_log
WHEN NEW.override_kind IN ('early', 'late') AND NEW.override_confirmed != 1
BEGIN
    SELECT RAISE(ABORT, 'Override must be confirmed');
END;
```

## Notification Reliability

### Focus Mode Handling
**Issue**: Local notifications can be delayed/silenced by Focus, Low Power, Summary.

**Solution**:
1. Default: `interruptionLevel = .active` (respects Focus)
2. If user opts in: `interruptionLevel = .timeSensitive` (breaks through most Focus modes)
3. Require explicit consent for Time Sensitive via Settings toggle
4. Show red chip if notifications blocked: "Notifications blocked. Fix." → Deep link to system Settings

### Live Activity Expectations
**Issue**: Live Activities can be throttled or ended by system.

**Solution**:
- Treat Live Activity as decorative only
- Scheduling truth is pending notifications + state machine
- On app foreground: Reconcile ring state from `Dose1Time + windowStartMin`, NOT from Live Activity progress

### Alarm Fatigue Prevention
**Issue**: Pre-window, open, half, closing, end can spam users.

**Solution**:
1. **Budget limit**: Default 3 alerts per night before user action required to re-arm
2. **Collapse close alerts**: If pre-window is within 10 min of open, skip pre-window
3. **Interaction suppression**: If user interacts within 5 min of any alert, suppress next scheduled alert
4. **Escalation path**: quiet (1) → normal (3) → strong (5, opt-in only)

## Concurrency and Idempotency

### Reset Night Safety
**Issue**: "Reset Night" can leave phantom alerts alive.

**Solution**:
1. Every scheduled item uses `{nightKey}.dose2.{purpose}` identifier
2. Before Reset Night or re-arm: `cancelAll(forNightKey:)` removes by prefix
3. Verify zero pending with `pendingCount(forNightKey:)` after cancel

### Snooze Behavior
**Issue**: Snoozes can stack parallel alerts.

**Solution**:
- Snooze finds next pending alarm for the night
- Cancels it
- Reschedules with new fire time
- **Never** creates a new parallel series

## DST and Time Zone Handling

### Date Math
**Issue**: Raw `Date` arithmetic breaks on DST fall-back or travel.

**Solution**:
- Use `Calendar.date(byAdding: .minute, value: N, to: dose1)` with explicit calendar and time zone
- Time zone is captured at Dose 1 logging: `plan.plannedTimeZone = TimeZone.current`
- On foreground: Check `WindowState.needsRebase(dose1TimeZone:currentTimeZone:)`

### Time Zone Change
**Solution**:
- **Never auto-shift**: Don't silently adjust window times
- Show **Rebase Sheet**: "Old window 01:30–03:30, new window 02:30–04:30. Pick one."
- Use `WindowState.rebaseInfo(dose1:startMin:endMin:oldZone:newZone:)` for display
- Log `planned_zone_id` and `actual_zone_id` for audit

## Templates (Deferred)

**Recommendation**: Keep only **Workday** and **Off-day** templates initially.

**Travel Mode**: Becomes a one-time "Rebase Tonight" chip, not a persistent template.

**Adherence Feedback**: If user hits Dose 2 late 3+ times in a week on Workday, suggest moving Dose 1 15 min earlier. **Never auto-change**.

## Accessibility

### Inclusive Alerts
**Issue**: "Soft tone" and "louder tone" not inclusive.

**Solution**:
- Provide modes: vibration-only, tone-only, watch-only
- Respect Reduce Motion and Attention Aware settings
- Option: Require cognitive check to silence hard alerts ("tap 2 then 5") to avoid groggy swipes

## Safety and Scope

### Factual Language Only
**Rule**: Never prescriptive. No "should" on dose timing.

**Examples**:
✅ "Window opens at 01:30"
✅ "You are 22 minutes late, logging will be recorded as a late override."
❌ "You should take Dose 2 now"
❌ "This is the best time for your dose"

## Telemetry and Analytics

### Per-Night Metrics
Track in `NightAlarmPlan.AlarmEvent`:
- `scheduled` - How many alerts were scheduled
- `delivered` - How many were delivered by system
- `acted` - How many user tapped
- `snoozed` - How many snoozed
- `canceled` - How many canceled (Reset Night, re-arm)
- `suppressed` - How many suppressed (budget, interaction window)

### Dashboard Metrics
- **Missed Dose 2 rate**: % of nights with no Dose 2 logged
- **Average window lateness**: Minutes from window open to Dose 2
- **Budget exhaustion rate**: % of nights where budget hit limit
- **Alarm fatigue indicator**: Snoozed / Delivered ratio

### Device Attribution
Log `deviceType: .phone | .watch | .unknown` to track which device delivered the tap.

## Testing Strategy

### Unit Tests
```swift
// WindowState edge cases
testWindowState_atDSTFallback()
testWindowState_earlyBy59Minutes()
testWindowState_lateInGracePeriod()
testWindowState_lateAfterGrace()

// Snooze math
testSnooze_replacesNextAlarm()
testSnooze_doesNotStack()

// Budget enforcement
testArm_respectsBudgetLimit()
testArm_skipsAlarmsWhenBudgetExhausted()
```

### Integration Tests
```swift
// Scheduling
testDose1At2245_schedulesCorrectAlarms()
testDose1At2245_identifiersFollowPattern()
testResetNight_cancelsAllAlarms()
testResetNight_verifiesZeroPending()

// Interaction suppression
testUserTapsNotification_suppressesNextAlert()
```

### UI Tests
```swift
// Notification actions
testTapNotification_invokesDose2Attempt()
testTapNotification_passesCorrectOverrideContext()
```

## Implementation Checklist

### Phase 1: Core State Machine ✅
- [x] WindowState.swift with compute()
- [x] WindowState override gates (early/late with severity)
- [x] WindowState time zone rebase detection

### Phase 2: Alarm Infrastructure ✅
- [x] NightAlarmPlan.swift with budget tracking
- [x] AlarmOrchestrator.swift with identifier discipline
- [x] Idempotent arm/cancel/snooze
- [x] Telemetry events

### Phase 3: Settings ✅
- [x] Add alarm ladder policy settings to AppPreferences
- [x] Add DNDPolicy enum
- [x] Add lateGraceMinutes

### Phase 4: UI Integration
- [ ] Update SettingsViewEnhanced with alarm ladder section
- [ ] Add alarm style picker (quiet/normal/strong)
- [ ] Add consent toggles (Time Sensitive, Strong)
- [ ] Add notification status chip ("Notifications blocked. Fix.")
- [ ] Add alarm summary line ("Next alert 02:18:35. Budget 2 of 3 left.")

### Phase 5: ViewModel Integration
- [ ] Update TodayViewModel to use WindowState.compute()
- [ ] Replace manual timing checks with windowState gates
- [ ] Integrate AlarmOrchestrator for notification scheduling
- [ ] Add alarm summary to Today view

### Phase 6: Testing
- [ ] Write WindowState unit tests
- [ ] Write AlarmOrchestrator tests
- [ ] Integration test for Dose 1 → alarm scheduling
- [ ] UI test for notification → override flow

### Phase 7: Documentation
- [ ] Update PRODUCT_DESCRIPTION.md with alarm ladder
- [ ] Update PRD with notification reliability section
- [ ] Create user guide for alarm styles

## Next Steps

1. **Add Settings UI** for alarm ladder controls
2. **Integrate WindowState** into TodayViewModel
3. **Wire AlarmOrchestrator** to Dose 1 logging
4. **Add notification handlers** for alarm taps
5. **Test alarm scheduling** with real notifications
6. **Add telemetry dashboard** to visualize adherence

## References

- Constitution Principle I (Safety First): Alarm hard limits enforced by triggers
- Constitution Principle II (Local-First Privacy): All alarm data stays on device
- Spec requirement: Two-tap confirmation for early/late overrides
- PRD section 4.3: Notification system with Focus mode handling
