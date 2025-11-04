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
    @State private var showCutoffToast = false
    @State private var cutoffToastDate = ""
    
    private let prefs = AppPreferencesEnhanced.shared
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    private var turnoverController: NightTurnoverController {
        NightTurnoverController(modelContext: modelContext, preferences: prefs)
    }
    
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
            .overlay(alignment: .top) {
                if showCutoffToast {
                    cutoffToastView
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(100)
                }
            }
            .onReceive(timer) { _ in
                checkForCutoffCrossing()
                checkForTimeZoneChange()
            }
            .onAppear {
                checkForCutoffCrossing()
                turnoverController.mintTonightIfNeeded()
            }
        }
    }
    
    // MARK: - Cutoff Toast UI
    
    private var cutoffToastView: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(.yellow)
                Text("Tonight prepared • \(cutoffToastDate)")
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 8)
            .padding(.top, 8)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showCutoffToast = false
                }
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
        
        // Use controller to handle turnover
        let changesMade = turnoverController.handleCutoffCrossing()
        
        if changesMade {
            showCutoffCrossedToast()
        }
        
        lastRefreshDate = Date()
    }
    
    private func showCutoffCrossedToast() {
        let tonightKey = NightServiceDay.tonightKey(cutoffHour: prefs.cutoffHourLocal)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        
        // Parse nightKey to get date
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM-dd"
        if let date = keyFormatter.date(from: tonightKey) {
            cutoffToastDate = formatter.string(from: date)
            withAnimation {
                showCutoffToast = true
            }
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
        
        let currentTZ = TimeZone.current
        let previousTZ = TimeZone(identifier: prefs.lastKnownTimeZone) ?? currentTZ
        
        // Use controller to handle timezone change
        turnoverController.handleTimeZoneChange(
            from: previousTZ,
            to: currentTZ,
            action: action
        )
    }
}

// MARK: - Preview

#Preview {
    ThreeCardPlanningView()
        .modelContainer(for: DoseLog.self, inMemory: true)
}
