//
//  CSVExporter.swift
//  DoseTrack
//
import Foundation
import SwiftData

struct CSVExporter {
    static func header() -> String {
        let cols = [
            "nightKey","bedtime","dose1_time","dose1_g","dose2_time","dose2_g","final_wake","wake_reason",
            "was_alarm_interrupted","avg_hr","min_hr","avg_resp","rMSSD","SDNN","resting_hr",
            "stage_min_light","stage_min_deep","stage_min_rem","disturbances","physio_source",
            "data_source_conflict","sleep_window_source",
            "alcohol_units","alcohol_time","stress","room_light","screen_last_off",
            "ml_feature_vector_id"
        ]
        return cols.joined(separator: ",")
    }

    static func row(log: DoseLog, survey: NightSurvey?) -> String {
        var cells: [String] = []
        let dfD = DateFormatter()
        dfD.timeZone = TimeZone(secondsFromGMT: 0)
        dfD.dateFormat = Config.csvDateFormat
        let tf = DateFormatter()
        tf.timeZone = TimeZone(secondsFromGMT: 0)
        tf.dateFormat = Config.csvTimeFormat

        func timeCell(_ d: Date?) -> String { d.map { tf.string(from: $0) } ?? "" }

        cells.append(log.nightKey)
        cells.append(timeCell(log.bedtimeUTC))
        cells.append(timeCell(log.dose1TimeUTC))
        cells.append(log.dose1Grams.map { String(format: "%.2f", $0) } ?? "")
        cells.append(timeCell(log.dose2TimeUTC))
        cells.append(log.dose2Grams.map { String(format: "%.2f", $0) } ?? "")
        cells.append(timeCell(log.finalWakeTimeUTC))
        cells.append(log.wakeReason.rawValue)
        cells.append(log.wasAlarmInterrupted ? "yes" : "no")

        cells.append(log.physio_avgHR.map { String(format: "%.2f", $0) } ?? "")
        cells.append(log.physio_minHR.map { String(format: "%.2f", $0) } ?? "")
        cells.append(log.physio_avgRespRate.map { String(format: "%.2f", $0) } ?? "")
        cells.append(log.physio_rMSSD.map { String(format: "%.2f", $0) } ?? "")
        cells.append(log.physio_SDNN.map { String(format: "%.2f", $0) } ?? "")
        cells.append(log.physio_restingHR.map { String(format: "%.2f", $0) } ?? "")

        cells.append(log.sleep_stage_min_light.map { String($0) } ?? "")
        cells.append(log.sleep_stage_min_deep.map { String($0) } ?? "")
        cells.append(log.sleep_stage_min_rem.map { String($0) } ?? "")
        cells.append(log.sleep_disturbances.map { String($0) } ?? "")
        cells.append(log.physio_source.rawValue)
        cells.append(log.data_source_conflict ? "yes" : "no")
        cells.append(log.sleep_window_source.rawValue)

        cells.append(survey?.alcohol_units.map { String(format: "%.2f", $0) } ?? "")
        cells.append(timeCell(survey?.alcohol_timeUTC))
        cells.append(survey?.stress_1to5.map { String($0) } ?? "")
        cells.append(survey?.room_light ?? "")
        cells.append(timeCell(survey?.screen_last_off_timeUTC))

        // Feature vector id
        let fv = FeatureVectorBuilder.featureVector(for: log, survey: survey)
        let fid = FeatureVectorBuilder.stableId(from: fv)
        cells.append(fid)

        return cells.joined(separator: ",")
    }
}
