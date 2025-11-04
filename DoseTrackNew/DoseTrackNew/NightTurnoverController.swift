import Foundation
import SwiftData

/// Centralized controller for night lifecycle transitions and cutoff crossing logic
/// Handles auto-close, minting, and state transitions in a transactional, idempotent way
@MainActor
final class NightTurnoverController {
    
    private let modelContext: ModelContext
    private let prefs: AppPreferencesEnhanced
    
    init(modelContext: ModelContext, preferences: AppPreferencesEnhanced = .shared) {
        self.modelContext = modelContext
        self.prefs = preferences
    }
    
    // MARK: - Cutoff Crossing Handler
    
    /// Handle cutoff crossing: auto-close lingering nights, mint tonight
    /// - Returns: True if any changes were made
    @discardableResult
    func handleCutoffCrossing() -> Bool {
        var changesMade = false
        
        // Step 1: Auto-close any lingering nights from before last night
        if autoCloseLingeringNights() {
            changesMade = true
        }
        
        // Step 2: Mint tonight if it doesn't exist (idempotent)
        if mintTonightIfNeeded() {
            changesMade = true
        }
        
        // Step 3: Save changes
        if changesMade {
            do {
                try modelContext.save()
                print("✅ Cutoff crossing handled: changes saved")
            } catch {
                print("❌ Failed to save cutoff crossing changes: \(error)")
            }
        }
        
        return changesMade
    }
    
    // MARK: - Auto-Close Logic
    
    /// Auto-close nights that should have been closed at previous cutoff
    /// Finds any nights before "last night" that aren't closed/abandoned
    /// - Returns: True if any nights were closed
    @discardableResult
    func autoCloseLingeringNights() -> Bool {
        let lastNightKey = NightServiceDay.lastNightKey(cutoffHour: prefs.cutoffHourLocal)
        
        // Fetch all nights before last night
        let descriptor = FetchDescriptor<DoseLog>(
            predicate: #Predicate<DoseLog> { night in
                night.nightKey < lastNightKey
            }
        )
        
        guard let allNights = try? modelContext.fetch(descriptor) else {
            print("⚠️ Failed to fetch nights for auto-close")
            return false
        }
        
        // Filter to only active nights (not already closed/abandoned)
        let lingeringNights = allNights.filter { night in
            night.currentLifecycleState != .closed &&
            night.currentLifecycleState != .abandoned
        }
        
        guard !lingeringNights.isEmpty else {
            return false // No lingering nights to close
        }
        
        // Close each lingering night
        for night in lingeringNights {
            night.currentLifecycleState = .closed
            night.autoClosedAt = Date()
            print("🔒 Auto-closed lingering night: \(night.nightKey) (was \(night.lifecycleState))")
        }
        
