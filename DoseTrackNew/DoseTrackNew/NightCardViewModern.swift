//
//  NightCardViewModern.swift
//  DoseTrack
//
//  Modern dark-mode-first version of NightCardView
//  Uses WindowBar, ModernStatusChip, and ActionButtons
//

import SwiftUI
import SwiftData

/// Decision routing for Dose 2 override flows
enum Dose2Decision: Identifiable {
    case early(minutes: Int)      // within earlyMaxOverrideMin
    case late(minutes: Int)       // within lateMaxOverrideMin
    case blocked(reason: String)  // too early/late or need D1/already logged
    
    var id: String {
        switch self {
        case .early(let m): return "early_\(m)"
        case .late(let m): return "late_\(m)"
        case .blocked(let r): return "blocked_\(r)"
        }
    }
}

/// Modern night card with dark UI, compact window bar, and action grid
struct NightCardViewModern: View {
    let horizon: PlanningHorizon
    let night: DoseLog?
    let modelContext: ModelContext
    
    @State private var showPlanEditor = false
    @State private var dose2Decision: Dose2Decision? = nil  // NEW: unified decision routing
    @State private var showWakeSheet = false
    @State private var showResetNightSheet = false
    @State private var wakeSheetIsFinal = false
    @State private var showAlreadyLoggedSheet = false
    @State private var showDose2TimePicker = false          // Time picker for long-press
    @State private var customDose2Time = Date()             // Selected time from picker
    @State private var showInBedTimePicker = false          // Time picker for In bed
    @State private var customInBedTime = Date()
    @State private var showDose1TimePicker = false          // Time picker for Dose 1
    @State private var customDose1Time = Date()
    @State private var showFinalWakeTimePicker = false      // Time picker for Final wake
    @State private var customFinalWakeTime = Date()
    
    @StateObject private var prefs = AppPreferencesEnhanced.shared
    
    /// Time picker range: allow 48 hours in the past to 6 hours in the future
    /// This covers midnight crossovers and late logging scenarios
    private var timePickerRange: ClosedRange<Date> {
        let now = Date()
        // Allow from 48 hours ago to 6 hours from now
        return now.addingTimeInterval(-48 * 3600)...now.addingTimeInterval(6 * 3600)
    }
    
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
        
        // MARK: - Dose 2 Decision Routing (NEW: unified early/late/blocked)
        .sheet(item: $dose2Decision) { decision in
            switch decision {
            case .early(let minutes):
                // Early override sheet
                Dose2OverrideSheet(
                    title: "Dose 2 early",
                    subtitle: "You're \(minutes)m before the window.",
                    reasonRequired: false,
                    primaryLabel: "Log early now",
                    secondaryLabel: "Remind me at window start",
                    onPrimary: { reason in
                        logDose2Override(kind: "early", minutes: minutes, reason: reason)
                    },
                    onSecondary: {
                        scheduleWindowStartReminder()
                        dose2Decision = nil
                    },
                    onCancel: {
                        dose2Decision = nil
                    }
                )
                
            case .late(let minutes):
                // Late override sheet
                Dose2OverrideSheet(
                    title: "Dose 2 late",
                    subtitle: "You're \(minutes)m after the window.",
                    reasonRequired: true,
                    primaryLabel: "Log late now",
                    secondaryLabel: "Mark as missed",
                    onPrimary: { reason in
                        logDose2Override(kind: "late", minutes: minutes, reason: reason)
                    },
                    onSecondary: {
                        // TODO: Mark as missed dose
                        print("⚠️ Mark as missed dose")
                        dose2Decision = nil
                    },
                    onCancel: {
                        dose2Decision = nil
                    }
                )
                
            case .blocked(let message):
                // Blocked sheet (uses existing Dose2BlockedSheet from Dose2InfoSheets.swift)
                Dose2BlockedSheet(
                    reason: message,
                    onRemindAtStart: {
                        scheduleWindowStartReminder()
                        dose2Decision = nil
                    }
                )
            }
        }
        
