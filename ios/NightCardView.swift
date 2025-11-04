import SwiftUI
import SwiftData

/// Individual night card showing state, plan, and actions
/// Adapts behavior based on horizon (Last Night / Tonight / Tomorrow)
struct NightCardView: View {
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
            VStack(spacing: 20) {
                if let night = night {
                    existingNightCard(night)
                } else {
                    plannedNightCard
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Existing Night Card
    
    @ViewBuilder
    private func existingNightCard(_ night: DoseLog) -> some View {
        VStack(spacing: 16) {
            // Header with date, nightKey, timezone
            headerSection(night)
            
            // Plan summary
            planSection(night)
            
            // Safety status
            safetySection(night)
            
            // Status ring (if active)
            if night.currentLifecycleState.isActive {
                statusRingSection(night)
            }
            
            // Actions based on state and horizon
            actionsSection(night)
            
            // Recent events
            if horizon == .tonight || horizon == .lastNight {
                recentEventsSection(night)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(radius: 2)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Planned Night Card (Tomorrow)
    
    @ViewBuilder
    private var plannedNightCard: some View {
        VStack(spacing: 16) {
            // Tomorrow preview
            Text("No plan yet for \(horizon.displayName)")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Button("Create Plan from Template") {
                createPlanFromTemplate()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(radius: 2)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private func headerSection(_ night: DoseLog) -> some View {
        VStack(spacing: 8) {
            // Date label
            Text(formatNightDate(night.nightKey))
                .font(.title2)
                .fontWeight(.bold)
            
            HStack {
                // NightKey
                if prefs.showInternals {
                    Text("Key: \(night.nightKey)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Lifecycle state chip
                lifecycleChip(night.currentLifecycleState)
                
                // Timezone
                Text(timezoneLabel(night.timezoneOffsetMinutes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private func lifecycleChip(_ state: NightLifecycleState) -> some View {
        Text(state.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(chipColor(state))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
    
    private func chipColor(_ state: NightLifecycleState) -> Color {
        switch state {
        case .planned: return .gray
        case .armed: return .blue
        case .active: return .green
        case .windowOpen: return .orange
        case .windowClosed: return .red
        case .awaitWake: return .purple
        case .closed: return .gray
        case .abandoned: return .gray
        }
    }
    
    // MARK: - Plan Section
    
    @ViewBuilder
    private func planSection(_ night: DoseLog) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plan")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    if let planned = night.plannedDose1Time {
                        Text("Dose 1: \(formatTime(planned)) (planned)")
                            .font(.subheadline)
                    }
                    if let d1 = night.dose1TimeUTC {
                        Text("Dose 1: \(formatDoseTime(d1, offset: night.timezoneOffsetMinutes)) • \(formatGrams(night.dose1Grams))")
                            .font(.subheadline)
                            .fontWeight(night.dose1TimeUTC != nil ? .semibold : .regular)
                    }
                    
                    if let d2 = night.dose2TimeUTC {
                        Text("Dose 2: \(formatDoseTime(d2, offset: night.timezoneOffsetMinutes)) • \(formatGrams(night.dose2Grams))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        if night.dose2IsOverride {
                            overrideBadge(night)
                        }
                    } else {
                        Text("Dose 2: \(formatGrams(prefs.planDose2G)) planned")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if horizon == .tonight && !night.currentLifecycleState.isActive {
                    Button("Edit Plan") {
                        showPlanEditor = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            // Window times
            if let d1 = night.dose1TimeUTC {
                let windowStart = d1.addingTimeInterval(Double(prefs.windowStartMin * 60))
                let windowEnd = d1.addingTimeInterval(Double(prefs.windowEndMin * 60))
                Text("Window: \(formatTime(windowStart)) – \(formatTime(windowEnd))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Window: \(prefs.windowStartMin)–\(prefs.windowEndMin) min after Dose 1")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func overrideBadge(_ night: DoseLog) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
            if let kind = night.dose2OverrideKind, let minutes = night.dose2OverrideMinutes {
                Text("\(minutes) min \(kind)")
                    .font(.caption)
            }
        }
        .foregroundStyle(.orange)
    }
    
    // MARK: - Safety Section
    
    @ViewBuilder
    private func safetySection(_ night: DoseLog) -> some View {
        HStack {
            safetyIndicator(
                icon: "checkmark.shield.fill",
                label: "Per-dose safety",
                status: night.dose1Grams ?? 0 <= 5.0 && night.dose2Grams ?? 0 <= 5.0
            )
            
            Spacer()
            
            safetyIndicator(
                icon: "checkmark.circle.fill",
                label: "Nightly total",
                status: (night.dose1Grams ?? 0) + (night.dose2Grams ?? 0) <= 9.0
            )
            
            Spacer()
            
            dataSourceIndicator(night)
        }
        .padding()
    }
    
    @ViewBuilder
    private func safetyIndicator(icon: String, label: String, status: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(status ? .green : .red)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    private func dataSourceIndicator(_ night: DoseLog) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                    .foregroundStyle(.pink)
                Text("OK")
                    .font(.caption2)
            }
            Text("Sources")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Status Ring Section
    
    @ViewBuilder
    private func statusRingSection(_ night: DoseLog) -> some View {
        VStack(spacing: 12) {
            // Countdown ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: ringProgress(night))
                    .stroke(ringColor(night), style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: ringProgress(night))
                
                VStack {
                    Text(ringLabel(night))
                        .font(.headline)
                    if let countdown = ringCountdown(night) {
                        Text(countdown)
                            .font(.system(.largeTitle, design: .monospaced))
                            .fontWeight(.bold)
                    }
                }
            }
            
            if let nextAlert = nextAlertTime(night) {
                Text("Next alert: \(formatTime(nextAlert)) [\(prefs.alarmStyle.description)]")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
    
    private func ringProgress(_ night: DoseLog) -> Double {
        // TODO: Calculate actual progress based on state
        0.3
    }
    
    private func ringColor(_ night: DoseLog) -> Color {
        switch night.currentLifecycleState {
        case .active: return .green
        case .windowOpen: return .orange
        case .windowClosed: return .red
        default: return .blue
        }
    }
    
    private func ringLabel(_ night: DoseLog) -> String {
        switch night.currentLifecycleState {
        case .planned: return "Planned"
        case .armed: return "Armed"
        case .active: return "Active"
        case .windowOpen: return "Window Open"
        case .windowClosed: return "Expired"
        case .awaitWake: return "Awaiting Wake"
        default: return "—"
        }
    }
    
    private func ringCountdown(_ night: DoseLog) -> String? {
        // TODO: Calculate actual countdown
        "02:18:00"
    }
    
    private func nextAlertTime(_ night: DoseLog) -> Date? {
        // TODO: Get from AlarmOrchestrator
        nil
    }
    
    // MARK: - Actions Section
    
    @ViewBuilder
    private func actionsSection(_ night: DoseLog) -> some View {
        VStack(spacing: 12) {
            // Primary actions
            primaryActions(night)
            
            // Secondary actions
            secondaryActions(night)
        }
        .padding()
    }
    
    @ViewBuilder
    private func primaryActions(_ night: DoseLog) -> some View {
        HStack(spacing: 12) {
            if horizon == .tonight {
                switch night.currentLifecycleState {
                case .planned:
                    actionButton("In Bed", icon: "bed.double.fill") {
                        logInBed(night)
                    }
                    
                case .armed:
                    actionButton("Dose 1", icon: "pills.fill") {
                        logDose1(night)
                    }
                    
                case .active, .windowOpen:
                    actionButton("Dose 2", icon: "pills.fill") {
                        attemptDose2(night)
                    }
                    
                    actionButton("Wake", icon: "sunrise.fill") {
                        showWakeSheet = true
                    }
                    
                case .windowClosed:
                    actionButton("Late Dose 2", icon: "pills.fill") {
                        showLateDoseSheet = true
                    }
                    
                    actionButton("Final Wake", icon: "sunrise.fill") {
                        showWakeSheet = true
                    }
                    
                case .awaitWake:
                    actionButton("Final Wake", icon: "sunrise.fill") {
                        showWakeSheet = true
                    }
                    
                default:
                    EmptyView()
                }
            }
        }
    }
    
    @ViewBuilder
    private func actionButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(label)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
    
    @ViewBuilder
    private func secondaryActions(_ night: DoseLog) -> some View {
        HStack(spacing: 8) {
            if horizon == .tonight {
                Button("Bathroom") {
                    logBathroom(night)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Undo") {
                    // TODO: Implement undo
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(true)
                
                if night.currentLifecycleState == .planned || night.currentLifecycleState == .armed {
                    Button("Reset Night") {
                        // TODO: Reset night
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            if horizon == .lastNight {
                Button("Fix Times") {
                    // TODO: Time editor
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Export CSV") {
                    // TODO: Export
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    
    // MARK: - Recent Events Section
    
    @ViewBuilder
    private func recentEventsSection(_ night: DoseLog) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Events")
                .font(.headline)
            
            if let bedtime = night.bedtimeUTC {
                eventRow(icon: "bed.double.fill", label: "In bed", time: bedtime, offset: night.timezoneOffsetMinutes)
            }
            if let d1 = night.dose1TimeUTC {
                eventRow(icon: "pills.fill", label: "Dose 1", time: d1, offset: night.timezoneOffsetMinutes)
            }
            if let d2 = night.dose2TimeUTC {
                eventRow(icon: "pills.fill", label: "Dose 2", time: d2, offset: night.timezoneOffsetMinutes, isOverride: night.dose2IsOverride)
            }
            if !night.bathroomWakeTimesUTC.isEmpty {
                ForEach(night.bathroomWakeTimesUTC, id: \.self) { wake in
                    eventRow(icon: "toilet.fill", label: "Bathroom", time: wake, offset: night.timezoneOffsetMinutes)
                }
            }
            if let wake = night.finalWakeTimeUTC {
                eventRow(icon: "sunrise.fill", label: "Final Wake", time: wake, offset: night.timezoneOffsetMinutes)
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func eventRow(icon: String, label: String, time: Date, offset: Int, isOverride: Bool = false) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
            Text(label)
            Spacer()
            Text(formatDoseTime(time, offset: offset))
                .fontWeight(.semibold)
            if isOverride {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
        .font(.subheadline)
    }
    
    // MARK: - Actions Implementation
    
    private func logInBed(_ night: DoseLog) {
        night.bedtimeUTC = Date()
        night.currentLifecycleState = .armed
        try? modelContext.save()
    }
    
    private func logDose1(_ night: DoseLog) {
        night.dose1TimeUTC = Date()
        night.dose1Grams = prefs.planDose1G
        night.currentLifecycleState = .active
        try? modelContext.save()
    }
    
    private func attemptDose2(_ night: DoseLog) {
        guard let d1 = night.dose1TimeUTC else { return }
        
        let now = Date()
        let minutesSinceD1 = Int(now.timeIntervalSince(d1) / 60)
        
        if minutesSinceD1 < prefs.windowStartMin {
            // Too early
            if prefs.allowEarlyDose {
                showEarlyDoseSheet = true
            }
        } else if minutesSinceD1 > prefs.windowEndMin {
            // Too late
            if prefs.allowLateDose {
                showLateDoseSheet = true
            }
        } else {
            // In window - log normally
            night.dose2TimeUTC = now
            night.dose2Grams = prefs.planDose2G
            night.dose2IsOverride = false
            night.currentLifecycleState = .awaitWake
            try? modelContext.save()
        }
    }
    
    private func logBathroom(_ night: DoseLog) {
        night.bathroomWakeTimesUTC.append(Date())
        try? modelContext.save()
    }
    
    private func createPlanFromTemplate() {
        let nightKey = horizon.nightKey(cutoffHour: prefs.cutoffHourLocal)
        let now = Date()
        let tzOffset = TimeZone.current.secondsFromGMT(for: now) / 60
        
        let newNight = DoseLog(
            nightKey: nightKey,
            nightStartUTC: now,
            timezoneOffsetMinutes: tzOffset
        )
        newNight.currentLifecycleState = .planned
        newNight.plannedDose1Time = prefs.weeklySchedule.suggestedDose1Time(
            cutoffHour: prefs.cutoffHourLocal
        )
        
        modelContext.insert(newNight)
        try? modelContext.save()
    }
    
    // MARK: - Formatting Helpers
    
    private func formatNightDate(_ nightKey: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: nightKey) else { return nightKey }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "EEE, MMM d"
        return displayFormatter.string(from: date)
    }
    
    private func timezoneLabel(_ offsetMinutes: Int) -> String {
        let hours = offsetMinutes / 60
        let sign = hours >= 0 ? "+" : ""
        return "UTC\(sign)\(hours)"
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = prefs.showSeconds ? "HH:mm:ss" : "HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatDoseTime(_ date: Date, offset: Int) -> String {
        let adjusted = date.addingTimeInterval(Double(offset * 60))
        return formatTime(adjusted)
    }
    
    private func formatGrams(_ grams: Double?) -> String {
        guard let g = grams else { return "—" }
        return String(format: "%.2f g", g)
    }
}
