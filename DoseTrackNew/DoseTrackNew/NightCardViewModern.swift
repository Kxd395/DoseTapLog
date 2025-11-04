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
    
    private let prefs = AppPreferencesEnhanced.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: DT.gap) {
                if let night = night {
                    // Plan card
                    planCard(night)
                    
                    // Window status pills
                    windowPillsRow(night)
                    
                    // Status chips
                    statusChipsRow(night)
                    
                    // Window bar (compact, replaces big ring)
                    if night.currentLifecycleState.isActive {
                        windowBarSection(night)
                    }
                    
                    // Actions
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
        }
        .background(Palette.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Plan Card
    
    @ViewBuilder
    private func planCard(_ night: DoseLog) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tonight plan")
                .font(.title2)
                .bold()
                .foregroundStyle(Palette.text)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dose 1")
                        .font(.caption)
                        .foregroundStyle(Palette.dim)
                    Text("\(formatGrams(night.dose1Grams ?? prefs.planDose1G)) g")
                        .font(.title3)
                        .bold()
                        .foregroundStyle(Palette.dose1)
                }
                
                Spacer(minLength: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dose 2")
                        .font(.caption)
                        .foregroundStyle(Palette.dim)
                    Text("\(formatGrams(night.dose2Grams ?? prefs.planDose2G)) g")
                        .font(.title3)
                        .bold()
                        .foregroundStyle(Palette.dose2)
                }
            }
            
            // Window info
            if let d1 = night.dose1TimeUTC {
                let windowStart = d1.addingTimeInterval(Double(prefs.windowStartMin * 60))
                let windowEnd = d1.addingTimeInterval(Double(prefs.windowEndMin * 60))
                Text("Window: \(formatTime(windowStart)) – \(formatTime(windowEnd))")
                    .font(.footnote)
                    .foregroundStyle(Palette.dim)
            } else {
                Text("Window: \(prefs.windowStartMin)–\(prefs.windowEndMin) min after Dose 1")
                    .font(.footnote)
                    .foregroundStyle(Palette.dim)
            }
        }
        .padding(DT.pad)
        .background(
            RoundedRectangle(cornerRadius: DT.corner)
                .fill(Palette.surface)
        )
    }
    
    // MARK: - Window Pills Row
    
    @ViewBuilder
    private func windowPillsRow(_ night: DoseLog) -> some View {
        HStack(spacing: 8) {
            // Window status pill with live countdown
            WindowPill(
                dose1At: night.dose1TimeUTC,
                windowStartMin: prefs.windowStartMin,
                windowEndMin: prefs.windowEndMin,
                showSeconds: prefs.showSeconds
            )
            
            // Next alert chip (if scheduled)
            if let nextAlert = nextScheduledAlert(for: night) {
                NextAlertChip(
                    nextAlertTime: nextAlert,
                    alarmStyle: currentAlarmStyle()
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, DT.pad)
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
        ModernStatusChipRow(chips: [
            .init(
                text: "Per dose \(formatGrams(perDoseMin))–\(formatGrams(perDoseMax)) g",
                icon: "checkmark.seal.fill",
                tone: perDoseSafe(night) ? Palette.ok : Palette.warn
            ),
            .init(
                text: "Σ Planned \(formatGrams(plannedTotal(night))) g",
                icon: "calculator",
                tone: Palette.text.opacity(0.8)
            ),
            .init(
                text: "📒 Logged \(formatGrams(loggedTotal(night))) g",
                icon: "book.closed",
                tone: loggedTotal(night) > 0 ? Palette.text.opacity(0.8) : Palette.dim
            ),
            .init(
                text: "Health OK",
                icon: "heart.fill",
                tone: Palette.ok
            ),
            .init(
                text: "WHOOP OK",
                icon: "antenna.radiowaves.left.and.right",
                tone: Palette.ok
            ),
            .init(
                text: "Wake: manual",
                icon: "bed.double.fill",
                tone: Palette.dim
            )
        ])
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
                    icon: "pills.circle.fill",
                    action: {
                        tryLogDose2(night)
                    },
                    disabled: !dose2Enabled(night),
                    caption: dose2DisabledCaption(night)
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
    
    private func dose2DisabledCaption(_ night: DoseLog) -> String? {
        // Already logged or enabled
        if night.dose2TimeUTC != nil || dose2Enabled(night) {
            return nil
        }
        
        // Dose 1 not logged yet
        guard let d1 = night.dose1TimeUTC else {
            return "Log Dose 1 to start the window"
        }
        
        let now = Date()
        let windowStart = d1.addingTimeInterval(Double(prefs.windowStartMin) * 60)
        let windowEnd = d1.addingTimeInterval(Double(prefs.windowEndMin) * 60)
        
        // Before window
        if now < windowStart {
            let remainingSeconds = windowStart.timeIntervalSince(now)
            let remainingMinutes = Int(remainingSeconds / 60)
            let hours = remainingMinutes / 60
            let mins = remainingMinutes % 60
            
            let timeStr = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
            return "Opens in \(timeStr) (\(prefs.windowStartMin)–\(prefs.windowEndMin) min after Dose 1)"
        }
        
        // After window expired
        let expiredSeconds = now.timeIntervalSince(windowEnd)
        let expiredMinutes = Int(expiredSeconds / 60)
        let hours = expiredMinutes / 60
        let mins = expiredMinutes % 60
        let timeStr = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
        return "Window expired \(timeStr) ago"
    }
    
    private func formatGrams(_ value: Double) -> String {
        String(format: "%.2f", value)
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
        print("Log Dose 1")
    }
    
    private func tryLogDose2(_ night: DoseLog) {
        print("Try log Dose 2")
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
