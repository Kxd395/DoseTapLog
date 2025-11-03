import SwiftUI

/// Option B: Guided Checklist with Inline Timeline
/// Linear step-by-step flow reduces cognitive load
/// Timeline stays in same screen, scrollable
struct TodayLogView_Checklist: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm: TodayViewModel
    @State private var showSettings = false
    @State private var showLateDoseSheet = false
    
    init() {
        _vm = StateObject(wrappedValue: TodayViewModel(controller: StubController()))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Header: Safety & Sources (collapsible)
                statusHeaderSection
                
                // Step 1: In Bed
                step1InBedSection
                
                // Step 2: Dose 1
                step2Dose1Section
                
                // Step 3: Window to Dose 2
                step3WindowSection
                
                // Step 4: Dose 2
                step4Dose2Section
                
                // Step 5: Wake
                step5WakeSection
                
                // Timeline
                timelineSection
                
                // Footer Tools
                footerToolsSection
            }
            .navigationTitle("DoseTrack")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsViewEnhanced()
            }
            .sheet(isPresented: $vm.showEarlyDoseSheet) {
                EarlyDoseSheet(
                    minutes: .constant(5),
                    reason: .constant(.feltSleepy),
                    allowed: 1...15,
                    quickChoices: AppPreferencesEnhanced.shared.earlyTimePriorDefaults.split(separator: ",").compactMap { Int($0) },
                    requireReason: AppPreferencesEnhanced.shared.earlyRequireReason,
                    onConfirm: { vm.confirmEarlyDose2() },
                    onCancel: { vm.showEarlyDoseSheet = false }
                )
            }
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
            .sheet(isPresented: $vm.showResetSheet) {
                ResetNightSheet(
                    requireBiometric: AppPreferencesEnhanced.shared.resetRequireBiometricHard,
                    allowHardReset: AppPreferencesEnhanced.shared.resetAllowHard,
                    reasonRequired: AppPreferencesEnhanced.shared.resetReasonRequired,
                    hasFinalWake: vm.finalWakeTimeUTC != nil,
                    onConfirm: { mode, reason in
                        vm.performResetNight(mode: mode, reason: reason)
                    }
                )
            }
        }
    }
    
    // MARK: - Sections
    
    private var statusHeaderSection: some View {
        Section {
            // Compact chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    StatusChip(
                        title: "Safety",
                        systemImage: vm.planWithinBounds ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                        color: vm.planWithinBounds ? .green : .red
                    )
                    
                    StatusChip(title: "Wake", systemImage: "heart.fill", color: .blue)
                    StatusChip(title: "Health", systemImage: "checkmark", color: .green)
                    StatusChip(title: "WHOOP", systemImage: "checkmark", color: .green)
                }
            }
            
            Text(nightContextLine)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
    
    private var step1InBedSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("In bed")
                        .font(.headline)
                    
                    if let bedtime = vm.bedtimeUTC {
                        Text("Last: \(bedtime, style: .time)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not logged yet")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Button("In bed now") {
                    vm.logInBedNow()
                }
                .buttonStyle(.bordered)
                .font(.footnote)
            }
        } header: {
            Label("1", systemImage: "bed.double.fill")
                .font(.headline)
        }
    }
    
    private var step2Dose1Section: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dose 1")
                            .font(.headline)
                        
                        Text("Plan: \(vm.prefs.planDose1G.formatG)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        
                        if let dose1Time = vm.dose1TimeUTC {
                            Text("Last: \(dose1Time, style: .time)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not logged yet")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Dose 1 now") {
                        vm.logDose1Now(grams: vm.prefs.planDose1G)
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.footnote)
                }
                
                Text("Hint: you can long-press to edit grams for tonight only")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        } header: {
            Label("2", systemImage: "pills.fill")
                .font(.headline)
        }
    }
    
    private var step3WindowSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Window to Dose 2")
                            .font(.headline)
                        
                        Text("Target: \(vm.windowStartMinutes) to \(vm.windowEndMinutes) min after Dose 1")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Countdown Ring
                TimelineView(.periodic(from: Date(), by: 30)) { _ in
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.18), lineWidth: 12)
                                
                                Circle()
                                    .trim(from: 0, to: vm.ringProgress)
                                    .stroke(ringColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                
                                VStack(spacing: 4) {
                                    Image(systemName: ringIcon)
                                        .font(.title)
                                        .foregroundStyle(ringColor)
                                    
                                    Text(vm.ringStatus.rawValue)
                                        .font(.caption)
                                        .bold()
                                }
                            }
                            .frame(width: 120, height: 120)
                            
                            Text(vm.dose2ReasonText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Spacer()
                    }
                }
                
                // Quick snooze
                if vm.dose2Enabled {
                    HStack(spacing: 8) {
                        Text("Quick snooze:")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        
                        Button("5m") { /* TODO */ }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        
                        Button("10m") { /* TODO */ }
                            .buttonStyle(.bordered)
                            .font(.caption)
                    }
                }
                
                Text("When window opens, 'Dose 2 now' becomes enabled")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        } header: {
            Label("3", systemImage: "clock.fill")
                .font(.headline)
        }
    }
    
    private var step4Dose2Section: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dose 2")
                            .font(.headline)
                        
                        Text("Plan: \(vm.prefs.planDose2G.formatG)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        
                        if let dose2Time = vm.dose2TimeUTC {
                            Text("Last: \(dose2Time, style: .time)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not logged yet")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                // Main Dose 2 button
                Button("Dose 2 now") {
                    vm.tryLogDose2()
                }
                .buttonStyle(.borderedProminent)
                .font(.footnote)
                .frame(maxWidth: .infinity)
                .disabled(!vm.dose2Enabled)
                
                Divider()
                
                // Override options
                VStack(spacing: 8) {
                    Text("Override options:")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        Button("Log early") {
                            vm.showEarlyDoseSheet = true
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                        .disabled(!vm.isBeforeWindowButEligibleEarly)
                        
                        if vm.isAfterWindow && AppPreferencesEnhanced.shared.allowLateDose {
                            Button("Log late") {
                                showLateDoseSheet = true
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                            .tint(.orange)
                        }
                    }
                }
                
                Text("Policy: reason required for overrides")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        } header: {
            Label("4", systemImage: "pills.circle.fill")
                .font(.headline)
        } footer: {
            if vm.isAfterWindow {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    
                    Text("Window closed \(vm.minutesAfterWindow) min ago. Use 'Log late' to record what happened.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
    
    private var step5WakeSection: some View {
        Section {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Button("Final wake now") {
                        vm.logFinalWake()
                    }
                    .buttonStyle(.bordered)
                    .font(.footnote)
                    
                    Button("Alarm wake") {
                        vm.logAlarmWake()
                    }
                    .buttonStyle(.bordered)
                    .font(.footnote)
                }
                
                Button("Autofill from Health") {
                    // TODO: Health autofill
                }
                .buttonStyle(.bordered)
                .font(.footnote)
                .frame(maxWidth: .infinity)
                
                Button("Bathroom") {
                    vm.logBathroom()
                }
                .buttonStyle(.bordered)
                .font(.footnote)
                .frame(maxWidth: .infinity)
            }
        } header: {
            Label("5", systemImage: "sunrise.fill")
                .font(.headline)
        }
    }
    
    private var timelineSection: some View {
        Section {
            if vm.lastEvents.isEmpty {
                HStack {
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Image(systemName: "moon.zzz")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        
                        Text("No events logged yet")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                    .padding(.vertical, 12)
                    
                    Spacer()
                }
            } else {
                ForEach(vm.lastEvents) { event in
                    TimelineRow(event: event)
                }
            }
        } header: {
            Label("Timeline", systemImage: "list.bullet")
                .font(.headline)
        }
    }
    
    private var footerToolsSection: some View {
        Section {
            HStack(spacing: 8) {
                Button("Undo last") {
                    vm.undoLast()
                }
                .buttonStyle(.bordered)
                .font(.footnote)
                .disabled(vm.lastEvents.isEmpty)
                
                Button("Edit plan") {
                    showSettings = true
                }
                .buttonStyle(.bordered)
                .font(.footnote)
                
                Button("Export CSV") {
                    // TODO: Export
                }
                .buttonStyle(.bordered)
                .font(.footnote)
            }
            
            if vm.nightKey != nil {
                Button("Reset Night") {
                    vm.presentResetNight()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .font(.footnote)
                .frame(maxWidth: .infinity)
            }
        } header: {
            Text("Tools")
                .font(.headline)
        }
    }
    
    // MARK: - Helpers
    
    private var nightContextLine: String {
        let tz = TimeZone.current.abbreviation() ?? "UTC"
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d"
        let dateStr = formatter.string(from: date)
        
        if let nightKey = vm.nightKey {
            return "\(dateStr)  •  \(tz)  •  NightKey \(nightKey)"
        } else {
            return "\(dateStr)  •  \(tz)  •  No session"
        }
    }
    
    private var planWithinBounds: Bool {
        let perDoseMin = 1.5
        let perDoseMax = 4.5
        let nightMin = 3.0
        let nightMax = 9.0
        
        return vm.prefs.planDose1G >= perDoseMin &&
               vm.prefs.planDose1G <= perDoseMax &&
               vm.prefs.planDose2G >= perDoseMin &&
               vm.prefs.planDose2G <= perDoseMax &&
               vm.prefs.totalNightG >= nightMin &&
               vm.prefs.totalNightG <= nightMax
    }
    
    private var ringColor: Color {
        switch vm.ringStatus {
        case .idle: return .gray
        case .waiting: return .blue
        case .open: return .green
        case .expired: return .red
        }
    }
    
    private var ringIcon: String {
        switch vm.ringStatus {
        case .idle: return "moon.stars"
        case .waiting: return "clock"
        case .open: return "checkmark.circle.fill"
        case .expired: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Supporting Views

private struct StatusChip: View {
    let title: String
    let systemImage: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2)
            
            Text(title)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .cornerRadius(8)
    }
}

struct TimelineRow: View {
    let event: LoggedEvent
    
    var body: some View {
        HStack(spacing: 12) {
            Text(event.timestampUTC, style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Image(systemName: eventIcon)
                .font(.body)
                .foregroundStyle(eventColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(eventLabel)
                    .font(.footnote)
                    .bold()
                
                if let detail = eventDetail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    private var eventIcon: String {
        switch event.kind {
        case "bedtime": return "bed.double.fill"
        case "dose1": return "pills.fill"
        case "dose2": return "pills.fill"
        case "bathroom": return "toilet.fill"
        case "alarm_wake": return "alarm.fill"
        case "final_wake": return "sunrise.fill"
        default: return "circle.fill"
        }
    }
    
    private var eventColor: Color {
        switch event.kind {
        case "dose1", "dose2": return .blue
        case "bathroom": return .orange
        case "alarm_wake", "final_wake": return .green
        default: return .gray
        }
    }
    
    private var eventLabel: String {
        switch event.kind {
        case "bedtime": return "In bed"
        case "dose1": return "Dose 1"
        case "dose2": return "Dose 2"
        case "bathroom": return "Bathroom"
        case "alarm_wake": return "Alarm wake"
        case "final_wake": return "Final wake"
        default: return event.kind
        }
    }
    
    private var eventDetail: String? {
        if let grams = event.grams {
            return "\(grams.formatG)"
        }
        return nil
    }
}

// MARK: - Preview

#Preview("Checklist Layout") {
    TodayLogView_Checklist()
}
