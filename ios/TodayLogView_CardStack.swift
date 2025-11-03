import SwiftUI

/// Option A: Card Stack with Fixed Action Dock
/// Scrollable cards above, fixed action buttons at bottom
/// Fixes "buttons not working / page doesn't scroll" issues
struct TodayLogView_CardStack: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm: TodayViewModel
    @State private var showSettings = false
    @State private var showLateDoseSheet = false
    
    init() {
        _vm = StateObject(wrappedValue: TodayViewModel(controller: StubController()))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Card 1: Tonight Plan
                    planCard
                    
                    // Card 2: Safety & Sources
                    safetyCard
                    
                    // Card 3: Night Context
                    contextCard
                    
                    // Card 4: Countdown Ring
                    countdownCard
                    
                    // Card 5: Recent Events (always visible)
                    eventsCard
                    
                    // Card 6: Status & Notices
                    statusCard
                    
                    // Spacer to prevent last card from hiding behind dock
                    Spacer()
                        .frame(height: 200)
                }
                .padding(16)
            }
            .safeAreaInset(edge: .bottom) {
                // Fixed Action Dock
                actionDock
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
    
    // MARK: - Card Components
    
    private var planCard: some View {
        GroupBox {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tonight plan")
                        .font(.title3)
                        .bold()
                    
                    Text("Dose 1: \(vm.prefs.planDose1G.formatG)")
                    
                    Text("Window: \(vm.windowStartMinutes) to \(vm.windowEndMinutes) min after Dose 1")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Dose 2: \(vm.prefs.planDose2G.formatG)")
                    Spacer()
                }
            }
        } label: {
            Label("Plan", systemImage: "moon.stars.fill")
        }
    }
    
    private var safetyCard: some View {
        VStack(spacing: 12) {
            // Safety validation
            SafetyBanner(
                nightTotalG: vm.prefs.totalNightG,
                planDose1G: vm.prefs.planDose1G,
                planDose2G: vm.prefs.planDose2G
            )
            
            // Data sources
            StatusChips(
                healthOK: true,
                whoopOK: true,
                wakeSource: "manual",
                onChangeWakeSource: {},
                onCheckHealth: {},
                onCheckWhoop: {}
            )
        }
    }
    
    private var contextCard: some View {
        Text(nightContextLine)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
    
    private var countdownCard: some View {
        GroupBox {
            TimelineView(.periodic(from: Date(), by: 30)) { _ in
                CountdownRing(
                    progress: vm.ringProgress,
                    status: vm.ringStatus,
                    reasonText: vm.dose2ReasonText
                )
            }
        } label: {
            Label("Dose 2 Window", systemImage: "clock.fill")
        }
    }
    
    private var eventsCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent Events")
                        .font(.headline)
                    
                    Spacer()
                    
                    if !vm.lastEvents.isEmpty {
                        Button("View all") {
                            // TODO: Show full history
                        }
                        .font(.footnote)
                    }
                }
                
                if vm.lastEvents.isEmpty {
                    HStack {
                        Image(systemName: "moon.zzz")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        
                        Text("No events logged yet")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    ForEach(vm.lastEvents.prefix(5)) { event in
                        EventRow(event: event)
                    }
                }
                
                Divider()
                
                Button(action: vm.undoLast) {
                    Label("Undo last (60s)", systemImage: "arrow.uturn.backward")
                        .font(.footnote)
                }
                .disabled(vm.lastEvents.isEmpty)
            }
        } label: {
            Label("Timeline", systemImage: "list.bullet")
        }
    }
    
    private var statusCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label("Status", systemImage: "info.circle.fill")
                    .font(.headline)
                
                Text(vm.dose2ReasonText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                
                if AppPreferencesEnhanced.shared.liveActivityEnabled {
                    Text("You will be notified at window start and end")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Fixed Action Dock
    
    private var actionDock: some View {
        VStack(spacing: 0) {
            Divider()
            
            VStack(spacing: 12) {
                // Row 1: Primary actions
                HStack(spacing: 8) {
                    Button("In bed") { vm.logInBedNow() }
                        .buttonStyle(.bordered)
                        .font(.footnote)
                    
                    Button("Dose 1") { vm.logDose1Now(grams: vm.prefs.planDose1G) }
                        .buttonStyle(.bordered)
                        .font(.footnote)
                    
                    Button("Dose 2") { vm.tryLogDose2() }
                        .buttonStyle(.borderedProminent)
                        .font(.footnote)
                        .disabled(!vm.dose2Enabled)
                    
                    Button("Final wake") { vm.logFinalWake() }
                        .buttonStyle(.bordered)
                        .font(.footnote)
                }
                
                // Row 2: Secondary actions
                HStack(spacing: 8) {
                    Button("Alarm wake") { vm.logAlarmWake() }
                        .buttonStyle(.bordered)
                        .font(.footnote)
                    
                    Button("Bathroom") { vm.logBathroom() }
                        .buttonStyle(.bordered)
                        .font(.footnote)
                    
                    Button("Undo") { vm.undoLast() }
                        .buttonStyle(.bordered)
                        .font(.footnote)
                        .disabled(vm.lastEvents.isEmpty)
                    
                    Button("Edit plan") { showSettings = true }
                        .buttonStyle(.bordered)
                        .font(.footnote)
                }
                
                // Row 3: Override & Tools
                HStack(spacing: 8) {
                    if vm.isAfterWindow && AppPreferencesEnhanced.shared.allowLateDose {
                        Button("Log Dose 2 (late)") {
                            showLateDoseSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .font(.footnote)
                    }
                    
                    if vm.nightKey != nil {
                        Button("Reset Night") {
                            vm.presentResetNight()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .font(.footnote)
                    }
                    
                    Button("Export CSV") {
                        // TODO: Export
                    }
                    .buttonStyle(.bordered)
                    .font(.footnote)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
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
}

// MARK: - Supporting Views

struct EventRow: View {
    let event: LoggedEvent
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: eventIcon)
                .font(.title3)
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
            
            Text(relativeTime)
                .font(.caption)
                .foregroundStyle(.secondary)
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
    
    private var relativeTime: String {
        let interval = Date().timeIntervalSince(event.timestampUTC)
        let minutes = Int(interval / 60)
        
        if minutes < 1 {
            return "Just now"
        } else if minutes < 60 {
            return "\(minutes)m ago"
        } else {
            let hours = minutes / 60
            return "\(hours)h ago"
        }
    }
}

// MARK: - Preview

#Preview("Card Stack Layout") {
    TodayLogView_CardStack()
}
