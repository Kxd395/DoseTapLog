//
//  NightCardViewModern.swift
//  DoseTrack
//
//  Modern dark-mode-first version of NightCardView
//  Uses WindowBar, ModernStatusChip, and ActionButtons
//

import SwiftUI
import SwiftData

/// Modern night card with dark UI, compact window bar, and action grid
struct NightCardViewModern: View {
    let horizon: PlanningHorizon
    let night: DoseLog?
    let modelContext: ModelContext
    
    @State private var showPlanEditor = false
    @State private var showEarlyDoseSheet = false
    @State private var showLateDoseSheet = false
    @State private var showWakeSheet = false
    @State private var showWhyDose2Disabled = false
    
    // New override sheets
    @State private var showEarlyDose2Sheet = false
    @State private var showLateDose2Sheet = false
    @State private var showBlockedSheet = false
    @State private var showNeedDose1Sheet = false
    @State private var showAlreadyLoggedSheet = false
    
    @State private var blockedReason: String = ""
    @State private var dose2Gate: Dose2Gate = .needDose1
    
    // Undo window state
    @State private var undoSecondsRemaining: Int = 0
    @State private var undoAction: String = ""
    @State private var undoTimer: Timer?
    @State private var savedNightState: DoseLog?
    
    private let prefs = AppPreferencesEnhanced.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: DT.gap) {
                    if let night = night {
                        // Plan card (now includes WindowPill)
                        planCard(night)
                        
                        // Next alert chip (if scheduled)
                        nextAlertChipRow(night)
                        
                        // Status chips
                        statusChipsRow(night)
                        
                        // Window bar (compact, only when window is active)
                        if night.currentLifecycleState.isActive || night.currentLifecycleState == .windowOpen {
                            windowBarSection(night)
                        }
                        
                        // Actions section with hint
                        SectionHeader(
                            title: "Actions",
                            hint: dose2Enabled(night) ? nil : dose2DisabledHint(night)
                        )
                        
                        actionsGrid(night)
                        
                        // Recent events
                        if horizon == .tonight || horizon == .lastNight {
                            recentEventsCard(night)
                        }
                    } else {
                        // No night yet (Tomorrow)
                        emptyStateCard
                    }
                }
                .padding(DT.pad)
                .padding(.bottom, undoSecondsRemaining > 0 ? 80 : 0) // Space for undo banner
            }
            
            // Undo banner (floating at bottom)
            if undoSecondsRemaining > 0 {
                UndoBanner(
                    actionName: undoAction,
                    secondsRemaining: undoSecondsRemaining,
                    onUndo: performUndo
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(), value: undoSecondsRemaining)
            }
        }
        .background(Palette.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showWhyDose2Disabled) {
            whyDose2DisabledSheet
        }
        .sheet(isPresented: $showEarlyDose2Sheet) {
            if let night = night {
                if case .tooEarly(let minutes) = dose2Gate {
                    EarlyDose2Sheet(
                        minutesEarly: minutes,
                        policy: Dose2Policy.from(prefs),
                        onConfirm: { override in
                            logDose2WithOverride(night, override: override)
                        },
                        onRemindAtStart: {
                            scheduleWindowStartReminder()
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showLateDose2Sheet) {
            if let night = night {
                if case .tooLate(let minutes) = dose2Gate {
                    LateDose2Sheet(
                        minutesLate: minutes,
                        policy: Dose2Policy.from(prefs),
                        onConfirm: { override in
                            logDose2WithOverride(night, override: override)
                        },
                        onLogMissed: {
                            logMissedDose2(night)
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showBlockedSheet) {
            Dose2BlockedSheet(
                reason: blockedReason,
                onRemindAtStart: {
                    scheduleWindowStartReminder()
                }
            )
        }
        .sheet(isPresented: $showNeedDose1Sheet) {
            if let night = night {
                NeedDose1Sheet(
                    onLogDose1Now: {
                        logDose1(night)
                    },
                    onSetReminder: {
                        // TODO: Schedule Dose 1 reminder
                    }
                )
            }
        }
        .sheet(isPresented: $showAlreadyLoggedSheet) {
            if let night = night, let dose2Time = night.dose2TimeUTC {
                Dose2AlreadyLoggedSheet(
                    loggedAt: dose2Time,
                    onEditTime: {
                        // TODO: Open edit time sheet
                    },
                    onUndo: {
                        // TODO: Undo Dose 2 (if within 30s window)
                    }
                )
            }
        }
    }
    
    // MARK: - Plan Card
    
    @ViewBuilder
    private func planCard(_ night: DoseLog) -> some View {
        VStack(alignment: .leading, spacing: DT.md) {
            Text("Tonight plan")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.text)
            
            // Grid layout for perfect Dose 1/2 alignment
            Grid(horizontalSpacing: DT.lg, verticalSpacing: 2) {
                GridRow {
                    Text("Dose 1")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    Text("Dose 2")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                }
                
                GridRow {
                    Text(formatGrams(night.dose1Grams ?? prefs.planDose1G))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Palette.text)
                        .monospacedDigit() // Prevents digit jitter
                    
                    Text(formatGrams(night.dose2Grams ?? prefs.planDose2G))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Palette.text)
                        .monospacedDigit() // Prevents digit jitter
                        .gridColumnAlignment(.trailing)
                }
            }
            
            // Window info
            if let d1 = night.dose1TimeUTC {
                let windowStart = d1.addingTimeInterval(Double(prefs.windowStartMin * 60))
                let windowEnd = d1.addingTimeInterval(Double(prefs.windowEndMin * 60))
                Text("Window: \(formatTime(windowStart)) – \(formatTime(windowEnd))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Window: \(prefs.windowStartMin)–\(prefs.windowEndMin) min after Dose 1")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Window status pill (moved inside plan card)
            WindowPill(
                dose1At: night.dose1TimeUTC,
                windowStartMin: prefs.windowStartMin,
                windowEndMin: prefs.windowEndMin,
                showSeconds: prefs.showSeconds
            )
        }
        .padding(DT.lg)
        .background(
            RoundedRectangle(cornerRadius: DT.corner)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DT.corner)
                .stroke(Color.white.opacity(DT.strokeOpacity), lineWidth: DT.strokeWidth)
        )
    }
    
    // MARK: - Next Alert Chip
    
    @ViewBuilder
    private func nextAlertChipRow(_ night: DoseLog) -> some View {
        // Next alert chip (if scheduled)
        if let nextAlert = nextScheduledAlert(for: night) {
            HStack {
                NextAlertChip(
                    nextAlertTime: nextAlert,
                    alarmStyle: currentAlarmStyle()
                )
                Spacer()
            }
            .padding(.horizontal, DT.pad)
        }
    }
    
    /// Get next scheduled alert time for this night
    /// TODO: Wire to actual notification scheduler
    private func nextScheduledAlert(for night: DoseLog) -> Date? {
        // Temporary: Calculate expected window open time
        guard let d1 = night.dose1TimeUTC else { return nil }
        let windowOpen = d1.addingTimeInterval(Double(prefs.windowStartMin) * 60)
        
        // Only show if window hasn't opened yet
        return Date() < windowOpen ? windowOpen : nil
    }
    
    /// Get current alarm style setting
    /// TODO: Wire to actual preferences
    private func currentAlarmStyle() -> AlarmStyle {
        return .normal // Default for now
    }
    
    // MARK: - Status Chips
    
    @ViewBuilder
    private func statusChipsRow(_ night: DoseLog) -> some View {
        let perDoseMin = 1.5, perDoseMax = 4.5 // Safety constants from AppPreferencesEnhanced
        
        // Use wrapping HStack for chips (or FlowLayout when available)
        HStack(spacing: DT.md) {
            Chip(
                icon: "exclamationmark.triangle.fill",
                text: "Per dose \(formatGrams(perDoseMin))–\(formatGrams(perDoseMax))",
                tone: .warn
            )
            
            Chip(
                icon: loggedTotal(night) > 0 ? "book.closed.fill" : "sum",
                text: loggedTotal(night) > 0 
                    ? "Logged \(formatGrams(loggedTotal(night)))"
                    : "Planned \(formatGrams(plannedTotal(night)))",
                tone: .neutral
            )
        }
        .padding(.horizontal, DT.lg)
    }
    
    // MARK: - Window Bar (Compact)
    
    @ViewBuilder
    private func windowBarSection(_ night: DoseLog) -> some View {
        WindowBar(
            status: windowStatus(night),
            progress: windowProgress(night),
            leadingText: windowLeadingText(night),
            showSeconds: prefs.showSeconds
        )
    }
    
    private func windowStatus(_ night: DoseLog) -> WindowBar.Status {
        switch night.currentLifecycleState {
        case .active:
            return .waiting
        case .windowOpen:
            // Check if closing soon (< 30 min remaining)
            if let d1 = night.dose1TimeUTC {
                let windowEnd = d1.addingTimeInterval(Double(prefs.windowEndMin * 60))
                let remaining = windowEnd.timeIntervalSinceNow
                return remaining < 1800 ? .closingSoon : .open
            }
            return .open
        case .windowClosed:
            return .expired
        default:
            return .waiting
        }
    }
    
    private func windowProgress(_ night: DoseLog) -> Double {
        guard let d1 = night.dose1TimeUTC else { return 0.0 }
        
        let windowStart = d1.addingTimeInterval(Double(prefs.windowStartMin * 60))
        let windowEnd = d1.addingTimeInterval(Double(prefs.windowEndMin * 60))
        let now = Date()
        
        if now < windowStart {
            // Before window
            let totalWait = windowStart.timeIntervalSince(d1)
            let elapsed = now.timeIntervalSince(d1)
            return min(1.0, max(0.0, elapsed / totalWait))
        } else if now <= windowEnd {
            // During window
            let duration = windowEnd.timeIntervalSince(windowStart)
            let elapsed = now.timeIntervalSince(windowStart)
            return min(1.0, max(0.0, elapsed / duration))
        } else {
            // After window
            return 1.0
        }
    }
    
    private func windowLeadingText(_ night: DoseLog) -> String {
        guard let d1 = night.dose1TimeUTC else {
            return "Waiting for Dose 1"
        }
        
        let windowStart = d1.addingTimeInterval(Double(prefs.windowStartMin * 60))
        let windowEnd = d1.addingTimeInterval(Double(prefs.windowEndMin * 60))
        let now = Date()
        
        if now < windowStart {
            let remaining = windowStart.timeIntervalSinceNow
            return "Opens in \(formatDuration(remaining))"
        } else if now <= windowEnd {
            let remaining = windowEnd.timeIntervalSinceNow
            return "Ends in \(formatDuration(remaining))"
        } else {
            let elapsed = now.timeIntervalSince(windowEnd)
            return "Expired \(formatDuration(elapsed)) ago"
        }
    }
    
    // MARK: - Actions Grid
    
    @ViewBuilder
    private func actionsGrid(_ night: DoseLog) -> some View {
        ActionGrid(
            primaryActions: [
                .init(title: "In bed", icon: "moon.fill", action: {
                    logInBed(night)
                }),
                .init(title: "Dose 1", icon: "pills.fill", action: {
                    logDose1(night)
                }),
                .init(
                    title: "Dose 2",
                    icon: dose2Enabled(night) ? "pills.fill" : "lock.fill",
                    action: {
                        if dose2Enabled(night) {
                            tryLogDose2(night)
                        } else {
                            showWhyDose2Disabled = true
                        }
                    },
                    disabled: !dose2Enabled(night)
                ),
                .init(title: "Final wake", icon: "sunrise.fill", action: {
                    logFinalWake(night)
                })
            ],
            secondaryActions: [
                .init(title: "Alarm wake", icon: "alarm.fill", action: {
                    logAlarmWake(night)
                }),
                .init(title: "Natural wake", icon: "bed.double.fill", action: {
                    logNaturalWake(night)
                }),
                .init(title: "Bathroom", icon: "figure.walk", action: {
                    logBathroom(night)
                }),
                .init(title: "Reset night", icon: "arrow.counterclockwise", action: {
                    resetNight(night)
                }, tone: Palette.danger)
            ]
        )
    }
    
    // MARK: - Recent Events
    
    @ViewBuilder
    private func recentEventsCard(_ night: DoseLog) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent")
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                Spacer()
                Button("Undo last") {
                    // TODO: Undo last event
                }
                .font(.footnote)
                .foregroundStyle(Palette.primary)
            }
            
            // Show last 5 events
            if night.dose1TimeUTC == nil && night.dose2TimeUTC == nil {
                Text("No events yet")
                    .font(.footnote)
                    .foregroundStyle(Palette.dim)
            } else {
                // TODO: Show actual events from event log
                eventRow(icon: "pills.fill", text: "Dose 1 logged", time: "8:30 PM", color: Palette.dose1)
                eventRow(icon: "pills.circle.fill", text: "Dose 2 logged", time: "12:15 AM", color: Palette.dose2)
            }
        }
        .padding(DT.pad)
        .background(
            RoundedRectangle(cornerRadius: DT.corner)
                .fill(Palette.surface)
        )
    }
    
    @ViewBuilder
    private func eventRow(icon: String, text: String, time: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .bold()
                .foregroundStyle(Palette.text)
            Spacer()
            Text(time)
                .foregroundStyle(Palette.dim)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: DT.chipCorner)
                .fill(Palette.surfaceHi)
        )
    }
    
    // MARK: - Empty State
    
    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            Text("No plan yet for \(horizon.displayName)")
                .font(.headline)
                .foregroundStyle(Palette.dim)
            
            Button("Create Plan from Template") {
                // TODO: Create plan
            }
            .buttonStyle(.bordered)
        }
        .padding(DT.pad)
        .background(
            RoundedRectangle(cornerRadius: DT.corner)
                .fill(Palette.surface)
        )
    }
    
    // MARK: - Helper Methods
    
    private func perDoseSafe(_ night: DoseLog) -> Bool {
        let perDoseMin = 1.5, perDoseMax = 4.5  // Safety constants from AppPreferencesEnhanced
        let d1 = night.dose1Grams ?? 0
        let d2 = night.dose2Grams ?? 0
        return d1 >= perDoseMin && d1 <= perDoseMax &&
               d2 >= perDoseMin && d2 <= perDoseMax
    }
    
    private func plannedTotal(_ night: DoseLog) -> Double {
        return prefs.planDose1G + prefs.planDose2G
    }
    
    private func loggedTotal(_ night: DoseLog) -> Double {
        return (night.dose1Grams ?? 0) + (night.dose2Grams ?? 0)
    }
    
    private func dose2Enabled(_ night: DoseLog) -> Bool {
        // Dose 2 already logged
        if night.dose2TimeUTC != nil { return false }
        
        // Dose 1 not logged yet
        guard let d1 = night.dose1TimeUTC else { return false }
        
        let now = Date()
        let windowStart = d1.addingTimeInterval(Double(prefs.windowStartMin) * 60)
        let windowEnd = d1.addingTimeInterval(Double(prefs.windowEndMin) * 60)
        
        // Within window
        if now >= windowStart && now <= windowEnd {
            return true
        }
        
        // Early override allowed
        if prefs.allowEarlyDose && now < windowStart {
            let minutesUntilOpen = windowStart.timeIntervalSince(now) / 60
            return minutesUntilOpen <= Double(prefs.maxEarlyMinutes)
        }
        
        return false
    }
    
    private func formatGrams(_ value: Double) -> String {
        String(format: "%.2f", value) + "\u{2009}g"  // Thin space + lowercase g
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let absSeconds = abs(seconds)
        let hours = Int(absSeconds) / 3600
        let minutes = Int(absSeconds) / 60 % 60
        let secs = Int(absSeconds) % 60
        
        if prefs.showSeconds {
            return String(format: "%dh %dm %ds", hours, minutes, secs)
        } else {
            return String(format: "%dh %dm", hours, minutes)
        }
    }
    
    // MARK: - Action Handlers (Stubs)
    
    private func logInBed(_ night: DoseLog) {
        print("Log in bed")
    }
    
    private func logDose1(_ night: DoseLog) {
        night.dose1TimeUTC = Date()
        night.dose1Grams = prefs.planDose1G
        try? modelContext.save()
        
        // Haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        print("Logged Dose 1")
    }
    
    private func tryLogDose2(_ night: DoseLog) {
        // Evaluate gate
        let policy = Dose2Policy.from(prefs)
        let gate = evaluateDose2Gate(
            now: Date(),
            dose1At: night.dose1TimeUTC,
            dose2At: night.dose2TimeUTC,
            policy: policy
        )
        
        // Store gate for sheets
        dose2Gate = gate
        
        // Handle each gate state
        switch gate {
        case .ready:
            // Log immediately
            logDose2Now(night, override: nil)
            
        case .tooEarly(let minutes):
            if isOverrideAllowed(gate: gate, policy: policy) {
                // Show early override sheet
                showEarlyDose2Sheet = true
            } else {
                // Blocked
                blockedReason = "Dose 2 must be at least \(prefs.windowStartMin) min after Dose 1. You're \(minutes) min early."
                showBlockedSheet = true
            }
            
        case .tooLate(let minutes):
            if isOverrideAllowed(gate: gate, policy: policy) {
                // Show late override sheet
                showLateDose2Sheet = true
            } else {
                // Blocked
                blockedReason = "Window ended \(minutes) min ago."
                showBlockedSheet = true
            }
            
        case .needDose1:
            showNeedDose1Sheet = true
            
        case .alreadyLogged:
            showAlreadyLoggedSheet = true
        }
    }
    
    private func logDose2Now(_ night: DoseLog, override: Dose2Override?) {
        // Save state snapshot for undo
        let snapshot = createStateSnapshot(night)
        
        night.dose2TimeUTC = Date()
        night.dose2Grams = prefs.planDose2G
        
        // Store override data if present
        if let override = override {
            night.dose2IsOverride = true
            night.dose2OverrideKind = override.kind.rawValue
            night.dose2OverrideMinutes = override.minutes
            night.dose2OverrideReason = override.reason
        }
        
        try? modelContext.save()
        
        // Cancel any pending window start reminder since Dose 2 is now logged
        NotificationHelper.shared.cancelWindowStartReminder()
        
        // Haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Start undo window
        let actionName = override != nil 
            ? "Dose 2 (\(formatGrams(prefs.planDose2G)), \(override!.kind.rawValue))"
            : "Dose 2 (\(formatGrams(prefs.planDose2G)))"
        startUndoWindow(actionName: actionName, savedState: snapshot)
        
        print("Logged Dose 2")
    }
    
    private func logDose2WithOverride(_ night: DoseLog, override: Dose2Override) {
        logDose2Now(night, override: override)
    }
    
    private func logMissedDose2(_ night: DoseLog) {
        // TODO: Log as missed dose with flag
        print("Log missed Dose 2")
    }
    
    private func logFinalWake(_ night: DoseLog) {
        print("Log final wake")
    }
    
    private func logAlarmWake(_ night: DoseLog) {
        print("Log alarm wake")
    }
    
    private func logNaturalWake(_ night: DoseLog) {
        print("Log natural wake")
    }
    
    private func logBathroom(_ night: DoseLog) {
        print("Log bathroom")
    }
    
    private func resetNight(_ night: DoseLog) {
        print("Reset night")
    }
    
    // MARK: - Helper: Dose 2 Disabled Hint
    
    /// Short parenthetical hint for section header (not the full caption)
    private func dose2DisabledHint(_ night: DoseLog) -> String? {
        guard !dose2Enabled(night) else { return nil }
        
        if night.dose1TimeUTC == nil {
            return "Dose 2 locked until Dose 1"
        }
        
        // If Dose 1 logged but window not open yet
        let d1 = night.dose1TimeUTC!
        let now = Date()
        let windowStart = d1.addingTimeInterval(Double(prefs.windowStartMin) * 60)
        
        if now < windowStart {
            let remainingMinutes = Int(windowStart.timeIntervalSince(now) / 60)
            return "Opens in \(remainingMinutes)m"
        }
        
        return "Window expired"
    }
    
    // MARK: - Why Dose 2 Disabled Sheet
    
    @ViewBuilder
    private var whyDose2DisabledSheet: some View {
        VStack(spacing: DT.lg) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Dose 2 is locked")
                .font(.title2.bold())
            
            if let night = night {
                Text(dose2DisabledExplanation(night))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: DT.md) {
                Button("Remind me at window start") {
                    scheduleWindowStartReminder()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Close") {
                    showWhyDose2Disabled = false
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, DT.sm)
        }
        .padding(DT.xl)
        .presentationDetents([.height(280)])
    }
    
    /// Full explanation for the sheet
    private func dose2DisabledExplanation(_ night: DoseLog) -> String {
        if night.dose1TimeUTC == nil {
            return "Log Dose 1 to start the dosing window."
        }
        
        let d1 = night.dose1TimeUTC!
        let now = Date()
        let windowStart = d1.addingTimeInterval(Double(prefs.windowStartMin) * 60)
        let windowEnd = d1.addingTimeInterval(Double(prefs.windowEndMin) * 60)
        
        if now < windowStart {
            let remainingSeconds = windowStart.timeIntervalSince(now)
            let remainingMinutes = Int(remainingSeconds / 60)
            let hours = remainingMinutes / 60
            let mins = remainingMinutes % 60
            let timeStr = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
            return "Window opens in \(timeStr) (\(prefs.windowStartMin)–\(prefs.windowEndMin) min after Dose 1)."
        }
        
        // Window expired
        let expiredSeconds = now.timeIntervalSince(windowEnd)
        let expiredMinutes = Int(expiredSeconds / 60)
        let hours = expiredMinutes / 60
        let mins = expiredMinutes % 60
        let timeStr = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
        return "The dosing window expired \(timeStr) ago."
    }
    
    private func scheduleWindowStartReminder() {
        guard let night = night, let d1 = night.dose1TimeUTC else {
            print("⚠️ Cannot schedule reminder: no Dose 1 logged")
            showWhyDose2Disabled = false
            return
        }
        
        let windowStartTime = d1.addingTimeInterval(Double(prefs.windowStartMin) * 60)
        
        Task {
            let success = await NotificationHelper.shared.scheduleWindowStartReminder(at: windowStartTime)
            
            await MainActor.run {
                if success {
                    // Show confirmation
                    print("✅ Reminder scheduled for \(windowStartTime)")
                    // Could add a toast/banner here
                } else {
                    // Permission denied - could show settings prompt
                    print("⚠️ Failed to schedule reminder - check notification permissions")
                }
                showWhyDose2Disabled = false
            }
        }
    }
    
    // MARK: - Undo Window Logic
    
    /// Start undo countdown after logging an action
    private func startUndoWindow(actionName: String, savedState: DoseLog) {
        // Cancel any existing timer
        undoTimer?.invalidate()
        
        // Save state for restoration
        savedNightState = savedState
        undoAction = actionName
        undoSecondsRemaining = 30
        
        // Start countdown timer
        undoTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
            if undoSecondsRemaining > 0 {
                undoSecondsRemaining -= 1
            } else {
                timer.invalidate()
                savedNightState = nil
                undoAction = ""
            }
        }
    }
    
    /// Perform undo - restore saved state
    private func performUndo() {
        guard let savedState = savedNightState, let night = night else {
            print("⚠️ No saved state to restore")
            return
        }
        
        // Restore previous state
        night.dose1TimeUTC = savedState.dose1TimeUTC
        night.dose1Grams = savedState.dose1Grams
        night.dose2TimeUTC = savedState.dose2TimeUTC
        night.dose2Grams = savedState.dose2Grams
        night.dose2IsOverride = savedState.dose2IsOverride
        night.dose2OverrideKind = savedState.dose2OverrideKind
        night.dose2OverrideMinutes = savedState.dose2OverrideMinutes
        night.dose2OverrideReason = savedState.dose2OverrideReason
        night.finalWakeTimeUTC = savedState.finalWakeTimeUTC
        night.bathroomWakeTimesUTC = savedState.bathroomWakeTimesUTC
        
        try? modelContext.save()
        
        // Clear undo state
        undoTimer?.invalidate()
        undoSecondsRemaining = 0
        savedNightState = nil
        undoAction = ""
        
        // Light haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        print("✅ Undo successful")
    }
    
    /// Create a snapshot of current night state
    private func createStateSnapshot(_ night: DoseLog) -> DoseLog {
        let snapshot = DoseLog(
            nightKey: night.nightKey,
            nightStartUTC: night.nightStartUTC,
            timezoneOffsetMinutes: night.timezoneOffsetMinutes
        )
        snapshot.bedtimeUTC = night.bedtimeUTC
        snapshot.dose1TimeUTC = night.dose1TimeUTC
        snapshot.dose1Grams = night.dose1Grams
        snapshot.dose2TimeUTC = night.dose2TimeUTC
        snapshot.dose2Grams = night.dose2Grams
        snapshot.dose2IsOverride = night.dose2IsOverride
        snapshot.dose2OverrideKind = night.dose2OverrideKind
        snapshot.dose2OverrideMinutes = night.dose2OverrideMinutes
        snapshot.dose2OverrideReason = night.dose2OverrideReason
        snapshot.finalWakeTimeUTC = night.finalWakeTimeUTC
        snapshot.bathroomWakeTimesUTC = night.bathroomWakeTimesUTC
        snapshot.morningAlertness = night.morningAlertness
        snapshot.notes = night.notes
        return snapshot
    }
}

// MARK: - Section Header Component

struct SectionHeader: View {
    let title: String
    let hint: String?
    
    var body: some View {
        HStack(spacing: DT.sm) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Palette.text)
            
            if let hint, !hint.isEmpty {
                Text("(\(hint))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            
            Spacer()
        }
        .padding(.horizontal, DT.lg)
        .padding(.top, DT.xs)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DoseLog.self, configurations: config)
    let context = container.mainContext
    
    // Create sample night
    let night = DoseLog(
        nightKey: "2025-11-03",
        nightStartUTC: Calendar.current.startOfDay(for: Date()),
        timezoneOffsetMinutes: -300
    )
    night.lifecycleState = "active"
    night.dose1TimeUTC = Date().addingTimeInterval(-7200) // 2 hours ago
    night.dose1Grams = 4.25
    
    context.insert(night)
    
    return NightCardViewModern(
        horizon: .tonight,
        night: night,
        modelContext: context
    )
}
