//
//  Models.swift
//  DoseTrack
//
import Foundation
import SwiftData

public enum PhysioSource: String, Codable, CaseIterable {
    case healthKit
    case whoop
    case manual
    case unknown
}

public enum SleepWindowSource: String, Codable, CaseIterable {
    case userFinalWake
    case healthKit
    case whoop
    case fallback
}

public enum WakeReason: String, Codable, CaseIterable {
    case natural
    case alarm
    case bathroom
    case doseRecoil
    case unknown
}

@Model
public final class DoseLog {
    // Primary key - anchor date key for the night
    @Attribute(.unique) public var nightKey: String

    // UTC anchor and timezone offset
    public var nightStartUTC: Date
    public var timezoneOffsetMinutes: Int

    // Core events
    public var bedtimeUTC: Date?
    public var dose1TimeUTC: Date?
    public var dose2TimeUTC: Date?
    public var finalWakeTimeUTC: Date?
    public var finalWakeSource: SleepWindowSource?

    // Dose grams
    public var dose1Grams: Double?
    public var dose2Grams: Double?

    // Environmental events
    public var bathroomWakeTimesUTC: [Date]
    public var wasAlarmInterrupted: Bool
    public var wakeReason: WakeReason

    // Physiology - summary per night
    public var physio_avgHR: Double?
    public var physio_minHR: Double?
    public var physio_avgRespRate: Double?
    public var physio_rMSSD: Double?     // from WHOOP if available
    public var physio_SDNN: Double?      // from Apple Health if available
    public var physio_restingHR: Double?
    public var physio_source: PhysioSource

    // Sleep staging and quality
    public var sleep_stage_min_light: Int?
    public var sleep_stage_min_deep: Int?
    public var sleep_stage_min_rem: Int?
    public var sleep_disturbances: Int?

    // Morning
    public var morningAlertness: Int?
    public var notes: String?

    // Data quality flags
    public var data_source_conflict: Bool
    public var sleep_window_source: SleepWindowSource

    // ML feature vector id - stable hash of features used in training for this night
    public var ml_feature_vector_id: String?

    public init(nightKey: String,
                nightStartUTC: Date,
                timezoneOffsetMinutes: Int) {
        self.nightKey = nightKey
        self.nightStartUTC = nightStartUTC
        self.timezoneOffsetMinutes = timezoneOffsetMinutes
        self.bedtimeUTC = nil
        self.dose1TimeUTC = nil
        self.dose2TimeUTC = nil
        self.finalWakeTimeUTC = nil
        self.finalWakeSource = nil
        self.dose1Grams = nil
        self.dose2Grams = nil
        self.bathroomWakeTimesUTC = []
        self.wasAlarmInterrupted = false
        self.wakeReason = .unknown
        self.physio_avgHR = nil
        self.physio_minHR = nil
        self.physio_avgRespRate = nil
        self.physio_rMSSD = nil
        self.physio_SDNN = nil
        self.physio_restingHR = nil
        self.physio_source = .unknown
        self.sleep_stage_min_light = nil
        self.sleep_stage_min_deep = nil
        self.sleep_stage_min_rem = nil
        self.sleep_disturbances = nil
        self.morningAlertness = nil
        self.notes = nil
        self.data_source_conflict = false
        self.sleep_window_source = .fallback
        self.ml_feature_vector_id = nil
    }

    public func isValidSequence(windowStartMin: Int = Config.windowStartMinAfterDose1,
                                windowEndMin: Int = Config.windowEndMinAfterDose1) -> (Bool, String?) {
        guard let d1 = dose1TimeUTC, let d2 = dose2TimeUTC else {
            return (true, nil) // nothing to validate yet
        }
        if d2 <= d1 {
            return (false, "Dose 2 must be after Dose 1")
        }
        let delta = d2.timeIntervalSince(d1) / 60.0
        if Int(delta) < windowStartMin || Int(delta) > windowEndMin {
            return (false, "Dose 2 must be \(windowStartMin)-\(windowEndMin) minutes after Dose 1")
        }
        return (true, nil)
    }

    public func validateDoseGuardrails() -> (Bool, String?) {
        if let d1g = dose1Grams {
            if d1g < Config.perDoseMinG || d1g > Config.perDoseMaxG {
                return (false, "Dose 1 grams outside guardrails")
            }
        }
        if let d2g = dose2Grams {
            if d2g < Config.perDoseMinG || d2g > Config.perDoseMaxG {
                return (false, "Dose 2 grams outside guardrails")
            }
        }
        if let d1g = dose1Grams, let d2g = dose2Grams {
            let total = d1g + d2g
            if total < Config.nightlyTotalMinG || total > Config.nightlyTotalMaxG {
                return (false, "Total nightly grams outside guardrails")
            }
        }
        return (true, nil)
    }
}

@Model
public final class NightSurvey {
    @Attribute(.unique) public var nightKey: String

    // Optional one-to-one details captured in the morning
    public var alcohol_units: Double?
    public var alcohol_timeUTC: Date?
    // store hashed medication keys for privacy
    public var other_meds_hashed: [String]    // e.g. SHA256(name.lowercased())
    public var other_meds_timesUTC: [Date]
    public var stress_1to5: Int?
    public var room_light: String?            // "dark", "dim", "bright"
    public var screen_last_off_timeUTC: Date?

    public init(nightKey: String) {
        self.nightKey = nightKey
        self.alcohol_units = nil
        self.alcohol_timeUTC = nil
        self.other_meds_hashed = []
        self.other_meds_timesUTC = []
        self.stress_1to5 = nil
        self.room_light = nil
        self.screen_last_off_timeUTC = nil
    }
}
