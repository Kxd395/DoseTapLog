import Foundation
import SwiftData

@Model
final class DoseLog {
    @Attribute(.unique) var nightKey: String
    var nightStartUTC: Date
    var timezoneOffsetMinutes: Int
    var dose1TimeUTC: Date?
    var dose1Grams: Double?
    var dose2TimeUTC: Date?
    var dose2Grams: Double?
    var finalWakeTimeUTC: Date?
    var finalWakeProvenance: String?
    var bathroomWakeTimesUTC: [Date]
    var morningAlertness: Int?
    var notes: String?

    init(nightKey: String, nightStartUTC: Date, timezoneOffsetMinutes: Int) {
        self.nightKey = nightKey
        self.nightStartUTC = nightStartUTC
        self.timezoneOffsetMinutes = timezoneOffsetMinutes
        self.bathroomWakeTimesUTC = []
    }

    func isValidSequence(windowStartMin: Int, windowEndMin: Int) -> (Bool, String?) {
        guard let d1 = dose1TimeUTC, let d2 = dose2TimeUTC else { return (true, nil) }
        let delta = d2.timeIntervalSince(d1) / 60.0
        if delta < Double(windowStartMin) { return (false, "Dose 2 too soon") }
        if delta > Double(windowEndMin) { return (false, "Dose 2 too late") }
        return (true, nil)
    }
}
