import Foundation
import SwiftData

enum CSVExporter {
    static func header() -> String {
        "nightKey,bedtime,dose1_time,dose1_g,dose2_time,dose2_g,final_wake,wake_reason,was_alarm_interrupted,avg_hr,min_hr,avg_resp,rMSSD,SDNN,resting_hr,stage_min_light,stage_min_deep,stage_min_rem,disturbances,physio_source,data_source_conflict,sleep_window_source,alcohol_units,alcohol_time,stress,room_light,screen_last_off,ml_feature_vector_id"
    }
    static func export(_ logs: [DoseLog]) -> String {
        var rows = [header()]
        for l in logs {
            let row = [
                l.nightKey,
                "",
                l.dose1TimeUTC?.toHHmm(offsetMinutes: l.timezoneOffsetMinutes) ?? "",
                l.dose1Grams.map { String(format: "%.2f", $0) } ?? "",
                l.dose2TimeUTC?.toHHmm(offsetMinutes: l.timezoneOffsetMinutes) ?? "",
                l.dose2Grams.map { String(format: "%.2f", $0) } ?? "",
                l.finalWakeTimeUTC?.toHHmm(offsetMinutes: l.timezoneOffsetMinutes) ?? "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                featureVectorId(for: l)
            ].joined(separator: ",")
            rows.append(row)
        }
        return rows.joined(separator: "\n")
    }
    static func featureVectorId(for log: DoseLog) -> String {
        let s = "\(log.nightKey)|\(log.dose1TimeUTC?.timeIntervalSince1970 ?? 0)|\(log.dose2TimeUTC?.timeIntervalSince1970 ?? 0)|\(log.finalWakeTimeUTC?.timeIntervalSince1970 ?? 0)"
        return String(s.hashValue)
    }
}
