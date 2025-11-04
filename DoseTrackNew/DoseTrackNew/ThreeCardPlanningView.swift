import SwiftUI
import SwiftData

/// Three-card planning horizon: Last Night / Tonight / Tomorrow
/// Replaces the single "TodayLogView" with a comprehensive planning interface
struct ThreeCardPlanningView: View {
    @Query(sort: \DoseLog.nightKey, order: .reverse) private var allNights: [DoseLog]
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedHorizon: PlanningHorizon = .tonight
    @State private var showSettings = false
    @State private var showTimeZoneRebasePrompt = false
    @State private var lastRefreshDate = Date()
    
    private let prefs = AppPreferencesEnhanced.shared
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control for horizon selection
                Picker("Planning Horizon", selection: $selectedHorizon) {
                    ForEach(PlanningHorizon.allCases, id: \.self) { horizon in
                        Text(horizon.displayName).tag(horizon)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Selected card
                TabView(selection: $selectedHorizon) {
                    ForEach(PlanningHorizon.allCases, id: \.self) { horizon in
                        NightCardViewModern(
                            horizon: horizon,
                            night: nightFor(horizon),
                            modelContext: modelContext
                        )
                        .tag(horizon)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("DoseTrack")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsViewEnhanced()
            }
            .alert("Time Zone Changed", isPresented: $showTimeZoneRebasePrompt) {
                timeZoneRebaseAlert
            }
            .onReceive(timer) { _ in
                checkForCutoffCrossing()
                checkForTimeZoneChange()
            }
            .onAppear {
                checkForCutoffCrossing()
                mintTonightIfNeeded()
            }
        }
    }
    
    // MARK: - Night Lookup
    
    private func nightFor(_ horizon: PlanningHorizon) -> DoseLog? {
        let nightKey = horizon.nightKey(cutoffHour: prefs.cutoffHourLocal)
        return allNights.first { $0.nightKey == nightKey }
    }
    
    // MARK: - Auto-Turnover Logic
    
    /// Check if we've crossed the cutoff and need to auto-close/mint
    private func checkForCutoffCrossing() {
        let hasCrossed = NightServiceDay.hasCrossedCutoff(
            since: lastRefreshDate,
            cutoffHour: prefs.cutoffHourLocal
        )
        
        guard hasCrossed else { return }
        
        // Auto-close any lingering nights from yesterday
        autoCloseLingeringNights()
        
        // Mint tonight if it doesn't exist
        mintTonightIfNeeded()
        
        // Show toast
        showCutoffCrossedToast()
        
        lastRefreshDate = Date()
    }
    
    /// Auto-close nights that should have been closed at previous cutoff
    private func autoCloseLingeringNights() {
        let lastNightKey = NightServiceDay.lastNightKey(cutoffHour: prefs.cutoffHourLocal)
        
        // Find any nights before last night that aren't closed
        let lingeringNights = allNights.filter { night in
            night.nightKey < lastNightKey &&
            night.currentLifecycleState != .closed &&
            night.currentLifecycleState != .abandoned
        }
        
        for night in lingeringNights {
            night.currentLifecycleState = .closed
            night.autoClosedAt = Date()
            print("Auto-closed lingering night: \(night.nightKey)")
        }
        
        if !lingeringNights.isEmpty {
            try? modelContext.save()
        }
    }
    
    /// Mint a planned "Tonight" session if it doesn't exist
    private func mintTonightIfNeeded() {
        let tonightKey = NightServiceDay.tonightKey(cutoffHour: prefs.cutoffHourLocal)
        
        // Check if tonight already exists
        if allNights.contains(where: { $0.nightKey == tonightKey }) {
            return
        }
        
        // Create new planned night for tonight
        let now = Date()
        let tzOffset = TimeZone.current.secondsFromGMT(for: now) / 60
        let newNight = DoseLog(
            nightKey: tonightKey,
            nightStartUTC: now,
            timezoneOffsetMinutes: tzOffset
        )
        newNight.currentLifecycleState = .planned
        
        // Set planned Dose 1 time from weekly schedule
        let schedule = prefs.weeklySchedule
        newNight.plannedDose1Time = schedule.suggestedDose1Time(
            for: now,
            cutoffHour: prefs.cutoffHourLocal
        )
        
        modelContext.insert(newNight)
        try? modelContext.save()
        
        print("Minted tonight: \(tonightKey)")
    }
    
    private func showCutoffCrossedToast() {
        let tonightKey = NightServiceDay.tonightKey(cutoffHour: prefs.cutoffHourLocal)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        
        // Parse nightKey to get date
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM-dd"
        if let date = keyFormatter.date(from: tonightKey) {
            let dateString = formatter.string(from: date)
            print("✅ Tonight prepared • \(dateString)")
            // TODO: Show actual toast UI
        }
    }
    
    // MARK: - Timezone Change Detection
    
    private func checkForTimeZoneChange() {
        let currentTZ = TimeZone.current.identifier
        let lastKnownTZ = prefs.lastKnownTimeZone
        
        guard currentTZ != lastKnownTZ else { return }
        
        // Timezone has changed
        let previous = TimeZone(identifier: lastKnownTZ) ?? .current
        let current = TimeZone.current
        let change = TimeZoneChange(from: previous, to: current)
        
        // Update last known
        prefs.lastKnownTimeZone = currentTZ
        
        // Show rebase prompt if policy is "ask" and shift is significant
        if prefs.timeZonePolicy == .ask && change.shouldPromptRebase {
            showTimeZoneRebasePrompt = true
        } else if prefs.timeZonePolicy == .local {
            // Auto-rebase to local time
            rebaseTonightPlan(action: .local)
        }
        // If policy is "home", do nothing (keep home time)
    }
    
    private var timeZoneRebaseAlert: some View {
        Group {
            Button("Use Local Time") {
                rebaseTonightPlan(action: .local)
            }
            Button("Keep Home Time") {
                rebaseTonightPlan(action: .keepHome)
            }
            Button("Adjust Manually") {
                // Just dismiss
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    private func rebaseTonightPlan(action: RebaseAction) {
        guard let tonight = nightFor(.tonight) else { return }
        
        switch action {
        case .local:
            // Recompute planned Dose 1 time in local timezone
            let schedule = prefs.weeklySchedule
            tonight.plannedDose1Time = schedule.suggestedDose1Time(
                cutoffHour: prefs.cutoffHourLocal
            )
            try? modelContext.save()
            print("Rebased tonight to local time")
            
        case .keepHome:
            // Don't adjust - planned time stays in home timezone
            print("Keeping home time")
            
        case .manual:
            // User will adjust via plan editor
            break
        }
    }
}

// MARK: - Preview

#Preview {
    ThreeCardPlanningView()
        .modelContainer(for: DoseLog.self, inMemory: true)
}
