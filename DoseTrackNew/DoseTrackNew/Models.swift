import Foundation
import SwiftData

@Model
final class DoseLog {
    @Attribute(.unique) var nightKey: String
    var nightStartUTC: Date
    var timezoneOffsetMinutes: Int
    var bedtimeUTC: Date?
    var dose1TimeUTC: Date?
    var dose2TimeUTC: Date?
    var finalWakeTimeUTC: Date?
    var bathroomWakeTimesUTC: [Date]
    var dose1Grams: Double?
    var dose2Grams: Double?
    var morningAlertness: Int?
    var notes: String?
    var finalWakeProvenance: String?
    
    // Reset Night fields
    var resetBatchId: String?
    var isClosedByReset: Bool = false
    
    // Override tracking (late/early dose)
    var dose2IsOverride: Bool = false
    var dose2OverrideKind: String? // "late" or "early"
    var dose2OverrideMinutes: Int? // How many minutes late/early
    var dose2OverrideReason: String? // User-provided reason

    init(nightKey: String, nightStartUTC: Date, timezoneOffsetMinutes: Int) {
        self.nightKey = nightKey
        self.nightStartUTC = nightStartUTC
        self.timezoneOffsetMinutes = timezoneOffsetMinutes
        self.bathroomWakeTimesUTC = []
    }

    func isValidSequence(windowStartMin: Int, windowEndMin: Int) -> (ok: Bool, msg: String?) {
        guard let d1 = dose1TimeUTC else { return (true, nil) }
        if let d2 = dose2TimeUTC, d2 <= d1 { return (false, "Dose 2 cannot be before or equal to Dose 1.") }
        if let d2 = dose2TimeUTC {
            let mins = Int(d2.timeIntervalSince(d1) / 60.0)
            if mins < windowStartMin { return (false, "Dose 2 is earlier than the allowed window start.") }
            if mins > windowEndMin { return (false, "Dose 2 is later than the allowed window end.") }
        }
        return (true, nil)
    }

    static func csvHeader() -> String {
        "night_date,bedtime,dose1_time,dose1_g,dose2_time,dose2_g,dose2_is_override,dose2_override_kind,dose2_override_minutes,dose2_override_reason,bathroom_wakes,final_wake,morning_alertness,notes"
    }

    func csvRow() -> String {
        let off = timezoneOffsetMinutes
        let nightDate = nightKey
        let bt = bedtimeUTC?.hhmm(withUTCOffsetMinutes: off) ?? ""
        let d1t = dose1TimeUTC?.hhmm(withUTCOffsetMinutes: off) ?? ""
        let d2t = dose2TimeUTC?.hhmm(withUTCOffsetMinutes: off) ?? ""
        let fwt = finalWakeTimeUTC?.hhmm(withUTCOffsetMinutes: off) ?? ""
        let d1g = dose1Grams.map { String(format: "%.2f", $0) } ?? ""
        let d2g = dose2Grams.map { String(format: "%.2f", $0) } ?? ""
        
        // Override fields
        let d2Override = dose2IsOverride ? "1" : "0"
        let d2OverrideKind = dose2OverrideKind ?? ""
        let d2OverrideMin = dose2OverrideMinutes.map(String.init) ?? ""
        let d2OverrideReason = dose2OverrideReason ?? ""
        
        let wakes = bathroomWakeTimesUTC.map { $0.hhmm(withUTCOffsetMinutes: off) }.joined(separator: "|")
        let ma = morningAlertness.map(String.init) ?? ""
        let n = notes ?? ""
        return [nightDate, bt, d1t, d1g, d2t, d2g, d2Override, d2OverrideKind, d2OverrideMin, d2OverrideReason, wakes, fwt, ma, n].joined(separator: ",")
    }
}
