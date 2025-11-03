import SwiftUI
import Foundation

@MainActor
final class TodayViewModel: ObservableObject {
    @Published var nightKey: String?
    @Published var timezoneOffsetMinutes: Int = TimeZone.current.secondsFromGMT() / 60
    @Published var dose1TimeUTC: Date?
    @Published var dose2TimeUTC: Date?
    @Published var finalWakeTimeUTC: Date?
    @Published var showEarlyDoseSheet: Bool = false
    @Published var earlyMinutesRequested: Int = 0
    @Published var earlyReason: EarlyReason = .couldNotSleep
    @Published var lastEvents: [LoggedEvent] = []
    @Published var dose2DisabledReason: String = "Dose 2 available after window opens"
    @Published var prefs: LegacyAppPreferences
    
    // MARK: - Reset Night State
    @Published var showResetSheet: Bool = false
    @Published var showUndoResetBanner: Bool = false
    @Published var pendingResetBatchId: String?
    
    private(set) var controller: DoseLogControllering
    
    init(controller: DoseLogControllering, prefs: LegacyAppPreferences? = nil) {
        self.controller = controller
        self.prefs = prefs ?? AppPreferences.shared.toLegacyStruct()
        refreshFromStore()
    }
    
    /// Update controller (used when injecting real controller after initialization)
    func updateController(_ newController: DoseLogControllering) {
        self.controller = newController
        refreshFromStore()
    }
    
    func onAppear() {
        controller.consumePendingFromWidget()
        refreshFromStore()
    }
    func refreshFromStore() {
        if let ctx = controller.fetchOpenNight() {
            nightKey = ctx.nightKey
            dose1TimeUTC = ctx.dose1TimeUTC
            dose2TimeUTC = ctx.dose2TimeUTC
            finalWakeTimeUTC = ctx.finalWakeTimeUTC
            timezoneOffsetMinutes = ctx.timezoneOffsetMinutes
            lastEvents = controller.fetchRecentEvents(limit: 3)
        } else {
            nightKey = nil; dose1TimeUTC = nil; dose2TimeUTC = nil; finalWakeTimeUTC = nil; lastEvents = []
        }
    }
    
    var windowStartMinutes: Int { prefs.windowStartMin }
    var windowEndMinutes: Int { prefs.windowEndMin }
    var nowUTC: Date { Date() }
    var elapsedSinceDose1Min: Double? {
        guard let t1 = dose1TimeUTC else { return nil }
        return nowUTC.timeIntervalSince(t1) / 60.0
    }
    var isWithinWindow: Bool {
        guard let e = elapsedSinceDose1Min else { return false }
        return e >= Double(windowStartMinutes) && e <= Double(windowEndMinutes)
    }
    var isWindowExpired: Bool {
        guard let e = elapsedSinceDose1Min else { return false }
        return e > Double(windowEndMinutes)
    }
    var dose2Enabled: Bool {
        if dose2TimeUTC != nil { return false }
        if isWithinWindow { return true }
        if isBeforeWindowButEligibleEarly { return true }
        return false
    }
    var dose2ReasonText: String {
        guard let e = elapsedSinceDose1Min else { return "Log Dose 1 to start the window" }
        if isWithinWindow { return "Window closes in \(formatMinutes(Int(Double(windowEndMinutes) - e)))" }
        if e < Double(windowStartMinutes) {
            let t = Int(Double(windowStartMinutes) - e)
            return prefs.allowEarlyDose ? "Window opens in \(formatMinutes(t)). Early override allowed" : "Window opens in \(formatMinutes(t))"
        }
        return "Window expired \(formatMinutes(Int(e - Double(windowEndMinutes)))) ago"
    }
    var ringProgress: Double {
        guard let e = elapsedSinceDose1Min else { return 0 }
        let clamped = max(0, min(Double(windowEndMinutes), e))
        return clamped / Double(windowEndMinutes)
    }
    var ringStatus: CountdownRing.Status {
        if dose1TimeUTC == nil { return .idle }
        if isWithinWindow { return .open }
        if isWindowExpired { return .expired }
        return .waiting
    }
    