        return true
    }
    
    // MARK: - Mint Tonight Logic
    
    /// Mint a planned "Tonight" session if it doesn't exist
    /// Idempotent: safe to call multiple times
    /// - Returns: True if a new night was minted
    @discardableResult
    func mintTonightIfNeeded() -> Bool {
        let tonightKey = NightServiceDay.tonightKey(cutoffHour: prefs.cutoffHourLocal)
        
        // Check if tonight already exists
        let descriptor = FetchDescriptor<DoseLog>(
            predicate: #Predicate<DoseLog> { night in
                night.nightKey == tonightKey
            }
        )
        
        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty {
            print("ℹ️ Tonight already exists: \(tonightKey)")
            return false // Already minted
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
        newNight.plannedDose1Time = prefs.weeklySchedule.suggestedDose1Time(
            for: now,
            cutoffHour: prefs.cutoffHourLocal
        )
        
        modelContext.insert(newNight)
        print("🌙 Minted tonight: \(tonightKey) with planned Dose 1 at \(newNight.plannedDose1Time?.description ?? "N/A")")
        
        return true
    }
    
    // MARK: - Timezone Change Handler
    
    /// Handle timezone changes (travel, DST)
    /// Updates tonight's plan based on timezone policy
    /// - Parameters:
    ///   - from: Previous timezone
    ///   - to: Current timezone
    ///   - action: Rebase action to take
    func handleTimeZoneChange(from previousTZ: TimeZone, to currentTZ: TimeZone, action: RebaseAction) {
        let tonightKey = NightServiceDay.tonightKey(cutoffHour: prefs.cutoffHourLocal)
        
        // Fetch tonight
        let descriptor = FetchDescriptor<DoseLog>(
            predicate: #Predicate<DoseLog> { night in
                night.nightKey == tonightKey
            }
        )
        
        guard let nights = try? modelContext.fetch(descriptor),
              let tonight = nights.first else {
            print("⚠️ No tonight session to rebase")
            return
        }
        
        let change = TimeZoneChange(from: previousTZ, to: currentTZ)
        print("🌍 Timezone changed: \(change.description)")
        
        switch action {
        case .local:
            // Recompute planned Dose 1 time in local timezone
            tonight.plannedDose1Time = prefs.weeklySchedule.suggestedDose1Time(
                cutoffHour: prefs.cutoffHourLocal,
                in: currentTZ
            )
            
            // Update timezone offset
            tonight.timezoneOffsetMinutes = currentTZ.secondsFromGMT(for: Date()) / 60
            
            do {
                try modelContext.save()
                print("✅ Rebased tonight to local time: \(tonight.plannedDose1Time?.description ?? "N/A")")
            } catch {
                print("❌ Failed to save rebase: \(error)")
            }
            
        case .keepHome:
            // Don't adjust - planned time stays in home timezone
            print("🏠 Keeping home time (no rebase)")
            
        case .manual:
            // User will adjust via plan editor
            print("👤 Manual adjustment required")
        }
    }
    
    // MARK: - State Transition Helpers
    
    /// Transition a night to a specific lifecycle state
    /// - Parameters:
    ///   - night: The night to transition
    ///   - newState: The target state
    ///   - reason: Optional reason for the transition (for debugging/audit)
    func transition(_ night: DoseLog, to newState: NightLifecycleState, reason: String? = nil) {
        let oldState = night.currentLifecycleState
        
        // Validate transition is allowed
        guard isValidTransition(from: oldState, to: newState) else {
            print("❌ Invalid transition: \(oldState.displayName) → \(newState.displayName)")
            return
        }
        
        night.currentLifecycleState = newState
        
        let reasonStr = reason.map { " (\($0))" } ?? ""
        print("🔄 Night \(night.nightKey): \(oldState.displayName) → \(newState.displayName)\(reasonStr)")
    }
    
    /// Check if a state transition is valid
    private func isValidTransition(from: NightLifecycleState, to: NightLifecycleState) -> Bool {
        // Allow any transition to closed or abandoned (reset/skip/auto-close)
        if to == .closed || to == .abandoned {
            return true
        }
        
        // Allow re-planning abandoned nights
        if from == .abandoned && to == .planned {
            return true
        }
        
        // Define valid forward transitions
        switch from {
        case .planned:
            return to == .armed || to == .active
        case .armed:
            return to == .active
        case .active:
            return to == .windowOpen
        case .windowOpen:
            return to == .windowClosed || to == .awaitWake
        case .windowClosed:
            return to == .awaitWake
        case .awaitWake:
            return to == .closed
        case .closed, .abandoned:
            return false // Cannot transition from terminal states
        }
    }
    
    // MARK: - Query Helpers
    
    /// Fetch tonight's session
    func fetchTonight() -> DoseLog? {
        let tonightKey = NightServiceDay.tonightKey(cutoffHour: prefs.cutoffHourLocal)
        let descriptor = FetchDescriptor<DoseLog>(
            predicate: #Predicate<DoseLog> { night in
                night.nightKey == tonightKey
            }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    /// Fetch last night's session
    func fetchLastNight() -> DoseLog? {
        let lastNightKey = NightServiceDay.lastNightKey(cutoffHour: prefs.cutoffHourLocal)
        let descriptor = FetchDescriptor<DoseLog>(
            predicate: #Predicate<DoseLog> { night in
                night.nightKey == lastNightKey
            }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    /// Fetch all active nights (not closed/abandoned)
    func fetchActiveNights() -> [DoseLog] {
        let descriptor = FetchDescriptor<DoseLog>(
            sortBy: [SortDescriptor(\.nightKey, order: .reverse)]
        )
        
        guard let allNights = try? modelContext.fetch(descriptor) else {
            return []
        }
        
        return allNights.filter { night in
            night.currentLifecycleState.isActive
        }
    }
}
