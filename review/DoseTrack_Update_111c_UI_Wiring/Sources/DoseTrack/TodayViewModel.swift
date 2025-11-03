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
    @Published var earlyReason: EarlyReason = .couldNotSleepAgain
    @Published var lastEvents: [LoggedEvent] = []
    @Published var dose2DisabledReason: String = "Dose 2 available after window opens"
    @Published var prefs = AppPreferences.load()
    
    private let controller: DoseLogControllering
    init(controller: DoseLogControllering) { self.controller = controller }
    
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
    var isBeforeWindowButEligibleEarly: Bool {
        guard prefs.allowEarlyDose, let e = elapsedSinceDose1Min else { return false }
        let minToStart = Double(windowStartMinutes) - e
        return minToStart > 0 && minToStart <= Double(prefs.maxEarlyMinutes)
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
    func tryLogDose2() {
        guard dose1TimeUTC != nil else { dose2DisabledReason = "Log Dose 1 first"; return }
        if isWithinWindow { controller.logDose2Now(grams: prefs.planDose2G); controller.endLiveActivity(); refreshFromStore(); return }
        if isBeforeWindowButEligibleEarly { earlyMinutesRequested = max(5, min(prefs.maxEarlyMinutes, prefs.defaultEarlyButtons.first ?? 5)); showEarlyDoseSheet = true; return }
        if let e = elapsedSinceDose1Min, e < Double(windowStartMinutes) {
            let remaining = Int(Double(windowStartMinutes) - e)
            dose2DisabledReason = "Dose 2 must be at least \(windowStartMinutes) min after Dose 1. \(formatMinutes(remaining)) remaining"
        } else { dose2DisabledReason = "Window expired" }
    }
    func confirmEarlyDose2() {
        controller.logDose2Now(grams: prefs.planDose2G, overrideEarlyMinutes: earlyMinutesRequested, overrideReason: earlyReason.rawValue)
        controller.endLiveActivity(); showEarlyDoseSheet = false; refreshFromStore()
    }
    func logFinalWake() { controller.logFinalWakeNow(provenance: "Manual"); refreshFromStore() }
    func logAlarmWake() { controller.logAlarmWakeNow(); refreshFromStore() }
    func logBathroom() { controller.logBathroomNow(); refreshFromStore() }
    func undoLast() { controller.undoLastEvent(); refreshFromStore() }
    private func ensureNightKeyMintedIfNeeded() { if nightKey == nil { controller.mintNightKeyIfNeeded() } }
    func formatMinutes(_ minutes: Int) -> String { let h = minutes / 60; let m = minutes % 60; return h == 0 ? "\(m)m" : "\(h)h \(m)m" }
}

struct AppPreferences: Codable, Equatable {
    var totalNightG: Double = 6.5
    var split: Split = .fiftyFifty
    var roundingStepG: Double = 0.25
    var windowStartMin: Int = 150
    var windowEndMin: Int = 240
    var allowEarlyDose: Bool = false
    var maxEarlyMinutes: Int = 15
    var requireEarlyReason: Bool = true
    var defaultEarlyButtons: [Int] = [5, 10]
    var liveActivityEnabled: Bool = true
    var notifyAtStart: Bool = true
    var notifyAtHalf: Bool = false
    var notifyAtEnd: Bool = true
    var planDose1G: Double { Self.round(totalNightG * split.firstFraction, step: roundingStepG) }
    var planDose2G: Double { Self.round(totalNightG * split.secondFraction, step: roundingStepG) }
    enum Split: String, Codable, CaseIterable { case fiftyFifty, sixtyForty, fortySixty, custom
        var firstFraction: Double { switch self { case .fiftyFifty: 0.5; case .sixtyForty: 0.6; case .fortySixty: 0.4; case .custom: 0.5 } }
        var secondFraction: Double { 1.0 - firstFraction } }
    static func round(_ value: Double, step: Double) -> Double { (value / step).rounded() * step }
    private static let suite = UserDefaults(suiteName: "group.com.jefferson.dosetrack")!
    private static let key = "AppPreferences.v1"
    static func load() -> AppPreferences { if let d = suite.data(forKey: key), let p = try? JSONDecoder().decode(AppPreferences.self, from: d) { return p } ; return AppPreferences() }
    func save() { if let data = try? JSONEncoder().encode(self) { AppPreferences.suite.set(data, forKey: AppPreferences.key) } }
}
enum EarlyReason: String, CaseIterable, Identifiable { case couldNotSleepAgain = "Could not sleep again", shiftSchedule = "Shift schedule", other = "Other"; var id: String { rawValue } }
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
    func logFinalWakeNow(provenance: String)
    func logAlarmWakeNow()
    func logBathroomNow()
    func undoLastEvent()
    func startLiveActivityIfEnabled(prefs: AppPreferences, dose1UTC: Date, windowStartMin: Int, windowEndMin: Int)
    func endLiveActivity()
}