    func logInBedNow() { ensureNightKeyMintedIfNeeded(); controller.logInBedNow(); refreshFromStore() }
    func logDose1Now(grams: Double) {
        ensureNightKeyMintedIfNeeded()
        controller.logDose1Now(grams: grams)
        refreshFromStore()
        controller.startLiveActivityIfEnabled(prefs: prefs, dose1UTC: dose1TimeUTC ?? nowUTC, windowStartMin: windowStartMinutes, windowEndMin: windowEndMinutes)
    }
    func confirmEarlyDose2() {
        controller.logDose2Now(grams: prefs.planDose2G, overrideEarlyMinutes: earlyMinutesRequested, overrideReason: earlyReason.rawValue)
        controller.endLiveActivity(); showEarlyDoseSheet = false; refreshFromStore()
    }
    func logFinalWake() { controller.logFinalWakeNow(provenance: "Manual"); refreshFromStore() }
    func logAlarmWake() { controller.logAlarmWakeNow(); refreshFromStore() }
    func logBathroom() { controller.logBathroomNow(); refreshFromStore() }
    func undoLast() { controller.undoLastEvent(); refreshFromStore() }
    
    // MARK: - Reset Night Methods
    
    /// Present the Reset Night sheet
    func presentResetNight() {
        self.showResetSheet = true
    }
    
    /// Perform reset night with mode and reason (soft or hard)
    func performResetNight(mode: ResetMode, reason: String) {
        let batchId = UUID().uuidString
        controller.resetNight(mode: mode, reason: reason, resetBatchId: batchId)
        controller.endLiveActivity()
        controller.cancelDose2Notifications()
        
        // Clear all state
        self.nightKey = nil
        self.dose1TimeUTC = nil
        self.dose2TimeUTC = nil
        self.finalWakeTimeUTC = nil
        self.lastEvents.removeAll()
        
        // Show undo banner for soft reset only
        if mode == .soft {
            self.pendingResetBatchId = batchId
            self.showUndoResetBanner = true
            
            // Auto-hide undo banner after window expires
            let undoWindow = Double(AppPreferences.shared.resetUndoWindowSec)
            DispatchQueue.main.asyncAfter(deadline: .now() + undoWindow) {
                self.showUndoResetBanner = false
                self.pendingResetBatchId = nil
            }
        }
    }
    
    /// Undo a soft reset within the undo window
    func undoResetNight() {
        guard let batch = self.pendingResetBatchId else { return }
        controller.undoResetNight(resetBatchId: batch)
        self.pendingResetBatchId = nil
        self.showUndoResetBanner = false
        refreshFromStore()
    }
    
    /// DEPRECATED: Legacy reset method - use performResetNight instead
    func resetNight(archive: Bool = true) {
        controller.resetCurrentNight(archive: archive)
        controller.endLiveActivity()
        refreshFromStore()
    }
    
    private func ensureNightKeyMintedIfNeeded() { if nightKey == nil { controller.mintNightKeyIfNeeded() } }
    func formatMinutes(_ minutes: Int) -> String { let h = minutes / 60; let m = minutes % 60; return h == 0 ? "\(m)m" : "\(h)h \(m)m" }
}

// Moved to AppPreferences.swift - using LegacyAppPreferences for compatibility

struct LoggedEvent: Identifiable, Equatable { enum Kind: String { case inBed, dose1, bathroom, dose2, alarmWake, finalWake }
    let id = UUID(); let kind: Kind; let timestampUTC: Date; let detail: String }
protocol DoseLogControllering {
    func consumePendingFromWidget()
    func fetchOpenNight() -> (nightKey: String, dose1TimeUTC: Date?, dose2TimeUTC: Date?, finalWakeTimeUTC: Date?, timezoneOffsetMinutes: Int)?
    func fetchRecentEvents(limit: Int) -> [LoggedEvent]
    func mintNightKeyIfNeeded()
    func logInBedNow()
    func logDose1Now(grams: Double)
    func logDose2Now(grams: Double, overrideEarlyMinutes: Int?, overrideReason: String?)
    func logDose2Now(grams: Double, overrideKind: String?, overrideMinutes: Int?, overrideReason: String?) // Late dose support
    func logFinalWakeNow(provenance: String)
    func logAlarmWakeNow()
    func logBathroomNow()
    func undoLastEvent()
    func resetCurrentNight(archive: Bool) // DEPRECATED: Use resetNight(mode:reason:resetBatchId:) instead
    func resetNight(mode: ResetMode, reason: String, resetBatchId: String)
    func undoResetNight(resetBatchId: String)
    func cancelDose2Notifications()
    func startLiveActivityIfEnabled(prefs: LegacyAppPreferences, dose1UTC: Date, windowStartMin: Int, windowEndMin: Int)
    func endLiveActivity()
}