        // MARK: - Other Sheets
        .sheet(isPresented: $showAlreadyLoggedSheet) {
            if let night = night, let dose2Time = night.dose2TimeUTC {
                Dose2AlreadyLoggedSheet(
                    loggedAt: dose2Time,
                    onEditTime: {
                        // Edit time functionality
                        showAlreadyLoggedSheet = false
                    },
                    onUndo: {
                        night.dose2TimeUTC = nil
                        night.dose2Grams = nil
                        try? modelContext.save()
                        showAlreadyLoggedSheet = false
                    }
                )
            }
        }
        .sheet(isPresented: $showWakeSheet) {
            if let night = night {
                WakeSheetView(
                    isPresented: $showWakeSheet,
                    isFinalPreset: wakeSheetIsFinal,
                    allowTimeEditMinutes: 15,
                    showSeconds: false,
                    onConfirm: { reason, isFinal, wasInterrupted, time, note in
                        if isFinal {
                            night.finalWakeTimeUTC = time
                            night.finalWakeProvenance = reason.rawValue
                        }
                        // TODO: Add to events array when implemented
                        
                        do {
                            try modelContext.save()
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            print("✅ Logged \(isFinal ? "final" : "alarm") wake: \(reason.label)")
                        } catch {
                            print("❌ Failed to log wake: \(error)")
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showResetNightSheet) {
            if let night = night {
                ResetNightSheet(
                    requireBiometric: true,
                    allowHardReset: true,
                    reasonRequired: true,
                    hasFinalWake: night.finalWakeTimeUTC != nil,
                    onConfirm: { mode, reason in
                        print("🔵 Reset Night onConfirm called")
                        print("🔍 Mode: \(mode.rawValue)")
                        print("🔍 Reason: \(reason)")
                        print("🔍 Has Final Wake: \(night.finalWakeTimeUTC != nil)")
                        print("🔍 Current lifecycle state: \(night.lifecycleState)")
                        
                        if mode == .soft {
                            // Archive and reset
                            print("✅ Performing SOFT reset - setting to abandoned")
                            night.currentLifecycleState = .abandoned
                            night.notes = (night.notes ?? "") + " [Reset: \(reason)]"
                            print("🔍 New lifecycle state: \(night.lifecycleState)")
                        } else {
                            // Hard delete
                            print("✅ Performing HARD reset - deleting night")
                            modelContext.delete(night)
                        }
                        
                        do {
                            try modelContext.save()
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            print("✅ Reset night (\(mode.rawValue)): \(reason)")
                            print("✅ ModelContext saved successfully")
                        } catch {
                            print("❌ Failed to reset night: \(error)")
                        }
                    }
                )
            }
        }
        
        // MARK: - Dose 2 Time Picker (Long-Press)
        .sheet(isPresented: $showDose2TimePicker) {
            NavigationStack {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose Dose 2 time")
                            .font(.headline)
                        Text("Select when you actually took Dose 2")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    
                    DatePicker(
                        "Date & Time",
                        selection: $customDose2Time,
                        in: timePickerRange,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    
                    Spacer()
                }
                .padding()
                .background(Palette.bg)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showDose2TimePicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Continue") {
                            if let night = night {
                                tryLogDose2(night, at: customDose2Time, source: "longpress_custom")
                            }
                            showDose2TimePicker = false
                        }
                    }
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .presentationDetents([.height(400)])  // Taller for date + time
            }
            .preferredColorScheme(.dark)
        }
        
        // MARK: - In Bed Time Picker (Long-Press)
        .sheet(isPresented: $showInBedTimePicker) {
            NavigationStack {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose 'In bed' time")
                            .font(.headline)
                        Text("Select when you got into bed")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    
                    DatePicker(
                        "Date & Time",
                        selection: $customInBedTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    
                    Spacer()
                }
                .padding()
                .background(Palette.bg)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showInBedTimePicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Continue") {
                            if let night = night {
                                logInBed(night, at: customInBedTime)
                            }
                            showInBedTimePicker = false
                        }
                    }
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .presentationDetents([.height(400)])  // Taller for date + time
            }
            .preferredColorScheme(.dark)
        }
        
