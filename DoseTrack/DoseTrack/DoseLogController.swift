import Foundation
import SwiftData

final class DoseLogController {
    let context: ModelContext
    init(_ context: ModelContext) { self.context = context }

    func currentNightKeyAndStartUTC() -> (String, Date, Int) {
        let now = Date()
        let tzOffsetMin = TimeZone.current.secondsFromGMT() / 60
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: tzOffsetMin * 60)!
        let comps = DateComponents(hour: Config.defaultBedtimeHour, minute: Config.defaultBedtimeMinute)
        let bedtimeLocalToday = cal.nextDate(after: now, matching: comps, matchingPolicy: .nextTimePreservingSmallerComponents) ?? now
        // If after midnight, map dose2 to same night by subtracting 1 day if needed
        let nightKey = cal.dateComponents([.year, .month, .day], from: bedtimeLocalToday).date.map {
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; df.timeZone = cal.timeZone; return df.string(from: $0)
        } ?? "unknown"
        // Convert bedtimeLocalToday to UTC for storage
        let bedtimeUTC = Date(timeIntervalSince1970: bedtimeLocalToday.timeIntervalSince1970 - Double(tzOffsetMin * 60))
        return (nightKey, bedtimeUTC, tzOffsetMin)
    }

    private func fetchOrCreateCurrentNight() -> DoseLog {
        let (key, startUTC, off) = currentNightKeyAndStartUTC()
        let descriptor = FetchDescriptor<DoseLog>(predicate: #Predicate { $0.nightKey == key })
        if let found = try? context.fetch(descriptor).first { return found }
        let log = DoseLog(nightKey: key, nightStartUTC: startUTC, timezoneOffsetMinutes: off)
        context.insert(log)
        try? context.save()
        return log
    }

    func logDose1(at date: Date, gramsOverride: Double?) {
        var log = fetchOrCreateCurrentNight()
        log.dose1TimeUTC = date
        if let g = gramsOverride { log.dose1Grams = safeDisplayGrams(g) }
        try? context.save()
    }

    func logDose2(at date: Date, gramsOverride: Double?) {
        var log = fetchOrCreateCurrentNight()
        log.dose2TimeUTC = date
        if let g = gramsOverride { log.dose2Grams = safeDisplayGrams(g) }
        try? context.save()
    }

    func setFinalWake(_ date: Date, provenance: String) {
        var log = fetchOrCreateCurrentNight()
        log.finalWakeTimeUTC = date
        log.finalWakeProvenance = provenance
        try? context.save()
    }

    func consumePendingFromWidget() {
        if let pending = AppGroupStore.consumePending() {
            switch pending.kind {
            case .dose1Now: logDose1(at: pending.timestamp, gramsOverride: pending.grams)
            case .dose2Now: logDose2(at: pending.timestamp, gramsOverride: pending.grams)
            }
        }
    }
}