        // MARK: - Dose 1 Time Picker (Long-Press)
        .sheet(isPresented: $showDose1TimePicker) {
            NavigationStack {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose Dose 1 time")
                            .font(.headline)
                        Text("Select when you took Dose 1")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    
                    DatePicker(
                        "Date & Time",
                        selection: $customDose1Time,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    
                    Spacer()
                }
                .padding()
                .background(Palette.bg)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showDose1TimePicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Continue") {
                            if let night = night {
                                logDose1(night, at: customDose1Time)
                            }
                            showDose1TimePicker = false
                        }
                    }
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .presentationDetents([.height(400)])  // Taller for date + time
            }
            .preferredColorScheme(.dark)
        }
        
        // MARK: - Final Wake Time Picker (Long-Press)
        .sheet(isPresented: $showFinalWakeTimePicker) {
            NavigationStack {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose final wake time")
                            .font(.headline)
                        Text("Select when you woke up for the day")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    
                    DatePicker(
                        "Date & Time",
                        selection: $customFinalWakeTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    
                    Spacer()
                }
                .padding()
                .background(Palette.bg)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showFinalWakeTimePicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Continue") {
                            if let night = night {
                                logFinalWake(night, at: customFinalWakeTime)
                            }
                            showFinalWakeTimePicker = false
                        }
                    }
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .presentationDetents([.height(400)])  // Taller for date + time
            }
            .preferredColorScheme(.dark)
        }
    }
    
    // MARK: - Header
    
    
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
                icon: "function",
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
                .init(
                    title: "In bed",
                    icon: "moon.fill",
                    action: {
                        // Tap = log now
                        logInBed(night, at: Date())
                    },
                    longPressAction: {
                        // Long-press = choose time
                        customInBedTime = Date()
                        showInBedTimePicker = true
                    }
                ),
                .init(
                    title: "Dose 1",
                    icon: "pills.fill",
                    action: {
                        // Tap = log now
                        logDose1(night, at: Date())
                    },
                    longPressAction: {
                        // Long-press = choose time
                        customDose1Time = Date()
                        showDose1TimePicker = true
                    }
                ),
                .init(
                    title: "Dose 2",
                    icon: "pills.circle.fill",
                    action: {
                        // Tap = log now
                        tryLogDose2(night, at: Date(), source: "tap_now")
                    },
                    disabled: false,  // ALWAYS TAPPABLE
                    caption: dose2StatusCaption(night),
                    longPressAction: {
                        // Long-press = choose time
                        customDose2Time = Date()
                        showDose2TimePicker = true
                    }
                ),
                .init(
                    title: "Final wake",
                    icon: "sunrise.fill",
                    action: {
                        // Tap = log now
                        logFinalWake(night, at: Date())
                    },
                    longPressAction: {
                        // Long-press = choose time
                        customFinalWakeTime = Date()
                        showFinalWakeTimePicker = true
                    }
                )
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
            
            // Show actual events from night
            let events = collectEvents(night)
            
            if events.isEmpty {
                Text("No events yet")
                    .font(.footnote)
                    .foregroundStyle(Palette.dim)
            } else {
                ForEach(events) { event in
                    eventRow(
                        icon: event.icon,
                        text: event.text,
                        time: formatEventTime(event.time),
                        color: event.color
                    )
                }
            }
        }
        .padding(DT.pad)
        .background(
            RoundedRectangle(cornerRadius: DT.corner)
                .fill(Palette.surface)
        )
    }
    
    /// Collect all events from night
    private func collectEvents(_ night: DoseLog) -> [EventItem] {
        var events: [EventItem] = []
        
        // In bed
        if let inBed = night.bedtimeUTC {
            events.append(EventItem(
                time: inBed,
                icon: "bed.double.fill",
                text: "In bed",
                color: Palette.text
            ))
        }
        
        // Dose 1
        if let dose1 = night.dose1TimeUTC {
            let grams = night.dose1Grams ?? 0
            events.append(EventItem(
                time: dose1,
                icon: "pills.fill",
                text: "Dose 1: \(String(format: "%.1f", grams))g",
                color: Palette.dose1
            ))
        }
        
        // Dose 2
        if let dose2 = night.dose2TimeUTC {
            let grams = night.dose2Grams ?? 0
            let override = night.dose2IsOverride == true ? " ⚠️" : ""
            events.append(EventItem(
                time: dose2,
                icon: "pills.circle.fill",
                text: "Dose 2: \(String(format: "%.1f", grams))g\(override)",
                color: Palette.dose2
            ))
        }
        
        // Final wake
        if let wake = night.finalWakeTimeUTC {
            events.append(EventItem(
                time: wake,
                icon: "sunrise.fill",
                text: "Final wake",
                color: .orange
            ))
        }
        
        // Sort by time (most recent first)
        return events.sorted { $0.time > $1.time }
    }
    
    /// Format event time
    private func formatEventTime(_ time: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: time)
    }
    
    /// Event item for display
    private struct EventItem: Identifiable {
        let id = UUID()
        let time: Date
        let icon: String
        let text: String
        let color: Color
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
                createPlanFromTemplate()
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
        let d1 = night.dose1Grams ?? 0
        let d2 = night.dose2Grams ?? 0
        // TODO: Add perDoseMinG and perDoseMaxG to AppPreferencesEnhanced
        return d1 >= 1.0 && d1 <= 6.0 &&
               d2 >= 1.0 && d2 <= 6.0
    }
    
    private func plannedTotal(_ night: DoseLog) -> Double {
        return prefs.planDose1G + prefs.planDose2G
    }
    
    private func loggedTotal(_ night: DoseLog) -> Double {
        return (night.dose1Grams ?? 0) + (night.dose2Grams ?? 0)
    }
    
    // MARK: - Dose 2 Status Caption
    
    /// Returns status caption for Dose 2 button (always shows current state)
    private func dose2StatusCaption(_ night: DoseLog) -> String? {
        let policy = Dose2Policy.from(prefs)
        let gate = evaluateDose2Gate(
            now: Date(),
            dose1At: night.dose1TimeUTC,
            dose2At: night.dose2TimeUTC,
            policy: policy
        )
        
        switch gate {
        case .ready:
            return "Within window"
        case .needDose1:
            return "Log Dose 1 first"
        case .alreadyLogged:
            return "Already logged"
        case .tooEarly(let minutes):
            let hours = minutes / 60
            let mins = minutes % 60
            if hours > 0 {
                return "Opens in \(hours)h \(mins)m"
            } else {
                return "Opens in \(mins)m"
            }
        case .tooLate(let minutes):
            let hours = minutes / 60
            let mins = minutes % 60
            if hours > 0 {
                return "Closed \(hours)h \(mins)m ago"
            } else {
                return "Closed \(mins)m ago"
            }
        }
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
    
    private func logInBed(_ night: DoseLog, at time: Date = Date()) {
        print("🔵 logInBed called - NEW VERSION")
        print("🔍 Time: \(time)")
        night.bedtimeUTC = time
        
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            print("✅ Logged in bed at \(time)")
        } catch {
            print("❌ Failed to log in bed: \(error)")
        }
    }
    
    private func logDose1(_ night: DoseLog, at time: Date = Date()) {
        print("🔵 logDose1 called")
        print("🔍 Time: \(time)")
        night.dose1TimeUTC = time
        night.dose1Grams = prefs.planDose1G
        
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            print("✅ Logged Dose 1: \(night.dose1Grams ?? 0)g at \(time)")
        } catch {
            print("❌ Failed to log Dose 1: \(error)")
        }
    }
    
    // MARK: - Dose 2 Gate Logic
    
    /// Always tappable - evaluate gate and route to decision sheet
    /// @param proposedTime: When the dose was/will be taken (now for tap, custom for long-press)
    /// @param source: "tap_now" or "longpress_custom" for audit trail
    private func tryLogDose2(_ night: DoseLog, at proposedTime: Date = Date(), source: String = "tap_now") {
        print("🔵 tryLogDose2 called - NEW VERSION (decision routing)")
        print("🔍 Source: \(source)")
        print("🔍 Proposed time: \(proposedTime)")
        
        let policy = Dose2Policy.from(prefs)
        let gate = evaluateDose2Gate(
            now: proposedTime,  // Use proposed time for gate evaluation
            dose1At: night.dose1TimeUTC,
            dose2At: night.dose2TimeUTC,
            policy: policy
        )
        
        print("🔍 Dose 2 Gate State: \(gate)")
        print("🔍 Dose1: \(night.dose1TimeUTC?.description ?? "nil")")
        print("🔍 Dose2: \(night.dose2TimeUTC?.description ?? "nil")")
        print("🔍 Window: \(policy.startMin)m - \(policy.endMin)m")
        print("🔍 Policy: early=\(policy.allowEarly) (max \(policy.maxEarlyMin)m), late=\(policy.allowLate) (max \(policy.maxLateMin)m)")
        
        switch gate {
        case .ready:
            // Within window → log immediately
            print("✅ Gate is READY - logging Dose 2 now")
            logDose2Now(night)
            
        case .needDose1:
            // Need Dose 1 first → blocked
            print("⚠️ Gate: Need Dose 1 → blocked sheet")
            dose2Decision = .blocked(reason: "Log Dose 1 first")
            
        case .alreadyLogged:
            // Already logged → show already logged sheet
            print("⚠️ Gate: Already logged")
            showAlreadyLoggedSheet = true
            
        case .tooEarly(let minutes):
            // Too early - check if override allowed
            print("⚠️ Gate: Too early by \(minutes)m")
            if policy.allowEarly && minutes <= policy.maxEarlyMin {
                // Early override sheet
                print("  → Early override sheet (policy allows, within \(policy.maxEarlyMin)m limit)")
                dose2Decision = .early(minutes: minutes)
            } else {
                // Blocked
                let reason = policy.allowEarly
                    ? "Opens in \(minutes)m (beyond \(policy.maxEarlyMin)m limit)"
                    : "Opens in \(minutes)m (early override disabled)"
                print("  → Blocked: \(reason)")
                dose2Decision = .blocked(reason: "Opens in \(minutes)m")
            }
            
        case .tooLate(let minutes):
            // Too late - check if override allowed
            print("⚠️ Gate: Too late by \(minutes)m")
            if policy.allowLate && minutes <= policy.maxLateMin {
                // Late override sheet
                print("  → Late override sheet (policy allows, within \(policy.maxLateMin)m limit)")
                dose2Decision = .late(minutes: minutes)
            } else {
                // Blocked
                let reason = policy.allowLate
                    ? "Window closed \(minutes)m ago (beyond \(policy.maxLateMin)m limit)"
                    : "Window closed \(minutes)m ago (late override disabled)"
                print("  → Blocked: \(reason)")
                dose2Decision = .blocked(reason: "Window closed \(minutes)m ago")
            }
        }
    }
    
    /// Log Dose 2 immediately (no override)
    private func logDose2Now(_ night: DoseLog) {
        print("🔵 logDose2Now called")
        
        night.dose2TimeUTC = Date()
        night.dose2Grams = prefs.planDose2G
        night.dose2IsOverride = false
        
        // Transition state to awaitWake
        night.currentLifecycleState = .awaitWake
        
        do {
            try modelContext.save()
            
            // Success haptic
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
            print("✅ Logged Dose 2: \(night.dose2Grams ?? 0)g")
            print("✅ State transitioned to: \(night.lifecycleState)")
            
            // Cancel any scheduled window start notifications
            NotificationHelper.shared.cancelWindowStartReminder()
            
            // TODO: Audit log
            // audit.log(.dose2Logged(override: nil, minutes: 0, reason: nil, source: "app", nightKey: night.nightKey))
            
        } catch {
            print("❌ Failed to log Dose 2: \(error)")
        }
    }
    
    /// Log Dose 2 with override (early/late) - simplified interface
    private func logDose2Override(kind: String, minutes: Int, reason: String?) {
        guard let night = night else {
            print("❌ No night available for override")
            return
        }
        
        print("🔵 logDose2Override called")
        print("🔍 Override kind: \(kind)")
        print("🔍 Override minutes: \(minutes)")
        print("🔍 Override reason: \(reason ?? "none")")
        
        // Set all required override fields
        night.dose2TimeUTC = Date()
        night.dose2Grams = prefs.planDose2G
        night.dose2IsOverride = true
        night.dose2OverrideKind = kind  // "early" | "late"
        night.dose2OverrideMinutes = minutes
        night.dose2OverrideReason = reason
        
        // Transition state to awaitWake
        night.currentLifecycleState = .awaitWake
        
        do {
            try modelContext.save()
            
            // Warning haptic for overrides
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            
            print("✅ Logged Dose 2 with \(kind) override")
            print("✅ Dose 2: \(night.dose2Grams ?? 0)g")
            print("✅ State transitioned to: \(night.lifecycleState)")
            
            // Cancel notifications
            NotificationHelper.shared.cancelWindowStartReminder()
            
            // Close the decision sheet
            dose2Decision = nil
            
            // TODO: Audit log
            // audit.log(.dose2Logged(override: kind, minutes: minutes, reason: reason, source: "app", nightKey: night.nightKey))
            
        } catch {
            print("❌ Failed to log Dose 2 override: \(error)")
        }
    }
    
    /// Log Dose 2 with override (early/late) - full Dose2Override struct
    private func logDose2WithOverride(_ night: DoseLog, override: Dose2Override) {
        print("🔵 logDose2WithOverride called")
        print("🔍 Override kind: \(override.kind.rawValue)")
        print("🔍 Override minutes: \(override.minutes)")
        print("🔍 Override reason: \(override.reason)")
        
        // Set all required override fields per spec
        night.dose2TimeUTC = Date()
        night.dose2Grams = prefs.planDose2G
        night.dose2IsOverride = true
        night.dose2OverrideKind = override.kind.rawValue  // "early" | "late"
        night.dose2OverrideMinutes = override.minutes
        night.dose2OverrideReason = override.reason
        
        // Transition state to awaitWake
        night.currentLifecycleState = .awaitWake
        
        do {
            try modelContext.save()
            
            // Heavy impact haptic for overrides
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            
            print("✅ Logged Dose 2 with \(override.kind.rawValue) override")
            print("✅ Dose 2: \(night.dose2Grams ?? 0)g")
            print("✅ State transitioned to: \(night.lifecycleState)")
            
            // Cancel notifications
            NotificationHelper.shared.cancelWindowStartReminder()
            
            // TODO: Audit log
            // audit.log(.dose2Logged(override: override.kind.rawValue, minutes: override.minutes, reason: override.reason, source: "app", nightKey: night.nightKey))
            
        } catch {
            print("❌ Failed to log Dose 2 override: \(error)")
        }
    }
    
    /// Schedule notification for window start
    private func scheduleWindowStartReminder() {
        guard let night = night, let d1 = night.dose1TimeUTC else { return }
        
        let windowStartTime = d1.addingTimeInterval(Double(prefs.windowStartMin * 60))
        
        Task {
            let success = await NotificationHelper.shared.scheduleWindowStartReminder(at: windowStartTime)
            if success {
                print("✅ Scheduled window start reminder for \(windowStartTime)")
            } else {
                print("❌ Failed to schedule window start reminder")
            }
        }
    }
    
    private func logFinalWake(_ night: DoseLog, at time: Date = Date()) {
        print("🔵 logFinalWake called - NEW VERSION")
        print("🔍 Time: \(time)")
        night.finalWakeTimeUTC = time
        night.finalWakeProvenance = WakeReason.natural.rawValue
        
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            print("✅ Logged final wake at \(time)")
        } catch {
            print("❌ Failed to log final wake: \(error)")
        }
    }
    
    private func logAlarmWake(_ night: DoseLog) {
        print("🔵 logAlarmWake called - NEW VERSION")
        wakeSheetIsFinal = false
        showWakeSheet = true
    }
    
    private func logNaturalWake(_ night: DoseLog) {
        print("🔵 logNaturalWake called - NEW VERSION")
        night.finalWakeTimeUTC = Date()
        night.finalWakeProvenance = WakeReason.natural.rawValue
        
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            print("✅ Logged natural wake")
        } catch {
            print("❌ Failed to log natural wake: \(error)")
        }
    }
    
    private func logBathroom(_ night: DoseLog) {
        print("🔵 logBathroom called - NEW VERSION")
        // Log bathroom event (non-final wake)
        // TODO: Add to events array when implemented
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        print("✅ Logged bathroom wake")
    }
    
    // MARK: - Create Plan from Template
    
    private func createPlanFromTemplate() {
        print("🔵 createPlanFromTemplate called - NEW VERSION")
        
        // If no night exists, create one first
        if night == nil {
            print("⚠️ No night available - creating new night for \(horizon.rawValue)")
            let nightKey = horizon.nightKey(cutoffHour: prefs.cutoffHourLocal)
            let now = Date()
            let tzOffset = TimeZone.current.secondsFromGMT(for: now) / 60
            let newNight = DoseLog(
                nightKey: nightKey,
                nightStartUTC: now,
                timezoneOffsetMinutes: tzOffset
            )
            newNight.currentLifecycleState = .planned
            
            modelContext.insert(newNight)
            
            do {
                try modelContext.save()
                print("✅ Created new night: \(nightKey)")
            } catch {
                print("❌ Failed to create new night: \(error)")
                return
            }
            
            // Note: The parent view's @Query will refresh and provide the new night
            // We'll need to call this function again after the view updates
            // For now, show feedback
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        
        guard let night = night else {
            print("❌ No night available after creation attempt")
            return
        }
        
        // Get the weekly schedule template
        let schedule = prefs.weeklySchedule
        
        // Get suggested Dose 1 time based on template
        let suggestedDose1 = schedule.suggestedDose1Time(
            for: Date(),
            cutoffHour: prefs.cutoffHourLocal,
            in: TimeZone.current
        )
        
        // Apply to night plan (only plannedDose1Time exists in DoseLog model)
        night.plannedDose1Time = suggestedDose1
        
        // Note: Dose 2 and wake times are calculated on-the-fly from:
        // - Dose 2 = plannedDose1Time + (windowStartMin + windowEndMin)/2
        // - Wake = Dose 2 + remaining sleep time
        // These are computed in the UI based on preferences, not stored in DB
        
        // Save
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
            // Calculate display times for logging
            let windowMidpoint = (prefs.windowStartMin + prefs.windowEndMin) / 2
            let dose2Time = suggestedDose1.addingTimeInterval(TimeInterval(windowMidpoint * 60))
            
            print("✅ Created plan from template")
            print("   Dose 1: \(suggestedDose1)")
            print("   Dose 2 (estimated): \(dose2Time)")
            print("   Amounts: D1=\(prefs.planDose1G)g, D2=\(prefs.planDose2G)g")
        } catch {
            print("❌ Failed to save plan: \(error)")
        }
    }
    
    private func resetNight(_ night: DoseLog) {
        print("🔵 resetNight called - NEW VERSION")
        showResetNightSheet = true
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

// MARK: - Embedded WakeSheetView (copied into this compilation unit so Xcode picks it up)
struct WakeSheetView: View {
    @Binding var isPresented: Bool
    @State private var reason: WakeReason = .natural
    @State private var isFinal: Bool = false
    @State private var wasAlarmInterrupted: Bool = false
    @State private var note: String = ""
    @State private var time: Date = Date()

    let allowTimeEditMinutes: Int
    let onConfirm: (_ reason: WakeReason, _ isFinal: Bool, _ wasAlarmInterrupted: Bool, _ time: Date, _ note: String?) -> Void
    let showSeconds: Bool

    init(isPresented: Binding<Bool>,
         isFinalPreset: Bool = false,
         allowTimeEditMinutes: Int = 15,
         showSeconds: Bool = false,
         onConfirm: @escaping (_ reason: WakeReason, _ isFinal: Bool, _ wasAlarmInterrupted: Bool, _ time: Date, _ note: String?) -> Void) {
        self._isPresented = isPresented
        self.allowTimeEditMinutes = allowTimeEditMinutes
        self.showSeconds = showSeconds
        self.onConfirm = onConfirm
        self._isFinal = State(initialValue: isFinalPreset)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reason") {
                    Picker("Type", selection: $reason) {
                        ForEach(WakeReason.allCases) { r in
                            Label(r.label, systemImage: r.iconName).tag(r)
                        }
                    }
                }

                Section("Details") {
                    Toggle("Final wake", isOn: $isFinal)

                    if reason == .alarm {
                        Toggle("Alarm interrupted", isOn: $wasAlarmInterrupted)
                    }

                    DatePicker("Time", selection: $time, displayedComponents: [.hourAndMinute, .date])
                        .environment(\.locale, .current)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .onAppear { clampEditableWindow() }

                    TextField("Note (optional)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    Button {
                        onConfirm(reason, isFinal, wasAlarmInterrupted, time, note.isEmpty ? nil : note)
                        isPresented = false
                    } label: {
                        HStack {
                            Image(systemName: reason.iconName)
                            Text(isFinal ? "Log final wake" : "Log wake now")
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Wake now")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }

    private func clampEditableWindow() {
        let minT = Date().addingTimeInterval(-Double(allowTimeEditMinutes) * 60)
        if time < minT { time = minT }
    }
}

